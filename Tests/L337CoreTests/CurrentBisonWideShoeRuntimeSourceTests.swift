import Foundation
import Testing

@testable import L337Core

struct CurrentBisonWideShoeRuntimeSourceTests {
  @Test
  func exactV2SourceBindsAllSixMassesAndFourMaterialPairsWithoutExtraActuators() throws {
    let (bytes, commissioning) = try sourceBytes()
    let source = try #require(CurrentNewtKitSource.decodeBisonSource(bytes, commissioningBytes: commissioning))
    #expect(source.configuration == "SH005-current-newt-person7-wide-shoes-v2")
    #expect(source.sourceSHA256 == "48c747bffefc6abccee84e9eacaea361f318fe3afd6c52f82ce463a34b648a5e")
    #expect(source.driveRolesAreCoherent && source.massExpectationsAreCoherent())
    #expect(source.driveContactPairs.count == 2 && source.passiveDriveMaterialContactPairs.count == 2)
    let moving = source.retainedParts.filter { source.movingDriveComponentIDs.contains($0.id) }
    #expect(moving.count == 6 && source.driveFollowerComponentIDs.count == 2)
    #expect(abs(moving.reduce(0) { $0 + $1.stowed.massKilograms } - 43.3376) < 1e-9)
    #expect(source.maximumForceNewtons == 4000 && source.ejectWork == 2400)
    let definition = try #require(source.bisonCommissioning)
    #expect(definition.driveContactPairs.reduce(0) { $0 + $1.maximumNormalForceNewtons } == 4000)
    #expect(definition.passiveDriveMaterialContactPairs.allSatisfy {
      $0.nominalAppliedActuatorForceNewtons == 0 && $0.ordinaryUnilateralReactionRequired
        && $0.actualAnnularMaterialQuads.count == 4
    })
    #expect(Set(source.driveContactPairs.map(\.driverID)).isDisjoint(
      with: Set(source.passiveDriveMaterialContactPairs.map(\.rodComponentID))))
    let shoes = source.releasedParts.filter { $0.id.hasPrefix("new-Bison-conformal-thrust-shoe-") }
    #expect(shoes.count == 2 && shoes.allSatisfy { $0.collisionMesh?.vertices.count == 8 && $0.mass.massKilograms == 0.5 })
    #expect(source.personSlots.count == 12 && source.selectedPersonOrdinal == 7)
    #expect(source.personSlots.allSatisfy { $0.profile.sourceSHA256 == source.sourceSHA256 })
  }

  @Test
  func oldFileAliasAndChangedCommissioningCannotAuthenticateV2() throws {
    let (bytes, commissioning) = try sourceBytes()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let current = root.appendingPathComponent(CurrentBisonWideShoePhysicalSource.resourceFileName)
    let alias = root.appendingPathComponent("SH005-current-newt-person7-kit-v1.json")
    try bytes.write(to: current)
    try bytes.write(to: alias)
    #expect(CurrentNewtKitSource.authenticResource(at: current))
    #expect(!CurrentNewtKitSource.authenticResource(at: alias))
    var changed = commissioning
    changed[changed.startIndex] ^= 1
    #expect(CurrentBisonWideShoeCommissioning.decode(changed) == nil)
    #expect(CurrentNewtKitSource.decodeBisonSource(bytes, commissioningBytes: changed) == nil)
  }

  @Test(arguments: ["extra-paid-pairs", "passive-paid-force", "missing-passive", "missing-catch"])
  func decodedDefinitionsCannotPromotePassivePairsDropMassOrEscapeRoleChecks(fault: String) throws {
    let (bytes, commissioning) = try sourceBytes()
    let source = try #require(CurrentNewtKitSource.decodeBisonSource(bytes, commissioningBytes: commissioning))
    var object = try #require(JSONSerialization.jsonObject(with: commissioning) as? [String: Any])
    switch fault {
    case "extra-paid-pairs":
      let pairs = try #require(object["driveContactPairs"] as? [[String: Any]])
      object["driveContactPairs"] = pairs + pairs
    case "passive-paid-force":
      var pairs = try #require(object["passiveDriveMaterialContactPairs"] as? [[String: Any]])
      pairs[0]["nominalAppliedActuatorForceNewtons"] = 2000
      object["passiveDriveMaterialContactPairs"] = pairs
    case "missing-passive": object["passiveDriveMaterialContactPairs"] = []
    case "missing-catch":
      var moving = try #require(object["movingDriveComponentIDs"] as? [String])
      moving.removeAll { $0 == "new-load-catch-14.238718506088443" }
      object["movingDriveComponentIDs"] = moving
    default: Issue.record("Unknown negative control"); return
    }
    // Negative decoded definitions grant no source or observation authority.
    let negative = try JSONDecoder().decode(CurrentBisonWideShoeCommissioning.self,
      from: JSONSerialization.data(withJSONObject: object))
    #expect(!negative.matchesParts(retained: source.retainedParts, released: source.releasedParts))
    #expect(source.driveRolesAreCoherent && source.driveContactPairs.count == 2)
    #expect(source.movingDriveComponentIDs.count == 6)
  }

  @Test
  func expectedThirteenUnitStatesCannotCreatePrivateCommissioningOrBisonBirthStock() throws {
    let (bytes, commissioning) = try sourceBytes()
    let source = try #require(CurrentNewtKitSource.decodeBisonSource(bytes, commissioningBytes: commissioning))
    let declarations = try #require(source.bisonCommissioning)
    let occupied = try #require(declarations.carrierCells.first { $0.originalCellOrdinal == 0 })
    let empty = try #require(declarations.carrierCells.first { $0.originalCellOrdinal == 7 })
    #expect(occupied.expectedAtBirth.physicalBodyOrdinal == 0)
    #expect(empty.expectedAtBirth.physicalBodyOrdinal == nil)
    #expect(occupied.expectedAtBirth.initialAbsolutePressurePascals != empty.expectedAtBirth.initialAbsolutePressurePascals)
    #expect(declarations.portablePod.expectedAtBirth.physicalBodyOrdinal == 7)
    #expect(declarations.carrierCells.count + 1 == 13)
    #expect(declarations.actualCommissioningRequirements.privateActualCommissioningIdentityPerUnitRequired)
    #expect(declarations.actualCommissioningRequirements.sourceDeclarationIsNotObservedState)
    #expect(source.carrierCellService == nil && !source.sourceQualifiedForBirth)
    #expect(source.initialCarrierCells(at: 123) == nil)
    // The existing actual SH029 producer remains independent of v2 definitions.
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let body = try #require(game.bodies.first { $0.physical?.currentNewtKitStock != nil })
    let stock = try #require(body.physical?.currentNewtKitStock)
    #expect(stock.issue.configuration == CurrentNewtKitPhysicalSource.configurationID && stock.remaining == 1)
    #expect(CurrentNewtKitSource.current?.matches(stock, at: game.commander.flightSimulation.physicalTime) == true)

    // Resolution is a source-definition phase, not a route to issue Bison stock.
    let newt = try #require(CurrentNewtMechanicalPlan.ResolvedSources(issues: [stock.issue]))
    #expect(newt.source(for: stock.issue)?.sourceSHA256 == CurrentNewtKitPhysicalSource.sourceSHA256)
    let now = game.storedFlightSimulation().physicalTime
    let plan = try #require(game.currentNewtMechanicalPlan(.init(start: now, end: now + 0.01)))
    // This genuinely issued, still-stowed trader has no EMP episode to plan.
    #expect(game.nativeMechanicalStoredEMPState() == nil)
    #expect(plan.owners.isEmpty && plan.drives.isEmpty && plan.coasts.isEmpty)
    #expect(game.bodies.first { $0.physical?.currentNewtKitStock?.issue == stock.issue }?
      .physical?.currentNewtKitStock == stock)

    // Alter only source-selection metadata. This remains an invalid Bison issue.
    let encodedIssue = try JSONEncoder().encode(stock.issue)
    var bisonObject = try #require(JSONSerialization.jsonObject(with: encodedIssue) as? [String: Any])
    bisonObject["configuration"] = CurrentBisonWideShoePhysicalSource.configurationID
    bisonObject["sourceSHA256"] = CurrentBisonWideShoePhysicalSource.sourceSHA256
    var bisonLoad = try #require(bisonObject["birthLoad"] as? [String: Any])
    bisonLoad["catalogueShipID"] = "SH005"
    bisonObject["birthLoad"] = bisonLoad
    let bisonIssue = try JSONDecoder().decode(CurrentNewtKitIssue.self,
      from: JSONSerialization.data(withJSONObject: bisonObject))
    #expect(!bisonIssue.structurallyValid && !source.matches(bisonIssue) && !source.sourceQualifiedForBirth)
    let bisonOnly = try #require(CurrentNewtMechanicalPlan.ResolvedSources(issues: [bisonIssue]))
    #expect(bisonOnly.source(for: bisonIssue)?.sourceSHA256 == source.sourceSHA256)
    #expect(bisonOnly.source(for: stock.issue) == nil)
    let mixed = try #require(CurrentNewtMechanicalPlan.ResolvedSources(issues: [stock.issue, bisonIssue]))
    #expect(mixed.source(for: stock.issue)?.parentCatalogueID == "SH029")
    #expect(mixed.source(for: bisonIssue)?.parentCatalogueID == "SH005")
    let reversed = try #require(CurrentNewtMechanicalPlan.ResolvedSources(issues: [bisonIssue, stock.issue]))
    #expect(reversed.source(for: stock.issue)?.sourceSHA256 == CurrentNewtKitPhysicalSource.sourceSHA256)
    #expect(reversed.source(for: bisonIssue)?.sourceSHA256 == source.sourceSHA256)

    for fault in ["configuration", "sourceSHA256", "catalogueShipID"] {
      var changed = bisonObject
      if fault == "catalogueShipID" {
        var load = bisonLoad
        load[fault] = "SH029"
        changed["birthLoad"] = load
      } else {
        changed[fault] = fault == "configuration" ? "foreign-source" : String(repeating: "0", count: 64)
      }
      let foreign = try JSONDecoder().decode(CurrentNewtKitIssue.self,
        from: JSONSerialization.data(withJSONObject: changed))
      #expect(CurrentNewtMechanicalPlan.ResolvedSources(issues: [foreign]) == nil)
      #expect(CurrentNewtMechanicalPlan.ResolvedSources(issues: [stock.issue, foreign]) == nil)
      #expect(mixed.source(for: foreign) == nil)
    }
    let emptySources = try #require(CurrentNewtMechanicalPlan.ResolvedSources(issues: []))
    #expect(emptySources.source(for: stock.issue)?.sourceSHA256 == CurrentNewtKitPhysicalSource.sourceSHA256)
    #expect(emptySources.source(for: bisonIssue) == nil)
    let emptyGame = Game()
    try #require(!emptyGame.bodies.contains { $0.physical?.currentNewtKitStock != nil })
    let emptyNow = emptyGame.storedFlightSimulation().physicalTime
    let emptyPlan = try #require(emptyGame.currentNewtMechanicalPlan(.init(start: emptyNow, end: emptyNow + 0.01)))
    #expect(emptyPlan.owners.isEmpty && emptyPlan.proposals.isEmpty && emptyPlan.drives.isEmpty
      && emptyPlan.coasts.isEmpty && emptyPlan.interruptions.isEmpty)
  }

  private func sourceBytes() throws -> (Data, Data) {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let directory = root.appendingPathComponent("Sources/L337Core/Resources/OriginalFleetPhysical")
    return (try Data(contentsOf: directory.appendingPathComponent(CurrentBisonWideShoePhysicalSource.resourceFileName)),
      try Data(contentsOf: directory.appendingPathComponent(CurrentBisonWideShoePhysicalSource.commissioningFileName)))
  }
}
