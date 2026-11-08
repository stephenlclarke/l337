import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct AuthoredPendingRolePolicyUnitTests {
  private func retained() throws -> CatalogueShip {
    try TOMLDecoder().decode(CatalogueShip.self,
      from: Data(contentsOf: ShipCatalogue.folder.appendingPathComponent("SH007.toml")))
  }

  private func policy(_ changes: [String: Any]) throws -> ShipCatalogueMetadata {
    var fields = try #require(JSONSerialization.jsonObject(
      with: JSONEncoder().encode(retained().catalogue)) as? [String: Any])
    for (key, value) in changes { fields[key] = value }
    return try JSONDecoder().decode(ShipCatalogueMetadata.self,
      from: JSONSerialization.data(withJSONObject: fields))
  }

  @Test func actualPackagedCatalogueLoadsAndRetainsInertImpalaRole() throws {
    // Exercise the strict startup loader, not just a standalone metadata helper.
    let ships = try ShipCatalogue.load(from: ShipCatalogue.folder)
    #expect(ships.count == 171)
    let ship = try #require(ships.first { $0.id == "SH007" })
    #expect(ship == (try retained()) && OriginalImpalaVoyagerActivation.authenticates(ship))
    #expect(ship.catalogue.valid(shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat))
    #expect(OriginalImpalaVoyagerActivation.validEffectiveCargo(ship))
    #expect(ship.catalogue.primaryRole == .leisure && ship.catalogue.roleWeights.isEmpty)
    #expect(ship.catalogue.purchasePolicy == .pendingFabrication && !ship.catalogue.normalPurchaseEligible)
    #expect(!ship.catalogue.readyForNaturalEncounters)
    #expect(ship.catalogue.galaxies.isEmpty && ship.catalogue.regions.isEmpty)
    for role in ShipCatalogueRole.allCases { #expect(ship.catalogue.encounterWeight(for: role) == 0) }
  }

  @Test(arguments: ShipCatalogueRole.allCases)
  func unplacedPendingAuthoredRolesRemainDescriptive(role: ShipCatalogueRole) throws {
    let metadata = try policy(["primaryRole": role.rawValue])
    #expect(metadata.valid(shipID: "SH007", performance: try retained().game, nativeCombat: nil))
    #expect(metadata.primaryRole == role && metadata.roleWeights.isEmpty)
    #expect(metadata.minimumStandardCargoTonnes == 0)
    #expect(metadata.normallyDiscoverable && !metadata.readyForNaturalEncounters)
    for operatingRole in ShipCatalogueRole.allCases {
      #expect(metadata.encounterWeight(for: operatingRole) == 0)
    }
    let current = try JSONDecoder().decode(ShipCatalogueMetadata.self,
      from: JSONEncoder().encode(metadata))
    #expect(current == metadata && current.roleWeights.isEmpty)
  }

  @Test(arguments: ["natural", "ready", "declared", "galaxy", "region", "authoredSite", "habitat",
    "purchase", "eligible", "access", "missingRole", "kind", "schema", "tech", "discovery"])
  func neighborStatesCannotUseDescriptiveRoleException(mutation: String) throws {
    let changes: [String: Any]
    switch mutation {
    case "natural": changes = ["encounterMode": "natural", "placementStatus": "declared",
      "galaxies": [0], "regions": ["deepSpace"]]
    case "ready": changes = ["mechanicsStatus": "ready", "purchasePolicy": "blueprintFabrication",
      "normalPurchaseEligible": true]
    case "declared": changes = ["placementStatus": "declared", "galaxies": [0], "regions": ["deepSpace"]]
    case "galaxy": changes = ["galaxies": [0]]
    case "region": changes = ["regions": ["deepSpace"]]
    case "authoredSite": changes = ["galaxies": [0], "authoredSystems": [["galaxy": 0, "system": 7]]]
    case "habitat": changes = ["habitat": ["governments": [0], "minimumDisplayedTechLevel": 1]]
    case "purchase": changes = ["purchasePolicy": "blueprintFabrication"]
    case "eligible": changes = ["normalPurchaseEligible": true]
    case "access": changes = ["access": "xyzzyOnly"]
    case "missingRole": changes = ["primaryRole": NSNull()]
    case "kind": changes = ["objectKind": "other", "primaryType": NSNull()]
    case "schema": changes = ["schemaVersion": 3]
    case "tech": changes = ["minimumBuildTechLevel": 0]
    case "discovery": changes = ["discoveryEligible": false]
    default: throw SaveError.invalidCommander
    }
    let metadata = try policy(changes)
    #expect(!metadata.valid(shipID: "SH007", performance: try retained().game, nativeCombat: nil))
    for role in ShipCatalogueRole.allCases { #expect(metadata.encounterWeight(for: role) == 0) }
  }

  @Test(arguments: ["missing", "wrong", "zero", "high", "duplicate"])
  func naturalRolesStillRequireMatchingUniquePositiveWeights(mutation: String) throws {
    let natural: [String: Any] = ["encounterMode": "natural", "mechanicsStatus": "ready",
      "placementStatus": "declared", "purchasePolicy": "blueprintFabrication",
      "normalPurchaseEligible": true, "galaxies": [0], "regions": ["deepSpace"],
      "roleWeights": [["role": "leisure", "weight": 1]]]
    let positive = try policy(natural)
    #expect(positive.valid(shipID: "SH007", performance: try retained().game, nativeCombat: nil))
    #expect(positive.readyForNaturalEncounters && positive.encounterWeight(for: .leisure) > 0)
    var malformed = natural
    switch mutation {
    case "missing": malformed["roleWeights"] = [] as [[String: Any]]
    case "wrong": malformed["roleWeights"] = [["role": "pirate", "weight": 1]]
    case "zero": malformed["roleWeights"] = [["role": "leisure", "weight": 0]]
    case "high": malformed["roleWeights"] = [["role": "leisure", "weight": 101]]
    case "duplicate": malformed["roleWeights"] = [["role": "leisure", "weight": 1], ["role": "leisure", "weight": 2]]
    default: throw SaveError.invalidCommander
    }
    let rejected = try policy(malformed)
    #expect(!rejected.valid(shipID: "SH007", performance: try retained().game, nativeCombat: nil))
    // Nonempty malformed weights fail the original rules for authored pending hulls too.
    let authored = try policy(["roleWeights": try #require(malformed["roleWeights"])])
    #expect(mutation == "missing"
      ? authored.valid(shipID: "SH007", performance: try retained().game, nativeCombat: nil)
      : !authored.valid(shipID: "SH007", performance: try retained().game, nativeCombat: nil))
  }
}
