import Foundation

/// Looks up an actor's biography on Wikipedia, since Plex servers don't provide one.
/// Plex only knows the name, so a page counts only when its description reads like a
/// performer's; otherwise "(actor)" and "(actress)" titles are tried before giving up.
nonisolated struct WikipediaClient: Sendable {
    static let shared = WikipediaClient()

    private static let baseURL = "https://en.wikipedia.org/api/rest_v1/page/summary/"
    private static let performerWords = [
        "actor", "actress", "comedian", "filmmaker", "director", "performer",
        "entertainer", "singer", "musician", "rapper", "presenter", "host", "voice", "model",
    ]

    var session: URLSession = .shared

    func biography(for name: String) async -> String? {
        for title in [name, "\(name) (actor)", "\(name) (actress)"] {
            guard let summary = await summary(title: title) else { continue }
            if summary.type == "standard", Self.isPerformer(summary), let extract = summary.extract, !extract.isEmpty {
                return extract
            }
        }
        return nil
    }

    static func isPerformer(_ summary: WikipediaSummary) -> Bool {
        let description = (summary.description ?? "").lowercased()
        return performerWords.contains { description.contains($0) }
    }

    private func summary(title: String) async -> WikipediaSummary? {
        let path = title.replacingOccurrences(of: " ", with: "_")
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove("/")
        // Built as a string: `URL.appending(path:)` would encode the already-encoded title again.
        guard let encoded = path.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: Self.baseURL + encoded) else { return nil }
        var request = URLRequest(url: url)
        // Wikimedia asks API clients to identify themselves.
        request.setValue("Raptorr/1.0 (Apple TV Plex client)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(WikipediaSummary.self, from: data)
    }
}
