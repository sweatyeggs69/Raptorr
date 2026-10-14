import SwiftUI

/// A column of letters over the right edge of a library grid. Moving through it scrolls the
/// grid to each letter; selecting one moves focus onto that letter's first title.
struct LetterJumpBar: View {
    let letters: [LetterJump]
    let onFocus: (LetterJump) -> Void
    let onSelect: (LetterJump) -> Void
    /// Called when focus enters or leaves the bar.
    var onFocusChange: (Bool) -> Void = { _ in }

    /// The bar's width, which the grid leaves free beside it.
    static let width: CGFloat = 44

    @FocusState private var focusedLetter: String?

    var body: some View {
        // A little air between letters; 27 rows of this still fit beside the grid.
        VStack(spacing: 6) {
            ForEach(letters) { letter in
                Button {
                    onSelect(letter)
                } label: {
                    LetterJumpLabel(title: letter.title)
                }
                .buttonStyle(.focusBorder)
                .focused($focusedLetter, equals: letter.id)
            }
        }
        // Scroll only when moving between letters, not when focus first enters the bar.
        .onChange(of: focusedLetter != nil) { _, isFocused in
            onFocusChange(isFocused)
        }
        .onChange(of: focusedLetter) { previous, current in
            guard previous != nil, let current, let letter = letters.first(where: { $0.id == current }) else { return }
            onFocus(letter)
        }
        .padding(.vertical, 10)
        .frame(width: Self.width)
        .glassEffect(.regular, in: .capsule)
        .focusSection()
    }
}

#Preview {
    LetterJumpBar(
        letters: ["#", "A", "B", "C", "G", "M", "S", "Z"].enumerated().map { LetterJump(title: $1, offset: $0) },
        onFocus: { _ in },
        onSelect: { _ in }
    )
}
