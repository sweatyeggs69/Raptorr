import Foundation

nonisolated struct PlexStream: Decodable, Sendable, Hashable {
    let id: Int?
    /// 1 = video, 2 = audio, 3 = subtitle.
    let streamType: Int?
    /// Position inside the part's container; absent for sidecar files.
    let index: Int?
    let codec: String?
    let language: String?
    let languageCode: String?
    let title: String?
    let displayTitle: String?
    let extendedDisplayTitle: String?
    let selected: Bool?
    let isDefault: Bool?
    let forced: Bool?
    let hearingImpaired: Bool?
    /// Present only for sidecar (external) subtitle files.
    let key: String?

    enum CodingKeys: String, CodingKey {
        case id, streamType, index, codec, language, languageCode, title
        case displayTitle, extendedDisplayTitle, selected, forced, hearingImpaired, key
        case isDefault = "default"
    }

    var isAudio: Bool { streamType == 2 }
    var isSubtitle: Bool { streamType == 3 }
    var isExternalSubtitle: Bool { isSubtitle && key != nil }
    var isForced: Bool { forced == true }

    /// Menu label, e.g. "English (SRT)" plus "Forced" / "SDH" when the server didn't already say so.
    var menuTitle: String {
        var name = extendedDisplayTitle ?? displayTitle ?? title ?? language ?? "Unknown"
        if isForced, !name.localizedCaseInsensitiveContains("forced") {
            name += " · Forced"
        }
        if hearingImpaired == true, !name.localizedCaseInsensitiveContains("sdh") {
            name += " · SDH"
        }
        return name
    }
}
