import Foundation

enum ShelfStyle {
    /// 2:3 posters.
    case poster
    /// 16:9 stills, as in the Apple TV app's Continue Watching row.
    case landscape

    /// A card's width in points.
    var cardWidth: CGFloat {
        switch self {
        case .poster: 200
        case .landscape: 480
        }
    }

    /// The artwork a card in this style requests (at twice its point size), so prefetching
    /// asks for exactly the same image and hits the cache.
    func artwork(for item: PlexMetadata) -> (path: String?, width: Int, height: Int) {
        switch self {
        case .poster:
            (item.posterPath, Int(cardWidth * 2), Int(cardWidth * 3))
        case .landscape:
            (item.landscapeImagePath, Int(cardWidth * 2), Int(cardWidth * 9 / 8))
        }
    }
}
