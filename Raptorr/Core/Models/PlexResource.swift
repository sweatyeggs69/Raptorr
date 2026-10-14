import Foundation

/// A device on the user's account from plex.tv `/api/v2/resources`.
nonisolated struct PlexResource: Decodable, Sendable {
    let name: String?
    let provides: String?
    let clientIdentifier: String?
    let accessToken: String?
    let owned: Bool?
    let connections: [PlexConnection]?

    var isServer: Bool { provides?.split(separator: ",").contains("server") == true }
}
