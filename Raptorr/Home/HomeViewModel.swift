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
    /// The row holding the focused card, kept at the bottom of the screen.
    var activeRowID: String?

    /// Logo lookups by the rating key that carries the logo; `nil` means the item has none.
    @ObservationIgnored private var logoCache: [String: String?] = [:]
    @ObservationIgnored private var logoTask: Task<Void, Never>?

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

    /// Rows above the active one scroll out of view behind the header.
    func isAboveActiveRow(_ row: HomeRow) -> Bool {
        let rows = rows
        guard let active = rows.firstIndex(where: { $0.id == activeRowID }),
              let index = rows.firstIndex(where: { $0.id == row.id }) else { return false }
        return index < active
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
        if focusedItem == nil, let row = rows.first, let first = row.items.first {
            focus(first, inRow: row.id, server: server, client: client)
        }
    }

    /// Shows the item in the header and fetches its logo, which list responses leave out.
    func focus(_ item: PlexMetadata, inRow rowID: String, server: PlexServer, client: PlexAPIClient) {
        focusedItem = item
        activeRowID = rowID
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
            let cachedItem = try? await client.metadata(server: server, ratingKey: logoKey, from: .cache)
            let logo: String?
            if let cachedItem {
                logo = cachedItem.logoPath
            } else {
                logo = try? await client.metadata(server: server, ratingKey: logoKey)?.logoPath
            }
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
