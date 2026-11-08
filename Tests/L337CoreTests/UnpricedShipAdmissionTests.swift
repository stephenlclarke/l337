import Foundation
import Testing

@testable import L337Core

private func performanceWithPrice(_ price: Int, fuel: Int? = nil) throws -> ShipPerformance {
  let original = try #require(ShipCatalogue.ship("SH025")?.game)
  let bytes = try JSONEncoder().encode(original)
  let decoded = try JSONSerialization.jsonObject(with: bytes)
  var fields = try #require(decoded as? [String: Any])
  fields["price"] = price
  if let fuel { fields["fuel"] = fuel }
  let changed = try JSONSerialization.data(withJSONObject: fields)
  return try JSONDecoder().decode(ShipPerformance.self, from: changed)
}

@Test func unpricedPerformanceRequiresNeverPolicyAndPreservesEveryOtherBound() throws {
  let policies: [ShipCataloguePurchasePolicy] = [
    .blueprintFabrication, .pendingFabrication, .xyzzyOnly, .never,
  ]
  for policy in policies {
    for price in [-1, 0, 1, 100_000_000, 100_000_001] {
      let performance = try performanceWithPrice(price)
      let expected = price >= (policy == .never ? 0 : 1) && price <= 100_000_000
      let admitted = performance.valid(purchasePolicy: policy)
      #expect(admitted == expected)
      #expect(performance.valid == (price >= 1 && price <= 100_000_000))
    }
  }
  let emptyFuel = try performanceWithPrice(0, fuel: 0)
  let admittedEmptyFuel = emptyFuel.valid(purchasePolicy: .never)
  #expect(!admittedEmptyFuel)
}

private func priceAdmissionTOML(policy: ShipCataloguePurchasePolicy, price: Int) throws -> String {
  let originalShip = try #require(ShipCatalogue.ship("SH025"))
  let performance = try #require(originalShip.game)
  let original = try String(
    contentsOf: ShipCatalogue.folder.appendingPathComponent("SH025.toml"), encoding: .utf8)
  let catalogueStart = try #require(original.range(of: "[catalogue]"))
  let gameStart = try #require(
    original.range(of: "[game]", range: catalogueStart.upperBound..<original.endIndex))
  let designStart = try #require(
    original.range(of: "[design]", range: gameStart.upperBound..<original.endIndex))
  var catalogue = String(original[catalogueStart.lowerBound..<gameStart.lowerBound])
  if policy == .never {
    catalogue =
      catalogue
      .replacingOccurrences(
        of: "purchasePolicy = \"blueprintFabrication\"", with: "purchasePolicy = \"never\""
      )
      .replacingOccurrences(
        of: "normalPurchaseEligible = true", with: "normalPurchaseEligible = false"
      )
      .replacingOccurrences(of: "discoveryEligible = true", with: "discoveryEligible = false")
      .replacingOccurrences(
        of: "collectionMilestone = \"blueprintAndFabrication\"",
        with: "collectionMilestone = \"none\"")
    catalogue = catalogue.split(separator: "\n", omittingEmptySubsequences: false)
      .filter { !$0.hasPrefix("minimumBuildTechLevel =") }.joined(separator: "\n")
  }
  let game = String(original[gameStart.lowerBound..<designStart.lowerBound])
    .replacingOccurrences(
      of: "price = " + String(performance.price), with: "price = " + String(price))
  // An unregistered fixture exercises generic policy without changing authenticated SH025.
  let identity = String(original[..<catalogueStart.lowerBound]).replacingOccurrences(
    of: "id = \"SH025\"", with: "id = \"SH999\"")
  return identity + catalogue + game
    + String(original[designStart.lowerBound...])
}

@Test func actualLoaderAdmitsUnpricedNeverButRejectsFreePurchaseAndNegativePrices() throws {
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
    "unpriced-ship-admission-" + UUID().uuidString)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: directory) }
  let file = directory.appendingPathComponent("SH999.toml")
  try #require(ShipCatalogue.ship("SH999") == nil)
  let policies: [ShipCataloguePurchasePolicy] = [.blueprintFabrication, .never]
  for policy in policies {
    for price in [-1, 0, 1] {
      let text = try priceAdmissionTOML(policy: policy, price: price)
      try text.write(to: file, atomically: true, encoding: .utf8)
      let shouldLoad = price > 0 || (price == 0 && policy == .never)
      if shouldLoad {
        let loaded = try ShipCatalogue.load(from: directory)
        let ship = try #require(loaded.first)
        #expect(
          ship.id == "SH999" && ship.game?.price == price
            && ship.catalogue.purchasePolicy == policy)
        #expect(ship.catalogue.playerFlyable)
      } else {
        #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
      }
    }
  }
  let never = try priceAdmissionTOML(policy: .never, price: 0)
  let contradictory = never.replacingOccurrences(
    of: "normalPurchaseEligible = false", with: "normalPurchaseEligible = true")
  try contradictory.write(to: file, atomically: true, encoding: .utf8)
  #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
  // Generic admission does not permit the same edits to an authenticated original.
  try FileManager.default.removeItem(at: file)
  let canonicalFile = directory.appendingPathComponent("SH025.toml")
  let canonicalSource = try String(
    contentsOf: ShipCatalogue.folder.appendingPathComponent("SH025.toml"), encoding: .utf8)
  try canonicalSource.write(to: canonicalFile, atomically: true, encoding: .utf8)
  #expect(try ShipCatalogue.load(from: directory).first?.id == "SH025")
  let forgedCanonical = never.replacingOccurrences(of: "id = \"SH999\"", with: "id = \"SH025\"")
  try forgedCanonical.write(to: canonicalFile, atomically: true, encoding: .utf8)
  #expect(throws: (any Error).self) { try ShipCatalogue.load(from: directory) }
}
