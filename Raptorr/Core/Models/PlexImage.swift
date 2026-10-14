import Foundation

/// An `Image` element on a metadata item (poster, background, clear logo...).
nonisolated struct PlexImage: Decodable, Sendable, Hashable {
    let type: String?
    let url: String?
    let alt: String?
}
