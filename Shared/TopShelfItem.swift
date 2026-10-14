import Foundation

/// One Continue Watching item as the Top Shelf shows it.
nonisolated struct TopShelfItem: Codable, Sendable, Hashable {
    /// The item's rating key, unique within the snapshot.
    let identifier: String
    let title: String
    /// The 16:9 artwork's file name in `TopShelfStore.imagesDirectory`, when it downloaded.
    let imageFileName: String?
    /// Fraction watched, drawn as a progress bar under the artwork.
    let progress: Double?
    /// Opens the item's page in the app.
    let displayURL: URL
    /// Resumes playback in the app.
    let playURL: URL
}
