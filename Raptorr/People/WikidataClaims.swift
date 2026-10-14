import Foundation

/// The slice of a Wikidata `wbgetclaims` response holding a time value.
nonisolated struct WikidataClaims: Decodable, Sendable {
    let claims: [String: [Claim]]

    nonisolated struct Claim: Decodable, Sendable {
        let mainsnak: Snak
    }

    nonisolated struct Snak: Decodable, Sendable {
        let datavalue: DataValue?
    }

    nonisolated struct DataValue: Decodable, Sendable {
        let value: TimeValue
    }

    nonisolated struct TimeValue: Decodable, Sendable {
        let time: String
        let precision: Int
    }
}
