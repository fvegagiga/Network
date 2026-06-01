import Foundation

public enum NetworkError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case decodingFailed(String)
    case notFound
    case serverError(statusCode: Int)
    /// HTTP 429. `retryAfter` is the server-suggested wait in seconds (from the Retry-After header).
    case rateLimited(retryAfter: TimeInterval?)
    case noInternetConnection
    case requestCancelled
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL is malformed."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .decodingFailed(let detail):
            return "Failed to process server data: \(detail)"
        case .notFound:
            return "The requested resource was not found."
        case .serverError(let code):
            return "Server error (HTTP \(code)). Please try again later."
        case .rateLimited(let after):
            if let after {
                return "Too many requests. Retrying in \(Int(after))s…"
            }
            return "Too many requests. Retrying shortly…"
        case .noInternetConnection:
            return "No internet connection. Check your network settings."
        case .requestCancelled:
            return "The request was cancelled."
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        }
    }

    public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
        lhs.errorDescription == rhs.errorDescription
    }
}
