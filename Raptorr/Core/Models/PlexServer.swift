import Foundation

/// A reachable Plex Media Server, with the connection URI that answered the probe.
nonisolated struct PlexServer: Codable, Sendable, Hashable, Identifiable {
    let name: String
    let uri: String
    let machineIdentifier: String
    let accessToken: String
    let owned: Bool
    /// Every advertised connection, kept so the URI can be re-probed later.
    let connections: [PlexConnection]

    var id: String { machineIdentifier }
    var baseURL: URL? { URL(string: uri) }

    func with(uri newURI: String) -> PlexServer {
        PlexServer(
            name: name,
            uri: newURI,
            machineIdentifier: machineIdentifier,
            accessToken: accessToken,
            owned: owned,
            connections: connections
        )
    }
}
