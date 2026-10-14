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

    /// Builds the letters from titles already in sort order, for when the server's
    /// first-character list isn't available. Digits and symbols share "#".
    static func make(fromSortedTitles titles: [String]) -> [LetterJump] {
        var letters: [LetterJump] = []
        var seen = Set<String>()
        for (offset, title) in titles.enumerated() {
            let group = group(for: title)
            if seen.insert(group).inserted {
                letters.append(LetterJump(title: group, offset: offset))
            }
        }
        return letters
    }

    private static func group(for title: String) -> String {
        guard let first = title.first else { return "#" }
        let letter = String(first).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).uppercased()
        guard letter.count == 1, let character = letter.first, character.isASCII, character.isLetter else { return "#" }
        return letter
    }
}
