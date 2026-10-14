import Foundation
import Observation

@Observable
final class ShowDetailViewModel {
    private(set) var show: PlexMetadata?
    private(set) var seasons: [PlexMetadata] = []
    private(set) var selectedSeason: PlexMetadata?
    private(set) var episodes: [PlexMetadata] = []
    private(set) var isLoadingEpisodes = false
    private(set) var errorMessage: String?

    private let initialItem: PlexMetadata
    @ObservationIgnored private var episodesTask: Task<Void, Never>?
    /// Every season's episodes seen so far, so switching back to a season is instant.
    @ObservationIgnored private var episodesBySeason: [String: [PlexMetadata]] = [:]

    init(item: PlexMetadata) {
        initialItem = item
    }

    var displayItem: PlexMetadata { show ?? initialItem }

    /// The episode "Play" should start: the first one in progress or unwatched.
    var nextEpisode: PlexMetadata? {
        episodes.first { $0.progress != nil } ?? episodes.first { !$0.isWatched } ?? episodes.first
    }

    /// Shows the cached show, seasons and episodes right away, then the server's.
    func load(server: PlexServer, client: PlexAPIClient) async {
        if show == nil {
            try? await loadShow(server: server, client: client, from: .cache)
        }
        do {
            try await loadShow(server: server, client: client, from: .network)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        await prefetch(server: server, client: client)
    }

    /// Loads the rest of the show ahead of time: the current season's stills into memory,
    /// then every other season's episodes and their stills to disk, so switching seasons and
    /// scrolling never waits on the server. Runs in the view's task, so it stops when the
    /// page closes.
    private func prefetch(server: PlexServer, client: PlexAPIClient) async {
        let loader = ImageLoader.shared
        let current = stillURLs(for: episodes, server: server, client: client)
        await loader.prefetch(Array(current.prefix(Self.decodedPrefetchLimit)), decode: true)
        await loader.prefetch(Array(current.dropFirst(Self.decodedPrefetchLimit)), decode: false)

        for season in seasons where season.ratingKey != selectedSeason?.ratingKey {
            guard !Task.isCancelled else { return }
            guard let loaded = try? await client.children(server: server, ratingKey: season.ratingKey, from: .network) else {
                continue
            }
            episodesBySeason[season.ratingKey] = loaded
            await loader.prefetch(stillURLs(for: loaded, server: server, client: client), decode: false)
        }
    }

    /// How many stills go straight into memory; the rest wait on disk.
    private static let decodedPrefetchLimit = 40

    private func stillURLs(for episodes: [PlexMetadata], server: PlexServer, client: PlexAPIClient) -> [URL] {
        episodes.compactMap {
            client.artworkURL(server: server, path: $0.thumb, width: EpisodeRow.stillPixelWidth, height: EpisodeRow.stillPixelHeight)
        }
    }

    /// Switches season right away and loads its episodes in the background. Moving focus
    /// across the season picker selects each season in turn, so a newer pick cancels the
    /// older load instead of letting it land late and flip the picker back.
    func select(season: PlexMetadata, server: PlexServer, client: PlexAPIClient) {
        guard season.ratingKey != selectedSeason?.ratingKey else { return }
        selectedSeason = season
        if let known = episodesBySeason[season.ratingKey], known != episodes {
            episodes = known
        }
        episodesTask?.cancel()
        episodesTask = Task {
            isLoadingEpisodes = true
            defer { if !Task.isCancelled { isLoadingEpisodes = false } }
            try? await loadEpisodes(of: season, server: server, client: client, from: .cache)
            do {
                try await loadEpisodes(of: season, server: server, client: client, from: .network)
            } catch {
                if !Task.isCancelled { errorMessage = error.localizedDescription }
            }
        }
    }

    private func loadShow(server: PlexServer, client: PlexAPIClient, from source: DataSource) async throws {
        let showKey = initialItem.kind == .season ? (initialItem.parentRatingKey ?? initialItem.ratingKey) : initialItem.ratingKey
        let show = try await client.metadata(server: server, ratingKey: showKey, from: source)
        self.show = show

        if show?.skipChildren == true {
            // Shows without a season level list their episodes directly.
            seasons = []
            let loaded = try await client.grandchildren(server: server, ratingKey: showKey, from: source)
            if loaded != episodes { episodes = loaded }
            return
        }

        let loadedSeasons = try await client.children(server: server, ratingKey: showKey, from: source)
        if loadedSeasons != seasons { seasons = loadedSeasons }
        // Stay on the season the user is looking at; otherwise open the requested season,
        // or the first one with something left to watch.
        let current = selectedSeason.flatMap { selected in seasons.first { $0.ratingKey == selected.ratingKey } }
        let initialKey = initialItem.ratingKey
        let preferred = initialItem.kind == .season
            ? seasons.first(where: { $0.ratingKey == initialKey })
            : seasons.first(where: { !$0.isWatched && ($0.index ?? 0) > 0 })
        if let season = current ?? preferred ?? seasons.first {
            selectedSeason = season
            try await loadEpisodes(of: season, server: server, client: client, from: source)
        }
    }

    private func loadEpisodes(of season: PlexMetadata, server: PlexServer, client: PlexAPIClient, from source: DataSource) async throws {
        let loaded = try await client.children(server: server, ratingKey: season.ratingKey, from: source)
        episodesBySeason[season.ratingKey] = loaded
        // Ignore a stale response if the user already picked another season.
        guard !Task.isCancelled, selectedSeason?.ratingKey == season.ratingKey else { return }
        if loaded != episodes { episodes = loaded }
    }

    func toggleWatched(_ episode: PlexMetadata, server: PlexServer, client: PlexAPIClient) async {
        if episode.isWatched {
            await client.unscrobble(server: server, ratingKey: episode.ratingKey)
        } else {
            await client.scrobble(server: server, ratingKey: episode.ratingKey)
        }
        if let season = selectedSeason {
            try? await loadEpisodes(of: season, server: server, client: client, from: .network)
        }
    }

    var metadataLine: String {
        let item = displayItem
        var parts: [String] = []
        if let year = item.year { parts.append(String(year)) }
        if let contentRating = item.contentRating { parts.append(contentRating) }
        if !seasons.isEmpty { parts.append(seasons.count == 1 ? "1 Season" : "\(seasons.count) Seasons") }
        if let studio = item.studio { parts.append(studio) }
        return parts.joined(separator: " · ")
    }
}
