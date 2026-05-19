import Foundation

struct HTTPClient {
    func post(url: URL, headers: [String: String], body: Data) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LLMError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw LLMError.invalidAPIKey
        case 429:
            throw LLMError.rateLimitExceeded
        default:
            throw LLMError.invalidResponse
        }
    }

    func stream(url: URL, headers: [String: String], body: Data) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = body
                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LLMError.invalidResponse)
                        return
                    }

                    switch http.statusCode {
                    case 200...299:
                        break
                    case 401:
                        continuation.finish(throwing: LLMError.invalidAPIKey)
                        return
                    case 429:
                        continuation.finish(throwing: LLMError.rateLimitExceeded)
                        return
                    default:
                        continuation.finish(throwing: LLMError.invalidResponse)
                        return
                    }

                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let payload = String(line.dropFirst(6))
                            if payload == "[DONE]" { break }
                            continuation.yield(payload)
                        }
                    }

                    continuation.finish()
                } catch let error as LLMError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: LLMError.networkError(error))
                }
            }
        }
    }
}
