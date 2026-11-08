import Foundation
import Testing

@testable import L337Core

struct NativeHollowManifestBirthCodecUnitTests {
  private func fixture() throws -> (NativeHollowManifestSourceBirth, Commander) {
    var commander = Commander()
    try commander.prepareEquipment(legacy: false)
    let owner = try #require(commander.equipmentOwnerID)
    func dock(_ system: SystemIdentity, sequence: UInt64) -> NativeMainStationDockReceipt {
      .init(
        station: .init(
          world: owner, system: system,
          resource: Game.worldResourceIdentity(
            "main-station-v1:main-orbital:\(system.galaxy):\(system.system)")),
        actor: .init(system: system, visit: sequence, entity: 1), commanderOwner: owner,
        sequence: sequence, calendarSeconds: Double(sequence) * 10)
    }
    let saleDock = dock(.init(galaxy: 0, system: 7), sequence: 1)
    let commissionDock = dock(NativeHollowManifestDefinition.issuer, sequence: 2)
    let price = try #require(
      OriginalLiveMarkets.initialQuote(galaxy: 0, system: 7, commodity: 13)
    ).bidPrice
    let sale = NativeFirstCommoditySale(
      operation: UUID(), owner: owner, commodity: 13, dock: saleDock,
      physicalTime: 10, calendarOperation: 0, unitPrice: price, quantity: 1,
      before: .init(stock: 20, cargo: 1, credits: 100),
      after: .init(stock: 21, cargo: 0, credits: 100 + price))
    let birth = try NativeHollowManifestSourceBirth.preparing(
      .init(
        mission: UUID(), owner: owner, commission: UUID(), carrier: UUID(), inventoryRevision: 999,
        dock: commissionDock, sale: sale, physicalTime: 20, firstSourceSequence: 50))
    commander.flightSimulation.enter(saleDock.station.system, arriving: true)
    commander.flightSimulation.enter(commissionDock.station.system, arriving: true)
    commander.flightSimulation.physicalTime = 20
    commander.scriptState.calendarSeconds = 20
    commander.scriptState.firstNativeCommoditySale = sale
    var world = try NativeStationWorld(owner: owner)
    world.mainStations = [saleDock.station, commissionDock.station]
    world.nextMainDockSequence = 3
    commander.nativeStations = world
    return (birth, commander)
  }

  private func raw(_ birth: NativeHollowManifestSourceBirth) throws -> [String: Any] {
    try #require(
      JSONSerialization.jsonObject(
        with: NativeHollowManifestBirthCodec.encode(birth)) as? [String: Any])
  }
  private func bytes(_ raw: Any) throws -> Data {
    try JSONSerialization.data(
      withJSONObject: raw, options: [.sortedKeys, .withoutEscapingSlashes])
  }
  private func decode(_ bytes: Data, _ birth: NativeHollowManifestSourceBirth) throws
    -> NativeHollowManifestSourceBirth
  {
    try NativeHollowManifestBirthCodec.decode(
      bytes, owner: birth.input.owner, mission: birth.input.mission)
  }

  @Test func closedBirthRoundTripRetainsCanonicalTemplateAndAllImmutableOriginalOperations() throws
  {
    let (birth, _) = try fixture()
    let bytes = try NativeHollowManifestBirthCodec.encode(birth)
    #expect(bytes.count <= NativeHollowManifestBirthCodec.maximumBytes)
    let decoded = try decode(bytes, birth)
    #expect(decoded == birth && decoded.shapeValid)
    #expect(try NativeHollowManifestBirthCodec.encode(decoded) == bytes)
    #expect(
      try NativeHollowManifestBirthCodec.decode(
        bytes, owner: birth.input.owner, mission: birth.input.mission, existingBirth: birth)
        == birth)
  }

  @Test func foreignOwnerMissionAndChangedExistingBirthCannotBeImportedOrReset() throws {
    let (birth, _) = try fixture()
    let encoded = try NativeHollowManifestBirthCodec.encode(birth)
    #expect(throws: NativeHollowManifestBirthCodec.Failure.wrongOwner) {
      try NativeHollowManifestBirthCodec.decode(
        encoded, owner: UUID(), mission: birth.input.mission)
    }
    #expect(throws: NativeHollowManifestBirthCodec.Failure.wrongMission) {
      try NativeHollowManifestBirthCodec.decode(encoded, owner: birth.input.owner, mission: UUID())
    }
    let (other, _) = try fixture()
    #expect(throws: NativeHollowManifestBirthCodec.Failure.changedBirth) {
      try NativeHollowManifestBirthCodec.decode(
        encoded, owner: birth.input.owner, mission: birth.input.mission, existingBirth: other)
    }
    #expect(birth.originals.count == 2 && birth.nextSourceSequence == 57)
  }

  @Test func unknownNullDuplicateAndNoncanonicalFormsAreNotSilentlyDiscarded() throws {
    let (birth, _) = try fixture()
    let original = try raw(birth)
    for value in [true as Any, NSNull()] {
      var object = original
      object["inventedSourceAuthority"] = value
      #expect(throws: (any Error).self) { try decode(bytes(object), birth) }
    }
    var nullRequired = original
    nullRequired["originals"] = NSNull()
    #expect(throws: (any Error).self) { try decode(bytes(nullRequired), birth) }
    let canonical = try NativeHollowManifestBirthCodec.encode(birth)
    let fit = try #require(original["fit"])
    var duplicate = Data("{\"fit\":".utf8)
    duplicate.append(try bytes(fit))
    duplicate.append(Data(",".utf8))
    duplicate.append(canonical.dropFirst())
    #expect(throws: NativeHollowManifestBirthCodec.Failure.noncanonical) {
      try decode(duplicate, birth)
    }
    var spaced = canonical
    spaced.append(32)
    #expect(throws: NativeHollowManifestBirthCodec.Failure.noncanonical) {
      try decode(spaced, birth)
    }
  }

  @Test func nestedGeometryUnknownsBadDimensionsAndBrokenCausalParentsRefuse() throws {
    let (birth, _) = try fixture()
    let original = try raw(birth)
    var geometry = try #require(original["rootDesign"] as? [String: Any])
    geometry["unexpectedMaterialAuthority"] = true
    var changed = original
    changed["rootDesign"] = geometry
    #expect(throws: (any Error).self) { try decode(bytes(changed), birth) }
    var vertices = try #require(geometry["vertices"] as? [[Any]])
    vertices[0] = [0, 0]
    geometry.removeValue(forKey: "unexpectedMaterialAuthority")
    geometry["vertices"] = vertices
    changed["rootDesign"] = geometry
    #expect(throws: (any Error).self) { try decode(bytes(changed), birth) }
    var operations = try #require(original["operations"] as? [[String: Any]])
    operations[2]["parent"] = UUID().uuidString
    changed = original
    changed["operations"] = operations
    #expect(throws: (any Error).self) { try decode(bytes(changed), birth) }
  }

  @Test func originalOperationAndGeometryArrayBoundsApplyBeforeFoundationDecode() throws {
    let (birth, _) = try fixture()
    let original = try raw(birth)
    for field in ["originals", "operations"] {
      var changed = original
      var array = try #require(original[field] as? [Any])
      array.append(try #require(array.first))
      changed[field] = array
      #expect(throws: NativeHollowManifestBirthCodec.Failure.resourceLimit) {
        try NativeHollowManifestBirthCodec.preflight(bytes(changed))
      }
    }
    for field in ["vertices", "faces"] {
      for template in [false, true] {
        var changed = original
        var master = try #require(original["master"] as? [String: Any])
        var geometry = try #require(
          (template ? master["template"] : original["rootDesign"]) as? [String: Any])
        var array = try #require(geometry[field] as? [Any])
        array.append(try #require(array.first))
        geometry[field] = array
        if template {
          master["template"] = geometry
          changed["master"] = master
        } else {
          changed["rootDesign"] = geometry
        }
        #expect(throws: NativeHollowManifestBirthCodec.Failure.resourceLimit) {
          try NativeHollowManifestBirthCodec.preflight(bytes(changed))
        }
      }
    }
    #expect(throws: NativeHollowManifestBirthCodec.Failure.resourceLimit) {
      try NativeHollowManifestBirthCodec.preflight(Data("{\"vertices\":[[1,2,3,4]]}".utf8))
    }
  }

  @Test func byteStringDepthAndScalarBoundsPrecedeFoundationAllocation() throws {
    for malformed in [
      Data(repeating: 32, count: NativeHollowManifestBirthCodec.maximumBytes + 1),
      Data(("{\"extra\":\"" + String(repeating: "x", count: 4097) + "\"}").utf8),
      Data((String(repeating: "[", count: 17) + "0" + String(repeating: "]", count: 17)).utf8),
      Data(("[" + String(repeating: "1", count: 65) + "]").utf8),
    ] {
      #expect(throws: NativeHollowManifestBirthCodec.Failure.resourceLimit) {
        try NativeHollowManifestBirthCodec.preflight(malformed)
      }
    }
    for malformed in [Data("{\"open".utf8), Data("[}".utf8)] {
      #expect(throws: (any Error).self) { try NativeHollowManifestBirthCodec.preflight(malformed) }
    }
  }

  @Test func historicalOwnerJoinsKeepOldCarrierAndRejectMissingSaleDockOrFutureHistory() throws {
    let (birth, commander) = try fixture()
    #expect(birth.input.carrier != commander.hullInstanceID)
    #expect(
      NativeHollowManifestBirthCodec.historicalOwnerMatches(
        birth, commander: commander, mission: birth.input.mission))
    var missingSale = commander
    missingSale.scriptState.firstNativeCommoditySale = nil
    var missingDock = commander
    missingDock.nativeStations?.mainStations.removeAll()
    var early = commander
    early.flightSimulation.physicalTime = 19
    var foreignWorld = commander
    var wrongLedger = try NativeStationWorld(owner: UUID())
    wrongLedger.mainStations = try #require(commander.nativeStations).mainStations
    wrongLedger.nextMainDockSequence = 3
    foreignWorld.nativeStations = wrongLedger
    for invalid in [missingSale, missingDock, early, foreignWorld, Commander()] {
      #expect(
        !NativeHollowManifestBirthCodec.historicalOwnerMatches(
          birth, commander: invalid, mission: birth.input.mission))
    }
    #expect(
      !NativeHollowManifestBirthCodec.historicalOwnerMatches(
        birth, commander: commander, mission: UUID()))
    #expect(commander.scriptState.firstNativeCommoditySale == birth.input.sale)
  }
}
