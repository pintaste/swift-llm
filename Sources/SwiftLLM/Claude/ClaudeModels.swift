import Foundation

// MARK: - Request

struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
    let system: String?
    let stream: Bool?
}

public struct ClaudeMessage: Codable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Response

struct ClaudeResponse: Decodable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let usage: ClaudeUsage
}

struct ClaudeContent: Decodable {
    let type: String
    let text: String
}

struct ClaudeUsage: Decodable {
    let input_tokens: Int
    let output_tokens: Int
}

// MARK: - Streaming

struct ClaudeStreamEvent: Decodable {
    let type: String
    let delta: ClaudeDelta?
}

struct ClaudeDelta: Decodable {
    let type: String
    let text: String?
}
