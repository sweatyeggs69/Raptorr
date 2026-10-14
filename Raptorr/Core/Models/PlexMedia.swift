import Foundation

nonisolated struct PlexMedia: Decodable, Sendable, Hashable {
    let id: Int?
    let duration: Int?
    let bitrate: Int?
    let width: Int?
    let height: Int?
    let container: String?
    let videoCodec: String?
    let audioCodec: String?
    let audioChannels: Int?
    let videoResolution: String?
    let part: [PlexPart]?

    enum CodingKeys: String, CodingKey {
        case id, duration, bitrate, width, height, container
        case videoCodec, audioCodec, audioChannels, videoResolution
        case part = "Part"
    }
}
