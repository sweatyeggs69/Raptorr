import SwiftUI

/// Logo, basic metadata and description of the focused card, above the Home rows.
struct FocusedItemHeader: View {
    let item: PlexMetadata
    let logoPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TitleLogo(
                title: item.kind == .episode ? (item.grandparentTitle ?? item.title) : item.title,
                logoPath: logoPath,
                maxWidth: 640,
                maxHeight: 180
            )

            if item.kind == .episode {
                Text(item.title)
                    .font(.title3.bold())
            }

            Text(item.infoLine)
                .font(.headline)
                .foregroundStyle(.secondary)

            if let summary = item.summary, !summary.isEmpty {
                Text(summary)
                    .lineLimit(3)
                    .frame(maxWidth: 1000, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.default, value: item.ratingKey)
    }
}

#Preview {
    FocusedItemHeader(item: .previewMovie, logoPath: nil)
}
