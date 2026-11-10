import Foundation
import Testing
@testable import Molecule_app

// MARK: - Wikidata identifiers

struct WikidataIDTests {
    @Test func extractsQIDFromEntityURI() {
        #expect(WikidataID.qid(from: "http://www.wikidata.org/entity/Q283") == "Q283")
    }

    @Test func rejectsNonQIDsAndNil() {
        #expect(WikidataID.qid(from: "http://www.wikidata.org/entity/P31") == nil)
        #expect(WikidataID.qid(from: nil) == nil)
        #expect(WikidataID.qid(from: "") == nil)
    }

    @Test func buildsPageURL() {
        #expect(WikidataID.pageURL(for: "Q283")?.absoluteString == "https://www.wikidata.org/wiki/Q283")
    }
}

// MARK: - Number and unit formatting

struct FormattingTests {
    @Test func appendsUnitSymbol() {
        #expect(Formatting.format(value: "235", unitName: "degree Celsius") == "235 °C")
        #expect(Formatting.format(value: "180", unitName: "kelvin") == "180 K")
    }

    @Test func roundsToTwoDecimals() {
        let expected = 99.98.formatted(.number.precision(.fractionLength(0...2)))
        #expect(Formatting.format(value: "99.9839", unitName: "degree Celsius") == "\(expected) °C")
    }

    @Test func omitsMissingAndDimensionlessUnits() {
        #expect(Formatting.format(value: "7", unitName: nil) == "7")
        #expect(Formatting.format(value: "7", unitName: "1") == "7")
    }

    @Test func keepsUnknownUnitNamesAndNonNumericValues() {
        #expect(Formatting.format(value: "12", unitName: "furlong") == "12 furlong")
        #expect(Formatting.format(value: "about ten", unitName: nil) == "about ten")
    }

    @Test func prefersCelsiusOverOtherUnits() {
        let best = Formatting.bestMeasurement([("508", "kelvin"), ("235", "degree Celsius")])
        #expect(best == "235 °C")
    }

    @Test func fallsBackToFirstValueWithoutCelsius() {
        #expect(Formatting.bestMeasurement([("508", "kelvin"), ("400", "degree Fahrenheit")]) == "508 K")
    }

    @Test func returnsNilWhenThereIsNoValue() {
        #expect(Formatting.bestMeasurement([]) == nil)
        #expect(Formatting.bestMeasurement([(nil, "kelvin")]) == nil)
    }
}

// MARK: - Substance profile

struct SubstanceProfileTests {
    @Test func mapsChemicalPhysicalAndKindRows() {
        let profile = SubstanceProfile.make(
            name: "caffeine",
            chemical: [
                chemRow("chemical_formula", "C8H10N4O2"),
                chemRow("canonical_smiles", "CN1C=NC2=C1C(=O)N(C(=O)N2C)C"),
                chemRow("inchi_key", "RYYVLZVUVIJVGH-UHFFFAOYSA-N"),
                chemRow("cas_registry_number", "58-08-2"),
                chemRow("pubchem_cid", "2519"),
                chemRow("chebi_id", "27732"),
            ],
            physical: [
                physRow("density", "1.23", unitName: "gram per cubic centimetre"),
                physRow("melting_point", "235", unitName: "degree Celsius"),
                physRow("boiling_point", "178", unitName: "degree Celsius"),
                physRow("mass", "194", unitName: "dalton"),
            ],
            kinds: [
                kindRow("instance of", "type of chemical entity"),
                kindRow("subclass of", "methylxanthine"),
            ]
        )

        #expect(profile.qid == "Q60235")
        #expect(profile.formula == "C8H10N4O2")
        #expect(profile.casNumber == "58-08-2")
        #expect(profile.pubchemCID == "2519")
        #expect(profile.chebiID == "27732")
        #expect(profile.meltingPoint == "235 °C")
        #expect(profile.boilingPoint == "178 °C")
        #expect(profile.molarMass == "194 Da")
        #expect(profile.instanceOf == ["type of chemical entity"])
        #expect(profile.subclassOf == ["methylxanthine"])
        #expect(!profile.isEmpty)
    }

    @Test func keepsOnlyTheEntityWithTheMostChemicalData() {
        // "caffeine" can also match unrelated Wikidata items; their rows must be ignored.
        let profile = SubstanceProfile.make(
            name: "caffeine",
            chemical: [
                chemRow("chemical_formula", "C8H10N4O2"),
                chemRow("cas_registry_number", "58-08-2"),
                chemRow("chemical_formula", "WRONG", entity: otherEntity),
            ],
            physical: [physRow("melting_point", "1", unitName: "degree Celsius", entity: otherEntity)],
            kinds: [kindRow("instance of", "software", entity: otherEntity)]
        )

        #expect(profile.qid == "Q60235")
        #expect(profile.formula == "C8H10N4O2")
        #expect(profile.meltingPoint == nil)
        #expect(profile.instanceOf.isEmpty)
    }

    @Test func ignoresRowsThatCarryAnError() {
        let failed = ChemicalPropertyRow(entity: caffeineEntity, property: "chemical_formula", value: "X", unit: nil, unitName: nil, error: "SPARQL failed")
        let profile = SubstanceProfile.make(name: "caffeine", chemical: [failed], physical: [], kinds: [])
        #expect(profile.formula == nil)
        #expect(profile.isEmpty)
    }

    @Test func removesDuplicateTags() {
        let profile = SubstanceProfile.make(
            name: "caffeine",
            chemical: [chemRow("chemical_formula", "C8H10N4O2")],
            physical: [],
            kinds: [kindRow("instance of", "drug"), kindRow("instance of", "drug"), kindRow("instance of", "alkaloid")]
        )
        #expect(profile.instanceOf == ["drug", "alkaloid"])
    }

    @Test func prefersCelsiusWhenSeveralMeltingPointsExist() {
        let profile = SubstanceProfile.make(
            name: "caffeine",
            chemical: [chemRow("chemical_formula", "C8H10N4O2")],
            physical: [
                physRow("melting_point", "508", unitName: "kelvin"),
                physRow("melting_point", "235", unitName: "degree Celsius"),
            ],
            kinds: []
        )
        #expect(profile.meltingPoint == "235 °C")
    }

    @Test func emptyInputGivesAnEmptyProfile() {
        let profile = SubstanceProfile.make(name: "nothing", chemical: [], physical: [], kinds: [])
        #expect(profile.isEmpty)
        #expect(profile.qid == nil)
        #expect(profile.wikidataURL == nil)
    }

    @Test func buildsLinksFromIdentifiers() {
        var profile = SubstanceProfile(name: "caffeine", qid: "Q60235")
        profile.pubchemCID = "2519"
        profile.chebiID = "27732"
        #expect(profile.wikidataURL?.absoluteString == "https://www.wikidata.org/wiki/Q60235")
        #expect(profile.pubchemURL?.absoluteString == "https://pubchem.ncbi.nlm.nih.gov/compound/2519")
        #expect(profile.chebiURL?.absoluteString.hasSuffix("CHEBI:27732") == true)
    }
}

// MARK: - API model conveniences

struct APIModelTests {
    @Test func mixtureComponentUsesLabelThenQID() {
        let labelled = MixtureComponent(entity: "http://www.wikidata.org/entity/Q706", label: "calcium")
        let unlabelled = MixtureComponent(entity: "http://www.wikidata.org/entity/Q706", label: nil)
        #expect(labelled.displayName == "calcium")
        #expect(unlabelled.displayName == "Q706")
        #expect(unlabelled.qid == "Q706")
    }

    @Test func reactionStatusTitles() {
        func response(status: String, count: Int) -> ReactionResponse {
            ReactionResponse(
                status: status, resolvedQids: [],
                reactions: (0..<count).map { reaction("RHEA:\($0)") },
                individualReactions: [], message: nil
            )
        }
        #expect(response(status: "shared_reactions_found", count: 1).statusTitle == "1 shared reaction found")
        #expect(response(status: "shared_reactions_found", count: 3).statusTitle == "3 shared reactions found")
        #expect(response(status: "no_shared_reactions", count: 0).statusTitle == "No reaction lists both substances")
        #expect(response(status: "no_rhea_reactions_for_one_or_both", count: 0).statusTitle == "Rhea has no reactions for one or both")
        #expect(response(status: "something_new", count: 0).statusTitle == "something_new")
    }

    @Test func onlySharedReactionsCountAsSuccess() {
        let found = ReactionResponse(status: "shared_reactions_found", resolvedQids: [], reactions: [], individualReactions: [], message: nil)
        let none = ReactionResponse(status: "no_shared_reactions", resolvedQids: [], reactions: [], individualReactions: [], message: nil)
        #expect(found.isSuccess)
        #expect(!none.isSuccess)
    }
}

// MARK: - LaTeX → Unicode

struct ChemTextFormatterTests {
    @Test func convertsTextSubscripts() {
        #expect(ChemTextFormatter.format(#"$\text{C}_2\text{H}_6\text{O}$"#) == "C₂H₆O")
    }

    @Test func convertsMhchemEquations() {
        #expect(ChemTextFormatter.format(#"$\ce{2H2 + O2 -> 2H2O}$"#) == "2H₂ + O₂ → 2H₂O")
    }

    @Test func convertsDegreesAndIonCharges() {
        #expect(ChemTextFormatter.format(#"$78.29^\circ\text{C}$"#) == "78.29°C")
        #expect(ChemTextFormatter.format(#"$\text{SO}_4^{2-}$"#) == "SO₄²⁻")
    }

    @Test func convertsMarkupWithoutDelimiters() {
        #expect(ChemTextFormatter.format(#"Water is \text{H}_2\text{O}."#) == "Water is H₂O.")
    }

    @Test func leavesPlainTextAndPricesAlone() {
        #expect(ChemTextFormatter.format("It costs $5 and $10.") == "It costs $5 and $10.")
        #expect(ChemTextFormatter.format("Plain sentence.") == "Plain sentence.")
    }

    @Test func keepsSurroundingTextAroundMath() {
        let result = ChemTextFormatter.format(#"Glucose is $\text{C}_6\text{H}_{12}\text{O}_6$ in water."#)
        #expect(result == "Glucose is C₆H₁₂O₆ in water.")
    }

    @Test func mapsSubscriptAndSuperscriptCharacters() {
        #expect(ChemTextFormatter.toSubscript("H2SO4") == "H₂SO₄")
        #expect(ChemTextFormatter.toSuperscript("2-") == "²⁻")
        #expect(ChemTextFormatter.toSubscript("Q") == "Q")
    }
}
