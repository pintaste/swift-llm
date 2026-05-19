import Foundation

public enum LLMError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case rateLimitExceeded
    case invalidResponse
    case decodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Invalid API key"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .rateLimitExceeded: return "Rate limit exceeded"
        case .invalidResponse: return "Invalid response from API"
        case .decodingError(let e): return "Decoding error: \(e.localizedDescription)"
        }
    }
}
