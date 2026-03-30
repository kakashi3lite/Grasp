import CoreImage
import ImageIO
import MLXLMCommon
import MLXVLM
import UIKit

// MARK: - Errors

/// Domain errors surfaced to the UI layer.
enum GraspError: LocalizedError {
    case scannerNotReady
    case modelNotLoaded
    case imageConversionFailed
    /// FIFO backlog exceeded `GraspMaxPendingInferenceJobs` (see `Grasp/Info.plist`).
    case inferenceQueueFull

    var errorDescription: String? {
        switch self {
        case .scannerNotReady:       "Camera scanner is not ready"
        case .modelNotLoaded:        "Vision model has not finished loading"
        case .imageConversionFailed: "Could not convert the captured image"
        case .inferenceQueueFull:
            "Too many items are waiting to process. Wait for the queue to clear or try again."
        }
    }
}

// MARK: - MLX Vision Manager

/// Encapsulates VLM model loading and image → structured-JSON inference.
///
/// `nonisolated` opts out of any project-wide MainActor default.
/// All inference is serialised through `VLMInferenceActor`.
nonisolated final class MLXVisionManager: @unchecked Sendable {

    static let defaultModelID = "mlx-community/SmolVLM-Instruct-4bit"

    // MARK: Resolution Constants

    /// Max pixel dimension for inference input.
    ///
    /// SmolVLM tiles images internally — passing a 4K frame buys nothing
    /// but 4–8× extra memory and pre-processing time.  896 px gives the
    /// same extraction accuracy at ~20× less data.
    static let vlmMaxDimension: CGFloat = 896

    /// Max pixel dimension for thumbnails stored in SwiftData
    /// (`@Attribute(.externalStorage)`).
    ///
    /// At 512 px + 0.4 JPEG quality each thumbnail is ~50–100 KB vs the
    /// ~1–2 MB produced by `.jpegData(compressionQuality: 0.3)` at full
    /// camera resolution.
    static let thumbnailMaxDimension: CGFloat = 512

    // MARK: Private Singletons

    /// Stable temp path — overwritten each inference cycle instead of
    /// allocating a new UUID-named file per run.
    /// Safe because the FIFO queue guarantees serial access.
    ///
    /// `tmp/` is already excluded from iCloud/iTunes backup by iOS policy, but
    /// we set `isExcludedFromBackupKey` explicitly as belt-and-suspenders
    /// insurance against SDK changes or simulator edge cases.
    private static let inferenceInputURL: URL = {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("grasp_vlm_input.jpg")
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        return url
    }()

    /// Shared `CIContext` with Metal renderer.
    /// Creating a new context per call triggers expensive pipeline setup.
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private var session: ChatSession?
    private let modelID: String

    init(modelID: String = MLXVisionManager.defaultModelID) {
        self.modelID = modelID
    }

    var isLoaded: Bool { session != nil }

    // MARK: - Model Lifecycle

    /// Downloads weights (first run) and loads the VLM into memory.
    func prepare() async throws {
        let container = try await MLXLMCommon.loadModel(id: modelID)
        session = ChatSession(container)
    }

    // MARK: - Image Preprocessing

    /// Downsamples JPEG/HEIF `Data` to `maxDimension` using `CGImageSource`.
    ///
    /// **Key property — streaming decode:**
    /// `CGImageSourceCreateThumbnailAtIndex` never loads the full-resolution
    /// image into a `CGImage`; it decodes only enough to produce the output
    /// size.  Peak memory is proportional to the *output*, not the input.
    ///
    /// - Parameters:
    ///   - imageData: Source JPEG or HEIF bytes.
    ///   - maxDimension: Longest edge in pixels after downsampling.
    ///   - quality: JPEG re-encode quality (0.0–1.0).  Defaults to 0.85.
    /// - Returns: Downsampled JPEG `Data`, or the original on failure.
    static func downsample(
        _ imageData: Data,
        maxDimension: CGFloat,
        quality: CGFloat = 0.85
    ) -> Data {
        let srcOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(imageData as CFData, srcOptions) else {
            return imageData
        }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,  // respect EXIF orientation
            kCGImageSourceShouldCacheImmediately: false,
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbOptions as CFDictionary
        ) else { return imageData }

        return UIImage(cgImage: thumb).jpegData(compressionQuality: quality) ?? imageData
    }

    /// Resizes a `UIImage` to `maxDimension` using `UIGraphicsImageRenderer`.
    ///
    /// More efficient than `downsample(_:)` when the caller already has a
    /// decoded `UIImage` (avoids a full-quality JPEG intermediate).
    /// Rendering is hardware-accelerated via Core Animation.
    ///
    /// - Parameters:
    ///   - image: Source image.
    ///   - maxDimension: Longest edge in pixels after downsampling.
    ///   - quality: JPEG encode quality (0.0–1.0). Defaults to 0.85.
    /// - Returns: Downsampled JPEG `Data`.  Never upscales.
    static func resize(
        _ image: UIImage,
        maxDimension: CGFloat,
        quality: CGFloat = 0.85
    ) -> Data {
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(maxDimension / longestSide, 1.0)  // never upscale

        // Already fits — compress only, skip the render pass.
        guard scale < 1.0 else {
            return image.jpegData(compressionQuality: quality) ?? Data()
        }

        let targetSize = CGSize(
            width:  (image.size.width  * scale).rounded(),
            height: (image.size.height * scale).rounded()
        )
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality) ?? Data()
    }

    // MARK: - Inference

    /// Strictly constrained prompt that forces consistent JSON output.
    private static let extractionPrompt = """
        Analyze this image. Return ONLY a valid JSON object with these \
        exact keys: 'title' (string), 'category' (one of: Receipt, \
        Document, Object, Note), 'summary' (1 sentence string), and \
        'key_entities' (array of strings). Do not include markdown \
        formatting or any other text.
        """

    /// Runs VLM inference on `imageData`.
    ///
    /// Downsamples to `vlmMaxDimension` before writing to disk — the VLM's
    /// internal tile engine doesn't benefit from higher resolution, and a
    /// smaller payload reduces temp I/O and MLX pre-processing time.
    ///
    /// Uses a **stable temp path** (`grasp_vlm_input.jpg`) that is overwritten
    /// on each call rather than accumulating UUID-named files.  Serial FIFO
    /// access makes this safe.
    func extractJSON(from imageData: Data) async throws -> ExtractionResult {
        guard let session else { throw GraspError.modelNotLoaded }

        let startTime = Date()
        GraspLogger.inference.info("Inference started — raw input \(imageData.count) bytes")

        // Downsample: full-res JPEG sits at disk for the whole inference call
        // (typically 800 ms – 2 s on A17 Pro); smaller file = faster I/O.
        let processedData = Self.downsample(imageData, maxDimension: Self.vlmMaxDimension)
        GraspLogger.inference.info("Downsampled to \(processedData.count) bytes (\(Self.vlmMaxDimension)px max)")

        // Atomic write prevents a partial file if the process is interrupted.
        // No defer-delete: the stable path is simply overwritten next time.
        try processedData.write(to: Self.inferenceInputURL, options: .atomic)

        let raw = try await session.respond(
            to: Self.extractionPrompt,
            image: .url(Self.inferenceInputURL)
        )

        let elapsed = Date().timeIntervalSince(startTime)
        GraspLogger.inference.info("Inference complete in \(String(format: "%.2f", elapsed))s")

        return ExtractionResult.parse(from: raw)
    }

    // MARK: - CVPixelBuffer Helper

    /// Converts a CVPixelBuffer to UIImage using the shared, cached CIContext.
    static func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
