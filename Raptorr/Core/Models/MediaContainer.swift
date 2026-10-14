import Foundation

nonisolated struct MediaContainer: Decodable, Sendable {
    let size: Int?
    let totalSize: Int?
    let offset: Int?
    let title1: String?
    let title2: String?
    let metadata: [PlexMetadata]?
    let directory: [LibrarySection]?
    let hub: [Hub]?

    enum CodingKeys: String, CodingKey {
        case size, totalSize, offset, title1, title2
        case metadata = "Metadata"
        case directory = "Directory"
        case hub = "Hub"
    }
}
