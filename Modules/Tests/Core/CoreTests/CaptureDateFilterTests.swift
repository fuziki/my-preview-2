import Testing
import Foundation
import Core

struct CaptureDateFilterTests {

    private let base = Date(timeIntervalSince1970: 1_000_000)

    @Test
    func emptyFilter_matchesEverything_includingNilDate() {
        let filter = CaptureDateFilter()
        #expect(filter.isEmpty)
        #expect(filter.matches(captureDate: base))
        #expect(filter.matches(captureDate: nil))
    }

    @Test
    func startOnly_matchesAtOrAfterStart() {
        let filter = CaptureDateFilter(start: base, end: nil)
        #expect(filter.matches(captureDate: base))
        #expect(filter.matches(captureDate: base.addingTimeInterval(1)))
        #expect(filter.matches(captureDate: base.addingTimeInterval(-1)) == false)
    }

    @Test
    func endOnly_matchesAtOrBeforeEnd() {
        let filter = CaptureDateFilter(start: nil, end: base)
        #expect(filter.matches(captureDate: base))
        #expect(filter.matches(captureDate: base.addingTimeInterval(-1)))
        #expect(filter.matches(captureDate: base.addingTimeInterval(1)) == false)
    }

    @Test
    func range_matchesInclusiveBothEnds() {
        let end = base.addingTimeInterval(60)
        let filter = CaptureDateFilter(start: base, end: end)
        #expect(filter.matches(captureDate: base))
        #expect(filter.matches(captureDate: end))
        #expect(filter.matches(captureDate: base.addingTimeInterval(30)))
        #expect(filter.matches(captureDate: end.addingTimeInterval(1)) == false)
    }

    @Test
    func nonEmptyFilter_doesNotMatchNilDate() {
        #expect(CaptureDateFilter(start: base, end: nil).matches(captureDate: nil) == false)
        #expect(CaptureDateFilter(start: nil, end: base).matches(captureDate: nil) == false)
    }
}
