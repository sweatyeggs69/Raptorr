import Foundation

nonisolated struct PlexConnection: Codable, Sendable, Hashable {
    let uri: String?
    let local: Bool?
    let relay: Bool?
}
