# swift-llm

![Swift](https://img.shields.io/badge/Swift-5.9-orange) ![SPM](https://img.shields.io/badge/SPM-compatible-blue) ![Platform](https://img.shields.io/badge/platform-iOS%2015%2B%20%7C%20macOS%2012%2B-lightgrey) ![Tests](https://github.com/pintaste/swift-llm/actions/workflows/test.yml/badge.svg)

Native Swift Package for Claude and OpenAI — async/await, streaming, multi-turn, zero dependencies.

---

## Install

Add the package in Xcode via **File → Add Package Dependencies**, or directly in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pintaste/swift-llm", from: "1.0.0")
],
targets: [
    .target(name: "YourTarget", dependencies: ["SwiftLLM"])
]
```

---

## Usage

### Single message

```swift
import SwiftLLM

let claude = ClaudeClient(apiKey: "sk-ant-...")
let reply = try await claude.message("What is the capital of France?")
print(reply) // "The capital of France is Paris."
```

### Streaming

```swift
import SwiftLLM

let openai = OpenAIClient(apiKey: "sk-...")
for try await chunk in openai.stream("Tell me a joke") {
    print(chunk, terminator: "")
}
```

### Multi-turn chat

```swift
import SwiftLLM

let chat = ClaudeClient(apiKey: "sk-ant-...").chat()
let first  = try await chat.send("My name is Alice.")
let second = try await chat.send("What is my name?")
// second → "Your name is Alice."
```

---

## API Reference

| Method | ClaudeClient | OpenAIClient |
|--------|-------------|--------------|
| Single message | `message(_ text:, model:, maxTokens:) async throws -> String` | Same signature |
| Streaming | `stream(_ text:, model:, maxTokens:) -> AsyncThrowingStream<String, Error>` | Same signature |
| Multi-turn chat | `chat() -> ClaudeChat` | `chat() -> OpenAIChat` |
| Default model | `claude-opus-4-7` | `gpt-4o` |

Both `ClaudeChat` and `OpenAIChat` expose:

| Method | Description |
|--------|-------------|
| `send(_ text:, model:, maxTokens:) async throws -> String` | Send a turn; history is maintained automatically |

---

## Error Handling

All methods throw `LLMError`:

```swift
public enum LLMError: Error {
    case invalidAPIKey       // HTTP 401
    case rateLimitExceeded   // HTTP 429
    case invalidResponse     // Other non-2xx
    case networkError(Error) // URLSession failure
    case decodingError(Error)// JSON decode failure
}
```

---

## Why swift-llm?

- **Zero dependencies** — uses only `Foundation` and `URLSession`
- **Native async/await** — no callbacks, no Combine wrappers
- **Streaming via AsyncSequence** — `for try await chunk in client.stream(...)` just works
- **Multi-turn history** — `ClaudeChat` / `OpenAIChat` track the full conversation automatically
- **Broad platform support** — macOS 12+ and iOS 15+
- **Tiny surface area** — three types, one import, done
