import Foundation

/// A titled shelf of items returned by the `/hubs` family.
nonisolated struct Hub: Decodable, Sendable, Hashable, Identifiable {
    let hubIdentifier: String?
    let title: String?
    let type: String?
    let size: Int?
    let metadata: [PlexMetadata]?

    var id: String { hubIdentifier ?? "\(type ?? "hub")-\(title ?? "")" }
    var items: [PlexMetadata] { metadata ?? [] }

    enum CodingKeys: String, CodingKey {
        case hubIdentifier, title, type, size
        case metadata = "Metadata"
    }
}
