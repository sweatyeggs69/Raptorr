import SwiftUI

/// Back on a detail page returns to the previous screen instead of leaving the app.
struct PopOnExitModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.onExitCommand { dismiss() }
    }
}
