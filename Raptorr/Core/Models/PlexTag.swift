import Foundation

/// A `tag` from the spec: genres, directors and cast (`Role`) on an item, and the person on
/// `/library/people/{personId}`.
nonisolated struct PlexTag: Decodable, Sendable, Hashable {
    let id: Int?
    let tag: String?
    /// The person's Plex identifier, also accepted as `{personId}`.
    let tagKey: String?
    let role: String?
    let thumb: String?
    /// A person's biography, when the server includes one.
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case id, tag, tagKey, role, thumb, summary
    }

    init(
        id: Int? = nil,
        tag: String?,
        tagKey: String? = nil,
        role: String? = nil,
        thumb: String? = nil,
        summary: String? = nil
    ) {
        self.id = id
        self.tag = tag
        self.tagKey = tagKey
        self.role = role
        self.thumb = thumb
        self.summary = summary
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let number = try? container.decode(Int.self, forKey: .id) {
            id = number
        } else {
            id = (try? container.decode(String.self, forKey: .id)).flatMap(Int.init)
        }
        tag = try container.decodeIfPresent(String.self, forKey: .tag)
        tagKey = try? container.decodeIfPresent(String.self, forKey: .tagKey)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        thumb = try container.decodeIfPresent(String.self, forKey: .thumb)
        summary = try? container.decodeIfPresent(String.self, forKey: .summary)
    }

    /// The `{personId}` for `/library/people/{personId}`: the tag `id`, else its `tagKey`.
    var personID: String? {
        id.map(String.init) ?? tagKey
    }
}
