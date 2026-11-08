import Foundation

/// Presentation of last measured, unqualified instrument state only. No Game, clock,
/// optical query or mission command is accepted or produced by this formatter.
enum NativeAssemblyCalibrationHUD {
  static func lines(for readout: NativeAssemblySurveyInstrumentControls.Readout) -> [String] {
    let phase: String
    switch readout.mode {
    case .off: return []
    case .seeking: phase = "CALIBRATION SEEKING"
    case .tracking: phase = "CALIBRATION RUNNING"
    case .paused: phase = "CALIBRATION PAUSED"
    case .exposureReady: phase = "CALIBRATION READY"
    case .interrupted: phase = "CALIBRATION RESET"
    }
    // Genuine source values stop at the first >=12s bracket. All three lines fit the
    // existing cockpit's minimum 20-column wrapping budget, including a rounded 12.1s.
    let elapsed = String(format: "%.1f/%.0fs UNVERIFIED",
      locale: Locale(identifier: "en_US_POSIX"), arguments: [readout.seconds, readout.requiredSeconds])
    return [phase, elapsed, "NO REGISTER READING"]
  }
}
