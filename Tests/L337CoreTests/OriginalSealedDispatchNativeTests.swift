import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

struct OriginalSealedDispatchFixture {
  let files: ScriptFreightFixture
  let pack: ScriptPack
  var save: URL { files.save }
  init() throws {
    files = try ScriptFreightFixture()
    pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledSealedDispatchDirectory)
  }
  func runtime(escapeReady: Bool = false, defaults: Bool = false) async throws -> GameRuntime {
    var game = try ScriptProcurementFixture.freshG03FlightGame(escapeReady: escapeReady)
    try game.prepareG03FlightEquipment()
    if escapeReady {
      let pod = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let equipmentPurchased = try game.applyEquipmentPurchase(game.quoteEquipmentPurchase(pod))
      try #require(equipmentPurchased)
    }
    game.scriptPacks = defaults ? [] : [pack]
    let runtime = GameRuntime(game: game, saveURL: save)
    try await runtime.save(to: save)
    if defaults {
      let errors = await runtime.loadDefaultScriptPacks(
        directory: files.root.appendingPathComponent("installed"))
      try #require(errors.isEmpty)
    }
    await runtime.key("0")
    try await dock(runtime)
    return runtime
  }
  // Near-door framing supplies no station/journey receipt. Real swept entry mints the dock proof.
  @inline(never)
  func dock(_ runtime: GameRuntime) async throws {
    await releaseMainDockApproach(runtime)
    await brakeDockApproach(runtime)
    try await finishMainDockApproach(runtime)
  }

  @inline(never)
  private func releaseMainDockApproach(_ runtime: GameRuntime) async {
    let arriving = await runtime.snapshot()
    if arriving.workGuidance != nil || arriving.workBraking != nil {
      await runtime.key("q")
    }
  }

  @inline(never)
  private func brakeDockApproach(_ runtime: GameRuntime) async {
    var braking = Controls()
    braking.throttle = -1
    await runtime.setControls(braking)
    for _ in 0..<100 {
      if await runtime.snapshot().flightWorldVelocity == Vector3(0, 0, 0) { break }
      _ = await runtime.advance(delta: 0.05)
    }
  }

  @inline(never)
  private func finishMainDockApproach(_ runtime: GameRuntime) async throws {
    await runtime.setControls(Controls())
    let stopped = await runtime.snapshot()
    try #require(stopped.workGuidance == nil && stopped.workBraking == nil)
    try #require(stopped.flightWorldVelocity == Vector3(0, 0, 0))
    await runtime.nativeCommand { game in
      guard Self.frameMainDockDoorway(&game) else { return }
      for _ in 0..<100 where !game.docked { game.tick(delta: 0.1) }
    }
    let game = await runtime.snapshot()
    try #require(game.docked && game.nativeMainStationDockEvidenceIsCurrent)
  }

  @inline(never)
  private static func frameMainDockDoorway(_ game: inout Game) -> Bool {
    guard let station = game.bodies.first(where: { $0.id == 0 && $0.hull == .station }) else {
      return false
    }
    let old = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = old.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = old.orientation.apply(station.entranceUp)
    pose.orientation.z = old.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    return true
  }
  /// Earn a fitting hull before visiting an original mission source. Main-only callers stay unchanged.
  @inline(never)
  func runtime(
    at site: OriginalStationSite, escapeReady: Bool = false, defaults: Bool = false,
    galaxyReady: Bool = false
  ) async throws -> GameRuntime {
    try #require(site != .remoteUtility)
    let storage = NativeStationTestStorage(root: files.root)
    try #require(storage.url == save)
    let runtime = try await NativeOkapiAcquisitionJourneyFixture.purchasedRuntime(storage: storage)
    return try await prepareOwnedDispatchRuntime(
      runtime, at: site, escapeReady: escapeReady, defaults: defaults, galaxyReady: galaxyReady)
  }

  @inline(never)
  private func prepareOwnedDispatchRuntime(
    _ runtime: GameRuntime, at site: OriginalStationSite, escapeReady: Bool, defaults: Bool,
    galaxyReady: Bool
  ) async throws -> GameRuntime {
    let owned = await runtime.snapshot()
    try #require(owned.nativeMainStationDockEvidenceIsCurrent)
    try #require(owned.commander.shipID == "SH029" && owned.commander.nativeCrewMissing == 0)
    try #require(owned.commander.valid && owned.commander.legal == 0)
    try #require(!owned.commander.unlimitedCash && !owned.commander.unlimitedFuel)
    let acquisition = try #require(owned.commander.fleetBlueprintAcquisition(for: "SH029"))
    let owner = try #require(owned.commander.equipmentOwnerID)
    let source = try #require(NativeStationSource.binding(for: site.identity(world: owner)))
    try #require(source.geometry.docking.fits(owned.commander.playerMesh))

    // The salvage journey retains actual captured people. Close their custody through care,
    // preserving the original capture history and paid property before the lawful departure.
    let capturedPeople = try #require(owned.commander.nativePeople)
    let captives = capturedPeople.heldCaptives.map(\.person)
    try #require(!captives.isEmpty)
    try #require(owned.commander.cargo[CommodityIdentity.slaves.rawValue] == captives.count)
    try await NativePeopleTestFixture.confirm(runtime, row: .care(.capturedCrew))
    let cared = await runtime.snapshot()
    let caredPeople = try #require(cared.commander.nativePeople)
    let care = try #require(caredPeople.transfers.last)
    try #require(care.kind == .care && Set(care.members) == Set(captives))
    try #require(care.dock != nil && care.dock == owned.commander.nativeStations?.currentMainDock)
    try #require(caredPeople.heldCaptives.isEmpty && caredPeople.admissions == capturedPeople.admissions)
    try #require(Array(caredPeople.transfers.dropLast()) == capturedPeople.transfers)
    var expectedCargo = owned.commander.cargo
    expectedCargo[CommodityIdentity.slaves.rawValue] -= captives.count
    try #require(cared.commander.cargo == expectedCargo)
    try #require(cared.commander.credits == owned.commander.credits)
    try #require(cared.commander.legal == owned.commander.legal)
    try #require(cared.commander.equipmentInventory == owned.commander.equipmentInventory)
    try #require(cared.commander.equipmentPurchaseHistory == owned.commander.equipmentPurchaseHistory)
    try #require(cared.commander.hullInstanceID == owned.commander.hullInstanceID)
    try #require(cared.commander.savedEMPState == owned.commander.savedEMPState)
    try #require(cared.commander.fleetBlueprintAcquisition(for: "SH029") == acquisition)
    for commodity in [CommodityIdentity.slaves, .narcotics, .firearms] {
      try #require(cared.commander.cargo[commodity.rawValue] == 0)
    }

    // Existing dispatch consumers exercise an empty ordinary hold, then protected-only 1t.
    // Cutting can collect other goods: sell only actual unreserved stock at the genuine
    // main market. Care alone proves removal of people, not removal of incidental goods.
    await runtime.key("7")
    await runtime.key("market-sell")
    try #require(await runtime.snapshot().screen == .sell)
    for commodity in MarketDisplayOrder.commodityIDs {
      let stock = await runtime.snapshot()
      let quantity = stock.commander.sellableCargo(commodity)
      try #require(quantity == stock.commander.cargo[commodity],
        "An existing reservation cannot be sold to prepare the dispatch fixture.")
      if quantity == 0 { continue }
      try #require(![CommodityIdentity.slaves.rawValue, CommodityIdentity.narcotics.rawValue,
        CommodityIdentity.firearms.rawValue].contains(commodity))
      let requestedRow = try #require(MarketDisplayOrder.commodityIDs.firstIndex(of: commodity))
      for _ in 0..<MarketDisplayOrder.commodityIDs.count {
        let selected = await runtime.snapshot().selection
        if selected == commodity { break }
        let row = try #require(MarketDisplayOrder.commodityIDs.firstIndex(of: selected))
        await runtime.key(row > requestedRow ? "up" : "down")
      }
      try #require(await runtime.snapshot().selection == commodity)
      for _ in 0..<quantity {
        let selling = await runtime.snapshot()
        try #require(selling.nativeMainStationDockEvidenceIsCurrent)
        try #require(selling.commander.sellableCargo(commodity) > 0)
        let price = selling.market[commodity].bidPrice
        try #require(price > 0 && selling.commander.credits <= 4_294_967_295 - price)
        var cargo = selling.commander.cargo
        cargo[commodity] -= 1
        var market = selling.market
        market[commodity].quantity += 1
        await runtime.key("left")
        let sold = await runtime.snapshot()
        try #require(sold.commander.cargo == cargo && sold.market == market)
        try #require(sold.commander.credits == selling.commander.credits + price)
        try #require(sold.commander.nativePeople == selling.commander.nativePeople)
        try #require(sold.commander.equipmentInventory == selling.commander.equipmentInventory)
        try #require(sold.commander.equipmentPurchaseHistory == selling.commander.equipmentPurchaseHistory)
        try #require(sold.commander.hullInstanceID == owned.commander.hullInstanceID)
        try #require(sold.commander.fleetBlueprintAcquisition(for: "SH029") == acquisition)
        try #require(sold.nativeMainStationDockEvidenceIsCurrent && sold.commander.valid)
      }
    }
    let cleared = await runtime.snapshot()
    try #require(cleared.commander.cargo.allSatisfy { $0 == 0 })
    try #require(cleared.commander.standardCargoCapacity - cleared.commander.cargoTonnes >= 1)
    try #require(cleared.commander.legal == cared.commander.legal)

    // SH029 has three ordinary utility mounts, already used by EMP, cutter and scoops.
    // Store the real paid cutter before buying the optional pod/galactic drive; keep it owned.
    if escapeReady || galaxyReady {
      await runtime.key("9")
      let fitting = await runtime.snapshot()
      try #require(fitting.screen == .inventory && fitting.nativeMainStationDockEvidenceIsCurrent)
      let inventory = try #require(fitting.commander.equipmentInventory)
      let cutter = try #require(fitting.commander.fittedEquipment(at: .utility(.salvageCutter)))
      let emp = try #require(fitting.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
      let scoops = try #require(fitting.commander.fittedEquipment(at: .utility(.fuelScoops)))
      let mounts = inventory.items.filter { item in
        guard let slot = item.location?.slot else { return false }
        switch slot {
        case .utility, .fuelStorage: return true
        default: return false
        }
      }
      try #require(mounts.count == 3)
      let preview = fitting.inventoryActionPreview(for: .equipment(cutter))
      let command = try #require(preview.command)
      try #require(preview.label == "Store" && command.action == .store(cutter))
      try #require(await runtime.snapshot().commander == fitting.commander)
      let stored = await runtime.inventoryCommand(command)
      try #require(stored)
      let fitted = await runtime.snapshot()
      let after = try #require(fitted.commander.equipmentInventory)
      try #require(after.owner == inventory.owner && after.activeHull == inventory.activeHull)
      try #require(after.items == inventory.items.map { $0.id == cutter.id ? $0.moved(to: nil) : $0 })
      try #require(fitted.commander.fittedEquipment(at: .utility(.salvageCutter)) == nil)
      try #require(fitted.commander.fittedEquipment(at: .utility(.empPirateBlaster)) == emp)
      try #require(fitted.commander.fittedEquipment(at: .utility(.fuelScoops)) == scoops)
      try #require(fitted.commander.credits == fitting.commander.credits)
      try #require(fitted.commander.cargo == fitting.commander.cargo)
      try #require(fitted.commander.cargoTonnes == fitting.commander.cargoTonnes)
      try #require(fitted.commander.salvageLedger == fitting.commander.salvageLedger)
      try #require(fitted.commander.nativePeople == fitting.commander.nativePeople)
      try #require(fitted.commander.savedEMPState == fitting.commander.savedEMPState)
      try #require(fitted.commander.equipmentPurchaseHistory == fitting.commander.equipmentPurchaseHistory)
      try #require(fitted.commander.fleetBlueprintAcquisition(for: "SH029") == acquisition)
      try #require(fitted.nativeMainStationDockEvidenceIsCurrent && fitted.commander.valid)
    }

    // Use the same genuine paid producer; never replay the fresh G03 purchase sequence.
    if escapeReady {
      try await NativeOkapiAcquisitionJourneyFixture.purchasePaidEquipment("Escape Pod", runtime: runtime)
      try #require(await runtime.snapshot().commander.equipment.contains("Escape Pod"))
    }
    if galaxyReady {
      let drive = try #require(Equipment.all.first { $0.name == "Galactic Hyperdrive" })
      let before = await runtime.snapshot()
      try #require(before.currentSystem.name == "Verasel" && before.currentSystem.technology == 16)
      try #require(drive.price == 285000 && drive.requiredTechnologyLevel == 15)
      let ownedPreparationRequired1 = before.equipmentAvailable(drive) && before.shopPrice(drive) == 285000
      try #require(ownedPreparationRequired1)
      try await NativeOkapiAcquisitionJourneyFixture.purchasePaidEquipment(drive.name, runtime: runtime)
      let bought = await runtime.snapshot()
      let fittedDrive = try #require(bought.commander.fittedEquipment(at: .utility(.galacticHyperdrive)))
      let paid = try #require(bought.commander.equipmentPurchaseHistory?.paid.last)
      try #require(fittedDrive.id == paid.binding.request.newItem && paid.price == 285000)
      try #require(bought.commander.credits == before.commander.credits - paid.price)
    }
    try await NativeOkapiAcquisitionJourneyFixture.purchasePaidEquipment(
      NavigationTier.military.equipmentName, runtime: runtime)
    try await runtime.procurementRefuelForTurnaround(expectedSystem: owned.commander.system)
    let ready = await runtime.snapshot()
    let baseline = try originalCargoBaseline(ready.commander)
    try #require(ready.commander.navigationTier == .military)
    let path = try #require(NavigationGraph(game: ready).path(
      from: ready.commander.system, to: site.system.system,
      fuel: ready.commander.availableJumpFuel, scoring: 0))
    let installed = files.root.appendingPathComponent("dispatch-library", isDirectory: true)
    if defaults {
      let errors = await runtime.loadDefaultScriptPacks(directory: installed)
      try #require(errors.isEmpty)
    } else {
      try await runtime.installScriptPack(
        from: ScriptPackLibrary.bundledSealedDispatchDirectory, destination: installed)
    }
    let diagnostic = ScriptProcurementFlightDiagnostic(label: "owned-original-dispatch")
    try await ScriptProcurementFixture.travel(
      runtime, path: path, diagnostic: diagnostic, verifyDeparture: true,
      selectionDiagnostic: .init(label: "earned Okapi route to original dispatch source"))
    // Final arrival fuel is spent. Secondary source capabilities do not include a fuel shop.
    try await runtime.procurementRefuelForTurnaround(expectedSystem: site.system.system)
    try await dock(runtime, at: site)
    let arrived = await runtime.snapshot()
    try #require(arrived.commander.hullInstanceID == owned.commander.hullInstanceID)
    try #require(arrived.commander.fleetBlueprintAcquisition(for: "SH029") == acquisition)
    let beforeInventory = try #require(ready.commander.equipmentInventory)
    let afterInventory = try #require(arrived.commander.equipmentInventory)
    try #require(afterInventory.owner == beforeInventory.owner && afterInventory.activeHull == beforeInventory.activeHull)
    try #require(Set(afterInventory.items.map(\.id)) == Set(beforeInventory.items.map(\.id)))
    for item in beforeInventory.items {
      let retained = try #require(afterInventory.items.first { $0.id == item.id })
      try #require(retained.node == item.node && retained.provenance == item.provenance)
      try #require(retained.component == item.component && retained.location == item.location)
      try #require(retained.boundHull == item.boundHull && retained.preferredSlot == item.preferredSlot)
      try #require(retained.retainedLegacyState == item.retainedLegacyState)
      try #require(retained.nativeRepairLoopCondition == item.nativeRepairLoopCondition)
      try #require(retained.empGrades == item.empGrades)
      // The actual EMP bank may recharge during flight; its paid grades and item stay fixed.
    }
    try #require(arrived.commander.equipmentPurchaseHistory == ready.commander.equipmentPurchaseHistory)
    try #require(arrived.commander.nativePeople == ready.commander.nativePeople)
    try #require(arrived.commander.nativeCrewMissing == 0 && arrived.commander.legal == 0)
    try #require(arrived.commander.fuel == arrived.commander.fuelCapacity)
    try #require(arrived.commander.cargo == ready.commander.cargo)
    let arrivedBaseline = try originalCargoBaseline(arrived.commander)
    try #require(arrivedBaseline == baseline)
    try #require(arrived.commander.scriptState.instances.isEmpty)
    try #require(arrived.scriptPacks.contains { $0.digest == pack.digest })
    if galaxyReady {
      try #require(arrived.commander.equipment.contains("Galactic Hyperdrive"))
    }
    return runtime
  }

  /// Framing is controlled setup. Only actual runtime swept entry and its writer issue the receipt.
  @inline(never)
  func dock(_ runtime: GameRuntime, at site: OriginalStationSite) async throws {
    try await releaseSecondaryDockApproach(runtime, at: site)
    await brakeDockApproach(runtime)
    try await finishSecondaryDockApproach(runtime, at: site)
  }

  @inline(never)
  private func releaseSecondaryDockApproach(_ runtime: GameRuntime, at site: OriginalStationSite) async throws {
    try #require(site != .remoteUtility)
    let initial = await runtime.snapshot()
    if initial.docked {
      await runtime.nativeCommand { $0.screen = .status }
      await runtime.key("0")
    }
    let arriving = await runtime.snapshot()
    try #require(!arriving.docked && arriving.commander.valid)
    if arriving.workGuidance != nil || arriving.workBraking != nil {
      await runtime.key("q")
    }
  }

  @inline(never)
  private func finishSecondaryDockApproach(_ runtime: GameRuntime, at site: OriginalStationSite) async throws {
    await runtime.setControls(Controls())
    let stopped = await runtime.snapshot()
    try #require(!stopped.docked && stopped.commander.valid)
    try #require(stopped.workGuidance == nil && stopped.workBraking == nil)
    try #require(stopped.flightWorldVelocity == Vector3(0, 0, 0))
    try #require(stopped.systemIdentity == site.system)
    let owner = try #require(stopped.commander.equipmentOwnerID)
    let station = site.identity(world: owner)
    let source = try #require(NativeStationSource.binding(for: station))
    let world = try #require(stopped.commander.nativeStations)
    let record = try #require(world.ledger.records.first { $0.identity == station })
    try #require(record.tombstone == nil && NativeStationSource.authentic(record, owner: owner))
    let bodies = stopped.bodies.filter { $0.nativeStationIdentity == station }
    let body = try #require(bodies.first)
    let ownedPreparationRequired2 = bodies.count == 1 && body.energy > 0 && stopped.nativeStationBodyIsCurrent(body)
    try #require(ownedPreparationRequired2)
    let binding = try #require(body.physical?.identity)
    try #require(record.binding?.actor == binding && record.binding?.bodyID == body.id)
    let time = stopped.commander.flightSimulation.physicalTime
    let position = try #require(world.currentPosition(for: .originalStation(station), at: time))
    let orientation = try #require(world.currentOrientation(for: station, at: time))
    let port = source.geometry.docking
    var pose = ShipPose()
    pose.position = position + orientation.apply(port.center + port.outward)
    pose.orientation.y = orientation.apply(port.up)
    pose.orientation.z = orientation.apply(port.outward) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    let frame = pose
    await runtime.nativeCommand { actual in
      NativeStationTestFixture.reframe(&actual, to: frame)
      actual.speed = 2
    }
    let framed = await runtime.snapshot()
    try #require(!framed.docked && framed.commander.flightSimulation.pose == frame)
    let arrived = await runtime.advance(delta: 0.1)
    try #require(arrived.docked && !arrived.dockedAtMainStation && arrived.commander.valid)
    try #require(arrived.nativeStationDockEvidenceIsCurrent && arrived.pendingNativeStationDock == nil)
    let ownedPreparationRequired3 = arrived.nativeOriginalSealedDispatchOrigin(for: pack)
    let origin = try #require(ownedPreparationRequired3)
    let endpoint = try #require(NativeOriginalSealedDispatchOrigin.station(for: site))
    try #require(origin.station == endpoint && origin.facts.receipt.station == station)
    try #require(origin.isCurrent(in: arrived, pack: pack))
    let persisted = try NativeSaveTestFixture.readVersionedCommander(from: save)
    try #require(persisted.nativeStations?.ledger.currentDock == origin.facts.receipt)
  }

  /// Ordinary commodities are separate from real retained hardware/recovered-item mass.
  /// Capture this baseline before acceptance; the sealed package adds exactly one tonne.
  func originalCargoBaseline(_ commander: borrowing Commander, sealedTonnes: Int = 0) throws -> Int {
    try #require((0...1).contains(sealedTonnes))
    let inventory = try #require(commander.equipmentInventory)
    let empItems = inventory.items.filter { $0.node == EMPModuleGradePolicy.node }
    try #require(empItems.count == 1)
    let emp = try #require(empItems.first)
    let bank = try #require(emp.empBank)
    try #require(bank.valid && bank.module == emp.id && emp.empGrades?.valid == true)
    let mass = commander.salvageLedger.inventoryMassKg
      + (commander.alienStorageState?.current.storedMassKg ?? 0)
      + Double(empItems.count) * EMPModuleGradePolicy.massKilograms
    let rounded = ceil(mass / 1000)
    try #require(mass.isFinite && mass >= 0 && rounded.isFinite && rounded < Double(Int.max))
    let baseline = Int(rounded)
    let context = String(("Original dispatch cargo: ordinary=\(commander.cargo)"
      + " total=\(commander.cargoTonnes) retainedKg=\(mass) baseline=\(baseline)"
      + " sealed=\(sealedTonnes) EMP=\(empItems.count) cases=\(commander.scriptState.instances.count)").prefix(768))
    try #require(commander.cargo.allSatisfy { $0 == 0 }, "\(context)")
    try #require(commander.cargoTonnes == baseline + sealedTonnes, "\(context)")
    return baseline
  }

  func offer(_ runtime: GameRuntime, index: Int = 0) async throws -> (String, ScriptContractOffer) {
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    return (
      key, try #require(await runtime.snapshot().commander.contracts.boards[key]?.offers[index])
    )
  }
  func accept(_ runtime: GameRuntime, index: Int = 0) async throws -> UUID {
    let (key, offer) = try await offer(runtime, index: index)
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed, "\(quote.issues)")
    return try await runtime.confirmContract(quote)
  }
  func travel(_ runtime: GameRuntime, path: [Int]) async throws {
    for destination in path.dropFirst() {
      await runtime.key("escape")
      await runtime.key("0")
      await runtime.nativeCommand { game in
        // Clear the departure geometry only; native H/countdown owns system, fuel and calendar.
        var pose = game.commander.flightSimulation.pose
        pose.position = pose.position + pose.orientation.x * 20_000
        NativeStationTestFixture.reframe(&game, to: pose)
      }
      let game = await runtime.snapshot()
      await runtime.selectSystem(
        x: Double(game.systems[destination].x), y: Double(game.systems[destination].y))
      await runtime.key("h")
      try #require(await runtime.snapshot().jumpCountdown != nil)
      for _ in 0..<200 {
        if await runtime.snapshot().jumpCountdown == nil { break }
        _ = await runtime.advance(delta: 0.1)
      }
      try #require(await runtime.snapshot().commander.system == destination)
      try await dock(runtime)
      if destination != path.last { await runtime.procurementRefuel() }
    }
  }
  func contact(_ runtime: GameRuntime, action: String) async throws {
    await runtime.key("contacts-open")
    try #require(await runtime.snapshot().courierContactActionLabel == action)
  }
  func confirm(_ runtime: GameRuntime) async {
    if await runtime.snapshot().scriptConfirmSelected == false { await runtime.key("left") }
    await runtime.key("return")
  }
}

struct OriginalSealedDispatchNativeTests {
  @Test func closedDispatchPlanKeepsSixDrawsThreeOddRowsAndAuthoredUntimedTerms() async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    #expect(
      fixture.pack.digest == "8cd3f7b667d3842cbe2c0f4a6acb9d304fc4bede2fce66573169569e2ed4fcb3")
    #expect(OriginalSealedDispatch.validManifest(fixture.pack.manifest))
    let runtime = try await fixture.runtime(at: .salamander)
    let (key, _) = try await fixture.offer(runtime)
    let game = await runtime.snapshot()
    let board = try #require(game.commander.contracts.boards[key])
    let generation = try #require(board.courierGeneration)
    #expect(
      board.valid && generation.valid && generation.draws.count == 6
        && generation.indices.count == 6)
    #expect(board.offers.compactMap { $0.courier?.row } == [1, 3, 5])
    for offer in board.offers {
      let terms = try #require(offer.courier)
      #expect(terms.variant == .package && terms.duration == 0)
      #expect(terms.reward == (320 + 90 * (terms.path.count - 1)) * 10)
      #expect(terms.generation == generation && terms.valid && terms.matches(offer))
      #expect(ScriptCourierPreview(terms: terms).summary.contains("H0 | Untimed"))
    }
    let before = game.commander
    #expect(try await runtime.generateContractBoard(packDigest: fixture.pack.digest) == key)
    #expect(await runtime.snapshot().commander == before)
    for (index, pair) in [
      ("original-sealed-dispatch", "other-profile"),
      (#"exclusiveGroup = "sealed-dispatch""#, #"exclusiveGroup = "g02-courier""#),
      (#"id = "sealed-dispatch""#, #"id = "foreign-dispatch""#),
    ].enumerated() {
      let folder = fixture.files.root.appendingPathComponent("invalid-\(index)")
      try FileManager.default.copyItem(
        at: ScriptPackLibrary.bundledSealedDispatchDirectory, to: folder)
      let url = folder.appendingPathComponent("manifest.toml")
      try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: pair.0, with: pair.1)
        .write(to: url, atomically: true, encoding: .utf8)
      #expect(throws: (any Error).self) { try ScriptPackLibrary.read(folder) }
    }
  }

  @Test(arguments: [0, 1, 2])
  func dispatchNativeIssuanceActualTravelReceptionAndReplayPayOnlyOriginal(index: Int) async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let sites: [OriginalStationSite] = [.salamander, .frog, .dhole]
    let runtime = try await fixture.runtime(at: sites[index])
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let id = try await fixture.accept(runtime, index: index)
    let accepted = await runtime.snapshot()
    let original = try #require(accepted.commander.scriptState.instances[id])
    let terms = try #require(original.contract?.offer.courier)
    #expect(original.contract?.deadline == nil && original.contract?.offer.duration == 0)
    #expect(original.courier?.item == ScriptCourierCustody.itemIdentity(id))
    #expect(
      accepted.commander.cargoTonnes == baseline + 1 && accepted.commander.scriptState.savedClueJournal == nil)
    try await fixture.travel(runtime, path: terms.path)
    let arrived = await runtime.snapshot()
    #expect(
      arrived.commander.scriptState.clock(.missionCalendar) > original.contract!.acceptedAt
        + terms.calendarLowerBoundSeconds)
    try await fixture.contact(runtime, action: "Deliver")
    let before = await runtime.snapshot()
    await runtime.key("return")  // Back is the initial selection.
    #expect(await runtime.snapshot().commander == before.commander)
    try await fixture.contact(runtime, action: "Deliver")
    await fixture.confirm(runtime)
    let done = await runtime.snapshot()
    let state = try #require(done.commander.scriptState.instances[id])
    #expect(state.outcome == .complete && state.courier?.terminal?.item == original.courier?.item)
    #expect(
      state.courier?.terminal?.amount == terms.reward
        && done.commander.credits == before.commander.credits + terms.reward)
    #expect(done.commander.cargoTonnes == baseline && done.commander.valid)
    #expect(
      done.commander.scriptState.savedClueJournal?.awards[OriginalSealedDispatch.stateID]?.clueID
        == "sealed-dispatch-family-trace")
    var replay = done
    replay.emitScriptEvent("dialogue.confirmed", only: id)
    #expect(replay.commander.credits == done.commander.credits)
    #expect(
      replay.commander.scriptState.savedClueJournal == done.commander.scriptState.savedClueJournal)
    try await runtime.save(to: fixture.save)
    try await runtime.load(from: fixture.save, persistMigrations: false)
    #expect(await runtime.snapshot().commander == done.commander)
  }

  @Test func dispatchNilDeadlineSurvivesLateCalendarAndRejectsForeignRowsItemsAndExpiry()
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .frog)
    let id = try await fixture.accept(runtime)
    let terms = try #require(
      await runtime.snapshot().commander.scriptState.instances[id]?.contract?.offer.courier)
    try await fixture.travel(runtime, path: terms.path)
    // Controlled boundary semantics on a genuinely travelled snapshot, not elapsed-flight evidence.
    await runtime.nativeCommand { game in
      let late = game.commander.scriptState.clock(.missionCalendar) + 259201
      game.commander.scriptState.calendarSeconds = late
      game.commander.scriptState.missionCalendar?.seconds = late
      game.resolveCourierTerminals()
    }
    let late = await runtime.snapshot()
    let state = try #require(late.commander.scriptState.instances[id])
    #expect(state.outcome == .active && state.courier?.terminal == nil && late.commander.valid)
    let custody = try #require(state.courier)
    for field in ["row", "profile", "item", "deadline"] {
      var object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
      var job = try #require(object["contract"] as? [String: Any])
      var offer = try #require(job["offer"] as? [String: Any])
      var courier = try #require(offer["courier"] as? [String: Any])
      if field == "row" { courier["row"] = 0 }
      if field == "profile" {
        var declaration = try #require(courier["declaration"] as? [String: Any])
        declaration["profile"] = "PROJECT-SPACE-G02-1"
        courier["declaration"] = declaration
      }
      if field == "deadline" { job["deadline"] = 999999999999.0 }
      if field == "item" {
        var held = try #require(object["courier"] as? [String: Any])
        held["item"] = UUID().uuidString
        object["courier"] = held
      }
      offer["courier"] = courier
      job["offer"] = offer
      object["contract"] = job
      let forged = try JSONDecoder().decode(
        ScriptInstance.self, from: JSONSerialization.data(withJSONObject: object))
      #expect(
        !forged.contract!.valid
          || !forged.courier!.valid(state: forged, engine: late.commander.scriptState))
    }
    var expired = state
    var job = try #require(expired.contract)
    job.settled = true
    job.settlementOutcome = .failed
    job.settlementAmount = 0
    job.settledAt = late.commander.scriptState.clock(.missionCalendar)
    expired.contract = job
    expired.outcome = .failed
    expired.courier = .init(
      item: custody.item, issue: custody.issue,
      terminal: .init(
        id: ScriptCourierCustody.terminalIdentity(custody.item), item: custody.item,
        cause: .expired,
        proof: late.courierProof(token: "native:expired", revision: state.revision), amount: 0))
    #expect(!expired.courier!.valid(state: expired, engine: late.commander.scriptState))
    try await fixture.contact(runtime, action: "Deliver")
    await fixture.confirm(runtime)
    #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  }

  @Test(arguments: ["abandon", "escape", "fatal"])
  func dispatchNativeLossConsumesOriginalWithoutPaymentOrClue(mode: String) async throws {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let runtime = try await fixture.runtime(at: .dhole, escapeReady: mode == "escape")
    let baseline = try fixture.originalCargoBaseline(await runtime.snapshot().commander)
    let id = try await fixture.accept(runtime)
    let before = await runtime.snapshot()
    let item = before.commander.scriptState.instances[id]?.courier?.item
    if mode == "abandon" {
      try await fixture.contact(runtime, action: "Abandon")
      await fixture.confirm(runtime)
    } else {
      await runtime.key("0")
      if mode == "escape" {
        await runtime.key("escape-pod")
      } else {
        let launched = await runtime.snapshot()
        try #require(!launched.docked && launched.screen != .gameOver)
        await runtime.nativeCommand { game in
          game.speed = 0
          game.cabinTemperature = 0.99
          game.celestials = [.init(kind: .sun, position: .init(0, 0, 1500), radius: 1100)]
        }
        let staged = await runtime.snapshot()
        // Retain every physical source: erasing station bodies would roll this command back.
        try #require(staged.commander == launched.commander && staged.bodies == launched.bodies)
        try #require(staged.cabinTemperature == 0.99)
        try #require(staged.celestials == [.init(kind: .sun, position: .init(0, 0, 1500), radius: 1100)])
        _ = await runtime.advance(delta: 0.1)
        let destroyed = await runtime.snapshot()
        #expect(destroyed.screen == .gameOver && destroyed.energy == 0 && destroyed.cabinTemperature == 1)
      }
    }
    let lost = await runtime.snapshot()
    let state = try #require(lost.commander.scriptState.instances[id])
    #expect(state.courier?.terminal?.item == item && state.courier?.terminal?.amount == 0)
    #expect(
      state.courier?.terminal?.cause
        == (mode == "abandon" ? .abandoned : mode == "escape" ? .escapePod : .shipDestroyed))
    #expect(lost.commander.cargoTonnes == baseline && lost.commander.credits == before.commander.credits)
    #expect(lost.commander.scriptState.savedClueJournal == nil && lost.commander.valid)
    let originalEMP = try #require(before.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    let retainedEMP = try #require(lost.commander.fittedEquipment(at: .utility(.empPirateBlaster)))
    #expect(retainedEMP.id == originalEMP.id && retainedEMP.provenance == originalEMP.provenance)
    #expect(retainedEMP.component == originalEMP.component && retainedEMP.empGrades == originalEMP.empGrades)
    #expect(retainedEMP.empBank?.module == originalEMP.empBank?.module)
    #expect(retainedEMP.empBank?.capacity == originalEMP.empBank?.capacity)
    #expect(retainedEMP.empBank?.lastDischarge == originalEMP.empBank?.lastDischarge)
    #expect(lost.commander.salvageLedger.inventory == before.commander.salvageLedger.inventory)
    var retry = lost
    retry.resolveCourierTerminals()
    #expect(retry.commander == lost.commander)
    if mode == "abandon" {
      let newID = try await fixture.accept(runtime, index: 1)
      let next = await runtime.snapshot()
      #expect(newID != id && next.commander.scriptState.instances[newID]?.courier?.item != item)
    }
  }
  @Test(arguments: [172800.0, 259200.0], [false, true])
  func currentNativeLegacyCourierKeepsInclusiveDeadlineAndStrictExpiry(duration: Double, late: Bool)
    async throws
  {
    let fixture = try OriginalSealedDispatchFixture()
    defer { fixture.files.clean() }
    let prepared = try await prepareCurrentLegacyCourier(fixture: fixture, duration: duration)
    try await continueCurrentLegacyCourier(prepared.runtime, fixture: fixture, pack: prepared.pack,
      source: prepared.source, duration: duration, late: late)
  }

  private final class LegacyCourierRuntimeSource {
    let runtime: GameRuntime
    let pack: ScriptPack
    let source: (origin: Int, row: Int)
    init(runtime: GameRuntime, pack: ScriptPack, source: (origin: Int, row: Int)) {
      self.runtime = runtime; self.pack = pack; self.source = source
    }
  }

  @inline(never)
  private func prepareCurrentLegacyCourier(
    fixture: OriginalSealedDispatchFixture, duration: Double
  ) async throws -> LegacyCourierRuntimeSource {
    let pack = try ScriptPackLibrary.read(ScriptPackLibrary.bundledCourierDirectory)
    let declaration = try #require(pack.manifest.courier)
    var initial = try ScriptProcurementFixture.freshG03FlightGame()
    try initial.prepareG03FlightEquipment()
    initial.scriptPacks = [pack]
    // Pick an initial scene with an admissible genuine quote, never rewrite a generated plan.
    // The real runtime below is initialized and physically docked before its board freezes.
    var selected: (origin: Int, row: Int)?
    for origin in 0..<256 {
      var commander = initial.commander
      commander.system = origin
      let station = ContractStationIdentity(galaxy: 0, system: origin, stationClass: "main-orbital")
      let key = pack.digest + "/" + pack.manifest.board!.id + "/" + station.key
      let seed = try #require(Game.pledgeBoardSeed(key, revision: 0))
      guard
        let generation = try? ScriptCourierGeneration(
          origin: station, commander: commander, seed: seed)
      else { continue }
      if let row = (0..<6).first(where: {
        let terms = generation.terms(declaration, row: $0)
        return terms.duration == duration && terms.calendarLowerBoundSeconds + 1200 < duration
      }) {
        selected = (origin, row)
        break
      }
    }
    let source = try #require(selected)
    initial.commander.system = source.origin
    initial.selectedSystem = source.origin
    initial.market = MarketItem.at(initial.currentSystem)
    let runtime = GameRuntime(game: initial, saveURL: fixture.save)
    try await runtime.save(to: fixture.save)
    await runtime.key("0")
    return .init(runtime: runtime, pack: pack, source: source)
  }

  @inline(never)
  private func continueCurrentLegacyCourier(
    _ runtime: GameRuntime, fixture: OriginalSealedDispatchFixture, pack: ScriptPack,
    source: (origin: Int, row: Int), duration: Double, late: Bool
  ) async throws {
    try await fixture.dock(runtime)
    try await verifyCurrentLegacyCourierAfterDock(runtime, fixture: fixture, pack: pack,
      source: source, duration: duration, late: late)
  }

  @inline(never)
  private func verifyCurrentLegacyCourierAfterDock(
    _ runtime: GameRuntime, fixture: OriginalSealedDispatchFixture, pack: ScriptPack,
    source: (origin: Int, row: Int), duration: Double, late: Bool
  ) async throws {
    let key = try await runtime.generateContractBoard(packDigest: pack.digest)
    let frozen = try #require(await runtime.snapshot().commander.contracts.boards[key])
    let offer = frozen.offers[source.row]
    let terms = try #require(offer.courier)
    #expect(frozen.valid && frozen.offers.count == 6 && frozen.courierGeneration?.draws.count == 6)
    #expect(frozen.offers.compactMap { $0.courier?.row } == Array(0..<6))
    #expect(terms.duration == duration && !OriginalSealedDispatch.matches(terms.declaration))
    let quote = await runtime.contractAcceptanceQuote(board: key, offer: offer.id)
    try #require(quote.allowed, "\(quote.issues)")
    let id = try await runtime.confirmContract(quote)
    let accepted = try #require(await runtime.snapshot().commander.scriptState.instances[id])
    let due = try #require(accepted.contract?.deadline)
    #expect(due == accepted.contract!.acceptedAt + duration && accepted.courier != nil)
    try await fixture.travel(runtime, path: terms.path)
    let arrived = await runtime.snapshot()
    try #require(arrived.commander.scriptState.clock(.missionCalendar) < due)
    let ledger = try #require(arrived.commander.scriptState.calendarLedger)
    try #require(ledger.pendingJourney == nil)
    let operation = try #require(arrived.commander.scriptState.missionCalendar?.lastNativeOperation)
    #expect(operation == ledger.operation)
    // Controlled deadline-policy clock on a genuinely travelled and docked snapshot.
    // Preserve calendar offset and native operation ledger; this is not elapsed-flight evidence.
    await runtime.nativeCommand { game in
      let target = due + (late ? 0.1 : 0)
      let delta = target - game.commander.scriptState.clock(.missionCalendar)
      game.commander.scriptState.calendarSeconds += delta
      game.commander.scriptState.missionCalendar?.seconds = target
      game.resolveCourierTerminals()
    }
    let boundary = await runtime.snapshot()
    #expect(boundary.commander.scriptState.calendarLedger == ledger)
    #expect(boundary.commander.scriptState.missionCalendar?.lastNativeOperation == operation)
    #expect(boundary.commander.valid)
    if late {
      let expired = try #require(boundary.commander.scriptState.instances[id])
      #expect(expired.outcome == .failed && expired.courier?.terminal?.cause == .expired)
      #expect(expired.contract?.settlementAmount == 0 && expired.courier?.terminal?.amount == 0)
      #expect(boundary.commander.credits == arrived.commander.credits)
    } else {
      #expect(boundary.commander.scriptState.instances[id]?.outcome == .active)
      try await fixture.contact(runtime, action: "Deliver")
      await fixture.confirm(runtime)
      let delivered = await runtime.snapshot()
      let state = try #require(delivered.commander.scriptState.instances[id])
      #expect(state.outcome == .complete && state.courier?.terminal?.proof.clock == due)
      #expect(delivered.commander.credits == arrived.commander.credits + terms.reward)
      #expect(delivered.commander.valid)
    }
  }
}
