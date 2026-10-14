import UIKit

/// Decoded artwork kept in memory, so a card that scrolls off screen and back (lazy rows
/// discard off-screen views) shows its image immediately instead of loading it again.
/// `NSCache` evicts on its own under memory pressure.
nonisolated final class ImageMemoryCache: @unchecked Sendable {
    static let shared = ImageMemoryCache()

    private let cache = NSCache<NSURL, UIImage>()

    init(costLimit: Int = 200 * 1024 * 1024) {
        cache.totalCostLimit = costLimit
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func store(_ image: UIImage, for url: URL) {
        let pixels = image.size.width * image.size.height * image.scale * image.scale
        cache.setObject(image, forKey: url as NSURL, cost: Int(pixels * 4))
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}
