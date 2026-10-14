import Foundation

nonisolated enum LibraryType: String, Sendable, Hashable {
    case movie
    case show
    case other

    /// Metadata type number used by the `type` media query parameter.
    var metadataTypeNumber: Int? {
        switch self {
        case .movie: 1
        case .show: 2
        case .other: nil
        }
    }

    var systemImage: String {
        switch self {
        case .movie: "film"
        case .show: "tv"
        case .other: "folder"
        }
    }
}
