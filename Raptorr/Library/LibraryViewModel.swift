import Foundation
import Observation

@Observable
final class LibraryViewModel {
    private(set) var items: [PlexMetadata] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// The jump bar's letters, from the server's first-character counts.
    private(set) var letters: [LetterJump] = []

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

    func loadLetters(section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        if letters.isEmpty, let cached = try? await client.firstCharacters(server: server, section: section, from: .cache) {
            letters = LetterJump.make(from: cached)
        }
        do {
            letters = LetterJump.make(from: try await client.firstCharacters(server: server, section: section))
        } catch {
            #if DEBUG
            print("[Library] firstCharacters failed for section \(section.key): \(error)")
            #endif
        }
    }

    /// Makes sure the letter's first title is loaded and returns its id to scroll to.
    func jump(to letter: LetterJump, section: LibrarySection, server: PlexServer, client: PlexAPIClient) async -> String? {
        // A page load may be in flight; let it land so this one starts after it.
        while isLoading {
            try? await Task.sleep(for: .milliseconds(50))
        }
        if items.count <= letter.offset, hasMore {
            await loadThrough(index: letter.offset, section: section, server: server, client: client)
        }
        guard items.indices.contains(letter.offset) else { return nil }
        return items[letter.offset].id
    }

    /// Loads everything up to `index` in one request, so a jump far down the alphabet doesn't
    /// page through the whole library. The size stays a multiple of the page size so later
    /// pages keep lining up.
    private func loadThrough(index: Int, section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        isLoading = true
        defer { isLoading = false }
        let start = items.count
        let size = ((index - start) / pageSize + 1) * pageSize
        do {
            let page = try await client.sectionItems(server: server, section: section, start: start, size: size)
            items.append(contentsOf: page.items)
            totalSize = page.totalSize ?? (page.items.count < size ? items.count : nil)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
