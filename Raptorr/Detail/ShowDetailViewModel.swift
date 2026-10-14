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

    func load(server: PlexServer, client: PlexAPIClient) async {
        let showKey = initialItem.kind == .season ? (initialItem.parentRatingKey ?? initialItem.ratingKey) : initialItem.ratingKey
        do {
            let show = try await client.metadata(server: server, ratingKey: showKey)
            self.show = show

            if show?.skipChildren == true {
                // Shows without a season level list their episodes directly.
                seasons = []
                episodes = try await client.grandchildren(server: server, ratingKey: showKey)
                return
            }

            seasons = try await client.children(server: server, ratingKey: showKey)
            let initialKey = initialItem.ratingKey
            let preferred = initialItem.kind == .season
                ? seasons.first(where: { $0.ratingKey == initialKey })
                : seasons.first(where: { !$0.isWatched && ($0.index ?? 0) > 0 })
            if let season = preferred ?? seasons.first {
                await select(season: season, server: server, client: client)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(season: PlexMetadata, server: PlexServer, client: PlexAPIClient) async {
        selectedSeason = season
        isLoadingEpisodes = true
        defer { isLoadingEpisodes = false }
        do {
            let loaded = try await client.children(server: server, ratingKey: season.ratingKey)
            // Ignore a stale response if the user already picked another season.
            guard selectedSeason?.ratingKey == season.ratingKey else { return }
            episodes = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleWatched(_ episode: PlexMetadata, server: PlexServer, client: PlexAPIClient) async {
        if episode.isWatched {
            await client.unscrobble(server: server, ratingKey: episode.ratingKey)
        } else {
            await client.scrobble(server: server, ratingKey: episode.ratingKey)
        }
        if let season = selectedSeason {
            await select(season: season, server: server, client: client)
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
