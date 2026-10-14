import Foundation

nonisolated struct MediaContainer: Decodable, Sendable {
    let size: Int?
    let totalSize: Int?
    let offset: Int?
    let title1: String?
    let title2: String?
    /// Set on `/identity` responses.
    let machineIdentifier: String?
    let metadata: [PlexMetadata]?
    let directory: [LibrarySection]?
    /// `Directory` again, on `/library/sections/{sectionId}/firstCharacters` responses.
    let firstCharacters: [FirstCharacter]?
    let hub: [Hub]?

    enum CodingKeys: String, CodingKey {
        case size, totalSize, offset, title1, title2, machineIdentifier
        case metadata = "Metadata"
        case directory = "Directory"
        case hub = "Hub"
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decodeIfPresent(Int.self, forKey: .size)
        totalSize = try container.decodeIfPresent(Int.self, forKey: .totalSize)
        offset = try container.decodeIfPresent(Int.self, forKey: .offset)
        title1 = try container.decodeIfPresent(String.self, forKey: .title1)
        title2 = try container.decodeIfPresent(String.self, forKey: .title2)
        machineIdentifier = try container.decodeIfPresent(String.self, forKey: .machineIdentifier)
        metadata = try container.decodeIfPresent([PlexMetadata].self, forKey: .metadata)
        directory = try container.decodeIfPresent([LibrarySection].self, forKey: .directory)
        // Only first-character directories carry a `size`, so this is nil everywhere else.
        firstCharacters = try? container.decodeIfPresent([FirstCharacter].self, forKey: .directory)
        hub = try container.decodeIfPresent([Hub].self, forKey: .hub)
    }
}
