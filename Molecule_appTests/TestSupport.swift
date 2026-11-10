import Foundation
@testable import Molecule_app

// MARK: - Errors

enum TestError: LocalizedError {
    case boom
    case unset

    var errorDescription: String? {
        switch self {
        case .boom: "Boom"
        case .unset: "No result configured for this test"
        }
    }
}

// MARK: - LoadState helpers

extension LoadState {
    var loadedValue: Value? {
        if case .loaded(let value) = self { return value }
        return nil
    }

    var failureMessage: String? {
        if case .failed(let message) = self { return message }
        return nil
    }

    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }
}

func waitUntil(_ condition: @autoclosure () -> Bool) async {
    for _ in 0..<2_000 where !condition() { await Task.yield() }
}

// MARK: - Row builders

let caffeineEntity = "http://www.wikidata.org/entity/Q60235"
let otherEntity = "http://www.wikidata.org/entity/Q999"

func chemRow(_ property: String, _ value: String, entity: String = caffeineEntity, unitName: String? = nil) -> ChemicalPropertyRow {
    ChemicalPropertyRow(entity: entity, property: property, value: value, unit: nil, unitName: unitName, error: nil)
}

func physRow(_ property: String, _ amount: String, unitName: String?, entity: String = caffeineEntity) -> PhysicalPropertyRow {
    PhysicalPropertyRow(entity: entity, property: property, amount: amount, unit: nil, unitName: unitName, error: nil)
}

func kindRow(_ relation: String, _ label: String, entity: String = caffeineEntity) -> KindRow {
    KindRow(entity: entity, relation: relation, type: nil, typeLabel: label, error: nil)
}

func reaction(_ id: String, _ equation: String = "A = B") -> Reaction {
    Reaction(rheaId: id, equation: equation, participants: "A;B", url: "https://www.rhea-db.org/rhea/\(id)")
}

// MARK: - Chemistry service mock

final class MockChemistry: ChemistryServicing {
    var chemical: Result<ChemicalPropertiesResponse, Error> = .success(.init(substance: "", properties: []))
    var physical: Result<PhysicalPropertiesResponse, Error> = .success(.init(substance: "", properties: []))
    var kinds: Result<SubstanceKindResponse, Error> = .success(.init(substance: "", kinds: []))
    var reactionResult: Result<ReactionResponse, Error> = .failure(TestError.unset)
    var mixtureResult: Result<MixtureResponse, Error> = .failure(TestError.unset)
    var pingResult: Result<Void, Error> = .success(())

    private(set) var chemicalQueries: [String] = []
    private(set) var physicalQueries: [String] = []
    private(set) var kindQueries: [String] = []
    private(set) var reactionQueries: [(String, String)] = []
    private(set) var mixtureQueries: [String] = []

    func chemicalProperties(of substance: String) async throws -> ChemicalPropertiesResponse {
        chemicalQueries.append(substance)
        return try chemical.get()
    }

    func physicalProperties(of substance: String) async throws -> PhysicalPropertiesResponse {
        physicalQueries.append(substance)
        return try physical.get()
    }

    func kind(of substance: String) async throws -> SubstanceKindResponse {
        kindQueries.append(substance)
        return try kinds.get()
    }

    func reactions(between substance: String, and other: String) async throws -> ReactionResponse {
        reactionQueries.append((substance, other))
        return try reactionResult.get()
    }

    func components(of mixture: String) async throws -> MixtureResponse {
        mixtureQueries.append(mixture)
        return try mixtureResult.get()
    }

    func ping() async throws {
        try pingResult.get()
    }
}

// MARK: - Chat service mocks

final class MockChat: ChatServicing {
    var reply: Result<String, Error> = .success("ok")
    var healthResult: Result<HealthResponse, Error> = .success(HealthResponse(status: "ok", agentInitialized: true))
    private(set) var sent: [(message: String, conversationID: String)] = []

    func send(_ message: String, conversationID: String) async throws -> String {
        sent.append((message, conversationID))
        return try reply.get()
    }

    func health() async throws -> HealthResponse {
        try healthResult.get()
    }
}

final class GatedChat: ChatServicing {
    private var pending: [CheckedContinuation<String, Error>] = []
    private(set) var conversationIDs: [String] = []

    var waitingCount: Int { pending.count }

    func send(_ message: String, conversationID: String) async throws -> String {
        conversationIDs.append(conversationID)
        return try await withCheckedThrowingContinuation { pending.append($0) }
    }

    func health() async throws -> HealthResponse {
        HealthResponse(status: "ok", agentInitialized: true)
    }

    /// Answers the oldest request that is still waiting.
    func releaseOldest(with text: String) {
        guard !pending.isEmpty else { return }
        pending.removeFirst().resume(returning: text)
    }
}

// MARK: - Network stub

nonisolated final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// An `APIClient` whose session is answered by `handler`.
func makeStubClient(_ handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    StubURLProtocol.handler = handler
    return APIClient(session: URLSession(configuration: configuration))
}

/// A canned HTTP response for `request`.
func stubResponse(_ request: URLRequest, status: Int = 200, json: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    return (response, Data(json.utf8))
}

/// Reads a request body, which `URLProtocol` exposes as a stream.
func bodyData(of request: URLRequest) -> Data {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return Data() }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }
    return data
}

/// Collects a value from inside a stub handler.
final class Box<Value> {
    var value: Value?
}
