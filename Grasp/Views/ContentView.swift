import AVFoundation
import CoreSpotlight
import SwiftData
import SwiftUI
import VisionKit

// MARK: - Custom Colors
extension Color {
    static let amber = Color(red: 1.0, green: 0.75, blue: 0.0)
    static let emerald = Color(red: 0.18, green: 0.8, blue: 0.44)
}

struct ContentView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CapturedEntity.date, order: .reverse)
    private var entities: [CapturedEntity]

    // Scanner + VLM
    @State private var scannerModel = ScannerModel()

    // Permission gate
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)

    // Model warm-up
    @State private var isLoadingModel = false
    @State private var modelLoadProgress: Double = 0
    @State private var progressTickerTask: Task<Void, Never>?

    // Processing queue counter
    @State private var processingCount = 0
    @State private var lastCaptureTime: Date = .distantPast

    // Shutter FX
    @State private var showFlash = false
    @State private var shutterScale: CGFloat = 1.0

    // Vault
    @State private var showVault = false

    // Error surface
    @State private var errorMessage: String?
    @State private var showError = false

    // Core Spotlight deep-link
    @State private var spotlightEntityID: UUID?

    // [Fix 1] Gate Spotlight sheet until @Query has populated,
    // preventing a false "Capture Deleted" on cold launch.
    @State private var hasLoadedEntities = false

    // [Fix 8] Scale the permission icon with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var permissionIconSize: CGFloat = 72

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch cameraStatus {
            case .notDetermined:
                permissionView
            case .authorized:
                cameraView
            default:
                deniedView
            }
        }
        .preferredColorScheme(.dark)
        .task { await preloadModel() }
        // [Fix 1] Track when @Query first delivers results.
        .onChange(of: entities) { _, newValue in
            if !hasLoadedEntities && !newValue.isEmpty {
                hasLoadedEntities = true
            }
        }
        // Core Spotlight deep-link: user tapped a Grasp result in system search
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard
                let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
                let uuid = UUID(uuidString: identifier)
            else { return }
            spotlightEntityID = uuid
        }
        // [Fix 1] Only present once @Query has populated, so cold-launch
        // doesn't immediately show "Capture Deleted" for a valid entity.
        .sheet(isPresented: Binding(
            get: { spotlightEntityID != nil && hasLoadedEntities },
            set: { if !$0 { spotlightEntityID = nil } }
        )) {
            if let id = spotlightEntityID {
                let matchedEntity = entities.first(where: { $0.id == id })
                NavigationStack {
                    Group {
                        if let entity = matchedEntity {
                            EntityDetailView(entity: entity)
                        } else {
                            ContentUnavailableView(
                                "Capture Deleted",
                                systemImage: "doc.badge.minus",
                                description: Text(
                                    "This capture was removed from your Vault."
                                )
                            )
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { spotlightEntityID = nil }
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationCornerRadius(32)
                .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Permission Seduction

    private var permissionView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                // [Fix 8] Uses @ScaledMetric instead of hardcoded 72pt.
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: permissionIconSize, weight: .light))
                    .foregroundStyle(Color.emerald)
                    .shadow(color: Color.emerald.opacity(0.4), radius: 20, y: 10)

                Text("""
                    Grasp needs your camera to organize
                    your physical world.

                    Everything is processed on this device.
                    Nothing goes to the cloud.
                    """)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 40)
                    .lineSpacing(4)

                Button {
                    Task { await requestCamera() }
                } label: {
                    Text("AUTHORIZE")
                        .font(.system(.headline, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 48)
                        .shadow(color: .white.opacity(0.2), radius: 10, y: 5)
                }
                Spacer()
            }
        }
    }

    private var deniedView: some View {
        ContentUnavailableView(
            "Camera Unavailable",
            systemImage: "camera.badge.ellipsis",
            description: Text("Enable camera access in Settings to use Grasp.")
        )
    }

    // MARK: - Camera View

    // [Fix 5] Removed .contentShape(Rectangle()) and the ambient .onTapGesture
    // from this ZStack. The shutter Button is the sole tap target for captures.
    // The old ambient gesture swallowed taps intended for the Button, vault handle,
    // and sheet dismiss controls.
    private var cameraView: some View {
        ZStack {
            cameraLayer
            flashOverlay
            overlayControls
        }
        .sheet(isPresented: $showVault) {
            VaultView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
    }

    @ViewBuilder
    private var cameraLayer: some View {
        if scannerModel.isAvailable {
            DataScannerRepresentable(scannerModel: scannerModel)
                .ignoresSafeArea()
                .scaleEffect(shutterScale)
                .overlay {
                    RadialGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        center: .center,
                        startRadius: 200,
                        endRadius: 500
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
        } else {
            deniedView
        }
    }

    private var flashOverlay: some View {
        Color.white.ignoresSafeArea()
            .opacity(showFlash ? 1.0 : 0)
            .allowsHitTesting(false)
    }

    // MARK: - Overlay Controls

    private var overlayControls: some View {
        VStack(spacing: 0) {
            headerArea
                .padding(.top, 8)
            
            Spacer()
            
            shutterArea
                .padding(.bottom, 24)
            
            vaultHandle
                .padding(.bottom, 12)
        }
    }

    // MARK: Header (Dynamic Pills)

    private var headerArea: some View {
        VStack(spacing: 8) {
            if isLoadingModel {
                modelLoadingPill
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            } else if ThermalMonitor.shared.isCoolingDown && processingCount > 0 {
                coolingPill
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            } else if processingCount > 0 {
                processingPill
                    .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: isLoadingModel)
        .animation(.snappy, value: processingCount)
        .animation(.snappy, value: ThermalMonitor.shared.isCoolingDown)
    }

    private var modelLoadingPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .foregroundStyle(Color.amber)
            Text("Initializing Local Engine (\(Int(modelLoadProgress * 100))%)")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
        .phaseAnimator([false, true]) { content, phase in
            content.opacity(phase ? 1 : 0.7)
        } animation: { _ in .easeInOut(duration: 1.5) }
    }

    /// Blue-tinted pill shown when the FIFO queue is paused
    /// due to `.serious` or `.critical` thermal state.
    private var coolingPill: some View {
        HStack(spacing: 10) {
            Text("❄️")
            Text("Cooling Neural Engine...")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.blue.opacity(0.3), radius: 10, y: 0)
        .phaseAnimator([false, true]) { content, phase in
            content.opacity(phase ? 1 : 0.6)
        } animation: { _ in .easeInOut(duration: 2.0) }
    }

    private var processingPill: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.horizontal.fill")
                .foregroundStyle(Color.emerald)
            Text("Processing \(processingCount) item\(processingCount == 1 ? "" : "s")")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color.emerald.opacity(0.2), radius: 10, y: 0)
        .phaseAnimator([false, true]) { content, phase in
            content.scaleEffect(phase ? 1.02 : 0.98)
        } animation: { _ in .easeInOut(duration: 1.0) }
    }

    // MARK: Shutter Button
    private var shutterArea: some View {
        Button(action: capture) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.8), lineWidth: 4)
                    .frame(width: 80, height: 80)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 68, height: 68)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Vault Handle
    private var vaultHandle: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.white.opacity(0.5))
                .frame(width: 44, height: 5)
                .shadow(color: .black.opacity(0.5), radius: 2, y: 1)

            Text("VAULT")
                .font(.system(.caption2, design: .monospaced).bold())
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { showVault = true }
        .highPriorityGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { v in
                    if v.translation.height < -20 { showVault = true }
                }
        )
    }

    // MARK: - Actions

    private func requestCamera() async {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    }

    // [Fix 6] The progress ticker Task is stored and explicitly cancelled
    // when model loading completes, preventing an orphaned task loop.
    private func preloadModel() async {
        isLoadingModel = true

        progressTickerTask = Task { @MainActor in
            while !Task.isCancelled && isLoadingModel && modelLoadProgress < 0.92 {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, isLoadingModel else { break }
                withAnimation(.linear(duration: 0.5)) {
                    modelLoadProgress = min(
                        modelLoadProgress + Double.random(in: 0.03...0.09),
                        0.92
                    )
                }
            }
        }

        do {
            try await VLMInferenceActor.shared.loadModelIfNeeded()
        } catch { /* non-fatal */ }

        progressTickerTask?.cancel()
        progressTickerTask = nil

        withAnimation { modelLoadProgress = 1.0 }
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation { isLoadingModel = false }
    }

    // MARK: - Rapid-Fire Capture

    private func capture() {
        guard scannerModel.isAvailable else { return }

        guard Date.now.timeIntervalSince(lastCaptureTime) > 0.3 else { return }
        lastCaptureTime = .now

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        withAnimation(.easeIn(duration: 0.05)) {
            showFlash = true
            shutterScale = 0.96
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0)) {
                showFlash = false
                shutterScale = 1.0
            }
        }

        Task {
            do {
                let photo = try await scannerModel.capturePhoto()

                // Resize before JPEG encoding so that the full-resolution
                // UIImage (up to ~48 MB decoded on A17 Pro) is never written
                // to disk or the pending queue at full size.
                //
                // MLXVisionManager.resize uses UIGraphicsImageRenderer —
                // hardware-accelerated, no full-quality JPEG intermediate.
                //
                // Thumbnail: 512 px max, 0.4 quality → ~50–100 KB in SwiftData
                //   vs ~1–2 MB from jpegData(0.3) at full camera resolution.
                // Inference: 896 px max, 0.85 quality → ~150–300 KB in the
                //   pending WorkItem queue vs ~4–8 MB at full resolution.
                //   VLMInferenceActor will NOT downsample further — this is
                //   already the optimal VLM input size.
                let thumbData = MLXVisionManager.resize(
                    photo,
                    maxDimension: MLXVisionManager.thumbnailMaxDimension,
                    quality: 0.4
                )
                let inferenceData = MLXVisionManager.resize(
                    photo,
                    maxDimension: MLXVisionManager.vlmMaxDimension
                )
                // `photo` (full-res UIImage) goes out of use here. ARC will
                // release it before the long-running enqueue() await below,
                // recovering the full-resolution memory during inference.

                let entity = CapturedEntity(thumbnail: thumbData)
                modelContext.insert(entity)
                try modelContext.save()

                let identifier = entity.persistentModelID
                
                withAnimation(.snappy) {
                    processingCount += 1
                }

                defer {
                    Task { @MainActor in
                        withAnimation(.snappy) {
                            processingCount -= 1
                        }
                    }
                }
                
                try await VLMInferenceActor.shared.enqueue(
                    identifier: identifier,
                    imageData: inferenceData
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: CapturedEntity.self, inMemory: true)
}
