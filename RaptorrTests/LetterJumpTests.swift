import Testing
@testable import Raptorr

struct LetterJumpTests {
    @Test func offsetsAccumulateCounts() {
        let characters = [
            FirstCharacter(key: "%23", title: "#", size: 2),
            FirstCharacter(key: "A", title: "A", size: 5),
            FirstCharacter(key: "G", title: "G", size: 3),
        ]

        let letters = LetterJump.make(from: characters)

        #expect(letters.map(\.title) == ["#", "A", "G"])
        #expect(letters.map(\.offset) == [0, 2, 7])
    }

    @Test func lettersFromSortedTitles() {
        let letters = LetterJump.make(fromSortedTitles: ["12 Monkeys", "Alien", "Avatar", "Émilie", "Gattaca", "Zodiac"])

        #expect(letters.map(\.title) == ["#", "A", "E", "G", "Z"])
        #expect(letters.map(\.offset) == [0, 1, 3, 4, 5])
    }
}
