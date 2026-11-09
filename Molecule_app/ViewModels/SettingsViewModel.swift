import Foundation
import Observation

/// Tests connectivity to both backend services.
@Observable
final class SettingsViewModel {
    enum ConnectionStatus: Equatable {
        case unknown, checking, ok, failed(String)
    }

    private(set) var chemistryStatus: ConnectionStatus = .unknown
    private(set) var llmStatus: ConnectionStatus = .unknown

    private let chemistry: ChemistryServicing
    private let chat: ChatServicing

    init(chemistry: ChemistryServicing = ChemistryService(), chat: ChatServicing = ChatService()) {
        self.chemistry = chemistry
        self.chat = chat
    }

    /// Pings both services and updates their statuses.
    func testConnections() async {
        chemistryStatus = .checking
        llmStatus = .checking
        async let chem = capture { try await chemistry.ping() }
        async let llm = capture { try await chat.health() }

        switch await chem {
        case .success: chemistryStatus = .ok
        case .failure(let error): chemistryStatus = .failed(error.userMessage)
        }
        switch await llm {
        case .success: llmStatus = .ok
        case .failure(let error): llmStatus = .failed(error.userMessage)
        }
    }
}
