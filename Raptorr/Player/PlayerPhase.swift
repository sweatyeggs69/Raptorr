import Foundation

nonisolated enum PlayerPhase: Equatable {
    case loading
    case playing
    case paused
    case ended
    case failed(String)
}
