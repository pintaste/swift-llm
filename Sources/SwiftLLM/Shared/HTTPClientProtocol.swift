import Foundation

/// Protocol that both `HTTPClient` and test mocks conform to,
/// enabling dependency injection without external frameworks.
protocol HTTPClientProtocol {
    func post(url: URL, headers: [String: String], body: Data) async throws -> Data
    func stream(url: URL, headers: [String: String], body: Data) -> AsyncThrowingStream<String, Error>
}

extension HTTPClient: HTTPClientProtocol {}
