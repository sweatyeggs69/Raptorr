import Foundation

/// Warms the response cache for every movie and show in the background, so a detail page
/// opens from cache instead of waiting on the server.
///
/// Per library it caches the title list (the same pages `LibraryViewModel` reads), every
/// title's full metadata in batches, every title's backdrop and logo, and for shows the
/// seasons plus the episodes of the season the show page opens on. A full pass runs at most every few hours per server.
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

    /// Runs a full pass when one is due, or always with `force`. Returns whether it ran to
    /// the end.
    @discardableResult
    func run(sections: [LibrarySection], server: PlexServer, force: Bool = false) async -> Bool {
        let defaultsKey = Self.lastRunKeyPrefix + server.machineIdentifier
        guard force || Self.isDue(for: server) else { return false }
        for section in sections {
            guard !Task.isCancelled else { return false }
            // The title list is always fetched: it's how new and changed titles are found.
            let items = await allItems(in: section, server: server)
            var images = ImageList()

            // Only titles that are new or changed since they were cached get fetched again.
            var cached: [String: PlexMetadata] = [:]
            var stale: [PlexMetadata] = []
            for item in items {
                if let full = try? await client.metadata(server: server, ratingKey: item.ratingKey, from: .cache),
                   Self.isCurrent(full, comparedWith: item) {
                    cached[item.ratingKey] = full
                } else {
                    stale.append(item)
                }
            }
            for start in stride(from: 0, to: stale.count, by: Self.metadataBatchSize) {
                guard !Task.isCancelled else { return false }
                let batch = stale[start..<min(start + Self.metadataBatchSize, stale.count)]
                try? await client.cacheMetadata(server: server, ratingKeys: batch.map(\.ratingKey))
                for item in batch {
                    cached[item.ratingKey] = try? await client.metadata(server: server, ratingKey: item.ratingKey, from: .cache)
                }
            }
            let staleKeys = Set(stale.map(\.ratingKey))

            // Each detail page's backdrop and logo, at the sizes `BackdropView` and
            // `TitleLogo` ask for. Images already on disk are skipped by the prefetch, and
            // changed artwork has a new URL.
            for item in items {
                let full = cached[item.ratingKey] ?? item
                images.add(client.artworkURL(server: server, path: full.backdropPath, width: 1920, height: 1080))
                images.add(client.logoURL(
                    server: server,
                    path: full.logoPath,
                    width: Int(TitleLogo.widthLimit * 2),
                    height: Int(TitleLogo.defaultHeight * 2)
                ))
            }

            // Cast photos at the size the Cast row asks for.
            for item in items {
                for person in cached[item.ratingKey]?.role ?? [] {
                    images.add(client.artworkURL(
                        server: server,
                        path: person.thumb,
                        width: Int(CastCard.portraitSize * 2),
                        height: Int(CastCard.portraitSize * 2)
                    ))
                }
            }
            if section.type == .show {
                for show in items {
                    guard !Task.isCancelled else { return false }
                    // Stills of the episodes the show page opens on, at `EpisodeRow`'s size.
                    let episodes = await cacheSeasons(of: show, server: server, refresh: staleKeys.contains(show.ratingKey))
                    for episode in episodes {
                        images.add(client.artworkURL(
                            server: server,
                            path: episode.thumb,
                            width: EpisodeRow.stillPixelWidth,
                            height: EpisodeRow.stillPixelHeight
                        ))
                    }
                }
            }
            guard !Task.isCancelled else { return false }
            await ImageLoader.shared.prefetch(images.urls, decode: false)
        }
        guard !Task.isCancelled else { return false }
        UserDefaults.standard.set(Date.now, forKey: defaultsKey)
        return true
    }

    /// Downloads every library's posters ahead of time, so the Movies and TV Shows grids
    /// open with artwork in place. Each library's first screens are decoded into memory
    /// first, then everything else goes to disk. Runs on every launch: images already on
    /// disk are skipped.
    func cachePosters(sections: [LibrarySection], server: PlexServer, size: CGSize) async {
        let loader = ImageLoader.shared
        var lists: [[URL]] = []
        for section in sections {
            guard !Task.isCancelled else { return }
            let items = await cachedOrFetchedItems(in: section, server: server)
            lists.append(items.compactMap {
                client.artworkURL(server: server, path: $0.posterPath, width: Int(size.width), height: Int(size.height))
            })
        }
        for urls in lists {
            await loader.prefetch(Array(urls.prefix(Self.decodedPostersPerLibrary)), decode: true)
        }
        for urls in lists {
            guard !Task.isCancelled else { return }
            await loader.prefetch(Array(urls.dropFirst(Self.decodedPostersPerLibrary)), decode: false)
        }
    }

    /// Two screens of the grid; decoding more for every library would crowd out Home's cards.
    private static let decodedPostersPerLibrary = 24

    /// The library's titles from the response cache, or from the server when nothing is cached.
    private func cachedOrFetchedItems(in section: LibrarySection, server: PlexServer) async -> [PlexMetadata] {
        var items: [PlexMetadata] = []
        while let page = try? await client.sectionItems(
            server: server,
            section: section,
            start: items.count,
            size: Self.pageSize,
            from: .cache
        ) {
            items += page.items
            if page.items.count < Self.pageSize { break }
        }
        return items.isEmpty ? await allItems(in: section, server: server) : items
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

    /// Whether the cached metadata is as new as the item in the fresh title list. Without
    /// `updatedAt` on either side it counts as changed. Shows also compare their episode
    /// count, which goes up when episodes are added.
    static func isCurrent(_ cached: PlexMetadata, comparedWith fresh: PlexMetadata) -> Bool {
        guard let cachedDate = cached.updatedAt, let freshDate = fresh.updatedAt else { return false }
        return cachedDate == freshDate && cached.leafCount == fresh.leafCount
    }

    /// Seasons, then the episodes of the season `ShowDetailViewModel` opens on first, which
    /// it returns. An unchanged show reuses what's cached and only asks the server for
    /// anything missing.
    private func cacheSeasons(of show: PlexMetadata, server: PlexServer, refresh: Bool) async -> [PlexMetadata] {
        var seasons = refresh ? nil : try? await client.children(server: server, ratingKey: show.ratingKey, from: .cache)
        // Not `??`: its right side is an autoclosure, which can't await.
        if seasons == nil {
            seasons = try? await client.children(server: server, ratingKey: show.ratingKey)
        }
        guard let seasons,
              let opening = seasons.first(where: { !$0.isWatched && ($0.index ?? 0) > 0 }) ?? seasons.first else {
            return []
        }
        if !refresh, let episodes = try? await client.children(server: server, ratingKey: opening.ratingKey, from: .cache) {
            return episodes
        }
        return (try? await client.children(server: server, ratingKey: opening.ratingKey)) ?? []
    }

    /// Image URLs in order, each once: the same actor appears in many titles.
    private struct ImageList {
        private(set) var urls: [URL] = []
        private var seen = Set<URL>()

        mutating func add(_ url: URL?) {
            guard let url, seen.insert(url).inserted else { return }
            urls.append(url)
        }
    }
}
