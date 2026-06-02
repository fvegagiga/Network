# Network

A lightweight Swift networking library for iOS and macOS built on top of `URLSession` and `async/await`.

![iOS](https://img.shields.io/badge/iOS-16%2B-blue)
![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
[![iOS CI](https://github.com/fvegagiga/Network/actions/workflows/ci.yml/badge.svg)](https://github.com/fvegagiga/Network/actions/workflows/ci.yml)

## Features

- Generic `fetch` that decodes any `Decodable` type
- Automatic snake_case → camelCase key decoding
- Typed `NetworkError` with human-readable descriptions
- `RetryingNetworkService` decorator with automatic retry on HTTP 429 (respects `Retry-After` header, falls back to exponential backoff with ±20% jitter)
- Protocol-based design — easy to mock in tests

## Requirements

| Platform | Minimum version |
|----------|----------------|
| iOS      | 16.0           |
| macOS    | 13.0           |
| Swift    | 5.9            |

## Installation

Add the package via Swift Package Manager in Xcode or directly in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/fvegagiga/Network.git", from: "1.0.0")
]
```

## Usage

### 1. Define an endpoint

```swift
import Network

struct UsersEndpoint: Endpoint {
    var url: URL? { URL(string: "https://api.example.com/users") }
}
```

### 2. Fetch and decode

```swift
let service = NetworkService()
let users: [User] = try await service.fetch(UsersEndpoint())
```

### 3. Add automatic retry on rate limiting

```swift
let service = RetryingNetworkService(
    wrapped: NetworkService(),
    maxRetries: 3,       // 4 total attempts
    baseDelay: 1.0       // 1s → 2s → 4s (capped at 30s)
)
let users: [User] = try await service.fetch(UsersEndpoint())
```

### 4. Mock in tests

```swift
final class MockNetworkService: NetworkServiceProtocol {
    var result: Any?
    func fetch<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        result as! T
    }
}
```

## Error handling

`NetworkError` covers the most common failure scenarios:

| Case | Description |
|------|-------------|
| `.invalidURL` | The endpoint produced a `nil` URL |
| `.invalidResponse` | Response is not an HTTP response |
| `.notFound` | HTTP 404 |
| `.rateLimited(retryAfter:)` | HTTP 429, optional wait hint in seconds |
| `.serverError(statusCode:)` | HTTP 5xx (or other unexpected codes) |
| `.decodingFailed(_)` | JSON decoding failed, with details |
| `.noInternetConnection` | No network connectivity |
| `.requestCancelled` | Task was cancelled |
| `.unknown(_)` | Any other error |

## License

MIT
