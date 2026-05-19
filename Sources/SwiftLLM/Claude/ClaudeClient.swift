import Foundation

public final class ClaudeClient {
    private let apiKey: String
    let http: HTTPClientProtocol
    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    public convenience init(apiKey: String) {
        self.init(apiKey: apiKey, http: HTTPClient())
    }

    init(apiKey: String, http: HTTPClientProtocol) {
        self.apiKey = apiKey
        self.http = http
    }

    var headers: [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        ]
    }

    /// Send a single message and return the full response text.
    public func message(
        _ text: String,
        model: String = "claude-opus-4-7",
        maxTokens: Int = 1024
    ) async throws -> String {
        let req = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            messages: [ClaudeMessage(role: "user", content: text)],
            system: nil,
            stream: nil
        )
        let body = try JSONEncoder().encode(req)
        let data = try await http.post(url: Self.baseURL, headers: headers, body: body)
        let response: ClaudeResponse
        do {
            response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch {
            throw LLMError.decodingError(error)
        }
        return response.content.first?.text ?? ""
    }

    /// Stream a single message, yielding text chunks as they arrive.
    public func stream(
        _ text: String,
        model: String = "claude-opus-4-7",
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let req = ClaudeRequest(
                        model: model,
                        max_tokens: maxTokens,
                        messages: [ClaudeMessage(role: "user", content: text)],
                        system: nil,
                        stream: true
                    )
                    let body = try JSONEncoder().encode(req)
                    let inner = self.http.stream(url: Self.baseURL, headers: self.headers, body: body)
                    for try await jsonString in inner {
                        guard
                            let data = jsonString.data(using: .utf8),
                            let event = try? JSONDecoder().decode(ClaudeStreamEvent.self, from: data),
                            event.type == "content_block_delta",
                            let text = event.delta?.text
                        else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Create a multi-turn chat session.
    public func chat() -> ClaudeChat {
        ClaudeChat(client: self)
    }
}

// MARK: - ClaudeChat

public final class ClaudeChat {
    private let client: ClaudeClient
    private var history: [ClaudeMessage] = []
    private static let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(client: ClaudeClient) { self.client = client }

    /// Send a message with full conversation history and return the assistant reply.
    public func send(_ text: String, model: String = "claude-opus-4-7", maxTokens: Int = 1024) async throws -> String {
        history.append(ClaudeMessage(role: "user", content: text))

        let req = ClaudeRequest(
            model: model,
            max_tokens: maxTokens,
            messages: history,
            system: nil,
            stream: nil
        )
        let body = try JSONEncoder().encode(req)
        let data = try await client.http.post(url: Self.baseURL, headers: client.headers, body: body)
        let response: ClaudeResponse
        do {
            response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        } catch {
            throw LLMError.decodingError(error)
        }
        let reply = response.content.first?.text ?? ""
        history.append(ClaudeMessage(role: "assistant", content: reply))
        return reply
    }
}
