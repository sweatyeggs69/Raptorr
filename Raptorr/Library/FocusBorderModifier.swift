import SwiftUI

/// Draws a border along `shape` while the enclosing card button has focus.
struct FocusBorderModifier<S: InsettableShape>: ViewModifier {
    let shape: S

    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content
            .overlay {
                shape
                    .strokeBorder(.white, lineWidth: 6)
                    .opacity(isFocused ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    func focusBorder<S: InsettableShape>(_ shape: S) -> some View {
        modifier(FocusBorderModifier(shape: shape))
    }
}
