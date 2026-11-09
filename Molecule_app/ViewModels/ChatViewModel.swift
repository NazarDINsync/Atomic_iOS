import Foundation
import Observation

/// A single message in the chat transcript.
struct ChatMessage: Identifiable, Hashable {
    enum Role { case user, assistant, error }

    let id = UUID()
    let role: Role
    let text: String
}

/// Drives the conversation with the LLM chemistry assistant.
@Observable
final class ChatViewModel {
    var draft = ""
    private(set) var messages: [ChatMessage] = []
    private(set) var isSending = false
    /// `nil` while unknown, then whether the LLM service answered its health check.
    private(set) var isServiceOnline: Bool?

    /// Starter prompts shown in an empty conversation.
    let suggestions = [
        "Tell me everything you know about glycerol: formula, physical properties, identifiers and classification.",
        "Compare ethanol and methanol: formula, melting point, boiling point and density.",
        "What are the physical and chemical properties of benzene?",
        "Which biochemical reactions involve both NAD+ and NADH?",
    ]

    /// The backend keeps context per conversation ID.
    private var conversationID = UUID().uuidString
    /// The request currently waiting for the assistant, so a new chat can cancel it.
    private var requestTask: Task<Void, Never>?
    private let service: ChatServicing

    init(service: ChatServicing = ChatService()) {
        self.service = service
    }

    var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Sends `text`, or the current draft when `text` is nil.
    func send(_ text: String? = nil) async {
        let message = (text ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !isSending else { return }
        draft = ""
        messages.append(ChatMessage(role: .user, text: message))
        isSending = true

        let conversation = conversationID
        let task = Task { await deliver(message, conversation: conversation) }
        requestTask = task
        await task.value
    }

    /// Performs the request and appends the outcome, unless the conversation was reset meanwhile.
    private func deliver(_ message: String, conversation: String) async {
        // Only the request that belongs to the current conversation may turn the indicator off.
        defer { if conversation == conversationID { isSending = false } }

        do {
            let reply = try await service.send(message, conversationID: conversation)
            // The model often writes formulas in LaTeX; show them as readable Unicode instead.
            append(ChatMessage(role: .assistant, text: ChemTextFormatter.format(reply)), for: conversation)
        } catch APIError.server(status: 502, _) {
            // The LLM service is up but its model backend (KoboldCpp) failed or isn't running.
            append(ChatMessage(role: .error, text: "The assistant couldn't generate an answer. Is KoboldCpp running with a model loaded?"), for: conversation)
        } catch {
            append(ChatMessage(role: .error, text: error.userMessage), for: conversation)
        }
    }

    /// Adds a message only if it still belongs to the current conversation and wasn't cancelled.
    private func append(_ message: ChatMessage, for conversation: String) {
        guard conversation == conversationID, !Task.isCancelled else { return }
        messages.append(message)
    }

    /// Cancels any request in flight, clears the transcript and starts a fresh backend conversation.
    func newConversation() {
        requestTask?.cancel()
        requestTask = nil
        isSending = false
        messages = []
        conversationID = UUID().uuidString
    }

    /// Checks whether the LLM service is reachable.
    func checkHealth() async {
        isServiceOnline = (try? await service.health())?.status == "ok"
    }
}
