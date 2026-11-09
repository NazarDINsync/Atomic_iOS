import SwiftUI

struct SubstanceSearchView: View {
    @State private var viewModel = SubstanceViewModel()

    var body: some View {
        NavigationStack {
            content
                .background { AmbientBackground() }
                .navigationTitle("Substance")
                .searchable(text: $viewModel.query, prompt: "Name or QID, e.g. caffeine")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(of: .search) { Task { await viewModel.search() } }
        }
        #if DEBUG
        // Launch with `-demoSubstance caffeine` to open a profile immediately (handy for screenshots).
        .task {
            if let demo = UserDefaults.standard.string(forKey: "demoSubstance") {
                await viewModel.load(name: demo, qid: nil)
            }
        }
        #endif
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .idle:
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HeroHeader(
                        systemImage: "atom",
                        title: "Look up any substance",
                        subtitle: "Formula, identifiers, physical properties and classification, live from Wikidata."
                    )
                    SuggestionChips(title: "Try one of these", items: viewModel.suggestions) { name in
                        Task { await viewModel.load(name: name, qid: nil) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        case .loading:
            LoadingView()
        case .loaded(let profile):
            SubstanceProfileView(profile: profile)
        case .failed(let message):
            ErrorView(message: message) { Task { await viewModel.search() } }
        }
    }
}

/// Loads and shows a substance pushed from another screen (e.g. a mixture component).
struct SubstanceLoaderView: View {
    let name: String
    let qid: String?
    @State private var viewModel = SubstanceViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading: LoadingView()
            case .loaded(let profile): SubstanceProfileView(profile: profile)
            case .failed(let message): ErrorView(message: message) { Task { await viewModel.load(name: name, qid: qid) } }
            }
        }
        .background { AmbientBackground() }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load(name: name, qid: qid) }
    }
}

/// The profile for one substance, laid out as a stack of glass cards.
struct SubstanceProfileView: View {
    let profile: SubstanceProfile

    var body: some View {
        if profile.isEmpty {
            ContentUnavailableView(
                "No data for “\(profile.name)”",
                systemImage: "magnifyingglass",
                description: Text("Wikidata matches exact English names. Try a lowercase name like “ethanol” or a QID like “Q283”.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if hasPhysical { physicalGrid }
                    if !profile.instanceOf.isEmpty || !profile.subclassOf.isEmpty {
                        classification
                    }
                    if !identifiers.isEmpty { identifiersCard }
                    if !links.isEmpty { linksCard }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let qid = profile.qid {
                Text("Wikidata \(qid)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(profile.name.capitalized)
                .font(.largeTitle.bold())
            if let formula = profile.formula {
                Text(formula)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .glassCard(in: Capsule(), tint: Color.accentColor.opacity(0.18))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Properties

    private var hasPhysical: Bool {
        [profile.meltingPoint, profile.boilingPoint, profile.density, profile.molarMass].contains { $0 != nil }
    }

    private var physicalGrid: some View {
        let tiles: [(String, String?, String)] = [
            ("Melting point", profile.meltingPoint, "thermometer.snowflake"),
            ("Boiling point", profile.boilingPoint, "thermometer.sun"),
            ("Density", profile.density, "scalemass"),
            ("Mass", profile.molarMass, "atom"),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                PropertyTile(title: tile.0, value: tile.1, icon: tile.2)
            }
        }
    }

    // MARK: Classification

    private var classification: some View {
        GlassSection("What it is") {
            if !profile.instanceOf.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instance of").font(.caption).foregroundStyle(.secondary)
                    FlowLayout { ForEach(profile.instanceOf, id: \.self) { TagView(text: $0) } }
                }
            }
            if !profile.instanceOf.isEmpty && !profile.subclassOf.isEmpty { GlassDivider() }
            if !profile.subclassOf.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subclass of").font(.caption).foregroundStyle(.secondary)
                    FlowLayout { ForEach(profile.subclassOf, id: \.self) { TagView(text: $0, tint: .purple) } }
                }
            }
        }
    }

    // MARK: Identifiers

    private var identifiers: [(title: String, value: String)] {
        let all: [(String, String?)] = [
            ("CAS number", profile.casNumber),
            ("PubChem CID", profile.pubchemCID),
            ("ChEBI", profile.chebiID.map { "CHEBI:\($0)" }),
            ("InChIKey", profile.inchiKey),
            ("SMILES", profile.smiles),
        ]
        return all.compactMap { title, value in value.map { (title, $0) } }
    }

    private var identifiersCard: some View {
        GlassSection("Identifiers") {
            ForEach(Array(identifiers.enumerated()), id: \.offset) { index, row in
                if index > 0 { GlassDivider() }
                LabeledContent(row.title) {
                    Text(row.value)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    // MARK: Links

    private var links: [(title: String, url: URL)] {
        var result: [(String, URL)] = []
        if let url = profile.wikidataURL { result.append(("Open in Wikidata", url)) }
        if let url = profile.pubchemURL { result.append(("Open in PubChem", url)) }
        if let url = profile.chebiURL { result.append(("Open in ChEBI", url)) }
        return result
    }

    private var linksCard: some View {
        GlassSection("Sources") {
            ForEach(Array(links.enumerated()), id: \.offset) { index, link in
                if index > 0 { GlassDivider() }
                Link(destination: link.url) {
                    HStack {
                        Text(link.title)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(.rect)
                }
            }
        }
    }
}

/// A glass tile for one physical quantity.
private struct PropertyTile: View {
    let title: String
    let value: String?
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(.tint.opacity(0.14), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(value ?? "—")
                    .font(.headline)
                    .foregroundStyle(value == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SubstanceProfileView(profile: SubstanceProfile(
        name: "caffeine", qid: "Q60235", formula: "C₈H₁₀N₄O₂", smiles: "CN1C=NC2=C1C(=O)N(C(=O)N2C)C",
        inchiKey: "RYYVLZVUVIJVGH-UHFFFAOYSA-N", casNumber: "58-08-2", pubchemCID: "2519", chebiID: "27732",
        molarMass: "194.08 Da", density: "1.23 g/cm³", meltingPoint: "235 °C", boilingPoint: "178 °C",
        instanceOf: ["type of chemical entity"], subclassOf: ["methylxanthine"]
    ))
    .background { AmbientBackground() }
}
