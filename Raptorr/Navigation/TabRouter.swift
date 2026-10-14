import Observation

/// The selected top tab, shared through the environment so a tab's content can switch tabs:
/// Back on another tab's top level goes to Home instead of leaving the app.
@Observable
final class TabRouter {
    var selection: AppTab = .home {
        didSet {
            if selection == .home, oldValue != .home { homeReturns += 1 }
            if selection != oldValue { isContentFocused = false }
        }
    }

    /// Whether focus is inside the selected tab's content rather than on the tab bar. Back
    /// from content is left to the system, which moves focus up to the tab bar; Back on
    /// another tab's tab bar item goes to Home.
    var isContentFocused = false

    /// Counts returns to Home from another tab, so Home can start over from its first row
    /// instead of putting focus back on the card it last had.
    private(set) var homeReturns = 0
}
