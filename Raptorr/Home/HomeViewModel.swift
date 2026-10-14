import Foundation
import Observation

@Observable
final class HomeViewModel {
    private(set) var shelves: [Hub] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// Continue Watching first, then each library's own hubs (Recently Added, etc.).
    func load(sections: [LibrarySection], server: PlexServer, client: PlexAPIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            var result = try await client.continueWatching(server: server).filter { !$0.items.isEmpty }
            for section in sections {
                let hubs = (try? await client.sectionHubs(server: server, sectionKey: section.key)) ?? []
                result += hubs.filter { !$0.items.isEmpty && !Self.isInProgressHub($0) }
            }
            shelves = result
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Per-library "On Deck"/"Continue Watching" hubs repeat the global Continue Watching shelf.
    private static func isInProgressHub(_ hub: Hub) -> Bool {
        let identifier = (hub.hubIdentifier ?? "").lowercased()
        return ["inprogress", "ondeck", "continuewatching"].contains { identifier.contains($0) }
    }
}
