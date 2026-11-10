import Foundation
import Testing
@testable import Molecule_app

struct ChatViewModelTests {
    @Test func cannotSendBlankDraft() {
        let model = ChatViewModel(service: MockChat())
        #expect(!model.canSend)
        model.draft = "   \n "
        #expect(!model.canSend)
        model.draft = "hello"
        #expect(model.canSend)
    }

    @Test func sendAddsUserAndAssistantMessagesAndClearsDraft() async {
        let chat = MockChat()
        chat.reply = .success("Water is wet.")
        let model = ChatViewModel(service: chat)
        model.draft = "  What is water?  "

        await model.send()

        #expect(model.draft.isEmpty)
        #expect(model.messages.map(\.role) == [.user, .assistant])
        #expect(model.messages.first?.text == "What is water?")
        #expect(model.messages.last?.text == "Water is wet.")
        #expect(!model.isSending)
        #expect(chat.sent.first?.message == "What is water?")
    }

    @Test func sendingExplicitTextLeavesTheDraftAlone() async {
        let model = ChatViewModel(service: MockChat())
        model.draft = "typing something else"
        await model.send("Compare ethanol and methanol")
        #expect(model.draft == "typing something else")
        #expect(model.messages.first?.text == "Compare ethanol and methanol")
    }

    @Test func blankMessagesAreIgnored() async {
        let chat = MockChat()
        let model = ChatViewModel(service: chat)
        await model.send("   ")
        #expect(model.messages.isEmpty)
        #expect(chat.sent.isEmpty)
    }

    @Test func formatsLatexInReplies() async {
        let chat = MockChat()
        chat.reply = .success(#"Ethanol is $\text{C}_2\text{H}_6\text{O}$."#)
        let model = ChatViewModel(service: chat)
        await model.send("formula of ethanol?")
        #expect(model.messages.last?.text == "Ethanol is C₂H₆O.")
    }

    @Test func gatewayErrorMentionsKoboldCpp() async {
        let chat = MockChat()
        chat.reply = .failure(APIError.server(status: 502, message: "agent failed"))
        let model = ChatViewModel(service: chat)
        await model.send("hi")
        #expect(model.messages.last?.role == .error)
        #expect(model.messages.last?.text.contains("KoboldCpp") == true)
        #expect(!model.isSending)
    }

    @Test func otherErrorsShowTheirOwnMessage() async {
        let chat = MockChat()
        chat.reply = .failure(TestError.boom)
        let model = ChatViewModel(service: chat)
        await model.send("hi")
        #expect(model.messages.last?.role == .error)
        #expect(model.messages.last?.text == "Boom")
    }

    @Test func keepsTheSameConversationUntilReset() async {
        let chat = MockChat()
        let model = ChatViewModel(service: chat)
        await model.send("one")
        await model.send("two")
        #expect(chat.sent[0].conversationID == chat.sent[1].conversationID)

        model.newConversation()
        await model.send("three")
        #expect(chat.sent[2].conversationID != chat.sent[0].conversationID)
    }

    @Test func newConversationClearsTheTranscript() async {
        let model = ChatViewModel(service: MockChat())
        await model.send("hi")
        #expect(!model.messages.isEmpty)
        model.newConversation()
        #expect(model.messages.isEmpty)
    }

    @Test func newConversationCancelsThePendingRequest() async {
        let chat = GatedChat()
        let model = ChatViewModel(service: chat)

        let sending = Task { await model.send("slow question") }
        await waitUntil(chat.waitingCount == 1)
        #expect(model.isSending)

        model.newConversation()
        #expect(!model.isSending, "the thinking indicator must disappear immediately")
        #expect(model.messages.isEmpty)

        // The model finally answers the old question: it must not show up in the new chat.
        chat.releaseOldest(with: "stale answer")
        await sending.value
        #expect(model.messages.isEmpty)
        #expect(!model.isSending)
    }

    @Test func aStaleReplyDoesNotStopTheNewRequestsIndicator() async {
        let chat = GatedChat()
        let model = ChatViewModel(service: chat)

        let first = Task { await model.send("old question") }
        await waitUntil(chat.waitingCount == 1)
        model.newConversation()

        let second = Task { await model.send("new question") }
        await waitUntil(chat.waitingCount == 2)
        #expect(model.isSending)

        chat.releaseOldest(with: "stale answer")      // answers the cancelled first request
        await first.value
        #expect(model.isSending, "the new request is still running")
        #expect(model.messages.map(\.text) == ["new question"])

        chat.releaseOldest(with: "fresh answer")
        await second.value
        #expect(!model.isSending)
        #expect(model.messages.map(\.text) == ["new question", "fresh answer"])
    }

    @Test func ignoresASecondSendWhileOneIsPending() async {
        let chat = GatedChat()
        let model = ChatViewModel(service: chat)

        let first = Task { await model.send("first") }
        await waitUntil(chat.waitingCount == 1)
        await model.send("second")                    // returns immediately

        #expect(chat.waitingCount == 1)
        #expect(model.messages.map(\.text) == ["first"])
        chat.releaseOldest(with: "done")
        await first.value
    }

    @Test func healthCheckReflectsTheService() async {
        let chat = MockChat()
        let model = ChatViewModel(service: chat)
        #expect(model.isServiceOnline == nil)

        await model.checkHealth()
        #expect(model.isServiceOnline == true)

        chat.healthResult = .failure(TestError.boom)
        await model.checkHealth()
        #expect(model.isServiceOnline == false)
    }

    @Test func starterPromptsAreNotEmpty() {
        let model = ChatViewModel(service: MockChat())
        #expect(!model.suggestions.isEmpty)
        #expect(model.suggestions.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }
}
