import Foundation
import SwiftData

/// Persisted record of a single camera capture + VLM extraction.
///
/// Saved immediately on capture with `isProcessed = false`,
/// then updated asynchronously by `VLMInferenceActor` once
/// the on-device VLM finishes inference.
@Model
final class CapturedEntity {

    @Attribute(.unique) var id: UUID
    var title: String
    var category: String
    var summary: String
    var extractedText: String
    var keyEntities: [String]
    var date: Date
    var isProcessed: Bool

    /// JPEG thumbnail kept in external file-backed storage.
    @Attribute(.externalStorage) var thumbnail: Data

    init(
        id: UUID = UUID(),
        title: String = "Processing…",
        category: String = "Unknown",
        summary: String = "",
        extractedText: String = "",
        keyEntities: [String] = [],
        date: Date = .now,
        isProcessed: Bool = false,
        thumbnail: Data
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.summary = summary
        self.extractedText = extractedText
        self.keyEntities = keyEntities
        self.date = date
        self.isProcessed = isProcessed
        self.thumbnail = thumbnail
    }
}
