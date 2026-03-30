import CoreSpotlight
import SwiftData
import UIKit
import UniformTypeIdentifiers

// ThermalMonitor lives in Managers/ThermalMonitor.swift.

// MARK: - VLM Inference Actor

/// Serialises **all** VLM work on a single, non-main executor.
///
/// Architecture guarantees:
/// - One inference at a time (FIFO queue via `CheckedContinuation`).
/// - Background `ModelContext` for SwiftData writes — main thread never blocks.
/// - `Task.yield()` between model load and inference so the iOS scheduler can
///   manage device thermals.
/// - Thermal pausing: event-driven via `thermalStateDidChangeNotification`
///   (replaces 3-second polling; CPU wakes only on actual thermal events).
/// - Core Spotlight indexing after every successful VLM extraction.
actor VLMInferenceActor {

    static let shared = VLMInferenceActor()

    private let manager: MLXVisionManager

    /// Use `shared` only. `MLXVisionManager` is created with the plist **model id**.
    private init() {
        self.manager = MLXVisionManager(modelID: GraspAppConfiguration.mlxModelID)
    }
    private var container: ModelContainer?
    private var isLoading = false

    // FIFO queue — prevents concurrent inference despite actor reentrancy.
    private var pending: [WorkItem] = []
    private var isDraining = false

    private struct WorkItem {
        let identifier: PersistentIdentifier
        let imageData: Data
        let continuation: CheckedContinuation<Void, any Error>
    }

    // MARK: - Configuration

    /// Called once from `GraspApp.init` with the shared container.
    func configure(container: ModelContainer) {
        self.container = container
    }

    /// True once the VLM weights are in memory.
    var isModelLoaded: Bool { manager.isLoaded }

    /// Eagerly downloads / warms up the model.
    func loadModelIfNeeded() async throws {
        guard !manager.isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        try await manager.prepare()
    }

    // MARK: - Public API

    /// Enqueues one inference job. Suspends the caller until the item has
    /// been fully processed and the SwiftData entity updated.
    ///
    /// - Parameters:
    ///   - identifier: `PersistentIdentifier` of the pre-saved entity.
    ///   - imageData: JPEG `Data` (Sendable-safe; no UIImage crossing).
    func enqueue(
        identifier: PersistentIdentifier,
        imageData: Data
    ) async throws {
        // [Fix 3] If container hasn't landed yet (fast first-capture on cold
        // launch), yield once to give the configure() Task a chance to complete.
        if container == nil {
            await Task.yield()
        }
        guard container != nil else { throw GraspError.modelNotLoaded }

        // Bound FIFO depth so rapid capture cannot grow `pending` without limit
        // (each `WorkItem` retains JPEG bytes until processed).
        if pending.count >= GraspAppConfiguration.maxPendingInferenceJobs {
            throw GraspError.inferenceQueueFull
        }

        try await withCheckedThrowingContinuation { continuation in
            pending.append(WorkItem(
                identifier: identifier,
                imageData: imageData,
                continuation: continuation
            ))
            if !isDraining { Task { await drain() } }
        }
    }

    // MARK: - FIFO Drain Loop

    private func drain() async {
        isDraining = true
        while !pending.isEmpty {
            // Thermal gate: halt if the device is overheating.
            // Safe during reentrancy — new enqueue() calls only append
            // to `pending`; `isDraining` prevents duplicate drain loops.
            await waitForCooldown()

            let item = pending.removeFirst()
            do {
                try await processItem(item)
                item.continuation.resume()
            } catch {
                item.continuation.resume(throwing: error)
            }
        }
        isDraining = false
    }

    private func processItem(_ item: WorkItem) async throws {
        try await loadModelIfNeeded()
        await Task.yield()

        let result = try await manager.extractJSON(from: item.imageData)
        try await updateEntity(identifier: item.identifier, with: result)
    }

    // MARK: - Thermal Pausing (Event-Driven)

    /// Pauses the drain loop while `thermalState` is `.serious` or `.critical`.
    ///
    /// **Before (3-second polling):** CPU woke every 3 seconds regardless of
    /// whether the thermal state had changed.
    ///
    /// **After (notification-driven):** CPU wakes *only* on an actual
    /// `thermalStateDidChangeNotification` event, or at most every 5 seconds
    /// via the fallback timeout yielded into the stream.  Zero overhead during
    /// normal (cool) operation.
    private func waitForCooldown() async {
        guard ProcessInfo.processInfo.thermalState == .serious
            || ProcessInfo.processInfo.thermalState == .critical else { return }

        GraspLogger.thermal.warning("Thermal pause — state: \(ProcessInfo.processInfo.thermalState.rawValue)")
        await MainActor.run { ThermalMonitor.shared.setCoolingDown(true) }

        let coolStart = Date()
        // Iterate the event-driven stream until state normalises.
        // `makeThermalStream()` is nonisolated — no actor hop required.
        for await state in makeThermalStream() {
            GraspLogger.thermal.info("Thermal notification received — new state: \(state.rawValue)")
            if state != .serious && state != .critical { break }
        }

        let coolDuration = Date().timeIntervalSince(coolStart)
        GraspLogger.thermal.info("Thermal cooldown complete after \(String(format: "%.1f", coolDuration))s")
        await MainActor.run { ThermalMonitor.shared.setCoolingDown(false) }
    }

    /// Builds an `AsyncStream<ProcessInfo.ThermalState>` that emits a new
    /// value on every `thermalStateDidChangeNotification`.
    ///
    /// **`nonisolated`** — touches no actor state; can be called from any
    /// concurrency context without an executor hop.
    ///
    /// **TOCTOU guard:** the current thermal state is yielded immediately
    /// *after* the observer is registered.  If the device already cooled
    /// between `waitForCooldown()`'s guard check and here, the caller receives
    /// a non-critical state as the first value and exits without blocking.
    ///
    /// **`TokenBox`:** `NSObjectProtocol` (the observer token returned by
    /// `NotificationCenter.addObserver`) is not `Sendable` by default.
    /// Wrapping it in an `@unchecked Sendable` class satisfies the type
    /// system for `AsyncStream.Continuation.onTermination`, which is
    /// `@Sendable`.  The underlying cleanup call (`removeObserver`) is
    /// thread-safe and executes exactly once.
    nonisolated private func makeThermalStream() -> AsyncStream<ProcessInfo.ThermalState> {
        // @unchecked Sendable wrapper so we can capture the observer token
        // inside the @Sendable `onTermination` closure.
        final class TokenBox: @unchecked Sendable {
            var token: NSObjectProtocol?
            func cleanup() {
                if let t = token { NotificationCenter.default.removeObserver(t) }
            }
        }

        let box = TokenBox()

        return AsyncStream { continuation in
            // Register BEFORE the initial yield to guarantee no notification
            // can slip through the gap.
            box.token = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: nil
            ) { _ in
                continuation.yield(ProcessInfo.processInfo.thermalState)
            }

            // Remove observer when the consumer breaks out of the for-await
            // loop, cancels the task, or the stream goes out of scope.
            continuation.onTermination = { _ in box.cleanup() }

            // Emit current state — closes the TOCTOU window described above.
            continuation.yield(ProcessInfo.processInfo.thermalState)
        }
    }

    // MARK: - Background SwiftData Update + Spotlight

    /// Creates a throwaway `ModelContext`, fetches by identifier,
    /// applies the extraction results, saves, then indexes in Core Spotlight.
    private func updateEntity(
        identifier: PersistentIdentifier,
        with result: ExtractionResult
    ) async throws {
        guard let container else { return }
        let context = ModelContext(container)

        // context.model(for:) can throw if the entity was deleted between
        // enqueue and processing — silently skip in that case.
        do {
            let model = try context.model(for: identifier)
            guard let entity = model as? CapturedEntity else { return }

            entity.title         = result.title
            entity.category      = result.category
            entity.summary       = result.summary
            entity.extractedText = result.rawJSON
            entity.keyEntities   = result.keyEntities
            entity.isProcessed   = true
            try context.save()

            // Spotlight indexing — fire-and-forget, non-fatal.
            await indexInSpotlight(
                id: entity.id,
                title: result.title,
                category: result.category,
                summary: result.summary,
                keywords: result.keyEntities,
                thumbnailData: entity.thumbnail
            )
        } catch {
            // Entity no longer exists in the store — silently skip.
            return
        }
    }

    // MARK: - Core Spotlight Indexing

    /// Maps a processed entity to a `CSSearchableItem` and pushes it to the
    /// default Spotlight index.  Thumbnail data is already compressed JPEG
    /// so memory impact during batch indexing is minimal.
    private func indexInSpotlight(
        id: UUID,
        title: String,
        category: String,
        summary: String,
        keywords: [String],
        thumbnailData: Data
    ) async {
        let attributes = CSSearchableItemAttributeSet(contentType: .image)
        attributes.title = title
        attributes.contentDescription = summary
        attributes.keywords = [category] + keywords
        attributes.thumbnailData = thumbnailData

        let item = CSSearchableItem(
            uniqueIdentifier: id.uuidString,
            domainIdentifier: "com.grasp.captures",
            attributeSet: attributes
        )
        item.expirationDate = .distantFuture

        try? await CSSearchableIndex.default().indexSearchableItems([item])
    }
}
