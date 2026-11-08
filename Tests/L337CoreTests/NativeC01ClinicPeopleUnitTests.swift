import Foundation
import Testing

@testable import L337Core

/// Controlled records test the local codec/state machine only. They cannot construct any
/// private source intent, native admission, consent quote, fatality or arrival witness.
private enum ClinicPeopleCodecFixture {
  static func source(reference: ShipPose = .init()) throws -> NativeC01ClinicSourceState {
    let owner = UUID()
    var flight = FlightSimulationState()
    flight.enter(NativeC01ClinicEscort.location, arriving: true)
    let anchors = try #require(flight.anchors)
    let mission = ScriptIdentity.uuid("glass-meridian-commission-v1:\(owner)")
    let source = NativeC01ClinicEscortSource(mission: mission, permission: UUID(), owner: owner,
      installation: UUID(), recorder: UUID(),
      station: .init(world: owner, system: NativeC01ClinicEscort.location, resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:91")),
      anchors: anchors, reference: reference, visit: flight.visit, physicalTime: 0)
    let frame = ShipPose(position: source.position)
    let units = (0..<2).map { ordinal in
      NativeC01ClinicRegisteredUnit(ordinal: ordinal,
        registeredHull: NativeC01ClinicPeople.hull(owner: owner, ordinal: ordinal),
        pilot: NativeC01ClinicPeople.person(owner: owner, ordinal: ordinal),
        pilotName: NativeC01ClinicPeople.definitions[ordinal].name, adult: true,
        consentPolicy: NativeC01ClinicPeople.consentPolicy, intrinsicPlace: 0,
        mass: .init(dryHullKilograms: 25545, pilotKilograms: 80, fuelKilograms: 0,
          cargoKilograms: 0, roleKitKilograms: 0, ammunitionKilograms: 0, otherPeopleKilograms: 0),
        actor: NativeC01ClinicEscort.actor(mission: mission, ordinal: ordinal),
        birthPhysical: .init(system: source.station.system, visit: flight.visit,
          entity: UInt64(ordinal + 3)),
        berth: NativeC01ClinicEscort.parkedPose(cradle: frame, ordinal: ordinal))
    }
    let operation = NativeC01ClinicPeople.registrationOperation(owner: owner)
    let birth = NativeC01ClinicStockBirth(registration: operation,
      units: units.map { .init(ordinal: $0.ordinal, registeredHull: $0.registeredHull,
        pilot: .clinicPilot($0.pilot)) }, cradle: frame, reference: source.reference, physicalTime: 0)
    return .init(registration: .init(operation: operation, source: source, birth: birth,
      facility: NativeC01ClinicPeople.facility(owner: owner),
      cradle: .init(system: source.station.system, visit: flight.visit, entity: 2),
      cradlePose: frame, cradleVelocity: .init(0, 0, 0), cradleAngularVelocity: .init(0, 0, 0),
      resourceSHA256: NativeC01ClinicCradle.resourceSHA256,
      recipeSHA256: NativeC01ClinicCradle.recipeSHA256, units: units, physicalTime: 0, epoch: UUID()))
  }

  static func assignment(_ source: NativeC01ClinicSourceState, ordinal: Int,
    time: Double) throws -> NativeC01ClinicPeopleAssignment
  {
    let registration = source.registration
    let unit = try #require(source.unit(ordinal))
    let reservation = NativeC01ClinicPeople.reservationOperation(registration: registration, unit: unit)
    let operation = try NativeC01ClinicEscort.launchOperation(source: registration.source,
      reservation: reservation, hull: unit.registeredHull, pilot: .clinicPilot(unit.pilot),
      ordinal: ordinal, berth: unit.berth, reference: registration.source.reference)
    let launch = NativeC01ClinicLaunch(operation: operation, sourceReceipt: reservation,
      registeredHull: unit.registeredHull, pilot: .clinicPilot(unit.pilot), ordinal: ordinal,
      nativeActor: unit.birthPhysical, berth: unit.berth,
      reference: registration.source.reference, physicalTime: time)
    let consent = NativeC01ClinicPilotConsent(pilot: unit.pilot, registeredHull: unit.registeredHull,
      sourceRevision: source.revision, reservation: reservation,
      destination: registration.source.station, actor: unit.birthPhysical, cradle: registration.cradle,
      berth: unit.berth, reference: registration.source.reference,
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), cradlePose: registration.cradlePose,
      cradleVelocity: .init(0, 0, 0), cradleAngularVelocity: .init(0, 0, 0), physicalTime: time,
      epoch: registration.epoch)
    return .init(operation: reservation, revision: source.revision + 1, launch: launch,
      actor: unit.actor, physical: unit.birthPhysical, consent: consent,
      observer: .init(system: unit.birthPhysical.system, visit: unit.birthPhysical.visit, entity: 0),
      carrier: UUID(), inventoryRevision: 0, beforeCash: 1000, afterCash: 1000)
  }

  static func loss(_ source: NativeC01ClinicSourceState, ordinal: Int,
    time: Double) throws -> NativeC01ClinicPeopleDisposition
  {
    let unit = try #require(source.unit(ordinal))
    let assignment = source.assignment(ordinal)?.operation
    let casualty = NativeC01ClinicPilotCasualty(actor: unit.actor, physical: unit.birthPhysical,
      incident: UInt64(ordinal + 1), origin: nil, startTime: time - 0.05,
      physicalTime: time, epoch: source.registration.epoch)
    let kind = NativeC01ClinicDispositionKind.casualty(casualty)
    let operation = try NativeC01ClinicPeople.dispositionOperation(
      registration: source.registration, unit: unit, assignment: assignment, kind: kind)
    return .init(operation: operation, revision: source.revision + 1, ordinal: ordinal,
      registeredHull: unit.registeredHull, pilot: unit.pilot, assignment: assignment, kind: kind)
  }
}

struct NativeC01ClinicPeopleUnitTests {
  @Test func twoOriginalPilotsAreDistinctFromOwnerAndAvenorExchange() throws {
    let source = try ClinicPeopleCodecFixture.source()
    #expect(NativeC01ClinicPeopleSave.shapeValid(source))
    #expect(source.registration.units.map(\.pilotName) == ["Iria Neth", "Daven Roh"])
    let people = source.registration.units.map(\.pilot)
    #expect(Set(people.map(\.id)).count == 2)
    #expect(people.allSatisfy { $0.valid && $0.id != source.owner })
    #expect(source.registration.units.allSatisfy {
      $0.adult && $0.intrinsicPlace == 0 && $0.mass.valid && $0.mass.loadedKilograms == 25625
    })
    #expect(NativeC01ClinicPeople.person(owner: source.owner, ordinal: 2).valid == false)
    #expect(NativePersonReference.clinicPilot(people[0]).station == nil)
    #expect(NativePersonReference.clinicPilot(people[0]).emp == nil)
  }

  @Test func birthUsesWorldIdentityWhileStationReferenceMayBeRotated() throws {
    var rotated = Basis3()
    rotated.rotate(pitch: 0.1, roll: 0.3, yaw: 0.2)
    let reference = ShipPose(position: .init(20, 30, 40), orientation: rotated)
    let source = try ClinicPeopleCodecFixture.source(reference: reference)
    #expect(NativeC01ClinicPeopleSave.shapeValid(source))
    #expect(source.registration.birth.cradle.orientation == Basis3())
    #expect(source.registration.birth.reference == reference)
    let bytes = try JSONEncoder().encode(source)
    #expect(try NativeC01ClinicPeopleSave.decodeClosed(bytes) == source)
    var raw = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var registration = try #require(raw["registration"] as? [String: Any])
    var birth = try #require(registration["birth"] as? [String: Any])
    var cradle = try #require(birth["cradle"] as? [String: Any])
    cradle["orientation"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rotated))
    birth["cradle"] = cradle
    registration["birth"] = birth
    registration["cradlePose"] = cradle
    raw["registration"] = registration
    #expect(throws: (any Error).self) {
      try NativeC01ClinicPeopleSave.decodeClosed(JSONSerialization.data(withJSONObject: raw))
    }
  }

  @Test func currentLocalCodecAndCOWRetainBothStoredPilots() throws {
    let source = try ClinicPeopleCodecFixture.source()
    let bytes = try JSONEncoder().encode(source)
    #expect(try NativeC01ClinicPeopleSave.decodeClosed(bytes) == source)
    var original = NativePeopleCustodyState(owner: source.owner)
    original.clinicSource = source
    var changed = original
    let loss = try ClinicPeopleCodecFixture.loss(source, ordinal: 0, time: 1)
    changed.clinicSource?.dispositions.append(loss)
    #expect(original.clinicSource == source)
    #expect(changed.clinicSource?.dispositions == [loss])
    let roundtrip = try JSONDecoder().decode(NativePeopleCustodyState.self,
      from: JSONEncoder().encode(changed))
    #expect(roundtrip == changed && roundtrip != original)
    var commander = Commander()
    commander.savedNativePeopleCustody = original
    for ordinal in 0..<2 {
      let facts = try #require(commander.c01ClinicStockPilotFacts(ordinal: ordinal))
      #expect(facts.location == .aboardStored && facts.alive == true && !facts.operating)
      #expect(facts.massKilograms == 80 && facts.loadedMassKilograms == 25625)
    }
    #expect(commander.c01ClinicStockPilotFacts(ordinal: 2) == nil)
  }

  @Test func parkedFirstLossAllowsReserveAsFirstLegWithoutRefillOrFakeLaunch() throws {
    var source = try ClinicPeopleCodecFixture.source()
    let firstLoss = try ClinicPeopleCodecFixture.loss(source, ordinal: 0, time: 1)
    source.dispositions.append(firstLoss)
    #expect(firstLoss.assignment == nil && source.assignments.isEmpty)
    #expect(NativeC01ClinicPeopleSave.shapeValid(source))
    let assignment = try ClinicPeopleCodecFixture.assignment(source, ordinal: 1, time: 2)
    source.assignments.append(assignment)
    #expect(source.assignments[0].launch.ordinal == 1)
    #expect(NativeC01ClinicPeopleSave.shapeValid(source))
    let lastLoss = try ClinicPeopleCodecFixture.loss(source, ordinal: 1, time: 3)
    source.dispositions.append(lastLoss)
    #expect(lastLoss.assignment == assignment.operation)
    #expect(try NativeC01ClinicPeopleSave.decodeClosed(JSONEncoder().encode(source)) == source)
    var commander = Commander()
    var custody = NativePeopleCustodyState(owner: source.owner)
    custody.clinicSource = source
    commander.savedNativePeopleCustody = custody
    #expect(commander.c01ClinicStockPilotFacts(ordinal: 0)?.alive == nil)
    #expect(commander.c01ClinicPilotFacts(for: assignment.launch)?.alive == nil)
    var duplicate = source
    duplicate.dispositions.append(lastLoss)
    #expect(!NativeC01ClinicPeopleSave.shapeValid(duplicate))
    let refill = try ClinicPeopleCodecFixture.assignment(source, ordinal: 0, time: 4)
    source.assignments.append(refill)
    #expect(!NativeC01ClinicPeopleSave.shapeValid(source))
  }

  @Test func localHistoryRejectsReserveSkippingAndParallelOperatingPilots() throws {
    var skipped = try ClinicPeopleCodecFixture.source()
    let reserveFirst = try ClinicPeopleCodecFixture.assignment(skipped, ordinal: 1, time: 1)
    skipped.assignments.append(reserveFirst)
    #expect(!NativeC01ClinicPeopleSave.shapeValid(skipped))
    var parallel = try ClinicPeopleCodecFixture.source()
    let front = try ClinicPeopleCodecFixture.assignment(parallel, ordinal: 0, time: 1)
    parallel.assignments.append(front)
    #expect(NativeC01ClinicPeopleSave.shapeValid(parallel))
    let reserve = try ClinicPeopleCodecFixture.assignment(parallel, ordinal: 1, time: 2)
    parallel.assignments.append(reserve)
    #expect(!NativeC01ClinicPeopleSave.shapeValid(parallel))
  }

  @Test func localDecoderRejectsUnknownFieldsOversizedNestedStockAndThirdReceipt() throws {
    let source = try ClinicPeopleCodecFixture.source()
    let bytes = try JSONEncoder().encode(source)
    let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var unknown = original
    unknown["refill"] = true
    #expect(throws: (any Error).self) {
      try NativeC01ClinicPeopleSave.decodeClosed(JSONSerialization.data(withJSONObject: unknown))
    }
    var registration = try #require(original["registration"] as? [String: Any])
    var birth = try #require(registration["birth"] as? [String: Any])
    let stock = try #require(birth["units"] as? [Any])
    birth["units"] = stock + [stock[0]]
    registration["birth"] = birth
    var oversized = original
    oversized["registration"] = registration
    let oversizedBytes = try JSONSerialization.data(withJSONObject: oversized)
    #expect(throws: (any Error).self) { try NativeC01ClinicPeopleSave.decodeClosed(oversizedBytes) }
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeC01ClinicSourceState.self, from: oversizedBytes)
    }
    let loss = try ClinicPeopleCodecFixture.loss(source, ordinal: 0, time: 1)
    let rawLoss = try JSONSerialization.jsonObject(with: JSONEncoder().encode(loss))
    var third = original
    third["dispositions"] = [rawLoss, rawLoss, rawLoss]
    #expect(throws: (any Error).self) {
      try NativeC01ClinicPeopleSave.decodeClosed(JSONSerialization.data(withJSONObject: third))
    }
    #expect(throws: (any Error).self) { try NativeC01ClinicPeopleSave.decodeClosed(Data()) }
  }

  @Test func currentRawCodecRejectsNamesMassPlaceAndSourceAliases() throws {
    let bytes = try JSONEncoder().encode(ClinicPeopleCodecFixture.source())
    let original = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    let registration = try #require(original["registration"] as? [String: Any])
    let units = try #require(registration["units"] as? [[String: Any]])
    for (key, value) in [("pilotName", "Sorel" as Any), ("intrinsicPlace", 1 as Any),
                         ("adult", false as Any), ("consentPolicy", "free-crew" as Any)] {
      var changedUnits = units
      changedUnits[0][key] = value
      var changedRegistration = registration
      changedRegistration["units"] = changedUnits
      var changed = original
      changed["registration"] = changedRegistration
      #expect(throws: (any Error).self) {
        try NativeC01ClinicPeopleSave.decodeClosed(JSONSerialization.data(withJSONObject: changed))
      }
    }
    var changedUnits = units
    var mass = try #require(units[0]["mass"] as? [String: Any])
    mass["fuelKilograms"] = 1
    changedUnits[0]["mass"] = mass
    var changedRegistration = registration
    changedRegistration["units"] = changedUnits
    var changed = original
    changed["registration"] = changedRegistration
    #expect(throws: (any Error).self) {
      try NativeC01ClinicPeopleSave.decodeClosed(JSONSerialization.data(withJSONObject: changed))
    }
    let alias = try JSONSerialization.data(withJSONObject: ["clinicSource": original])
    #expect(throws: (any Error).self) {
      try NativeC01ClinicPeopleSave.validateFields(alias, part: .commander)
    }
  }
}


/// Shares maintained actual relay work and native source birth with the physical journey
/// tests. Only player placement is controlled; no clinic source/people/receipt is seeded.
final class C01ClinicPeopleJourneyFixture {
  let lane: C01LaneRepairJourneyFixture
  var save: URL { lane.save }
  init() async throws { lane = try await C01LaneRepairJourneyFixture() }
  func clean() { lane.clean() }

  func sourceGame() async throws -> Game {
    var game = try await lane.atRelays()
    for target in NativeC01LaneRepair.Target.allCases {
      let working = try await lane.runtime(at: target, game: game)
      await lane.work(working)
      game = await working.snapshot()
    }
    try #require(game.glassMeridianMission?.savedGlassMeridian?.laneRepair?.installation != nil)
    // The final relay is outside the admission bubble. Move only the player into
    // range, then let the existing durable runtime publish the actual native cohort.
    let context = try #require(game.c01ClinicSourceContext())
    NativeStationTestFixture.reframe(&game,
      to: .init(position: context.position + .init(0, 0, 300)))
    game.speed = 0
    game.screen = .front
    game.autoPilot.disengage()
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    _ = await runtime.advance(delta: 0.05)
    game = await runtime.snapshot()
    try #require(game.commander.nativePeople?.clinicSource != nil)
    return game
  }

  func parkAtCradle(_ game: inout Game) throws {
    let source = try #require(game.commander.nativePeople?.clinicSource)
    let frame = try #require(game.bodies.first { $0.missionActorID == source.registration.facility })
    let pose = game.modelPose(of: frame)
    NativeStationTestFixture.reframe(&game,
      to: .init(position: pose.systemPoint(.init(0, 0, 300)), orientation: pose.orientation))
    game.speed = 0
    game.screen = .front
    game.autoPilot.disengage()
    game.weaponsTargetID = frame.id
  }
}

extension NativeC01ClinicPeopleUnitTests {
  @Test func actualThreeActorBirthCancelStaleOfferPublicationRefusalReleaseAndCurrentLoad() async throws {
    let f = try await C01ClinicPeopleJourneyFixture()
    defer { f.clean() }
    var game = try await f.sourceGame()
    let mission = try #require(game.glassMeridianMission)
    let state = try #require(mission.savedGlassMeridian?.clinicEscort)
    let source = try #require(game.commander.nativePeople?.clinicSource)
    let group = try #require(mission.ownedEncounters[NativeC01ClinicEscort.sourceEncounter])
    #expect(group.admitted && group.actors.count == 3)
    #expect(source.registration.birth == state.birth && source.assignments.isEmpty)
    #expect(source.registration.units.count == 2 && source.dispositions.isEmpty)
    #expect(NativeC01ClinicPeopleSave.sourceClaimsMatch(state, mission: mission, commander: game.commander))
    #expect(game.commander.valid)
    let frameID = source.registration.facility
    let frame = try #require(game.bodies.first { $0.missionActorID == frameID })
    let cradleCollision = try #require(game.c01ClinicCradleCollision(frame))
    #expect(cradleCollision.mass == 315120 && cradleCollision.mesh.faces.count == 144)
    for ordinal in 0..<2 {
      let unit = try #require(source.unit(ordinal))
      let body = try #require(game.bodies.first { $0.missionActorID == unit.actor })
      let collision = try #require(game.c01ClinicStockCollision(body))
      #expect(collision.mass == 25625 && collision.mesh.faces.count == 512)
      #expect(body.physical?.identity == unit.birthPhysical)
      #expect(game.commander.c01ClinicStockPilotFacts(ordinal: ordinal)?.location == .aboardStored)
    }
    // Controlled player placement near the actual cradle enables the real input offer.
    try f.parkAtCradle(&game)
    let quote = try #require(game.c01ClinicPeopleQuote())
    #expect(quote.pilotName == "Iria Neth")
    let custody = game.commander.nativePeople
    let bodies = game.bodies
    let flight = game.commander.flightSimulation
    let cash = game.commander.credits
    let bodyCounter = game.nextBodyID
    // A changed actual body invalidates the WHOLE quote; no new healthy body is substituted.
    var stale = game
    let front = try #require(stale.bodies.firstIndex {
      $0.missionActorID == source.unit(0)?.actor
    })
    stale.bodies[front].energy -= 1
    #expect(throws: (any Error).self) { try stale.validateC01ClinicPeopleQuote(quote) }
    #expect(stale.commander.nativePeople == custody)
    let runtime = GameRuntime(game: game, saveURL: f.save)
    try await runtime.save(to: f.save)
    await runtime.key("return")
    try #require(await runtime.snapshot().c01ClinicEscortRuntime.review != nil)
    await runtime.key("escape")
    let cancelled = await runtime.snapshot()
    #expect(cancelled.commander.nativePeople == custody && cancelled.bodies == bodies)
    #expect(cancelled.commander.credits == cash && cancelled.nextBodyID == bodyCounter)
    #expect(cancelled.commander.flightSimulation == flight)
    // Refuse confirmation with an unavailable durable destination, preserving the finite source.
    await runtime.key("return")
    let pointer = try Data(contentsOf: f.save)
    try FileManager.default.removeItem(at: f.save)
    try FileManager.default.createDirectory(at: f.save, withIntermediateDirectories: false)
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander.nativePeople == custody && refused.bodies == bodies)
    #expect(refused.glassMeridianMission?.savedGlassMeridian?.clinicEscort?.launches.isEmpty == true)
    #expect(refused.commander.credits == cash && refused.commander.flightSimulation == flight)
    try FileManager.default.removeItem(at: f.save)
    try pointer.write(to: f.save, options: .atomic)
    await runtime.key("escape")
    await runtime.key("return")
    try #require(await runtime.snapshot().c01ClinicEscortRuntime.review != nil)
    await runtime.key("return")
    let released = await runtime.snapshot()
    let after = try #require(released.commander.nativePeople?.clinicSource)
    let assignment = try #require(after.assignments.first)
    #expect(after.registration == source.registration && after.assignments.count == 1)
    #expect(after.dispositions.isEmpty && assignment.launch.ordinal == 0)
    #expect(released.bodies == bodies && released.commander.flightSimulation == flight)
    #expect(released.nextBodyID == bodyCounter && released.commander.credits == cash)
    #expect(released.commander.c01ClinicPilotFacts(for: assignment.launch)?.operating == true)
    #expect(released.commander.c01ClinicStockPilotFacts(ordinal: 1)?.location == .aboardStored)
    #expect(released.c01ClinicPeopleQuote() == nil)
    #expect(released.commander.valid)
    try await runtime.save(to: f.save)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: f.save)
    let loaded = await cold.snapshot()
    #expect(loaded.commander.nativePeople?.clinicSource == after)
    #expect(loaded.c01ClinicEscortRuntime.review == nil)
    #expect(loaded.commander.c01ClinicStockPilotFacts(ordinal: 1)?.location == .aboardStored)
    #expect(loaded.commander.c01ClinicPilotFacts(for: assignment.launch)?.operating == true)
    #expect(loaded.commander.credits == cash && loaded.commander.valid)
    let stockIDs = Set([frameID] + source.registration.units.map(\.actor))
    #expect(loaded.bodies.filter { body in
      guard body.missionInstanceID == mission.id, let id = body.missionActorID else { return false }
      return stockIDs.contains(id)
    }.count == 3)
  }
}
