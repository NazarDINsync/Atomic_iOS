import SwiftUI

struct ReactionView: View {
    @State private var viewModel = ReactionViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    inputCard
                    results
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background { AmbientBackground() }
            .navigationTitle("Reaction")
        }
    }

    // MARK: Input

    private var inputCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    TextField("First substance", text: $viewModel.first)
                    GlassDivider()
                    TextField("Second substance", text: $viewModel.second)
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.search)
                .onSubmit { runSearch() }

                Button {
                    viewModel.swap()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .frame(width: 44, height: 44)
                        .background(.tint.opacity(0.14), in: .circle)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: viewModel.first)
                .accessibilityLabel("Swap substances")
            }

            Button(action: runSearch) {
                Text("Find reactions")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!viewModel.canSearch)

            Text("Searches Rhea, the expert-curated database of biochemical reactions.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .glassCard(cornerRadius: 28)
    }

    // MARK: Results

    @ViewBuilder private var results: some View {
        switch viewModel.state {
        case .idle:
            GlassSection("Examples") {
                ForEach(Array(viewModel.examples.enumerated()), id: \.offset) { index, pair in
                    if index > 0 { GlassDivider() }
                    Button {
                        viewModel.first = pair.0
                        viewModel.second = pair.1
                        runSearch()
                    } label: {
                        HStack {
                            Text("\(pair.0)  +  \(pair.1)")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .loading:
            LoadingView(message: "Searching Wikidata and Rhea…")
                .frame(height: 300)
        case .failed(let message):
            ErrorView(message: message, retry: runSearch)
        case .loaded(let response):
            ReactionResults(response: response)
        }
    }

    private func runSearch() {
        focused = false
        Task { await viewModel.search() }
    }
}

private struct ReactionResults: View {
    let response: ReactionResponse

    var body: some View {
        VStack(spacing: 24) {
            status

            if !response.reactions.isEmpty {
                GlassSection("Shared reactions") {
                    ForEach(Array(response.reactions.enumerated()), id: \.element.id) { index, reaction in
                        if index > 0 { GlassDivider() }
                        ReactionRow(reaction: reaction)
                    }
                }
            }

            GlassSection("Each substance on its own") {
                ForEach(Array(response.individualReactions.enumerated()), id: \.element.qid) { index, group in
                    if index > 0 { GlassDivider() }
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 0) {
                            if group.reactions.isEmpty {
                                Text("No reactions in Rhea").foregroundStyle(.secondary)
                            }
                            ForEach(Array(group.reactions.enumerated()), id: \.element.id) { i, reaction in
                                if i > 0 { GlassDivider() }
                                ReactionRow(reaction: reaction)
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        HStack {
                            Text(group.input).font(.body.weight(.medium))
                            Spacer()
                            Text("\(group.reactions.count)").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var status: some View {
        let tint: Color = response.isSuccess ? .green : .orange
        return HStack(alignment: .top, spacing: 14) {
            Image(systemName: response.isSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(response.statusTitle).font(.headline)
                if let message = response.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24, tint: tint.opacity(0.18))
    }
}

private struct ReactionRow: View {
    let reaction: Reaction

    var body: some View {
        if let url = URL(string: reaction.url) {
            Link(destination: url) { content }.foregroundStyle(.primary)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(reaction.equation).font(.callout)
                Text(reaction.rheaId).font(.caption).foregroundStyle(.tint)
            }
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

#Preview {
    ReactionView()
}
