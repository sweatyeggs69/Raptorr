import SwiftUI

/// The controls on either side of the tab bar: sync on the left, Settings on the right,
/// centered on the tab bar's row.
struct TopBarAccessories: View {
    let isSyncing: Bool
    let onSync: () -> Void
    let onSettings: () -> Void

    /// The tab bar's row, measured from the top of the screen: it starts this far down and is
    /// this tall. Adjust these if the buttons don't line up with the tab bar.
    static let rowTop: CGFloat = 40
    static let rowHeight: CGFloat = 70
    /// The 1080p safe area's side margins, matching the tab bar's.
    static let sideInset: CGFloat = 80

    var body: some View {
        HStack {
            SyncButton(isRunning: isSyncing, action: onSync)
            Spacer()
            Button(action: onSettings) {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        .frame(height: Self.rowHeight)
        .padding(.top, Self.rowTop)
        .padding(.horizontal, Self.sideInset)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }
}

#Preview {
    TopBarAccessories(isSyncing: false, onSync: {}, onSettings: {})
}
