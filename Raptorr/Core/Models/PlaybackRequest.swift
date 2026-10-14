import Foundation

nonisolated struct PlaybackRequest: Identifiable, Hashable, Sendable {
    let id = UUID()
    let item: PlexMetadata
    /// Where to start, in milliseconds. `nil` plays from the beginning.
    let startOffsetMs: Int?
}
