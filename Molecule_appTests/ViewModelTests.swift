import Foundation
import Testing
@testable import Molecule_app

// MARK: - Substance

struct SubstanceViewModelTests {
    private func richService() -> MockChemistry {
        let service = MockChemistry()
        service.chemical = .success(.init(substance: "caffeine", properties: [chemRow("chemical_formula", "C8H10N4O2")]))
        service.physical = .success(.init(substance: "caffeine", properties: [physRow("melting_point", "235", unitName: "degree Celsius")]))
        service.kinds = .success(.init(substance: "caffeine", kinds: [kindRow("subclass of", "methylxanthine")]))
        return service
    }

    @Test func loadBuildsAProfile() async throws {
        let model = SubstanceViewModel(service: richService())
        await model.load(name: "caffeine", qid: nil)

        let profile = try #require(model.state.loadedValue)
        #expect(profile.formula == "C8H10N4O2")
        #expect(profile.meltingPoint == "235 °C")
        #expect(profile.subclassOf == ["methylxanthine"])
        #expect(model.query == "caffeine")
    }

    @Test func trimsTheNameAndIgnoresBlankOnes() async {
        let service = richService()
        let model = SubstanceViewModel(service: service)

        await model.load(name: "   ", qid: nil)
        #expect(model.state.isIdle)
        #expect(service.chemicalQueries.isEmpty)

        await model.load(name: "  caffeine \n", qid: nil)
        #expect(service.chemicalQueries == ["caffeine"])
    }

    @Test func prefersTheQIDWhereTheEndpointAllowsIt() async {
        let service = richService()
        let model = SubstanceViewModel(service: service)
        await model.load(name: "caffeine", qid: "Q60235")

        #expect(service.chemicalQueries == ["Q60235"])
        #expect(service.kindQueries == ["Q60235"])
        // physical-properties only understands English labels.
        #expect(service.physicalQueries == ["caffeine"])
    }

    @Test func failsOnlyWhenEveryRequestFails() async {
        let service = MockChemistry()
        service.chemical = .failure(TestError.boom)
        service.physical = .failure(TestError.boom)
        service.kinds = .failure(TestError.boom)
        let model = SubstanceViewModel(service: service)

        await model.load(name: "caffeine", qid: nil)
        #expect(model.state.failureMessage == "Boom")
    }

    @Test func partialFailureStillShowsWhatWasFound() async throws {
        let service = richService()
        service.physical = .failure(TestError.boom)
        let model = SubstanceViewModel(service: service)

        await model.load(name: "caffeine", qid: nil)
        let profile = try #require(model.state.loadedValue)
        #expect(profile.formula == "C8H10N4O2")
        #expect(profile.meltingPoint == nil)
    }

    @Test func exampleChipsAreUsable() {
        let model = SubstanceViewModel(service: MockChemistry())
        #expect(!model.suggestions.isEmpty)
        #expect(Set(model.suggestions).count == model.suggestions.count)
    }
}

// MARK: - Reaction

struct ReactionViewModelTests {
    private func response() -> ReactionResponse {
        ReactionResponse(
            status: "shared_reactions_found", resolvedQids: ["Q1", "Q2"],
            reactions: [reaction("RHEA:1")], individualReactions: [], message: nil
        )
    }

    @Test func needsBothSubstances() {
        let model = ReactionViewModel(service: MockChemistry())
        #expect(!model.canSearch)
        model.first = "ATP"
        #expect(!model.canSearch)
        model.second = "   "
        #expect(!model.canSearch)
        model.second = "ADP"
        #expect(model.canSearch)
    }

    @Test func swapExchangesTheFields() {
        let model = ReactionViewModel(service: MockChemistry())
        model.first = "ATP"
        model.second = "ADP"
        model.swap()
        #expect(model.first == "ADP")
        #expect(model.second == "ATP")
    }

    @Test func searchTrimsInputAndStoresTheResult() async throws {
        let service = MockChemistry()
        service.reactionResult = .success(response())
        let model = ReactionViewModel(service: service)
        model.first = "  NAD+ "
        model.second = "NADH  "

        await model.search()

        #expect(service.reactionQueries.count == 1)
        #expect(service.reactionQueries[0].0 == "NAD+")
        #expect(service.reactionQueries[0].1 == "NADH")
        #expect(try #require(model.state.loadedValue).reactions.count == 1)
    }

    @Test func searchDoesNothingWithoutBothInputs() async {
        let service = MockChemistry()
        let model = ReactionViewModel(service: service)
        model.first = "ATP"
        await model.search()
        #expect(service.reactionQueries.isEmpty)
        #expect(model.state.isIdle)
    }

    @Test func failureBecomesAnErrorState() async {
        let service = MockChemistry()
        service.reactionResult = .failure(TestError.boom)
        let model = ReactionViewModel(service: service)
        model.first = "ATP"
        model.second = "ADP"
        await model.search()
        #expect(model.state.failureMessage == "Boom")
    }

    @Test func examplesArePairsOfNonEmptyNames() {
        let model = ReactionViewModel(service: MockChemistry())
        #expect(!model.examples.isEmpty)
        #expect(model.examples.allSatisfy { !$0.0.isEmpty && !$0.1.isEmpty && $0.0 != $0.1 })
    }
}

// MARK: - Mixture

struct MixtureViewModelTests {
    private func response() -> MixtureResponse {
        MixtureResponse(
            mixture: "milk", status: "components_found", resolvedQid: "Q8495", error: nil,
            components: [MixtureComponent(entity: "http://www.wikidata.org/entity/Q706", label: "calcium")]
        )
    }

    @Test func searchUsesTheGivenNameAndUpdatesTheQuery() async throws {
        let service = MockChemistry()
        service.mixtureResult = .success(response())
        let model = MixtureViewModel(service: service)

        await model.search("milk")

        #expect(model.query == "milk")
        #expect(service.mixtureQueries == ["milk"])
        #expect(try #require(model.state.loadedValue).components.first?.displayName == "calcium")
    }

    @Test func searchFallsBackToTheTypedQuery() async {
        let service = MockChemistry()
        service.mixtureResult = .success(response())
        let model = MixtureViewModel(service: service)
        model.query = "  air "
        await model.search()
        #expect(service.mixtureQueries == ["air"])
    }

    @Test func blankQueryDoesNothing() async {
        let service = MockChemistry()
        let model = MixtureViewModel(service: service)
        model.query = "  "
        await model.search()
        #expect(service.mixtureQueries.isEmpty)
        #expect(model.state.isIdle)
    }

    @Test func failureBecomesAnErrorState() async {
        let service = MockChemistry()
        service.mixtureResult = .failure(TestError.boom)
        let model = MixtureViewModel(service: service)
        await model.search("milk")
        #expect(model.state.failureMessage == "Boom")
    }
}

// MARK: - Settings

struct SettingsViewModelTests {
    @Test func startsUnknown() {
        let model = SettingsViewModel(chemistry: MockChemistry(), chat: MockChat())
        #expect(model.chemistryStatus == .unknown)
        #expect(model.llmStatus == .unknown)
    }

    @Test func reportsBothServicesAsConnected() async {
        let model = SettingsViewModel(chemistry: MockChemistry(), chat: MockChat())
        await model.testConnections()
        #expect(model.chemistryStatus == .ok)
        #expect(model.llmStatus == .ok)
    }

    @Test func reportsEachFailureSeparately() async {
        let chemistry = MockChemistry()
        chemistry.pingResult = .failure(TestError.boom)
        let model = SettingsViewModel(chemistry: chemistry, chat: MockChat())

        await model.testConnections()
        #expect(model.chemistryStatus == .failed("Boom"))
        #expect(model.llmStatus == .ok)
    }
}
