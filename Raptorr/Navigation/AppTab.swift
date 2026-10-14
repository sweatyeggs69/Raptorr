import Foundation

nonisolated enum AppTab: Hashable {
    case search
    case home
    case library(key: String)
}
