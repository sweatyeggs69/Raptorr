import SwiftUI

/// A movie or show's clear logo, falling back to the title as text when there is no logo
/// or it fails to load, the way the Apple TV app presents titles.
struct TitleLogo: View {
    let title: String
    let logoPath: String?
    var maxWidth: CGFloat = 800
    var maxHeight: CGFloat = 220
    var font: Font = .largeTitle.bold()
    /// Leaves the box empty while the caller is still finding out whether a logo exists.
    var isLoading = false

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server

    var body: some View {
        // Logo, fallback text and loading state all fill the same box, anchored bottom left,
        // so switching between titles never changes the layout around it.
        content
            .frame(width: maxWidth, height: maxHeight, alignment: .bottomLeading)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Color.clear
        } else if let url = client.logoURL(server: server, path: logoPath, width: Int(maxWidth * 2), height: Int(maxHeight * 2)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    // The fitted logo is usually narrower or shorter than the box; pin it to
                    // the bottom left corner rather than leaving it centered.
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .accessibilityLabel(title)
                } else if phase.error != nil {
                    titleText
                } else {
                    Color.clear
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
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

#Preview {
    TitleLogo(title: "Big Buck Bunny", logoPath: nil)
}
