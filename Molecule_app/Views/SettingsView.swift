import SwiftUI

struct SettingsView: View {
    @AppStorage(ServerConfig.chemistryKey) private var chemistryURL = ServerConfig.defaultChemistryURL
    @AppStorage(ServerConfig.llmKey) private var llmURL = ServerConfig.defaultLLMURL
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://127.0.0.1:8001", text: $chemistryURL)
                        .keyboardType(.URL)
                    StatusRow(status: viewModel.chemistryStatus)
                } header: {
                    Text("Chemistry API")
                } footer: {
                    Text("Wikidata + Rhea knowledge-graph API (port 8001).")
                }
                .listRowBackground(GlassRowBackground())

                Section {
                    TextField("http://127.0.0.1:3001", text: $llmURL)
                        .keyboardType(.URL)
                    StatusRow(status: viewModel.llmStatus)
                } header: {
                    Text("Assistant (LLM service)")
                } footer: {
                    Text("On a real iPhone, use your Mac's local IP address, e.g. http://192.168.1.20:8001.")
                }
                .listRowBackground(GlassRowBackground())

                Section {
                    Button("Test connection") { Task { await viewModel.testConnections() } }
                    Button("Reset to defaults", role: .destructive) {
                        chemistryURL = ServerConfig.defaultChemistryURL
                        llmURL = ServerConfig.defaultLLMURL
                    }
                }
                .listRowBackground(GlassRowBackground())

                Section {
                    VStack(spacing: 10) {
                        AtomMark(size: 48)
                        Text("Molecule").font(.headline)
                        Text("Open chemistry data from Wikidata and Rhea")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background { AmbientBackground() }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Settings")
        }
    }
}

/// A translucent row background that lets the ambient backdrop show through.
private struct GlassRowBackground: View {
    var body: some View {
        Rectangle().fill(.thinMaterial)
    }
}

/// Shows the result of a connection check.
private struct StatusRow: View {
    let status: SettingsViewModel.ConnectionStatus

    var body: some View {
        content
    }

    @ViewBuilder private var content: some View {
        switch status {
        case .unknown:
            EmptyView()
        case .checking:
            HStack { ProgressView(); Text("Checking…").foregroundStyle(.secondary) }
        case .ok:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }
}

#Preview {
    SettingsView()
}
