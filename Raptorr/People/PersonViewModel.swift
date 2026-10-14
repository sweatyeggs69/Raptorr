import Foundation
import Observation

@Observable
final class PersonViewModel {
    private(set) var person: PlexTag
    private(set) var media: [PlexMetadata] = []
    private(set) var isLoading = false
    /// The lead of the person's Wikipedia article, when the server has no bio.
    private(set) var wikipediaBiography: String?

    /// The server's bio if it sent one, else Wikipedia's.
    var biography: String? {
        if let summary = person.summary, !summary.isEmpty { return summary }
        return wikipediaBiography
    }

    init(person: PlexTag) {
        self.person = person
    }

    var movies: [PlexMetadata] { media.filter { $0.kind == .movie } }
    var shows: [PlexMetadata] { media.filter { $0.kind == .show || $0.kind == .episode } }

    /// Fills the page from cache first, then refreshes from the server.
    func load(server: PlexServer, client: PlexAPIClient) async {
        guard let id = person.personID else { return }
        isLoading = true
        defer { isLoading = false }
        if let cached = try? await client.person(server: server, id: id, from: .cache) {
            person = merged(cached)
        }
        if media.isEmpty, let cached = try? await client.personMedia(server: server, id: id, from: .cache) {
            media = cached
        }
        if let fresh = try? await client.person(server: server, id: id) {
            person = merged(fresh)
        }
        if let fresh = try? await client.personMedia(server: server, id: id), fresh != media {
            media = fresh
        }
        if biography == nil, let name = person.tag {
            wikipediaBiography = await WikipediaClient.shared.biography(for: name)
        }
    }

    /// Keeps what the cast row already knew (photo, character) when the person record lacks it.
    private func merged(_ loaded: PlexTag) -> PlexTag {
        PlexTag(
            id: loaded.id ?? person.id,
            tag: loaded.tag ?? person.tag,
            tagKey: loaded.tagKey ?? person.tagKey,
            role: person.role,
            thumb: loaded.thumb ?? person.thumb,
            summary: loaded.summary ?? person.summary
        )
    }
}
