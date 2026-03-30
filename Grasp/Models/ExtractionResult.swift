import Foundation

/// Structured output parsed from the VLM JSON response.
/// Fully `Sendable` so it can safely cross actor boundaries.
/// `nonisolated` opts out of the project-wide MainActor default
/// so `parse(from:)` can be called from any actor.
nonisolated struct ExtractionResult: Sendable {

    let title: String
    let category: String
    let summary: String
    let keyEntities: [String]
    let rawJSON: String

    // MARK: - Resilient Parsing

    /// Best-effort parse of VLM output.  Strips rogue markdown
    /// code fences, tries `Codable` decode, then falls back to
    /// manual dictionary extraction, and finally to "Uncategorized".
    static func parse(from json: String) -> ExtractionResult {
        let cleaned = json
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Fast path: full Codable decode
        if let data = cleaned.data(using: .utf8),
           let dto = try? JSONDecoder().decode(DTO.self, from: data) {
            return ExtractionResult(
                title: dto.title ?? "Untitled",
                category: Self.validCategory(dto.category),
                summary: dto.summary ?? "",
                keyEntities: dto.key_entities ?? dto.keyEntities ?? [],
                rawJSON: json
            )
        }

        // Slow path: manual dictionary extraction
        if let data = cleaned.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let entities: [String] = {
                if let a = dict["key_entities"] as? [String] { return a }
                if let a = dict["keyEntities"] as? [String] { return a }
                return []
            }()
            return ExtractionResult(
                title: dict["title"] as? String ?? "Untitled",
                category: Self.validCategory(dict["category"] as? String),
                summary: dict["summary"] as? String ?? "",
                keyEntities: entities,
                rawJSON: json
            )
        }

        // Fallback: treat the whole response as a summary
        return ExtractionResult(
            title: "Uncategorized Capture",
            category: "Object",
            summary: String(cleaned.prefix(200)),
            keyEntities: [],
            rawJSON: json
        )
    }

    // MARK: - Helpers

    private static let allowedCategories: Set<String> = [
        "Receipt", "Document", "Object", "Note",
    ]

    /// Clamps the category to the allowed set.
    private static func validCategory(_ raw: String?) -> String {
        guard let raw, allowedCategories.contains(raw) else { return "Object" }
        return raw
    }

    /// Private Codable DTO with all-optional fields for maximum
    /// resilience against inconsistent VLM output.
    private struct DTO: Codable {
        let title: String?
        let category: String?
        let summary: String?
        let key_entities: [String]?
        let keyEntities: [String]?
    }
}
