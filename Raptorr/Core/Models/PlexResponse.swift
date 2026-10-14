import Foundation

/// Top-level `{"MediaContainer": {...}}` wrapper every PMS JSON response uses.
nonisolated struct PlexResponse: Decodable, Sendable {
    let mediaContainer: MediaContainer

    enum CodingKeys: String, CodingKey {
        case mediaContainer = "MediaContainer"
    }
}
