import Foundation
import Observation

@Observable
final class LibraryViewModel {
    private(set) var items: [PlexMetadata] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var totalSize: Int?
    private let pageSize = 100

    private var hasMore: Bool {
        guard let totalSize else { return items.isEmpty }
        return items.count < totalSize
    }

    /// Shows the cached pages right away, then refreshes everything loaded from the server.
    func load(section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        if items.isEmpty {
            await restoreCachedPages(section: section, server: server, client: client)
        }
        await refreshLoadedPages(section: section, server: server, client: client)
    }

    /// Loads the next page once the user scrolls near the end of what is loaded.
    func itemAppeared(_ item: PlexMetadata, section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        guard let index = items.firstIndex(of: item), index >= items.count - 20 else { return }
        await loadNextPage(section: section, server: server, client: client)
    }

    private func restoreCachedPages(section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        var restored: [PlexMetadata] = []
        var seen = Set<String>()
        var total: Int?
        while let page = try? await client.sectionItems(
            server: server,
            section: section,
            start: restored.count,
            size: pageSize,
            from: .cache
        ) {
            // Pages cached at different times can overlap if the library changed in between.
            restored += page.items.filter { seen.insert($0.ratingKey).inserted }
            total = page.totalSize
            if page.items.count < pageSize { break }
        }
        guard !restored.isEmpty else { return }
        items = restored
        totalSize = total
    }

    /// Re-fetches as many pages as are on screen (at least one) and swaps them in at once,
    /// so the grid doesn't shrink while the user is scrolling it.
    private func refreshLoadedPages(section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let target = max(items.count, pageSize)
        var fresh: [PlexMetadata] = []
        var total: Int?
        do {
            while fresh.count < target {
                let page = try await client.sectionItems(server: server, section: section, start: fresh.count, size: pageSize)
                fresh += page.items
                total = page.totalSize
                if page.items.count < pageSize {
                    total = total ?? fresh.count
                    break
                }
            }
            if fresh != items { items = fresh }
            totalSize = total
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadNextPage(section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await client.sectionItems(server: server, section: section, start: items.count, size: pageSize)
            items.append(contentsOf: page.items)
            totalSize = page.totalSize ?? (page.items.count < pageSize ? items.count : nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
