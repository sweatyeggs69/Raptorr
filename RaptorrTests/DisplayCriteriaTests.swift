import Foundation
import Testing
@testable import Raptorr

struct DisplayCriteriaTests {
    private func decodeStream(_ json: String) throws -> PlexStream {
        try JSONDecoder().decode(PlexStream.self, from: Data(json.utf8))
    }

    @Test func frameRateDecodesFromNumberOrString() throws {
        #expect(try decodeStream(#"{"streamType":1,"frameRate":23.976}"#).frameRate?.value == 23.976)
        #expect(try decodeStream(#"{"streamType":1,"frameRate":"29.970"}"#).frameRate?.value == 29.97)
    }

    @Test func criteriaNeedsAFrameRate() throws {
        let withRate = try decodeStream(#"{"streamType":1,"codec":"hevc","frameRate":23.976,"width":3840,"height":2160,"colorTrc":"smpte2084","colorPrimaries":"bt2020","colorSpace":"bt2020nc"}"#)
        let withoutRate = try decodeStream(#"{"streamType":1,"codec":"h264"}"#)
        #expect(DisplayCriteria.make(for: withRate) != nil)
        #expect(DisplayCriteria.make(for: withoutRate) == nil)
    }
}
