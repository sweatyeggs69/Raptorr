import Foundation

/// One row on Home: Continue Watching or a library hub.
struct HomeRow: Identifiable {
    let id: String
    let title: String
    let items: [PlexMetadata]
    let style: ShelfStyle
}
