import Foundation
import Observation

@Observable
final class HomeViewModel {
    private(set) var continueWatching: [PlexMetadata] = []
    private(set) var shelves: [Hub] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The focused card as the header shows it. Updates only after the card's logo and
    /// backdrop have loaded, so the header crossfades as one unit.
    private(set) var header: HomeHeader?
    /// The row holding the focused card, kept at the bottom of the screen.
    private(set) var activeRowID: String?

    /// Logo lookups by the rating key that carries the logo; `nil` means the item has none.
    @ObservationIgnored private var logoCache: [String: String?] = [:]
    @ObservationIgnored private var headerTask: Task<Void, Never>?

    var isEmpty: Bool { continueWatching.isEmpty && shelves.isEmpty }

    static let continueWatchingRowID = "continueWatching"

    /// Continue Watching as 16:9 cards, then the library hubs as posters.
    var rows: [HomeRow] {
        var rows: [HomeRow] = []
        if !continueWatching.isEmpty {
            rows.append(HomeRow(id: Self.continueWatchingRowID, title: "Continue Watching", items: continueWatching, style: .landscape))
        }
        rows += shelves.map { HomeRow(id: $0.id, title: $0.title ?? "", items: $0.items, style: .poster) }
        return rows
    }

    /// Continue Watching first, then each library's own hubs (Recently Added, etc.).
    /// The cached rows show right away; the server's replace them when they arrive.
    func load(sections: [LibrarySection], server: PlexServer, client: PlexAPIClient) async {
        if isEmpty {
            try? await load(sections: sections, server: server, client: client, from: .cache)
        }
        isLoading = true
        defer { isLoading = false }
        do {
            try await load(sections: sections, server: server, client: client, from: .network)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await prefetchArtwork(server: server, client: client)
    }

    /// Cards decoded into memory per row up front; the rest only go to disk, since every
    /// card decoded at once would overrun the memory cache.
    private static let decodedCardsPerRow = 20

    /// Downloads every Home card's artwork and backdrop ahead of time, so moving quickly along
    /// a row shows images from cache instead of waiting on the server.
    private func prefetchArtwork(server: PlexServer, client: PlexAPIClient) async {
        let loader = ImageLoader.shared
        var decoded: [URL] = []
        var stored: [URL] = []
        var backdrops: [URL] = []
        for row in rows {
            for (index, item) in row.items.enumerated() {
                let artwork = row.style.artwork(for: item)
                if let url = client.artworkURL(server: server, path: artwork.path, width: artwork.width, height: artwork.height) {
                    if index < Self.decodedCardsPerRow { decoded.append(url) } else { stored.append(url) }
                }
                if let url = client.artworkURL(server: server, path: item.backdropPath, width: 1920, height: 1080) {
                    backdrops.append(url)
                }
            }
        }
        await loader.prefetch(decoded, decode: true)
        await loader.prefetch(stored, decode: false)
        await loader.prefetch(backdrops, decode: false)
    }

    private func load(sections: [LibrarySection], server: PlexServer, client: PlexAPIClient, from source: DataSource) async throws {
        let continueHubs = try await client.continueWatching(server: server, from: source)
        var result: [Hub] = []
        for section in sections {
            let hubs = (try? await client.sectionHubs(server: server, sectionKey: section.key, from: source)) ?? []
            result += hubs.filter { !$0.items.isEmpty && !Self.isInProgressHub($0) }
        }
        let items = continueHubs.flatMap(\.items)
        if items != continueWatching { continueWatching = items }
        if result != shelves { shelves = result }
        if activeRowID == nil, let row = rows.first, let first = row.items.first {
            focus(first, inRow: row.id, server: server, client: client)
        }
    }

    /// Shows the item in the header once its logo (which list responses leave out) and
    /// backdrop are ready, so text, logo and artwork change together.
    func focus(_ item: PlexMetadata, inRow rowID: String, server: PlexServer, client: PlexAPIClient) {
        activeRowID = rowID
        let isContinueWatching = rowID == Self.continueWatchingRowID
        let logoKey = item.logoSourceRatingKey
        headerTask?.cancel()
        headerTask = Task {
            let logo: String?
            if let cached = logoCache[logoKey] {
                logo = cached
            } else {
                // Skip lookups for cards the user only passes over.
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                if let cachedItem = try? await client.metadata(server: server, ratingKey: logoKey, from: .cache) {
                    logo = cachedItem.logoPath
                } else {
                    logo = try? await client.metadata(server: server, ratingKey: logoKey)?.logoPath
                }
                guard !Task.isCancelled else { return }
                logoCache[logoKey] = logo
            }

            // Same URLs as `TitleLogo` and `BackdropView`, so both draw straight from memory.
            let logoURL = client.logoURL(
                server: server,
                path: logo,
                width: Int(HeaderLayout.logoWidth * 2),
                height: Int(HeaderLayout.logoHeight * 2)
            )
            let backdropURL = client.artworkURL(server: server, path: item.backdropPath, width: 1920, height: 1080)
            await Self.preload(logoURL: logoURL, backdropURL: backdropURL)
            guard !Task.isCancelled else { return }
            header = HomeHeader(item: item, logoPath: logo, isContinueWatching: isContinueWatching)
        }
    }

    /// Longest the header waits on images before switching anyway, on a slow connection.
    private static let preloadTimeout: Duration = .milliseconds(1500)

    /// Waits until both images are in memory, or the timeout passes.
    private static func preload(logoURL: URL?, backdropURL: URL?) async {
        let timeout = preloadTimeout
        await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                if let logoURL { _ = await ImageLoader.shared.image(for: logoURL) }
                return true
            }
            group.addTask {
                if let backdropURL { _ = await ImageLoader.backdrops.image(for: backdropURL) }
                return true
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            var loaded = 0
            while let finished = await group.next(), finished {
                loaded += 1
                if loaded == 2 { break }
            }
            group.cancelAll()
        }
    }

    /// Per-library "On Deck"/"Continue Watching" hubs repeat the global Continue Watching row.
    private static func isInProgressHub(_ hub: Hub) -> Bool {
        let identifier = (hub.hubIdentifier ?? "").lowercased()
        return ["inprogress", "ondeck", "continuewatching"].contains { identifier.contains($0) }
    }
}
