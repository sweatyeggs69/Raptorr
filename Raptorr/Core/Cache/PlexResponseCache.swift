import CryptoKit
import Foundation

/// Keeps the last server response for library requests so screens can show it instantly
/// while the fresh copy loads.
///
/// Raw response bodies are stored, so a cached value decodes exactly like a live one.
/// Entries live in memory and in Caches, which tvOS may purge at any time; a miss just
/// means the next network response fills it again.
actor PlexResponseCache {
    static let shared = PlexResponseCache()

    private let directory: URL?
    private var memory: [String: Data] = [:]

    init(directory: URL? = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
        .appending(path: "PlexResponses", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func data(for key: Key) -> Data? {
        let name = key.fileName
        if let data = memory[name] { return data }
        guard let url = fileURL(for: key), let data = try? Data(contentsOf: url) else { return nil }
        memory[name] = data
        return data
    }

    func store(_ data: Data, for key: Key) {
        memory[key.fileName] = data
        guard let url = fileURL(for: key) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    /// Drops everything, e.g. on sign out.
    func removeAll() {
        memory.removeAll()
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func fileURL(for key: Key) -> URL? {
        directory?
            .appending(path: key.serverID, directoryHint: .isDirectory)
            .appending(path: key.fileName)
    }

    /// Identifies a request independently of the connection URI and token, so a response
    /// cached over the local address is still found when connected remotely.
    nonisolated struct Key: Hashable, Sendable {
        let serverID: String
        let request: String

        init(serverID: String, path: String, query: [URLQueryItem], page: (start: Int, size: Int)?) {
            self.serverID = serverID
            var request = path
            let pairs = query.map { "\($0.name)=\($0.value ?? "")" }.sorted()
            if !pairs.isEmpty { request += "?" + pairs.joined(separator: "&") }
            if let page { request += "#\(page.start)+\(page.size)" }
            self.request = request
        }

        var fileName: String {
            let digest = SHA256.hash(data: Data((serverID + request).utf8))
            return digest.map { String(format: "%02x", $0) }.joined() + ".json"
        }
    }
}
