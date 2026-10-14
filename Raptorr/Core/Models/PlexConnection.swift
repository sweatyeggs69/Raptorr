import Foundation

nonisolated struct PlexConnection: Codable, Sendable, Hashable {
    let uri: String?
    let local: Bool?
    let relay: Bool?

    var kind: ConnectionKind {
        if relay == true { return .relay }
        return local == true ? .local : .remote
    }

    /// Connection URIs grouped local, then remote (WAN), then relay; empty groups are dropped.
    static func tiers(_ connections: [PlexConnection]) -> [(kind: ConnectionKind, uris: [String])] {
        ConnectionKind.allCases.compactMap { kind in
            let uris = connections.filter { $0.kind == kind }.compactMap(\.uri)
            return uris.isEmpty ? nil : (kind, uris)
        }
    }
}
