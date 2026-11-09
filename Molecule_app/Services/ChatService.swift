import Foundation

/// Access to the LLM chemistry assistant service.
protocol ChatServicing {
    func send(_ message: String, conversationID: String) async throws -> String
    func health() async throws -> HealthResponse
}

/// Live implementation that talks to the LLM FastAPI service.
struct ChatService: ChatServicing {
    var client = APIClient()
    var baseURL: () -> String = { ServerConfig.llmBaseURL }

    func send(_ message: String, conversationID: String) async throws -> String {
        let body = ChatRequestBody(message: message, conversationId: conversationID)
        let response: ChatResponseBody = try await client.post(baseURL: baseURL(), path: "/llm/v1/chat", body: body)
        return response.response
    }

    func health() async throws -> HealthResponse {
        try await client.get(baseURL: baseURL(), path: "/llm/v1/health", timeout: 10)
    }
}
