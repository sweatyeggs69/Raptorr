import Foundation
import Observation

@Observable
final class SearchViewModel {
    var query = ""
    private(set) var results: [Hub] = []
    private(set) var isSearching = false

    /// Only the hub types Plexiglass can open.
    private static let supportedTypes: Set<String> = ["movie", "show", "season", "episode"]

    func search(server: PlexServer, client: PlexAPIClient) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }
        // Debounce typing; a newer query cancels this task.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        isSearching = true
        defer { isSearching = false }
        let hubs = (try? await client.search(server: server, query: trimmed)) ?? []
        guard !Task.isCancelled else { return }
        results = hubs.filter { Self.supportedTypes.contains($0.type ?? "") && !$0.items.isEmpty }
    }
}
