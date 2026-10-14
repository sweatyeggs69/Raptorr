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

    func reload(section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        items = []
        totalSize = nil
        await loadNextPage(section: section, server: server, client: client)
    }

    /// Loads the next page once the user scrolls near the end of what is loaded.
    func itemAppeared(_ item: PlexMetadata, section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        guard let index = items.firstIndex(of: item), index >= items.count - 20 else { return }
        await loadNextPage(section: section, server: server, client: client)
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
