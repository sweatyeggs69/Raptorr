import Foundation

/// One entry of `/library/sections/{sectionId}/firstCharacters` (`Directory`): a leading
/// character and how many titles start with it.
nonisolated struct FirstCharacter: Decodable, Sendable, Hashable {
    let key: String
    let title: String
    let size: Int
}
