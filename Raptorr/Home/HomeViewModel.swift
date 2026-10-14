import Foundation
import Observation

@Observable
final class HomeViewModel {
    private(set) var continueWatching: [PlexMetadata] = []
    private(set) var shelves: [Hub] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The card the user is on, described in the header above the rows.
    private(set) var focusedItem: PlexMetadata?
    private(set) var focusedLogoPath: String?

    /// Logo lookups by the rating key that carries the logo; `nil` means the item has none.
    @ObservationIgnored private var logoCache: [String: String?] = [:]
    @ObservationIgnored private var logoTask: Task<Void, Never>?

    var isEmpty: Bool { continueWatching.isEmpty && shelves.isEmpty }

    /// Continue Watching first, then each library's own hubs (Recently Added, etc.).
    func load(sections: [LibrarySection], server: PlexServer, client: PlexAPIClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let continueHubs = try await client.continueWatching(server: server)
            continueWatching = continueHubs.flatMap(\.items)
            var result: [Hub] = []
            for section in sections {
                let hubs = (try? await client.sectionHubs(server: server, sectionKey: section.key)) ?? []
                result += hubs.filter { !$0.items.isEmpty && !Self.isInProgressHub($0) }
            }
            shelves = result
            errorMessage = nil
            if focusedItem == nil, let first = continueWatching.first ?? shelves.first?.items.first {
                focus(first, server: server, client: client)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Shows the item in the header and fetches its logo, which list responses leave out.
    func focus(_ item: PlexMetadata, server: PlexServer, client: PlexAPIClient) {
        focusedItem = item
        let logoKey = item.logoSourceRatingKey
        logoTask?.cancel()
        if let cached = logoCache[logoKey] {
            focusedLogoPath = cached
            return
        }
        focusedLogoPath = nil
        logoTask = Task {
            // Skip lookups for cards the user only passes over.
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let logo = try? await client.metadata(server: server, ratingKey: logoKey)?.logoPath
            guard !Task.isCancelled else { return }
            logoCache[logoKey] = logo
            if focusedItem?.logoSourceRatingKey == logoKey {
                focusedLogoPath = logo
            }
        }
    }

    /// Per-library "On Deck"/"Continue Watching" hubs repeat the global Continue Watching row.
    private static func isInProgressHub(_ hub: Hub) -> Bool {
        let identifier = (hub.hubIdentifier ?? "").lowercased()
        return ["inprogress", "ondeck", "continuewatching"].contains { identifier.contains($0) }
    }
}
