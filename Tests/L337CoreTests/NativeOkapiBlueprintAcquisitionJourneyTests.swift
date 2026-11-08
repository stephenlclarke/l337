import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

/// One specific SH029 acquisition path. Controlled starting location/funds and hostile
/// encounter birth are declared test inputs, not a natural RNG encounter, flown route,
/// people consent, owned blueprint, weapon payment, cut, intake or exchange authority.
/// Every positive below must be earned by the actual native actor/current writer. UNRUN.
enum NativeOkapiAcquisitionJourneyFixture {
  static let shipID = "SH029"

  /// Reusable by G3's existing loan test only after the entire physical prerequisite succeeds.
  /// No constructor or argument can provide an acquisition receipt/blueprint in its place.
  @inline(never)
  static func preparedExchangeRuntime(storage: NativeStationTestStorage) async throws -> GameRuntime {
    let runtime = try configuredExchangeRuntime(storage: storage)
    await runtime.beginScriptRefusalObservation()
    try await ScriptFinanceTestFixture.enterMain(runtime)
    return try await finishPreparedExchange(runtime, storage: storage)
  }

  @inline(never)
  private static func configuredExchangeRuntime(storage: NativeStationTestStorage) throws -> GameRuntime {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.galaxy = 0
    game.commander.system = 69
    game.selectedSystem = 69
    game.systems = Universe.systemsIncludingPlugh(number: 0)
    game.market = MarketItem.at(game.currentSystem)
    // Explicit finite fixture funding only. It does not satisfy the blueprint projection.
    game.commander.credits = 20_000_000
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    try #require(game.commander.shipID == "SH025" && game.commander.valid)
    try #require(!game.commander.unlimitedCash && !game.commander.unlimitedFuel)
    try #require(game.currentSystem.name == "Verasel" && game.currentSystem.technology == 16)
    try #require(game.commander.fleetBlueprintAcquisition(for: shipID) == nil)
    // Exact normal owned starter; no unearned transfer to the acquisition target.
    game.launch()
    try #require(!game.docked)
    try ScriptFinanceTestFixture.approachMain(&game)
    game.nativeSalvageAdmissionDiagnostic = .init()
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    return runtime
  }

  @inline(never)
  private static func finishPreparedExchange(
    _ runtime: GameRuntime, storage: NativeStationTestStorage
  ) async throws -> GameRuntime {
    let prepared = try await prepareExchangeEMPActor(runtime, storage: storage)
    try await runtime.okapiDisableWithActualEMP(shipID, actor: prepared.actor)
    return try await finishDisabledExchange(runtime, storage: storage, prepared: prepared)
  }

  @inline(never)
  private static func preparePaidEMPJourney(
    _ runtime: GameRuntime, storage: NativeStationTestStorage
  ) async throws -> OkapiPaidEquipment {
    try await runtime.save(to: storage.url)
    try #require(await runtime.snapshot().nativeMainStationDockEvidenceIsCurrent)
    try await NativeCrewTestFixture.fill(runtime)
    // Basic Navigation is intrinsic hardware, not a paid shop node. Keep its real identity
    // through the first shop upgrade; paid shield ancestry must include every intermediate.
    let standardNavigation = try #require(
      await runtime.snapshot().commander.fittedEquipment(at: .navigation))
    let standardNavigationNode = try #require(
      EquipmentRuntimeCatalog.node(for: NavigationTier.basic.equipmentName))
    try #require(standardNavigation.node == standardNavigationNode)
    try #require(standardNavigation.provenance == .standard)
    let purchaseNames = [
      TargetingTier.basic.equipmentName, TargetingTier.advanced.equipmentName,
      TargetingTier.docking.equipmentName, ShieldBooster.pulse.equipmentName,
      ShieldBooster.mining.equipmentName, ShieldBooster.beam.equipmentName,
      "Extra Energy Unit", "Military Laser", "Military Shield Booster",
      Equipment.empPirateBlaster, "Salvage Cutter", "Fuel Scoops",
      "Targeting: Salvage Module", NavigationTier.advanced.equipmentName,
    ]
    for name in purchaseNames {
      try await purchasePaidEquipment(name, runtime: runtime)
    }
    let stocked = await runtime.snapshot()
    let purchaseHistory = try #require(stocked.commander.equipmentPurchaseHistory)
    try #require(Array(purchaseHistory.paid.map(\.node.key).suffix(purchaseNames.count)) == purchaseNames)
    try #require(!purchaseHistory.paid.contains { $0.node == standardNavigationNode })
    let retainedNavigation = try #require(
      stocked.commander.equipmentInventory?.items.first { $0.id == standardNavigation.id })
    try #require(retainedNavigation.location == nil)
    try #require(retainedNavigation.moved(to: nil) == standardNavigation.moved(to: nil))
    try #require(stocked.commander.navigationTier == .advanced && stocked.commander.valid)
    await runtime.key("3")
    for axis in EMPModuleAxis.allCases {
      for grade in 1...3 {
        let before = await runtime.snapshot()
        let module = try #require(before.currentEMPPlayerModule())
        let context = try before.empModulePurchaseContext(module: module.id, axis: axis)
        let receipt = try await runtime.purchaseEMPModuleUpgrade(context)
        let after = await runtime.snapshot()
        try #require(receipt.after.value(for: axis) == grade && receipt.paidPrice > 0)
        try #require(after.commander.credits == before.commander.credits - receipt.paidPrice)
        try #require(after.currentEMPPlayerModule()?.empBank?.remaining == 0)
      }
    }
    let paid = await runtime.snapshot()
    let weapon = try #require(paid.currentEMPPlayerModule())
    let owner = try #require(paid.commander.equipmentOwnerID)
    guard case .paid(let buyer, let operation) = weapon.provenance else {
      throw OkapiJourneyFailure.payment
    }
    try #require(buyer == owner)
    let purchase = try #require(paid.commander.equipmentPurchaseHistory?.paid.first {
      $0.transaction == operation && $0.binding.request.newItem == weapon.id
    })
    try #require(purchase.price > 0 && purchase.binding.snapshot.funds != Int.max)
    try #require(purchase.binding.snapshot.funds >= purchase.price)
    try #require(paid.commander.fleetBlueprintAcquisition(for: shipID) == nil)
    return .init(weapon: weapon, owner: owner)
  }

  @inline(never)
  private static func prepareExchangeEMPActor(
    _ runtime: GameRuntime, storage: NativeStationTestStorage
  ) async throws -> OkapiPreparedDisable {
    let paid = try await preparePaidEMPJourney(runtime, storage: storage)
    let weapon = paid.weapon
    let owner = paid.owner
    await runtime.key("0")
    try await runtime.okapiEarnBank()
    try await runtime.okapiDepartToAllowedRegion(minimumStationDistance: 25_000)
    await runtime.enableStationDefenceDiagnostics()
    let actor = try await runtime.okapiAdmitControlledHostile()
    try #require(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: shipID) == nil)
    try await runtime.okapiSelect(actor, stage: "live actor before EMP")
    try await runtime.okapiSelectTool(.empPirateBlaster)
    return .init(actor: actor, weapon: weapon, owner: owner)
  }

  @inline(never)
  private static func finishDisabledExchange(
    _ runtime: GameRuntime, storage: NativeStationTestStorage, prepared: OkapiPreparedDisable
  ) async throws -> GameRuntime {
    let actor = prepared.actor
    try await requireDisabledExchangeSource(runtime, prepared: prepared)
    let empty = try await runtime.okapiWaitForEmptyHull(actor)
    try await requireEvacuatedExchangeSource(runtime, actor: actor)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    try await runtime.okapiSelect(empty, stage: "empty hull before cutting", filter: .salvage)
    let lot = try await runtime.okapiCutActualSection(source: actor)
    try #require(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: shipID) == nil)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    let fragment = try await releasedExchangeFragment(runtime, lot: lot)
    try await runtime.okapiSelect(fragment, stage: "released fragment before intake", filter: .salvage)
    try await runtime.okapiScoopActualSample(shipID, lot: lot)
    let acquisition = try await receivedExchangeAcquisition(runtime, actor: actor, lot: lot)
    await runtime.setControls(Controls())
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    try await runtime.okapiUseTargetFilter(.ships)
    try await ScriptProcurementFixture.dock(runtime,
      selectionDiagnostic: .init(label: "paid Okapi return after genuine salvage intake"))
    let commodity = try await runtime.okapiReceivedCommodity(shipID)
    await runtime.key("7")
    await runtime.key("market-sell")
    try #require(await runtime.snapshot().screen == .sell)
    let requestedRow = try #require(MarketDisplayOrder.commodityIDs.firstIndex(of: commodity.rawValue))
    for _ in 0..<17 {
      let selected = await runtime.snapshot().selection
      if selected == commodity.rawValue { break }
      let currentRow = try #require(MarketDisplayOrder.commodityIDs.firstIndex(of: selected))
      await runtime.key(currentRow > requestedRow ? "up" : "down")
    }
    try #require(await runtime.snapshot().selection == commodity.rawValue)
    for _ in 0..<256 {
      if await runtime.snapshot().commander.cargo[commodity.rawValue] == 0 { break }
      await runtime.key("left")
    }
    let ready = await runtime.snapshot()
    try #require(ready.commander.cargo[commodity.rawValue] == 0)
    try #require(ready.nativeMainStationDockEvidenceIsCurrent && ready.commander.system == 69)
    try #require(ready.commander.fleetBlueprintAcquisition(for: shipID) == acquisition)
    try #require(ready.commander.valid && ready.commander.nativeCrewMissing == 0)
    let selected = try #require(ShipCatalogue.ship(shipID))
    let quote = try #require(ready.shipTradeQuote(for: selected))
    try #require(quote.allowed, "Actual acquisition is not exchange permission without all current prerequisites: \(quote.issues)")
    try await runtime.save(to: storage.url)
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot()
    try #require(restored.commander.fleetBlueprintAcquisition(for: shipID) == acquisition)
    try #require(restored.nativeMainStationDockEvidenceIsCurrent && restored.commander.valid)
    try #require(restored.shipTradeQuote(for: selected)?.allowed == true)
    return cold
  }

  @inline(never)
  private static func requireDisabledExchangeSource(
    _ runtime: GameRuntime, prepared: OkapiPreparedDisable
  ) async throws {
    let actor = prepared.actor
    let weapon = prepared.weapon
    let owner = prepared.owner
    let disabled = await runtime.snapshot()
    let record = try #require(disabled.commander.savedEMPState?.records[actor])
    try #require(record.weapon.id == weapon.id && record.weaponOwner == owner)
    try #require(disabled.commander.fleetBlueprintAcquisition(for: shipID) == nil)
  }

  @inline(never)
  private static func requireEvacuatedExchangeSource(_ runtime: GameRuntime, actor: ActorIdentity) async throws {
    let evacuated = await runtime.snapshot()
    let emptyRecord = try #require(evacuated.commander.savedEMPState?.records[actor])
    try #require(emptyRecord.crewAboard == 0 && emptyRecord.lostCrewCount == 0)
    try #require(emptyRecord.pods.count + emptyRecord.capturedCrewCount == emptyRecord.crewTotal)
    try requireOriginalNativeEncoding(evacuated)
  }

  @inline(never)
  private static func releasedExchangeFragment(_ runtime: GameRuntime, lot: SalvageLotIdentity) async throws -> ActorIdentity {
    let released = await runtime.snapshot()
    let body = try #require(released.bodies.first { $0.physical?.payload == .salvage(lot) })
    let fragment = try #require(body.physical?.identity)
    let actualLot = try #require(released.currentSalvageLot(for: body))
    try #require(actualLot.identity == lot && actualLot.massKg >= 50)
    return fragment
  }

  @inline(never)
  private static func receivedExchangeAcquisition(
    _ runtime: GameRuntime, actor: ActorIdentity, lot: SalvageLotIdentity
  ) async throws -> NativeFleetBlueprintAcquisition {
    let received = await runtime.snapshot()
    let acquisition = try #require(received.commander.fleetBlueprintAcquisition(for: shipID))
    try #require(acquisition.source == actor && acquisition.section == lot.section)
    try #require(acquisition.receivedMassKg >= 50)
    try #require(received.commander.fleetBlueprintAcquisition(for: "SH030") == nil)
    return acquisition
  }

  static func purchasePaidEquipment(_ name: String, runtime: GameRuntime) async throws {
    try await runtime.scriptCommand { candidate in
      try #require(candidate.nativeMainStationDockEvidenceIsCurrent)
      let item = try #require(Equipment.all.first { $0.name == name })
      try #require(candidate.equipmentAvailable(item))
      let before = candidate.commander
      let history = try #require(before.equipmentPurchaseHistory)
      let quote = try candidate.quoteEquipmentPurchase(item)
      try #require(quote.purchase.requiredDebit > 0)
      let purchased = try candidate.applyEquipmentPurchase(quote)
      try #require(purchased)
      let paid = try #require(candidate.commander.equipmentPurchaseHistory)
      try #require(candidate.commander.credits == before.credits - quote.purchase.requiredDebit)
      try #require(paid.paid.count == history.paid.count + 1)
      try #require(paid.paid.last?.binding.request == quote.request)
      let receipt = try #require(paid.paid.last)
      let inventory = try #require(candidate.commander.equipmentInventory)
      let owned = try #require(inventory.items.first { $0.id == quote.request.newItem })
      try #require(receipt.owner == inventory.owner && receipt.price == quote.purchase.requiredDebit)
      try #require(receipt.node == owned.node && owned.node == quote.request.offer.node)
      try #require(owned.location == quote.location && owned.location != nil)
      try #require(owned.provenance == .paid(owner: receipt.owner, transaction: receipt.transaction))
    }
  }

  /// The same earned blueprint, actual paid exchange, writer rollback and cold restoration.
  @inline(never)
  static func purchasedRuntime(storage: NativeStationTestStorage) async throws -> GameRuntime {
    let runtime = try await NativeOkapiAcquisitionJourneyFixture.preparedExchangeRuntime(storage: storage)
    return try await purchasePreparedExchange(runtime, storage: storage)
  }

  @inline(never)
  private static func purchasePreparedExchange(
    _ runtime: GameRuntime, storage: NativeStationTestStorage
  ) async throws -> GameRuntime {
    let prepared = await runtime.snapshot()
    let proof = try #require(prepared.commander.fleetBlueprintAcquisition(for: "SH029"))
    let previous = try #require(prepared.commander.equipmentInventory)
    await runtime.key("6")
    await runtime.key("/")
    for character in "SH029" { await runtime.key(String(character)) }
    await runtime.key("return")
    try #require(await runtime.snapshot().showroom.selection == "SH029")
    await runtime.key("return")
    await runtime.key("right")
    let before = await runtime.snapshot()
    let quote = try #require(before.shipTradeQuote)
    try #require(before.showroom.trading && before.showroom.confirmTrade && quote.allowed)
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander && refused.bodies == before.bodies)
    #expect(refused.scriptWorldSave == before.scriptWorldSave)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    await runtime.key("return")
    let bought = await runtime.snapshot()
    try #require(bought.commander.shipID == "SH029" && bought.commander.valid)
    #expect(bought.commander.credits == quote.balance)
    #expect(bought.commander.fleetBlueprintAcquisition(for: "SH029") == proof)
    let current = try #require(bought.commander.equipmentInventory)
    #expect(current.owner == previous.owner && current.activeHull != previous.activeHull)
    #expect(Set(current.items.map(\.id)) == Set(previous.items.map(\.id)))
    for item in previous.items {
      let transferred = try #require(current.items.first { $0.id == item.id })
      #expect(transferred.node == item.node && transferred.provenance == item.provenance)
      #expect(transferred.component == item.component)
    }
    try #require(bought.commander.nativeCrewMissing == 0)
    try await runtime.save(to: storage.url)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(restored.commander == saved && saved == bought.commander)
    #expect(restored.commander.fleetBlueprintAcquisition(for: "SH029") == proof)
    #expect(restored.nativeMainStationDockEvidenceIsCurrent)
    return cold
  }
}

struct NativeOkapiBlueprintAcquisitionJourneyTests {
  @Test func ordinaryNPCSteersItsFixedFrontBeamOntoTheActualOpenCentrePlayerHull() async throws {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = 69
    game.selectedSystem = 69
    game.systems = Universe.systemsIncludingPlugh(number: 0)
    game.market = MarketItem.at(game.currentSystem)
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    game.launch()
    try #require(!game.docked && game.commander.shipID == "SH025")
    let runtime = GameRuntime(game: game)
    try await runtime.okapiDepartToAllowedRegion()
    let actor = try await runtime.okapiAdmitControlledHostile()
    await runtime.enableStationDefenceDiagnostics()
    var controls = Controls()
    controls.throttle = -1
    await runtime.setControls(controls)
    let before = await runtime.snapshot()
    let source = try #require(before.bodies.first { $0.physical?.identity == actor })
    let player = try #require(before.commander.flightSimulation.player)
    let centreRay = GameplayRaycast.nearest(
      origin: source.position, direction: source.position * -1, maxDistance: 20_000,
      bodies: [], playerMesh: before.commander.playerMesh)
    try #require(centreRay == nil)
    var after = before
    var incoming: CombatIncident?
    for _ in 0..<600 {
      after = await runtime.advance(delta: 0.1)
      incoming = after.gameplayCombatTrace?.incidents.first {
        $0.origin.owner == actor && $0.victim == player && $0.kind == .laser && $0.outcome == .hit
      }
      if incoming != nil { break }
    }
    let hit = try #require(incoming)
    #expect(hit.mount == .front && hit.laser == .pulse)
    #expect(hit.origin.emittedAt > before.commander.flightSimulation.physicalTime)
    let fired = try #require(after.bodies.first { $0.physical?.identity == actor })
    #expect(fired.orientation != source.orientation && fired.energy < source.energy)
    #expect(fired.physical?.laserCooldown == LaserKind.pulse.firingInterval)
    #expect((fired.physical?.npc?.resources?.laserHeat ?? 0) > 0)
    let context = try #require(after.gameplayContext())
    #expect(after.commander.crimeLedger.hasCurrentUnlawfulAttack(
      from: actor, against: player, context: context))
    #expect(after.frontShield < before.frontShield || after.rearShield < before.rearShield)
  }

  @Test func actualPaidEMPEmptyOkapiCutIntakeAndPaidFabricationSurviveCurrentSave() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    _ = try await NativeOkapiAcquisitionJourneyFixture.purchasedRuntime(storage: storage)
  }
}

private final class OriginalSpaceBodyWire: Encodable {
  let id: Int
  let hull: Hull
  let position: Vector3
  let rotation: Double
  let orientation: Basis3
  let rotationRate: Double
  let energy: Double
  let hostile: Bool
  let navalTarget: Bool
  let missiles: Int
  let playerMissileTarget: Int?
  let enemyMissile: Bool
  let missileSourceID: Int?
  let destroyedByPlayer: Bool?
  let missionActorID: UUID?
  let missionInstanceID: UUID?
  let blackjackIdentity: UUID?
  let blackjackRole: BlackjackTarget?
  let blackjackLaserCooldown: Double?
  let scriptNPC: ScriptNPCState?
  let scriptShot: ScriptNPCShot?
  let ecmEnabled: Bool
  let physical: PhysicalActorState?
  let nativeStationIdentity: NativeStationIdentity?

  @inline(never)
  init(_ value: borrowing SpaceBody) {
    self.id = value.id
    self.hull = value.hull
    self.position = value.position
    self.rotation = value.rotation
    self.orientation = value.orientation
    self.rotationRate = value.rotationRate
    self.energy = value.energy
    self.hostile = value.hostile
    self.navalTarget = value.navalTarget
    self.missiles = value.missiles
    self.playerMissileTarget = value.playerMissileTarget
    self.enemyMissile = value.enemyMissile
    self.missileSourceID = value.missileSourceID
    self.destroyedByPlayer = value.destroyedByPlayer
    self.missionActorID = value.missionActorID
    self.missionInstanceID = value.missionInstanceID
    self.blackjackIdentity = value.blackjackIdentity
    self.blackjackRole = value.blackjackRole
    self.blackjackLaserCooldown = value.blackjackLaserCooldown
    self.scriptNPC = value.scriptNPC
    self.scriptShot = value.scriptShot
    self.ecmEnabled = value.ecmEnabled
    self.physical = value.physical
    self.nativeStationIdentity = value.nativeStationIdentity
  }
}

private final class OriginalEMPStoredWire: Encodable {
  let body: OriginalSpaceBodyWire
  let binding: ActorIdentity?
  let physicalTime: Double

  @inline(never)
  init(_ value: borrowing EMPStoredObject) {
    self.body = OriginalSpaceBodyWire(value.body)
    self.binding = value.binding
    self.physicalTime = value.physicalTime
  }
}

private final class OriginalEMPCustodyWire: Encodable {
  let kind: EMPSourceCustody.Kind
  let logical: ActorIdentity
  let original: OriginalEMPStoredWire
  let traffic: NPCPersistenceSnapshot?
  let assignment: PoliceAssignment?

  @inline(never)
  init(_ value: borrowing EMPSourceCustody) {
    self.kind = value.kind
    self.logical = value.logical
    self.original = OriginalEMPStoredWire(value.original)
    self.traffic = value.traffic
    self.assignment = value.assignment
  }
}

private final class OriginalEMPHullWire: Encodable {
  let source: ActorIdentity
  let sequence: UInt64
  let wreck: WreckIdentity
  let crewTotal: Int
  let originalSpawn: SpawnIdentity?
  let originalBodyID: Int
  let custody: OriginalEMPCustodyWire
  let disableIncident: CombatIncident
  let weapon: OwnedEquipmentItem
  let weaponOwner: UUID
  let pods: [OriginalEMPStoredWire]
  let hull: OriginalEMPStoredWire
  let cargo: [CommodityAmount]
  let legal: LegalRecord
  let nextEjectionAt: Double
  let terminal: Bool
  let lostCrewCount: Int
  let savedCrewCaptures: [NativeCrewCaptureReceipt]?
  let savedDisableEpisodes: [EMPCrewDisableEpisode]?
  let savedDeceasedOrdinals: [Int]?
  let savedRecoveredAt: Double?
  let savedOrdinaryTerminal: NPCTerminalReason?
  let savedCurrentTrafficTransfer: NPCPersistenceSnapshot?
  let savedCurrentCargo: [CommodityAmount]?
  let savedCurrentLegal: LegalRecord?

  @inline(never)
  init(_ value: borrowing EMPHullRecord) {
    self.source = value.source
    self.sequence = value.sequence
    self.wreck = value.wreck
    self.crewTotal = value.crewTotal
    self.originalSpawn = value.originalSpawn
    self.originalBodyID = value.originalBodyID
    self.custody = OriginalEMPCustodyWire(value.custody)
    self.disableIncident = value.disableIncident
    self.weapon = value.weapon
    self.weaponOwner = value.weaponOwner
    self.pods = value.pods.map { OriginalEMPStoredWire($0) }
    self.hull = OriginalEMPStoredWire(value.hull)
    self.cargo = value.cargo
    self.legal = value.legal
    self.nextEjectionAt = value.nextEjectionAt
    self.terminal = value.terminal
    self.lostCrewCount = value.lostCrewCount
    self.savedCrewCaptures = value.savedCrewCaptures
    self.savedDisableEpisodes = value.savedDisableEpisodes
    self.savedDeceasedOrdinals = value.savedDeceasedOrdinals
    self.savedRecoveredAt = value.savedRecoveredAt
    self.savedOrdinaryTerminal = value.savedOrdinaryTerminal
    self.savedCurrentTrafficTransfer = value.savedCurrentTrafficTransfer
    self.savedCurrentCargo = value.savedCurrentCargo
    self.savedCurrentLegal = value.savedCurrentLegal
  }
}

private final class OriginalEMPStateWire: Encodable {
  let records: [ActorIdentity: EMPHullRecord]
  let nextSequence: UInt64

  @inline(never)
  init(_ value: borrowing EMPState) {
    self.records = value.records
    self.nextSequence = value.nextSequence
  }
}

@inline(never)
private func requireOriginalNativeEncoding(_ game: Game) throws {
  let opening = game
  let encoder = ScriptValueStorage.encoder()
  for body in game.bodies {
    try requireOriginalBodyEncoding(body, encoder: encoder)
  }
  try requireOriginalBodyEncoding(SpaceBody(id: -77, hull: .cargo, position: .init(0, 0, 0)), encoder: encoder)
  let state = try #require(game.commander.savedEMPState)
  let encodedState = try encoder.encode(state)
  let originalState = OriginalEMPStateWire(state)
  #expect(encodedState == (try encoder.encode(originalState)))
  try requireOriginalStoredWireKeys(state, data: encodedState)
  let empty = EMPState()
  #expect(try encoder.encode(empty) == encoder.encode(OriginalEMPStateWire(empty)))
  for record in state.records.values {
    let encoded = try encoder.encode(record)
    let original = OriginalEMPHullWire(record)
    #expect(encoded == (try encoder.encode(original)))
    try requireOriginalStoredWireKeys(record, data: encoded)
    let custody = try encoder.encode(record.custody)
    #expect(custody == (try encoder.encode(OriginalEMPCustodyWire(record.custody))))
    try requireOriginalStoredWireKeys(record.custody, data: custody)
    for stored in [record.custody.original, record.hull] + record.pods {
      let encoded = try encoder.encode(stored)
      #expect(encoded == (try encoder.encode(OriginalEMPStoredWire(stored))))
      try requireOriginalStoredWireKeys(stored, data: encoded)
      try requireOriginalBodyEncoding(stored.body, encoder: encoder)
    }
  }
  // A transparent owned root must preserve JSON configuration and every concrete field.
  let direct = try encoder.encode(game.commander)
  let prepared = NativeSaveEncodingValue<Commander>.prepare(game.commander)
  #expect(try encoder.encode(prepared) == direct)
  #expect(game.currentNewtNativeCommanderMatches(opening))
  #expect(game.bodies == opening.bodies && game.scriptWorldSave == opening.scriptWorldSave)
}

@inline(never)
private func requireOriginalBodyEncoding(_ body: SpaceBody, encoder: JSONEncoder) throws {
  let encoded = try encoder.encode(body)
  let original = OriginalSpaceBodyWire(body)
  #expect(encoded == (try encoder.encode(original)))
  try requireOriginalStoredWireKeys(body, data: encoded)
  var invalid = body
  invalid.energy = .nan
  do {
    _ = try encoder.encode(invalid)
    Issue.record("Native body encoding accepted non-finite energy")
  } catch EncodingError.invalidValue(_, let context) {
    #expect(context.codingPath.map(\.stringValue) == ["energy"])
  }
  do {
    _ = try encoder.encode(OriginalSpaceBodyWire(invalid))
    Issue.record("Original body encoding accepted non-finite energy")
  } catch EncodingError.invalidValue(_, let context) {
    #expect(context.codingPath.map(\.stringValue) == ["energy"])
  }
}

@inline(never)
private func requireOriginalStoredWireKeys<Value>(_ value: Value, data: Data) throws {
  let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  let expected = Set(Mirror(reflecting: value).children.compactMap { child -> String? in
    guard let name = child.label else { return nil }
    let field = Mirror(reflecting: child.value)
    if field.displayStyle == .optional && field.children.isEmpty { return nil }
    return name
  })
  #expect(Set(object.keys) == expected)
}

@inline(never)
private func requireOriginalEMPDisabledPolicy(_ game: Game) throws {
  let opening = game
  for body in game.bodies {
    let actual = game.isEMPDisabled(body)
    let original = originalEMPDisabledPolicy(game, body: body)
    #expect(actual == original)
  }
  #expect(game.currentNewtNativeCommanderMatches(opening))
  #expect(game.bodies == opening.bodies && game.scriptWorldSave == opening.scriptWorldSave)
}

@inline(never)
private func originalEMPDisabledPolicy(_ game: Game, body: SpaceBody) -> Bool {
  guard let source = body.physical?.empSource,
    let record = game.commander.savedEMPState?.records[source]
  else { return false }
  return !record.terminal && !record.isRecovered && record.hull.binding == body.physical?.identity
}

private enum OkapiCutAction {
  case next, exteriorFrame, cutFrame
  case released(SalvageLotIdentity)
}

private final class OkapiCutEvidence {
  var firstRefusal: String?
  var firstReleaseFailure: String?
  var approach: OkapiCutSurfaceApproach?
  var exhaustedSections: [String] = []
  var firstStructuralCustody: String?
  var latestStructuralCustody: String?
  var latestHullAllocator = "none"
}

private final class OkapiPaidEquipment: Sendable {
  let weapon: OwnedEquipmentItem
  let owner: UUID

  init(weapon: OwnedEquipmentItem, owner: UUID) {
    self.weapon = weapon
    self.owner = owner
  }
}

private final class OkapiPreparedDisable: Sendable {
  let actor: ActorIdentity
  let weapon: OwnedEquipmentItem
  let owner: UUID

  init(actor: ActorIdentity, weapon: OwnedEquipmentItem, owner: UUID) {
    self.actor = actor
    self.weapon = weapon
    self.owner = owner
  }
}

private final class OkapiDisableFrame {
  let start: FlightSimulationState
  let previousDropped: Int
  let input: Controls
  let priorCharge: EMPChargeState?

  @inline(never)
  init(start: FlightSimulationState, previousDropped: Int, input: Controls, priorCharge: EMPChargeState?) {
    self.start = start
    self.previousDropped = previousDropped
    self.input = input
    self.priorCharge = priorCharge
  }
}

extension GameRuntime {
  fileprivate func okapiSelectTool(_ tool: FlightWorkTool) throws {
    for _ in 0..<4 {
      if game.selectedFlightTool == tool { return }
      key(FlightControlInput.token(for: .changeWeapon))
    }
    throw OkapiJourneyFailure.toolSelection
  }

  @inline(never)
  fileprivate func okapiLiveFrame() throws -> Game {
    try #require(game.bodies.count <= 256 && game.screen.isFlight && !game.docked)
    try #require(!game.paused && game.energy > 0)
    let start = game.storedFlightSimulation().physicalTime
    let after = advance(delta: 0.1)
    return try okapiVerifyLiveFrame(after, start: start)
  }

  @inline(never)
  private func okapiVerifyLiveFrame(_ after: Game, start: Double) throws -> Game {
    try #require(after.commander.flightSimulation.physicalTime > start)
    try #require(after.bodies.count <= 256 && after.screen.isFlight && after.energy > 0)
    return after
  }

  @inline(never)
  fileprivate func okapiEarnBank() throws {
    var input = Controls()
    input.throttle = -1
    setControls(input)
    for _ in 0..<256 {
      if try okapiBankIsFull() { return }
      _ = try okapiLiveFrame()
    }
    throw OkapiJourneyFailure.bankBudget
  }

  @inline(never)
  private func okapiBankIsFull() throws -> Bool {
    let bank = try #require(game.currentEMPPlayerModule()?.empBank)
    return bank.remaining == bank.capacity
  }

  @inline(never)
  fileprivate func okapiDisableWithActualEMP(_ shipID: String, actor: ActorIdentity) throws {
    let epoch = try #require(game.gameplayCombatTrace?.epoch)
    let player = try #require(game.commander.flightSimulation.player)
    var incoming = false
    var evidence = OkapiDisableEvidence()
    game.gameplayCombatTrace?.beam = .init(actor: actor)
    defer { game.gameplayCombatTrace?.beam = nil }
    evidence.firstActor = okapiActorObservation(actor)
    for _ in 0..<1200 {
      if try okapiDisabledSourceIsCurrent(shipID, actor: actor, player: player, incoming: incoming, evidence: evidence) { return }
      let frame = try okapiPrepareDisableFrame(incoming: incoming, evidence: &evidence)
      let after = try okapiLiveFrame()
      try okapiObserveDisableFrame(after, frame: frame, actor: actor, player: player,
        epoch: epoch, incoming: &incoming, evidence: &evidence)
    }
    setControls(Controls())
    evidence.lastActor = okapiActorObservation(actor)
    evidence.beam = game.gameplayCombatTrace?.beam?.description
    throw OkapiJourneyFailure.disableBudget(evidence)
  }

  @inline(never)
  private func okapiDisabledSourceIsCurrent(
    _ shipID: String, actor: ActorIdentity, player: ActorIdentity,
    incoming: Bool, evidence: OkapiDisableEvidence
  ) throws -> Bool {
    let context = try #require(game.gameplayContext())
    if let disabled = game.commander.savedEMPState?.records[actor] {
      try #require(incoming && disabled.source == actor && disabled.valid)
      try #require(disabled.hull.body.physical?.catalogueShipID == shipID)
      try #require(disabled.weaponOwner == game.commander.equipmentOwnerID)
      try #require(disabled.disableIncident.kind == .emp && disabled.disableIncident.outcome == .hit)
      try #require(disabled.disableIncident.origin.owner == player)
      try requireOriginalEMPDisabledPolicy(game)
      try requireOriginalNativeEncoding(game)
      setControls(Controls())
      return true
    }
    if incoming {
      try #require(game.commander.crimeLedger.hasCurrentUnlawfulAttack(
        from: actor, against: player, context: context), Comment(rawValue: evidence.description))
    }
    return false
  }

  @inline(never)
  private func okapiPrepareDisableFrame(
    incoming: Bool, evidence: inout OkapiDisableEvidence
  ) throws -> OkapiDisableFrame {
    let start = game.storedFlightSimulation()
    let previousDropped = try #require(game.gameplayCombatTrace?.dropped)
    var input = Controls()
    input.throttle = -1
    // A completed charge or safety latch needs a real release before another press.
    let mayHoldCharge = game.commander.savedEMPCharge.map { $0.phase == .charging } ?? true
    input.fire = incoming && mayHoldCharge && !game.workFireSuspended
    let priorCharge = game.commander.savedEMPCharge
    if incoming && !input.fire && evidence.firstGate == nil {
      evidence.firstGate = "time=\(start.physicalTime) requested=false"
        + " chargeAllowsHold=\(mayHoldCharge) suspended=\(game.workFireSuspended)"
    }
    setControls(input)
    if input.fire && evidence.firstFire == nil {
      let bank = game.currentEMPPlayerModule()?.empBank?.remaining
      evidence.firstFire = "time=\(start.physicalTime) requested=true admitted=\(controls.fire)"
        + " tool=\(game.selectedFlightTool) screen=\(game.screen)"
        + " bank=\(String(describing: bank)) cooldown=\(game.fireCooldown) heat=\(game.laserHeat)"
        + " playerReserve=\(String(describing: game.commander.savedPlayerElectrical?.remaining))"
    }
    return .init(start: start, previousDropped: previousDropped, input: input, priorCharge: priorCharge)
  }

  @inline(never)
  private func okapiObserveDisableFrame(
    _ after: Game, frame: OkapiDisableFrame, actor: ActorIdentity, player: ActorIdentity,
    epoch: UUID, incoming: inout Bool, evidence: inout OkapiDisableEvidence
  ) throws {
    let start = frame.start
    let previousDropped = frame.previousDropped
    let input = frame.input
    let priorCharge = frame.priorCharge
    let trace = try #require(after.gameplayCombatTrace)
    try #require(trace.epoch == epoch && trace.incidents.count <= 128)
    if trace.dropped > previousDropped {
      try #require(trace.incidents.first.map { $0.id < start.nextIncident } == true)
    }
    if let charge = after.commander.savedEMPCharge, charge != priorCharge {
      let detail = "phase=\(charge.phase.rawValue) sourceMatch=\(charge.target == actor)"
        + " started=\(charge.startedAt) ended=\(String(describing: charge.endedAt))"
      if charge.phase == .charging, evidence.firstCharge == nil {
        evidence.firstCharge = detail
      } else if charge.phase != .charging, evidence.firstTerminal == nil {
        evidence.firstTerminal = detail + " fire=\(input.fire) message=\(after.message)"
      }
      if charge.phase == .released, evidence.firstRelease == nil {
        evidence.firstRelease = detail + " message=\(after.message)"
      }
    }
    if evidence.firstPulse == nil,
      let pulse = game.currentEMPPulseBeforeResult(), pulse.charge.target == actor
    {
      let incident = trace.incidents.first {
        $0.id >= start.nextIncident && $0.id < after.commander.flightSimulation.nextIncident
          && $0.kind == .emp && $0.origin.owner == player && $0.victim == actor
          && $0.origin.emissionID == pulse.emissionID
      }
      let body = after.bodies.first { $0.physical?.identity == actor }
      let electrical = body?.physical?.npc?.resources?.electrical
      let disabled = after.commander.savedEMPState?.records[actor]
      let publication = "emission=\(pulse.emissionID) incident=\(String(describing: incident?.id))"
      let outcome = "outcome=\(String(describing: incident?.outcome))"
      let before = "electricalBefore=\(pulse.primary.electrical.remaining)/\(pulse.primary.electrical.capacity)"
      let remaining = "electricalAfter=\(String(describing: electrical?.remaining))"
      let disabledAt = "disabledAt=\(String(describing: electrical?.disabledAt))"
      let sourceRecord = "sourceRecord=\(disabled?.source == actor)"
      evidence.firstPulse = [publication, outcome, before, remaining, disabledAt, sourceRecord]
        .joined(separator: " ")
    }
    for hit in trace.incidents where hit.id >= start.nextIncident {
      try #require(hit.id < after.commander.flightSimulation.nextIncident)
      if evidence.firstActorLaser == nil, hit.origin.owner == actor,
        hit.victim == player, hit.kind == .laser
      {
        let flight = after.commander.flightSimulation
        let incident = "id=\(hit.id) outcome=\(hit.outcome) playerVictim=\(hit.victim == player)"
        let interval = "incidentBounds=[\(start.nextIncident),\(flight.nextIncident))"
        let emission = "emission=\(hit.origin.emissionID) bounds=[\(start.nextEmission),\(flight.nextEmission))"
        let time = "hitTime=\(hit.physicalTime) emittedAt=\(hit.origin.emittedAt)"
        let frame = "frame=(\(start.physicalTime),\(flight.physicalTime)]"
        evidence.firstActorLaser = [incident, interval, emission, time, frame].joined(separator: " ")
      }
      if hit.kind == .laser && hit.outcome == .hit,
        hit.origin.owner == actor && hit.victim == player,
        hit.physicalTime > start.physicalTime,
        hit.physicalTime <= after.commander.flightSimulation.physicalTime,
        hit.origin.emissionID >= start.nextEmission,
        hit.origin.emissionID < after.commander.flightSimulation.nextEmission,
        hit.origin.emittedAt > start.physicalTime,
        hit.origin.emittedAt <= after.commander.flightSimulation.physicalTime
      {
        let current = try #require(after.gameplayContext())
        try #require(after.commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: actor, against: player, context: current))
        if evidence.firstIncoming == nil {
          evidence.firstIncoming = "incident=\(hit.id) emission=\(hit.origin.emissionID) time=\(hit.physicalTime)"
        }
        incoming = true
      }
    }
  }

  @inline(never)
  fileprivate func okapiActorObservation(_ actor: ActorIdentity) -> String {
    guard let body = game.bodies.first(where: { $0.physical?.identity == actor }) else {
      return "absent"
    }
    let physical = body.physical
    let intention = String(describing: physical?.npc?.intention)
    let cooldown = String(describing: physical?.laserCooldown)
    let canFire = String(describing: physical?.npc?.resources?.canFire)
    return "position=\(body.position) energy=\(body.energy) hostile=\(body.hostile)"
      + " intention=\(intention) cooldown=\(cooldown) canFire=\(canFire)"
  }

  @inline(never)
  fileprivate func okapiWaitForEmptyHull(_ source: ActorIdentity) throws -> ActorIdentity {
    setControls(Controls())
    let occupied = try #require(game.commander.savedEMPState?.records[source]?.hull.binding)
    key(FlightControlInput.token(for: .releaseHold))
    try okapiSelect(occupied, stage: "occupied hull before evacuation", filter: .salvage)
    try okapiSelectTool(.salvageCutter)
    for _ in 0..<600 {
      if let actor = try okapiEmptyHullSource(source) { return actor }
      var input = Controls()
      input.fire = game.workGuidance?.holding == true && !game.workFireSuspended
      setControls(input)
      _ = try okapiLiveFrame()
    }
    setControls(Controls())
    throw OkapiJourneyFailure.crewDepartureBudget
  }

  @inline(never)
  private func okapiEmptyHullSource(_ source: ActorIdentity) throws -> ActorIdentity? {
    let record = try #require(game.commander.savedEMPState?.records[source])
    try #require(record.valid && record.lostCrewCount == 0)
    if record.crewAboard == 0 {
      try #require(record.pods.count + record.capturedCrewCount == record.crewTotal)
      let actor = try #require(record.hull.binding)
      let body = try #require(game.bodies.first { $0.physical?.identity == actor })
      try #require(body.physical?.npc == nil && body.physical?.empSource == source)
      setControls(Controls())
      return actor
    }
    return nil
  }

  @inline(never)
  fileprivate func okapiCutActualSection(source: ActorIdentity) throws -> SalvageLotIdentity {
    let wreck = try #require(game.commander.savedEMPState?.records[source]?.wreck)
    let actor = try #require(game.commander.savedEMPState?.records[source]?.hull.binding)
    try okapiSelectTool(.salvageCutter)
    let evidence = OkapiCutEvidence()
    for _ in 0..<1200 {
      switch try okapiPrepareCutIteration(wreck: wreck, actor: actor, evidence: evidence) {
      case .next: continue
      case .exteriorFrame:
        _ = try okapiLiveFrame()
      case .released(let lot):
        _ = try okapiLiveFrame()
        return lot
      case .cutFrame:
        _ = try okapiLiveFrame()
        okapiObserveCutFrame(evidence)
      }
    }
    return try okapiCutBudgetFailure(wreck: wreck, actor: actor, evidence: evidence)
  }

  @inline(never)
  private func okapiPrepareCutIteration(
    wreck: WreckIdentity, actor: ActorIdentity, evidence: OkapiCutEvidence
  ) throws -> OkapiCutAction {
    let observation = okapiStructuralCustodyObservation(wreck: wreck)
    if let custody = observation.custody {
      if evidence.firstStructuralCustody == nil { evidence.firstStructuralCustody = custody }
      evidence.latestStructuralCustody = custody
    }
    evidence.latestHullAllocator = observation.allocator
    if let state = game.commander.alienStorageState?.current {
      try #require(state.snapshot.world.count <= 4096)
      let active = Set(game.bodies.compactMap { $0.physical?.identity })
      var released: [SalvageLotIdentity] = []
      for record in state.snapshot.world {
        if case .companion(let value) = record, case .structural = value.origin,
          case .pending(let lot, _, _, let binding) = value.state,
          lot.identity.section.wreck == wreck, lot.massKg >= 50, let binding,
          active.contains(binding)
        {
          released.append(lot.identity)
        }
      }
      if let lot = released.min(by: { $0.lot < $1.lot }) {
        setControls(Controls())
        // Releasing the trigger flushes its actual work before acquisition is queried.
        return .released(lot)
      }
    }
    if var route = evidence.approach {
      let step = try okapiPrepareExteriorInput(&route, actor: actor)
      evidence.approach = route
      switch step {
      case .advance:
        // All route observation temporaries have returned before the synchronous writer.
        return .exteriorFrame
      case .phaseChanged:
        break
      case .facingHull:
        try okapiSelect(actor, stage: "unexhausted surface after manual exterior flight",
          filter: .salvage)
        let next = try #require(game.workGuidance?.surface.section)
        try #require(next != route.previous && !game.salvageSectionIsDepleted(next),
          "Actual exterior flight selected section \(next.section) after \(route.previous.section)")
        evidence.approach = nil
      }
      return .next
    }
    if let section = game.workGuidance?.surface.section,
      game.salvageSectionIsDepleted(section)
    {
      let exhaustedKind = game.autoTargetBody.flatMap { body in
        game.salvageProfile(for: body)?.sections.first { $0.index == section.section }?.kind
      }
      evidence.exhaustedSections.append("\(section.section):\(String(describing: exhaustedKind))")
      setControls(Controls())
      key(FlightControlInput.token(for: .releaseHold))
      try okapiSelect(actor, stage: "next unexhausted cutting surface", filter: .salvage)
      let next = try #require(game.workGuidance?.surface.section)
      if next == section || game.salvageSectionIsDepleted(next) {
        // Other intact faces can be hidden from this completed face's holding point.
        evidence.approach = try okapiPrepareExteriorApproach(previous: section, wreck: wreck)
        key(FlightControlInput.token(for: .releaseHold))
      } else {
        try #require(next != section && !game.salvageSectionIsDepleted(next))
      }
      return .next
    }
    var input = Controls()
    input.fire = game.workGuidance?.holding == true && !game.workFireSuspended
    setControls(input)
    return .cutFrame
  }

  @inline(never)
  private func okapiObserveCutFrame(_ evidence: OkapiCutEvidence) {
    if evidence.firstRefusal == nil, game.message.hasPrefix("SALVAGE REFUSED") {
      evidence.firstRefusal = game.message
    }
    if evidence.firstReleaseFailure == nil, game.message.hasPrefix("SALVAGE SAVE FAILED") {
      evidence.firstReleaseFailure = (game.nativeSalvageWork?.firstReleaseRefusal ?? "releaseRefusal=none")
        + " " + (scriptRefusalDiagnostic?.detail() ?? "writerRefusal=none")
    }
  }

  @inline(never)
  private func okapiCutBudgetFailure(
    wreck: WreckIdentity, actor: ActorIdentity, evidence: OkapiCutEvidence
  ) throws -> SalvageLotIdentity {
    let section = game.workGuidance?.surface.section
    let kind = game.autoTargetBody.flatMap { body in
      game.salvageProfile(for: body)?.sections.first { $0.index == section?.section }?.kind
    }
    let native = game.commander.alienStorageState?.current.salvage.native
    let plan = native?.plans.values.first { $0.plan.section == section }
    let details = [
      "time=\(game.commander.flightSimulation.physicalTime) actor=[\(okapiActorObservation(actor))]",
      "selected=\(String(describing: game.autoTargetBody?.physical?.identity)) filter=\(game.workTargetFilter)",
      "guidance=\(game.workGuidance?.status ?? "none") holding=\(game.workGuidance?.holding == true)",
      "section=\(String(describing: section)) kind=\(String(describing: kind))",
      "depleted=\(section.map { game.salvageSectionIsDepleted($0) } ?? false)",
      "weapon=\(game.deriveFlightWeaponDisplay().text) suspended=\(game.workFireSuspended)",
      "exhaustedSections=\(evidence.exhaustedSections) exteriorWaypoint=\(String(describing: evidence.approach?.index))",
      "actualSpeed=\(game.flightWorldVelocity.length)",
      "firstStructuralCustody=\(evidence.firstStructuralCustody ?? "none") latestStructuralCustody=\(evidence.latestStructuralCustody ?? "none")",
      "hullAllocator=\(evidence.latestHullAllocator) admission=[\(game.nativeSalvageAdmissionDiagnostic?.detail() ?? "disabled")]",
      "firstRefusal=\(evidence.firstRefusal ?? "none")",
      "firstReleaseFailure=\(evidence.firstReleaseFailure ?? "none")",
      "inspection=\(section.flatMap { native?.inspections[$0] } != nil) plan=\(plan != nil)",
      "savedWork=\(plan.flatMap { native?.works[$0.id] } != nil)",
      "workSeconds=\(String(describing: game.nativeSalvageWork?.cycle.currentWorkSeconds))",
      "nextLot=\(String(describing: game.nativeSalvageWork?.cycle.progress.nextLot)) message=\(game.message)",
    ].joined(separator: " ")
    setControls(Controls())
    throw OkapiJourneyFailure.cutBudget(details)
  }

  @inline(never)
  private func okapiStructuralCustodyObservation(
    wreck: WreckIdentity
  ) -> (custody: String?, allocator: String) {
    guard let current = game.commander.alienStorageState?.current else { return (nil, "none") }
    let plans = current.salvage.native.plansByWreck[wreck] ?? []
    let hull = plans.first { $0.plan.section.section == 0 }
    let cycle = hull.flatMap { current.salvage.native.works[$0.id] }
    let allocator = hull.map {
      "units=\($0.progress.structuralUnits),issued=\($0.progress.issuedStructural),nextLot=\($0.progress.nextLot),releases=\(cycle?.releases ?? 0),depleted=\($0.depleted)"
    } ?? "none"
    let planIDs = Set(plans.map(\.id))
    for record in current.snapshot.world {
      guard case .companion(let item) = record, case .structural = item.origin,
        planIDs.contains(item.plan)
      else { continue }
      let prefix = "record=\(item.id),at=\(item.issuedAt)"
      switch item.state {
      case .pending(let lot, let time, let offer, let binding):
        let active = game.bodies.contains { $0.physical?.identity == binding && binding != nil }
        return (prefix + ",pending,section=\(lot.identity.section.section),mass=\(lot.massKg),time=\(time),offer=\(String(describing: offer)),binding=\(String(describing: binding)),active=\(active)", allocator)
      case .collected(let collection):
        return (prefix + ",collected=\(collection.operation),at=\(collection.at)", allocator)
      case .researched(let collection, _):
        return (prefix + ",researched=\(collection.operation),at=\(collection.at)", allocator)
      case .discarded(let at): return (prefix + ",discarded=\(at)", allocator)
      case .destroyed(let at): return (prefix + ",destroyed=\(at)", allocator)
      }
    }
    return (nil, allocator)
  }

  @inline(never)
  private func okapiPrepareExteriorInput(
    _ route: inout OkapiCutSurfaceApproach, actor: ActorIdentity
  ) throws -> OkapiExteriorStep {
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    let pose = game.modelPose(of: body)
    let point = route.index < route.points.count
      ? pose.systemPoint(route.points[route.index]) : pose.position
    let relative = game.commander.flightSimulation.pose.shipPoint(point)
    let actualSpeed = game.flightWorldVelocity.length
    if route.index < route.points.count, relative.length < 40, actualSpeed < 10 {
      route.index += 1
      return .phaseChanged
    }
    let yaw = atan2(relative.x, relative.z)
    let pitch = atan2(relative.y, hypot(relative.x, relative.z))
    if route.index == route.points.count, abs(yaw) < 0.03, abs(pitch) < 0.03,
      actualSpeed < 1
    {
      setControls(Controls())
      return .facingHull
    }
    let craft = game.commander.performance
    var input = Controls()
    input.yaw = max(-1, min(1, yaw * 1.8 / craft.yaw))
    input.pitch = max(-1, min(1, pitch * 1.8 / craft.pitch))
    let aligned = abs(yaw) < 0.1 && abs(pitch) < 0.1
    let desiredSpeed = route.index < route.points.count && aligned
      ? min(160, sqrt(2 * game.workLimits.acceleration * max(0, relative.length - 20)) * 0.5) : 0
    let speedStep = game.workLimits.acceleration * 0.1
    if actualSpeed > desiredSpeed + speedStep { input.throttle = -1 }
    if actualSpeed < desiredSpeed - speedStep { input.throttle = 1 }
    if desiredSpeed == 0 { input.throttle = -1 }
    setControls(input)
    return .advance
  }

  @inline(never)
  private func okapiPrepareExteriorApproach(
    previous: WreckSectionIdentity, wreck: WreckIdentity
  ) throws -> OkapiCutSurfaceApproach {
    let body = try #require(game.autoTargetBody)
    let profile = try #require(game.salvageProfile(for: body))
    let structural = try #require(profile.sections.first {
      $0.structural && !game.salvageSectionIsDepleted(.init(wreck: wreck, section: $0.index))
    })
    let localPlayer = game.modelPose(of: body).shipPoint(game.commander.flightSimulation.pose.position)
    let playerRadius = game.commander.playerMesh.vertices.map(\.length).max() ?? 0
    return .init(previous: previous,
      points: okapiExteriorWaypoints(from: localPlayer, section: structural,
        hullRadius: profile.mesh.vertices.map(\.length).max() ?? 0, playerRadius: playerRadius))
  }

  @inline(never)
  fileprivate func okapiScoopActualSample(_ shipID: String, lot: SalvageLotIdentity) throws {
    setControls(Controls())
    for _ in 0..<1200 {
      if try okapiSampleWasReceived(shipID, lot: lot) { return }
      _ = try okapiLiveFrame()
    }
    throw OkapiJourneyFailure.scoopBudget
  }

  @inline(never)
  private func okapiSampleWasReceived(_ shipID: String, lot: SalvageLotIdentity) throws -> Bool {
    if let proof = game.commander.fleetBlueprintAcquisition(for: shipID) {
      try #require(proof.section == lot.section && proof.receivedMassKg >= 50)
      return true
    }
    return false
  }

  fileprivate func okapiReceivedCommodity(_ shipID: String) throws -> CommodityIdentity {
    let proof = try #require(game.commander.fleetBlueprintAcquisition(for: shipID))
    let intake = try #require(game.commander.alienStorageState?.current.salvage.receivedStructure[shipID]?.first {
      if case .collected(let receipt) = $0.record.state { return receipt.operation == proof.collection }
      return false
    })
    guard case .commodity(let amount) = intake.item.content else {
      throw OkapiJourneyFailure.receivingType
    }
    return amount.commodity
  }

  @inline(never)
  fileprivate func okapiDepartToAllowedRegion(minimumStationDistance: Double = 0) throws {
    // Actual 20,000-unit police patrols and 1,500-unit beams must not pre-empt the ten-second EMP.
    // The paid acquisition stages at 25,000; the independent steering regression keeps its border.
    try #require(minimumStationDistance == 0 || minimumStationDistance == 25_000)
    let limits = game.workLimits
    let flightSeconds = minimumStationDistance / limits.speed + limits.speed / limits.acceleration + 1
    let frames = max(300, Int(ceil(flightSeconds / 0.1)))
    var input = Controls()
    input.throttle = 1
    setControls(input)
    for _ in 0..<frames {
      if try okapiDepartureIsAllowed(minimumStationDistance: minimumStationDistance) {
        input.throttle = -1
        setControls(input)
        return
      }
      _ = advance(delta: 0.1)
    }
    throw OkapiJourneyFailure.departureBudget
  }

  @inline(never)
  private func okapiDepartureIsAllowed(minimumStationDistance: Double) throws -> Bool {
    try #require(!game.docked && game.screen.isFlight && game.energy > 0 && !game.paused)
    let context = try #require(game.gameplayContext())
    let region = EncounterGeography.region(at: context.player.position, anchors: context.anchors)
    if (region == .tradeLane || region == .deepSpace),
      (context.player.position - context.anchors.station.position).length > minimumStationDistance
    {
      return true
    }
    return false
  }

  fileprivate func okapiUseTargetFilter(_ filter: WorkTargetFilter) throws {
    for _ in 0..<4 {
      if game.workTargetFilter == filter { break }
      key(FlightControlInput.token(for: .targetFilter))
    }
    try #require(game.workTargetFilter == filter)
  }

  fileprivate func okapiSelect(
    _ actor: ActorIdentity, stage: String, filter: WorkTargetFilter = .ships
  ) throws {
    // EMP-disabled hulls and their released sections use the player's salvage filter.
    try okapiUseTargetFilter(filter)
    for _ in 0..<128 {
      if game.autoTargetBody?.physical?.identity == actor { return }
      key("tab")
    }
    let body = game.bodies.first { $0.physical?.identity == actor }
    let context = game.gameplayContext()
    let layout = CockpitLayout(game: game, width: game.viewportWidth, height: game.viewportHeight)
    let front = body.map { Display.visibleInFront($0, game: game, layout: layout) } ?? false
    let decision = body.flatMap { body in
      context.flatMap { context in
        game.workTargetCandidate(for: body, context: context, frontVisible: front).map {
          WorkTargetSelection.evaluate(
            $0, system: context.system, visit: context.visit,
            capabilities: game.workTargetCapabilities)
        }
      }
    }
    let details = [
      "time=\(game.commander.flightSimulation.physicalTime) desired=\(actor)",
      "actor=[\(okapiActorObservation(actor))] decision=\(String(describing: decision)) front=\(front)",
      "selected=\(String(describing: game.autoTargetBody?.physical?.identity)) filter=\(game.workTargetFilter)",
      "core=\(String(describing: game.commander.targetingTier)) auto=\(game.autoPilot.status)",
      "screen=\(game.screen) paused=\(game.paused) docked=\(game.docked) bodies=\(game.bodies.count)",
      "commanderValid=\(game.commander.valid) EMP=\(game.commander.savedEMPState?.records[actor] != nil)",
      "message=\(game.message)",
    ].joined(separator: " ")
    throw OkapiJourneyFailure.selectionBudget(stage: stage, details: details)
  }

  fileprivate func okapiAdmitControlledHostile() throws -> ActorIdentity {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    try #require(source.ship.id == "SH029" && source.ship.name == "Okapi")
    try #require(source.ship.catalogue.primaryRole == .trader)
    try #require(source.contract.purchasePolicy == .blueprintFabrication)
    try #require(EMPState.hasSupportedCrew(source.ship))
    let context = try #require(game.gameplayContext())
    try #require(context.system.galaxy == 0 && context.system.system == 69 && context.government == 4)
    let position = context.anchors.arrival * 0.6 + context.anchors.station.position * 0.4
    try #require(source.permitsAmbientTrader(context: context, position: position))
    let stock = try #require(NPCResources.stock(source.performance))
    var npc = NPCState(role: .trader, origin: context.system, destination: context.system, resources: stock)
    npc.intention = .engage(context.player.identity)
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    let request = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: 9001, member: 0, producer: .ambient),
      population: .civilian, hull: .cobra, position: position, orientation: .init(),
      velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil, priority: .ordinary,
      catalogueShipID: source.ship.id)
    try #require(OriginalFleetRuntimeHullSource.matchesAmbientTrader(request, context: context))
    let receipts = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: true)], intents: []))
    let receipt = try #require(receipts.first)
    try #require(receipts.count == 1 && receipt.refusal == nil)
    let actor = try #require(receipt.actor)
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    try #require(body.physical?.catalogueShipID == source.ship.id && body.physical?.npc?.resources == stock)
    try #require(body.energy == source.performance.energy)
    return actor
  }
}

private struct OkapiDisableEvidence: Sendable, CustomStringConvertible {
  var firstActor: String?
  var lastActor: String?
  var firstActorLaser: String?
  var beam: String?
  var firstIncoming: String?
  var firstFire: String?
  var firstGate: String?
  var firstCharge: String?
  var firstTerminal: String?
  var firstRelease: String?
  var firstPulse: String?

  var description: String {
    [
      "actorStart [\(firstActor ?? "none")]",
      "actorEnd [\(lastActor ?? "none")]",
      "actorLaser [\(firstActorLaser ?? "none")]",
      "beam [\(beam.flatMap { $0.isEmpty ? nil : $0 } ?? "none")]",
      "incoming [\(firstIncoming ?? "none")]",
      "fire [\(firstFire ?? "none")]",
      "gate [\(firstGate ?? "none")]",
      "charge [\(firstCharge ?? "none")]",
      "terminal [\(firstTerminal ?? "none")]",
      "release [\(firstRelease ?? "none")]",
      "pulse [\(firstPulse ?? "none")]",
    ].joined(separator: " ")
  }
}

private enum OkapiJourneyFailure: Error {
  case departureBudget, toolSelection, bankBudget
  case selectionBudget(stage: String, details: String)
  case disableBudget(OkapiDisableEvidence)
  case crewDepartureBudget, scoopBudget, receivingType, payment
  case cutBudget(String)
}


private enum OkapiExteriorStep { case advance, phaseChanged, facingHull }

private struct OkapiCutSurfaceApproach {
  let previous: WreckSectionIdentity
  let points: [Vector3]
  var index = 0
}

/// Waypoints are pilot intent only. Actual flight, collision and target admission own every step.
private func okapiExteriorWaypoints(
  from position: Vector3, section: SalvageSectionProfile, hullRadius: Double, playerRadius: Double
) -> [Vector3] {
  let clearance = max(120, 2 * playerRadius)
  let radius = (hullRadius + playerRadius + clearance + 1) / cos(.pi / 12)
  let start = position.unit
  let end = (section.localPosition + section.normal.unit * radius).unit
  let angle = acos(max(-1, min(1, start.dot(end))))
  var axis = start.cross(end).unit
  if axis.length < 1e-9 {
    axis = start.cross(abs(start.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)).unit
  }
  let steps = max(1, Int(ceil(angle / (.pi / 6))))
  return (0...steps).map { step in
    let theta = angle * Double(step) / Double(steps)
    return (start * cos(theta) + axis.cross(start) * sin(theta)
      + axis * (axis.dot(start) * (1 - cos(theta)))) * radius
  }
}

@Test func okapiExteriorPilotWaypointsEncloseTheActualHullAndPreserveBoundedArcs() throws {
  let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH029"))
  let section = try #require(profile.sections.first { $0.structural })
  let hullRadius = try #require(profile.mesh.vertices.map(\.length).max())
  let playerRadius = try #require(Game(executive: false).commander.playerMesh.vertices.map(\.length).max())
  let points = okapiExteriorWaypoints(from: section.normal * -500, section: section,
    hullRadius: hullRadius, playerRadius: playerRadius)
  #expect((2...7).contains(points.count))
  let required = hullRadius + playerRadius + max(120, 2 * playerRadius)
  for (a, b) in zip(points, points.dropFirst()) {
    #expect(a.finite && b.finite)
    #expect((a + b).length * 0.5 > required)
    #expect(a.unit.dot(b.unit) >= cos(.pi / 6) - 1e-12)
  }
}
