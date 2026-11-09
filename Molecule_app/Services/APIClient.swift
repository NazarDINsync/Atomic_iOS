import Foundation

/// Server addresses, editable in the Settings tab and persisted in `UserDefaults`.
enum ServerConfig {
    static let chemistryKey = "chemistryBaseURL"
    static let llmKey = "llmBaseURL"
    static let defaultChemistryURL = "http://127.0.0.1:8001"
    static let defaultLLMURL = "http://127.0.0.1:3001"

    static var chemistryBaseURL: String {
        UserDefaults.standard.string(forKey: chemistryKey) ?? defaultChemistryURL
    }

    static var llmBaseURL: String {
        UserDefaults.standard.string(forKey: llmKey) ?? defaultLLMURL
    }
}

/// Errors surfaced to the user in a readable form.
enum APIError: LocalizedError {
    case invalidURL(String)
    case unreachable(String)
    case server(status: Int, message: String)
    case decoding(String)
    case other(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            "The server address \"\(url)\" is not valid. Check it in Settings."
        case .unreachable(let host):
            "Can't reach the server at \(host). Make sure the backend is running and the address in Settings is correct."
        case .server(let status, let message):
            "Server error \(status): \(message)"
        case .decoding(let details):
            "Unexpected response from the server. \(details)"
        case .other(let message):
            message
        }
    }
}

/// A tiny JSON-over-HTTP client built on `URLSession`.
struct APIClient {
    var session: URLSession = .shared

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    /// Sends a GET request with query parameters and decodes the JSON response.
    func get<Response: Decodable>(
        baseURL: String,
        path: String,
        query: [String: String] = [:],
        timeout: TimeInterval = 120
    ) async throws -> Response {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL(baseURL)
        }
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            // URLComponents leaves "+" as-is, but servers decode it as a space ("NAD+" would become "NAD ").
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let url = components.url else { throw APIError.invalidURL(baseURL) }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await send(request)
    }

    /// Sends a POST request with a JSON body and decodes the JSON response.
    func post<Body: Encodable, Response: Decodable>(
        baseURL: String,
        path: String,
        body: Body,
        timeout: TimeInterval = 180
    ) async throws -> Response {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL(baseURL) }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(body)
        return try await send(request)
    }

    private func send<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .networkConnectionLost:
                throw APIError.unreachable(request.url?.host() ?? "server")
            case .timedOut:
                throw APIError.other("The request timed out. Wikidata or the LLM may be slow — try again.")
            default:
                throw APIError.other(error.localizedDescription)
            }
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw APIError.server(status: http.statusCode, message: Self.detailMessage(from: data))
        }

        do {
            return try Self.decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    /// FastAPI returns `{"detail": "..."}` or `{"detail": [{...}]}` on errors.
    private static func detailMessage(from data: Data) -> String {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let detail = json?["detail"] as? String { return detail }
        if json?["detail"] is [Any] { return "Invalid request parameters." }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}
