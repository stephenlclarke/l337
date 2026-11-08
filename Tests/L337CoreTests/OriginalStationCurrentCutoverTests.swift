import Foundation
import Testing

@testable import L337Core

struct OriginalStationCurrentCutoverTests {
  @Test(arguments: [
    "adapterRevision", "geometryRevision", "mainStations", "mainObservations",
    "nextMainDockSequence", "stationInertia",
  ])
  func currentOriginalWorldRejectsMissingNullAndLegacyFieldForms(required: String) throws {
    let world = try NativeStationWorld(owner: UUID())
    let encoded = try JSONEncoder().encode(world)
    #expect(try JSONDecoder().decode(NativeStationWorld.self, from: encoded) == world)
    let original = try object(encoded)
    for null in [false, true] {
      var root = original
      root.removeValue(forKey: required)
      if null { root[required] = NSNull() }
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(
          NativeStationWorld.self, from: JSONSerialization.data(withJSONObject: root))
      }
    }
    var legacy = original
    legacy["adapterRevision"] = "removed-source-revision"
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        NativeStationWorld.self, from: JSONSerialization.data(withJSONObject: legacy))
    }
  }

  @Test(arguments: ["null", "value"])
  func currentContractRootRejectsRemovedRRSKeyEvenNull(form: String) throws {
    #expect(try JSONDecoder().decode(ScriptContractState.self, from: Data("{\"boards\":{}}".utf8)).valid)
    var root: [String: Any] = ["boards": [String: Any]()]
    if form == "null" { root["rrs"] = NSNull() }
    else { root["rrs"] = [String: Any]() }
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        ScriptContractState.self, from: JSONSerialization.data(withJSONObject: root))
    }
  }

  @Test func inertialCodecRejectsRemovedCaseBesideCurrentCase() throws {
    let identity = StationInertialIdentity.originalStation(
      OriginalStationSite.salamander.identity(world: UUID()))
    let data = try JSONEncoder().encode(identity)
    #expect(try JSONDecoder().decode(StationInertialIdentity.self, from: data) == identity)
    var root = try object(data)
    root["rrs"] = NSNull()
    for malformed in [root, ["rrs": NSNull()]] {
      #expect(throws: (any Error).self) {
        try JSONDecoder().decode(
          StationInertialIdentity.self, from: JSONSerialization.data(withJSONObject: malformed))
      }
    }
  }

  // These decoded values exercise the mass/coast equations, not live contact authority.
  @Test(arguments: ["SH141", "SH034", "SH102"])
  func originalImpulseMassAndCoastNeverUseMainMass(id: String) throws {
    let site = try #require(OriginalStationSite(rawValue: id))
    let identity = StationInertialIdentity.originalStation(site.identity(world: UUID()))
    let expectedMass = id == "SH141" ? 2_000_000.0 : 12_000_000.0
    #expect(identity.sourceMassKilograms == expectedMass)
    let zero: [String: Double] = ["x": 0, "y": 0, "z": 0]
    var root: [String: Any] = [
      "segment": "impact", "refusedStepDuration": 0, "refusedMotionTime": 0,
      "refusedSteps": 0, "station": try object(JSONEncoder().encode(identity)),
      "massKilograms": expectedMass, "displacement": zero,
      "momentum": ["x": expectedMass, "y": 0, "z": 0], "physicalTime": 1,
      "contacts": 1, "priorDisplacement": zero, "priorMomentum": zero,
      "priorTime": 0, "impactTime": 1,
    ]
    let state = try JSONDecoder().decode(
      NativeStationInertia.self, from: JSONSerialization.data(withJSONObject: root))
    #expect(state.valid && state.velocity == Vector3(1, 0, 0))
    #expect(state.offset(at: 1.5) == Vector3(0.5, 0, 0))
    root["massKilograms"] = 1_000_000_000.0
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        NativeStationInertia.self, from: JSONSerialization.data(withJSONObject: root))
    }
  }

  @Test func remoteUtilityIsSeparateSourceWithoutDispatch() throws {
    let owner = UUID()
    let source = try NativeStationSource.requireBindings()
    let dhole = try #require(source.first { $0.site == .dhole })
    let utility = try #require(source.first { $0.site == .remoteUtility })
    #expect(dhole.catalogueShipID == utility.catalogueShipID)
    #expect(dhole.physical == utility.physical)
    #expect(dhole.identity(world: owner) != utility.identity(world: owner))
    #expect(dhole.identity(world: owner).slot != utility.identity(world: owner).slot)
    #expect(dhole.descriptor.capabilities == [.sealedDispatchBoard])
    #expect(utility.descriptor.capabilities.isEmpty)
    #expect(OriginalStationSite.remoteUtility.sealedDispatchDefinition == nil)
  }

  @Test func destructibleDockingExceptionDoesNotChangeTheMainPolicy() throws {
    for id in ["SH141", "SH034", "SH102"] {
      let ship = try #require(ShipCatalogue.ship(id))
      #expect(ship.catalogue.damagePolicy == .destructible)
      #expect(ship.catalogue.valid(shipID: id, performance: ship.game, nativeCombat: ship.nativeCombat))
    }
    let main = try #require(ShipCatalogue.ship("SH028"))
    #expect(main.catalogue.damagePolicy == .activeStationIndestructible)
    var root = try object(JSONEncoder().encode(main.catalogue))
    root["damagePolicy"] = ShipCatalogueDamagePolicy.destructible.rawValue
    let changed = try JSONDecoder().decode(
      ShipCatalogueMetadata.self, from: JSONSerialization.data(withJSONObject: root))
    #expect(!changed.valid(shipID: main.id, performance: main.game, nativeCombat: main.nativeCombat))
  }

  private func object(_ data: Data) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }
}
