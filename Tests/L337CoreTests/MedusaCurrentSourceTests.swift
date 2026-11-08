import Foundation
import Testing

@testable import L337Core

@Test func medusaCurrentBareRequirementsRemainSeparateFromQuestAndMaximumUpgradeRights() throws {
  let ship = try #require(ShipCatalogue.ship("SH171"))
  let current = try #require(OriginalFleetR3Data.contract(for: ship.id))
  #expect(ship.name == "Medusa" && ship.game == current.performance)
  #expect(ship.catalogue.family == "medusa" && ship.catalogue.origin == .alien)
  #expect(current.purchasePolicy == .plughQuestFabrication)
  #expect(ship.catalogue.purchasePolicy == .never && !ship.catalogue.normalPurchaseEligible)
  #expect(ship.profiles.contains { profile in
    profile.fields.contains { $0.key == "r3.access.purchasePolicy" && $0.text == "plughQuestFabrication" }
  })
  #expect(current.fitting?.roleKitIncluded == false && current.accommodation?.initialPurchasedCabins == 0)
  let fit = try ShipAccommodationProfile(ship: ship)
  #expect(fit.equipmentUnits == current.fitting?.equipmentUnits)
  #expect(fit.operatingCrew == current.accommodation?.operatingCrew)
  var game = Game(executive: false)
  for query in ["Medusa", "SH171"] {
    game.showroom.query = query
    #expect(game.showroomShips.map(\.id) == [ship.id])
  }
  let before = game.commander
  #expect(game.shipTradeQuote(for: ship) == nil && game.commander == before)
}

@Test func medusaOriginalMaterialsSurviveProjectionAndKeepWireframePoliciesIndependent() throws {
  let ship = try #require(ShipCatalogue.ship("SH171"))
  let mesh = try #require(ship.previewMesh)
  let original = try OriginalFleetShowroomModels.model(for: ship.id)
  #expect(ship.design.valid && !mesh.materials.isEmpty)
  #expect(mesh.materials == original.nativeDesign.rawMesh.materials)
  #expect(mesh.faceMaterials == original.nativeDesign.rawMesh.faceMaterials)
  #expect(mesh.faceTextures == original.nativeDesign.rawMesh.faceTextures)
  let emissive = mesh.materials.filter(\.emissive)
  try #require(!emissive.isEmpty)
  let colours = Set(emissive.map(\.colour))
  var emissiveSeen = false
  for step in 0..<24 {
    let angle = Double(step) * .pi / 12
    let portrait = Display.shipPortrait(ship, angle: angle)
    #expect(!portrait.shipPanels.isEmpty)
    #expect(portrait.shipPanels.flatMap(\.vertices).allSatisfy { portrait.flightClip.contains($0) })
    emissiveSeen = emissiveSeen || portrait.shipPanels.contains { colours.contains($0.colour) }
    var game = Game(executive: false)
    game.screen = .front
    var body = SpaceBody(id: 1, hull: .cobra, position: .init(0, 0, 400))
    body.orientation.rotate(pitch: 0.3, roll: 0.15, yaw: angle)
    var counts: [Int] = []
    for style in [ShipDisplayStyle.whiteWireframe, .colourWireframe] {
      game.commander.shipDisplayStyle = style
      var frame = Frame()
      frame.rasterizeGraphics = false
      Display.draw(body, game: game, into: &frame, mesh: mesh)
      #expect(frame.shipPanels.isEmpty && !frame.shipLines.isEmpty)
      #expect(frame.shipLines.allSatisfy { $0.ink == (style == .whiteWireframe ? .white : .cyan) })
      counts.append(frame.shipLines.count)
    }
    #expect(counts[0] == counts[1])
  }
  #expect(emissiveSeen)
  for material in emissive {
    #expect(ShipProjection.shade(material.colour, normal: .init(0, 0, 1), emissive: true) == material.colour)
  }
  #expect(ShipProjection.shade(.cyan, normal: .init(0, 0, 1)) != Ink.cyan.rawValue)
}

@Test func shipMaterialLoaderRejectsIncompleteIndicesAndTransparentPanels() throws {
  let ship = try #require(ShipCatalogue.ship("SH171"))
  var definition = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(ship.design)) as? [String: Any])
  for invalid in [[0], Array(repeating: 999, count: ship.design.faces.count)] {
    definition["faceMaterials"] = invalid
    let design = try JSONDecoder().decode(
      ShipDesign.self, from: JSONSerialization.data(withJSONObject: definition))
    #expect(!design.valid)
  }
  definition["faceMaterials"] = ship.design.faceMaterials
  definition["materials"] = [["name": "transparent", "colour": 0x00FF_FF00, "emissive": false]]
  definition["faceMaterials"] = Array(repeating: 0, count: ship.design.faces.count)
  let transparent = try JSONDecoder().decode(
    ShipDesign.self, from: JSONSerialization.data(withJSONObject: definition))
  #expect(!transparent.valid)
  definition.removeValue(forKey: "materials")
  definition.removeValue(forKey: "faceMaterials")
  let untextured = try JSONDecoder().decode(
    ShipDesign.self, from: JSONSerialization.data(withJSONObject: definition))
  #expect(untextured.valid && untextured.rawMesh.materials.isEmpty)
}
