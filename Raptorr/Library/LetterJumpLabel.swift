import SwiftUI

/// One letter in `LetterJumpBar`. The focused letter turns black on a white circle, since a
/// bare letter is too small for the system focus effect to read.
struct LetterJumpLabel: View {
    let title: String

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(isFocused ? .black : .secondary)
            .frame(width: 32, height: 24)
            .background {
                if isFocused {
                    Circle()
                        .fill(.white)
                        .frame(width: 34, height: 34)
                }
            }
            .scaleEffect(isFocused ? 1.2 : 1)
            .animation(.snappy, value: isFocused)
    }
}

#Preview {
    Button {} label: { LetterJumpLabel(title: "G") }
        .buttonStyle(.focusBorder)
}
