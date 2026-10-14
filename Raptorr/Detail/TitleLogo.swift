import SwiftUI

/// A movie or show's clear logo, falling back to the title as text when there is no logo
/// or it fails to load, the way the Apple TV app presents titles.
struct TitleLogo: View {
    let title: String
    let logoPath: String?
    var maxWidth: CGFloat = TitleLogo.widthLimit
    var maxHeight: CGFloat = 220
    var font: Font = .largeTitle.bold()
    /// Leaves the box empty while the caller is still finding out whether a logo exists.
    var isLoading = false
    /// Sizes to the logo (or the text) instead of filling a fixed box, for inline use such as
    /// the player's title bar, where the episode title follows right after the logo.
    var hugsContent = false

    /// Logos fill their box's height unless that would make them wider than this: 40% of the
    /// 1920pt tvOS screen (Kyle's call).
    static let widthLimit: CGFloat = 768

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server

    var body: some View {
        // Logo, fallback text and loading state all fill the same box, anchored bottom left,
        // so switching between titles never changes the layout around it.
        sized(content)
            .animation(.easeInOut(duration: 0.35), value: logoPath)
            .animation(.easeInOut(duration: 0.35), value: isLoading)
    }

    @ViewBuilder
    private func sized(_ view: some View) -> some View {
        if hugsContent {
            view
                .frame(maxWidth: maxWidth, alignment: .leading)
                .frame(height: maxHeight)
                .fixedSize(horizontal: true, vertical: false)
        } else {
            view
                .frame(width: maxWidth, height: maxHeight, alignment: .bottomLeading)
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Color.clear
        } else if let url = client.logoURL(server: server, path: logoPath, width: Int(maxWidth * 2), height: Int(maxHeight * 2)) {
            // The fitted logo is usually narrower or shorter than the box; it sits in the
            // bottom left corner and crossfades when the title changes.
            CrossfadeImage(url: url, contentMode: .fit, alignment: .bottomLeading, sizesToImage: hugsContent) { failed in
                if failed {
                    titleText
                } else {
                    Color.clear
                }
            }
            .accessibilityLabel(title)
        } else {
            titleText
                .transition(.opacity)
        }
    }

    private var titleText: some View {
        Text(title)
            .font(font)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: hugsContent ? nil : .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

#Preview {
    TitleLogo(title: "Big Buck Bunny", logoPath: nil)
}
