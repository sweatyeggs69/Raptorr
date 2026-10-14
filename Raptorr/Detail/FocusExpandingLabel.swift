import SwiftUI

/// A button label that shows only its symbol until the button is focused, then reveals its
/// title beside it. For secondary actions next to the main Play button.
struct FocusExpandingLabel: View {
    let title: String
    let systemImage: String

    @Environment(\.isFocused) private var isFocused

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .contentTransition(.symbolEffect(.replace))
            if isFocused {
                Text(title)
                    .lineLimit(1)
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

#Preview {
    HStack {
        Button {} label: { FocusExpandingLabel(title: "Play from Beginning", systemImage: "arrow.counterclockwise") }
        Button {} label: { FocusExpandingLabel(title: "Mark Watched", systemImage: "checkmark.circle") }
    }
}
