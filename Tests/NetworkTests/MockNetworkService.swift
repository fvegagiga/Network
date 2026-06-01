import Foundation
import Network

final class MockNetworkService: NetworkServiceProtocol {
    var result: Any?
    var errorToThrow: Error?
    /// Throw `errorToThrow` for the first N calls, then return `result`.
    /// Default `Int.max` = always throw (original behaviour).
    var failCount: Int = Int.max
    private(set) var lastEndpoint: (any Endpoint)?
    private(set) var callCount = 0

    func fetch<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        callCount += 1
        lastEndpoint = endpoint

        if let error = errorToThrow, callCount <= failCount {
            throw error
        }

        guard let value = result as? T else {
            throw NetworkError.decodingFailed("MockNetworkService: result type mismatch")
        }
        return value
    }
}
