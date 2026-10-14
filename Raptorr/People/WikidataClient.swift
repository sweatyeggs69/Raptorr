import Foundation

/// Reads a person's birth (P569) and death (P570) dates from Wikidata, the structured data
/// behind the Wikipedia article the bio comes from.
nonisolated struct WikidataClient: Sendable {
    static let shared = WikidataClient()

    var session: URLSession = .shared

    func lifeDates(for entity: String) async -> LifeDates? {
        async let born = date(entity: entity, property: "P569")
        async let died = date(entity: entity, property: "P570")
        let dates = await LifeDates(born: born, died: died)
        return dates.born == nil ? nil : dates
    }

    private func date(entity: String, property: String) async -> DateComponents? {
        var components = URLComponents(string: "https://www.wikidata.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "wbgetclaims"),
            URLQueryItem(name: "entity", value: entity),
            URLQueryItem(name: "property", value: property),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        // Wikimedia asks API clients to identify themselves.
        request.setValue("Raptorr/1.0 (Apple TV Plex client)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let claims = try? JSONDecoder().decode(WikidataClaims.self, from: data),
              let value = claims.claims[property]?.first?.mainsnak.datavalue?.value else { return nil }
        return LifeDates.components(time: value.time, precision: value.precision)
    }
}
