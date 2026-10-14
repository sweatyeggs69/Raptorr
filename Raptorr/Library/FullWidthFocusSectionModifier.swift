import SwiftUI

/// A focus section stretched across the full width. `focusSection()` only catches moves
/// that land inside its frame, so a short row (two cards, a couple of buttons) left most of
/// the screen with nothing above or below it and up or down from there went nowhere.
struct FullWidthFocusSectionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .focusSection()
    }
}

extension View {
    func fullWidthFocusSection() -> some View {
        modifier(FullWidthFocusSectionModifier())
    }
}
