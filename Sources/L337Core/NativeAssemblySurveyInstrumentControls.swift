import Foundation

/// Explicit operation of the carried instrument's unqualified calibration mode.
/// This value belongs to the simulation actor when wired; it has no saved representation.
struct NativeAssemblySurveyInstrumentControls: Sendable {
  enum Mode: Equatable, Sendable { case off, seeking, tracking, paused, exposureReady, interrupted }

  /// Last measured instrument state, never a live clearance or authenticated register.
  struct Readout: Equatable, Sendable {
    let mode: Mode
    let seconds: Double
    let requiredSeconds: Double
    let fraction: Double
    let title: String
    let explanation: String
  }

  private var window = NativeAssemblySurveyExposureWindow()
  private var enabled = false
  private var epoch: UUID?
  private var pending: NativeAssemblyOpticalSample?
  private var hasPendingMotion = false

  var readout: Readout {
    let mode: Mode
    if !enabled { mode = .off }
    else {
      switch window.status {
      case .needsTarget: mode = .seeking
      case .paused: mode = .paused
      case .tracking: mode = .tracking
      case .exposureReady: mode = .exposureReady
      case .interrupted: mode = .interrupted
      }
    }
    return .init(mode: mode, seconds: window.seconds,
      requiredSeconds: NativeAssemblySurveyOpticalRules.requiredSeconds,
      fraction: min(1, max(0, window.seconds / NativeAssemblySurveyOpticalRules.requiredSeconds)),
      title: "SURFACE CALIBRATION",
      explanation: "Original register not authenticated. No register reading has been recorded.")
  }

  /// Snapshot synchronization observes only the runtime epoch. It cannot acquire optics,
  /// consume a pending bracket, advance time or authenticate an original register.
  mutating func synchronizedReadout(in game: borrowing Game) -> Readout {
    invalidateEpoch(in: game)
    return readout
  }

  /// Only an explicit player action starts calibration. Refusal also discards old exposure.
  /// Actual Darik survey authorization remains a separate, currently absent source join.
  @discardableResult
  mutating func startCalibration(in game: borrowing Game) throws -> Bool {
    cancel()
    guard let sample = try game.assemblySurveyOpticalSample() else { return false }
    enabled = true
    epoch = sample.epoch
    return true
  }

  mutating func cancel() {
    enabled = false
    epoch = nil
    pending = nil
    hasPendingMotion = false
    window.reset()
  }

  /// Future native ingress calls this immediately before its ordinary motion step.
  /// Opening a screen or reading the readout cannot create a sampling bracket.
  mutating func beginMotion(in game: borrowing Game) throws {
    invalidateEpoch(in: game)
    guard enabled else { return }
    pending = nil
    hasPendingMotion = false
    do {
      pending = try game.assemblySurveyOpticalSample()
      hasPendingMotion = true  // A paused/invalid start is still an observed interruption.
    } catch {
      cancel()
      throw error
    }
  }

  /// A finish consumes its bracket exactly once. The window independently validates actual
  /// adjacent native frames/time/geometry. Neither this driver nor the caller supplies time.
  mutating func finishMotion(in game: borrowing Game) throws {
    invalidateEpoch(in: game)
    guard enabled, hasPendingMotion else { return }
    defer {
      pending = nil
      hasPendingMotion = false
    }
    do { try window.observe(start: pending, end: game) }
    catch {
      cancel()
      throw error
    }
  }

  /// Load/new visit cannot retain armed controls, even without a matching motion callback.
  private mutating func invalidateEpoch(in game: borrowing Game) {
    if let epoch, epoch != game.nativeStationRuntimeEpoch { cancel() }
  }
}
