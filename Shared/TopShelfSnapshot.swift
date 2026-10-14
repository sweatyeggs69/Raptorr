import Foundation

/// What the Top Shelf extension shows: the app's Continue Watching row, saved by the app.
nonisolated struct TopShelfSnapshot: Codable, Sendable, Hashable {
    var items: [TopShelfItem]
}
