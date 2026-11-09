import Foundation
import Testing

@testable import L337Core

/// Typed policy checks and a native publication regression.
struct NativeFlightReceptionUnitTests {
  private func fixture() throws -> (
    NativeFlightReceptionState, NativeFlightReceptionSample, NativeFlightReceptionSample
  ) {
    let owner = UUID()
    let mission = UUID()
    let carrier = UUID()
    let epoch = UUID()
    let system = SystemIdentity(galaxy: 0, system: 7)
    let station = NativeMainStationIdentity(
      world: owner, system: system,
      resource: Game.worldResourceIdentity("main-station-v1:main-orbital:0:7"))
    let dock = NativeMainStationDockReceipt(
      station: station, actor: .init(system: system, visit: 1, entity: 1),
      commanderOwner: owner, sequence: 1, calendarSeconds: 0)
    let operation = try NativeFlightReception.permissionOperation(
      mission: mission, owner: owner, carrier: carrier, revision: 4, dock: dock, fit: [])
    let state = NativeFlightReceptionState(
      permission: .init(
        mission: mission, operation: operation, owner: owner, carrier: carrier,
        inventoryRevision: 4, dock: dock, fit: [], epoch: epoch))
    func sample(z: Double, time: Double) -> NativeFlightReceptionSample {
      .init(
        mission: mission, permission: operation, owner: owner, carrier: carrier,
        inventoryRevision: 4, station: station,
        player: .init(system: system, visit: 2, entity: 0),
        actor: .init(system: system, visit: 2, entity: 1),
        pose: .init(position: .init(0, 0, z)), stationPosition: .init(0, 0, 1200),
        relativeVelocity: .init(0, 0, 8), time: time, epoch: epoch)
    }
    return (state, sample(z: 0, time: 10), sample(z: 0.4, time: 10.05))
  }

  private func replacing<T: Codable>(_ value: T, key: String, with replacement: Any) throws -> T {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object[key] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func positiveBoundedAlignedApproachRetainsExactAuthorityAndRoundTrips() throws {
    let (_, first, last) = try fixture()
    let reading = try NativeFlightReception.measure(first: first, last: last)
    #expect(reading.first == first && reading.last == last)
    #expect(NativeFlightReception.readingValid(reading))
    #expect(
      try JSONDecoder().decode(
        NativeFlightReceptionReading.self,
        from: JSONEncoder().encode(reading)) == reading)
    let forged = try replacing(reading, key: "authority", with: UUID().uuidString)
    #expect(!NativeFlightReception.readingValid(forged))
  }

  @Test func changedAuthorityClockOrUnmovedPoseCannotSupplyApproachEvidence() throws {
    let (_, first, last) = try fixture()
    for key in ["mission", "permission", "owner", "carrier", "epoch"] {
      let changed = try replacing(last, key: key, with: UUID().uuidString)
      #expect(throws: (any Error).self) {
        try NativeFlightReception.measure(first: first, last: changed)
      }
    }
    for time in [10.0, 10.2, 9.9] {
      let changed = try replacing(last, key: "time", with: time)
      #expect(throws: (any Error).self) {
        try NativeFlightReception.measure(first: first, last: changed)
      }
    }
    let samePose = try replacing(
      last, key: "pose",
      with:
        JSONSerialization.jsonObject(with: JSONEncoder().encode(first.pose)))
    #expect(throws: (any Error).self) {
      try NativeFlightReception.measure(first: first, last: samePose)
    }
    let changedFit = try replacing(last, key: "inventoryRevision", with: 5)
    #expect(throws: (any Error).self) {
      try NativeFlightReception.measure(first: first, last: changedFit)
    }
  }

  @Test func wrongAimRangeAndNonClosingMotionRefuseQualification() throws {
    let (_, first, _) = try fixture()
    for vector in [Vector3(0, 0, 900), Vector3(0, 0, 1600), Vector3(100, 0, 1200)] {
      let sample = try replacing(
        first, key: "stationPosition",
        with:
          JSONSerialization.jsonObject(with: JSONEncoder().encode(vector)))
      #expect(!sample.qualifies)
    }
    for vector in [Vector3(0, 0, 0), Vector3(0, 0, -8)] {
      let sample = try replacing(
        first, key: "relativeVelocity",
        with:
          JSONSerialization.jsonObject(with: JSONEncoder().encode(vector)))
      #expect(!sample.qualifies)
    }
  }

  @Test func receptionRequiresMeasuredSameBerthLaterDoorwayReceiptAndSeparatePermission() throws {
    let (initial, first, last) = try fixture()
    var state = initial
    let permission = state.permission
    let arrival = NativeMainStationDockReceipt(
      station: permission.dock.station, actor: last.actor, commanderOwner: permission.owner,
      sequence: 2, calendarSeconds: 5)
    #expect(!NativeFlightReception.returnReady(state, dock: arrival))
    state.reading = try NativeFlightReception.measure(first: first, last: last)
    #expect(NativeFlightReception.returnReady(state, dock: arrival))
    #expect(!NativeFlightReception.returnReady(state, dock: permission.dock))
    let foreign = try replacing(arrival, key: "commanderOwner", with: UUID().uuidString)
    #expect(!NativeFlightReception.returnReady(state, dock: foreign))
    let oldVisit = try replacing(
      arrival, key: "actor",
      with:
        JSONSerialization.jsonObject(with: JSONEncoder().encode(permission.dock.actor)))
    #expect(!NativeFlightReception.returnReady(state, dock: oldVisit))
    let (_, otherFirst, otherLast) = try fixture()
    state.reading = try NativeFlightReception.measure(first: otherFirst, last: otherLast)
    #expect(!NativeFlightReception.returnReady(state, dock: arrival))
  }

  @Test(arguments: [false, true])
  func refusedApproachWriteCanResumeAtTheActualSameDoorwayAfterColdLoad(protected: Bool)
    async throws
  {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    var initial = try ScriptProcurementFixture.freshG03FlightGame()
    try initial.prepareG03FlightEquipment()
    if protected {
      initial.commander.system = NativeMemoryAtlasWatcherSource.world.system
      initial.selectedSystem = initial.commander.system
      initial.market = MarketItem.at(initial.currentSystem)
    }
    initial.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledFlightReceptionDirectory)
    ]
    let runtime = GameRuntime(game: initial, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    await runtime.key("0")
    try await ScriptProcurementFixture.dock(runtime)
    try await confirmPractice(.accept, runtime: runtime)
    let issued = await runtime.snapshot()
    let attempt = try #require(issued.activeFlightReception)
    if issued.screen == .contracts {
      if issued.contractBoard.detail { await runtime.key("escape") }
      await runtime.key("escape")
    }
    await runtime.key("0")
    await runtime.nativeCommand { game in
      _ = Self.framePractice(&game, forDoorway: false)
    }
    let approaching = await runtime.snapshot()
    try #require(approaching.flightReceptionSample() != nil)
    try storage.blockWriter()
    let refused = await runtime.advance(delta: 0.05)
    let pending = try #require(refused.nativeFlightReceptionPending)
    try #require(refused.activeFlightReception?.state.reading == nil)
    try storage.restoreWriter()

    let received = try await runtime.crossPracticeDoorway(protected: protected)
    let arrival = try #require(
      received.nativeMainStationArrivalContext(for: attempt.state.permission.dock.station))
    try #require(arrival.receipt.actor == pending.reading.last.actor)
    try #require(received.nativeStationRuntimeEpoch != pending.reading.first.epoch)
    try #require(received.nativeFlightReceptionPending === pending)
    try #require(received.activeFlightReception?.state.reading == nil)
    var unproved = received
    unproved.nativeMainStationDockEvidence = nil
    #expect(throws: SaveError.self) { try unproved.applyFlightReceptionPending() }
    var invalidated = received
    invalidated.invalidateNativeStationAuthority()
    #expect(invalidated.nativeFlightReceptionPending == nil)

    try await runtime.save(to: storage.url)
    try await runtime.load(from: storage.url, persistMigrations: false)
    if await runtime.snapshot().paused { await runtime.key("pause") }
    let resumed = await runtime.snapshot()
    #expect(resumed.nativeFlightReceptionPending == nil)
    #expect(resumed.activeFlightReception?.state.reading == pending.reading)
    try await confirmPractice(.receive, runtime: runtime)
    let finished = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    let completed = try #require(finished.scriptState.instances[attempt.instance.id])
    #expect(completed.outcome == .complete && completed.milestones == [0, 1, 2])
    #expect(completed.savedFlightReception?.terminalDock == arrival.receipt)
    #expect(finished.credits == issued.commander.credits)
    #expect(finished.scriptState.savedClueJournal?.awards.count == 1)
    #expect(
      finished.scriptState.savedClueJournal?.awards[NativeFlightReception.stateID]?.completion
        == completed.completionReceipt)
  }

  private func confirmPractice(_ action: NativeFlightReceptionAction, runtime: GameRuntime)
    async throws
  {
    await runtime.key("contracts-open")
    let board = await runtime.snapshot().contractBoard
    let index = try #require(board.rows.firstIndex { $0.flightReception == action })
    for _ in 0..<abs(index - board.selection) {
      await runtime.key(index < board.selection ? "up" : "down")
    }
    await runtime.key("return")
    let review = try #require(await runtime.snapshot().contractBoard.flightReceptionQuote)
    try #require(review.allowed, Comment(rawValue: review.issues.joined(separator: ", ")))
    await runtime.key("right")
    await runtime.key("return")
  }

  fileprivate static func framePractice(_ game: inout Game, forDoorway: Bool) -> Bool {
    guard let station = game.bodies.first(where: { $0.id == 0 && $0.hull == .station }) else {
      return false
    }
    let previous = game.commander.flightSimulation.pose
    let outward = previous.orientation.apply(station.entranceNormal)
    let anchor = forDoorway ? station.entrancePosition : station.position
    var pose = ShipPose()
    pose.position = previous.systemPoint(anchor) + outward * (forDoorway ? 2 : 1200)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = outward * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.clearManualResidualFlight()
    game.autoPilot.disengage()
    game.speed = 3
    return true
  }

  @Test(arguments: [false, true])
  func strictLeafAndSharedSchemaPreserveLowerNativeFeatureGates(alien: Bool) throws {
    let (state, _, _) = try fixture()
    let leaf = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    let instance: [String: Any] = [
      "definition": NativeFlightReception.stateID,
      "digest": NativeFlightReception.digest, "savedFlightReception": leaf,
    ]
    func bytes(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": ["tutorial": value]])
    }
    let schema = alien ? 60 : 59
    try ScriptSaveJSONPreflight.validateRepairLoopFields(
      try bytes(instance), part: .missions, schema: schema)
    #expect(throws: (any Error).self) {
      try ScriptSaveJSONPreflight.validateRepairLoopFields(
        try bytes(instance), part: .missions, schema: schema - 2)
    }
    var missing = instance
    missing.removeValue(forKey: "savedFlightReception")
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(missing), part: .missions, schema: schema)
    }
    var unknown = try #require(leaf as? [String: Any])
    unknown["invented"] = true
    var forged = instance
    forged["savedFlightReception"] = unknown
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(forged), part: .missions, schema: schema)
    }
    var wrongDigest = instance
    wrongDigest["digest"] = String(repeating: "0", count: 64)
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(wrongDigest), part: .missions, schema: schema)
    }
    var nested = try #require(leaf as? [String: Any])
    var permission = try #require(nested["permission"] as? [String: Any])
    permission["unexpected"] = 1
    nested["permission"] = permission
    forged["savedFlightReception"] = nested
    #expect(throws: (any Error).self) {
      try NativeFlightReceptionSave.validateFields(
        try bytes(forged), part: .missions, schema: schema)
    }
    let lower = NativeFlightReceptionSave.lowerSchema(schema)
    #expect(lower == (alien ? 58 : 57))
    #expect(
      NativeMeasuredExtractionSave.lowerSchema(WayfarerFieldReliefSave.lowerSchema(lower))
        == (alien ? 54 : 53))
    #expect(NativeFlightReceptionSave.lowerSchema(nil) == nil)
    #expect(NativeFlightReceptionSave.lowerSchema(53) == 53)
  }

  @Test func bundledLessonPinsCurrentFitZeroPaymentAndClosedNativeDeclaration() throws {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledFlightReceptionDirectory)
    #expect(pack.digest == NativeFlightReception.digest)
    #expect(pack.manifest.stateID == NativeFlightReception.stateID)
    #expect(pack.missingCapabilities.isEmpty && pack.manifest.trial == nil)
    #expect(pack.manifest.mission.milestones.count == 3)
    var mixed = pack.manifest
    mixed.measuredExtraction = try ScriptPackLibrary.read(
      ScriptPackLibrary.bundledMeasuredExtractionDirectory
    ).manifest.measuredExtraction
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateFlightReception(mixed) }
    mixed = pack.manifest
    mixed.flightReception = nil
    #expect(throws: (any Error).self) { try ScriptPackLibrary.validateFlightReception(mixed) }
  }
}

extension GameRuntime {
  fileprivate func crossPracticeDoorway(protected: Bool) throws -> Game {
    // Frame geometry on the same live actor. Only native motion can issue the doorway receipt.
    let framed = NativeFlightReceptionUnitTests.framePractice(&game, forDoorway: true)
    try #require(framed)
    for _ in 0..<100 {
      if game.docked || game.pendingMemoryAtlasMainDock != nil { break }
      game.tick(delta: 0.1)
    }
    try #require((game.pendingMemoryAtlasMainDock != nil) == protected)
    if protected {
      // Leave publication to the following ordinary save so the live pending object is observable.
      try game.commitPendingMemoryAtlasMainArrival { candidate in
        try #require(candidate.nativeMainStationDockEvidenceIsCurrent)
      }
    }
    return snapshot()
  }
}
