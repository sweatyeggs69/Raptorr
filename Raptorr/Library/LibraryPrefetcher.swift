import Foundation

/// Warms the response cache for every movie and show in the background, so a detail page
/// opens from cache instead of waiting on the server.
///
/// Per library it caches the title list (the same pages `LibraryViewModel` reads), every
/// title's full metadata in batches, and for shows the seasons plus the episodes of the
/// season the show page opens on. A full pass runs at most every few hours per server.
nonisolated struct LibraryPrefetcher: Sendable {
    let client: PlexAPIClient

    /// Matches `LibraryViewModel`'s page size so the cached pages line up with its requests.
    private static let pageSize = 100
    private static let metadataBatchSize = 50
    private static let minimumInterval: TimeInterval = 6 * 60 * 60

    private static let lastRunKeyPrefix = "libraryPrefetch.lastRun."

    /// Forgets when each server was last prefetched, so the next launch warms the cache again.
    static func resetSchedule() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(lastRunKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
    }

    /// Whether a full pass has ever finished for this server (since the cache was last cleared).
    static func hasRun(for server: PlexServer) -> Bool {
        UserDefaults.standard.object(forKey: lastRunKeyPrefix + server.machineIdentifier) != nil
    }

    /// Whether a pass is due: never run, or the last one is older than the minimum interval.
    static func isDue(for server: PlexServer) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: lastRunKeyPrefix + server.machineIdentifier) as? Date else {
            return true
        }
        return Date.now.timeIntervalSince(last) >= minimumInterval
    }

    /// Runs a full pass when one is due. Returns whether it ran to the end.
    @discardableResult
    func run(sections: [LibrarySection], server: PlexServer) async -> Bool {
        let defaultsKey = Self.lastRunKeyPrefix + server.machineIdentifier
        guard Self.isDue(for: server) else { return false }
        for section in sections {
            guard !Task.isCancelled else { return false }
            let items = await allItems(in: section, server: server)
            for start in stride(from: 0, to: items.count, by: Self.metadataBatchSize) {
                guard !Task.isCancelled else { return false }
                let batch = items[start..<min(start + Self.metadataBatchSize, items.count)]
                try? await client.cacheMetadata(server: server, ratingKeys: batch.map(\.ratingKey))
            }
            if section.type == .show {
                for show in items {
                    guard !Task.isCancelled else { return false }
                    await cacheSeasons(of: show, server: server)
                }
            }
        }
        guard !Task.isCancelled else { return false }
        UserDefaults.standard.set(Date.now, forKey: defaultsKey)
        return true
    }

    private func allItems(in section: LibrarySection, server: PlexServer) async -> [PlexMetadata] {
        var items: [PlexMetadata] = []
        while !Task.isCancelled,
              let page = try? await client.sectionItems(
                  server: server,
                  section: section,
                  start: items.count,
                  size: Self.pageSize
              ) {
            items += page.items
            if page.items.count < Self.pageSize { break }
        }
        return items
    }

    /// Seasons, then the episodes of the season `ShowDetailViewModel` opens on first.
    private func cacheSeasons(of show: PlexMetadata, server: PlexServer) async {
        guard let seasons = try? await client.children(server: server, ratingKey: show.ratingKey) else { return }
        let opening = seasons.first { !$0.isWatched && ($0.index ?? 0) > 0 } ?? seasons.first
        if let opening {
            _ = try? await client.children(server: server, ratingKey: opening.ratingKey)
        }
    }
}
