import Foundation
import Observation

/// Finds Rhea reactions that involve two substances.
@Observable
final class ReactionViewModel {
    var first = ""
    var second = ""
    private(set) var state: LoadState<ReactionResponse> = .idle

    /// Example pairs shown before the first search.
    // Pairs that share at least one Rhea reaction, so the result is never empty.
    let examples: [(String, String)] = [
        ("NAD+", "NADH"),
        ("ATP", "ADP"),
        ("NADP+", "NADPH"),
        ("acetyl-CoA", "coenzyme A"),
        ("L-glutamic acid", "2-oxoglutaric acid"),
    ]

    private let service: ChemistryServicing

    init(service: ChemistryServicing = ChemistryService()) {
        self.service = service
    }

    var canSearch: Bool {
        !first.trimmingCharacters(in: .whitespaces).isEmpty && !second.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Swaps the two input fields.
    func swap() {
        (first, second) = (second, first)
    }

    /// Runs the reaction query for the two current inputs.
    func search() async {
        guard canSearch else { return }
        state = .loading
        do {
            state = .loaded(try await service.reactions(
                between: first.trimmingCharacters(in: .whitespaces),
                and: second.trimmingCharacters(in: .whitespaces)
            ))
        } catch {
            state = .failed(error.userMessage)
        }
    }
}

extension ReactionResponse {
    /// A short, human-friendly explanation of `status`.
    var statusTitle: String {
        switch status {
        case "shared_reactions_found": "\(reactions.count) shared reaction\(reactions.count == 1 ? "" : "s") found"
        case "no_shared_reactions": "No reaction lists both substances"
        case "no_rhea_reactions_for_one_or_both": "Rhea has no reactions for one or both"
        default: status
        }
    }

    /// Whether the search found at least one shared reaction.
    var isSuccess: Bool { status == "shared_reactions_found" }
}
