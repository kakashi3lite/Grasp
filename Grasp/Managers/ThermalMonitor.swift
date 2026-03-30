import Observation

// MARK: - Thermal Monitor

/// `@Observable` singleton that bridges `VLMInferenceActor`'s thermal-pause
/// state to SwiftUI views.
///
/// **Update path:**
///   `VLMInferenceActor` → `await MainActor.run { ThermalMonitor.shared.setCoolingDown(true) }`
///
/// **Read path:**
///   SwiftUI `body` reads `.isCoolingDown` automatically via `@Observable` tracking.
///   No manual `objectWillChange` sink needed.
@Observable
final class ThermalMonitor {

    static let shared = ThermalMonitor()
    private init() {}

    /// `true` while the FIFO inference queue is paused for device-thermal safety.
    /// Written exclusively through `setCoolingDown(_:)`.
    private(set) var isCoolingDown = false

    /// The only authorised mutation entry-point.
    ///
    /// Must be called on `@MainActor` so SwiftUI observation callbacks fire
    /// on the main thread, preventing layout warnings.
    @MainActor
    func setCoolingDown(_ value: Bool) {
        isCoolingDown = value
    }
}
