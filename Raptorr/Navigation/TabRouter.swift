import Observation

/// The selected top tab, shared through the environment so a tab's content can switch tabs:
/// Back on another tab's top level goes to Home instead of leaving the app.
@Observable
final class TabRouter {
    var selection: AppTab = .home
}
