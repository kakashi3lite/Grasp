import OSLog

// MARK: - Privacy-Safe On-Device Logger

/// Structured logging for Grasp using Apple's `os_log` subsystem.
///
/// **Privacy guarantee:** All log entries are written only to the device's
/// on-device unified log store. Zero bytes leave the device.  Logs are
/// viewable in Console.app (Xcode → Window → Devices & Simulators →
/// Open Console).  Users who want to share diagnostics do so by exporting
/// from Console.app or via the "Send Feedback" share sheet — no SDK,
/// no network call, no background upload.
///
/// **Usage pattern:**
/// ```swift
/// GraspLogger.inference.info("Inference started, input \(data.count) bytes")
/// GraspLogger.thermal.warning("Thermal state: \(state.debugDescription)")
/// ```
///
/// **Privacy annotations:**  Mark sensitive fields with `\(value, privacy: .private)`
/// so they are redacted in non-development log streams.
/// Metadata like byte counts or state names are safe as `.public`.
enum GraspLogger {

    /// VLM model loading and inference timing.
    static let inference = Logger(
        subsystem: "com.grasp.vault",
        category: "inference"
    )

    /// ThermalMonitor state transitions and cooldown durations.
    static let thermal = Logger(
        subsystem: "com.grasp.vault",
        category: "thermal"
    )

    /// CoreSpotlight index, delete, and deep-link events.
    static let spotlight = Logger(
        subsystem: "com.grasp.vault",
        category: "spotlight"
    )

    /// SwiftData persistence — save/update/delete timing.
    static let persistence = Logger(
        subsystem: "com.grasp.vault",
        category: "persistence"
    )

    /// View lifecycle, capture events, and user interactions.
    static let ui = Logger(
        subsystem: "com.grasp.vault",
        category: "ui"
    )
}
