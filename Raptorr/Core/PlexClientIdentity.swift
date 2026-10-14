import Foundation

/// Identification values sent as `X-Plex-*` headers on every request.
///
/// Per the Plex auth docs, the client identifier is a random value generated once per
/// install and reused for all later requests.
nonisolated enum PlexClientIdentity {
    static let product = "Raptorr"
    static let platform = "tvOS"
    static let device = "Apple TV"
    static let deviceName = "Raptorr (Apple TV)"

    static let version: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"

    static let platformVersion: String = {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }()

    private static let identifierKey = "plexClientIdentifier"

    static let clientIdentifier: String = {
        if let existing = UserDefaults.standard.string(forKey: identifierKey) {
            return existing
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: identifierKey)
        return generated
    }()
}
