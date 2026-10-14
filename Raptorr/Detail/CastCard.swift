import SwiftUI

/// One cast member: a round portrait with the actor's name and character below.
struct CastCard: View {
    let person: PlexTag

    static let portraitSize: CGFloat = 160

    var body: some View {
        // A button so the focus engine can reach it and scroll the row; there's no
        // person page to open yet.
        Button {} label: {
            VStack(spacing: 12) {
                ArtworkImage(
                    path: person.thumb,
                    width: Int(Self.portraitSize * 2),
                    height: Int(Self.portraitSize * 2),
                    placeholderSymbol: "person.fill"
                )
                .frame(width: Self.portraitSize, height: Self.portraitSize)
                .clipShape(.circle)

                VStack(spacing: 4) {
                    Text(person.tag ?? "")
                        .font(.caption)
                        .lineLimit(1)
                    // Always present so every card in the row is the same height.
                    Text(person.role ?? " ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: Self.portraitSize + 40)
            }
        }
        .buttonStyle(.borderless)
    }
}

#Preview {
    CastCard(person: PlexTag(tag: "Jane Doe", role: "Herself", thumb: nil))
}
