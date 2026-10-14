import Foundation

/// A letter in the library's jump bar and the index of the first title that starts with it.
nonisolated struct LetterJump: Sendable, Hashable, Identifiable {
    let title: String
    let offset: Int

    var id: String { title }

    /// Turns per-character counts, in title-sort order, into starting offsets.
    static func make(from characters: [FirstCharacter]) -> [LetterJump] {
        var offset = 0
        return characters.map { character in
            defer { offset += character.size }
            return LetterJump(title: character.title, offset: offset)
        }
    }
}
