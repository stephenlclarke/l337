import Foundation
import Testing

@testable import L337Core

/// Synthetic display DTOs only: these are NOT actual clock samples, original registers,
/// consent, physical geometry, observations or mission receipts. Formatter tests are UNRUN.
struct NativeAssemblyCalibrationHUDUnitTests {
  private typealias Mode = NativeAssemblySurveyInstrumentControls.Mode

  private func display(_ mode: Mode, seconds: Double = 0)
    -> NativeAssemblySurveyInstrumentControls.Readout
  {
    .init(mode: mode, seconds: seconds, requiredSeconds: 12, fraction: seconds / 12,
      title: "Synthetic calibration display fixture",
      explanation: "Presentation fixture only; no source authority.")
  }

  @Test func everyVisiblePhaseRetainsTheWarningAndRoundedTimeDoesNotDeclareReadiness() {
    #expect(NativeAssemblyCalibrationHUD.lines(for: display(.off)).isEmpty)
    let phases: [(Mode, String)] = [
      (.seeking, "CALIBRATION SEEKING"), (.tracking, "CALIBRATION RUNNING"),
      (.paused, "CALIBRATION PAUSED"), (.exposureReady, "CALIBRATION READY"),
      (.interrupted, "CALIBRATION RESET"),
    ]
    for (mode, expected) in phases {
      let readout = display(mode, seconds: mode == .exposureReady ? 12.04 : 0.26)
      let before = readout
      let lines = NativeAssemblyCalibrationHUD.lines(for: readout)
      #expect(lines.count == 3 && lines.first == expected)
      #expect(lines[1].contains("UNVERIFIED") && lines[2] == "NO REGISTER READING")
      #expect(lines.allSatisfy { $0.count <= 20 && $0.utf8.count == $0.count })
      #expect(readout == before)
    }
    // Rounding can show 12.0 before the actual source mode is ready; never infer readiness.
    let almost = NativeAssemblyCalibrationHUD.lines(for: display(.tracking, seconds: 11.99))
    #expect(almost[1] == "12.0/12s UNVERIFIED" && almost[0] == "CALIBRATION RUNNING")
    let reset = NativeAssemblyCalibrationHUD.lines(for: display(.interrupted))
    #expect(reset[1] == "0.0/12s UNVERIFIED" && reset[2] == "NO REGISTER READING")
  }

  @Test(arguments: [320.0, 640.0, 1280.0])
  func threeShortLinesFitTheExistingResponsiveWrapBudget(_ width: Double) {
    // Same responsive text-column rule as current CockpitLayout. The shared HUD hook
    // is not installed here; this checks contribution size, not rendered acceptance.
    let columns = max(20, Int((width - 24) / (6 * GameTypography.scale)))
    let source = display(.exposureReady, seconds: 12.09)
    let lines = NativeAssemblyCalibrationHUD.lines(for: source)
    let wrapped = lines.flatMap { MissionNotice.wrap($0, width: columns) }
    #expect(wrapped == lines && wrapped.count == 3)
    #expect(wrapped[1] == "12.1/12s UNVERIFIED" && wrapped[2] == "NO REGISTER READING")
    #expect(lines.allSatisfy { $0.count <= min(20, columns) })
  }
}
