import Foundation

nonisolated enum PlexAPIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)
    case networkError(any Error)
    case decodingError(any Error, path: String)
    case noPlayableMedia

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .unauthorized: "Your Plex session has expired. Please sign in again."
        case .serverError(let code): "The server returned an error (\(code))."
        case .networkError(let error): error.localizedDescription
        case .decodingError(_, let path): "The server sent an unexpected response for \(path)."
        case .noPlayableMedia: "This item has no playable media."
        }
    }
}
