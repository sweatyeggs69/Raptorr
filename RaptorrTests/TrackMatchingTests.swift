import Foundation
import Testing
@testable import Raptorr

struct TrackMatchingTests {
    private func stream(
        id: Int,
        type: Int,
        index: Int?,
        language: String? = nil,
        forced: Bool = false,
        selected: Bool = false,
        key: String? = nil
    ) -> PlexStream {
        PlexStream(
            id: id, streamType: type, index: index, codec: nil, language: nil, languageCode: language,
            title: nil, displayTitle: "Stream \(id)", extendedDisplayTitle: nil, selected: selected,
            isDefault: nil, forced: forced, hearingImpaired: nil, key: key
        )
    }

    @Test func subtitlesListEmbeddedByIndexThenSidecars() {
        let part = PlexPart(
            id: 1, key: nil, duration: nil, file: nil, size: nil, container: nil,
            stream: [
                stream(id: 10, type: 3, index: nil, key: "/library/streams/10"),
                stream(id: 11, type: 3, index: 4),
                stream(id: 12, type: 2, index: 1),
                stream(id: 13, type: 3, index: 3),
            ]
        )

        #expect(TrackMatching.plexSubtitleStreams(in: part).compactMap(\.id) == [13, 11, 10])
        #expect(TrackMatching.plexAudioStreams(in: part).compactMap(\.id) == [12])
    }

    @Test func pairsTracksOnlyWhenCountsMatch() {
        let vlc = [
            TrackMatching.VLCTrack(id: "spu/1", name: "Track 1", isSelected: false),
            TrackMatching.VLCTrack(id: "spu/2", name: "Track 2", isSelected: true),
        ]
        let plex = [stream(id: 1, type: 3, index: 1, language: "eng", forced: true), stream(id: 2, type: 3, index: 2)]

        let paired = TrackMatching.options(vlc: vlc, plex: plex)
        #expect(paired.map(\.plexStreamID) == [1, 2])
        #expect(paired[0].isForced)

        let unpaired = TrackMatching.options(vlc: vlc, plex: [plex[0]])
        #expect(unpaired.map(\.name) == ["Track 1", "Track 2"])
        #expect(unpaired.allSatisfy { $0.plexStreamID == nil })
    }

    @Test func autoPicksForcedTrackInAudioLanguage() {
        let subtitles = [
            TrackOption(id: "a", name: "English", isSelected: false, languageCode: "eng"),
            TrackOption(id: "b", name: "French Forced", isSelected: false, languageCode: "fre", isForced: true),
            TrackOption(id: "c", name: "English Forced", isSelected: false, languageCode: "eng", isForced: true),
        ]

        #expect(TrackMatching.forcedTrack(in: subtitles, audioLanguage: "eng")?.id == "c")
        #expect(TrackMatching.forcedTrack(in: subtitles, audioLanguage: "ger") == nil)
        #expect(TrackMatching.forcedTrack(in: subtitles, audioLanguage: nil)?.id == "b")
    }

    @Test func initialModeUsesServerPreferenceOrAuto() {
        let preferred = TrackOption(id: "a", name: "English", isSelected: false, isPlexSelected: true)
        let forcedPreferred = TrackOption(id: "b", name: "Forced", isSelected: false, isForced: true, isPlexSelected: true)

        #expect(TrackMatching.initialSubtitleMode(for: [preferred]) == .track(id: "a"))
        #expect(TrackMatching.initialSubtitleMode(for: [forcedPreferred]) == .auto)
        #expect(TrackMatching.initialSubtitleMode(for: []) == .auto)
    }

    @Test func menuTitleMarksForcedAndSDH() throws {
        let json = Data(#"{"id": 1, "streamType": 3, "displayTitle": "English (SRT)", "forced": true, "hearingImpaired": true, "default": true}"#.utf8)
        let decoded = try JSONDecoder().decode(PlexStream.self, from: json)

        #expect(decoded.isDefault == true)
        #expect(decoded.menuTitle == "English (SRT) · Forced · SDH")
    }

    @Test func logoComesFromClearLogoImage() {
        let movie = PlexMetadata(
            ratingKey: "1",
            title: "Movie",
            image: [
                PlexImage(type: "coverPoster", url: "/poster", alt: nil),
                PlexImage(type: "clearLogo", url: "/logo", alt: nil),
            ]
        )

        #expect(movie.logoPath == "/logo")
        #expect(PlexMetadata(ratingKey: "2", title: "No Logo").logoPath == nil)
    }
}
