import Foundation
import Observation

@Observable
final class ItemDetailViewModel {
    private(set) var item: PlexMetadata
    /// Episodes use their show's logo, which only the show's own metadata carries.
    private(set) var showLogoPath: String?

    init(item: PlexMetadata) {
        self.item = item
    }

    /// Hub and list responses are partial, so fetch the full item (media, cast, genres).
    func load(server: PlexServer, client: PlexAPIClient) async {
        if let full = try? await client.metadata(server: server, ratingKey: item.ratingKey) {
            item = full
        }
        if item.kind == .episode, showLogoPath == nil, let showKey = item.grandparentRatingKey {
            showLogoPath = try? await client.metadata(server: server, ratingKey: showKey)?.logoPath
        }
    }

    func toggleWatched(server: PlexServer, client: PlexAPIClient) async {
        if item.isWatched {
            await client.unscrobble(server: server, ratingKey: item.ratingKey)
        } else {
            await client.scrobble(server: server, ratingKey: item.ratingKey)
        }
        await load(server: server, client: client)
    }

    var metadataLine: String { item.infoLine }

    var creditsLine: String? {
        let genres = (item.genre ?? []).compactMap(\.tag).prefix(3)
        let directors = (item.director ?? []).compactMap(\.tag).prefix(2)
        var lines: [String] = []
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
