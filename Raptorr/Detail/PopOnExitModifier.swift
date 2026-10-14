import SwiftUI

/// Back on a detail page returns to the previous screen instead of leaving the app.
struct PopOnExitModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var router: TabRouter?

    func body(content: Content) -> some View {
        content
            .onExitCommand { dismiss() }
            // Keeps the tab view's own Back handler (switch to Home) out of the way while
            // this page is showing.
            .onAppear { router?.visibleDetailPages += 1 }
            .onDisappear {
                if let router { router.visibleDetailPages = max(0, router.visibleDetailPages - 1) }
            }
    }
}
