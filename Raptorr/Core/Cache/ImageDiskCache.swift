import CryptoKit
import Foundation

/// Downloaded artwork kept in Caches, so images survive relaunches and come back without a
/// trip to the server. tvOS may purge it at any time; a miss just downloads again.
///
/// Entries are keyed by the image request without its host and token, so artwork fetched
/// over the local address is still found when connected remotely or through the relay.
/// Plex artwork paths carry the item's rating key and an update timestamp, so a changed
/// image gets a new key rather than a stale hit.
nonisolated struct ImageDiskCache: Sendable {
    static let shared = ImageDiskCache()

    let directory: URL?

    init(directory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appending(path: "PlexImages", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func data(for url: URL) -> Data? {
        guard let file = fileURL(for: url) else { return nil }
        return try? Data(contentsOf: file)
    }

    func store(_ data: Data, for url: URL) {
        guard let file = fileURL(for: url) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
    }

    func contains(_ url: URL) -> Bool {
        guard let file = fileURL(for: url) else { return false }
        return FileManager.default.fileExists(atPath: file.path(percentEncoded: false))
    }

    /// Drops everything, e.g. on sign out.
    func removeAll() {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// The request minus scheme, host, port and `X-Plex-Token`, with the query sorted.
    static func key(for url: URL) -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        let pairs = (components.queryItems ?? [])
            .filter { $0.name != "X-Plex-Token" }
            .map { "\($0.name)=\($0.value ?? "")" }
            .sorted()
        return pairs.isEmpty ? components.path : components.path + "?" + pairs.joined(separator: "&")
    }

    private func fileURL(for url: URL) -> URL? {
        let digest = SHA256.hash(data: Data(Self.key(for: url).utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory?.appending(path: name)
    }
}
