import Foundation

/// The parts of Wikipedia's page summary (`/api/rest_v1/page/summary/{title}`) a person
/// page uses.
nonisolated struct WikipediaSummary: Decodable, Sendable {
    /// "standard" for an article, "disambiguation" for a list of same-named pages.
    let type: String?
    /// The short description, e.g. "American actor and comedian (born 1962)".
    let description: String?
    /// The article's lead paragraph.
    let extract: String?
    /// The article's Wikidata item, e.g. "Q40504", which carries the birth and death dates.
    let wikibaseItem: String?

    enum CodingKeys: String, CodingKey {
        case type, description, extract
        case wikibaseItem = "wikibase_item"
    }

    init(type: String?, description: String?, extract: String?, wikibaseItem: String? = nil) {
        self.type = type
        self.description = description
        self.extract = extract
        self.wikibaseItem = wikibaseItem
    }
}
