import Foundation
import Testing

@testable import L337Core

/// Deliberately untrusted caller data must never replace an authenticated catalogue entry.
private func unpricedCallerHull(_ canonical: CatalogueShip, id: String) throws -> CatalogueShip {
  var fields = try #require(
    JSONSerialization.jsonObject(with: JSONEncoder().encode(canonical)) as? [String: Any])
  var performance = try #require(fields["game"] as? [String: Any])
  var catalogue = try #require(fields["catalogue"] as? [String: Any])
  fields["id"] = id
  performance["price"] = 0
  catalogue["purchasePolicy"] = "never"
  catalogue["normalPurchaseEligible"] = false
  catalogue["discoveryEligible"] = false
  catalogue["collectionMilestone"] = "none"
  catalogue.removeValue(forKey: "minimumBuildTechLevel")
  fields["game"] = performance
  fields["catalogue"] = catalogue
  return try JSONDecoder().decode(
    CatalogueShip.self, from: JSONSerialization.data(withJSONObject: fields))
}

@Test func canonicalHullQuoteIgnoresCallerPriceAndRefusesUnregisteredUnpricedHull() async throws {
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let runtime = try await NativeOkapiAcquisitionJourneyFixture.preparedExchangeRuntime(
    storage: storage)
  let game = await runtime.snapshot()
  let canonical = try #require(ShipCatalogue.ship("SH029"))
  let performance = try #require(canonical.game)
  let before = game.commander
  let bodies = game.bodies
  let positive = try #require(game.shipTradeQuote(for: canonical))
  try #require(positive.allowed, Comment(rawValue: positive.issues.joined(separator: ", ")))
  #expect(positive.purchase == performance.price * 10 && positive.purchase > 0)

  let forged = try unpricedCallerHull(canonical, id: canonical.id)
  try #require(forged.game?.price == 0 && forged.catalogue.purchasePolicy == .never)
  let resolved = try #require(game.shipTradeQuote(for: forged))
  #expect(resolved.selected == canonical && resolved.allowed)
  #expect(resolved.purchase == positive.purchase && resolved.allowance == positive.allowance)
  #expect(resolved.net == positive.net && resolved.balance == positive.balance)

  let unregistered = try unpricedCallerHull(canonical, id: "SH999")
  try #require(ShipCatalogue.ship(unregistered.id) == nil)
  #expect(game.shipTradeQuote(for: unregistered) == nil)
  #expect(game.commander == before && game.bodies == bodies)
}

/// Use the actual earned fabrication berth; only this isolated collection's location changes.
private func exchangeCollectionPack(in root: URL) throws -> ScriptPack {
  let example = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/mission-packs/material-collection")
  let folder = root.appendingPathComponent("collection-pack")
  try FileManager.default.copyItem(at: example, to: folder)
  let manifest = folder.appendingPathComponent("manifest.toml")
  let source = folder.appendingPathComponent("scripts/main.lua")
  let manifestText = try String(contentsOf: manifest, encoding: .utf8)
    .replacingOccurrences(of: "system = 7", with: "system = 69")
  let sourceText = try String(contentsOf: source, encoding: .utf8)
    .replacingOccurrences(of: "w.system == 7", with: "w.system == 69")
  try manifestText.write(to: manifest, atomically: true, encoding: .utf8)
  try sourceText.write(to: source, atomically: true, encoding: .utf8)
  return try ScriptPackLibrary.read(folder)
}

@Test func actualHullExchangeAndReloadKeepPreviouslyDeliveredMaterialLots() async throws {
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let pack = try exchangeCollectionPack(in: storage.root)
  let runtime = try await NativeOkapiAcquisitionJourneyFixture.preparedExchangeRuntime(
    storage: storage)
  let id = try await runtime.scriptCommand { game in
    try #require(game.nativeMainStationDockEvidenceIsCurrent && game.commander.system == 69)
    // Controlled ordinary commodity stock, supplied after the real physical acquisition journey.
    game.commander.cargo[2] = 2
    game.scriptPacks = [pack]
    game.screen = .status
    return try game.acceptScriptMission(pack)
  }
  await runtime.key("contacts-open")
  try #require(await runtime.snapshot().scriptOffer == id)
  await runtime.key("return")
  let delivered = await runtime.snapshot()
  let collection = try #require(
    delivered.commander.scriptState.instances[id]?.collections["materials"])
  try #require(collection.delivered(2) == 2 && collection.lots.count == 1 && !collection.complete)
  let cargo = delivered.commander.cargo
  let blueprint = try #require(delivered.commander.fleetBlueprintAcquisition(for: "SH029"))
  let hull = try #require(delivered.commander.hullInstanceID)
  await runtime.key("6")
  await runtime.key("/")
  for character in "SH029" { await runtime.key(String(character)) }
  await runtime.key("return")
  let trading = await runtime.snapshot()
  try #require(trading.showroom.selection == "SH029")
  let quote = try #require(trading.shipTradeQuote)
  try #require(quote.allowed, Comment(rawValue: quote.issues.joined(separator: ", ")))
  await runtime.key("showroom-trade")
  await runtime.key("right")
  await runtime.key("return")
  let changed = await runtime.snapshot()
  try #require(changed.commander.shipID == "SH029" && changed.commander.valid)
  #expect(changed.commander.hullInstanceID != hull && changed.commander.credits == quote.balance)
  #expect(changed.commander.fleetBlueprintAcquisition(for: "SH029") == blueprint)
  #expect(changed.commander.scriptState.instances[id]?.collections["materials"] == collection)
  #expect(changed.commander.cargo == cargo)
  try await runtime.save(to: storage.url)
  var fresh = Game(executive: false)
  fresh.scriptPacks = [pack]
  let restored = GameRuntime(game: fresh)
  try await restored.load(from: storage.url, persistMigrations: false)
  let cold = await restored.snapshot()
  #expect(cold.commander.scriptState.instances[id]?.collections["materials"] == collection)
  #expect(cold.commander.cargo == cargo && cold.commander.shipID == "SH029")
  #expect(cold.commander.hullInstanceID == changed.commander.hullInstanceID)
  #expect(cold.commander.credits == changed.commander.credits && cold.commander.valid)
  #expect(cold.commander.fleetBlueprintAcquisition(for: "SH029") == blueprint)
  #expect(cold.nativeMainStationDockEvidenceIsCurrent)
}
