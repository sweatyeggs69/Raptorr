import Foundation

/// A selectable audio or subtitle track: VLC's track, labelled with Plex's stream info when
/// the two lists line up.
nonisolated struct TrackOption: Identifiable, Hashable, Sendable {
    /// VLC's track identifier.
    let id: String
    let name: String
    let isSelected: Bool
    var languageCode: String? = nil
    var isForced = false
    /// The matching Plex stream, used to save the choice back to the server.
    var plexStreamID: Int? = nil
    /// Whether the server has this stream marked as the user's preferred choice.
    var isPlexSelected = false
}
