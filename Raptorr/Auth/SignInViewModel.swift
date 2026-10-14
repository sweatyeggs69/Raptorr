import Foundation
import Observation

/// Drives the Plex PIN flow: create a short PIN, show it as a QR code and a typed code
/// for plex.tv/link, then poll plex.tv until the user claims it.
@Observable
final class SignInViewModel {
    private(set) var code: String?
    private(set) var linkURL: URL?
    private(set) var errorMessage: String?

    private let pollInterval: Duration = .seconds(2)

    /// Runs until a token arrives or the calling task is cancelled.
    /// Expired PINs are replaced with fresh ones automatically.
    func run(client: PlexAPIClient) async -> String? {
        while !Task.isCancelled {
            do {
                let pin = try await client.createPin()
                errorMessage = nil
                code = pin.code
                linkURL = Self.linkURL(for: pin.code)

                let lifetime = Duration.seconds(pin.expiresIn ?? 900)
                let deadline = ContinuousClock.now + lifetime
                while ContinuousClock.now < deadline {
                    try await Task.sleep(for: pollInterval)
                    let status = try await client.checkPin(id: pin.id)
                    if let token = status.authToken, !token.isEmpty {
                        return token
                    }
                }
            } catch is CancellationError {
                return nil
            } catch {
                errorMessage = error.localizedDescription
                code = nil
                linkURL = nil
                try? await Task.sleep(for: .seconds(5))
            }
        }
        return nil
    }

    /// Short PINs are claimed on the link page (see "Authenticating with Plex" in plex-api.json).
    static func linkURL(for code: String) -> URL? {
        var components = URLComponents(string: "https://plex.tv/link/")
        components?.queryItems = [URLQueryItem(name: "pin", value: code)]
        return components?.url
    }
}
