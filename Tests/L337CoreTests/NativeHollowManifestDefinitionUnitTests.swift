import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

struct NativeHollowManifestDefinitionUnitTests {
  private var declaration: [String: Any] {
    ["schema": "l337-mission-design/1", "sourceID": "l337.hollow-manifest", "version": "1.0.0"]
  }

  private func decode(_ object: [String: Any]) throws -> NativeHollowManifestDefinition {
    try JSONDecoder().decode(
      NativeHollowManifestDefinition.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func exactAuthoredDeclarationRoundTripsThroughJSONAndTOML() throws {
    let current = try decode(declaration)
    try current.validate()
    #expect(current.valid)
    #expect(
      try JSONDecoder().decode(
        NativeHollowManifestDefinition.self, from: JSONEncoder().encode(current)) == current)
    let text = """
      schema = "l337-mission-design/1"
      sourceID = "l337.hollow-manifest"
      version = "1.0.0"
      """
    #expect(
      try TOMLDecoder().decode(NativeHollowManifestDefinition.self, from: Data(text.utf8))
        == current)
    let encoded = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(current)) as? [String: String])
    #expect(Set(encoded.keys) == Set(["schema", "sourceID", "version"]))
  }

  @Test func foreignMissingUnknownAndWrongTypeDeclarationsAreRefused() throws {
    for key in ["schema", "sourceID", "version"] {
      var changed = declaration
      changed.removeValue(forKey: key)
      #expect(throws: (any Error).self) { try decode(changed) }
      changed[key] = NSNull()
      #expect(throws: (any Error).self) { try decode(changed) }
      changed[key] = 1
      #expect(throws: (any Error).self) { try decode(changed) }
    }
    for (key, value) in [
      ("sourceID", "l337.borrowed-dawn"), ("sourceID", "l337.contract/hollow-manifest"),
      ("schema", "l337.finished-game-physical-profiles/1"), ("version", "0.9.0"),
    ] {
      var changed = declaration
      changed[key] = value
      #expect(throws: (any Error).self) { try decode(changed) }
    }
    for key in ["profile", "capability", "consent", "cargoSerial", "evidence", "reward"] {
      var changed = declaration
      changed[key] = true
      #expect(throws: (any Error).self) { try decode(changed) }
    }
    let invalid = NativeHollowManifestDefinition(
      schema: "l337-mission-design/1", sourceID: "l337.open-shadow", version: "1.0.0")
    #expect(!invalid.valid)
    #expect(throws: (any Error).self) { try invalid.validate() }
  }

  @Test func authoredRoutePreservesEveryWorldEventTargetAndSuccessor() throws {
    let stages = NativeHollowManifestStage.allCases
    #expect(
      stages.map(\.rawValue) == [
        "accept", "inspect-freighters", "analyse-seals", "follow-carrier", "recover-register",
        "rescue-crew", "reconstruct-ledger", "choose-remedy", "return-equipment", "close-case",
      ])
    let actualLocations = stages.map(\.location)
    let expectedLocations: [SystemIdentity] = [
      .init(galaxy: 1, system: 120), .init(galaxy: 1, system: 113),
      .init(galaxy: 1, system: 27), .init(galaxy: 1, system: 182), .init(galaxy: 1, system: 34),
      .init(galaxy: 1, system: 182), .init(galaxy: 1, system: 113),
      .init(galaxy: 1, system: 27), .init(galaxy: 1, system: 120), .init(galaxy: 1, system: 120),
    ]
    #expect(actualLocations == expectedLocations)
    #expect(
      stages.map(\.authoredEvent) == [
        "mission_contact_confirmed", "entity_scan_completed", "mission_contact_confirmed",
        "entity_scan_completed", "mission_item_recovered", "escort_arrived",
        "mission_contact_confirmed", "mission_choice_confirmed", "mission_contact_confirmed",
        "mission_contact_confirmed",
      ])
    #expect(
      stages.map(\.requiredTargets) == [
        ["toren-commission"], ["freighter-seal-a", "freighter-seal-b"], ["seal-laboratory"],
        ["wake-one", "wake-two", "wake-three"], ["custody-register"], ["evacuation-launch"],
        ["ledger-reconstruction"], ["manifest-remedy"], ["inspection-kit-return"],
        ["manifest-payment"],
      ])
    #expect(stages.map(\.next) == Array(stages.dropFirst().map(\.rawValue)) + ["complete"])
    #expect(stages.map(\.receiptID) == stages.map { "l337.hollow-manifest/" + $0.rawValue })
    #expect(Set(stages.map(\.receiptID)).count == 10)
    #expect(NativeHollowManifestStage(rawValue: "complete") == nil)
    #expect(NativeHollowManifestStage(rawValue: "field-work") == nil)
    for (identity, name) in [
      (NativeHollowManifestDefinition.issuer, "Narargan"),
      (NativeHollowManifestDefinition.freighterWorld, "Garrivek"),
      (NativeHollowManifestDefinition.laboratoryWorld, "Torenran"),
      (NativeHollowManifestDefinition.carrierWorld, "Haldator"),
      (NativeHollowManifestDefinition.registerWorld, "Durenran"),
    ] {
      #expect(
        try Universe.originalWorld(galaxy: identity.galaxy, system: identity.system).name == name)
    }
  }

  @Test func kitLoanAndTerminalIdentitiesDoNotAliasCommoditiesOrOtherCampaignRewards() {
    #expect(NativeHollowManifestDefinition.logicalSourceID == "l337.hollow-manifest")
    #expect(
      NativeHollowManifestDefinition.authoringCommit == "c70110b292077588a0855fb48127adfb1b611c9d")
    #expect(
      NativeHollowManifestDefinition.definitionSHA256
        == "82d8567a390bdd82b68a08430b071da84696e07e6b1d5a027f3ee5690e065e2a")
    #expect(NativeHollowManifestDefinition.issuerContactName == "Nia Toren")
    #expect(NativeHollowManifestDefinition.laboratoryContactName == "Marek Iven")
    #expect(NativeHollowManifestDefinition.requiresPriorOrdinaryCommoditySale)
    #expect(NativeHollowManifestDefinition.inspectionKitID == "inspection-kit")
    #expect(NativeHollowManifestDefinition.inspectionKitMassTonnes == 1)
    #expect(NativeHollowManifestDefinition.kitAcquireStage == .analyseSeals)
    #expect(NativeHollowManifestDefinition.kitReturnStage == .returnEquipment)
    #expect(
      NativeHollowManifestStage.allCases.map(\.inspectionKitDeltaTonnes) == [
        0, 0, 1, 0, 0, 0, 0, 0, -1, 0,
      ])
    #expect(NativeHollowManifestDefinition.terminalRewardTenths == 56_000)
    #expect(
      NativeHollowManifestDefinition.terminalRewardReceipt == "l337.hollow-manifest/final-payment")
    #expect(NativeHollowManifestDefinition.completionClueID == "manifest-hidden-imprint")
    #expect(
      NativeHollowManifestDefinition.completionClueReceipt
        == "l337.unwritten-route/clue/manifest-hidden-imprint")
  }
}
