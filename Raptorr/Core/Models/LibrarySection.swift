import Foundation

/// A library on the server (`/library/sections/all` → `Directory`).
nonisolated struct LibrarySection: Decodable, Sendable, Hashable, Identifiable {
    let key: String
    let type: LibraryType
    let title: String
    let thumb: String?
    let art: String?

    var id: String { key }

    /// Raptorr only browses movie and TV libraries.
    var isSupported: Bool { type == .movie || type == .show }

    enum CodingKeys: String, CodingKey {
        case key, type, title, thumb, art
    }

    init(key: String, type: LibraryType, title: String, thumb: String? = nil, art: String? = nil) {
        self.key = key
        self.type = type
        self.title = title
        self.thumb = thumb
        self.art = art
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let string = try? container.decode(String.self, forKey: .key) {
            key = string
        } else {
            key = try String(container.decode(Int.self, forKey: .key))
        }
        type = LibraryType(rawValue: (try? container.decode(String.self, forKey: .type)) ?? "") ?? .other
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        thumb = try? container.decodeIfPresent(String.self, forKey: .thumb)
        art = try? container.decodeIfPresent(String.self, forKey: .art)
    }
}
