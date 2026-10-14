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
    /// Posters decoded into memory so far, counted from the top of the grid.
    private var decodedThrough = 0
    private var warmTask: Task<Void, Never>?

    /// Posters kept decoded ahead of the ones on screen. Decoding every poster would overrun
    /// the memory cache, so the rest are only downloaded to disk.
    private static let decodeWindow = 48

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
        guard letters.count <= 1 else { return }
        // No usable counts from the server: load every title and read the letters off them.
        await loadAll(section: section, server: server, client: client)
        letters = LetterJump.make(fromSortedTitles: items.map { $0.titleSort ?? $0.title })
    }

    /// Loads every title, then downloads every poster to disk and decodes the first screens
    /// into memory, so scrolling and letter jumps show artwork straight away.
    func loadEverything(section: LibrarySection, posterSize: CGSize, server: PlexServer, client: PlexAPIClient) async {
        await loadAll(section: section, server: server, client: client)
        guard !Task.isCancelled else { return }
        await warmPosters(from: 0, posterSize: posterSize, server: server, client: client)
        let urls = items.compactMap { posterURL(for: $0, size: posterSize, server: server, client: client) }
        await ImageLoader.shared.prefetch(urls, decode: false)
    }

    /// Decodes the posters from `index` onward into memory, for the grid's next screens.
    func warmPosters(from index: Int, posterSize: CGSize, server: PlexServer, client: PlexAPIClient) async {
        let end = min(index + Self.decodeWindow, items.count)
        guard index < end else { return }
        decodedThrough = max(decodedThrough, end)
        let urls = items[index..<end].compactMap { posterURL(for: $0, size: posterSize, server: server, client: client) }
        await ImageLoader.shared.prefetch(urls, decode: true)
    }

    /// Keeps the posters below the visible ones decoded as the grid scrolls, or around a
    /// letter it jumped to.
    func keepPostersWarm(near index: Int, posterSize: CGSize, server: PlexServer, client: PlexAPIClient, force: Bool = false) {
        guard force || index + Self.decodeWindow / 2 > decodedThrough else { return }
        if force { decodedThrough = 0 }
        warmTask?.cancel()
        warmTask = Task {
            await warmPosters(from: index, posterSize: posterSize, server: server, client: client)
        }
    }

    /// The same request `PosterCard` makes, so the prefetched image is the one it shows.
    private func posterURL(for item: PlexMetadata, size: CGSize, server: PlexServer, client: PlexAPIClient) -> URL? {
        client.artworkURL(server: server, path: item.posterPath, width: Int(size.width), height: Int(size.height))
    }

    private func loadAll(section: LibrarySection, server: PlexServer, client: PlexAPIClient) async {
        while hasMore {
            while isLoading {
                try? await Task.sleep(for: .milliseconds(50))
            }
            let before = items.count
            await loadThrough(index: max((totalSize ?? 0) - 1, before), section: section, server: server, client: client)
            if items.count == before { break }
        }
    }

    /// Makes sure the letter's first title is loaded and returns its id to scroll to.
    func jump(to letter: LetterJump, section: LibrarySection, server: PlexServer, client: PlexAPIClient) async -> String? {
        // Already loaded (the usual case, since the whole library loads on open): jump now
        // rather than waiting on a refresh that may be running.
        if items.indices.contains(letter.offset) {
            return items[letter.offset].id
        }
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
    func itemAppeared(_ item: PlexMetadata, section: LibrarySection, posterSize: CGSize, server: PlexServer, client: PlexAPIClient) async {
        guard let index = items.firstIndex(of: item) else { return }
        keepPostersWarm(near: index, posterSize: posterSize, server: server, client: client)
        guard index >= items.count - 20 else { return }
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
