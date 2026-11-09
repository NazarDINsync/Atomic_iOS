import Foundation

// MARK: - Chemistry API responses
// These types mirror the JSON returned by the Chemistry API exactly.
// Keys are decoded with `.convertFromSnakeCase`, so `unit_name` becomes `unitName`.

/// One row of `/api/v1/ask/chemical-properties`.
struct ChemicalPropertyRow: Decodable, Hashable {
    let entity: String?
    let property: String?
    let value: String?
    let unit: String?
    let unitName: String?
    /// Present instead of the other fields when the SPARQL query failed.
    let error: String?
}

/// Response of `/api/v1/ask/chemical-properties`.
struct ChemicalPropertiesResponse: Decodable {
    let substance: String
    let properties: [ChemicalPropertyRow]
}

/// One row of `/api/v1/ask/physical-properties`.
struct PhysicalPropertyRow: Decodable, Hashable {
    let entity: String?
    let property: String?
    let amount: String?
    let unit: String?
    let unitName: String?
    let error: String?
}

/// Response of `/api/v1/ask/physical-properties`.
struct PhysicalPropertiesResponse: Decodable {
    let substance: String
    let properties: [PhysicalPropertyRow]
}

/// One "instance of" / "subclass of" row of `/api/v1/ask/substance-kind`.
struct KindRow: Decodable, Hashable {
    let entity: String?
    let relation: String?
    let type: String?
    let typeLabel: String?
    let error: String?
}

/// Response of `/api/v1/ask/substance-kind`.
struct SubstanceKindResponse: Decodable {
    let substance: String
    let kinds: [KindRow]
}

/// A Rhea reaction record.
struct Reaction: Decodable, Hashable, Identifiable {
    let rheaId: String
    let equation: String
    let participants: String
    let url: String

    var id: String { rheaId }
}

/// Reactions found for one of the two queried substances.
struct IndividualReactions: Decodable, Hashable {
    let input: String
    let qid: String
    let reactions: [Reaction]
}

/// Response of `/api/v1/ask/reaction`.
struct ReactionResponse: Decodable {
    let status: String
    let resolvedQids: [String]
    let reactions: [Reaction]
    let individualReactions: [IndividualReactions]
    let message: String?
}

/// A direct component of a mixture.
struct MixtureComponent: Decodable, Hashable, Identifiable {
    let entity: String
    let label: String?

    var id: String { entity }
    /// The Wikidata QID of the component, e.g. `Q283`.
    var qid: String? { WikidataID.qid(from: entity) }
    /// A readable name, falling back to the QID when Wikidata has no English label.
    var displayName: String { label ?? qid ?? entity }
}

/// Response of `/api/v1/ask/mixture-components`.
struct MixtureResponse: Decodable {
    let mixture: String
    let status: String
    let resolvedQid: String?
    let error: String?
    let components: [MixtureComponent]
}

// MARK: - LLM service

/// Body of `POST /llm/v1/chat`.
struct ChatRequestBody: Encodable {
    let message: String
    let conversationId: String
}

/// Response of `POST /llm/v1/chat`.
struct ChatResponseBody: Decodable {
    let response: String
    let conversationId: String
}

/// Response of `GET /llm/v1/health`.
struct HealthResponse: Decodable {
    let status: String
    let agentInitialized: Bool?
}

// MARK: - Helpers

/// Helpers for working with Wikidata identifiers.
nonisolated enum WikidataID {
    /// Extracts a QID such as `Q283` from an entity URI like `http://www.wikidata.org/entity/Q283`.
    static func qid(from uri: String?) -> String? {
        guard let last = uri?.split(separator: "/").last, last.hasPrefix("Q") else { return nil }
        return String(last)
    }

    /// The human-facing Wikidata page for a QID.
    static func pageURL(for qid: String) -> URL? {
        URL(string: "https://www.wikidata.org/wiki/\(qid)")
    }
}
