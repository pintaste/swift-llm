import XCTest
@testable import SwiftLLM

final class ClaudeClientTests: XCTestCase {

    // MARK: - message()

    func test_message_returnsExpectedText() async throws {
        let mock = MockHTTPClient()
        mock.postResult = .success(MockFixtures.claudeResponse(text: "Hello, world!"))
        let client = ClaudeClient(apiKey: "test-key", http: mock)

        let result = try await client.message("Hi")

        XCTAssertEqual(result, "Hello, world!")
    }

    func test_message_throws_invalidAPIKey_on401() async throws {
        let mock = MockHTTPClient()
        mock.postResult = .failure(LLMError.invalidAPIKey)
        let client = ClaudeClient(apiKey: "bad-key", http: mock)

        do {
            _ = try await client.message("Hi")
            XCTFail("Expected error to be thrown")
        } catch LLMError.invalidAPIKey {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_message_throws_rateLimitExceeded_on429() async throws {
        let mock = MockHTTPClient()
        mock.postResult = .failure(LLMError.rateLimitExceeded)
        let client = ClaudeClient(apiKey: "test-key", http: mock)

        do {
            _ = try await client.message("Hi")
            XCTFail("Expected error to be thrown")
        } catch LLMError.rateLimitExceeded {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_message_throws_decodingError_onMalformedJSON() async throws {
        let mock = MockHTTPClient()
        mock.postResult = .success("not json".data(using: .utf8)!)
        let client = ClaudeClient(apiKey: "test-key", http: mock)

        do {
            _ = try await client.message("Hi")
            XCTFail("Expected error to be thrown")
        } catch LLMError.decodingError {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - stream()

    func test_stream_yieldsTextChunks() async throws {
        let mock = MockHTTPClient()
        mock.streamLines = [
            MockFixtures.claudeStreamEvent(text: "Hello"),
            MockFixtures.claudeStreamEvent(text: ", world"),
            MockFixtures.claudeStreamEvent(text: "!"),
        ]
        let client = ClaudeClient(apiKey: "test-key", http: mock)

        var chunks: [String] = []
        for try await chunk in client.stream("Hi") {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["Hello", ", world", "!"])
    }

    func test_stream_ignoresNonDeltaEvents() async throws {
        let mock = MockHTTPClient()
        mock.streamLines = [
            #"{"type":"message_start","message":{"id":"msg_1"}}"#,
            MockFixtures.claudeStreamEvent(text: "Hi"),
            #"{"type":"message_stop"}"#,
        ]
        let client = ClaudeClient(apiKey: "test-key", http: mock)

        var chunks: [String] = []
        for try await chunk in client.stream("Hi") {
            chunks.append(chunk)
        }

        XCTAssertEqual(chunks, ["Hi"])
    }

    // MARK: - chat()

    func test_chat_maintainsHistory() async throws {
        // We need to vary the response per call — use a sequential mock.
        let sequenceMock = SequenceMockHTTPClient(responses: [
            MockFixtures.claudeResponse(text: "Reply 1"),
            MockFixtures.claudeResponse(text: "Reply 2"),
        ])
        let client = ClaudeClient(apiKey: "test-key", http: sequenceMock)
        let chat = client.chat()

        let first = try await chat.send("Turn 1")
        let second = try await chat.send("Turn 2")

        XCTAssertEqual(first, "Reply 1")
        XCTAssertEqual(second, "Reply 2")
        // Two POST calls were made (one per turn)
        XCTAssertEqual(sequenceMock.callCount, 2)
    }
}

// MARK: - Helpers

/// A mock that cycles through a list of responses in order.
final class SequenceMockHTTPClient: HTTPClientProtocol {
    private let responses: [Data]
    private var index = 0
    private(set) var callCount = 0

    init(responses: [Data]) { self.responses = responses }

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        defer {
            callCount += 1
            index += 1
        }
        guard index < responses.count else { throw LLMError.invalidResponse }
        return responses[index]
    }

    func stream(url: URL, headers: [String: String], body: Data) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
