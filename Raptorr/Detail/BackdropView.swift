import SwiftUI

/// Full-bleed background art, darkened toward the content side so text stays readable.
/// Crossfades from one backdrop to the next.
struct BackdropView: View {
    let path: String?

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server

    var body: some View {
        ZStack {
            Color.black
            CrossfadeImage(url: client.artworkURL(server: server, path: path, width: 1920, height: 1080)) { _ in
                Color.clear
            }
            LinearGradient(
                colors: [.black.opacity(0.9), .black.opacity(0.6), .black.opacity(0.2)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        }
        .ignoresSafeArea()
    }
}

#Preview {
    BackdropView(path: nil)
}
