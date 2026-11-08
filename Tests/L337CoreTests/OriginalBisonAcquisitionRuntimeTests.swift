import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

/// Controlled hostile birth is a unit input; the kill, payment, arrival and crew must be real.
struct OriginalBisonAcquisitionRuntimeTests {
  @Test(arguments: ["SH005", "SH006"])
  func controlledNativeKillAloneCannotBuyOrPersistABlueprint(shipID: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let initial = try paidStarterGame(recovery: false)
    let runtime = GameRuntime(game: initial, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    await runtime.key("0")
    try await runtime.bisonDepartToAllowedRegion()
    await runtime.enableStationDefenceDiagnostics()
    let actor = try await runtime.bisonAdmitControlledHostile(shipID)
    try await runtime.bisonSelect(actor)
    try await runtime.bisonEarnActualMilestone(shipID, actor: actor)
    await runtime.setControls(Controls())
    try await ScriptProcurementFixture.dock(runtime)
    try #require(await runtime.snapshot().nativeMainStationDockEvidenceIsCurrent)
    try await openReview(runtime, shipID: shipID)
    let before = await runtime.snapshot()
    try #require(before.commander.system == 69 && before.nativeMainStationDockEvidenceIsCurrent)
    let proof = try #require(before.commander.scriptState.savedFleetDiscovery?.entries[shipID]?.milestone)
    try #require(proof.kind == .playerDestruction && proof.actor == actor)
    #expect(before.commander.fleetBlueprintAcquisition(for: shipID) == nil)
    let quote = try #require(before.shipTradeQuote)
    #expect(!quote.allowed && quote.issues.contains { $0.contains("blueprint") })
    let files = try bundle(storage.directory)
    await runtime.key("right")
    let review = await runtime.snapshot()
    let inputs = await runtime.bisonControlValues()
    await runtime.key("return")
    assertRefusedTransaction(before: review, after: await runtime.snapshot())
    #expect(await runtime.bisonControlValues() == inputs)
    #expect(try bundle(storage.directory) == files)
    try await runtime.save(to: storage.url)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    #expect(saved.shipID == "SH029" && saved.fleetBlueprintAcquisition(for: shipID) == nil)
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot().commander
    #expect(restored == saved && restored.fleetBlueprintAcquisition(for: shipID) == nil)
    #expect(restored.scriptState.savedFleetDiscovery?.entries[shipID]?.milestone == proof)
  }

  @Test(arguments: ["SH005", "SH006"])
  func paidEMPActualEmptySectionCutScoopAndPaidFabricationPersist(shipID: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = GameRuntime(game: try paidStarterGame(recovery: true), saveURL: storage.url)
    try await runtime.save(to: storage.url)
    await runtime.key("3")
    for axis in EMPModuleAxis.allCases {
      for grade in 1...3 {
        let before = await runtime.snapshot()
        let module = try #require(before.currentEMPPlayerModule())
        let context = try before.empModulePurchaseContext(module: module.id, axis: axis)
        let receipt = try await runtime.purchaseEMPModuleUpgrade(context)
        let after = await runtime.snapshot()
        #expect(receipt.after.value(for: axis) == grade && receipt.paidPrice > 0)
        #expect(after.commander.credits == before.commander.credits - receipt.paidPrice)
        #expect(after.currentEMPPlayerModule()?.empBank?.remaining == 0)
      }
    }
    await runtime.key("0")
    try await runtime.bisonEarnBank()
    try await runtime.bisonDepartToAllowedRegion()
    await runtime.enableStationDefenceDiagnostics()
    let actor = try await runtime.bisonAdmitControlledHostile(shipID)
    try await runtime.bisonSelect(actor)
    try await runtime.bisonSelectTool(.empPirateBlaster)
    try await runtime.bisonDisableWithActualEMP(shipID, actor: actor)
    #expect(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: shipID) == nil)
    let empty = try await runtime.bisonWaitForEmptyHull(actor)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    try await runtime.bisonSelect(empty)
    let lot = try await runtime.bisonCutActualSection(source: actor)
    #expect(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: shipID) == nil)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    let pendingGame = await runtime.snapshot()
    let fragmentBody = try #require(pendingGame.bodies.first {
      $0.physical?.payload == .salvage(lot)
    })
    let fragment = try #require(fragmentBody.physical?.identity)
    let pendingLot = try #require(pendingGame.currentSalvageLot(for: fragmentBody))
    try #require(pendingLot.identity == lot)
    try await runtime.bisonSelect(fragment)
    try await runtime.bisonScoopActualSample(shipID, lot: lot)
    let received = await runtime.snapshot()
    let proof = try #require(received.commander.fleetBlueprintAcquisition(for: shipID))
    #expect(proof.source == actor && proof.section == lot.section && proof.receivedMassKg >= 50)
    #expect(received.commander.fleetBlueprintAcquisition(for: shipID == "SH005" ? "SH006" : "SH005") == nil)
    var missingSource = received.commander
    missingSource.savedEMPState = nil
    #expect(missingSource.fleetBlueprintAcquisition(for: shipID) == nil)
    var staleStorage = received.commander
    staleStorage.savedAlienStorageReference = nil
    #expect(staleStorage.fleetBlueprintAcquisition(for: shipID) == nil)
    var foreignOwner = received.commander
    foreignOwner.savedEquipmentPurchaseHistory = .init(owner: UUID())
    #expect(foreignOwner.fleetBlueprintAcquisition(for: shipID) == nil)
    var freePurchase = received.commander
    let history = try #require(freePurchase.equipmentPurchaseHistory)
    let weapon = try #require(freePurchase.savedEMPState?.records[actor]?.weapon.id)
    let unpaid = history.paid.map { receipt in
      guard receipt.binding.request.newItem == weapon else { return receipt }
      let old = receipt.binding
      let snapshot = old.snapshot
      return EquipmentPaidPurchaseReceipt(
        owner: receipt.owner, node: receipt.node,
        binding: .init(
          request: old.request,
          snapshot: .init(owner: snapshot.owner, activeHull: snapshot.activeHull,
            revision: snapshot.revision, funds: Int.max, items: snapshot.items),
          historyRevision: old.historyRevision, graphRevision: old.graphRevision,
          lineage: old.lineage))
    }
    freePurchase.savedEquipmentPurchaseHistory = .init(
      owner: history.owner, revision: history.revision, paid: unpaid, legacy: history.legacy)
    #expect(freePurchase.fleetBlueprintAcquisition(for: shipID) == nil)
    var lostCrew = received.commander
    lostCrew.savedEMPState?.records[actor]?.lostCrewCount = 1
    #expect(lostCrew.fleetBlueprintAcquisition(for: shipID) == nil)
    await runtime.setControls(Controls())
    try await ScriptProcurementFixture.dock(runtime)
    // Sell the actual received structural commodity through the ordinary market UI.
    let commodity = try await runtime.bisonReceivedCommodity(shipID)
    await runtime.key("7")
    await runtime.key("market-sell")
    for _ in 0..<17 {
      if await runtime.snapshot().selection == commodity.rawValue { break }
      await runtime.key("down")
    }
    try #require(await runtime.snapshot().selection == commodity.rawValue)
    for _ in 0..<100 {
      if await runtime.snapshot().commander.cargo[commodity.rawValue] == 0 { break }
      await runtime.key("left")
    }
    let sold = await runtime.snapshot()
    try #require(sold.commander.cargo[commodity.rawValue] == 0)
    #expect(sold.commander.fleetBlueprintAcquisition(for: shipID) == proof)
    // A second real paid-EMP/empty-cut/scoop intake is required, never a cloned receipt.
    await runtime.key("0")
    try await runtime.bisonDepartToAllowedRegion()
    try await runtime.bisonEarnBank()
    let secondActor = try await runtime.bisonAdmitControlledHostile(shipID)
    try #require(secondActor != actor)
    try await runtime.bisonSelect(secondActor)
    try await runtime.bisonSelectTool(.empPirateBlaster)
    try await runtime.bisonDisableWithActualEMP(shipID, actor: secondActor)
    let secondEmpty = try await runtime.bisonWaitForEmptyHull(secondActor)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    try await runtime.bisonSelect(secondEmpty)
    let secondLot = try await runtime.bisonCutActualSection(source: secondActor)
    try #require(secondLot.section != lot.section)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    let secondPending = await runtime.snapshot()
    let secondBody = try #require(secondPending.bodies.first { $0.physical?.payload == .salvage(secondLot) })
    let secondFragment = try #require(secondBody.physical?.identity)
    try await runtime.bisonSelect(secondFragment)
    try await runtime.bisonScoopActualSample(shipID, lot: secondLot)
    let twice = await runtime.snapshot()
    let state = try #require(twice.commander.alienStorageState?.current)
    let intakes = try #require(state.salvage.receivedStructure[shipID])
    let firstIntake = try #require(intakes.first { $0.item.identity == lot })
    let secondIntake = try #require(intakes.first { $0.item.identity == secondLot })
    guard case .collected(let firstReceipt) = firstIntake.record.state,
      case .collected(let secondReceipt) = secondIntake.record.state
    else { throw SaveError.invalidCommander }
    try #require(firstReceipt.at < secondReceipt.at && firstReceipt.operation != secondReceipt.operation)
    // Removing one source from a query-only negative copy cannot manufacture the other.
    let originalEMP = twice.commander.savedEMPState
    var secondOnly = twice.commander
    secondOnly.savedEMPState?.records.removeValue(forKey: actor)
    let secondProof = try #require(secondOnly.fleetBlueprintAcquisition(for: shipID))
    try #require(secondProof.source == secondActor && secondProof.section == secondLot.section
      && secondProof.collection == secondReceipt.operation && secondProof.receivedMassKg >= 50)
    #expect(twice.commander.savedEMPState == originalEMP)
    #expect(twice.commander.fleetBlueprintAcquisition(for: shipID) == proof)
    let world = state.snapshot
    let reversedWorld = AlienStorageSnapshot(
      owner: world.owner, revision: world.revision, worldRevision: world.worldRevision,
      world: world.world.reversed(), sources: world.sources, attachments: world.attachments,
      upgrades: world.upgrades, receipts: world.receipts, commands: world.commands)
    try #require(reversedWorld == world)
    var reordered = twice.commander
    try reordered.replaceAlienStorage(with: reversedWorld)
    #expect(reordered == twice.commander)
    #expect(reordered.fleetBlueprintAcquisition(for: shipID) == proof)
    #expect(twice.commander.alienStorageState?.current.snapshot == world)
    await runtime.setControls(Controls())
    try await runtime.save(to: storage.url)
    do {
      let replay = GameRuntime(game: Game(executive: false), saveURL: storage.url)
      try await replay.load(from: storage.url, persistMigrations: false)
      let coldTwice = await replay.snapshot()
      #expect(coldTwice.commander.fleetBlueprintAcquisition(for: shipID) == proof)
      let coldIntakes = try #require(coldTwice.commander.alienStorageState?.current.salvage.receivedStructure[shipID])
      #expect(coldIntakes.map { $0.record.id } == intakes.map { $0.record.id })
      #expect(coldIntakes.map { $0.record } == intakes.map { $0.record })
      #expect(coldIntakes.map { $0.item.identity } == intakes.map { $0.item.identity })
    }
    try await ScriptProcurementFixture.dock(runtime)
    await runtime.key("8")
    try await ScriptProcurementFixture.travel(runtime, path: [69, 0], verifyDeparture: true)
    try await openReview(runtime, shipID: shipID)
    let below = await runtime.snapshot()
    try #require(below.commander.system == 0 && below.nativeMainStationDockEvidenceIsCurrent)
    #expect(below.shipTradeQuote?.allowed == false)
    #expect(below.shipTradeQuote?.issues.contains { $0.contains("TL") } == true)
    await runtime.key("return")
    await runtime.key("escape")
    await runtime.key("escape")
    await runtime.procurementRefuel()
    try await ScriptProcurementFixture.travel(runtime, path: [0, 185, 7], verifyDeparture: true)
    try await openReview(runtime, shipID: shipID)
    let arrival = await runtime.snapshot()
    try #require(arrival.commander.system == 7 && arrival.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrival.commander.fleetBlueprintAcquisition(for: shipID) == proof)
    try #require(arrival.shipTradeQuote?.allowed == true)
    let files = try bundle(storage.directory)
    let intake = try #require(arrival.commander.alienStorageState?.current.salvage.receivedStructure[shipID]?.first {
      if case .collected(let receipt) = $0.record.state {
        return receipt.operation == proof.collection && $0.item.identity.section == proof.section
      }
      return false
    })
    let replayControls = await runtime.bisonControlValues()
    do {
      try await runtime.scriptCommand { candidate in
        let current = try #require(candidate.commander.alienStorageState?.current)
        let hull = try #require(candidate.commander.hullInstanceID)
        let replay = try NativeSalvageCollectionMutation(
          snapshot: current.snapshot, record: intake.record.id, lot: pendingLot,
          hull: hull, at: candidate.commander.flightSimulation.physicalTime,
          cargo: candidate.commander.cargo)
        try candidate.commander.replaceAlienStorage(with: replay.snapshot)
        candidate.commander.cargo = replay.cargo
      }
      Issue.record("An actual collected structural record must refuse a second receiving")
    } catch {
      #expect(error as? AlienStorageError == .invalidJoin)
    }
    let replayRefused = await runtime.snapshot()
    assertRefusedTransaction(before: arrival, after: replayRefused)
    #expect(replayRefused.commander.fleetBlueprintAcquisition(for: shipID) == proof)
    #expect(await runtime.bisonControlValues() == replayControls)
    await runtime.key("return")
    #expect(await runtime.snapshot().commander == arrival.commander)
    #expect(try bundle(storage.directory) == files)
    await runtime.key("return")
    await runtime.key("right")
    let review = await runtime.snapshot()
    let quote = try #require(review.shipTradeQuote)
    try #require(quote.allowed && review.showroom.confirmTrade)
    let controls = await runtime.bisonControlValues()
    let diagnostic = await runtime.bisonObservePublicationRefusal()
    try storage.blockWriter()
    await runtime.key("return")
    assertRefusedTransaction(before: review, after: await runtime.snapshot())
    #expect(await runtime.bisonControlValues() == controls)
    try #require(diagnostic.detail()?.contains("publication=storeWrite,") == true)
    #expect(try bundle(storage.backup) == files)
    #expect(try Data(contentsOf: storage.directory) == Data("blocked save directory".utf8))
    try storage.restoreWriter()
    #expect(try bundle(storage.directory) == files)
    await runtime.key("return")
    let bought = await runtime.snapshot()
    try #require(bought.commander.shipID == shipID && bought.commander.valid)
    #expect(bought.commander.credits == quote.balance)
    #expect(bought.commander.fleetBlueprintAcquisition(for: shipID) == proof)
    let previous = try #require(review.commander.equipmentInventory)
    let current = try #require(bought.commander.equipmentInventory)
    #expect(current.owner == previous.owner && current.activeHull != previous.activeHull)
    #expect(Set(current.items.map(\.id)) == Set(previous.items.map(\.id)))
    for old in previous.items {
      let item = try #require(current.items.first { $0.id == old.id })
      #expect(item.node == old.node && item.provenance == old.provenance && item.component == old.component)
    }
    let needed = shipID == "SH005" ? 11 : 13
    try #require(bought.commander.nativeCrewMissing == needed && bought.nativeCrewPeople.count == 13)
    await runtime.key("escape")
    await runtime.key("escape")
    await runtime.key("0")
    try #require(await runtime.snapshot().docked)
    let beforeCrew = await runtime.snapshot().commander
    try await NativeCrewTestFixture.fill(runtime)
    let crewed = await runtime.snapshot()
    #expect(crewed.commander.credits == beforeCrew.credits - needed * 2000)
    #expect(crewed.commander.assignedNativeCrew.count == needed)
    #expect(Set(crewed.commander.assignedNativeCrew.map(\.identity)).count == needed)
    try #require(crewed.commander.nativeCrewMissing == 0 && crewed.commander.valid)
    await runtime.key("0")
    let launched = await runtime.snapshot()
    try #require(!launched.docked && launched.screen.isFlight && launched.energy > 0)
    try await runtime.save(to: storage.url)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: storage.url)
    #expect(saved == launched.commander && saved.fleetBlueprintAcquisition(for: shipID) == proof)
    let cold = GameRuntime(game: Game(executive: false), saveURL: storage.url)
    try await cold.load(from: storage.url, persistMigrations: false)
    let restored = await cold.snapshot().commander
    #expect(restored == saved && restored.nativeCrewMissing == 0)
    #expect(restored.fleetBlueprintAcquisition(for: shipID) == proof)
  }

  private func paidStarterGame(recovery: Bool) throws -> Game {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    try OriginalDetailedHullStage.requireRuntime(source.ship.id)
    let current = try #require(OriginalFleetR3Data.contract(for: source.ship.id))
    let fitting = try #require(current.fitting)
    try #require(source.ship.id == "SH029" && source.ship.name == "Okapi")
    try #require(source.performance == current.performance && source.ship.game == current.performance)
    try #require(source.performance.workTools?.contains(.salvageCutter) == true)
    try #require(fitting.compatibleUtilities.contains("salvageCutter")
      && fitting.compatibleUtilities.contains("cargoScoop") && !fitting.roleKitIncluded)
    try #require(fitting.equipmentUnits == 20 && fitting.utilityMounts == 3)
    try #require(current.accommodation?.operatingCrew == 1
      && current.accommodation?.intrinsicCrewPlaces == 1)
    // Root-authorised controlled initial hull, before any inventory/history. No earned
    // acquisition, live transfer, included role kit or G1 Okapi helper is substituted.
    var initial = Game(executive: false)
    try #require(initial.commander.equipmentInventory == nil
      && initial.commander.equipmentPurchaseHistory == nil
      && initial.commander.equipmentOwnerID == nil && initial.commander.hullInstanceID == nil)
    initial.commander.shipID = source.ship.id
    initial.commander.fuel = source.performance.fuel
    initial.energy = source.performance.energy
    initial.frontShield = source.performance.shield
    initial.rearShield = source.performance.shield
    initial.screen = .status
    initial.commander.galaxy = 0
    initial.commander.system = 69
    initial.selectedSystem = 69
    initial.market = MarketItem.at(initial.currentSystem)
    initial.commander.credits = 20_000_000
    try #require(initial.commander.shipID == "SH029" && initial.currentSystem.name == "Verasel")
    try #require(initial.currentSystem.technology == 16 && initial.currentSystem.government == 4)
    try #require(!initial.commander.unlimitedCash && !initial.commander.unlimitedFuel)
    try initial.commander.prepareEquipment(legacy: false)
    try #require(initial.commander.nativeCrewMissing == 0)
    try #require(initial.commander.fleetBlueprintAcquisition(for: "SH029") == nil)
    try initial.prepareG03FlightEquipment()
    // Pulse came from paid G03 preparation; the remaining ancestors must also be paid.
    for name in [
      "Military Laser", ShieldBooster.mining.equipmentName, ShieldBooster.beam.equipmentName,
      ShieldBooster.military.equipmentName,
    ] {
      let item = try #require(Equipment.all.first { $0.name == name })
      let before = initial.commander
      let history = try #require(before.equipmentPurchaseHistory)
      let quote = try initial.quoteEquipmentPurchase(item)
      try #require(quote.purchase.requiredDebit > 0)
      let equipmentPurchased = try initial.applyEquipmentPurchase(quote)
      try #require(equipmentPurchased)
      let paid = try #require(initial.commander.equipmentPurchaseHistory)
      try #require(initial.commander.credits == before.credits - quote.purchase.requiredDebit)
      try #require(paid.paid.count == history.paid.count + 1)
      try #require(paid.paid.last?.binding.request == quote.request)
    }
    try #require(initial.commander.laser(on: .front) == .military)
    try #require(initial.commander.shieldBooster == .military)
    if recovery {
      for name in [Equipment.empPirateBlaster, "Salvage Cutter", "Fuel Scoops", "Targeting: Salvage Module"] {
        let item = try #require(Equipment.all.first { $0.name == name })
        let before = initial.commander
        let quote = try initial.quoteEquipmentPurchase(item)
        try #require(quote.purchase.requiredDebit > 0)
        let equipmentPurchased = try initial.applyEquipmentPurchase(quote)
        try #require(equipmentPurchased)
        #expect(initial.commander.credits == before.credits - quote.purchase.requiredDebit)
        #expect(initial.commander.equipmentPurchaseHistory?.paid.last?.binding.request == quote.request)
      }
    }
    try #require(initial.commander.commonEquipmentUnits <= fitting.equipmentUnits)
    try #require(initial.commander.passengerFit?.allowed == true)
    let inventory = try #require(initial.commander.equipmentInventory)
    try inventory.validate(context: EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: initial.commander.nativePerformance))
    try OriginalFleetR3Fitting.validateUtilities(inventory, ship: initial.commander.ship)
    if recovery {
      for utility in [ComponentUtility.empPirateBlaster, .salvageCutter, .fuelScoops] {
        try #require(initial.commander.fittedEquipment(at: .utility(utility)) != nil)
      }
    }
    try #require(initial.energy.isFinite && initial.energy > 0
      && initial.energy <= initial.commander.performance.energy)
    try NativeSaveTestFixture.prepareCurrentPolicy(&initial)
    return initial
  }

  private func openReview(_ runtime: GameRuntime, shipID: String) async throws {
    await runtime.key("6")
    await runtime.key("/")
    for character in shipID { await runtime.key(String(character)) }
    await runtime.key("return")
    try #require(await runtime.snapshot().showroom.selection == shipID)
    await runtime.key("return")
    try #require(await runtime.snapshot().showroom.trading)
  }

  private func assertRefusedTransaction(before: Game, after: Game) {
    #expect(after.commander == before.commander)
    #expect(after.bodies == before.bodies && after.celestials == before.celestials)
    #expect(after.screen == before.screen && after.paused == before.paused)
    #expect(after.docked == before.docked && after.dockedAtMainStation == before.dockedAtMainStation)
    #expect(after.time == before.time && after.jumpCountdown == before.jumpCountdown)
    #expect(after.energy == before.energy && after.frontShield == before.frontShield)
    #expect(after.rearShield == before.rearShield && after.laserHeat == before.laserHeat)
    #expect(after.fireCooldown == before.fireCooldown && after.speed == before.speed)
    #expect(after.pitch == before.pitch && after.yaw == before.yaw && after.roll == before.roll)
    #expect(after.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    #expect(after.inventoryContextEpoch == before.inventoryContextEpoch)
    #expect(after.pendingNativeStationDock == nil && before.pendingNativeStationDock == nil)
    #expect(showroomValues(after.showroom) == showroomValues(before.showroom))
  }

  private func showroomValues(_ s: ShowroomState) -> [String] {
    [s.sort.rawValue, String(s.trading), String(s.confirmTrade), String(s.tradeScroll),
     String(describing: s.previousScreen), s.selection, s.baseline, String(s.baselineUsesCurrent),
     s.query, String(s.searching), String(s.detail), String(s.compare), String(s.rotationPaused),
     String(s.angle), String(s.scroll), String(s.listOffset), String(s.sourceProfiles),
     String(s.profileIndex)]
  }

  /// Only the task-owned bundle is read. Exhaustion and nonregular entries fail closed.
  private func bundle(_ directory: URL) throws -> [String: Data] {
    let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
    var pending = [directory]
    var result: [String: Data] = [:]
    var count = 0
    var total = 0
    while let parent = pending.popLast() {
      let children = try FileManager.default.contentsOfDirectory(
        at: parent, includingPropertiesForKeys: keys)
      count += children.count
      try #require(count <= 128)
      for file in children {
        let path = String(file.path.dropFirst(directory.path.count + 1))
        try #require(path.split(separator: "/").count <= 8)
        let facts = try file.resourceValues(forKeys: Set(keys))
        try #require(facts.isSymbolicLink != true)
        if facts.isDirectory == true {
          result["directory:" + path] = Data()
          pending.append(file)
          continue
        }
        try #require(facts.isRegularFile == true)
        let size = try #require(facts.fileSize)
        try #require(size <= 8 * 1024 * 1024 && size >= 0)
        total += size
        try #require(total <= 32 * 1024 * 1024)
        let bytes = try Data(contentsOf: file)
        try #require(bytes.count == size)
        result["file:" + path] = bytes
      }
    }
    return result
  }
}

/// A genuine earned checkpoint for the crew exchange test, using one runtime and owner.
/// Its controlled hostile birth is not a claim about natural encounter sampling.
enum NativeEarnedPeregrineFixture {
  static func runtime(storage: NativeStationTestStorage) async throws -> GameRuntime {
    let runtime = try await NativeCrewTestFixture.runtime(
      storage: storage, initialCredits: 20_000_000)
    let initial = await runtime.snapshot()
    let owner = try #require(initial.commander.equipmentOwnerID)
    let hull = try #require(initial.commander.hullInstanceID)
    try #require(initial.commander.shipID == "SH013" && initial.commander.valid)
    try #require(initial.commander.fleetBlueprintAcquisition(for: "SH025") == nil)
    try await NativeCrewTestFixture.fill(runtime)
    let crew = await runtime.snapshot().commander.assignedNativeCrew.map(\.identity)
    try #require(crew.count == 5)
    try await ScriptProcurementFixture.travel(runtime, path: [7, 185, 0, 69], verifyDeparture: true)
    let shop = await runtime.snapshot()
    try #require(shop.nativeMainStationDockEvidenceIsCurrent && shop.currentSystem.technology == 16)
    // Basic navigation is existing standard hardware, not a purchasable shop upgrade.
    let navigation = try #require(shop.commander.fittedEquipment(at: .navigation))
    let navigationNode = try #require(EquipmentRuntimeCatalog.node(for: NavigationTier.basic.equipmentName))
    let navigationPolicy = try #require(EquipmentRuntimeCatalog.graph.nodes.first { $0.id == navigationNode })
    let foundationHistory = try #require(shop.commander.equipmentPurchaseHistory)
    try #require(navigation.node == navigationNode && navigation.provenance == .standard)
    try #require(navigation.location?.hullInstanceID == hull && shop.commander.navigationTier == .basic)
    try #require(navigationPolicy.policy == .standardFoundation && foundationHistory.owner == owner)
    try #require(!foundationHistory.paid.contains { $0.node == navigationNode })
    // Every additional upgrade is paid at this attained shop with its full ancestry.
    for name in [
      TargetingTier.basic.equipmentName, TargetingTier.advanced.equipmentName,
      TargetingTier.docking.equipmentName, ShieldBooster.pulse.equipmentName,
      "Extra Energy Unit", "Military Laser", ShieldBooster.mining.equipmentName,
      ShieldBooster.beam.equipmentName, ShieldBooster.military.equipmentName,
      Equipment.empPirateBlaster, "Salvage Cutter", "Fuel Scoops",
      "Targeting: Salvage Module",
    ] {
      try await runtime.scriptCommand { game in
        try #require(game.docked && game.nativeMainStationDockEvidenceIsCurrent)
        let item = try #require(Equipment.all.first { $0.name == name })
        try #require(game.equipmentAvailable(item))
        let before = game.commander
        let history = try #require(before.equipmentPurchaseHistory)
        let quote = try game.quoteEquipmentPurchase(item)
        try #require(quote.purchase.requiredDebit > 0)
        let equipmentPurchased = try game.applyEquipmentPurchase(quote)
        try #require(equipmentPurchased)
        let paid = try #require(game.commander.equipmentPurchaseHistory)
        try #require(game.commander.credits == before.credits - quote.purchase.requiredDebit)
        try #require(paid.paid.count == history.paid.count + 1)
        try #require(paid.paid.last?.binding.request == quote.request)
        try #require(game.commander.equipmentOwnerID == owner && game.commander.hullInstanceID == hull)
      }
    }
    let paidSetup = await runtime.snapshot()
    try #require(paidSetup.commander.fittedEquipment(at: .navigation) == navigation)
    try #require(paidSetup.commander.navigationTier == .basic)
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
    await runtime.key("0")
    try await runtime.bisonEarnBank()
    try await runtime.bisonDepartToAllowedRegion()
    await runtime.enableStationDefenceDiagnostics()
    let actor = try await runtime.peregrineAdmitControlledHostile()
    try await runtime.bisonSelect(actor)
    try await runtime.bisonSelectTool(.empPirateBlaster)
    try await runtime.bisonDisableWithActualEMP("SH025", actor: actor)
    try #require(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: "SH025") == nil)
    let empty = try await runtime.bisonWaitForEmptyHull(actor)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    try await runtime.bisonSelect(empty)
    let lot = try await runtime.bisonCutActualSection(source: actor)
    try #require(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: "SH025") == nil)
    await runtime.key(FlightControlInput.token(for: .releaseHold))
    let pending = await runtime.snapshot()
    let fragment = try #require(pending.bodies.first { $0.physical?.payload == .salvage(lot) }?.physical?.identity)
    try await runtime.bisonSelect(fragment)
    try await runtime.bisonScoopActualSample("SH025", lot: lot)
    let proof = try #require(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: "SH025"))
    try #require(proof.source == actor && proof.section == lot.section && proof.receivedMassKg >= 50)
    await runtime.setControls(Controls())
    try await ScriptProcurementFixture.dock(runtime)
    await runtime.procurementRefuel()
    try await ScriptProcurementFixture.travel(runtime, path: [69, 0, 185, 7], verifyDeparture: true)
    for id in crew { try await NativePeopleTestFixture.confirm(runtime, row: .crew(.disembark(id))) }
    let target = try #require(ShipCatalogue.ship("SH025"))
    let targetPerformance = try #require(target.game)
    // Show the real overfull-tank refusal, then consume fuel by ordinary flown legs.
    await runtime.procurementRefuel()
    let full = await runtime.snapshot()
    let fuelQuote = try #require(full.shipTradeQuote(for: target))
    try #require(!fuelQuote.allowed && fuelQuote.issues.contains { $0.contains("excess fuel") })
    try #require(full.commander.fuel > targetPerformance.fuel)
    try await NativeCrewTestFixture.fill(runtime)
    try #require(Set(await runtime.snapshot().commander.assignedNativeCrew.map(\.identity)) == Set(crew))
    try await ScriptProcurementFixture.travel(runtime, path: [7, 185, 7], verifyDeparture: true)
    for id in crew { try await NativePeopleTestFixture.confirm(runtime, row: .crew(.disembark(id))) }
    let ready = await runtime.snapshot()
    try #require(ready.commander.fuel <= targetPerformance.fuel)
    let projected = try ready.commander.projectedEquipmentTransfer(to: target.id)
    let destination = try #require(ready.knownSystems.prefix(256).first {
      $0.id != 256 && $0.id != ready.commander.system
        && ready.currentSystem.distance(to: $0) > projected.fullTankJumpDistance
        && ready.currentSystem.distance(to: $0) <= ready.commander.maximumJumpDistance
    })
    await runtime.selectSystem(x: destination.x, y: destination.y)
    try await runtime.scriptCommand { game in
      game.openNavigation()
      try #require(game.screen == .navigation)
      // The direct alternative comes from the actual planner, never an injected NavigationPlan.
      let index = try #require(game.navigationOptions.firstIndex {
        $0.plan.path == [game.commander.system, destination.id]
      })
      game.navigationSelection = index
      game.navigationKey("return")
      try #require(game.commander.navigationPlan?.path == [game.commander.system, destination.id])
    }
    let routed = await runtime.snapshot()
    let routeQuote = try #require(routed.shipTradeQuote(for: target))
    try #require(!routeQuote.allowed && routeQuote.issues.contains { $0.contains("navigation route") })
    try await runtime.scriptCommand { game in
      game.openNavigation()
      try #require(game.screen == .navigation)
      game.navigationKey("c")
      try #require(game.commander.navigationPlan == nil)
    }
    let checkpoint = await runtime.snapshot()
    try #require(checkpoint.commander.shipID == initial.commander.shipID)
    try #require(checkpoint.commander.equipmentOwnerID == owner && checkpoint.commander.hullInstanceID == hull)
    try #require(checkpoint.commander.system == 7 && checkpoint.nativeMainStationDockEvidenceIsCurrent)
    try #require(checkpoint.commander.valid && !checkpoint.commander.unlimitedCash && !checkpoint.commander.unlimitedFuel)
    try #require(checkpoint.commander.assignedNativeCrew.isEmpty)
    try #require(checkpoint.commander.fleetBlueprintAcquisition(for: "SH025") == proof)
    try #require(checkpoint.shipTradeQuote(for: target)?.allowed == true)
    return runtime
  }
}

extension GameRuntime {
  fileprivate func peregrineAdmitControlledHostile() throws -> ActorIdentity {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
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

  fileprivate func bisonControlValues() -> [String] {
    [String(controls.pitch), String(controls.roll), String(controls.yaw), String(controls.throttle),
     String(controls.fire), String(controls.spinContacts), String(controls.spinRecognition),
     String(controls.spinSlower), String(controls.spinFaster)]
  }

  fileprivate func bisonObservePublicationRefusal() -> ScriptRefusalDiagnostic {
    let diagnostic = ScriptRefusalDiagnostic()
    scriptRefusalDiagnostic = diagnostic
    return diagnostic
  }

  fileprivate func bisonSelectTool(_ tool: FlightWorkTool) throws {
    for _ in 0..<4 {
      if game.selectedFlightTool == tool { return }
      key(FlightControlInput.token(for: .changeWeapon))
    }
    throw BisonAcquisitionFailure.toolSelection
  }

  fileprivate func bisonLiveFrame() throws -> Game {
    try #require(game.bodies.count <= 256 && game.screen.isFlight && !game.docked)
    try #require(!game.paused && game.energy > 0)
    let start = game.commander.flightSimulation.physicalTime
    let after = advance(delta: 0.1)
    try #require(after.commander.flightSimulation.physicalTime > start)
    try #require(after.bodies.count <= 256 && after.screen.isFlight && after.energy > 0)
    return after
  }

  fileprivate func bisonEarnBank() throws {
    var input = Controls()
    input.throttle = -1
    setControls(input)
    for _ in 0..<256 {
      let bank = try #require(game.currentEMPPlayerModule()?.empBank)
      if bank.remaining == bank.capacity { return }
      _ = try bisonLiveFrame()
    }
    throw BisonAcquisitionFailure.bankBudget
  }

  fileprivate func bisonDisableWithActualEMP(_ shipID: String, actor: ActorIdentity) throws {
    let epoch = try #require(game.gameplayCombatTrace?.epoch)
    let player = try #require(game.commander.flightSimulation.player)
    var incoming = false
    for _ in 0..<1200 {
      let context = try #require(game.gameplayContext())
      if let disabled = game.commander.savedEMPState?.records[actor] {
        try #require(incoming && disabled.source == actor && disabled.valid)
        try #require(disabled.hull.body.physical?.catalogueShipID == shipID)
        try #require(disabled.weaponOwner == game.commander.equipmentOwnerID)
        try #require(disabled.disableIncident.kind == .emp && disabled.disableIncident.outcome == .hit)
        try #require(disabled.disableIncident.origin.owner == player)
        setControls(Controls())
        return
      }
      if incoming {
        try #require(game.commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: actor, against: player, context: context))
      }
      let start = game.commander.flightSimulation
      let previousDropped = try #require(game.gameplayCombatTrace?.dropped)
      var input = Controls()
      input.throttle = -1
      // A terminal charge or safety stop needs an ordinary release before a fresh press.
      // Keep holding a valid charge; changing saved phase/latch state would bypass input.
      let terminalCharge = game.commander.savedEMPCharge.map { $0.phase != .charging } ?? false
      input.fire = incoming && !terminalCharge && !game.workFireSuspended
      setControls(input)
      let after = try bisonLiveFrame()
      let trace = try #require(after.gameplayCombatTrace)
      try #require(trace.epoch == epoch && trace.incidents.count <= 128)
      if trace.dropped > previousDropped {
        try #require(trace.incidents.first.map { $0.id < start.nextIncident } == true)
      }
      for hit in trace.incidents where hit.id >= start.nextIncident {
        try #require(hit.id < after.commander.flightSimulation.nextIncident)
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
          incoming = true
        }
      }
    }
    setControls(Controls())
    throw BisonAcquisitionFailure.disableBudget
  }

  fileprivate func bisonWaitForEmptyHull(_ source: ActorIdentity) throws -> ActorIdentity {
    setControls(Controls())
    let occupied = try #require(game.commander.savedEMPState?.records[source]?.hull.binding)
    key(FlightControlInput.token(for: .releaseHold))
    try bisonSelect(occupied)
    try bisonSelectTool(.salvageCutter)
    for _ in 0..<600 {
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
      var input = Controls()
      input.fire = game.workGuidance?.holding == true
      setControls(input)
      _ = try bisonLiveFrame()
    }
    setControls(Controls())
    throw BisonAcquisitionFailure.crewDepartureBudget
  }

  fileprivate func bisonCutActualSection(source: ActorIdentity) throws -> SalvageLotIdentity {
    let wreck = try #require(game.commander.savedEMPState?.records[source]?.wreck)
    try bisonSelectTool(.salvageCutter)
    for _ in 0..<1200 {
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
          _ = try bisonLiveFrame()
          return lot
        }
      }
      var input = Controls()
      input.fire = game.workGuidance?.holding == true
      setControls(input)
      _ = try bisonLiveFrame()
    }
    setControls(Controls())
    throw BisonAcquisitionFailure.cutBudget
  }

  fileprivate func bisonScoopActualSample(_ shipID: String, lot: SalvageLotIdentity) throws {
    setControls(Controls())
    for _ in 0..<1200 {
      if let received = game.commander.alienStorageState?.current.salvage.receivedStructure[shipID]?.first(where: {
        $0.item.identity == lot
      }) {
        guard case .collected(let receipt) = received.record.state else { throw SaveError.invalidCommander }
        try #require(receipt.at <= game.commander.flightSimulation.physicalTime
          && received.item.massKg >= 50 && received.item.identity.section == lot.section)
        try #require(game.commander.fleetBlueprintAcquisition(for: shipID) != nil)
        return
      }
      _ = try bisonLiveFrame()
    }
    throw BisonAcquisitionFailure.scoopBudget
  }

  fileprivate func bisonReceivedCommodity(_ shipID: String) throws -> CommodityIdentity {
    let proof = try #require(game.commander.fleetBlueprintAcquisition(for: shipID))
    let intake = try #require(game.commander.alienStorageState?.current.salvage.receivedStructure[shipID]?.first {
      if case .collected(let receipt) = $0.record.state { return receipt.operation == proof.collection }
      return false
    })
    guard case .commodity(let amount) = intake.item.content else {
      throw BisonAcquisitionFailure.receivingType
    }
    return amount.commodity
  }

  fileprivate func bisonDepartToAllowedRegion() throws {
    var input = Controls()
    input.throttle = 1
    setControls(input)
    for _ in 0..<300 {
      try #require(!game.docked && game.screen.isFlight && game.energy > 0 && !game.paused)
      let context = try #require(game.gameplayContext())
      let region = EncounterGeography.region(at: context.player.position, anchors: context.anchors)
      if region == .tradeLane || region == .deepSpace {
        input.throttle = -1
        setControls(input)
        return
      }
      _ = advance(delta: 0.1)
    }
    throw BisonAcquisitionFailure.departureBudget
  }

  fileprivate func bisonAdmitControlledHostile(_ shipID: String) throws -> ActorIdentity {
    let source = try #require(OriginalBisonActivation.source(for: shipID))
    let allocatedSpawn = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSpawn)
    let context = try #require(game.gameplayContext())
    try #require(context.system.galaxy == 0 && context.system.system == 69 && context.government == 4)
    let position = context.anchors.arrival * 0.6 + context.anchors.station.position * 0.4
    try #require(source.ship.catalogue.regions.contains(
      EncounterGeography.region(at: context.player.position, anchors: context.anchors)))
    try #require(source.ship.catalogue.regions.contains(
      EncounterGeography.region(at: position, anchors: context.anchors)))
    let stock = try #require(NPCResources.stock(source.game))
    var npc = NPCState(role: .trader, origin: context.system, destination: context.system,
      resources: stock)
    npc.intention = .engage(context.player.identity)
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    let request = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .ambient),
      population: .civilian, hull: .cobra, position: position, orientation: .init(),
      velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil, priority: .ordinary,
      catalogueShipID: shipID)
    try #require(!game.bodies.contains { $0.physical?.spawnIdentity == request.identity })
    try #require(OriginalBisonActivation.matchesRequest(request, context: context))
    let receipts = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: true)], intents: []))
    let receipt = try #require(receipts.first)
    try #require(receipts.count == 1 && receipt.refusal == nil)
    let actor = try #require(receipt.actor)
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    try #require(body.physical?.catalogueShipID == shipID && body.physical?.npc?.resources == stock)
    try #require(body.energy == source.game.energy)
    try #require(OriginalBisonActivation.matchesNativeBody(body, context: context, commander: game.commander))
    return actor
  }

  fileprivate func bisonSelect(_ actor: ActorIdentity) throws {
    for _ in 0..<128 {
      if game.autoTargetBody?.physical?.identity == actor { return }
      key("tab")
    }
    throw BisonAcquisitionFailure.selectionBudget
  }

  fileprivate func bisonEarnActualMilestone(_ shipID: String, actor: ActorIdentity) throws {
    let epoch = try #require(game.gameplayCombatTrace?.epoch)
    let player = try #require(game.commander.flightSimulation.player)
    var incoming = false
    var militaryHit = false
    for _ in 0..<1200 {
      try #require(game.bodies.count <= 256 && game.screen.isFlight && !game.docked)
      try #require(!game.paused && game.energy > 0 && game.commander.shipID == "SH029")
      let context = try #require(game.gameplayContext())
      try #require(context.player.identity == player)
      if incoming {
        try #require(game.commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: actor, against: player, context: context))
      }
      var input = Controls()
      input.throttle = -1
      input.fire = incoming
      let start = game.commander.flightSimulation
      let previousDropped = try #require(game.gameplayCombatTrace?.dropped)
      setControls(input)
      let after = advance(delta: 0.1)
      let trace = try #require(after.gameplayCombatTrace)
      try #require(trace.epoch == epoch && trace.incidents.count <= 128)
      try #require(after.commander.flightSimulation.physicalTime > start.physicalTime)
      if trace.dropped > previousDropped {
        try #require(trace.incidents.first.map { $0.id < start.nextIncident } == true)
      }
      for hit in trace.incidents where hit.id >= start.nextIncident {
        try #require(hit.id < after.commander.flightSimulation.nextIncident)
        if hit.kind == .laser && hit.outcome == .hit,
          hit.physicalTime > start.physicalTime,
          hit.physicalTime <= after.commander.flightSimulation.physicalTime,
          hit.origin.emissionID >= start.nextEmission,
          hit.origin.emissionID < after.commander.flightSimulation.nextEmission,
          hit.origin.emittedAt > start.physicalTime,
          hit.origin.emittedAt <= after.commander.flightSimulation.physicalTime
        {
          if hit.origin.owner == actor && hit.victim == player {
            let current = try #require(after.gameplayContext())
            try #require(after.commander.crimeLedger.hasCurrentUnlawfulAttack(
              from: actor, against: player, context: current))
            incoming = true
          }
          if incoming && hit.origin.owner == player && hit.victim == actor,
            hit.laser == .military && hit.mount == .front && hit.origin.ordnance == nil
          {
            militaryHit = true
          }
        }
      }
      if let proof = after.commander.scriptState.savedFleetDiscovery?.entries[shipID]?.milestone {
        try #require(NativeFleetDiscoverySave.validateClaims(after.commander))
        try #require(incoming && militaryHit && proof.kind == .playerDestruction)
        try #require(proof.actor == actor && proof.player == player && proof.death?.lawful == true)
        try #require(proof.death?.victim == actor && proof.death?.owner == player)
        try #require(after.energy > 0 && after.commander.valid)
        setControls(Controls())
        return
      }
    }
    setControls(Controls())
    throw BisonAcquisitionFailure.combatBudget
  }
}

private enum BisonAcquisitionFailure: Error {
  case departureBudget, selectionBudget, combatBudget, toolSelection, bankBudget, disableBudget
  case crewDepartureBudget, cutBudget, scoopBudget, receivingType
}
