import Foundation

/// Whole current native context, retained only in private, non-Codable offers/capsules.
/// Source history and actor condition remain in their existing owners.
fileprivate struct NativeC01ClinicPeopleContext: Sendable, Equatable {
  let inFlight: Bool
  let playerEnergy: Double
  let playerDisabled: Bool
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let inventoryHash: String
  let credits: Int
  let epoch: UUID
  let flight: FlightSimulationState
  let bodies: [SpaceBody]
  let nextBodyID: Int
  let reference: ShipPose

  init?(_ game: borrowing Game) {
    guard game.systemIdentity == NativeC01ClinicEscort.location,
      let owner = game.commander.equipmentOwnerID, let carrier = game.commander.hullInstanceID,
      let inventory = game.commander.equipmentInventory,
      let inventoryHash = try? NativeFlightReception.hash(inventory),
      let anchor = game.scriptAnchor, game.commander.flightSimulation.player != nil
    else { return nil }
    inFlight = !game.docked && !game.paused && game.screen.isFlight
    playerEnergy = game.energy
    playerDisabled = game.playerEMPDisabled
    self.owner = owner
    self.carrier = carrier
    inventoryRevision = inventory.revision
    self.inventoryHash = inventoryHash
    credits = game.commander.credits
    epoch = game.nativeStationRuntimeEpoch
    flight = game.commander.flightSimulation
    bodies = game.bodies
    nextBodyID = game.nextBodyID
    reference = .init(position: flight.pose.systemPoint(anchor.position),
      orientation: anchor.orientation.transformed(by: flight.pose.orientation))
  }
}

final class NativeC01ClinicSourceIntent: Sendable {
  let birth: NativeC01ClinicStockBirth
  fileprivate let source: NativeC01ClinicEscortSource
  fileprivate let context: NativeC01ClinicPeopleContext
  fileprivate let custody: NativePeopleCustodyState?
  fileprivate let mission: ScriptInstance

  fileprivate init(source: NativeC01ClinicEscortSource, context: NativeC01ClinicPeopleContext,
    custody: NativePeopleCustodyState?, mission: ScriptInstance)
  {
    self.source = source
    self.context = context
    self.custody = custody
    self.mission = mission
    birth = .init(registration: NativeC01ClinicPeople.registrationOperation(owner: source.owner),
      units: (0..<2).map { ordinal in
        .init(ordinal: ordinal,
          registeredHull: NativeC01ClinicPeople.hull(owner: source.owner, ordinal: ordinal),
          pilot: .clinicPilot(NativeC01ClinicPeople.person(owner: source.owner, ordinal: ordinal)))
      }, cradle: .init(position: source.position, orientation: Basis3()),
      reference: source.reference, physicalTime: context.flight.physicalTime)
  }
}

final class NativeC01ClinicSourceAdmissionPlan: Sendable {
  fileprivate let admission: NativeMissionActorAdmissionPlan
  fileprivate let context: NativeC01ClinicPeopleContext
  fileprivate let beforeCustody: NativePeopleCustodyState?
  fileprivate let beforeMission: ScriptInstance
  fileprivate let custody: NativePeopleCustodyState
  fileprivate let mission: ScriptInstance

  fileprivate init(admission: NativeMissionActorAdmissionPlan,
    context: NativeC01ClinicPeopleContext, beforeCustody: NativePeopleCustodyState?,
    beforeMission: ScriptInstance, custody: NativePeopleCustodyState, mission: ScriptInstance)
  {
    self.admission = admission
    self.context = context
    self.beforeCustody = beforeCustody
    self.beforeMission = beforeMission
    self.custody = custody
    self.mission = mission
  }
}

final class NativeC01ClinicPeopleQuote: Sendable {
  var pilotName: String { unit.pilotName }
  fileprivate let context: NativeC01ClinicPeopleContext
  fileprivate let custody: NativePeopleCustodyState
  fileprivate let mission: ScriptInstance
  fileprivate let unit: NativeC01ClinicRegisteredUnit
  fileprivate let actor: ScriptOwnedActor
  fileprivate let consent: NativeC01ClinicPilotConsent

  fileprivate init(context: NativeC01ClinicPeopleContext, custody: NativePeopleCustodyState,
    mission: ScriptInstance, unit: NativeC01ClinicRegisteredUnit, actor: ScriptOwnedActor,
    consent: NativeC01ClinicPilotConsent)
  {
    self.context = context
    self.custody = custody
    self.mission = mission
    self.unit = unit
    self.actor = actor
    self.consent = consent
  }
}

final class NativeC01ClinicPeopleIntent: Sendable {
  let launch: NativeC01ClinicLaunch
  fileprivate let quote: NativeC01ClinicPeopleQuote

  fileprivate init(quote: NativeC01ClinicPeopleQuote, launch: NativeC01ClinicLaunch) {
    self.quote = quote
    self.launch = launch
  }
}

final class NativeC01ClinicPeopleAssignmentPlan: Sendable {
  fileprivate let context: NativeC01ClinicPeopleContext
  fileprivate let beforeCustody: NativePeopleCustodyState
  fileprivate let custody: NativePeopleCustodyState
  fileprivate let mission: ScriptInstance

  fileprivate init(context: NativeC01ClinicPeopleContext,
    beforeCustody: NativePeopleCustodyState, custody: NativePeopleCustodyState,
    mission: ScriptInstance)
  {
    self.context = context
    self.beforeCustody = beforeCustody
    self.custody = custody
    self.mission = mission
  }
}

final class NativeC01ClinicPilotLossWitness: Sendable {
  var actor: ScriptOwnedActor { transition.actor }
  var physicalTime: Double { transition.physicalTime }
  fileprivate let transition: NativeC01ClinicFatalTransition
  fileprivate let registration: NativeC01ClinicSourceRegistration
  fileprivate let assignment: NativeC01ClinicPeopleAssignment?

  fileprivate init(transition: NativeC01ClinicFatalTransition,
    registration: NativeC01ClinicSourceRegistration, assignment: NativeC01ClinicPeopleAssignment?)
  {
    self.transition = transition
    self.registration = registration
    self.assignment = assignment
  }
}

final class NativeC01ClinicPeopleDispositionPlan: Sendable {
  let operation: UUID
  fileprivate let context: NativeC01ClinicPeopleContext
  fileprivate let beforeCustody: NativePeopleCustodyState
  fileprivate let custody: NativePeopleCustodyState
  fileprivate let mission: ScriptInstance
  fileprivate let state: NativeC01ClinicEscortState
  fileprivate let actor: ScriptOwnedActor
  fileprivate let ordinal: Int
  fileprivate let kind: NativeC01ClinicDispositionKind

  fileprivate init(operation: UUID, context: NativeC01ClinicPeopleContext,
    beforeCustody: NativePeopleCustodyState, custody: NativePeopleCustodyState,
    mission: ScriptInstance, state: NativeC01ClinicEscortState, actor: ScriptOwnedActor,
    ordinal: Int, kind: NativeC01ClinicDispositionKind)
  {
    self.operation = operation
    self.context = context
    self.beforeCustody = beforeCustody
    self.custody = custody
    self.mission = mission
    self.state = state
    self.actor = actor
    self.ordinal = ordinal
    self.kind = kind
  }
}

extension Game {
  func prepareC01ClinicSourceIntent(_ source: NativeC01ClinicEscortSource) throws
    -> NativeC01ClinicSourceIntent
  {
    guard !playerEMPDisabled, source == c01ClinicSourceContext(), let context = NativeC01ClinicPeopleContext(self),
      source.owner == context.owner, source.visit == context.flight.visit,
      source.physicalTime == context.flight.physicalTime, source.reference == context.reference,
      let mission = glassMeridianMission, mission.savedGlassMeridian?.clinicEscort == nil,
      mission.revision < UInt64(Int64.max) - 1,
      mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter] == nil,
      commander.nativePeople?.clinicSource == nil,
      commander.nativePeople.map({ $0.owner == source.owner }) ?? true,
      NativeC01ClinicPeople.sourceIDsExclusive(commander),
      !bodies.contains(where: { body in
        body.missionInstanceID == mission.id &&
          (body.missionActorID == NativeC01ClinicEscort.cradle(mission: mission.id)
            || (0..<2).contains(where: { ordinal in
              body.missionActorID == NativeC01ClinicEscort.actor(mission: mission.id, ordinal: ordinal)
            }))
      })
    else { throw SaveError.invalidCommander }
    // Loading the exact maintained resources is fallible and precedes every native allocation.
    _ = try NativeC01ClinicCradle.original.get()
    _ = try NativeC01SurveyorGeometry.harrier.get()
    return .init(source: source, context: context, custody: commander.nativePeople, mission: mission)
  }

  func prepareC01ClinicSourceAdmission(_ intent: NativeC01ClinicSourceIntent,
    admission: NativeMissionActorAdmissionPlan) throws -> NativeC01ClinicSourceAdmissionPlan
  {
    guard NativeC01ClinicPeopleContext(self) == intent.context,
      commander.nativePeople == intent.custody, commander.nativePeople?.clinicSource == nil,
      c01ClinicSourceContext() == intent.source,
      let current = glassMeridianMission, var opening = current.savedGlassMeridian,
      let state = opening.clinicEscort, state.source == intent.source, state.birth == intent.birth,
      state.launches.isEmpty, state.parkedLosses.isEmpty, state.arrival == nil,
      current.revision == intent.mission.revision + 1,
      NativeC01ClinicPeople.sourceIDsExclusive(commander)
    else { throw SaveError.invalidCommander }
    // Verify G3 staged only this source before using its SAME sealed native retention plan.
    var normalized = current
    opening.clinicEscort = nil
    normalized.savedGlassMeridian = opening
    normalized.ownedEncounters.removeValue(forKey: NativeC01ClinicEscort.sourceEncounter)
    normalized.revision = intent.mission.revision
    guard normalized == intent.mission else { throw SaveError.invalidCommander }
    let staged = try admission.retentionPatch.preparingInstance(current)
    guard let group = staged.ownedEncounters[NativeC01ClinicEscort.sourceEncounter],
      group.admitted, group.valid, group.actors.count == 3,
      Set(admission.sceneBodyIDs.keys) == Set(group.actors.values.map(\.identity)),
      let cradle = group.actors[NativeC01ClinicEscort.cradleTarget],
      NativeC01ClinicPeople.initialActor(cradle, source: intent.source, ordinal: nil,
        birth: intent.birth, bodyIDs: admission.sceneBodyIDs),
      let framePhysical = cradle.body.physical
    else { throw SaveError.invalidCommander }
    var units: [NativeC01ClinicRegisteredUnit] = []
    for ordinal in 0..<2 {
      guard let actor = group.actors[NativeC01ClinicEscort.stockTarget(ordinal)],
        NativeC01ClinicPeople.initialActor(actor, source: intent.source, ordinal: ordinal,
          birth: intent.birth, bodyIDs: admission.sceneBodyIDs),
        let physical = actor.body.physical
      else { throw SaveError.invalidCommander }
      units.append(.init(ordinal: ordinal,
        registeredHull: NativeC01ClinicPeople.hull(owner: intent.source.owner, ordinal: ordinal),
        pilot: NativeC01ClinicPeople.person(owner: intent.source.owner, ordinal: ordinal),
        pilotName: NativeC01ClinicPeople.definitions[ordinal].name, adult: true,
        consentPolicy: NativeC01ClinicPeople.consentPolicy, intrinsicPlace: 0,
        mass: NativeC01ClinicPeople.mass, actor: actor.identity,
        birthPhysical: physical.identity,
        berth: NativeC01ClinicEscort.parkedPose(cradle: intent.birth.cradle, ordinal: ordinal)))
    }
    let registration = NativeC01ClinicSourceRegistration(operation: intent.birth.registration,
      source: intent.source, birth: intent.birth,
      facility: NativeC01ClinicPeople.facility(owner: intent.source.owner),
      cradle: framePhysical.identity, cradlePose: intent.birth.cradle,
      cradleVelocity: framePhysical.velocity, cradleAngularVelocity: framePhysical.angularVelocity,
      resourceSHA256: NativeC01ClinicCradle.resourceSHA256,
      recipeSHA256: NativeC01ClinicCradle.recipeSHA256, units: units,
      physicalTime: intent.context.flight.physicalTime, epoch: intent.context.epoch)
    let source = NativeC01ClinicSourceState(registration: registration)
    guard NativeC01ClinicPeopleSave.shapeValid(source) else { throw SaveError.invalidCommander }
    var custody = intent.custody ?? .init(owner: intent.source.owner)
    custody.clinicSource = source
    return .init(admission: admission, context: intent.context, beforeCustody: intent.custody,
      beforeMission: current, custody: custody, mission: staged)
  }

  mutating func commitC01ClinicSourceAdmission(_ capsule: NativeC01ClinicSourceAdmissionPlan) throws
    -> NativeMissionActorAdmissionReceipt
  {
    guard NativeC01ClinicPeopleContext(self) == capsule.context,
      commander.nativePeople == capsule.beforeCustody,
      commander.scriptState.instances[capsule.beforeMission.id] == capsule.beforeMission
    else { throw SaveError.invalidCommander }
    let receipt = try commitMissionActorAdmission(capsule.admission)
    // The selected instance and custody were fully prepared before the native commit.
    commander.savedNativePeopleCustody = capsule.custody
    commander.scriptState.instances[capsule.mission.id] = capsule.mission
    return receipt
  }
}

private extension NativeC01ClinicPeople {
  static var mass: NativeC01ClinicMassTerms {
    .init(dryHullKilograms: 25545, pilotKilograms: 80, fuelKilograms: 0,
      cargoKilograms: 0, roleKitKilograms: 0, ammunitionKilograms: 0, otherPeopleKilograms: 0)
  }

  static func sourceIDsExclusive(_ commander: borrowing Commander) -> Bool {
    guard let owner = commander.equipmentOwnerID else { return false }
    let people = Set((0..<2).map { person(owner: owner, ordinal: $0).id })
    let hulls = Set((0..<2).map { hull(owner: owner, ordinal: $0) })
    guard !people.contains(owner) else { return false }
    guard let ownedHull = commander.hullInstanceID, !hulls.contains(ownedHull) else { return false }
    if commander.nativePeople?.admissions.contains(where: {
      $0.person.nativeID.map { people.contains($0) } ?? false
    }) == true { return false }
    if commander.accommodation.ownedBerths.contains(where: {
      $0.use.personID.map { people.contains($0) } ?? false
    }) { return false }
    return !(commander.nativePeople?.crewService?.people.contains(where: {
      people.contains($0.identity.id)
    }) ?? false)
  }

  static func initialActor(_ actor: ScriptOwnedActor, source: NativeC01ClinicEscortSource,
    ordinal: Int?, birth: NativeC01ClinicStockBirth, bodyIDs: [UUID: Int]) -> Bool
  {
    let expected = ordinal.map { NativeC01ClinicEscort.parkedPose(cradle: birth.cradle, ordinal: $0) }
      ?? birth.cradle
    let local = birth.reference.shipPoint(expected.position)
    guard actor.presence == .present, actor.body.id == bodyIDs[actor.identity],
      NativeC01ClinicEscort.original(actor, source: source, ordinal: ordinal),
      actor.body.position == local,
      actor.body.orientation == expected.orientation.relative(to: birth.reference.orientation),
      let physical = actor.body.physical,
      physical.identity.visit == source.visit,
      NativeC01ClinicEscort.nativeValid(physical, cradle: ordinal == nil),
      physical.deathIncidentID == nil, physical.deathOrigin == nil,
      actor.body.energy == actor.body.scriptNPC?.fit.definition.energy,
      let resources = physical.npc?.resources,
      resources.frontShield == resources.frontCapacity,
      resources.rearShield == resources.rearCapacity
    else { return false }
    return true
  }
}


extension Game {
  func c01ClinicPeopleQuote() -> NativeC01ClinicPeopleQuote? {
    guard !playerEMPDisabled, let context = NativeC01ClinicPeopleContext(self),
      let actualSource = c01ClinicSourceContext(),
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      let custody = commander.nativePeople, let source = custody.clinicSource,
      source.registration.source == actualSource, source.registration.birth == state.birth,
      NativeC01ClinicPeopleSave.sourceClaimsMatch(state, mission: mission, commander: commander),
      state.arrival == nil, state.current == nil || state.current?.loss != nil,
      source.assignments.count < NativeC01ClinicPeople.maximumAssignments,
      let unit = source.registration.units.first(where: {
        source.assignment($0.ordinal) == nil && source.disposition($0.ordinal) == nil
      }), unit.adult, unit.consentPolicy == NativeC01ClinicPeople.consentPolicy,
      let facts = commander.c01ClinicStockPilotFacts(ordinal: unit.ordinal),
      facts.location == .aboardStored, facts.pilot == .clinicPilot(unit.pilot),
      facts.registeredHull == unit.registeredHull, facts.intrinsicPlace == 0,
      facts.mass.valid, facts.loadedMassKilograms == 25625,
      NativeC01ClinicPeople.sourceIDsExclusive(commander),
      let body = bodies.first(where: { $0.missionActorID == unit.actor }), body.energy > 0,
      let actor = c01ClinicStockActor(body, ordinal: unit.ordinal), actor.presence == .present,
      let physical = actor.body.physical, physical.deathIncidentID == nil,
      physical.deathOrigin == nil,
      let cradleBody = bodies.first(where: {
        $0.missionActorID == source.registration.facility
      }), cradleBody.energy > 0,
      cradleBody.position.length <= NativeC01ClinicEscort.stayNearMetres,
      let cradle = c01ClinicCradleActor(cradleBody), cradle.presence == .present,
      let cradlePhysical = cradle.body.physical,
      cradlePhysical.deathIncidentID == nil, cradlePhysical.deathOrigin == nil
    else { return nil }
    let consent = NativeC01ClinicPilotConsent(pilot: unit.pilot,
      registeredHull: unit.registeredHull, sourceRevision: source.revision,
      reservation: NativeC01ClinicPeople.reservationOperation(
        registration: source.registration, unit: unit),
      destination: actualSource.station, actor: physical.identity, cradle: cradlePhysical.identity,
      berth: modelPose(of: body), reference: context.reference,
      velocity: physical.velocity, angularVelocity: physical.angularVelocity,
      cradlePose: modelPose(of: cradleBody), cradleVelocity: cradlePhysical.velocity,
      cradleAngularVelocity: cradlePhysical.angularVelocity,
      physicalTime: context.flight.physicalTime, epoch: context.epoch)
    return .init(context: context, custody: custody, mission: mission, unit: unit,
      actor: actor, consent: consent)
  }

  func validateC01ClinicPeopleQuote(_ quote: NativeC01ClinicPeopleQuote) throws
    -> NativeC01ClinicPeopleIntent
  {
    guard let current = c01ClinicPeopleQuote(), current.context == quote.context,
      current.custody == quote.custody, current.mission == quote.mission,
      current.unit == quote.unit, current.actor == quote.actor, current.consent == quote.consent,
      let source = quote.custody.clinicSource
    else { throw SaveError.invalidCommander }
    let consent = quote.consent
    let operation = try NativeC01ClinicEscort.launchOperation(
      source: source.registration.source, reservation: consent.reservation,
      hull: quote.unit.registeredHull, pilot: .clinicPilot(quote.unit.pilot),
      ordinal: quote.unit.ordinal, berth: consent.berth, reference: consent.reference)
    let launch = NativeC01ClinicLaunch(operation: operation, sourceReceipt: consent.reservation,
      registeredHull: quote.unit.registeredHull, pilot: .clinicPilot(quote.unit.pilot),
      ordinal: quote.unit.ordinal, nativeActor: consent.actor, berth: consent.berth,
      reference: consent.reference, physicalTime: consent.physicalTime)
    return .init(quote: quote, launch: launch)
  }

  func prepareC01ClinicPeopleAssignment(_ intent: NativeC01ClinicPeopleIntent) throws
    -> NativeC01ClinicPeopleAssignmentPlan
  {
    let quote = intent.quote
    guard NativeC01ClinicPeopleContext(self) == quote.context,
      commander.nativePeople == quote.custody, let current = glassMeridianMission,
      var expectedOpening = quote.mission.savedGlassMeridian,
      var expectedState = expectedOpening.clinicEscort,
      var source = quote.custody.clinicSource,
      source.assignment(quote.unit.ordinal) == nil, source.disposition(quote.unit.ordinal) == nil,
      quote.mission.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    var expected = quote.mission
    expectedState.launches.append(intent.launch)
    expectedOpening.clinicEscort = expectedState
    expected.savedGlassMeridian = expectedOpening
    expected.revision += 1
    expected.journal.append("Clinic pilot accepted the local escort leg in the same registered Harrier. No fee or replacement hull.")
    guard current == expected else { throw SaveError.invalidCommander }
    let assignment = NativeC01ClinicPeopleAssignment(operation: quote.consent.reservation,
      revision: source.revision + 1, launch: intent.launch, actor: quote.actor.identity,
      physical: quote.consent.actor, consent: quote.consent,
      observer: .init(system: source.registration.source.station.system,
        visit: quote.context.flight.visit, entity: 0),
      carrier: quote.context.carrier, inventoryRevision: quote.context.inventoryRevision,
      beforeCash: quote.context.credits, afterCash: quote.context.credits)
    source.assignments.append(assignment)
    guard NativeC01ClinicPeopleSave.shapeValid(source) else { throw SaveError.invalidCommander }
    var custody = quote.custody
    custody.clinicSource = source
    return .init(context: quote.context, beforeCustody: quote.custody,
      custody: custody, mission: current)
  }

  mutating func commitC01ClinicPeopleAssignment(_ capsule: NativeC01ClinicPeopleAssignmentPlan) throws {
    guard NativeC01ClinicPeopleContext(self) == capsule.context,
      commander.nativePeople == capsule.beforeCustody,
      commander.scriptState.instances[capsule.mission.id] == capsule.mission
    else { throw SaveError.invalidCommander }
    // Release only records consent/control. The existing body's every physical field and
    // both native allocators remain byte-for-byte unchanged until subsequent real physics.
    commander.savedNativePeopleCustody = capsule.custody
    commander.scriptState.instances[capsule.mission.id] = capsule.mission
  }
}


extension Game {
  func c01ClinicPilotLossWitness(_ transition: NativeC01ClinicFatalTransition)
    -> NativeC01ClinicPilotLossWitness?
  {
    guard transition.epoch == nativeStationRuntimeEpoch,
      transition.physicalTime <= commander.flightSimulation.physicalTime,
      transition.postNextIncident <= commander.flightSimulation.nextIncident,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      let source = commander.nativePeople?.clinicSource,
      NativeC01ClinicPeopleSave.shapeValid(source), source.owner == commander.equipmentOwnerID,
      mission.id == source.registration.source.mission,
      mission.definition == NativeGlassMeridian.stateID, mission.digest == NativeGlassMeridian.digest,
      mission.version == NativeGlassMeridian.version,
      mission.savedGlassMeridian?.permission.operation == source.registration.source.permission,
      mission.savedGlassMeridian?.permission.owner == source.owner,
      mission.savedGlassMeridian?.laneRepair?.installation?.operation
        == source.registration.source.installation,
      mission.savedGlassMeridian?.surveyor?.capture?.operation == source.registration.source.recorder,
      state.source == transition.source, state.birth == transition.birth,
      source.registration.source == transition.source,
      source.registration.birth == transition.birth,
      source.disposition(transition.ordinal) == nil, state.loss(for: transition.ordinal) == nil,
      let unit = source.unit(transition.ordinal),
      unit.actor == transition.actor.identity,
      let held = mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter]?
        .actors[NativeC01ClinicEscort.stockTarget(transition.ordinal)], held == transition.actor,
      held.presence == .destroyed, held.body.energy == 0,
      NativeC01ClinicEscort.original(held, source: state.source, ordinal: unit.ordinal),
      let physical = held.body.physical,
      NativeC01ClinicEscort.nativeValid(physical, cradle: false),
      physical.identity.visit == commander.flightSimulation.visit,
      let incident = physical.deathIncidentID, incident >= transition.preNextIncident,
      incident < transition.postNextIncident,
      transition.startTime >= source.registration.physicalTime,
      transition.physicalTime > transition.startTime,
      transition.physicalTime - transition.startTime <= NativeC01LaneRepair.maximumPhysicalInterval,
      state.launch(for: unit.ordinal) == transition.launch
    else { return nil }
    let assignment = source.assignment(unit.ordinal)
    if let launch = transition.launch {
      guard assignment?.launch == launch, launch.loss == nil,
        launch.registeredHull == unit.registeredHull, launch.pilot == .clinicPilot(unit.pilot)
      else { return nil }
    } else if assignment != nil { return nil }
    return .init(transition: transition, registration: source.registration, assignment: assignment)
  }

  func prepareC01ClinicPilotLoss(_ witness: NativeC01ClinicPilotLossWitness) throws
    -> NativeC01ClinicPeopleDispositionPlan
  {
    // Rewrap the real private observation against the current target. A disposition of
    // the other unit on this same tick neither invalidates this target nor refills stock.
    guard let current = c01ClinicPilotLossWitness(witness.transition),
      current.registration == witness.registration, current.assignment == witness.assignment,
      let physical = witness.actor.body.physical, let incident = physical.deathIncidentID
    else { throw SaveError.invalidCommander }
    let casualty = NativeC01ClinicPilotCasualty(actor: witness.actor.identity,
      physical: physical.identity, incident: incident, origin: physical.deathOrigin,
      startTime: witness.transition.startTime, physicalTime: witness.physicalTime,
      epoch: witness.transition.epoch)
    return try prepareC01ClinicPeopleDisposition(ordinal: witness.transition.ordinal,
      actor: witness.actor, kind: .casualty(casualty))
  }

  func prepareC01ClinicPilotReception(_ witness: NativeC01ClinicArrivalWitness) throws
    -> NativeC01ClinicPeopleDispositionPlan
  {
    guard witness.epoch == nativeStationRuntimeEpoch,
      witness.physicalTime == commander.flightSimulation.physicalTime,
      witness.startTime.isFinite, witness.physicalTime > witness.startTime,
      witness.physicalTime - witness.startTime <= NativeC01LaneRepair.maximumPhysicalInterval,
      let actualSource = c01ClinicSourceContext(), actualSource == witness.source,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      state.source == witness.source, state.current == witness.launch,
      state.arrival == nil, witness.launch.loss == nil,
      let source = commander.nativePeople?.clinicSource,
      NativeC01ClinicPeopleSave.sourceClaimsMatch(state, mission: mission, commander: commander),
      let unit = source.unit(witness.launch.ordinal),
      source.disposition(unit.ordinal) == nil,
      source.assignment(unit.ordinal)?.launch == witness.launch,
      witness.launch.registeredHull == unit.registeredHull,
      witness.launch.pilot == .clinicPilot(unit.pilot),
      let actual = c01ClinicTenderActor(launch: witness.launch), actual == witness.actor,
      actual.identity == unit.actor, actual.presence == .present, actual.body.energy > 0,
      let physical = actual.body.physical, physical.deathIncidentID == nil,
      physical.deathOrigin == nil,
      case .living(let destination) = nativeOriginalMainStationDestination,
      destination.identity == witness.source.station,
      witness.stationActor.system == destination.identity.system,
      witness.stationActor.visit == physical.identity.visit, witness.stationActor.entity == 1,
      bodies.contains(where: {
        $0.id == 0 && $0.hull == .station && $0.energy > 0
          && $0.physical?.identity == witness.stationActor
      })
    else { throw SaveError.invalidCommander }
    let reception = NativeC01ClinicPilotReception(actor: actual.identity,
      physical: physical.identity, station: destination.identity, stationActor: witness.stationActor,
      startTime: witness.startTime, physicalTime: witness.physicalTime, epoch: witness.epoch)
    return try prepareC01ClinicPeopleDisposition(ordinal: unit.ordinal,
      actor: actual, kind: .reception(reception))
  }

  private func prepareC01ClinicPeopleDisposition(ordinal: Int, actor: ScriptOwnedActor,
    kind: NativeC01ClinicDispositionKind) throws -> NativeC01ClinicPeopleDispositionPlan
  {
    guard let context = NativeC01ClinicPeopleContext(self),
      let before = commander.nativePeople, var source = before.clinicSource,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.clinicEscort,
      source.owner == context.owner, source.registration.source == state.source,
      source.registration.birth == state.birth, let unit = source.unit(ordinal),
      source.disposition(ordinal) == nil, source.dispositions.count < 2,
      unit.actor == actor.identity
    else { throw SaveError.invalidCommander }
    let assignment = source.assignment(ordinal)?.operation
    let operation = try NativeC01ClinicPeople.dispositionOperation(
      registration: source.registration, unit: unit, assignment: assignment, kind: kind)
    source.dispositions.append(.init(operation: operation, revision: source.revision + 1,
      ordinal: ordinal, registeredHull: unit.registeredHull, pilot: unit.pilot,
      assignment: assignment, kind: kind))
    guard NativeC01ClinicPeopleSave.shapeValid(source) else { throw SaveError.invalidCommander }
    var custody = before
    custody.clinicSource = source
    return .init(operation: operation, context: context, beforeCustody: before,
      custody: custody, mission: mission, state: state, actor: actor, ordinal: ordinal, kind: kind)
  }

  mutating func commitC01ClinicPeopleDisposition(_ capsule: NativeC01ClinicPeopleDispositionPlan) throws {
    guard NativeC01ClinicPeopleContext(self) == capsule.context,
      commander.nativePeople == capsule.beforeCustody,
      commander.scriptState.instances[capsule.mission.id] == capsule.mission,
      capsule.mission.savedGlassMeridian?.clinicEscort == capsule.state
    else { throw SaveError.invalidCommander }
    // G3 has already prepared all reciprocal mission/event/consumed-body edits. Its
    // same candidate publisher installs those values immediately after this assignment.
    commander.savedNativePeopleCustody = capsule.custody
  }
}
