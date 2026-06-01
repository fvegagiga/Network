import XCTest
import Foundation
@testable import Network

@MainActor
final class RetryingNetworkServiceTests: XCTestCase {
    var mockInner: MockNetworkService!

    override func setUp() {
        super.setUp()
        mockInner = MockNetworkService()
    }

    override func tearDown() {
        mockInner = nil
        super.tearDown()
    }

    // MARK: - Happy path

    func testFetch_whenNoError_returnsResultOnFirstAttempt() async throws {
        mockInner.result = TestResponse(id: 1)

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)
        let _: TestResponse = try await sut.fetch(TestEndpoint())

        XCTAssertEqual(mockInner.callCount, 1)
    }

    // MARK: - Retry on 429

    func testFetch_on429_retriesAndEventuallySucceeds() async throws {
        mockInner.result = TestResponse(id: 1)
        mockInner.errorToThrow = NetworkError.rateLimited(retryAfter: 0.0)
        mockInner.failCount = 2  // fail twice, succeed on 3rd call

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)
        let _: TestResponse = try await sut.fetch(TestEndpoint())

        XCTAssertEqual(mockInner.callCount, 3, "Should have made 3 attempts (2 failures + 1 success)")
    }

    func testFetch_on429_whenRetriesExhausted_throwsRateLimited() async {
        mockInner.errorToThrow = NetworkError.rateLimited(retryAfter: 0.0)
        mockInner.failCount = .max  // always fail

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 2, baseDelay: 0.0)

        do {
            let _: TestResponse = try await sut.fetch(TestEndpoint())
            XCTFail("Should have thrown")
        } catch let error as NetworkError {
            guard case .rateLimited = error else {
                return XCTFail("Expected .rateLimited, got \(error)")
            }
            XCTAssertEqual(mockInner.callCount, 3, "maxRetries=2 → 3 total attempts")
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Non-429 errors are NOT retried

    func testFetch_onNotFound_doesNotRetry() async {
        mockInner.errorToThrow = NetworkError.notFound
        mockInner.failCount = .max

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)

        do {
            let _: TestResponse = try await sut.fetch(TestEndpoint())
            XCTFail("Should have thrown")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .notFound)
            XCTAssertEqual(mockInner.callCount, 1, "Not-found errors must not be retried")
        } catch {
            XCTFail("Wrong error type")
        }
    }

    func testFetch_onServerError_doesNotRetry() async {
        mockInner.errorToThrow = NetworkError.serverError(statusCode: 500)
        mockInner.failCount = .max

        let sut = RetryingNetworkService(wrapped: mockInner, maxRetries: 3, baseDelay: 0.0)

        do {
            let _: TestResponse = try await sut.fetch(TestEndpoint())
            XCTFail("Should have thrown")
        } catch {
            XCTAssertEqual(mockInner.callCount, 1, "5xx errors must not be retried")
        }
    }
}

// Minimal stubs — tests only need something conforming to Endpoint / Decodable.
private struct TestEndpoint: Endpoint {
    let url: URL? = URL(string: "https://example.com/test")
}

private struct TestResponse: Decodable {
    let id: Int
}
