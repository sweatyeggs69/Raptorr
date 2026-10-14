import SwiftUI

/// Binds a card's own focusable view to a row's focus state, when the row passes one.
/// Applying `focused(_:equals:)` to the card from outside doesn't reliably reach the
/// button inside it, so the card applies it to its `NavigationLink` itself.
struct FocusBindingModifier: ViewModifier {
    let binding: FocusState<String?>.Binding?
    let id: String

    func body(content: Content) -> some View {
        if let binding {
            content.focused(binding, equals: id)
        } else {
            content
        }
    }
}

extension View {
    func focused(_ binding: FocusState<String?>.Binding?, id: String) -> some View {
        modifier(FocusBindingModifier(binding: binding, id: id))
    }
}
