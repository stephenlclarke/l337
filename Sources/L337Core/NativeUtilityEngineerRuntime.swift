import Foundation

/// An opaque current inspection offer. Equality compares captured facts, not wrapper identity.
struct NativeUtilityEngineerInspectionAuthority: Sendable, Equatable {
  let engineer: UUID
  fileprivate let witness: NativeOriginalUtilityDockWitness
  fileprivate let custody: NativePeopleCustodyState
  fileprivate let utility: NativeUtilityState

  fileprivate init(witness: NativeOriginalUtilityDockWitness,
    custody: NativePeopleCustodyState, utility: NativeUtilityState, engineer: UUID)
  {
    self.witness = witness
    self.custody = custody
    self.utility = utility
    self.engineer = engineer
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.engineer == rhs.engineer && lhs.custody == rhs.custody && lhs.utility == rhs.utility
      && lhs.witness.receipt == rhs.witness.receipt
      && lhs.witness.runtimeEpoch == rhs.witness.runtimeEpoch
      && lhs.witness.physicalTime == rhs.witness.physicalTime
      && lhs.witness.utilityRevision == rhs.witness.utilityRevision
      && lhs.witness.owner == rhs.witness.owner
      && lhs.witness.stationRevision == rhs.witness.stationRevision
  }
}

fileprivate enum NativeUtilityEngineerMutationKind: Sendable {
  case birth(NativeOriginalUtilityBirthWitness)
  case inspection(NativeUtilityEngineerInspectionAuthority, NativeUtilityInstallation, UUID, UInt64)
  case casualty(NativeOriginalUtilityFatalTransition)
}

/// Only prepared people are assigned here; G3 owns the reciprocal native publication.
final class NativeUtilityEngineerMutationPlan: Sendable {
  let operation: UUID
  fileprivate let before: NativePeopleCustodyState?
  let after: NativePeopleCustodyState
  fileprivate let kind: NativeUtilityEngineerMutationKind

  fileprivate init(operation: UUID, before: NativePeopleCustodyState?,
    after: NativePeopleCustodyState, kind: NativeUtilityEngineerMutationKind)
  {
    self.operation = operation
    self.before = before
    self.after = after
    self.kind = kind
  }
}

extension Game {
  func prepareNativeUtilityEngineerBirth(_ witness: NativeOriginalUtilityBirthWitness) throws
    -> NativeUtilityEngineerMutationPlan
  {
    guard acceptsNativeOriginalUtilityBirthWitness(witness), commander.nativePeopleStateValid,
      let owner = commander.equipmentOwnerID, owner == witness.station.world,
      witness.station == OriginalStationSite.remoteUtility.identity(world: owner),
      witness.sourceVersion == OriginalStationSite.sourceVersion,
      witness.epoch == nativeStationRuntimeEpoch,
      witness.priorVisit == commander.flightSimulation.visit,
      witness.priorNextActor == commander.flightSimulation.nextActor,
      witness.priorNextSpawn == commander.flightSimulation.nextSpawn,
      commander.nativePeople?.utilityEngineer == nil
    else { throw SaveError.invalidCommander }
    let identity = NativeUtilityEngineerIdentity(owner: owner)
    let registration = NativeUtilityEngineerRegistration(
      operation: NativeUtilityEngineer.birthOperation(owner: owner), identity: identity,
      station: witness.station, sourceVersion: witness.sourceVersion,
      binding: witness.binding, spawn: witness.spawn,
      physicalTime: witness.physicalTime, epoch: witness.epoch)
    var custody = commander.nativePeople ?? .init(owner: owner)
    custody.utilityEngineer = .init(registration: registration)
    let plan = NativeUtilityEngineerMutationPlan(operation: registration.operation,
      before: commander.nativePeople, after: custody, kind: .birth(witness))
    try validateNativeUtilityEngineerMutation(plan)
    return plan
  }

  func nativeUtilityEngineerInspectionAuthority(_ witness: NativeOriginalUtilityDockWitness)
    -> NativeUtilityEngineerInspectionAuthority?
  {
    guard acceptsNativeOriginalUtilityDockWitness(witness), commander.nativePeopleStateValid,
      let custody = commander.nativePeople, custody.owner == witness.owner,
      let source = custody.utilityEngineer, source.casualty == nil,
      source.registration.identity.owner == witness.owner,
      source.registration.station == witness.receipt.station,
      source.recordedLocation == .residentAtSource(witness.receipt.station),
      let utility = commander.nativeUtility, utility.owner == custody.owner,
      utility.revision == witness.utilityRevision,
      source.registration.identity.id == utility.engineer
    else { return nil }
    return .init(witness: witness, custody: custody, utility: utility, engineer: utility.engineer)
  }

  func prepareNativeUtilityEngineerInspection(
    _ authority: NativeUtilityEngineerInspectionAuthority,
    installation: NativeUtilityInstallation, consignment: UUID, operation: UUID,
    prospectiveUtilityRevision: UInt64
  ) throws -> NativeUtilityEngineerMutationPlan {
    guard nativeUtilityEngineerInspectionAuthority(authority.witness) == authority,
      let job = authority.utility.active, job.id == consignment, job.phase == .installed,
      job.installation == installation, job.reception == nil,
      installation.engineer == authority.engineer,
      installation.contact.lifecycle == authority.witness.receipt.lifecycleRevision,
      authority.utility.revision < UInt64(Int64.max) - 1,
      prospectiveUtilityRevision == authority.utility.revision + 1,
      operation == authority.utility.operation(
        consignment, stage: "receive", revision: prospectiveUtilityRevision),
      var source = authority.custody.utilityEngineer, source.casualty == nil,
      source.inspections.count < 2
    else { throw SaveError.invalidCommander }
    source.inspections.append(.init(operation: operation, consignment: consignment,
      installation: installation, dock: authority.witness.receipt,
      utilityRevision: prospectiveUtilityRevision,
      physicalTime: authority.witness.physicalTime, epoch: authority.witness.runtimeEpoch))
    var custody = authority.custody
    custody.utilityEngineer = source
    let plan = NativeUtilityEngineerMutationPlan(operation: operation,
      before: commander.nativePeople, after: custody,
      kind: .inspection(authority, installation, consignment, prospectiveUtilityRevision))
    try validateNativeUtilityEngineerMutation(plan)
    return plan
  }

  func prepareNativeUtilityEngineerCasualty(_ transition: NativeOriginalUtilityFatalTransition)
    throws -> NativeUtilityEngineerMutationPlan
  {
    guard acceptsNativeOriginalUtilityFatalTransition(transition),
      commander.nativePeopleStateValid, let custody = commander.nativePeople,
      custody.owner == transition.station.world, var source = custody.utilityEngineer,
      source.casualty == nil, source.registration.station == transition.station,
      let physical = transition.actor.physical, let incident = physical.deathIncidentID,
      let origin = physical.deathOrigin
    else { throw SaveError.invalidCommander }
    let operation = NativeUtilityEngineer.casualtyOperation(
      owner: custody.owner, binding: transition.binding, incident: incident)
    source.casualty = .init(operation: operation, binding: transition.binding,
      priorLifecycleRevision: transition.priorLifecycleRevision, tombstone: transition.tombstone,
      incident: incident, origin: origin, startTime: transition.startTime,
      usedDuration: transition.usedDuration, physicalTime: transition.physicalTime,
      preNextIncident: transition.preNextIncident,
      postNextIncident: transition.postNextIncident, epoch: transition.epoch)
    var after = custody
    after.utilityEngineer = source
    let plan = NativeUtilityEngineerMutationPlan(operation: operation,
      before: custody, after: after, kind: .casualty(transition))
    try validateNativeUtilityEngineerMutation(plan)
    return plan
  }

  mutating func commitNativeUtilityEngineerMutation(_ plan: NativeUtilityEngineerMutationPlan)
    throws
  {
    try validateNativeUtilityEngineerMutation(plan)
    // All currentness and whole prospective people checks precede this only assignment.
    commander.savedNativePeopleCustody = plan.after
  }

  /// Validate a local value against the exact reciprocal state, without changing the Game.
  private func validateNativeUtilityEngineerMutation(_ plan: NativeUtilityEngineerMutationPlan)
    throws
  {
    guard commander.nativePeople == plan.before, commander.nativePeopleStateValid,
      plan.after.owner == commander.equipmentOwnerID,
      let source = plan.after.utilityEngineer, NativeUtilityEngineerSave.shapeValid(source)
    else { throw SaveError.invalidCommander }
    var projected = commander
    switch plan.kind {
    case .birth(let witness):
      guard acceptsNativeOriginalUtilityBirthWitness(witness),
        let population = nativeOriginalStationPopulationPlan,
        plan.before?.utilityEngineer == nil,
        source.registration.operation == plan.operation,
        source.inspections.isEmpty, source.casualty == nil
      else { throw SaveError.invalidCommander }
      projected.nativeStations = population.worldAfter
      projected.flightSimulation = population.flightAfter
    case .inspection(let authority, let installation, let consignment, let revision):
      guard nativeUtilityEngineerInspectionAuthority(authority.witness) == authority,
        var world = commander.nativeStations,
        let index = authority.utility.consignments.firstIndex(where: { $0.id == consignment })
      else { throw SaveError.invalidCommander }
      var utility = authority.utility
      guard utility.revision < UInt64(Int64.max) - 1, revision == utility.revision + 1,
        utility.consignments[index].phase == .installed,
        utility.consignments[index].installation == installation,
        utility.consignments[index].reception == nil,
        plan.operation == utility.operation(consignment, stage: "receive", revision: revision)
      else { throw SaveError.invalidCommander }
      utility.revision = revision
      utility.consignments[index].phase = .received
      utility.consignments[index].reception = .init(operation: plan.operation,
        installation: installation.operation, engineer: authority.engineer,
        contact: .init(authority.witness.receipt), revision: revision)
      try world.ledger.replaceUtility(utility)
      projected.nativeStations = world
    case .casualty(let transition):
      guard acceptsNativeOriginalUtilityFatalTransition(transition),
        let world = nativeOriginalUtilityFatalProspectiveWorld(transition),
        plan.before?.utilityEngineer?.casualty == nil,
        source.casualty?.operation == plan.operation
      else { throw SaveError.invalidCommander }
      projected.nativeStations = world
    }
    projected.savedNativePeopleCustody = plan.after
    guard projected.nativePeopleStateValid else { throw SaveError.invalidCommander }
  }
}
