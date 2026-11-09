import SwiftUI

struct MixtureView: View {
    @State private var viewModel = MixtureViewModel()

    var body: some View {
        NavigationStack {
            content
                .background { AmbientBackground() }
                .navigationTitle("Mixture")
                .searchable(text: $viewModel.query, prompt: "Mixture, e.g. milk")
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(of: .search) { Task { await viewModel.search() } }
                .navigationDestination(for: MixtureComponent.self) { component in
                    SubstanceLoaderView(name: component.displayName, qid: component.qid)
                }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.state {
        case .idle:
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    HeroHeader(
                        systemImage: "flask",
                        title: "What is it made of?",
                        subtitle: "Explore the components of a mixture using the “has part” relation in Wikidata."
                    )
                    SuggestionChips(title: "Try one of these", items: viewModel.suggestions) { name in
                        Task { await viewModel.search(name) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        case .loading:
            LoadingView()
        case .failed(let message):
            ErrorView(message: message) { Task { await viewModel.search() } }
        case .loaded(let response):
            if response.components.isEmpty {
                ContentUnavailableView(
                    "No components found",
                    systemImage: "flask",
                    description: Text(response.error ?? "Wikidata doesn't list components for “\(response.mixture)”.")
                )
            } else {
                components(response)
            }
        }
    }

    private func components(_ response: MixtureResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(response.mixture.capitalized) contains")
                    .font(.title2.bold())
                    .padding(.leading, 4)

                ForEach(Array(response.components.enumerated()), id: \.element.id) { index, component in
                    NavigationLink(value: component) {
                        ComponentRow(name: component.displayName)
                    }
                    .buttonStyle(.plain)
                }

                if let qid = response.resolvedQid {
                    Text("Wikidata \(qid) · tap a component to see its profile")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }
}

/// One mixture component as a tappable glass row.
private struct ComponentRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "circle.hexagongrid")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 38, height: 38)
                .background(.tint.opacity(0.14), in: .circle)
            Text(name)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: 22, interactive: true)
        .contentShape(.rect(cornerRadius: 22))
    }
}

#Preview {
    MixtureView()
}
