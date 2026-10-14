import SwiftUI

/// A movie or show's clear logo, falling back to the title as text when there is no logo
/// or it fails to load, the way the Apple TV app presents titles.
struct TitleLogo: View {
    let title: String
    let logoPath: String?
    var maxWidth: CGFloat = 800
    var maxHeight: CGFloat = 220
    var font: Font = .largeTitle.bold()

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server

    var body: some View {
        if let url = client.logoURL(server: server, path: logoPath, width: Int(maxWidth * 2), height: Int(maxHeight * 2)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: maxWidth, maxHeight: maxHeight, alignment: .bottomLeading)
                        .accessibilityLabel(title)
                } else if phase.error != nil {
                    titleText
                } else {
                    // Reserve the space while loading so the layout doesn't jump.
                    Color.clear.frame(width: maxWidth, height: maxHeight)
                }
            }
        } else {
            titleText
        }
    }

    private var titleText: some View {
        Text(title)
            .font(font)
            .lineLimit(2)
    }
}

#Preview {
    TitleLogo(title: "Big Buck Bunny", logoPath: nil)
}
