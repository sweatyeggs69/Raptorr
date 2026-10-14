import SwiftUI

/// A column of letters beside a library grid; selecting one jumps to the first title
/// starting with it.
struct LetterJumpBar: View {
    let letters: [LetterJump]
    let action: (LetterJump) -> Void

    /// The bar's width, which the grid leaves free beside it.
    static let width: CGFloat = 60

    var body: some View {
        // Sized to its letters (no scroll view, which would stretch and squeeze them into
        // ellipses) on a glass capsule so it reads as a control even before it has focus.
        VStack(spacing: 0) {
            ForEach(letters) { letter in
                Button {
                    action(letter)
                } label: {
                    Text(letter.title)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .fixedSize()
                        .frame(width: Self.width - 16, height: 26)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .glassEffect(.regular, in: .capsule)
        .frame(width: Self.width)
        .focusSection()
    }
}

#Preview {
    LetterJumpBar(
        letters: ["#", "A", "B", "C", "G", "M", "S", "Z"].enumerated().map { LetterJump(title: $1, offset: $0) }
    ) { _ in }
}
