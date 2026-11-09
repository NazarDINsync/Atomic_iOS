import Foundation

/// Access to the Chemistry API (Wikidata + Rhea open linked data).
protocol ChemistryServicing {
    func chemicalProperties(of substance: String) async throws -> ChemicalPropertiesResponse
    func physicalProperties(of substance: String) async throws -> PhysicalPropertiesResponse
    func kind(of substance: String) async throws -> SubstanceKindResponse
    func reactions(between substance: String, and other: String) async throws -> ReactionResponse
    func components(of mixture: String) async throws -> MixtureResponse
    /// Returns normally when the API answers at all.
    func ping() async throws
}

/// Live implementation that talks to the FastAPI backend.
struct ChemistryService: ChemistryServicing {
    var client = APIClient()
    var baseURL: () -> String = { ServerConfig.chemistryBaseURL }

    func chemicalProperties(of substance: String) async throws -> ChemicalPropertiesResponse {
        try await client.get(baseURL: baseURL(), path: "/api/v1/ask/chemical-properties", query: ["substance": substance])
    }

    func physicalProperties(of substance: String) async throws -> PhysicalPropertiesResponse {
        try await client.get(baseURL: baseURL(), path: "/api/v1/ask/physical-properties", query: ["substance": substance])
    }

    func kind(of substance: String) async throws -> SubstanceKindResponse {
        try await client.get(baseURL: baseURL(), path: "/api/v1/ask/substance-kind", query: ["substance": substance])
    }

    func reactions(between substance: String, and other: String) async throws -> ReactionResponse {
        try await client.get(
            baseURL: baseURL(),
            path: "/api/v1/ask/reaction",
            query: ["substance": substance, "other_substance": other]
        )
    }

    func components(of mixture: String) async throws -> MixtureResponse {
        try await client.get(baseURL: baseURL(), path: "/api/v1/ask/mixture-components", query: ["mixture": mixture])
    }

    func ping() async throws {
        struct OpenAPI: Decodable { let openapi: String }
        let _: OpenAPI = try await client.get(baseURL: baseURL(), path: "/openapi.json", timeout: 10)
    }
}
