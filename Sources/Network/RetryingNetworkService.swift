import Foundation

/// Decorator that wraps any `NetworkServiceProtocol` and retries automatically on HTTP 429.
///
/// Strategy:
///   1. If the server sends a `Retry-After` header, honour it exactly.
///   2. Otherwise use exponential backoff with ±20% jitter (1s → 2s → 4s …), capped at 30s.
///   3. Only 429 errors trigger a retry; all other errors propagate immediately.
///   4. Task cancellation propagates immediately (no retry on `CancellationError`).
public final class RetryingNetworkService: NetworkServiceProtocol {
    private let wrapped: NetworkServiceProtocol
    private let maxRetries: Int
    private let baseDelay: TimeInterval

    /// - Parameters:
    ///   - wrapped: The underlying service to decorate.
    ///   - maxRetries: Number of *additional* attempts after the first. Default 3 → 4 total.
    ///   - baseDelay: Starting delay in seconds for exponential backoff. Default 1.0s.
    public init(
        wrapped: NetworkServiceProtocol,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0
    ) {
        self.wrapped = wrapped
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }

    public func fetch<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        for attempt in 0...maxRetries {
            do {
                return try await wrapped.fetch(endpoint)
            } catch let error as NetworkError {
                guard case .rateLimited(let retryAfter) = error, attempt < maxRetries else {
                    throw error
                }
                let delay = retryAfter ?? exponentialDelay(attempt: attempt)
                try await Task.sleep(for: .seconds(delay))
            }
            // Non-NetworkError (e.g. CancellationError) propagates without retry.
        }
        // Unreachable: the guard above always throws on the last attempt.
        throw NetworkError.unknown("Retry loop exhausted unexpectedly.")
    }

    // MARK: - Private

    private func exponentialDelay(attempt: Int) -> TimeInterval {
        let base = baseDelay * pow(2.0, Double(attempt))  // 1s, 2s, 4s, 8s…
        let jitter = Double.random(in: 0.8...1.2)         // ±20% to avoid thundering herd
        return min(base * jitter, 30.0)
    }
}
