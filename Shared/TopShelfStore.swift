import Foundation

/// The Continue Watching snapshot and its artwork, kept in the App Group container the app
/// and the Top Shelf extension share. The app writes it; the extension only reads it, so the
/// extension never needs the Plex token or a server connection.
nonisolated enum TopShelfStore {
    static let appGroup = "group.com.kylemcclain.Raptorr"

    /// `TopShelf/` in the shared container; `nil` if the App Group entitlement is missing.
    static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: "TopShelf", directoryHint: .isDirectory)
    }

    static var imagesDirectory: URL? {
        directory?.appending(path: "Images", directoryHint: .isDirectory)
    }

    private static var snapshotURL: URL? {
        directory?.appending(path: "snapshot.json")
    }

    static func imageURL(fileName: String) -> URL? {
        imagesDirectory?.appending(path: fileName)
    }

    static func read() -> TopShelfSnapshot? {
        guard let snapshotURL, let data = try? Data(contentsOf: snapshotURL) else { return nil }
        return try? JSONDecoder().decode(TopShelfSnapshot.self, from: data)
    }

    static func write(_ snapshot: TopShelfSnapshot) throws {
        guard let snapshotURL, let directory else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(snapshot).write(to: snapshotURL, options: .atomic)
    }

    /// Removes the snapshot and all artwork, so the Top Shelf falls back to the static image.
    static func clear() {
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
