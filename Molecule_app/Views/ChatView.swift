import SwiftUI

struct ChatView: View {
    @State private var viewModel = ChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.messages.isEmpty { emptyState }
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if viewModel.isSending {
                            TypingBubble()
                                .id("typing")
                        }
                    }
                    .padding()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) {
                    proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                }
                .onChange(of: viewModel.isSending) {
                    if viewModel.isSending { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
            .background { AmbientBackground() }
            .safeAreaInset(edge: .bottom) { inputBar }
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { statusDot }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New chat", systemImage: "square.and.pencil") {
                        viewModel.newConversation()
                    }
                    .disabled(viewModel.messages.isEmpty)
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: viewModel.messages.count)
            .task { await viewModel.checkHealth() }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 28) {
            HeroHeader(
                systemImage: "sparkles",
                title: "Ask about chemistry",
                subtitle: "The assistant looks up answers in Wikidata and Rhea for you."
            )
            VStack(spacing: 12) {
                ForEach(Array(viewModel.suggestions.enumerated()), id: \.element) { index, suggestion in
                    Button {
                        Task { await viewModel.send(suggestion) }
                    } label: {
                        HStack {
                            Text(suggestion)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity)
                        .glassCard(cornerRadius: 22, interactive: true)
                        .contentShape(.rect(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 8)
    }

    private var inputBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button {
                    sendDraft()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.circle)
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send")
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Takes the text out of the field and clears it immediately, then sends it.
    ///
    /// Clearing synchronously (not inside the async send) is what makes a multi-line
    /// `TextField` reliably empty itself when the button is tapped.
    private func sendDraft() {
        let text = viewModel.draft
        viewModel.draft = ""
        Task { await viewModel.send(text) }
    }

    private var statusDot: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(viewModel.isServiceOnline == true ? .green : viewModel.isServiceOnline == false ? .red : .gray)
                .frame(width: 8, height: 8)
            Text(viewModel.isServiceOnline == true ? "Online" : viewModel.isServiceOnline == false ? "Offline" : "…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
        .onTapGesture { Task { await viewModel.checkHealth() } }
    }
}

/// A glass chat bubble aligned by sender.
private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundStyle(message.role == .user ? .white : .primary)
                .glassCard(cornerRadius: 24, tint: tint)
            if message.role != .user { Spacer(minLength: 48) }
        }
    }

    /// Assistant replies are full Markdown; user and error messages are plain text.
    @ViewBuilder private var content: some View {
        if message.role == .assistant {
            MarkdownText(text: message.text)
        } else {
            Text(message.text).textSelection(.enabled)
        }
    }

    private var tint: Color? {
        switch message.role {
        case .user: Color.accentColor.opacity(0.9)
        case .assistant: nil
        case .error: Color.red.opacity(0.35)
        }
    }
}

/// Animated "assistant is thinking" bubble.
private struct TypingBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: 10) {
                AtomMark(size: 24)
                Text("Thinking…").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 24)
            Spacer()
        }
    }
}

#Preview {
    ChatView()
}
