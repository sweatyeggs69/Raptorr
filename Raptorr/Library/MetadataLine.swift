import SwiftUI

/// A " · " separated metadata line with the content rating drawn as a `RatingBadge` in its
/// place, e.g. "S2E3 · 2024 · [TV-14] · 45m".
struct MetadataLine: View {
    let leading: [String]
    let rating: String?
    let trailing: [String]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                if index > 0 {
                    Text("·")
                }
                switch segment {
                case .text(let text): Text(text)
                case .rating(let rating): RatingBadge(rating: rating)
                }
            }
        }
        .lineLimit(1)
    }

    private enum Segment {
        case text(String)
        case rating(String)
    }

    private var segments: [Segment] {
        leading.map(Segment.text) + (rating.map { [Segment.rating($0)] } ?? []) + trailing.map(Segment.text)
    }
}

#Preview {
    MetadataLine(leading: ["S2E3", "2024"], rating: "TV-14", trailing: ["45m"])
        .font(.headline)
        .foregroundStyle(.secondary)
}
