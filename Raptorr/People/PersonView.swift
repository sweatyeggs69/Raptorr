import SwiftUI

/// An actor's page: photo on the left, name and biography on the right, and the movies and
/// shows they appear in below.
struct PersonView: View {
    @State private var viewModel: PersonViewModel

    @Environment(\.plexClient) private var client
    @Environment(\.plexServer) private var server

    init(person: PlexTag) {
        _viewModel = State(initialValue: PersonViewModel(person: person))
    }

    private let photoWidth: CGFloat = 360

    var body: some View {
        let person = viewModel.person

        ScrollView {
            VStack(alignment: .leading, spacing: 60) {
                HStack(alignment: .top, spacing: 60) {
                    ArtworkImage(
                        path: person.thumb,
                        width: Int(photoWidth * 2),
                        height: Int(photoWidth * 3),
                        placeholderSymbol: "person.fill"
                    )
                    .frame(width: photoWidth, height: photoWidth * 1.5)
                    .clipShape(.rect(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 20) {
                        Text(person.tag ?? "")
                            .font(.title.bold())

                        if let summary = person.summary, !summary.isEmpty {
                            Text(summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(12)
                        } else if !viewModel.isLoading {
                            Text("No biography available.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !viewModel.movies.isEmpty {
                    MediaShelf(title: "Movies", items: viewModel.movies)
                }

                if !viewModel.shows.isEmpty {
                    MediaShelf(title: "TV Shows", items: viewModel.shows)
                }

                if viewModel.media.isEmpty, viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding(80)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task(id: server.uri) {
            await viewModel.load(server: server, client: client)
        }
    }
}

#Preview {
    NavigationStack {
        PersonView(person: PlexTag(id: 1, tag: "Jane Doe", role: "Herself"))
    }
}
