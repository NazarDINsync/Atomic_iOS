import Foundation

/// A clean, display-ready summary of a substance built from the three raw API responses.
struct SubstanceProfile: Hashable {
    var name: String
    var qid: String?

    var formula: String?
    var smiles: String?
    var inchiKey: String?
    var casNumber: String?
    var pubchemCID: String?
    var chebiID: String?

    var molarMass: String?
    var density: String?
    var meltingPoint: String?
    var boilingPoint: String?

    var instanceOf: [String] = []
    var subclassOf: [String] = []

    /// `true` when Wikidata returned nothing useful for the substance.
    var isEmpty: Bool {
        formula == nil && molarMass == nil && meltingPoint == nil && boilingPoint == nil
            && density == nil && instanceOf.isEmpty && subclassOf.isEmpty && casNumber == nil
    }

    var wikidataURL: URL? { qid.flatMap(WikidataID.pageURL(for:)) }
    var pubchemURL: URL? { pubchemCID.flatMap { URL(string: "https://pubchem.ncbi.nlm.nih.gov/compound/\($0)") } }
    var chebiURL: URL? { chebiID.flatMap { URL(string: "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=CHEBI:\($0)") } }
}

extension SubstanceProfile {
    /// Builds a profile from raw API rows.
    ///
    /// Label-based queries can match several Wikidata items (e.g. "caffeine" also matches
    /// a piece of software), so we pick the entity with the most chemical data and
    /// ignore rows that belong to other entities.
    static func make(
        name: String,
        chemical: [ChemicalPropertyRow],
        physical: [PhysicalPropertyRow],
        kinds: [KindRow]
    ) -> SubstanceProfile {
        let chemical = chemical.filter { $0.error == nil }
        let physical = physical.filter { $0.error == nil }
        let kinds = kinds.filter { $0.error == nil }

        let primary = mostFrequent(chemical.compactMap(\.entity))
            ?? mostFrequent(physical.compactMap(\.entity))
            ?? kinds.first?.entity

        let chem = chemical.filter { $0.entity == primary }
        let phys = physical.filter { $0.entity == primary }
        let kind = kinds.filter { $0.entity == primary }

        func text(_ key: String) -> String? {
            chem.first { $0.property == key }?.value
        }
        func measurement(_ key: String) -> String? {
            let fromChem = chem.filter { $0.property == key }.map { ($0.value, $0.unitName) }
            let fromPhys = phys.filter { $0.property == key }.map { ($0.amount, $0.unitName) }
            return Formatting.bestMeasurement(fromChem + fromPhys)
        }

        var profile = SubstanceProfile(name: name, qid: WikidataID.qid(from: primary))
        profile.formula = text("chemical_formula")
        profile.smiles = text("canonical_smiles")
        profile.inchiKey = text("inchi_key")
        profile.casNumber = text("cas_registry_number")
        profile.pubchemCID = text("pubchem_cid")
        profile.chebiID = text("chebi_id")
        profile.molarMass = measurement("mass")
        profile.density = measurement("density")
        profile.meltingPoint = measurement("melting_point")
        profile.boilingPoint = measurement("boiling_point")
        profile.instanceOf = unique(kind.filter { $0.relation == "instance of" }.compactMap(\.typeLabel))
        profile.subclassOf = unique(kind.filter { $0.relation == "subclass of" }.compactMap(\.typeLabel))
        return profile
    }

    private static func mostFrequent(_ values: [String]) -> String? {
        Dictionary(grouping: values, by: { $0 }).max { $0.value.count < $1.value.count }?.key
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

/// Number and unit formatting for Wikidata quantities.
enum Formatting {
    /// Short symbols for the unit names Wikidata commonly uses.
    static let unitSymbols: [String: String] = [
        "degree Celsius": "°C",
        "kelvin": "K",
        "degree Fahrenheit": "°F",
        "gram per cubic centimetre": "g/cm³",
        "kilogram per cubic metre": "kg/m³",
        "gram per litre": "g/L",
        "gram per millilitre": "g/mL",
        "dalton": "Da",
        "gram per mole": "g/mol",
        "atomic mass unit": "u",
    ]

    /// Picks the most readable value: prefers Celsius for temperatures, otherwise the first one.
    static func bestMeasurement(_ values: [(String?, String?)]) -> String? {
        let valid = values.compactMap { value, unit in value.map { ($0, unit) } }
        guard !valid.isEmpty else { return nil }
        let chosen = valid.first { $0.1 == "degree Celsius" } ?? valid[0]
        return format(value: chosen.0, unitName: chosen.1)
    }

    /// Formats `"99.9839"` + `"degree Celsius"` as `"99.98 °C"`.
    static func format(value: String, unitName: String?) -> String {
        let number = Double(value).map { $0.formatted(.number.precision(.fractionLength(0...2))) } ?? value
        guard let unitName, unitName != "1" else { return number }
        return "\(number) \(unitSymbols[unitName] ?? unitName)"
    }
}
