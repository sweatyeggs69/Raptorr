import Foundation

/// The `raptorr://` links behind Top Shelf cards: selecting a card opens the item's page,
/// Play resumes it. Each link names the server, so a link saved for another server is ignored.
nonisolated struct TopShelfLink: Hashable, Sendable {
    nonisolated enum Action: String, Sendable {
        case show
        case play
    }

    static let scheme = "raptorr"

    let action: Action
    let machineIdentifier: String
    let ratingKey: String

    /// `raptorr://play?server=<machineIdentifier>&item=<ratingKey>`
    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = action.rawValue
        components.queryItems = [
            URLQueryItem(name: "server", value: machineIdentifier),
            URLQueryItem(name: "item", value: ratingKey),
        ]
        return components.url
    }
}

extension TopShelfLink {
    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == Self.scheme,
              let action = components.host.flatMap(Action.init(rawValue:)),
              let server = components.queryItems?.first(where: { $0.name == "server" })?.value, !server.isEmpty,
              let item = components.queryItems?.first(where: { $0.name == "item" })?.value, !item.isEmpty
        else { return nil }
        self.init(action: action, machineIdentifier: server, ratingKey: item)
    }
}
