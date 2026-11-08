import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

/// Controlled owned-hull fitting transfer; the paid acquisition journey has its own native test.
@Test func ownedHullTransferPreservesCargoMissionsPortablePropertyAndCash() throws {
  var game = hullTradeGame(missiles: 0)
  game.commander.fuel = 70
  game.commander.credits = 10_000_000
  game.commander.cargo[0] = 2
  game.commander.cargo[10] = 1
  game.commander.blackjack.stage = .deliverFirearm
  game.commander.blackjack.transfers = [.contact, .goldAward, .goldDelivery, .report, .firearmPickup]
  game.commander.missionStage = .huntingConstrictor
  game.commander.installLaser(.beam, on: .rear)
  game.commander.navigationPlan = nil
  try game.commander.prepareEquipment(legacy: false)
  game.commander.mirrorFittedEquipment()
  let before = game.commander
  let inventory = try #require(before.equipmentInventory)
  let drive = try #require(before.fittedEquipment(at: .drive))
  try game.commander.transferEquipment(to: "SH029", hullID: UUID())
  let after = game.commander
  #expect(after.shipID == "SH029" && after.credits == before.credits)
  #expect(after.cargo == before.cargo && after.equipment == before.equipment)
  #expect(after.fuel == before.fuel && after.missiles == before.missiles)
  #expect(after.blackjack == before.blackjack && after.missionStage == before.missionStage)
  #expect(after.laserMounts == before.laserMounts && after.valid)
  let transferred = try #require(after.equipmentInventory)
  #expect(transferred.owner == inventory.owner && transferred.activeHull != inventory.activeHull)
  #expect(Set(transferred.items.map(\.id)) == Set(inventory.items.map(\.id)))
  for original in inventory.items {
    let item = try #require(transferred.items.first { $0.id == original.id })
    #expect(item.node == original.node && item.provenance == original.provenance)
    #expect(item.component == original.component && item.boundHull == original.boundHull)
    #expect(item.preferredSlot == original.preferredSlot)
    #expect(item.location == original.location.map {
      .init(hullInstanceID: transferred.activeHull, slot: $0.slot)
    })
  }
  #expect(after.fittedEquipment(at: .drive)?.id == drive.id)
  #expect(after.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
  try game.commander.transferEquipment(to: "SH025", hullID: UUID())
  #expect(game.commander.shipID == "SH025" && game.commander.credits == before.credits)
}

@Test func exchangesBlockFundsCargoPaidFitFuelAndRouteConflictsWithoutAnyLoss() throws {
  var game = hullTradeGame(missiles: 0)
  game.commander.system = 69
  game.selectedSystem = 69
  game.market = MarketItem.at(game.currentSystem)
  try game.commander.prepareEquipment(legacy: false)
  game.commander.mirrorFittedEquipment()
  game.screen = .status
  game.key("6")
  game.showroom.selection = "SH029"
  #expect(try #require(game.shipTradeQuote).issues.contains { $0.contains("cash") })
  game.commander.credits = 100_000_000
  game.screen = .equipment
  game.equipmentMount = .rear
  let history = try #require(game.commander.equipmentPurchaseHistory)
  @discardableResult
  func buy(_ name: String, in game: inout Game) throws -> EquipmentRuntimePurchaseQuote {
    let item = try #require(Equipment.all.first { $0.name == name })
    let before = game.commander
    let quote = try game.quoteEquipmentPurchase(item)
    try #require(quote.purchase.requiredDebit > 0)
    let purchaseApplied = try game.applyEquipmentPurchase(quote)
    try #require(purchaseApplied)
    #expect(game.commander.credits == before.credits - quote.purchase.requiredDebit)
    let inventory = try #require(game.commander.equipmentInventory)
    let actual = try #require(inventory.items.first { $0.id == quote.request.newItem })
    #expect(actual.provenance == .paid(owner: inventory.owner, transaction: quote.request.transaction))
    #expect(game.commander.equipmentPurchaseHistory?.paid.contains {
      $0.transaction == quote.request.transaction && $0.node == actual.node && $0.price > 0
    } == true)
    return quote
  }
  let rear = try buy("Military Laser", in: &game)
  let bay = try buy("Large Cargo Bay", in: &game)
  for _ in 0..<7 { try buy("Missile", in: &game) }
  try #require(game.commander.missiles == 7 && game.commander.valid)
  #expect(game.commander.equipmentPurchaseHistory?.paid.count == history.paid.count + 9)
  #expect(game.commander.fittedEquipment(at: .laser(.rear))?.id == rear.request.newItem)
  #expect(game.commander.fittedEquipment(at: .utility(.cargoExpansion))?.id == bay.request.newItem)
  game.key("6")
  game.showroom.selection = "SH031"
  let selected = try #require(game.showroomShip?.game)
  try #require(selected.missiles == 6 && !selected.supports(.rear))
  game.commander.cargo[CommodityIdentity.food.rawValue] = selected.cargo + selected.cargoExpansion + 1
  let quote = try #require(game.shipTradeQuote)
  #expect(quote.issues.contains { $0.contains("Sell cargo") })
  #expect(quote.issues.contains { $0.contains("Physical fittings") })
  #expect(quote.issues.contains { $0.contains("Rear laser") })
  #expect(quote.issues.contains { $0.contains("missiles") })
  let old = game.commander
  game.key("showroom-trade")
  game.key("right")
  game.key("return")
  #expect(game.showroom.trading && game.commander == old)
  game.key("8")
  #expect(game.screen == .showroom)
  game.key("escape")
  #expect(!game.showroom.trading && game.commander == old)
  game.showroom.selection = "SH025"
  #expect(try #require(game.shipTradeQuote).issues.contains { $0.contains("already own") })
  game.dockedAtMainStation = false
  #expect(try #require(game.shipTradeQuote).issues.contains { $0.contains("main station") })
  game.showroom.selection = "SH141"
  #expect(game.shipTradeQuote == nil)
  game.key("showroom-trade")
  #expect(!game.showroom.trading)
}

@Test func ownedHullControlsRealFlightPoolsMountsAndCurrentSave() throws {
  var game = hullTradeGame(shipID: "SH025", missiles: 1)
  try game.commander.prepareEquipment(legacy: false)
  game.commander.mirrorFittedEquipment()
  try #require(game.commander.valid)
  game.launch()
  try #require(!game.docked)
  game.bodies = []
  game.speed = 0
  let p = game.commander.performance
  var controls = Controls()
  controls.throttle = 1
  controls.pitch = 1
  controls.roll = 1
  controls.yaw = 1
  game.tick(delta: 0.1, controls: controls)
  #expect(abs(game.speed - p.acceleration * 0.1) < 0.00001)
  #expect(game.pitch == p.pitch && game.yaw == p.yaw && game.roll == p.roll)
  controls.pitch = 0
  controls.roll = 0
  controls.yaw = 0
  for _ in 0..<100 { game.tick(delta: 0.1, controls: controls) }
  #expect(game.speed == p.speed && game.energy == p.energy)
  game.dock()
  #expect(game.energy == p.energy && game.frontShield == p.shield)
  let data = try JSONEncoder().encode(game.commander)
  let loaded = try JSONDecoder().decode(Commander.self, from: data)
  #expect(loaded == game.commander && loaded.shipID == "SH025" && loaded.valid)
  game.commander.shipID = "SH999"
  #expect(!game.commander.valid)
}

@Test func normalizedComparisonsSortAndTOMLLoaderAreConsistent() throws {
  let loaded = try ShipCatalogue.load(from: ShipCatalogue.folder)
  #expect(loaded.count == 171 && loaded.allSatisfy { $0.design.valid })
  #expect(loaded.filter { $0.game != nil }.count == 162)
  #expect(loaded.allSatisfy { $0.previewMesh != nil })
  var game = hullTradeGame()
  game.screen = .status
  game.key("6")
  game.showroom.selection = "SH013"
  let rows = game.showroomComparison
  #expect(rows.first { $0.label == "Cargo" }?.rating == .better)
  #expect(rows.first { $0.label == "Top speed" }?.rating == .worse)
  for key in ["fore_shield_max", "aft_shield_max"] {
    let field = try #require(game.showroomProfile?.fields.first { $0.key == key })
    let comparison = try #require(rows.first { $0.label == field.label })
    // Independent original Buffalo r3 shield capacity; the carried stock module is intrinsic.
    #expect(field.number == 470)
    #expect(comparison.rating == .better && comparison.baseline != comparison.selected)
  }
  let before = game.showroom.selection
  game.showroom.query = "buffalo"
  game.key("showroom-sort")
  #expect(game.showroom.selection == before && game.showroom.query == "buffalo")
  let powers = game.showroomShips.map { $0.game?.power ?? -1 }
  #expect(powers == powers.sorted(by: >))
  game.key("showroom-sort")
  let names = game.showroomShips.map(\.name)
  #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
  game.commander.unlimitedCargo = true
  #expect(game.showroomComparison.first { $0.label == "Cargo" }?.rating == .same)
  game.key("v")
  #expect(
    game.showroom.sourceProfiles && !game.showroom.compare
      && game.showroomProfiles.count == game.showroomShip?.sourceProfilesIncludingPhysical.count)
  for width in [512.0, 1512] {
    game.viewportWidth = width
    game.viewportHeight = 518
    game.key("showroom-trade")
    let frame = Display.presentation(game, width: width, height: 518)
    #expect(frame.labels.allSatisfy { $0.bounds.maxX <= width && $0.bounds.maxY < 518 })
    game.key("escape")
  }
}

@Test func informationScrollHintsShareViewportAndStopAtBothBoundaries() {
  for screen in [Screen.status, .inventory] {
    var game = Game(executive: false)
    game.screen = screen
    game.fitMaximumHardware()
    for i in game.commander.cargo.indices { game.commander.cargo[i] = 1 }
    game.viewportWidth = 768
    game.viewportHeight = 1400
    let needed = max(0, game.informationWindow.count - game.informationWindow.visible)
    let row = StationLayout(game: game, width: 768, height: 1400, footer: 28).row
    game.viewportHeight += Double(needed + 1) * row
    game.informationScroll = 0
    #expect(game.informationWindow.visible >= game.informationWindow.count)
    #expect(game.informationWindow.hint == nil)
    game.key("down")
    #expect(game.informationScroll == 0)
    let tall = Display.presentation(game, width: 768, height: game.viewportHeight)
    #expect(
      !tall.labels.contains { $0.text.contains("scroll") || $0.text.contains("Arrows: more") })
    game.viewportHeight = 518
    game.informationScroll = 0
    let window = game.informationWindow
    #expect(window.count == game.informationRows.count)
    #expect(window.last == max(0, window.count - window.visible))
    if window.last == 0 {
      #expect(game.informationWindow.hint == nil && game.informationWindow.last == 0)
      game.key("pagedown")
      game.key("up")
      #expect(game.informationScroll == 0)
    } else {
      #expect(game.informationWindow.hint?.hasPrefix("Down:") == true)
      for _ in 0..<100 { game.key("pagedown") }
      #expect(game.informationScroll == game.informationWindow.last)
      #expect(game.informationWindow.hint?.hasPrefix("Up:") == true)
      game.key("up")
      #expect(game.informationScroll == game.informationWindow.last - 1)
      for _ in 0..<window.count { game.key("pageup") }
      #expect(game.informationScroll == 0)
      game.key("up")
      #expect(game.informationScroll == 0)
    }
    game.docked = false
    #expect(
      Display.presentation(game, width: 768, height: 518).labels.contains {
        $0.text.contains("Esc: back") && $0.text.contains("K: help")
      })
  }
}

@Test func everyModelRemainsVisibleFiniteAndFramedThroughoutFullRotation() {
  for ship in ShipCatalogue.all {
    for step in 0..<24 {
      let frame = Display.shipPortrait(ship, angle: Double(step) * 2 * .pi / 24)
      #expect(frame.hasShipSurfaces, "\(ship.id) angle \(step)")
      #expect(
        frame.shipPanels.allSatisfy {
          $0.vertices.allSatisfy { $0.x.isFinite && $0.y.isFinite && frame.flightClip.contains($0) }
        })
      for graphic in frame.worldGraphics + frame.graphics {
        guard case .textured(let triangle) = graphic else { continue }
        #expect(triangle.vertices.count == 3, "\(ship.id) angle \(step)")
        #expect(triangle.clip == frame.flightClip, "\(ship.id) angle \(step)")
        #expect(
          triangle.vertices.allSatisfy {
            ShipTextureRaster.validVertex($0) && frame.flightClip.contains($0.point)
          }, "\(ship.id) angle \(step)")
      }
    }
  }
}

@Test func fuelAndRouteConstraintsFollowActualHullTanksAndDoNotDiscardFuel() throws {
  var initial = hullTradeGame(shipID: "SH019", missiles: 0)
  initial.commander.credits = 100_000_000
  try initial.commander.prepareEquipment(legacy: false)
  initial.commander.mirrorFittedEquipment()
  initial.screen = .status
  initial.key("6")
  initial.showroom.selection = "SH025"
  let target = try #require(ShipCatalogue.ship("SH025")?.game)
  try #require(initial.commander.fuel == 160 && target.fuel == 130)
  let full = initial.commander
  #expect(try #require(initial.shipTradeQuote).issues.contains { $0.contains("fuel") })
  #expect(initial.commander == full)
  // Separate controlled owned-resource vector; quoting does not discard the first vector's fuel.
  var route = initial
  route.commander.fuel = target.fuel
  let destination = try #require(route.systems.first {
    guard !$0.isPlugh else { return false }
    let distance = route.currentSystem.distance(to: $0)
    return distance > target.jump && distance <= route.commander.maximumJumpDistance
  })
  route.commander.navigationPlan = .init(
    galaxy: 0, path: [route.commander.system, destination.id], tier: .basic,
    originFuel: route.commander.fuel, originCapacity: route.commander.fuelCapacity)
  try #require(route.commander.navigationPlan?.valid == true)
  let beforeRoute = route.commander
  #expect(try #require(route.shipTradeQuote).issues.contains { $0.contains("route") })
  #expect(route.commander == beforeRoute)
  route.commander.navigationPlan = nil
  let cleared = try #require(route.shipTradeQuote)
  #expect(!cleared.issues.contains { $0.contains("fuel") || $0.contains("route") })
  let ownedProjection = try route.commander.projectedEquipmentTransfer(to: "SH025")
  #expect(ownedProjection.valid && ownedProjection.fuel == route.commander.fuel)
  // Paid fabrication additionally needs actual earned receiving and current station authority.
  // Its eventual allowed-quote/real exchange positive lives in NativeCrewReadinessUnitTests
  // via the same-owner NativeEarnedPeregrineFixture; this component vector grants no proof.
  #expect(!cleared.allowed && cleared.issues.contains { $0.contains("blueprint") })
}

@Test func shipFilesRejectInvalidSyntaxRangesGeometryAndMismatchedIDs() throws {
  let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
  let file = folder.appendingPathComponent("SH025.toml")
  let source = try String(
    contentsOf: ShipCatalogue.folder.appendingPathComponent("SH025.toml"), encoding: .utf8)
  let original = try TOMLDecoder().decode(CatalogueShip.self, from: Data(source.utf8))
  try #require(original.id == "SH025" && original.design.valid)
  try #require(original.game?.valid(purchasePolicy: original.catalogue.purchasePolicy) == true)
  try Data("name = [".utf8).write(to: file)
  #expect(throws: (any Error).self) { try ShipCatalogue.load(from: folder) }
  let gameStart = try #require(source.range(of: "[game]\n"))
  let designStart = try #require(source.range(of: "[design]\n"))
  let nativeStart = try #require(source.range(of: "[nativeDesign]\n"))
  let speedPattern = try NSRegularExpression(pattern: "(?m)^speed\\s*=\\s*[^\\n]+$")
  let speedMatches = speedPattern.matches(in: source,
    range: NSRange(gameStart.upperBound..<designStart.lowerBound, in: source))
  try #require(speedMatches.count == 1)
  let speedRange = try #require(Range(speedMatches[0].range, in: source))
  let badSpeed = source.replacingCharacters(in: speedRange, with: "speed = -1.0")
  try #require(badSpeed != source)
  let ranged = try TOMLDecoder().decode(CatalogueShip.self, from: Data(badSpeed.utf8))
  #expect(ranged.game?.speed == -1 && ranged.game?.valid(purchasePolicy: ranged.catalogue.purchasePolicy) == false)
  try Data(badSpeed.utf8).write(to: file)
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
  let facePattern = try NSRegularExpression(pattern: "faces\\s*=\\s*\\[\\s*\\[\\s*(\\d+)")
  let faceMatches = facePattern.matches(in: source,
    range: NSRange(designStart.upperBound..<nativeStart.lowerBound, in: source))
  try #require(faceMatches.count == 1)
  let indexRange = try #require(Range(faceMatches[0].range(at: 1), in: source))
  let badIndex = source.replacingCharacters(in: indexRange, with: String(Int.max))
  try #require(badIndex != source)
  let geometry = try TOMLDecoder().decode(CatalogueShip.self, from: Data(badIndex.utf8))
  #expect(geometry.design.faces.first?.first == Int.max && !geometry.design.valid)
  try Data(badIndex.utf8).write(to: file)
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
  try Data(source.utf8).write(to: file)
  #expect(try ShipCatalogue.load(from: folder).first?.id == "SH025")
  try FileManager.default.moveItem(at: file, to: folder.appendingPathComponent("SH001.toml"))
  #expect(throws: ShipFileError.self) { try ShipCatalogue.load(from: folder) }
}

struct ShipPurchasePolicyUnitTests {
  @Test(arguments: [false, true])
  func pricedNeverForSaleHullCannotExchangeOtherwiseCompatibleOwnedProperty(enabled: Bool) throws {
    var game = hullTradeGame(missiles: 0)
    game.commander.fuel = 0
    game.commander.credits = 10_000_000
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    game.commander.xyzzyActive = enabled
    try #require(game.commander.valid)
    let capsule = try #require(ShipCatalogue.ship("SH040"))
    let performance = try #require(capsule.game)
    try #require(
      capsule.catalogue.purchasePolicy == .never && !capsule.catalogue.normalPurchaseEligible
        && performance.price > 0)
    let projected = try game.commander.projectedEquipmentTransfer(to: capsule.id)
    try #require(projected.valid && projected.fuel == 0 && projected.missiles == 0)
    game.screen = .status
    game.key("6")
    game.showroom.selection = capsule.id
    let before = game.commander
    let quote = try #require(game.shipTradeQuote)
    #expect(!quote.allowed && quote.issues == ["This hull is not for sale."])
    game.key("showroom-trade")
    game.key("right")
    game.key("return")
    #expect(game.commander == before && game.showroom.trading)
    game.key("escape")
    game.showroom.selection = "SH029"
    #expect(game.shipTradeQuote?.allowed == false)
    #expect(game.shipTradeQuote?.issues.contains { $0.contains("blueprint") } == true)
    #expect(game.commander == before)
  }

  @Test(arguments: [false, true])
  func pendingMedusaCannotAcquireQuestRightsFromDebugAccess(enabled: Bool) throws {
    var game = hullTradeGame(missiles: 0)
    game.commander.credits = 10_000_000
    game.commander.xyzzyActive = enabled
    let selected = try #require(ShipCatalogue.ship("SH171"))
    #expect(selected.catalogue.purchasePolicy == .never && !selected.catalogue.normalPurchaseEligible)
    let before = game.commander
    #expect(game.shipTradeQuote(for: selected) == nil)
    #expect(throws: (any Error).self) {
      try game.commander.transferEquipment(to: selected.id, hullID: UUID())
    }
    #expect(game.commander == before)
  }

}

// Declare stock hulls for these model-specific trade and flight scenarios.
private func hullTradeGame(shipID: String = "SH025", missiles: Int? = nil) -> Game {
  var game = Game(executive: false)
  game.commander.shipID = shipID
  game.commander.fuel = game.commander.fuelCapacity
  if let missiles { game.commander.missiles = missiles }
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  return game
}

struct PendingBuffaloPurchaseUnitTests {
  @Test(arguments: ["SH013", "SH014"])
  func pendingBuffaloFabricationCannotExchangeOrChangeProperty(shipID: String) throws {
    var game = hullTradeGame(missiles: 0)
    game.commander.fuel = 0
    game.commander.credits = 100_000_000
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    game.screen = .status
    game.key("6")
    game.showroom.selection = shipID
    let before = game.commander
    let bodies = game.bodies
    let selected = try #require(game.showroomShip)
    let expectedPrice = try #require(OriginalFleetR3Data.contract(for: shipID)?.performance?.price)
    #expect(selected.catalogue.purchasePolicy == .pendingFabrication)
    #expect(!selected.catalogue.normalPurchaseEligible && selected.game?.price == expectedPrice)
    let quote = try #require(game.shipTradeQuote)
    #expect(quote.purchase == expectedPrice * 10)
    #expect(!quote.allowed && quote.issues.contains { $0.contains("Fabrication") })
    game.key("showroom-trade")
    game.key("right")
    game.key("return")
    #expect(game.commander == before && game.bodies == bodies)
  }
}
