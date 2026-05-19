import Foundation

public final class OpenAIClient {
    private let apiKey: String
    let http: HTTPClientProtocol
    private static let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    public convenience init(apiKey: String) {
        self.init(apiKey: apiKey, http: HTTPClient())
    }

    init(apiKey: String, http: HTTPClientProtocol) {
        self.apiKey = apiKey
        self.http = http
    }

    var headers: [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "content-type": "application/json"
        ]
    }

    /// Send a single message and return the full response text.
    public func message(
        _ text: String,
        model: String = "gpt-4o",
        maxTokens: Int = 1024
    ) async throws -> String {
        let req = OpenAIRequest(
            model: model,
            messages: [OpenAIMessage(role: "user", content: text)],
            max_tokens: maxTokens,
            stream: nil
        )
        let body = try JSONEncoder().encode(req)
        let data = try await http.post(url: Self.baseURL, headers: headers, body: body)
        let response: OpenAIResponse
        do {
            response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw LLMError.decodingError(error)
        }
        return response.choices.first?.message.content ?? ""
    }

    /// Stream a single message, yielding text chunks as they arrive.
    public func stream(
        _ text: String,
        model: String = "gpt-4o",
        maxTokens: Int = 1024
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let req = OpenAIRequest(
                        model: model,
                        messages: [OpenAIMessage(role: "user", content: text)],
                        max_tokens: maxTokens,
                        stream: true
                    )
                    let body = try JSONEncoder().encode(req)
                    let inner = self.http.stream(url: Self.baseURL, headers: self.headers, body: body)
                    for try await jsonString in inner {
                        guard
                            let data = jsonString.data(using: .utf8),
                            let chunk = try? JSONDecoder().decode(OpenAIStreamChunk.self, from: data),
                            let content = chunk.choices.first?.delta.content
                        else { continue }
                        continuation.yield(content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Create a multi-turn chat session.
    public func chat() -> OpenAIChat {
        OpenAIChat(client: self)
    }
}

// MARK: - OpenAIChat

public final class OpenAIChat {
    private let client: OpenAIClient
    private var history: [OpenAIMessage] = []
    private static let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    init(client: OpenAIClient) { self.client = client }

    /// Send a message with full conversation history and return the assistant reply.
    public func send(_ text: String, model: String = "gpt-4o", maxTokens: Int = 1024) async throws -> String {
        history.append(OpenAIMessage(role: "user", content: text))

        let req = OpenAIRequest(
            model: model,
            messages: history,
            max_tokens: maxTokens,
            stream: nil
        )
        let body = try JSONEncoder().encode(req)
        let data = try await client.http.post(url: Self.baseURL, headers: client.headers, body: body)
        let response: OpenAIResponse
        do {
            response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw LLMError.decodingError(error)
        }
        let reply = response.choices.first?.message.content ?? ""
        history.append(OpenAIMessage(role: "assistant", content: reply))
        return reply
    }
}
