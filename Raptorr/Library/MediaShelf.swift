import SwiftUI

/// A titled horizontal row of posters or 16:9 cards.
struct MediaShelf: View {
    let title: String
    let items: [PlexMetadata]
    var style: ShelfStyle = .poster
    /// Called with the card that just gained focus.
    var onFocus: ((PlexMetadata) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(items) { item in
                        switch style {
                        case .poster:
                            PosterCard(item: item, width: 200, onFocus: focusAction(for: item))
                        case .landscape:
                            LandscapeCard(item: item, onFocus: focusAction(for: item))
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func focusAction(for item: PlexMetadata) -> (() -> Void)? {
        guard let onFocus else { return nil }
        return { onFocus(item) }
    }
}

#Preview {
    NavigationStack {
        MediaShelf(title: "Continue Watching", items: [.previewEpisode, .previewMovie], style: .landscape)
    }
}
