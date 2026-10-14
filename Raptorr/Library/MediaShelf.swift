import SwiftUI

/// A titled horizontal row of posters or 16:9 cards.
struct MediaShelf: View {
    let title: String
    let items: [PlexMetadata]
    var style: ShelfStyle = .poster
    /// Called with the card that just gained focus.
    var onFocus: ((PlexMetadata) -> Void)?

    @FocusState private var focusedID: String?
    /// The card that last had focus, so coming back to the row returns to it.
    @State private var lastFocusedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(items) { item in
                        Group {
                            switch style {
                            case .poster:
                                PosterCard(item: item, width: 200, onFocus: focusAction(for: item))
                            case .landscape:
                                LandscapeCard(item: item, onFocus: focusAction(for: item))
                            }
                        }
                        .focused($focusedID, equals: item.id)
                    }
                }
                // Moving into the row lands on the card last focused here, or the first one,
                // rather than whichever card happens to sit under the previous row's focus.
                .defaultFocus($focusedID, lastFocusedID ?? items.first?.id, priority: .userInitiated)
            }
            .scrollClipDisabled()
        }
        .onChange(of: focusedID) { _, id in
            if let id { lastFocusedID = id }
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
