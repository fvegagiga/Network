import Testing
import Foundation
@testable import Network

@Suite
struct RetryingNetworkServiceTests {
    let mockInner = MockNetworkService()

    // MARK: - Happy path

    @Test func fetch_whenNoError_returnsResultOnFirstAttempt() async throws {
        mockInner.result = TestResponse(id: 1)

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)
        let _: TestResponse = try await sut.fetch(TestEndpoint())

        #expect(mockInner.callCount == 1)
    }

    // MARK: - Retry on 429

    @Test func fetch_on429_retriesAndEventuallySucceeds() async throws {
        mockInner.result = TestResponse(id: 1)
        mockInner.errorToThrow = NetworkError.rateLimited(retryAfter: 0.0)
        mockInner.failCount = 2

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)
        let _: TestResponse = try await sut.fetch(TestEndpoint())

        #expect(mockInner.callCount == 3, "Should have made 3 attempts (2 failures + 1 success)")
    }

    @Test func fetch_on429_whenRetriesExhausted_throwsRateLimited() async {
        mockInner.errorToThrow = NetworkError.rateLimited(retryAfter: 0.0)
        mockInner.failCount = .max

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 2, baseDelay: 0.0)

        let error = await #expect(throws: NetworkError.self) {
            let _: TestResponse = try await sut.fetch(TestEndpoint())
        }
        #expect(mockInner.callCount == 3, "maxRetries=2 → 3 total attempts")
        if case .rateLimited = error { } else {
            Issue.record("Expected .rateLimited, got \(String(describing: error))")
        }
    }

    // MARK: - Non-429 errors are NOT retried

    @Test func fetch_onNotFound_doesNotRetry() async {
        mockInner.errorToThrow = NetworkError.notFound
        mockInner.failCount = .max

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)

        await #expect(throws: NetworkError.notFound) {
            let _: TestResponse = try await sut.fetch(TestEndpoint())
        }
        #expect(mockInner.callCount == 1, "Not-found errors must not be retried")
    }

    @Test func fetch_onServerError_doesNotRetry() async {
        mockInner.errorToThrow = NetworkError.serverError(statusCode: 500)
        mockInner.failCount = .max

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)

        await #expect(throws: NetworkError.self) {
            let _: TestResponse = try await sut.fetch(TestEndpoint())
        }
        #expect(mockInner.callCount == 1, "5xx errors must not be retried")
    }
}

// Minimal stubs — tests only need something conforming to Endpoint / Decodable.
private struct TestEndpoint: Endpoint {
    let url: URL? = URL(string: "https://example.com/test")
}

private struct TestResponse: Decodable {
    let id: Int
}
