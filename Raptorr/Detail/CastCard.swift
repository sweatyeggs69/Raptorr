import SwiftUI

/// One cast member: a round portrait with the actor's name and character below.
struct CastCard: View {
    let person: PlexTag

    nonisolated static let portraitSize: CGFloat = 160

    var body: some View {
        // Opens the person page; a cast entry without an id can't be looked up, so it stays
        // a plain button the focus engine can still reach.
        if person.personID != nil {
            NavigationLink(value: person) { label }
                .buttonStyle(.focusBorder)
        } else {
            Button {} label: { label }
                .buttonStyle(.focusBorder)
        }
    }

    private var label: some View {
        Group {
            VStack(spacing: 12) {
                ArtworkImage(
                    path: person.thumb,
                    width: Int(Self.portraitSize * 2),
                    height: Int(Self.portraitSize * 2),
                    placeholderSymbol: "person.fill"
                )
                .frame(width: Self.portraitSize, height: Self.portraitSize)
                .clipShape(.circle)
                .focusBorder(.circle)

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
    }
}

#Preview {
    CastCard(person: PlexTag(tag: "Jane Doe", role: "Herself", thumb: nil))
}
