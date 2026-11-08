import Foundation

extension CurrentNewtKitStock {
  /// Observe retained finite stores at actual restoration time. This copies the
  /// original issue/work/history and cannot restart an active offscreen mechanism.
  func observedForRestoration(at time: Double) -> Self? {
    guard let source = CurrentNewtKitSource.current, time.isFinite, time >= observedAt,
      source.matches(self, at: time) else { return nil }
    if phase == .stowed { return self }
    guard interruptedAt != nil || (phase == .released && work.rodMetres == source.stroke),
      work.rodVelocity == 0, let actuation else { return nil }
    var retained = self
    guard retained.observe(at: time, work: work,
      charges: source.charges(at: time, actuation: actuation, work: work,
        serviceCapturedAt: serviceCapturedAt)) else { return nil }
    return retained
  }
}
