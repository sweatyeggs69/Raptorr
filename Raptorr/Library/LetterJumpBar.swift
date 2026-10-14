import SwiftUI

/// A column of letters beside a library grid; selecting one jumps to the first title
/// starting with it.
struct LetterJumpBar: View {
    let letters: [LetterJump]
    let action: (LetterJump) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(letters) { letter in
                    Button {
                        action(letter)
                    } label: {
                        Text(letter.title)
                            .font(.callout.weight(.semibold))
                            .frame(width: 44)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 40)
        }
        .scrollIndicators(.hidden)
        .focusSection()
    }
}

#Preview {
    LetterJumpBar(
        letters: ["#", "A", "B", "C", "G", "M", "S", "Z"].enumerated().map { LetterJump(title: $1, offset: $0) }
    ) { _ in }
}
