import SwiftUI

/// Plex artwork loaded through the server's photo transcoder.
struct ArtworkImage: View {
    let path: String?
    let width: Int
    let height: Int
    var placeholderSymbol = "film"

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server

    var body: some View {
        AsyncImage(url: client.artworkURL(server: server, path: path, width: width, height: height)) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: placeholderSymbol)
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}

#Preview {
    ArtworkImage(path: nil, width: 300, height: 450)
        .frame(width: 300, height: 450)
}
