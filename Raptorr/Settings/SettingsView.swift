import SwiftUI

struct SettingsView: View {
    @Environment(AuthStore.self) private var authStore
    @Environment(ServerConnectionManager.self) private var connection
    @Environment(\.plexClient) private var client
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
                        Button("Sign Out", role: .destructive) {
                            isConfirmingSignOut = true
                        }
                    }
                }
                .frame(maxWidth: .infinity)
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
}
