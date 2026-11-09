import Foundation
import Observation

/// Looks up what a mixture is made of.
@Observable
final class MixtureViewModel {
    var query = ""
    private(set) var state: LoadState<MixtureResponse> = .idle

    /// Quick examples shown before the first search.
    // Wikidata only lists components for some mixtures; these return the most.
    let suggestions = ["milk", "air", "bread", "beer", "coal", "bronze"]

    private let service: ChemistryServicing

    init(service: ChemistryServicing = ChemistryService()) {
        self.service = service
    }

    /// Searches the components of `name`, or of the current query when `name` is nil.
    func search(_ name: String? = nil) async {
        if let name { query = name }
        let mixture = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mixture.isEmpty else { return }
        state = .loading
        do {
            state = .loaded(try await service.components(of: mixture))
        } catch {
            state = .failed(error.userMessage)
        }
    }
}
