import Foundation

/// Pairs VLC's track lists with the Plex streams of the part being played, and decides which
/// subtitle "Auto" should show.
///
/// VLC lists embedded tracks in container order, then sidecar files in the order they were
/// added, which is the same order Plexiglass builds the Plex list in. When the counts differ the
/// lists can't be paired safely, so VLC's own names are used instead.
nonisolated enum TrackMatching {
    struct VLCTrack: Sendable {
        let id: String
        let name: String
        let isSelected: Bool
    }

    /// Plex audio streams in container order.
    static func plexAudioStreams(in part: PlexPart?) -> [PlexStream] {
        (part?.stream ?? []).filter(\.isAudio).sorted { ($0.index ?? 0) < ($1.index ?? 0) }
    }

    /// Embedded subtitles in container order, then sidecar files in server order.
    static func plexSubtitleStreams(in part: PlexPart?) -> [PlexStream] {
        let subtitles = (part?.stream ?? []).filter(\.isSubtitle)
        let embedded = subtitles.filter { !$0.isExternalSubtitle }.sorted { ($0.index ?? 0) < ($1.index ?? 0) }
        return embedded + subtitles.filter(\.isExternalSubtitle)
    }

    static func options(vlc: [VLCTrack], plex: [PlexStream]) -> [TrackOption] {
        guard vlc.count == plex.count else {
            return vlc.map { TrackOption(id: $0.id, name: $0.name, isSelected: $0.isSelected) }
        }
        return zip(vlc, plex).map { track, stream in
            TrackOption(
                id: track.id,
                name: stream.menuTitle,
                isSelected: track.isSelected,
                languageCode: stream.languageCode,
                isForced: stream.isForced,
                plexStreamID: stream.id,
                isPlexSelected: stream.selected == true
            )
        }
    }

    /// The forced track Auto should show: one in the audio's language, or any forced track
    /// when the audio language is unknown.
    static func forcedTrack(in subtitles: [TrackOption], audioLanguage: String?) -> TrackOption? {
        let forced = subtitles.filter(\.isForced)
        guard let audioLanguage else { return forced.first }
        return forced.first { $0.languageCode == audioLanguage }
            ?? forced.first { $0.languageCode == nil }
    }

    /// Starts on the subtitle the user last picked in Plex, otherwise Auto.
    static func initialSubtitleMode(for subtitles: [TrackOption]) -> SubtitleMode {
        if let preferred = subtitles.first(where: { $0.isPlexSelected && !$0.isForced }) {
            return .track(id: preferred.id)
        }
        return .auto
    }
}
