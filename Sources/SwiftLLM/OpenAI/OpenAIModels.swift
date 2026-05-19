import Foundation

// MARK: - Request

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let max_tokens: Int?
    let stream: Bool?
}

public struct OpenAIMessage: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Response

struct OpenAIResponse: Decodable {
    let id: String
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Decodable {
    let index: Int
    let message: OpenAIMessage
    let finish_reason: String?
}

// MARK: - Streaming

struct OpenAIStreamChunk: Decodable {
    let id: String
    let choices: [OpenAIStreamChoice]
}

struct OpenAIStreamChoice: Decodable {
    let delta: OpenAIDelta
}

struct OpenAIDelta: Decodable {
    let role: String?
    let content: String?
}
