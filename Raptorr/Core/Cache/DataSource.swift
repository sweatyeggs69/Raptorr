import Foundation

/// Where a library request is answered from.
nonisolated enum DataSource: Sendable {
    /// The server. Successful responses are written to the cache.
    case network
    /// The last cached response only; throws `PlexAPIError.notCached` on a miss.
    case cache
}
