import Foundation

nonisolated struct PlexPart: Decodable, Sendable, Hashable {
    let id: Int?
    /// `/library/parts/{partId}/{changestamp}/{filename}`, the documented media part endpoint.
    let key: String?
    let duration: Int?
    let file: String?
    let size: Int?
    let container: String?
    let stream: [PlexStream]?

    enum CodingKeys: String, CodingKey {
        case id, key, duration, file, size, container
        case stream = "Stream"
    }
}
