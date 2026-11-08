import Foundation

/// Runtime-only instrument exposure. This is NOT a qualified/persistent original survey
/// reading and supplies no permission, register contents or mission-stage authority.
struct NativeAssemblyOpticalExposure: Sendable {
  let first: NativeAssemblyOpticalSample
  let last: NativeAssemblyOpticalSample
  let seconds: Double
  let intervals: Int

  fileprivate init(first: NativeAssemblyOpticalSample, last: NativeAssemblyOpticalSample,
    seconds: Double, intervals: Int)
  {
    self.first = first
    self.last = last
    self.seconds = seconds
    self.intervals = intervals
  }
}

/// Owned interval controller for future simulation-actor ingress. No caller elapsed time,
/// Codable runtime state, UI callback, generic helper or native mission receipt is introduced.
struct NativeAssemblySurveyExposureWindow: Sendable {
  enum Status: Equatable, Sendable { case needsTarget, paused, tracking, exposureReady, interrupted }
  private var first: NativeAssemblyOpticalSample?
  private var last: NativeAssemblyOpticalSample?
  private(set) var seconds = 0.0
  private(set) var intervals = 0
  private(set) var exposure: NativeAssemblyOpticalExposure?
  private(set) var status: Status = .needsTarget

  mutating func reset() {
    first = nil
    last = nil
    seconds = 0
    intervals = 0
    exposure = nil
    status = .needsTarget
  }

  /// The owner must supply the actual pre-motion acquisition and post-motion Game. The
  /// physical tick hook is not installed by this component; rendering cannot award progress.
  mutating func observe(start: NativeAssemblyOpticalSample?, end game: borrowing Game) throws {
    if let last, last.epoch != game.nativeStationRuntimeEpoch { reset() }
    if game.paused {
      status = .paused
      return
    }
    guard let start else {
      reset()
      status = .interrupted
      return
    }
    let acquired: NativeAssemblyOpticalSample?
    do { acquired = try game.assemblySurveyOpticalSample() }
    catch {
      reset()
      status = .interrupted
      throw error
    }
    guard let end = acquired, start.sameProbe(as: end),
      start.frame < UInt64.max, end.frame == start.frame + 1,
      start.physicalTime.isFinite, end.physicalTime.isFinite
    else {
      reset()
      status = .interrupted
      return
    }
    let interval = end.physicalTime - start.physicalTime
    guard interval > 0, interval <= NativeAssemblySurveyOpticalRules.maximumInterval + 1e-9 else {
      reset()
      status = .interrupted
      return
    }
    if let previous = last, previous.sameObservation(as: end) {
      status = exposure == nil ? .tracking : .exposureReady
      return
    }
    if let previous = last, end.frame <= previous.frame {
      reset()
      status = .interrupted
      return
    }
    if let previous = last, previous.sameObservation(as: start) {
      guard intervals < 1_000_000 else {
        reset()
        status = .interrupted
        return
      }
    } else {
      reset()
      first = start
    }
    last = end
    if exposure == nil {
      seconds += interval
      intervals += 1
      if seconds >= NativeAssemblySurveyOpticalRules.requiredSeconds, let first {
        exposure = .init(first: first, last: end, seconds: seconds, intervals: intervals)
      }
    }
    status = exposure == nil ? .tracking : .exposureReady
  }
}
