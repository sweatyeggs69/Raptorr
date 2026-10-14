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
        }
    }

    func select(season: PlexMetadata, server: PlexServer, client: PlexAPIClient) async {
        selectedSeason = season
        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }
        try? await loadEpisodes(of: season, server: server, client: client, from: .cache)
        do {
            try await loadEpisodes(of: season, server: server, client: client, from: .network)
        } catch {
            errorMessage = error.localizedDescription
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
            try await loadEpisodes(of: season, server: server, client: client, from: source)
        }
    }

    private func loadEpisodes(of season: PlexMetadata, server: PlexServer, client: PlexAPIClient, from source: DataSource) async throws {
        selectedSeason = season
        let loaded = try await client.children(server: server, ratingKey: season.ratingKey, from: source)
        // Ignore a stale response if the user already picked another season.
        guard selectedSeason?.ratingKey == season.ratingKey else { return }
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
