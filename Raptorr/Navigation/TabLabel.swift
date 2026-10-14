import SwiftUI

/// A top tab's label: title with its symbol, or the title alone when tab bar icons are off
/// in Settings > Interface.
struct TabLabel: View {
    let title: String
    let systemImage: String
    let showsIcon: Bool

    var body: some View {
        if showsIcon {
            // Plain monochrome so the icon turns black with its title when selected, like the
            // system tabs; the "tv" symbol otherwise keeps a lighter layer.
            Label(title, systemImage: systemImage)
                .symbolRenderingMode(.monochrome)
                .symbolVariant(.none)
        } else {
            Text(title)
        }
    }
}

#Preview {
    TabView {
        Tab {
            Text("Home")
        } label: {
            TabLabel(title: "Home", systemImage: "house", showsIcon: true)
        }
        Tab {
            Text("Settings")
        } label: {
            TabLabel(title: "Settings", systemImage: "gearshape", showsIcon: false)
        }
    }
    .tabViewStyle(.tabBarOnly)
}
