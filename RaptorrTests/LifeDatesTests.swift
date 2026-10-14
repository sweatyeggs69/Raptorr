import Foundation
import Testing
@testable import Raptorr

struct LifeDatesTests {
    @Test func parsesWikidataTimeAtItsPrecision() {
        #expect(LifeDates.components(time: "+1962-01-17T00:00:00Z", precision: 11) == DateComponents(year: 1962, month: 1, day: 17))
        #expect(LifeDates.components(time: "+1962-01-00T00:00:00Z", precision: 10) == DateComponents(year: 1962, month: 1))
        #expect(LifeDates.components(time: "+1962-00-00T00:00:00Z", precision: 9) == DateComponents(year: 1962))
    }

    @Test func agesCountWholeYears() {
        let died = LifeDates(born: DateComponents(year: 1928, month: 4, day: 4), died: DateComponents(year: 2014, month: 5, day: 28))
        #expect(died.text()?.hasSuffix("(aged 86)") == true)

        let now = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 16))!
        let living = LifeDates(born: DateComponents(year: 1962, month: 1, day: 17))
        #expect(living.text(now: now)?.hasSuffix("(age 63)") == true)
    }
}
