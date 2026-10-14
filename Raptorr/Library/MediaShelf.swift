import SwiftUI

/// A titled horizontal row of posters.
struct MediaShelf: View {
    let title: String
    let items: [PlexMetadata]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.bold())

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(items) { item in
                        PosterCard(item: item, width: 220)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

#Preview {
    NavigationStack {
        MediaShelf(title: "Recently Added", items: [.previewMovie])
    }
}
