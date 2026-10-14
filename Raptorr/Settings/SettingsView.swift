import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @Environment(\.plexClient) private var client
    @Environment(TabRouter.self) private var router
    @FocusState private var focusedRow: String?
    @State private var isConfirmingSignOut = false
    @AppStorage(InterfaceSettings.showsTabIconsKey) private var showsTabIcons = InterfaceSettings.showsTabIconsDefault

    var body: some View {
        NavigationStack {
            // Laid out like the Apple TV's own Settings: a large symbol on the left half and
            // the grouped list on the right.
            HStack(spacing: 80) {
                Image(systemName: "gearshape")
                    .font(.system(size: 280, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                List {
                    Section("Interface") {
                        Toggle("Tab Bar Icons", isOn: $showsTabIcons)
                            .focused($focusedRow, equals: "tabBarIcons")
                    }

                    Section("About") {
                        infoRow("Version", value: PlexClientIdentity.version)
                    }

                    // Server details last, then the actions that leave it at the very bottom.
                    Section("Server") {
                        if let server = connection.currentServer {
                            infoRow("Name", value: server.name)
                            infoRow("Connection", value: connectionDescription(for: server))
                        }
                    }

                    Section {
                        Button("Switch Server") {
                            // Leaving the server drops everything cached from it.
                            connection.disconnect()
                            Task { await client.clearCache() }
                        }
                        .focused($focusedRow, equals: "switchServer")
                        Button("Sign Out", role: .destructive) {
                            isConfirmingSignOut = true
                        }
                        .focused($focusedRow, equals: "signOut")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            // Back from the list moves focus up to the tab bar, as in the libraries.
            .onChange(of: focusedRow) { _, row in
                router.isContentFocused = row != nil
            }
            .alert("Sign Out of Plex?", isPresented: $isConfirmingSignOut) {
                Button("Sign Out", role: .destructive) {
                    connection.disconnect()
                    authStore.signOut()
                    Task { await client.clearCache() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to watch anything.")
            }
        }
    }

    /// A read-only row. tvOS lists only draw rows the focus engine can reach, so it's a
    /// button that does nothing, the way the system Settings app shows its info rows.
    private func infoRow(_ title: String, value: String) -> some View {
        Button {} label: {
            LabeledContent(title) {
                Text(value)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .focused($focusedRow, equals: title)
    }

    private func connectionDescription(for server: PlexServer) -> String {
        guard connection.isReachable else { return "Unavailable" }
        return server.connectionKind?.title ?? "Unknown"
    }
}

#Preview {
    SettingsView()
        .environment(AuthStore())
        .environment(ServerConnectionManager())
        .environment(TabRouter())
}
