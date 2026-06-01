import Foundation

public final class NetworkService: NetworkServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    public func fetch<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        guard let url = endpoint.url else {
            throw NetworkError.invalidURL
        }

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(from: url)
        } catch let urlError as URLError {
            throw urlError.toNetworkError()
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        switch http.statusCode {
        case 200...299:
            break
        case 404:
            throw NetworkError.notFound
        case 429:
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw NetworkError.serverError(statusCode: http.statusCode)
        default:
            throw NetworkError.serverError(statusCode: http.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingFailed(decodingError.readableDescription)
        }
    }
}

private extension URLError {
    func toNetworkError() -> NetworkError {
        switch code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .cancelled:
            return .requestCancelled
        default:
            return .unknown(localizedDescription)
        }
    }
}

private extension DecodingError {
    var readableDescription: String {
        switch self {
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Value not found for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .keyNotFound(let key, let context):
            return "Key '\(key.stringValue)' not found at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let context):
            return "Data corrupted at \(context.codingPath.map(\.stringValue).joined(separator: "."))"
        @unknown default:
            return localizedDescription
        }
    }
}
