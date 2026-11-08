import Foundation
import Testing

@testable import L337Core

struct GearScriptFixture {
  let root: URL
  let pack: ScriptPack
  init(
    name: String = "E.C.M. System", quantity: Int = 1, loan: Bool = true,
    policy: String = "all", requiredReturn: Bool = true,
    accepted: String = "{op='gear.issue',id='issue',gear='kit',fit=true}",
    contact: String = "", confirm: String = "", observeReturn: Bool = false
  ) throws {
    let temporaryRoot = FileManager.default.temporaryDirectory.appendingPathComponent(
      "script-gear-" + UUID().uuidString)
    root = temporaryRoot
    var ready = false
    defer { if !ready { try? FileManager.default.removeItem(at: temporaryRoot) } }
    let original = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
        "docs/mission-packs/scripted-courier")
    let directory = root.appendingPathComponent("pack")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: original, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    text = text.replacingOccurrences(
      of: "\"cargo-v2\"]", with: "\"cargo-v2\", \"owned-equipment-v2\"]")
    if requiredReturn {
      text = text.replacingOccurrences(
        of: "milestones =", with: "requiredEquipmentReturns = [\"kit\"]\nmilestones =")
    }
    text +=
      "\n[[equipment]]\nid=\"kit\"\nname=\"\(name)\"\nquantity=\(quantity)\nloan=\(loan)\nreturnPolicy=\"\(policy)\"\n"
    if observeReturn {
      text += "\n[[handlers]]\nevent=\"equipment.returned\"\nfunction=\"returned\"\n"
    }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    let source = """
      return {
        accepted=function(e,w,d) return {data=d,commands={\(accepted)}} end,
        contact=function(e,w,d) return {data=d,commands={\(contact)}} end,
        confirm=function(e,w,d) return {data=d,commands={\(confirm)}} end,
        returned=function(e,w,d) d.actual_returns=#e.items; d.spent=e.consumed; return {data=d,commands={}} end
      }
      """
    try source.write(
      to: directory.appendingPathComponent("scripts/main.lua"), atomically: true, encoding: .utf8)
    pack = try ScriptPackLibrary.read(directory)
    ready = true
  }
  func game() throws -> Game {
    var game = Game(executive: false)
    game.screen = .status
    game.scriptPacks = [pack]
    try game.commander.prepareEquipment(legacy: false)
    _ = try game.acceptScriptMission(pack)
    return game
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
}

/// Current owned fixture before any mission issue; it grants no acquisition or paid history.
private func currentEquipmentLoanGame() throws -> Game {
  try OriginalDetailedHullStage.requireRuntime("SH032")
  let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH032"))
  let contract = try #require(OriginalFleetR3Fitting.contract(for: source.ship))
  let fitting = try #require(contract.fitting)
  let accommodation = try ShipAccommodationProfile(ship: source.ship)
  try #require(source.ship.id == "SH032" && source.ship.name == "Panther Explorer")
  try #require(source.ship.catalogue.playerFlyable && source.performance == contract.performance)
  try #require(source.performance.supports(.rear))
  try #require(fitting.compatibleUtilities.contains("auxiliaryFuelTank"))
  try #require(source.performance.fuel == 140 && source.performance.jump == 12)
  try #require(accommodation.equipmentUnits == fitting.equipmentUnits)

  var game = Game(executive: false)
  // Set the initial owned hull before physical inventory is allocated; never exchange a live fit.
  try #require(game.commander.equipmentInventory == nil)
  let funds = game.commander.credits
  game.commander.shipID = source.ship.id
  game.commander.fuel = source.performance.fuel
  try game.commander.prepareEquipment(legacy: false)
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.screen = .status
  try #require(game.commander.valid && game.commander.shipID == source.ship.id)
  try #require(game.commander.equipmentOwnerID != nil && game.commander.hullInstanceID != nil)
  try #require(game.commander.credits == funds && game.commander.fuelStorageUnits == 0)
  try #require(game.commander.fuel == source.performance.fuel)
  try #require(game.commander.fuelCapacity == source.performance.fuel)
  try #require(game.commander.laser(on: .rear) == nil)
  return game
}

@Test func authoredEquipmentExampleTravelsByNativeHyperspaceDocksAndReturnsTheOriginalUnit()
  async throws
{
  let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(
      "docs/mission-packs/scripted-equipment")
  let pack = try ScriptPackLibrary.read(directory)
  var game = try currentEquipmentLoanGame()
  // Controlled initialization on the demonstrator's approved current-world route.
  let origin = try Universe.originalWorlds.world(key: "G01-S167")
  let destination = try Universe.originalWorlds.world(key: "G01-S153")
  try #require(origin.name == "Natanas" && destination.name == "Bevitha")
  try #require(origin.galaxy == 0 && destination.galaxy == 0 && destination.governmentID == 7)
  game.commander.system = origin.system
  game.market = MarketItem.at(game.currentSystem)
  game.selectedSystem = destination.system
  try game.commander.prepareEquipment(legacy: false)
  try game.commander.grantEquipment(
    TargetingTier.docking.equipmentName, at: .targetingCore,
    provenance: .grant("current targeting unit fixture"))
  let distance = game.currentSystem.distance(to: game.systems[destination.system])
  let stockReach = game.commander.maximumJumpDistance
  try #require(stockReach == 12 && stockReach == game.commander.nativePerformance.jump)
  try #require(distance > 0 && distance <= stockReach)
  game.scriptPacks = [pack]
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(
    "loan-voyage-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: folder) }
  let runtime = GameRuntime(game: game, saveURL: folder.appendingPathComponent("commander.json"))
  await runtime.key("contacts-open")
  await runtime.key("return")
  let id = try #require(await runtime.snapshot().commander.scriptState.instances.keys.first)
  let unit = try #require(
    await runtime.snapshot().commander.scriptState.instances[id]?.gearIssues["ecm-kit"]?.items.first
  )
  await runtime.key("0")
  var throttle = Controls()
  throttle.throttle = 1
  await runtime.setControls(throttle)
  var scene = await runtime.snapshot()
  for _ in 0..<200 where scene.massLocked { scene = await runtime.advance(delta: 0.1) }
  await runtime.setControls(Controls())
  await runtime.key("h")
  let departing = await runtime.snapshot()
  try #require(departing.jumpCountdown != nil, Comment(rawValue: departing.message))
  let journey = try #require(departing.commander.scriptState.calendarLedger?.pendingJourney)
  try #require(journey.origin == origin.system && journey.destination == destination.system)
  try #require(journey.nativeFuelDebit > 0 && journey.nativeFuelDebit <= departing.commander.fuel)
  for _ in 0..<200 {
    scene = await runtime.advance(delta: 0.1)
    if scene.commander.system == destination.system { break }
  }
  #expect(
    scene.commander.system == destination.system
      && scene.commander.fuel < departing.commander.fuel)
  #expect(scene.commander.fuel == departing.commander.fuel - journey.nativeFuelDebit)
  #expect(scene.commander.equipmentInventory?.items.contains { $0.id == unit } == true)
  try #require(scene.screen != .gameOver && scene.energy > 0)
  let main = try #require(scene.bodies.first { $0.id == 0 && $0.hull == .station })
  let mainActor = try #require(main.physical?.identity)
  try #require(mainActor == scene.commander.flightSimulation.anchors?.station.identity)
  // Tab visits the actual finite cohort, including registered stations. Eight
  // attempts need not reach MAIN; selection itself advances no flight time.
  let selectionCount = scene.bodies.count + 1
  for _ in 0..<selectionCount {
    await runtime.key("tab")
    scene = await runtime.snapshot()
    if scene.autoPilot.targetID == 0 && scene.autoPilot.targetActor == mainActor { break }
  }
  try #require(scene.autoPilot.targetID == 0 && scene.autoPilot.targetActor == mainActor)
  for _ in 0..<10000 where !scene.docked { scene = await runtime.advance(delta: 0.02) }
  try #require(scene.docked && scene.dockedAtMainStation)
  let cash = scene.commander.credits
  await runtime.key("contacts-open")
  await runtime.key("return")
  let returned = await runtime.snapshot().commander
  #expect(
    returned.scriptState.instances[id]?.outcome == .complete && returned.credits == cash + 500)
  #expect(returned.equipmentInventory?.items.contains { $0.id == unit } == false)
}

@Test func declaredLaserAndTankLoansUseActualMountsStorageAndFuelWithoutARefill() throws {
  for name in ["Beam Laser", FuelStorage.equipmentName] {
    let laser = name == "Beam Laser"
    let fixture = try GearScriptFixture(
      name: name,
      accepted: "{op='gear.issue',id='issue',gear='kit',fit=false}",
      contact: "{op='gear.refit',id='refit',gear='kit',index=0\(laser ? ",mount='rear'" : "")}",
      confirm:
        "{op='gear.store',id='store',gear='kit',index=0},{op='gear.return',id='return',gear='kit'}")
    defer { fixture.clean() }
    var game = try currentEquipmentLoanGame()
    let initialFuel = game.commander.fuel
    let initialCapacity = game.commander.fuelCapacity
    let inventory = try #require(game.commander.equipmentInventory)
    let funds = game.commander.credits
    let history = game.commander.equipmentPurchaseHistory
    game.scriptPacks = [fixture.pack]
    try #require(game.commander.valid && game.commander.fuel == initialFuel)
    _ = try game.acceptScriptMission(fixture.pack)
    let instance = try #require(game.commander.scriptState.instances.values.first)
    let issue = try #require(instance.gearIssues["kit"])
    let original = try #require(issue.items.first)
    let held = try #require(game.commander.equipmentInventory?.items.first { $0.id == original })
    #expect(issue.items.count == 1 && issue.status == .issued && held.location == nil)
    #expect(held.provenance == .missionIssue(
      mission: instance.id, resource: "kit", index: 0, packDigest: fixture.pack.digest))
    game.emitScriptEvent("contact.requested")
    let fitted = try #require(game.commander.equipmentInventory?.items.first { $0.id == original })
    #expect(fitted.provenance == held.provenance)
    #expect(fitted.location?.hullInstanceID == inventory.activeHull)
    #expect(game.commander.valid && game.commander.fuel == initialFuel)
    if laser {
      #expect(game.commander.laser(on: .rear) == .beam)
      #expect(fitted.location?.slot == .laser(.rear))
    } else {
      #expect(
        game.commander.fuelStorageUnits == 1
          && game.commander.fuelCapacity == initialCapacity + FuelStorage.unitCapacity)
      #expect(fitted.location?.slot == .fuelStorage(0))
    }
    game.emitScriptEvent("dialogue.confirmed")
    #expect(
      game.commander.scriptState.instances.values.first?.gearIssues["kit"]?.status == .returned)
    #expect(game.commander.fuelStorageUnits == 0 && game.commander.laser(on: .rear) == nil)
    #expect(game.commander.valid && game.commander.fuel == initialFuel)
    #expect(game.commander.fuelCapacity == initialCapacity)
    #expect(game.commander.equipmentInventory?.items.contains { $0.id == original } == false)
    #expect(game.commander.equipmentInventory?.items == inventory.items)
    #expect(game.commander.equipmentOwnerID == inventory.owner)
    #expect(game.commander.hullInstanceID == inventory.activeHull)
    #expect(game.commander.credits == funds && game.commander.equipmentPurchaseHistory == history)
  }
  for name in ["Fuel", PassengerCabin.equipmentName, "Unknown Device"] {
    #expect(throws: MissionPackError.self) { try GearScriptFixture(name: name) }
  }
}

@Test func malformedDeclarationsAndIssueRequestsCannotAcquireAnyEquipment() throws {
  for quantity in [0, 33] {
    #expect(throws: MissionPackError.self) { try GearScriptFixture(quantity: quantity) }
  }
  #expect(throws: MissionPackError.self) { try GearScriptFixture(policy: "pretend-returned") }
  for commands in [
    "{op='gear.issue',id='issue',gear='kit',fit='yes'}",
    "{op='gear.issue',id='issue',gear='kit',overwrite=true}",
    "{op='gear.return',id='return',gear='kit'}",
    "{op='gear.refit',id='refit',gear='kit',index=0}",
  ] {
    let fixture = try GearScriptFixture(accepted: commands)
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.scriptPacks = [fixture.pack]
    try game.commander.prepareEquipment(legacy: false)
    try #require(game.commander.valid && game.commander.equipmentInventory != nil)
    let before = game.commander
    #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
    #expect(game.commander == before)
  }
  let fixture = try GearScriptFixture()
  defer { fixture.clean() }
  let manifest = fixture.root.appendingPathComponent("pack/manifest.toml")
  let text = try String(contentsOf: manifest, encoding: .utf8)
  for invalid in [
    text + "mount='front'\n", text.replacingOccurrences(of: ", \"owned-equipment-v2\"", with: ""),
  ] {
    try invalid.write(to: manifest, atomically: true, encoding: .utf8)
    #expect(throws: MissionPackError.self) {
      try ScriptPackLibrary.read(fixture.root.appendingPathComponent("pack"))
    }
  }
}

@Test func failedLoanReturnPublicationKeepsTheOriginalGoodsDialogueAndRewardForRetry() async throws
{
  let fixture = try GearScriptFixture(
    contact: "{op='dialogue.offer',id='delivery'}",
    confirm:
      "{op='dialogue.commit',id='delivery',token=e.token},{op='gear.return',id='return',gear='kit'},{op='credits',id='reward',amount=100},{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
  )
  defer { fixture.clean() }
  let directory = fixture.root.appendingPathComponent("save")
  let file = directory.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: try fixture.game(), saveURL: file)
  await runtime.key("contacts-open")
  let before = await runtime.snapshot().commander
  let bytes = try Data(contentsOf: file)
  let backup = fixture.root.appendingPathComponent("backup")
  try FileManager.default.moveItem(at: directory, to: backup)
  try Data("blocked".utf8).write(to: directory)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander == before)
  #expect(try Data(contentsOf: backup.appendingPathComponent("commander.json")) == bytes)
  try FileManager.default.removeItem(at: directory)
  try FileManager.default.moveItem(at: backup, to: directory)
  await runtime.key("return")
  let completed = await runtime.snapshot().commander
  #expect(
    completed.credits == before.credits + 100
      && completed.scriptState.instances.values.first?.outcome == .complete)
  #expect(try completed.equipmentIssueObligations().allSatisfy { !$0.loan || $0.status != .issued })
  let restored = GameRuntime()
  try await restored.load(from: file)
  #expect(await restored.snapshot().commander == completed)
  await runtime.key("contacts-open")
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.credits == completed.credits)
}

@Test func invalidGearRequestsCannotTakeForeignItemsDuplicateFitsOrMutateAnyProperty() throws {
  for request in [
    "{op='gear.return',id='return',gear='foreign'}",
    "{op='gear.refit',id='refit',gear='kit',index=0}",
    "{op='gear.store',id='store',gear='kit',index=99}",
    "{op='gear.store',id='store',gear='kit',index=0,mount='unknown'}",
    "{op='gear.store',id='store',gear='kit',index=0,item='foreign-uuid'}",
    "{op='gear.store',id='store',gear='kit',index=0},{op='gear.store',id='store-again',gear='kit',index=0}",
  ] {
    let fixture = try GearScriptFixture(contact: request)
    defer { fixture.clean() }
    var game = try fixture.game()
    let before = game.commander
    game.emitScriptEvent("contact.requested")
    #expect(
      game.commander.equipmentInventory == before.equipmentInventory
        && game.commander.credits == before.credits)
    #expect(
      game.commander.scriptState.instances.values.first?.suspension != nil && game.commander.valid)
  }
}

@Test func stationAndOriginGuardsPreserveBorrowedEquipmentAcrossHullChangesAndMissingContent()
  async throws
{
  let fixture = try GearScriptFixture(contact: "{op='gear.return',id='return',gear='kit'}")
  defer { fixture.clean() }
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let runtime = try await NativeOkapiAcquisitionJourneyFixture.preparedExchangeRuntime(storage: storage)
  let prepared = await runtime.snapshot()
  let blueprint = try #require(prepared.commander.fleetBlueprintAcquisition(for: "SH029"))
  let previous = try #require(prepared.commander.equipmentInventory)
  try #require(prepared.commander.shipID == "SH025" && prepared.nativeMainStationDockEvidenceIsCurrent)
  // Keep the paid scoop owned in storage to free one real mount for the fitted ECM loan.
  let arrival = try #require(prepared.commander.nativeStations?.currentMainDock)
  let history = try #require(prepared.commander.equipmentPurchaseHistory)
  let scoopNode = try #require(EquipmentRuntimeCatalog.node(for: "Fuel Scoops"))
  let scoop = try #require(previous.items.first { $0.location?.slot == .utility(.fuelScoops) })
  let payment = try #require(history.paid.first { $0.binding.request.newItem == scoop.id })
  try #require(scoop.node == scoopNode && payment.owner == previous.owner && payment.price > 0)
  try #require(scoop.provenance == .paid(owner: payment.owner, transaction: payment.transaction))
  try await runtime.scriptCommand { candidate in
    try #require(candidate.nativeMainStationDockEvidenceIsCurrent)
    try #require(candidate.commander.equipmentInventory?.revision == previous.revision)
    try #require(candidate.commander.fittedEquipment(at: .utility(.fuelScoops)) == scoop)
    try candidate.storeEquipment(scoop, expectedRevision: previous.revision)
  }
  let stored = await runtime.snapshot()
  let storedInventory = try #require(stored.commander.equipmentInventory)
  let storedScoop = try #require(storedInventory.items.first { $0.id == scoop.id })
  try #require(stored.commander.valid && stored.nativeMainStationDockEvidenceIsCurrent)
  try #require(storedScoop.location == nil && storedScoop.node == scoop.node)
  try #require(storedScoop.component == scoop.component && storedScoop.provenance == scoop.provenance)
  try #require(storedInventory.owner == previous.owner && storedInventory.activeHull == previous.activeHull)
  try #require(Set(storedInventory.items.map(\.id)) == Set(previous.items.map(\.id)))
  try #require(storedInventory.items.filter { $0.id != scoop.id } == previous.items.filter { $0.id != scoop.id })
  try #require(stored.commander.equipmentPurchaseHistory == history)
  try #require(stored.commander.credits == prepared.commander.credits)
  try #require(stored.commander.fleetBlueprintAcquisition(for: "SH029") == blueprint)
  try #require(stored.commander.nativeStations?.currentMainDock == arrival)
  let selected = try #require(ShipCatalogue.ship("SH029"))
  let storedQuote = try #require(stored.shipTradeQuote(for: selected))
  try #require(storedQuote.allowed, Comment(rawValue: storedQuote.issues.joined(separator: "; ")))
  let pack = fixture.pack
  // Issue the real original loan only after the physical acquisition and arrival journey.
  let id = try await runtime.scriptCommand { candidate in
    candidate.scriptPacks = [pack]
    return try candidate.acceptScriptMission(pack)
  }
  let accepted = await runtime.snapshot()
  let issue = try #require(accepted.commander.scriptState.instances[id]?.gearIssues["kit"])
  let original = try #require(accepted.commander.equipmentInventory?.items.first {
    $0.id == issue.items[0]
  })
  try #require(issue.status == .issued && original.location?.slot == .utility(.ecm))
  try #require(original.provenance == .missionIssue(
    mission: id, resource: "kit", index: 0, packDigest: fixture.pack.digest))
  // Issued mission custody already exists; prove compatibility without changing carried fuel.
  let destinationFuel = try #require(ShipCatalogue.ship("SH029")?.game?.fuel)
  try #require(accepted.commander.fuel <= destinationFuel)
  try #require(accepted.commander.valid)
  await runtime.key("6")
  await runtime.key("/")
  for character in "SH029" { await runtime.key(String(character)) }
  await runtime.key("return")
  try #require(await runtime.snapshot().showroom.selection == "SH029")
  await runtime.key("return")
  await runtime.key("right")
  let reviewed = await runtime.snapshot()
  let quote = try #require(reviewed.shipTradeQuote)
  try #require(reviewed.showroom.trading && reviewed.showroom.confirmTrade)
  try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: "; ")))
  await runtime.key("return")
  var game = await runtime.snapshot()
  #expect(game.commander.shipID == "SH029")
  try #require(game.commander.shipID == quote.selected.id)
  #expect(game.commander.credits == quote.balance)
  #expect(game.commander.fleetBlueprintAcquisition(for: "SH029") == blueprint)
  #expect(game.commander.equipmentOwnerID == previous.owner)
  #expect(game.commander.hullInstanceID != previous.activeHull)
  #expect(game.commander.fuel == accepted.commander.fuel)
  #expect(game.commander.scriptState.instances[id]?.gearIssues["kit"]?.items == issue.items)
  #expect(
    game.commander.equipmentInventory?.items.first { $0.id == issue.items[0] }?.provenance
      == .missionIssue(mission: id, resource: "kit", index: 0, packDigest: fixture.pack.digest))
  let file = storage.url
  try await runtime.save(to: file)
  let missing = GameRuntime(game: Game(executive: false))
  try await missing.load(from: file)
  #expect(
    await missing.snapshot().commander.equipmentInventory == game.commander.equipmentInventory)
  #expect(await missing.snapshot().commander.fleetBlueprintAcquisition(for: "SH029") == blueprint)
  _ = await missing.advance(delta: 0.1)
  #expect(await missing.snapshot().commander.scriptState.instances[id]?.suspension != nil)
  await runtime.key("0")
  game = await runtime.snapshot()
  try #require(!game.docked && game.commander.valid)
  let property = game.commander.equipmentInventory
  try await runtime.scriptCommand { candidate in candidate.emitScriptEvent("contact.requested") }
  game = await runtime.snapshot()
  #expect(game.commander.equipmentInventory == property && game.commander.valid)
  var corrupt = game.commander
  let inventory = try #require(corrupt.equipmentInventory)
  corrupt.savedEquipmentInventory = try .init(
    owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
    items: inventory.items.filter { $0.id != issue.items[0] })
  corrupt.equipment.remove("E.C.M. System")
  #expect(!corrupt.valid)
}

@Test func stationConfirmedLoansHaveRealIdentityStorageReturnsAndDurableCompletion() async throws {
  let fixture = try GearScriptFixture(
    contact: "{op='gear.store',id='store',gear='kit',index=0},{op='dialogue.offer',id='delivery'}",
    confirm:
      "{op='dialogue.commit',id='delivery',token=e.token},{op='gear.refit',id='refit',gear='kit',index=0},{op='gear.return',id='return',gear='kit'},{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
  )
  defer { fixture.clean() }
  let file = fixture.root.appendingPathComponent("commander.json")
  let runtime = GameRuntime(game: try fixture.game(), saveURL: file)
  let accepted = await runtime.snapshot().commander
  let state = try #require(accepted.scriptState.instances.values.first)
  let original = try #require(state.gearIssues["kit"]?.items.first)
  let item = try #require(accepted.equipmentInventory?.items.first { $0.id == original })
  #expect(
    item.provenance
      == .missionIssue(
        mission: state.id, resource: "kit", index: 0, packDigest: fixture.pack.digest))
  #expect(item.location?.slot == .utility(.ecm))
  await runtime.key("contacts-open")
  #expect(
    await runtime.snapshot().commander.equipmentInventory?.items.first { $0.id == item.id }?
      .location == nil)
  await runtime.key("return")
  let completed = await runtime.snapshot().commander
  #expect(completed.scriptState.instances[state.id]?.outcome == .complete)
  #expect(completed.scriptState.instances[state.id]?.gearIssues["kit"]?.status == .returned)
  #expect(completed.equipmentInventory?.items.contains { $0.id == item.id } == false)
  #expect(!completed.equipment.contains("E.C.M. System") && completed.valid)
  let restored = GameRuntime(game: Game(executive: false))
  try await restored.load(from: file)
  #expect(await restored.snapshot().commander == completed)
}

@Test func aStoryFlagCannotCompleteAnOutstandingLoanOrARequiredPhysicalReturn() throws {
  for loan in [true, false] {
    let fixture = try GearScriptFixture(
      loan: loan,
      contact:
        "{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
    )
    defer { fixture.clean() }
    var game = try fixture.game()
    let before = game.commander
    let id = try #require(before.scriptState.instances.keys.first)
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.scriptState.instances[id]?.outcome == .active)
    #expect(game.commander.scriptState.instances[id]?.milestones.isEmpty == true)
    #expect(game.commander.scriptState.instances[id]?.suspension != nil)
    #expect(game.commander.equipmentInventory == before.equipmentInventory && game.commander.valid)
  }
}

@Test func repeatedIssueCannotRefillStockAndRemainingReturnSeparatesRealItemsFromSpentAmmo() throws
{
  let fixture = try GearScriptFixture(
    name: "Missile", policy: "remaining",
    contact: "{op='gear.issue',id='another-issue',gear='kit',fit=true}",
    confirm: "{op='gear.return',id='return',gear='kit'}", observeReturn: true)
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try #require(game.commander.scriptState.instances.keys.first)
  let issued = try #require(game.commander.scriptState.instances[id]?.gearIssues["kit"])
  #expect(game.commander.missiles == 4)
  game.emitScriptEvent("contact.requested")
  #expect(
    game.commander.missiles == 4
      && game.commander.scriptState.instances[id]?.gearIssues["kit"] == issued)
  game.launch()
  var target = SpaceBody(id: 1, hull: .viper, position: .init(0, 0, 800))
  target.ecmEnabled = true
  game.bodies = [target]
  game.missileArmed = true
  let fired = game.fireMissile()
  #expect(fired && game.commander.missiles == 3 && game.commander.valid)
  #expect(
    game.commander.scriptState.instances[id]?.gearIssues["kit"]?.consumed == Set(issued.items))
  game.dock()
  game.emitScriptEvent("dialogue.confirmed")
  #expect(game.commander.scriptState.instances[id]?.gearIssues["kit"]?.status == .returned)
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.data["actual_returns"] == .integer(0))
  #expect(game.commander.scriptState.instances[id]?.data["spent"] == .integer(1))
  #expect(game.commander.valid)
}

@Test func spentAllItemLoansCannotBeSettledWithNewlyPurchasedSubstitutes() throws {
  let fixture = try GearScriptFixture(
    name: "Missile", contact: "{op='gear.return',id='return',gear='kit'}")
  defer { fixture.clean() }
  var game = try fixture.game()
  let id = try #require(game.commander.scriptState.instances.keys.first)
  let original = try #require(
    game.commander.scriptState.instances[id]?.gearIssues["kit"]?.items.first)
  game.launch()
  try #require(!game.docked && !game.paused && game.screen.isFlight)
  // Native launch creates and registers this asteroid; keep the complete launched world.
  let launchedBodies = game.bodies
  let launchedIDs = launchedBodies.map(\.id)
  let launchedActors = launchedBodies.compactMap { $0.physical?.identity }
  try #require(Set(launchedIDs).count == launchedIDs.count)
  try #require(Set(launchedActors).count == launchedActors.count)
  let target = try #require(game.bodies.first { $0.id == 2 })
  let physical = try #require(target.physical)
  let context = try #require(game.gameplayContext())
  try #require(target.hull == .asteroid && physical.population == .asteroid)
  try #require(physical.identity.system == game.systemIdentity && physical.identity.visit == context.visit)
  try #require(context.actors.filter { $0.identity == physical.identity }.count == 1)
  try #require(target.energy > 0 && target.position.z > 0)
  let mesh = game.gameplayMesh(for: target)
  try #require(!mesh.vertices.isEmpty && !mesh.faces.isEmpty)
  try #require(game.bodies == launchedBodies)
  try #require(game.bodies.map(\.id) == launchedIDs)
  try #require(game.bodies.compactMap { $0.physical?.identity } == launchedActors)
  game.weaponsTargetID = target.id
  game.missileArmed = true
  let fired = game.fireMissile()
  try #require(fired)
  try #require(game.commander.scriptState.instances[id]?.gearIssues["kit"]?.consumed.contains(original) == true)
  try #require(game.commander.equipmentInventory?.items.contains { $0.id == original } == false)
  game.dock()
  try #require(game.docked && game.commander.valid)
  game.selection = try #require(Equipment.all.firstIndex { $0.name == "Missile" })
  let funds = game.commander.credits
  let price = game.shopPrice(Equipment.all[game.selection])
  let inventory = try #require(game.commander.equipmentInventory)
  let previousIDs = Set(inventory.items.map(\.id))
  let paidCount = try #require(game.commander.equipmentPurchaseHistory).paid.count
  game.purchase()
  let replacement = try #require(game.commander.equipmentInventory?.items.first {
    !previousIDs.contains($0.id)
  })
  let history = try #require(game.commander.equipmentPurchaseHistory)
  let payment = try #require(history.paid.first { $0.binding.request.newItem == replacement.id })
  #expect(price > 0 && game.commander.credits == funds - price)
  #expect(history.paid.count == paidCount + 1 && payment.price == price)
  #expect(payment.owner == inventory.owner && replacement.node == EquipmentRuntimeCatalog.standardMissile)
  #expect(replacement.provenance == .paid(owner: payment.owner, transaction: payment.transaction))
  #expect(replacement.id != original)
  #expect(game.commander.missiles == 4)
  #expect(game.commander.equipmentInventory?.items.contains { $0.id == original } == false)
  let property = game.commander.equipmentInventory
  game.emitScriptEvent("contact.requested")
  #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  #expect(game.commander.scriptState.instances[id]?.gearIssues["kit"]?.status == .issued)
  #expect(game.commander.equipmentInventory == property && game.commander.valid)
}

@Test func loanReleaseIsExplicitAndCannotSatisfyARequiredReturn() throws {
  for required in [false, true] {
    let fixture = try GearScriptFixture(
      requiredReturn: required,
      contact:
        "{op='gear.release',id='release',gear='kit'},{op='milestone.ensure',index=0},{op='milestone.ensure',index=1},{op='mission.finish',outcome='complete'}"
    )
    defer { fixture.clean() }
    var game = try fixture.game()
    let id = try #require(game.commander.scriptState.instances.keys.first)
    game.emitScriptEvent("contact.requested")
    #expect(game.commander.scriptState.instances[id]?.outcome == (required ? .active : .complete))
    #expect(
      game.commander.scriptState.instances[id]?.gearIssues["kit"]?.status
        == (required ? .issued : .released))
    #expect(
      try game.commander.equipmentIssueObligations().first { $0.source.mission == id }?.status
        == (required ? .issued : .released))
    #expect(game.commander.valid)
  }
}

@Test func deniedEquipmentFitAndLaterDeniedCommandsRollbackTheWholeMissionAcceptance() throws {
  for commands in [
    "{op='gear.issue',id='issue',gear='kit',fit=true}",
    "{op='gear.issue',id='issue',gear='kit',fit=false},{op='credits',id='debit',amount=-100000}",
  ] {
    let fixture = try GearScriptFixture(quantity: 2, accepted: commands)
    defer { fixture.clean() }
    var game = Game(executive: false)
    game.scriptPacks = [fixture.pack]
    try game.commander.prepareEquipment(legacy: false)
    try #require(game.commander.valid && game.commander.equipmentInventory != nil)
    let before = game.commander
    #expect(throws: MissionPackError.self) { try game.acceptScriptMission(fixture.pack) }
    #expect(
      game.commander == before && game.commander.equipmentInventory == before.equipmentInventory)
  }
}
