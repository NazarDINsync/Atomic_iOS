import Foundation
import Testing
@testable import Molecule_app

@Suite(.serialized)
struct APIClientTests {
    private let healthJSON = #"{"status":"ok","agent_initialized":true}"#

    @Test func encodesPlusSignInQueryValues() async throws {
        let seen = Box<URL>()
        let client = makeStubClient { request in
            seen.value = request.url
            return stubResponse(request, json: healthJSON)
        }

        let _: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/x", query: ["substance": "NAD+"])

        let url = try #require(seen.value?.absoluteString)
        #expect(url.contains("substance=NAD%2B"))
        #expect(!url.contains("NAD+"))
    }

    @Test func sendsEveryQueryParameter() async throws {
        let seen = Box<URL>()
        let client = makeStubClient { request in
            seen.value = request.url
            return stubResponse(request, json: healthJSON)
        }

        let _: HealthResponse = try await client.get(
            baseURL: "http://test.local", path: "/reaction",
            query: ["substance": "ATP", "other_substance": "ADP"]
        )

        let items = URLComponents(url: try #require(seen.value), resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(items.first { $0.name == "substance" }?.value == "ATP")
        #expect(items.first { $0.name == "other_substance" }?.value == "ADP")
    }

    @Test func decodesSnakeCaseResponses() async throws {
        let client = makeStubClient { stubResponse($0, json: healthJSON) }
        let health: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/health")
        #expect(health.status == "ok")
        #expect(health.agentInitialized == true)
    }

    @Test func encodesRequestBodiesAsSnakeCase() async throws {
        let seen = Box<Data>()
        let client = makeStubClient { request in
            seen.value = bodyData(of: request)
            return stubResponse(request, json: #"{"response":"hi","conversation_id":"abc"}"#)
        }

        let reply: ChatResponseBody = try await client.post(
            baseURL: "http://test.local", path: "/chat",
            body: ChatRequestBody(message: "hello", conversationId: "abc")
        )

        let body = try #require(seen.value)
        let object = try JSONSerialization.jsonObject(with: body)
        let json = try #require(object as? [String: String])
        #expect(json["conversation_id"] == "abc")
        #expect(json["message"] == "hello")
        #expect(reply.response == "hi")
        #expect(reply.conversationId == "abc")
    }

    @Test func mapsServerErrorsWithTheirDetail() async {
        let client = makeStubClient { stubResponse($0, status: 502, json: #"{"detail":"model offline"}"#) }
        await #expect(throws: APIError.self) {
            let _: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/x")
        }
        do {
            let _: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/x")
        } catch APIError.server(let status, let message) {
            #expect(status == 502)
            #expect(message == "model offline")
        } catch {
            Issue.record("Expected a server error, got \(error)")
        }
    }

    @Test func summarisesValidationErrors() async {
        let client = makeStubClient { stubResponse($0, status: 422, json: #"{"detail":[{"loc":["query","substance"]}]}"#) }
        do {
            let _: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/x")
            Issue.record("Expected an error")
        } catch APIError.server(let status, let message) {
            #expect(status == 422)
            #expect(message == "Invalid request parameters.")
        } catch {
            Issue.record("Expected a server error, got \(error)")
        }
    }

    @Test func reportsAnUnreachableServer() async {
        let client = makeStubClient { _ in throw URLError(.cannotConnectToHost) }
        do {
            let _: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/x")
            Issue.record("Expected an error")
        } catch APIError.unreachable(let host) {
            #expect(host == "test.local")
        } catch {
            Issue.record("Expected .unreachable, got \(error)")
        }
    }

    @Test func reportsTimeoutsReadably() async {
        let client = makeStubClient { _ in throw URLError(.timedOut) }
        do {
            let _: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/x")
            Issue.record("Expected an error")
        } catch {
            #expect(error.userMessage.contains("timed out"))
        }
    }

    @Test func reportsUnexpectedResponseBodies() async {
        let client = makeStubClient { stubResponse($0, json: "<html>not json</html>") }
        do {
            let _: HealthResponse = try await client.get(baseURL: "http://test.local", path: "/x")
            Issue.record("Expected an error")
        } catch APIError.decoding {
            // expected
        } catch {
            Issue.record("Expected .decoding, got \(error)")
        }
    }

    @Test func decodesTheRealReactionShape() async throws {
        let json = """
        {"status":"shared_reactions_found","resolved_qids":["Q1","Q2"],
         "reactions":[{"rhea_id":"RHEA:1","equation":"A = B","participants":"A;B","url":"https://www.rhea-db.org/rhea/1"}],
         "individual_reactions":[{"input":"A","qid":"Q1","reactions":[]}],"message":"note"}
        """
        let client = makeStubClient { stubResponse($0, json: json) }
        let response: ReactionResponse = try await client.get(baseURL: "http://test.local", path: "/reaction")
        #expect(response.isSuccess)
        #expect(response.reactions.first?.rheaId == "RHEA:1")
        #expect(response.individualReactions.first?.input == "A")
        #expect(response.message == "note")
    }
}
