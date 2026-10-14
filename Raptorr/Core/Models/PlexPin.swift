import Foundation

/// Response of `POST /api/v2/pins` and `GET /api/v2/pins/{id}` on plex.tv.
nonisolated struct PlexPin: Decodable, Sendable {
    let id: Int
    let code: String
    let expiresIn: Int?
    let authToken: String?
}
