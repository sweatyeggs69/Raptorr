import Foundation
import TVServices

/// Saves Continue Watching for the Top Shelf extension: each item's 16:9 artwork goes to the
/// shared App Group container as a file, so the extension needs no token or server, and the
/// system is told to reload the Top Shelf when the row changed.
nonisolated struct TopShelfPublisher: Sendable {
    let client: PlexAPIClient

    /// The Top Shelf's sectioned row shows only a handful of cards.
    static let maxItems = 12
    /// 16:9, large enough for the Top Shelf's cards on a 4K screen.
    private static let imageSize = (width: 1280, height: 720)

    func publish(_ items: [PlexMetadata], server: PlexServer) async {
        guard let imagesDirectory = TopShelfStore.imagesDirectory else {
            TopShelfStore.log("no App Group container; check the App Groups capability on the Raptorr target")
            return
        }
        do {
            try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        } catch {
            TopShelfStore.log("couldn't create the artwork folder: \(error)")
            return
        }

        var shelfItems: [TopShelfItem] = []
        for item in items.prefix(Self.maxItems) {
            guard let displayURL = TopShelfLink(action: .show, machineIdentifier: server.machineIdentifier, ratingKey: item.ratingKey).url,
                  let playURL = TopShelfLink(action: .play, machineIdentifier: server.machineIdentifier, ratingKey: item.ratingKey).url
            else { continue }
            let imageFileName = await downloadImage(for: item, server: server, into: imagesDirectory)
            shelfItems.append(TopShelfItem(
                identifier: item.ratingKey,
                title: Self.title(for: item),
                imageFileName: imageFileName,
                progress: item.progress,
                displayURL: displayURL,
                playURL: playURL
            ))
        }
        guard !Task.isCancelled else { return }

        let snapshot = TopShelfSnapshot(items: shelfItems)
        removeImages(notIn: snapshot, from: imagesDirectory)
        if snapshot != TopShelfStore.read() {
            do {
                try TopShelfStore.write(snapshot)
            } catch {
                TopShelfStore.log("couldn't save snapshot: \(error)")
                return
            }
        }
        let imageCount = shelfItems.filter { $0.imageFileName != nil }.count
        TopShelfStore.log("saved \(shelfItems.count) items (\(imageCount) with artwork)")
        // Asked every time, not only on a change, in case the system missed an earlier one.
        await Self.reloadTopShelf()
    }

    /// Clears the Top Shelf on sign out or a server switch.
    static func clear() async {
        TopShelfStore.clear()
        await reloadTopShelf()
    }

    @MainActor
    private static func reloadTopShelf() {
        TVTopShelfContentProvider.topShelfContentDidChange()
    }

    /// "Show · S2E5" for episodes, the title otherwise.
    static func title(for item: PlexMetadata) -> String {
        guard item.kind == .episode, let show = item.grandparentTitle else { return item.title }
        return [show, item.shortEpisodeLabel].compactMap { $0 }.joined(separator: " · ")
    }

    /// Downloads the card's artwork unless it's already saved. Returns its file name, or `nil`
    /// when the item has no artwork or the download failed.
    private func downloadImage(for item: PlexMetadata, server: PlexServer, into directory: URL) async -> String? {
        let fileName = Self.imageFileName(for: item)
        let fileURL = directory.appending(path: fileName)
        if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) { return fileName }
        guard let url = client.artworkURL(
            server: server,
            path: item.landscapeImagePath,
            width: Self.imageSize.width,
            height: Self.imageSize.height
        ) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else { return nil }
            try data.write(to: fileURL, options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    /// Named by the artwork path too, so new artwork for the same item downloads again.
    private static func imageFileName(for item: PlexMetadata) -> String {
        let path = item.landscapeImagePath ?? ""
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in path.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01b3
        }
        return "\(item.ratingKey)-\(String(hash, radix: 16)).jpg"
    }

    private func removeImages(notIn snapshot: TopShelfSnapshot, from directory: URL) {
        let keep = Set(snapshot.items.compactMap(\.imageFileName))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))) ?? []
        for file in files where !keep.contains(file) {
            try? FileManager.default.removeItem(at: directory.appending(path: file))
        }
    }
}
