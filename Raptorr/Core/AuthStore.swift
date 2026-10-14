import Foundation
import Observation

/// Holds the signed-in user's plex.tv token, persisted in the Keychain.
@Observable
final class AuthStore {
    private static let tokenKey = "plexAuthToken"

    private(set) var token: String?

    var isSignedIn: Bool { token != nil }

    init() {
        token = KeychainHelper.load(forKey: Self.tokenKey)
    }

    func signIn(token: String) {
        KeychainHelper.save(token, forKey: Self.tokenKey)
        self.token = token
    }

    func signOut() {
        KeychainHelper.delete(forKey: Self.tokenKey)
        token = nil
    }
}
