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
}
