import SwiftUI

/// Calls `action` when the nearest focusable ancestor (e.g. the card's button) gains focus.
struct FocusReportingModifier: ViewModifier {
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    func body(content: Content) -> some View {
        content.onChange(of: isFocused) { _, focused in
            if focused { action() }
        }
    }
}

extension View {
    func onFocusGained(_ action: (() -> Void)?) -> some View {
        modifier(FocusReportingModifier(action: action ?? {}))
    }
}
