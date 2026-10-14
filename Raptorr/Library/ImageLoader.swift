import UIKit

/// Loads artwork from memory, then disk, then the server, and shares one download between
/// everything asking for the same image at once.
actor ImageLoader {
    static let shared = ImageLoader()
    /// Backdrops, decoded into their own memory cache.
    static let backdrops = ImageLoader(memory: .backdrops)

    /// The memory cache this loader decodes into, read synchronously by `CrossfadeImage`.
    nonisolated let memoryCache: ImageMemoryCache

    private let memory: ImageMemoryCache
    private let disk: ImageDiskCache
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init(memory: ImageMemoryCache = .shared, disk: ImageDiskCache = .shared) {
        self.memory = memory
        self.memoryCache = memory
        self.disk = disk
    }

    /// The decoded image, also kept in memory for the next view that asks.
    func image(for url: URL) async -> UIImage? {
        if let cached = memory.image(for: url) { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task.detached(priority: .userInitiated) { [memory, disk] () -> UIImage? in
            let data: Data
            if let stored = disk.data(for: url) {
                data = stored
            } else {
                guard let result = try? await URLSession.shared.data(from: url),
                      ImageLoader.isSuccess(result.1) else { return nil }
                data = result.0
                disk.store(data, for: url)
            }
            // Decode here, off the main thread, so large backdrops don't stall focus movement.
            guard let image = UIImage(data: data)?.preparingForDisplay() else { return nil }
            memory.store(image, for: url)
            return image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        return image
    }

    /// Downloads images ahead of time, a few at a time. With `decode`, they also go into
    /// memory so they appear instantly; otherwise they're only saved to disk.
    func prefetch(_ urls: [URL], decode: Bool) async {
        let pending = urls.filter { memory.image(for: $0) == nil && (decode || !disk.contains($0)) }
        await withTaskGroup(of: Void.self) { group in
            var iterator = pending.makeIterator()
            for _ in 0..<4 {
                guard let url = iterator.next() else { break }
                group.addTask { await self.warm(url, decode: decode) }
            }
            while await group.next() != nil {
                guard !Task.isCancelled, let url = iterator.next() else { continue }
                group.addTask { await self.warm(url, decode: decode) }
            }
        }
    }

    private func warm(_ url: URL, decode: Bool) async {
        if decode {
            _ = await image(for: url)
        } else if !disk.contains(url),
                  let result = try? await URLSession.shared.data(from: url),
                  Self.isSuccess(result.1) {
            disk.store(result.0, for: url)
        }
    }

    private static func isSuccess(_ response: URLResponse) -> Bool {
        ((response as? HTTPURLResponse)?.statusCode ?? 200) < 400
    }
}
