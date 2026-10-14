import Foundation
import Testing
@testable import Raptorr

struct PlexModelDecodingTests {
    @Test func decodesMovieWithMediaParts() throws {
        let json = Data("""
        {
          "MediaContainer": {
            "size": 1,
            "Metadata": [{
              "ratingKey": "42",
              "key": "/library/metadata/42",
              "type": "movie",
              "title": "Big Buck Bunny",
              "year": 2008,
              "duration": 596000,
              "viewOffset": 298000,
              "audienceRating": 8.1,
              "Media": [{
                "id": 7,
                "videoResolution": "1080",
                "Part": [{
                  "id": 9,
                  "key": "/library/parts/9/1700000000/file.mkv",
                  "Stream": [
                    { "id": 1, "streamType": 1, "codec": "h264" },
                    { "id": 2, "streamType": 3, "codec": "srt", "key": "/library/streams/2" }
                  ]
                }]
              }],
              "Genre": [{ "tag": "Animation" }]
            }]
          }
        }
        """.utf8)

        let response = try JSONDecoder().decode(PlexResponse.self, from: json)
        let movie = try #require(response.mediaContainer.metadata?.first)

        #expect(movie.kind == .movie)
        #expect(movie.primaryPart?.key == "/library/parts/9/1700000000/file.mkv")
        #expect(movie.primaryPart?.stream?.filter(\.isExternalSubtitle).count == 1)
        #expect(movie.progress == 0.5)
        #expect(movie.genre?.first?.tag == "Animation")
    }

    @Test func decodesLibrarySectionsWithStringOrNumberKeys() throws {
        let json = Data("""
        {
          "MediaContainer": {
            "Directory": [
              { "key": "1", "type": "movie", "title": "Movies" },
              { "key": 2, "type": "show", "title": "TV Shows" },
              { "key": "3", "type": "artist", "title": "Music" }
            ]
          }
        }
        """.utf8)

        let sections = try JSONDecoder().decode(PlexResponse.self, from: json).mediaContainer.directory ?? []

        #expect(sections.map(\.key) == ["1", "2", "3"])
        #expect(sections.filter(\.isSupported).map(\.title) == ["Movies", "TV Shows"])
        #expect(sections[0].type.metadataTypeNumber == 1)
        #expect(sections[1].type.metadataTypeNumber == 2)
    }

    @Test func decodesPin() throws {
        let json = Data(#"{"id": 123, "code": "ABCD", "expiresIn": 900, "authToken": null}"#.utf8)
        let pin = try JSONDecoder().decode(PlexPin.self, from: json)

        #expect(pin.id == 123)
        #expect(pin.code == "ABCD")
        #expect(pin.authToken == nil)
    }
}
