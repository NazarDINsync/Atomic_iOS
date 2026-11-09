import Foundation
import Observation

/// Loads a substance profile by combining three Chemistry API queries.
@Observable
final class SubstanceViewModel {
    var query = ""
    private(set) var state: LoadState<SubstanceProfile> = .idle

    /// Quick examples shown before the first search.
    // Chosen because Wikidata returns a complete profile for each of these.
    let suggestions = ["water", "glycerol", "benzene", "gold", "ethanol", "acetone"]

    private let service: ChemistryServicing

    init(service: ChemistryServicing = ChemistryService()) {
        self.service = service
    }

    /// Searches for the current `query`.
    func search() async {
        await load(name: query, qid: nil)
    }

    /// Loads a substance by name, optionally using a known QID for more precise lookups.
    ///
    /// `physical-properties` only accepts English labels, while the other two endpoints
    /// also accept QIDs, so the QID is used where possible.
    func load(name: String, qid: String?) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        query = name
        state = .loading

        let identifier = qid ?? name
        async let chemical = capture { try await service.chemicalProperties(of: identifier) }
        async let physical = capture { try await service.physicalProperties(of: name) }
        async let kinds = capture { try await service.kind(of: identifier) }
        let results = await (chemical, physical, kinds)

        // If every request failed there is nothing to show — report the first error.
        if case .failure(let error) = results.0, case .failure = results.1, case .failure = results.2 {
            state = .failed(error.userMessage)
            return
        }

        var profile = SubstanceProfile.make(
            name: name,
            chemical: (try? results.0.get().properties) ?? [],
            physical: (try? results.1.get().properties) ?? [],
            kinds: (try? results.2.get().kinds) ?? []
        )
        if profile.qid == nil { profile.qid = qid }
        state = .loaded(profile)
    }
}
