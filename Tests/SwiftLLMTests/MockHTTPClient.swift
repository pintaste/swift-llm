import Foundation
@testable import SwiftLLM

// MARK: - MockHTTPClient

/// A test double for HTTPClient that returns preset responses without hitting the network.
final class MockHTTPClient: HTTPClientProtocol {
    /// Set this to control what `post` returns (or throws).
    var postResult: Result<Data, Error> = .success(Data())

    /// Set this to control what `stream` yields.
    var streamLines: [String] = []
    var streamError: Error? = nil

    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        switch postResult {
        case .success(let data): return data
        case .failure(let error): throw error
        }
    }

    func stream(url: URL, headers: [String: String], body: Data) -> AsyncThrowingStream<String, Error> {
        let lines = streamLines
        let error = streamError
        return AsyncThrowingStream { continuation in
            for line in lines {
                continuation.yield(line)
            }
            if let error = error {
                continuation.finish(throwing: error)
            } else {
                continuation.finish()
            }
        }
    }
}

// MARK: - Fixture JSON helpers

enum MockFixtures {
    /// Minimal Claude Messages API response JSON.
    static func claudeResponse(text: String) -> Data {
        let json = """
        {
            "id": "msg_test",
            "type": "message",
            "role": "assistant",
            "content": [{"type": "text", "text": "\(text)"}],
            "usage": {"input_tokens": 10, "output_tokens": 5}
        }
        """
        return json.data(using: .utf8)!
    }

    /// Minimal OpenAI Chat Completions response JSON.
    static func openAIResponse(text: String) -> Data {
        let json = """
        {
            "id": "chatcmpl_test",
            "choices": [
                {
                    "index": 0,
                    "message": {"role": "assistant", "content": "\(text)"},
                    "finish_reason": "stop"
                }
            ]
        }
        """
        return json.data(using: .utf8)!
    }

    /// A Claude streaming event JSON (content_block_delta).
    static func claudeStreamEvent(text: String) -> String {
        """
        {"type":"content_block_delta","delta":{"type":"text_delta","text":"\(text)"}}
        """
    }

    /// An OpenAI streaming chunk JSON.
    static func openAIStreamChunk(content: String) -> String {
        """
        {"id":"chatcmpl_test","choices":[{"delta":{"role":null,"content":"\(content)"}}]}
        """
    }
}
