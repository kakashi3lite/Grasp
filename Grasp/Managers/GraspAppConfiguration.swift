import Foundation

// MARK: - App configuration (Info.plist)

/// Runtime settings loaded from the merged **Info.plist**.
///
/// **Why plist?**
/// - Ops and experiments can point at a different **MLX model id** without a full rebuild.
/// - The inference **queue cap** stays documented and tunable for thermal / memory QA.
///
/// Keys (see `Grasp/Info.plist`):
/// - `GraspMLXModelID` — string, HuggingFace / MLX identifier.
/// - `GraspMaxPendingInferenceJobs` — positive integer (default **50** if missing or invalid).
enum GraspAppConfiguration {

    /// MLX VLM weights identifier.
    static let mlxModelID: String = {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GraspMLXModelID") as? String else {
            return MLXVisionManager.defaultModelID
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? MLXVisionManager.defaultModelID : trimmed
    }()

    /// Maximum **pending** FIFO jobs (each holds JPEG `Data` for one capture).
    ///
    /// Prevents unbounded memory growth if the user captures faster than inference drains.
    static let maxPendingInferenceJobs: Int = {
        guard let any = Bundle.main.object(forInfoDictionaryKey: "GraspMaxPendingInferenceJobs") else {
            return 50
        }
        let n: Int?
        if let number = any as? NSNumber {
            n = number.intValue
        } else if let i = any as? Int {
            n = i
        } else {
            n = nil
        }
        guard let n, n > 0 else { return 50 }
        return n
    }()
}
