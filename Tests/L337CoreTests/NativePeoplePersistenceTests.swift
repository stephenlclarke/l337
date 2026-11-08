import Foundation
import Testing

@testable import L337Core

struct NativePeoplePersistenceTests {
  @Test func laterScheduleHookPreservesCurrentEpisodeAndRefusesMissingPrior() throws {
    var game = try NativePeopleTestFixture.withinWindow()
    let source = try NativePeopleTestFixture.source(game)
    var record = try #require(game.commander.savedEMPState?.records[source])
    let first = record.disableIncident
    let time = first.physicalTime + 31
    try game.commander.removeFittedEquipment(Equipment.empPirateBlaster)
    try game.commander.grantEquipment(
      Equipment.empPirateBlaster, at: .utility(.empPirateBlaster),
      provenance: .grant("Later actual fitted EMP replacement"))
    let replacement = try #require(game.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    try #require(replacement.id != record.weapon.id)
    // This is a data-hook boundary fixture, not evidence of actual electrical recovery.
    func laterIncident(emission: UInt64, part: String?, position: Vector3, station: Bool = false)
      -> CombatIncident
    {
      let origin = AttackOrigin(
        emissionID: emission, owner: first.origin.owner,
        emittedAt: time, ownerLegalAtEmission: first.origin.ownerLegalAtEmission, sourcePart: part)
      return CombatIncident(
        id: first.id + 1, physicalTime: time, origin: origin,
        victim: record.hull.body.physical?.identity, kind: .emp, outcome: .hit,
        position: position, victimLegalBeforeAttack: first.victimLegalBeforeAttack,
        firstAggressor: first.firstAggressor, victimRole: first.victimRole, victimIsStation: station
      )
    }
    let part = "emp:" + replacement.id.uuidString
    let later = laterIncident(
      emission: first.origin.emissionID + 1, part: part, position: first.position)
    let schedule = record.aboardOrdinals.map { EMPCrewEjection(ordinal: $0, delay: 45) }
    let currentCargo = try #require(record.hull.body.physical?.npc?.ordinaryCargo)
    let currentLegal = try #require(record.hull.body.physical?.npc?.legal)
    let prior = record
    let appended = record.appendCrewDisableEpisode(
      incident: later, weapon: replacement, owner: prior.weaponOwner, ejections: schedule)
    try #require(appended)
    // The timing hook does not own the later disable's cargo/legal custody facts.
    record.savedCurrentCargo = currentCargo
    record.savedCurrentLegal = currentLegal
    #expect(record.disableIncident == first && record.disableEpisodes.count == 2)
    #expect(record.disableEpisodes[0] == prior.disableEpisodes[0])
    #expect(record.currentCrewDisableIncident == later && record.crewDeadline == time + 30)
    #expect(record.crewCensusValid)
    // This hook cannot issue a later electrical disable or update its stored hull.
    #expect(!record.valid)
    var missingPrior = prior
    missingPrior.savedDisableEpisodes = nil
    let missingBefore = missingPrior
    let missingAccepted = missingPrior.appendCrewDisableEpisode(
      incident: later, weapon: replacement, owner: prior.weaponOwner, ejections: schedule)
    #expect(!missingAccepted && missingPrior == missingBefore && !missingPrior.crewCensusValid)
    #expect(
      record.disableEpisodes[0].weapon == prior.weapon
        && record.disableEpisodes[1].weapon == replacement)
    var foreignOwner = prior
    let foreignAccepted = foreignOwner.appendCrewDisableEpisode(
      incident: later, weapon: replacement, owner: UUID(), ejections: schedule)
    #expect(!foreignAccepted)
    #expect(foreignOwner == prior)
    for bad in [
      laterIncident(emission: 0, part: part, position: first.position),
      laterIncident(
        emission: first.origin.emissionID + 1, part: "laser:not-emp", position: first.position),
      laterIncident(
        emission: first.origin.emissionID + 1, part: first.origin.sourcePart,
        position: first.position),
      laterIncident(
        emission: first.origin.emissionID + 1, part: part, position: .init(.infinity, 0, 0)),
      laterIncident(
        emission: first.origin.emissionID + 1, part: part, position: first.position, station: true),
    ] {
      var refused = prior
      let accepted = refused.appendCrewDisableEpisode(
        incident: bad, weapon: replacement, owner: prior.weaponOwner, ejections: schedule)
      #expect(!accepted)
      #expect(refused == prior)
      var forged = record
      let valid = record.disableEpisodes[1]
      forged.savedDisableEpisodes?[1] = .init(
        incident: bad, weapon: valid.weapon,
        weaponOwner: valid.weaponOwner, ejections: valid.ejections, actorBindings: valid.actorBindings)
      #expect(!forged.crewCensusValid && !forged.valid)
    }
    let original = record
    let repeated = record.appendCrewDisableEpisode(
      incident: later, weapon: replacement, owner: original.weaponOwner, ejections: schedule)
    #expect(!repeated)
    #expect(record == original)
  }

  @Test func currentRecordRequiresItsActualNonemptyScheduleWithoutRuntimeReconstruction() throws {
    let game = try NativePeopleTestFixture.disabled()
    let source = try NativePeopleTestFixture.source(game)
    let record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.valid && !record.disableEpisodes.isEmpty)
    let bytes = try JSONEncoder().encode(record)
    #expect(try JSONDecoder().decode(EMPHullRecord.self, from: bytes) == record)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    for condition in ["missing", "null", "empty"] {
      var malformed = object
      switch condition {
      case "missing": malformed.removeValue(forKey: "savedDisableEpisodes")
      case "null": malformed["savedDisableEpisodes"] = NSNull()
      default: malformed["savedDisableEpisodes"] = []
      }
      #expect(throws: SaveError.invalidCommander) {
        _ = try JSONDecoder().decode(EMPHullRecord.self,
          from: JSONSerialization.data(withJSONObject: malformed))
      }
    }
    var missing = game
    missing.commander.savedEMPState?.records[source]?.savedDisableEpisodes = nil
    let before = missing
    #expect(!missing.commander.valid)
    missing.advanceEMPActors()
    #expect(missing.commander == before.commander && missing.bodies == before.bodies)
    #expect(missing.commander.savedEMPState?.records[source]?.savedDisableEpisodes == nil)
  }

  @Test func actualPaidKernelRecoveryAndRedisableKeepOriginalCurrentEpisode() async throws {
    let paid = try await paidEMPNativeFixture()
    defer { paid.clean() }
    var game = await paid.runtime.snapshot()
    let current = try #require(StationPoliceSource.current())
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let id = game.nextBodyID
    game.nextBodyID += 1
    var npc = NPCState(role: .police, origin: game.systemIdentity, destination: game.systemIdentity)
    var worn = current.stock
    worn.frontShield = 0
    worn.rearShield = 0
    worn.fuel = 0
    let now = game.commander.flightSimulation.physicalTime
    var reserve = try #require(ElectricalReserve(
      capacity: worn.energyCapacity, recharge: worn.energyRecharge, at: now))
    let drained = reserve.drain(worn.energyCapacity - 1, at: now)
    try #require(drained)
    worn.electrical = reserve
    npc.resources = worn
    var body = SpaceBody(id: id, hull: .viper, position: .init(0, 0, 1000))
    body.energy = current.source.performance.energy - 3
    body.missiles = 0
    body.physical = .init(
      identity: actor, population: .police, npc: npc, blocksNavalEncounter: true,
      catalogueShipID: current.source.ship.id)
    game.bodies.append(body)
    _ = try await disableNativeEMPActor(actor, game: &game)
    let key = try #require(game.bodies.first { $0.physical?.identity == actor }?.physical?.empSource)
    let disabled = try #require(game.commander.nativeEMPCustodyRecord(for: key))
    try #require(disabled.valid && !disabled.isRecovered && disabled.crewAboard > 0)
    try #require(disabled.disableEpisodes.count == 1)
    let episode = try #require(disabled.disableEpisodes.first)
    let deadline = try #require(disabled.crewDeadline)
    // Controlled owner-clock boundary, not an executed native recovery journey.
    game.commander.flightSimulation.advancePhysicalTime(
      deadline + 1 - game.commander.flightSimulation.physicalTime)
    game.recoverEMPHulls()
    let recovered = try #require(game.commander.nativeEMPCustodyRecord(for: key))
    try #require(recovered.isRecovered && recovered.valid)
    #expect(recovered.disableEpisodes == disabled.disableEpisodes)
    #expect(recovered.crewAboard == disabled.crewAboard && recovered.crewTotal == disabled.crewTotal)
    _ = try await disableNativeEMPActor(actor, game: &game)
    let second = try #require(game.commander.nativeEMPCustodyRecord(for: key))
    try #require(second.valid && !second.isRecovered && second.disableEpisodes.count == 2)
    #expect(second.disableEpisodes[0] == episode && second.disableIncident == disabled.disableIncident)
    #expect(second.disableEpisodes[1].incident.id > episode.incident.id)
    #expect(second.disableEpisodes[1].incident.physicalTime >= episode.deadline)
    #expect(Set(second.disableEpisodes[1].ejections.map(\.ordinal)) == Set(recovered.aboardOrdinals))
    #expect(second.crewTotal == disabled.crewTotal && second.crewAboard == recovered.crewAboard)
    #expect(second.hull.body.physical?.npc?.resources?.fuel == 0)
  }

  @Test func realCullAndReadmissionBeforeDeadlineAllowsOriginalCrewCaptureOnNewActor() async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    let source = try NativePeopleTestFixture.source(game)
    let original = try #require(game.commander.savedEMPState?.records[source]?.hull.binding)
    game.bodies.removeAll { $0.physical?.identity == original }
    let persistEMPStateResult1 = game.persistEMPState()
    try #require(persistEMPStateResult1)
    game.advanceEMPActors()
    let rejoined = try #require(
      game.bodies.first { $0.physical?.empSource == source }?.physical?.identity)
    try #require(rejoined != original)
    #expect(
      game.commander.savedEMPState?.records[source]?.disableEpisodes.last?.actorBindings.contains(
        rejoined) == true)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    let captured = await NativePeopleTestFixture.capture(runtime)
    #expect(captured.commander.nativeCaptiveCount == 1)
    #expect(captured.commander.nativePeople?.heldCaptives.first?.actor == rejoined)
    let heldPerson = try #require(captured.commander.nativePeople?.heldCaptives.first?.person.emp)
    #expect(heldPerson.source == source)
    #expect(captured.commander.valid)
  }

  @Test func scheduleOnlyAndCapturedPeopleUseVersionedStorageAndSurviveMissingContent() async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    let source = try NativePeopleTestFixture.source(game)
    let schedule = game.commander.savedEMPState?.records[source]?.disableEpisodes
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    let initial = try Data(contentsOf: storage.url)
    #expect(try JSONDecoder().decode(ScriptSavePointer.self, from: initial).schemaVersion == 26)
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let collector = GameRuntime(game: game, saveURL: storage.url)
    _ = await NativePeopleTestFixture.capture(collector)
    let saved = await collector.snapshot()
    try #require(saved.commander.nativeCaptiveCount == 1)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    let loaded = await reader.snapshot()
    #expect(loaded.commander.savedEMPState?.records[source]?.disableEpisodes == schedule)
    #expect(loaded.commander.nativePeople == saved.commander.nativePeople)
    #expect(loaded.scriptPacks.isEmpty && loaded.commander.valid)
    #expect(loaded.commander.nativeCaptiveCount == 1 && loaded.commander.cargo[3] == 1)
    let pointer = try JSONDecoder().decode(
      ScriptSavePointer.self, from: Data(contentsOf: storage.url))
    for version in [21, 22, 23] {
      let downgraded = ScriptSavePointer(
        format: pointer.format, schemaVersion: version,
        generation: pointer.generation, hashes: pointer.hashes, scope: pointer.scope,
        valueCodec: pointer.valueCodec)
      #expect(throws: SaveError.invalidCommander) {
        _ = try ScriptSaveStore.read(
          ScriptValueStorage.encoder().encode(downgraded), from: storage.url)
      }
    }
  }

  @Test(arguments: ["savedCrewCaptures", "savedDisableEpisodes", "savedDeceasedOrdinals"])
  func oldHeaderRejectsEveryReservedFieldIncludingNullButIgnoresAuthoredText(field: String) throws {
    for records: Any in [
      ["source": [field: NSNull()]],
      [[:], [field: NSNull()]],
    ] {
      let bytes = try JSONSerialization.data(withJSONObject: ["savedEMPState": ["records": records]]
      )
      #expect(throws: SaveError.invalidCommander) {
        try NativePeopleVersionedSave.rejectFields(bytes)
      }
    }
    let innocent = try JSONSerialization.data(withJSONObject: [
      "scriptState": ["instances": ["data": [field: NSNull()]]], "name": field,
    ])
    try NativePeopleVersionedSave.rejectFields(innocent)
  }

  @Test(arguments: [
    "captures", "ordinals", "episodes", "ejections", "bindings", "deceased",
  ])
  func nestedCollectionsRejectOversizeBeforeDecodingPoisonedChildren(collection: String) throws {
    let field: String
    let maximum: Int
    switch collection {
    case "captures":
      field = "savedCrewCaptures"
      maximum = EMPState.maximumPeople
    case "episodes":
      field = "savedDisableEpisodes"
      maximum = EMPHullRecord.maximumDisableEpisodes
    case "deceased":
      field = "savedDeceasedOrdinals"
      maximum = EMPState.maximumPeople
    default:
      field = collection == "bindings" ? "actorBindings" : collection
      maximum = EMPState.maximumPeople
    }
    let poison = Array(repeating: NSNull(), count: maximum + 1)
    let bytes = try JSONSerialization.data(withJSONObject: [field: poison])
    do {
      if ["captures", "episodes", "deceased"].contains(collection) {
        _ = try JSONDecoder().decode(EMPHullRecord.self, from: bytes)
      } else if collection == "ordinals" {
        _ = try JSONDecoder().decode(NativeCrewCaptureReceipt.self, from: bytes)
      } else {
        // Supply earlier bounded siblings so the poisoned target is reached first.
        var object: [String: Any] = [
          "ejections": [], "actorBindings": [],
        ]
        object[field] = poison
        _ = try JSONDecoder().decode(
          EMPCrewDisableEpisode.self, from: JSONSerialization.data(withJSONObject: object))
      }
      Issue.record("Oversized collection accepted")
    } catch DecodingError.dataCorrupted(let context) {
      #expect(context.debugDescription.contains("collection limit exceeded"))
    }
  }

  @Test func missingInitialScheduleMemberAndUnscheduledNewPodFailTheSavedCensus() throws {
    var game = try NativePeopleTestFixture.disabled()
    for _ in 0..<15 { game.tick(delta: 0.1) }
    let source = try NativePeopleTestFixture.source(game)
    var record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.podIndex(for: 0) != nil)
    record.savedDisableEpisodes?[0].ejections.removeAll { $0.ordinal == 0 }
    #expect(!record.crewCensusValid && !record.valid)
    record = try #require(game.commander.savedEMPState?.records[source])
    let index = try #require(
      record.savedDisableEpisodes?[0].ejections.firstIndex { $0.ordinal == 0 })
    record.savedDisableEpisodes?[0].ejections[index].emittedAt = nil
    #expect(!record.crewCensusValid && !record.valid)
  }

  @Test func actualEscapeFailureRollsBackEquipmentPeopleCargoAndControls() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    try game.commander.grantEquipment(
      "Escape Pod", at: .utility(.escapePod), provenance: .grant("Native escape regression"))
    game.commander.mirrorFittedEquipment()
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    _ = await NativePeopleTestFixture.capture(runtime)
    var held = Controls()
    held.pitch = 0.2
    await runtime.setControls(held)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    await runtime.key("escape-pod")
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander && failed.docked == before.docked)
    #expect(await runtime.nativePeopleTestControls().pitch == held.pitch)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    await runtime.key("escape-pod")
    let escaped = await runtime.snapshot()
    #expect(escaped.docked && escaped.commander.nativeCaptiveCount == 0)
    #expect(escaped.commander.nativePeople?.transfers.last?.kind == .escape)
    #expect(escaped.commander.nativePeople?.admissions == before.commander.nativePeople?.admissions)
    #expect(
      escaped.commander.savedEMPState?.records.values.first?.crewCaptures
        == before.commander.savedEMPState?.records.values.first?.crewCaptures)
    #expect(!escaped.commander.equipment.contains("Escape Pod"))
    #expect(escaped.message.contains("PEOPLE LEFT WITH ABANDONED SHIP"))
  }

  @Test func fatalFrameFailedWriterKeepsProtectedCustodyUntilOneSuccessfulLossSave() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var game = try NativePeopleTestFixture.withinWindow()
    game.commander.cargo[0] = game.commander.standardCargoCapacity - 1
    try NativePeopleTestFixture.aimCutter(&game)
    let collector = GameRuntime(game: game, saveURL: storage.url)
    game = await NativePeopleTestFixture.capture(collector)
    let people = try #require(game.commander.nativePeople)
    game.energy = -100
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    let failed = await runtime.advance(delta: 0.05)
    #expect(failed.screen == .gameOver && failed.energy == 0)
    #expect(failed.commander.nativePeople == people && failed.commander.nativeCaptiveCount == 1)
    #expect(!failed.commander.ordinaryCommodityAmounts.contains { $0.commodity == .slaves })
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    try await runtime.save(to: storage.url)
    let saved = await runtime.snapshot()
    #expect(saved.commander.nativePeople?.held.isEmpty == true)
    #expect(saved.commander.nativePeople?.transfers.last?.kind == .loss)
    #expect(saved.commander.nativePeople?.admissions == people.admissions)
    #expect(saved.commander.cargo[3] == 0 && saved.commander.valid)
    try await runtime.save(to: storage.url)
    #expect(await runtime.snapshot().commander.nativePeople?.transfers.count == 1)
  }
}

extension GameRuntime {
  func nativePeopleTestControls() -> Controls { controls }
}
