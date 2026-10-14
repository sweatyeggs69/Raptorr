import Foundation

/// Everything the Home header shows for the focused card, published only once its logo and
/// backdrop are ready so the header changes as one piece.
struct HomeHeader: Equatable {
    let item: PlexMetadata
    let logoPath: String?
    let isContinueWatching: Bool

    /// Changes whenever the header should crossfade, including the same title moving between
    /// Continue Watching and a library row, whose metadata lines differ.
    var id: String { "\(isContinueWatching)|\(item.ratingKey)" }
}
