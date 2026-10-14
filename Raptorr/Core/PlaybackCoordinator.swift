import Foundation
import Observation

/// Shared entry point for starting playback from anywhere in the app.
@Observable
final class PlaybackCoordinator {
    var request: PlaybackRequest?

    func play(_ item: PlexMetadata, resume: Bool = true) {
        let offset = resume ? item.viewOffset : nil
        request = PlaybackRequest(item: item, startOffsetMs: offset)
    }
}
