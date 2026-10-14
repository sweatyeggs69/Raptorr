import Foundation

/// A selectable audio or subtitle track, as reported by VLC.
nonisolated struct TrackOption: Identifiable, Hashable {
    let id: String
    let name: String
    let isSelected: Bool
}
