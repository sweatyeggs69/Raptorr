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

    func run(sections: [LibrarySection], server: PlexServer) async {
        let defaultsKey = "libraryPrefetch.lastRun.\(server.machineIdentifier)"
        if let last = UserDefaults.standard.object(forKey: defaultsKey) as? Date,
           Date.now.timeIntervalSince(last) < Self.minimumInterval {
            return
        }
        for section in sections {
            guard !Task.isCancelled else { return }
            let items = await allItems(in: section, server: server)
            for start in stride(from: 0, to: items.count, by: Self.metadataBatchSize) {
                guard !Task.isCancelled else { return }
                let batch = items[start..<min(start + Self.metadataBatchSize, items.count)]
                try? await client.cacheMetadata(server: server, ratingKeys: batch.map(\.ratingKey))
            }
            if section.type == .show {
                for show in items {
                    guard !Task.isCancelled else { return }
                    await cacheSeasons(of: show, server: server)
                }
            }
        }
        guard !Task.isCancelled else { return }
        UserDefaults.standard.set(Date.now, forKey: defaultsKey)
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
