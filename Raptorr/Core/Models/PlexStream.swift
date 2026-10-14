import Foundation

nonisolated struct PlexStream: Decodable, Sendable, Hashable {
    let id: Int?
    /// 1 = video, 2 = audio, 3 = subtitle.
    let streamType: Int?
    let codec: String?
    let language: String?
    let languageCode: String?
    let displayTitle: String?
    let selected: Bool?
    /// Present only for sidecar (external) subtitle files.
    let key: String?

    var isExternalSubtitle: Bool { streamType == 3 && key != nil }
}
