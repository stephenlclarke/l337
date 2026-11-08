import Foundation

/// Real source-powered contact input, not a prescribed future pod pose. G3's
/// native drive contact owner validates the actual paired shoes/rods before force.
struct CurrentNewtDrivePlan: Sendable {
  let issue: CurrentNewtKitIssue
  let actuation: CurrentNewtKitStock.Actuation
  let interval: CurrentNewtMechanicalInterval
  let parentActor: ActorIdentity
  let podActor: ActorIdentity
  let receipt: CurrentNewtKitReceipt
  let load: CurrentNewtKitLoad
  let parent: CurrentNewtKitReceipt.BodyState
  let pod: CurrentNewtKitReceipt.BodyState
  let parentMass: CurrentNewtKitReceipt.MassProperties
  let podMass: CurrentNewtKitReceipt.MassProperties
  let parentComponents: [CurrentNewtKitComponent]
  let podComponents: [CurrentNewtKitComponent]
  let work: CurrentNewtKitStock.WorkState
  let maximumForceNewtons: Double
  let maximumGuideFrictionNewtons: Double
  let maximumAdditionalWorkJoules: Double
  let maximumAvailableMechanicalJoules: Double
  let strokeLimitMetres: Double
  let targetRelativeSpeedMetresPerSecond: Double
}

/// Returned only from the one real native/contact callback. It describes actual
/// consumed work and retained independent-body motion, never a pose to replay.
struct CurrentNewtDriveOutcome: Sendable {
  let kitID: UUID
  let parentActor: ActorIdentity
  let podActor: ActorIdentity
  let observedAt: Double
  let work: CurrentNewtKitStock.WorkState
  let impulseOnPod: Vector3
  let interruptedAt: Double?
}


extension CurrentNewtDriveOutcome {
  func valid(for plan: CurrentNewtDrivePlan) -> Bool {
    kitID == plan.issue.kitID && parentActor == plan.parentActor && podActor == plan.podActor
      && observedAt == plan.interval.end && work.structurallyValid && impulseOnPod.finite
      && work.loweredFraction == plan.work.loweredFraction
      && work.rodMetres >= plan.work.rodMetres && work.rodMetres <= plan.strokeLimitMetres
      && work.guideWorkJoules == plan.work.guideWorkJoules
      && work.ejectionWorkJoules >= plan.work.ejectionWorkJoules
      && work.ejectionWorkJoules - plan.work.ejectionWorkJoules
        <= plan.maximumAdditionalWorkJoules + 1e-6
      && (interruptedAt.map { $0.isFinite && $0 >= plan.interval.start && $0 <= plan.interval.end } ?? true)
  }
}
