import Foundation

/// How a connection reaches the server, in the order they are tried.
nonisolated enum ConnectionKind: Int, CaseIterable, Comparable, Sendable {
    /// Same network as the Apple TV.
    case local
    /// The server's public (WAN) address.
    case remote
    /// Plex's relay, the slowest and bandwidth-limited fallback.
    case relay

    var title: String {
        switch self {
        case .local: "Local"
        case .remote: "Remote"
        case .relay: "Relay"
        }
    }

    /// How long a probe of this kind gets before the next kind is tried.
    var probeTimeout: TimeInterval {
        switch self {
        case .local: 3
        case .remote: 6
        case .relay: 8
        }
    }

    static func < (lhs: ConnectionKind, rhs: ConnectionKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
