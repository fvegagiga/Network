import Foundation

public protocol NetworkServiceProtocol {
    func fetch<T: Decodable>(_ endpoint: some Endpoint) async throws -> T
}
