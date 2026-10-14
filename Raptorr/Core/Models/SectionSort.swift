import Foundation

/// One entry of `/library/sections/{sectionId}/sorts` (`Directory` of `Sort`).
nonisolated struct SectionSort: Decodable, Sendable, Hashable {
    /// The value for the `sort` parameter, e.g. `titleSort`.
    let key: String
    /// Where this sort's items are indexed by first character, when the server offers it.
    let firstCharacterKey: String?
}
