import Testing

@testable import L337Core

/// Pure scalar bounds, not any source, person, receipt, history or native permission.
struct NativeC03CrewCalendarBoundsUnitTests {
  @Test(arguments: [Double.nan, Double.infinity, -Double.infinity, -1])
  func malformedCurrentClockRefusesWithoutConstructingARange(_ current: Double) {
    #expect(!NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: 0, current: current))
  }

  @Test func finiteBoundaryAndInvalidTransferRulesStayExact() {
    #expect(NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: 0, current: 0))
    #expect(NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: 10, current: 10))
    #expect(NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: 9, current: 10))
    #expect(!NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: 11, current: 10))
    for transfer in [Double.nan, Double.infinity, -Double.infinity, -1] {
      #expect(!NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: transfer, current: 10))
    }
  }
}
