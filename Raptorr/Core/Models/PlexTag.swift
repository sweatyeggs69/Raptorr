import Foundation

nonisolated struct PlexTag: Decodable, Sendable, Hashable {
    let tag: String?
    let role: String?
    let thumb: String?
}
