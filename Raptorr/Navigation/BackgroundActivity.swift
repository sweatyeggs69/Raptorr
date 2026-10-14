import Observation

/// Background loading the app is doing (the library sync, Home's refresh, a library's
/// posters), so the top right corner can show a spinner while any of it runs. Shared
/// through the environment.
@Observable
final class BackgroundActivity {
    private(set) var runningCount = 0
    /// Goes up when a background sync finishes, so open screens reload and pick up titles
    /// that were added or changed on the server.
    private(set) var libraryRevision = 0

    var isRunning: Bool { runningCount > 0 }

    /// Runs `work`, counting it as background activity while it runs.
    func track<T>(_ work: () async -> T) async -> T {
        runningCount += 1
        defer { runningCount -= 1 }
        return await work()
    }

    func libraryDidChange() {
        libraryRevision += 1
    }
}
