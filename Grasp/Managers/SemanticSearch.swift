import NaturalLanguage

/// Two-phase search: exact text match, then NLEmbedding
/// word-similarity fallback for semantic queries like
/// "Hardware store" → "Home Depot" (via category proximity).
nonisolated enum SemanticSearch {

    static func filter(
        _ entities: [CapturedEntity],
        query: String
    ) -> [CapturedEntity] {
        guard !query.isEmpty else { return entities }

        // Phase 1 — substring match across all searchable fields
        let textHits = entities.filter { matches($0, query: query) }
        if !textHits.isEmpty { return textHits }

        // Phase 2 — semantic word-level similarity
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
            return []
        }
        let queryWords = tokenize(query)
        return entities.filter { entity in
            let words = tokenize(searchableText(for: entity))
            return queryWords.contains { q in
                words.contains { w in
                    embedding.distance(between: q, and: w) < 1.0
                }
            }
        }
    }

    // MARK: - Private

    private static func matches(
        _ entity: CapturedEntity,
        query: String
    ) -> Bool {
        let fields = [
            entity.title, entity.category,
            entity.summary, entity.extractedText,
        ] + entity.keyEntities
        return fields.contains {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    private static func searchableText(
        for entity: CapturedEntity
    ) -> String {
        ([entity.title, entity.category, entity.summary]
            + entity.keyEntities).joined(separator: " ")
    }

    private static func tokenize(_ text: String) -> [String] {
        let tok = NLTokenizer(unit: .word)
        tok.string = text
        return tok.tokens(for: text.startIndex..<text.endIndex)
            .map { String(text[$0]).lowercased() }
    }
}
