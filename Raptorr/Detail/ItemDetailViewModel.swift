import Foundation
import Observation

@Observable
final class ItemDetailViewModel {
    private(set) var item: PlexMetadata
    /// Episodes use their show's logo, which only the show's own metadata carries.
    private(set) var showLogoPath: String?
    /// Similar movies, for the "Related" row. Episodes don't get one.
    private(set) var related: [PlexMetadata] = []

    init(item: PlexMetadata) {
        self.item = item
    }

    /// Hub and list responses are partial, so fetch the full item (media, cast, genres).
    /// A cached copy fills the page first.
    func load(server: PlexServer, client: PlexAPIClient) async {
        if let cached = try? await client.metadata(server: server, ratingKey: item.ratingKey, from: .cache) {
            item = cached
        }
        if let full = try? await client.metadata(server: server, ratingKey: item.ratingKey) {
            item = full
        }
        if item.kind == .movie {
            if related.isEmpty, let cached = try? await client.similar(server: server, ratingKey: item.ratingKey, from: .cache) {
                related = cached
            }
            if let loaded = try? await client.similar(server: server, ratingKey: item.ratingKey), loaded != related {
                related = loaded
            }
        }
        if item.kind == .episode, showLogoPath == nil, let showKey = item.grandparentRatingKey {
            let cachedShow = try? await client.metadata(server: server, ratingKey: showKey, from: .cache)
            showLogoPath = cachedShow?.logoPath
            if showLogoPath == nil {
                showLogoPath = try? await client.metadata(server: server, ratingKey: showKey)?.logoPath
            }
        }
    }

    /// Re-reads the item after the player closes. The player's final timeline report is
    /// still in flight then, so this waits briefly first.
    func refreshAfterPlayback(server: PlexServer, client: PlexAPIClient) async {
        try? await Task.sleep(for: .seconds(1))
        if let full = try? await client.metadata(server: server, ratingKey: item.ratingKey) {
            item = full
        }
    }

    func toggleWatched(server: PlexServer, client: PlexAPIClient) async {
        if item.isWatched {
            await client.unscrobble(server: server, ratingKey: item.ratingKey)
        } else {
            await client.scrobble(server: server, ratingKey: item.ratingKey)
        }
        if let full = try? await client.metadata(server: server, ratingKey: item.ratingKey) {
            item = full
        }
    }

    var cast: [PlexTag] { item.role ?? [] }

    var creditsLine: String? {
        let genres = (item.genre ?? []).compactMap(\.tag).prefix(3)
        let directors = (item.director ?? []).compactMap(\.tag).prefix(2)
        var lines: [String] = []
        // S#E# (episodes), year and rating lead the line; the runtime sits by the buttons.
        let info = [item.episodeLabel, item.year.map(String.init), item.contentRating].compactMap { $0 }
        if !info.isEmpty { lines.append(info.joined(separator: " · ")) }
        if !genres.isEmpty { lines.append(genres.joined(separator: ", ")) }
        if !directors.isEmpty { lines.append("Directed by " + directors.joined(separator: ", ")) }
        return lines.isEmpty ? nil : lines.joined(separator: "  ·  ")
    }

    var resumeText: String? {
        guard let offset = item.viewOffset, offset > 0 else { return nil }
        let minutes = offset / 60_000
        return minutes >= 60 ? "Resume from \(minutes / 60)h \(minutes % 60)m" : "Resume from \(minutes)m"
    }
}
