import Foundation

/// How subtitles are chosen, mirroring the Apple TV app's subtitle menu.
nonisolated enum SubtitleMode: Hashable, Sendable {
    case off
    /// Only forced subtitles (foreign-language dialogue) in the audio's language.
    case auto
    /// A specific track, by VLC track identifier.
    case track(id: String)
}
