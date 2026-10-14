import SwiftUI

/// The "Cast" row on a movie, episode or show page.
struct CastShelf: View {
    let cast: [PlexTag]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cast")
                .font(.title3.bold())

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(Array(cast.enumerated()), id: \.offset) { _, person in
                        CastCard(person: person)
                    }
                }
            }
            .scrollClipDisabled()
        }
        .fullWidthFocusSection()
    }
}

#Preview {
    CastShelf(cast: [
        PlexTag(tag: "Jane Doe", role: "Herself", thumb: nil),
        PlexTag(tag: "John Roe", role: "The Villain", thumb: nil),
    ])
}
