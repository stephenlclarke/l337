import Foundation
import Testing

@testable import L337Core

private struct TitheCommissionTestContext {
  let runtime: GameRuntime
  let game: Game
  let files: ScriptFreightFixture

  /// Controlled scene placement uses real visits, station registration and swept docking.
  /// It creates no Voss contact, desk source, mission grant or livery evidence.
  static func prepare() async throws -> Self {
    let files = try ScriptFreightFixture()
    do {
      let starter = GameRuntime(game: Game(executive: false))
      try await starter.startNewCommander()
      var game = await starter.snapshot()
      game.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledTitheOfWorldsDirectory)]
      let affordableItem = game.market.indices.first {
        Commodity.all[$0].unit == "t" && game.market[$0].quantity >= 2
          && game.market[$0].price > 0
          && game.market[$0].price <= game.commander.availableCredits / 2
      }
      let item = try #require(affordableItem)
      game.selection = item
      game.screen = .buy
      game.trade(buy: true)
      game.trade(buy: true)
      game.screen = .sell
      game.trade(buy: false)
      game.trade(buy: false)
      let hasTwoSales = game.commander.scriptState.secondNativeCommoditySale != nil
      try #require(hasTwoSales)
      game.screen = .status
      game.launch()
      let launched = !game.docked
      try #require(launched)
      for system in [20, 69, 245, 105] {
        game.persistScriptActors(unloading: true)
        try game.departOrdinarySimulation()
        game.commander.galaxy = 6
        game.commander.system = system
        game.selectedSystem = system
        game.systems = Universe.systemsIncludingPlugh(number: 6)
        game.speed = 0
        game.screen = .front
        game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
        game.resetCelestialFlight()
        let beganVisit = game.beginGameplayVisit(arriving: true)
        try #require(beganVisit)
        game.applyScriptStationResources()
        try game.registerOriginalNativeMainStation()
      }
      let stationCandidate = game.bodies.first { $0.id == 0 && $0.hull == .station }
      let station = try #require(stationCandidate)
      let previous = game.commander.flightSimulation.pose
      var pose = ShipPose()
      pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
      pose.orientation.y = previous.orientation.apply(station.entranceUp)
      pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
      pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
      NativeStationTestFixture.reframe(&game, to: pose)
      game.speed = 3
      let runtime = GameRuntime(game: game)
      for _ in 0..<100 {
        if await runtime.snapshot().docked { break }
        _ = await runtime.advance(delta: 0.05)
      }
      let arrived = await runtime.snapshot()
      let actualDockIsCurrent = arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent
      try #require(actualDockIsCurrent)
      let history = try NativeTitheCommissionHistory.current(in: arrived)
      try #require(history.hasRequiredVisitHistory && history.retainedOrdinarySaleCount == 2
        && history.atRakenorMainBerth)
      try FileManager.default.createDirectory(
        at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
      _ = try await runtime.registerNewCommanderDestination(at: files.save)
      try await runtime.save(to: files.save)
      return .init(runtime: runtime, game: await runtime.snapshot(), files: files)
    } catch {
      files.clean()
      throw error
    }
  }

  /// An intentionally unissued DTO claim. It must never become a native capability.
  func unissuedFacts() throws -> NativeTitheCommissionAcceptanceFacts {
    let dockCandidate = game.commander.nativeStations?.currentMainDock
    let dock = try #require(dockCandidate)
    let arrivalCandidate = game.nativeMainStationArrivalContext(for: dock.station)
    let arrival = try #require(arrivalCandidate)
    let ownerCandidate = game.commander.equipmentOwnerID
    let owner = try #require(ownerCandidate)
    let mission = NativeTitheCommissionDefinition.mission(owner: owner)
    let carrierCandidate = game.commander.hullInstanceID
    let carrier = try #require(carrierCandidate)
    let inventoryRevisionCandidate = game.commander.equipmentInventory?.revision
    let inventoryRevision = try #require(inventoryRevisionCandidate)
    let desk = NativeTitheCommissionDeskRecord(source: UUID(), operation: UUID(), owner: owner,
      station: dock.station, role: "VOSS / HEARTH COMPACT COMMISSION")
    let visited = try NativeTitheCommissionHistory.acceptanceObservations(in: game, at: arrival)
    let firstSaleCandidate = game.commander.scriptState.firstNativeCommoditySale?.operation
    let firstSale = try #require(firstSaleCandidate)
    let secondSaleCandidate = game.commander.scriptState.secondNativeCommoditySale?.sale.operation
    let secondSale = try #require(secondSaleCandidate)
    return .init(mission: mission, owner: owner,
      carrier: carrier, inventoryRevision: inventoryRevision, dock: dock,
      desk: desk,
      visited: visited, firstSale: firstSale, secondSale: secondSale,
      sequence: game.commander.scriptState.nextEvent + 1,
      physicalTime: game.commander.flightSimulation.physicalTime,
      calendarSeconds: game.commander.scriptState.calendarSeconds)
  }

  func fileBytes() throws -> [String: Data] {
    let root = files.save.deletingLastPathComponent()
    let urls = try #require(FileManager.default.enumerator(at: root,
      includingPropertiesForKeys: [.isRegularFileKey])?.allObjects as? [URL])
    var result: [String: Data] = [:]
    for file in urls where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
      result[String(file.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: file)
    }
    return result
  }
}

struct NativeTitheCommissionTransactionTests {
  @Test func actualRakenorHistoryPreviewDeclineAndUnissuedConfirmPreserveCurrentSaveAndColdState()
    async throws
  {
    let context = try await TitheCommissionTestContext.prepare()
    defer { context.files.clean() }
    let before = await context.runtime.snapshot()
    let files = try context.fileBytes()
    let quote = await context.runtime.reviewTitheCommission()
    #expect(quote.warning == NativeTitheCommissionMark.warning)
    #expect(quote.observations?.count == 5 && quote.firstSale != quote.secondSale)
    #expect(quote.arrival != nil && quote.contact == nil && !quote.allowed)
    let originalContentPresent = before.titheCommissionPack != nil
    #expect(originalContentPresent)
    #expect(!quote.issues.contains("Restore the original fourteen-stage Tithe of Worlds definition."))
    #expect(quote.issues.contains(NativeTitheCommissionContactSource.unavailable))
    try await context.runtime.decideTitheCommission(quote, decision: .decline)
    var refused = false
    do {
      try await context.runtime.decideTitheCommission(quote, decision: .confirmPermanentMark)
    } catch { refused = true }
    #expect(refused)
    let after = await context.runtime.snapshot()
    let commanderAndBodiesUnchanged = after.commander == before.commander && after.bodies == before.bodies
    #expect(commanderAndBodiesUnchanged)
    let marketAndJumpUnchanged = after.market == before.market && after.jumpCountdown == before.jumpCountdown
    #expect(marketAndJumpUnchanged)
    let noCommissionGranted = after.commander.titheCommissionMarkEntitlement == nil && after.titheCommissionMission == nil
    #expect(noCommissionGranted)
    let afterFiles = try context.fileBytes()
    #expect(afterFiles == files)
    let cold = GameRuntime(game: Game(executive: false))
    try await cold.load(from: context.files.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    let firstSaleRetained = loaded.commander.scriptState.firstNativeCommoditySale == before.commander.scriptState.firstNativeCommoditySale
    #expect(firstSaleRetained)
    let secondSaleRetained = loaded.commander.scriptState.secondNativeCommoditySale == before.commander.scriptState.secondNativeCommoditySale
    #expect(secondSaleRetained)
    let noColdCommission = loaded.titheCommissionMission == nil && loaded.commander.titheCommissionMarkEntitlement == nil
    #expect(noColdCommission)
    let coldFiles = try context.fileBytes()
    #expect(coldFiles == files)
  }

  @Test func typedCandidateRetainsCaseAndExactPermanentMarkAcrossEncodingAndCopyWithoutIssuingContact()
    async throws
  {
    let context = try await TitheCommissionTestContext.prepare()
    defer { context.files.clean() }
    let facts = try context.unissuedFacts()
    let claim = try NativeTitheCommissionState(acceptance: facts)
    let original = try claim.openingInstance()
    try #require(NativeTitheCommissionSave.prefixValid(original))
    #expect(claim.mark.id == NativeTitheCommissionMark.id)
    #expect(claim.mark.receipt == NativeTitheCommissionMark.receipt && claim.mark.permanent)
    #expect(claim.mark.owner == facts.owner && claim.mark.acceptance == claim.operation)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: JSONEncoder().encode(original))
    #expect(decoded == original && decoded.savedTitheCommission == claim)
    var changed = decoded
    changed.savedTitheCommission = nil
    #expect(changed != original && original.savedTitheCommission === claim)
    #expect(!NativeTitheCommissionSave.prefixValid(changed))
    var commander = context.game.commander
    commander.scriptState.instances[original.id] = original
    commander.scriptState.nextEvent = facts.sequence
    let unissuedDeskRefused = !NativeTitheCommissionContactSource.recognizesHistorical(facts.desk, commander: commander)
    #expect(unissuedDeskRefused)
    let unissuedClaimsRefused = !NativeTitheCommissionSave.validateClaims(commander)
    #expect(unissuedClaimsRefused)
    let noMarkProjected = commander.titheCommissionMarkEntitlement == nil
    #expect(noMarkProjected)
    let noIssuedContact = NativeTitheCommissionContactSource.current(in: context.game) == nil
    #expect(noIssuedContact)
  }

  @Test func closedCurrentLeafRejectsDetachedAlteredAndDuplicatePermanentMarkClaims() async throws {
    let context = try await TitheCommissionTestContext.prepare()
    defer { context.files.clean() }
    let claim = try NativeTitheCommissionState(acceptance: context.unissuedFacts())
    let instance = try claim.openingInstance()
    let leafCandidate = try JSONSerialization.jsonObject(with: JSONEncoder().encode(claim)) as? [String: Any]
    let leaf = try #require(leafCandidate)
    let rawCandidate = try JSONSerialization.jsonObject(with: JSONEncoder().encode(instance)) as? [String: Any]
    let raw = try #require(rawCandidate)
    func archive(_ value: [String: Any]) throws -> Data {
      try JSONSerialization.data(withJSONObject: ["instances": [instance.id.uuidString: value]])
    }
    // This verifies the closed DATA shape only; the unissued claim fails commander admission.
    try NativeTitheCommissionSave.validateFields(archive(raw), part: .missions)
    for name in [NativeTitheCommissionSave.field, "titheCommission", "titheCommissionMarkEntitlement"] {
      let detached = try JSONSerialization.data(withJSONObject: [name: leaf])
      #expect(throws: SaveError.invalidCommander) {
        try NativeTitheCommissionSave.validateFields(detached, part: .missions)
      }
    }
    for key in ["owner", "acceptance", "receipt", "permanent"] {
      var value = raw
      var altered = leaf
      var mark = try #require(leaf["mark"] as? [String: Any])
      if key == "permanent" { mark[key] = false }
      else { mark[key] = key == "receipt" ? "changed" : UUID().uuidString }
      altered["mark"] = mark
      value[NativeTitheCommissionSave.field] = altered
      #expect(throws: SaveError.invalidCommander) {
        try NativeTitheCommissionSave.validateFields(archive(value), part: .missions)
      }
    }
    let bytes = try archive(raw)
    let text = try #require(String(data: bytes, encoding: .utf8))
    let integer = "\"inventoryRevision\":\(claim.acceptance.inventoryRevision)"
    for replacement in [integer + ".0", integer + "e0", "\"inventoryRevision\":null"] {
      let altered = text.replacingOccurrences(of: integer, with: replacement)
      try #require(altered != text)
      #expect(throws: SaveError.invalidCommander) {
        try NativeTitheCommissionSave.validateFields(Data(altered.utf8), part: .missions)
      }
    }
    var unknown = raw
    var extraLeaf = leaf
    var extraMark = try #require(leaf["mark"] as? [String: Any])
    extraMark["inventedGrant"] = true
    extraLeaf["mark"] = extraMark
    unknown[NativeTitheCommissionSave.field] = extraLeaf
    #expect(throws: SaveError.invalidCommander) {
      try NativeTitheCommissionSave.validateFields(archive(unknown), part: .missions)
    }
    let duplicate = text.replacingOccurrences(of: "\"permanent\":true", with: "\"permanent\":true,\"permanent\":true")
    try #require(duplicate != text)
    #expect(throws: SaveError.invalidCommander) {
      try NativeTitheCommissionSave.validateFields(Data(duplicate.utf8), part: .missions)
    }
  }
}
