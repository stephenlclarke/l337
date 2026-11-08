import Foundation
import Testing

@testable import L337Core

/// Fresh Bison unit inputs and actual paid shop operations, never an acquisition receipt.
enum OriginalBisonFixture {
  /// Independent literal r3 expectations, not values read from the catalogue under test.
  static func expected(_ shipID: String) throws
    -> (name: String, performance: ShipPerformance, units: Int, crew: Int)
  {
    switch shipID {
    case "SH005":
      return ("Bison", .init(
        cargo: 1108, speed: 17.7, acceleration: 3.44, energy: 1120, recharge: 6.4,
        roll: 0.267, pitch: 0.232, yaw: 0.215, shield: 590, shieldRecharge: 1.7,
        fuel: 130, jump: 7, spool: 16, missiles: 7, facings: 15, cargoExpansion: 445,
        price: 814000, workTools: [.salvageCutter]), 48, 12)
    case "SH006":
      return ("Bison Mk II", .init(
        cargo: 1220, speed: 16.8, acceleration: 3.35, energy: 1300, recharge: 7.1,
        roll: 0.258, pitch: 0.224, yaw: 0.215, shield: 640, shieldRecharge: 1.78,
        fuel: 130, jump: 7, spool: 16, missiles: 8, facings: 15, cargoExpansion: 490,
        price: 908000, workTools: [.salvageCutter]), 54, 14)
    default: throw SaveError.invalidCommander
    }
  }

  static func game(shipID: String = "SH005", system: Int? = nil) throws -> Game {
    var game = Game(executive: false)
    var commander = Commander()
    commander.shipID = shipID
    if let system {
      commander.system = system
    } else {
      commander.system = try #require(game.systems.filter { !$0.isPlugh }.max {
        $0.technology < $1.technology
      }?.id)
    }
    commander.credits = 30_000_000
    commander.fuel = 20
    commander.missiles = 1
    try commander.prepareEquipment(legacy: false)
    commander.mirrorFittedEquipment()
    game.commander = commander
    game.selectedSystem = commander.system
    game.market = MarketItem.at(game.currentSystem)
    game.energy = commander.performance.energy
    game.frontShield = commander.shieldCapacity
    game.rearShield = commander.rearShieldCapacity
    game.screen = .equipment
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    try #require(game.commander.valid)
    return game
  }

  @discardableResult
  static func buy(_ name: String, in game: inout Game) throws -> EquipmentRuntimePurchaseQuote {
    let item = try #require(Equipment.all.first { $0.name == name })
    let quote = try game.quoteEquipmentPurchase(item)
    let purchased = try game.applyEquipmentPurchase(quote)
    try #require(purchased)
    return quote
  }

  static func withoutNativeDesign(_ text: String) -> String {
    var removing = false
    return text.split(separator: "\n", omittingEmptySubsequences: false).filter { raw in
      let line = raw.trimmingCharacters(in: .whitespaces)
      if line.range(
        of: #"^\[\[?[A-Za-z_][A-Za-z0-9_.-]*\]\]?$"#,
        options: .regularExpression) != nil
      {
        let table = line.trimmingCharacters(in: CharacterSet(charactersIn: "[] "))
        removing = table == "nativeDesign" || table.hasPrefix("nativeDesign.")
      }
      return !removing
    }.joined(separator: "\n")
  }
}

struct OriginalBisonAdoptionUnitTests {
  @Test(arguments: ["SH005", "SH006"])
  func actualBundledBisonAndStableFleetIDsUseR3PerformanceAndPrice(shipID: String) throws {
    let expected = try OriginalBisonFixture.expected(shipID)
    let expectedIDs = (1...171).map { String(format: "SH%03d", $0) }
    #expect(ShipCatalogue.all.map(\.id).sorted() == expectedIDs)
    let loaded = try ShipCatalogue.load(from: ShipCatalogue.folder)
    #expect(loaded.map(\.id).sorted() == expectedIDs)
    let ship = try #require(ShipCatalogue.ship(shipID))
    #expect(ship.name == expected.name && ship.catalogue.family == "bison")
    #expect(loaded.first { $0.id == shipID } == ship)
    let performance = try #require(ship.game)
    #expect(performance == expected.performance)
    #expect(ShipCatalogue.ship(expected.name) == nil)
    #expect(ShipCatalogue.ship(shipID.lowercased()) == nil)
  }

  @Test(arguments: ["SH005", "SH006"])
  func selectedPlayerNPCAndSalvageShareNativeLODWhilePreviewRemainsDetailed(shipID: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage, shipID: shipID)
    try await NativeCrewTestFixture.fill(runtime)
    var game = await runtime.snapshot()
    try #require(game.commander.nativeCrewMissing == 0)
    let ship = game.commander.ship
    let native = try #require(ship.nativeDesign).rawMesh
    let raw = try #require(ShipCatalogue.rawMesh(shipID))
    let salvage = try #require(SalvageCatalogue.profile(catalogueShipID: shipID))
    let siblingID = shipID == "SH005" ? "SH006" : "SH005"
    let sibling = try #require(ShipCatalogue.ship(siblingID)?.nativeDesign).rawMesh
    #expect(native.vertices != sibling.vertices || native.faces != sibling.faces)
    #expect(game.commander.playerMesh.vertices == native.vertices)
    #expect(game.commander.playerMesh.faces == native.faces)
    #expect(raw.vertices == native.vertices && raw.faces == native.faces)
    #expect(salvage.mesh.vertices == native.vertices && salvage.mesh.faces == native.faces)
    #expect(ship.previewMesh?.vertices == ship.design.mesh.vertices)
    #expect(ship.previewMesh?.faces == ship.design.mesh.faces)
    #expect(
      ship.design.rawMesh.vertices != native.vertices || ship.design.rawMesh.faces != native.faces)
    game.launch()
    // Isolate this admission from randomly seeded civilian traffic in the unit scene.
    game.bodies.removeAll { $0.physical?.population == .civilian }
    let initial = try #require(game.gameplayContext())
    var pose = game.commander.flightSimulation.pose
    pose.position = (initial.anchors.arrival + initial.anchors.station.position) * 0.5
    NativeStationTestFixture.reframe(&game, to: pose)
    let context = try #require(game.gameplayContext())
    let position = context.anchors.arrival * 0.6 + context.anchors.station.position * 0.4
    try #require(EncounterGeography.region(at: context.player.position, anchors: context.anchors) == .tradeLane)
    try #require(EncounterGeography.region(at: position, anchors: context.anchors) == .tradeLane)
    // A controlled stock-generated request uses the actual ambient admission owner.
    // It claims no natural encounter distribution, docking or acquisition acceptance.
    var npc = NPCState(
      role: .trader, origin: context.system, destination: context.system,
      resources: .stock(try #require(ship.game)))
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    func makeRequest(_ facts: NPCState) -> SpawnRequest {
      .init(
        identity: .init(
          system: context.system, visit: context.visit,
          sequence: 9001, member: 0, producer: .ambient),
        population: .civilian, hull: .cobra, position: position,
        orientation: .init(), velocity: .init(0, 0, 0), npc: facts,
        rock: nil, payload: nil, priority: .ordinary, catalogueShipID: shipID)
    }
    var recorded = npc
    recorded.legalProvenance = .recorded
    recorded.cargoProvenance = .recorded
    let beforeActor = game.commander.flightSimulation.nextActor
    let beforeBodies = game.bodies.map(\.id)
    let refusals = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [makeRequest(recorded)], atomic: true)], intents: []))
    let refusal = try #require(refusals.first)
    #expect(refusal.actor == nil && refusal.refusal == .staleContext)
    #expect(game.commander.flightSimulation.nextActor == beforeActor)
    #expect(game.bodies.map(\.id) == beforeBodies)
    let request = makeRequest(npc)
    let receipts = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: true)], intents: []))
    let receipt = try #require(receipts.first)
    let actor = try #require(receipt.actor)
    try #require(receipt.refusal == nil)
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    #expect(body.physical?.catalogueShipID == shipID)
    #expect(game.gameplayMesh(for: body).vertices == native.vertices)
    #expect(game.gameplayMesh(for: body).faces == native.faces)
  }

  @Test(arguments: ["SH005", "SH006"])
  func declaredBisonMissingNativeOrPartialIdentityRefusesAtomicLoader(shipID: String) throws {
    let source = ShipCatalogue.folder.appendingPathComponent(shipID + ".toml")
    let original = try Data(contentsOf: source)
    let text = try #require(String(data: original, encoding: .utf8))
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent(shipID + ".toml")
    try original.write(to: file)
    #expect(try ShipCatalogue.load(from: folder).map(\.id) == [shipID])
    let before = ShipCatalogue.all
    for mutation in ["native", "name", "family", "swapped-name"] {
      var changed = text
      if mutation == "native" {
        changed = OriginalBisonFixture.withoutNativeDesign(text)
        try #require(changed != text)
      } else {
        let key = mutation == "family" ? "family" : "name"
        let sibling = shipID == "SH005" ? "SH006" : "SH005"
        let replacement: String
        if mutation == "swapped-name" {
          replacement = try OriginalBisonFixture.expected(sibling).name
        } else {
          replacement = "incomplete-original-record"
        }
        let range = try #require(changed.range(
          of: "(?m)^" + key + "[[:blank:]]*=.*$", options: .regularExpression))
        changed.replaceSubrange(range, with: key + " = " + String(reflecting: replacement))
      }
      try Data(changed.utf8).write(to: file)
      #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
      #expect(ShipCatalogue.all == before)
      #expect(try Data(contentsOf: source) == original)
    }
  }

  @Test(arguments: ["SH005", "SH006"])
  func pendingFabricationQuoteUsesActualPriceAndCannotExchangeOrGrantRights(shipID: String) throws {
    let expected = try OriginalBisonFixture.expected(shipID)
    var game = try OriginalBisonFixture.game(shipID: "SH023")
    game.commander.credits = 30_000_000
    game.screen = .status
    game.openShowroom()
    game.showroom.selection = shipID
    let before = game.commander
    let ship = try #require(game.showroomShip)
    #expect(ship.catalogue.purchasePolicy == .blueprintFabrication)
    #expect(ship.catalogue.normalPurchaseEligible && ship.catalogue.mechanicsStatus == .ready)
    #expect(before.fleetBlueprintAcquisition(for: shipID) == nil)
    let quote = try #require(game.shipTradeQuote)
    #expect(quote.selected.id == shipID && quote.selected.name == expected.name)
    #expect(quote.purchase == expected.performance.price * 10)
    #expect(quote.allowance == before.performance.price * 10 * 3 / 4)
    #expect(!quote.allowed && quote.issues.contains { $0.contains("blueprint") })
    game.key("showroom-trade")
    game.key("right")
    game.key("return")
    #expect(game.commander == before)
    // An existing owned hull still cannot be exchanged for itself.
    game.showroom.selection = "SH023"
    let sameHull = try #require(game.shipTradeQuote)
    #expect(sameHull.issues.contains { $0.contains("already own") })
  }
}
