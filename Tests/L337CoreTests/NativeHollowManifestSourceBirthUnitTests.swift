import Foundation
import Testing

@testable import L337Core

/// Controlled source proposals only; no actual contact, manufacture or person life is exercised.
struct NativeHollowManifestSourceBirthUnitTests {
  private func input(sequence: UInt64 = 500) throws -> NativeHollowManifestSourceBirth.Input {
    let owner = UUID()
    func dock(_ system: SystemIdentity, sequence: UInt64, visit: UInt64, time: Double)
      -> NativeMainStationDockReceipt
    {
      .init(
        station: .init(
          world: owner, system: system,
          resource: Game.worldResourceIdentity(
            "main-station-v1:main-orbital:\(system.galaxy):\(system.system)")),
        actor: .init(system: system, visit: visit, entity: 1), commanderOwner: owner,
        sequence: sequence, calendarSeconds: time)
    }
    let saleDock = dock(.init(galaxy: 0, system: 7), sequence: 1, visit: 1, time: 10)
    let price = try #require(
      OriginalLiveMarkets.initialQuote(galaxy: 0, system: 7, commodity: 13)
    ).bidPrice
    let sale = NativeFirstCommoditySale(
      operation: UUID(), owner: owner, commodity: 13, dock: saleDock,
      physicalTime: 10, calendarOperation: 1, unitPrice: price, quantity: 2,
      before: .init(stock: 20, cargo: 2, credits: 100),
      after: .init(stock: 22, cargo: 0, credits: 100 + 2 * price))
    return .init(
      mission: UUID(), owner: owner, commission: UUID(), carrier: UUID(), inventoryRevision: 3,
      dock: dock(NativeHollowManifestDefinition.issuer, sequence: 2, visit: 2, time: 20),
      sale: sale, physicalTime: 20, firstSourceSequence: sequence)
  }

  private func changed<T: Codable>(_ value: T, field: String, replacement: Any) throws -> T {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object[field] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }

  private func object<T: Encodable>(_ value: T) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
  }

  @Test func deterministicProposalHasOneMasterTwoDistinctOriginalsAndSevenCausalOperations() throws
  {
    let request = try input()
    let birth = try NativeHollowManifestSourceBirth.preparing(request)
    #expect(birth.shapeValid && birth.input == request)
    #expect(birth.operations.count == 7 && birth.originals.count == 2)
    #expect(birth.operations.map(\.sequence) == Array(UInt64(500)...506))
    #expect(birth.nextSourceSequence == 507)
    #expect(birth.operations.filter { $0.kind == .masterCreated }.count == 1)
    let masterOperation = try #require(birth.operations.first)
    #expect(masterOperation.parent == request.commission)
    #expect(masterOperation.object == birth.master.id)
    #expect(
      Set(birth.originals.map(\.slot))
        == Set(
          NativeHollowManifestOriginalSealBinding.Slot.allCases))
    let originalIDs = birth.originals.flatMap {
      [$0.source, $0.hull, $0.captain, $0.seal, $0.imprint]
    }
    #expect(Set(originalIDs + [birth.master.id]).count == 11)
    #expect(Set(birth.operations.map(\.id)).count == 7)
    for original in birth.originals {
      #expect(original.master == birth.master.id)
      #expect(original.operatingCrew == 1 && original.intrinsicCrewQuarters == 1)
      let assignment = try #require(birth.operations.first { $0.id == original.assignment })
      let manufacture = try #require(birth.operations.first { $0.id == original.manufacture })
      let attachment = try #require(birth.operations.first { $0.id == original.attachment })
      #expect(assignment.kind == .hullAndCaptainAssigned && assignment.object == original.hull)
      #expect(manufacture.parent == birth.master.operation && manufacture.object == original.seal)
      #expect(attachment.parent == manufacture.id && attachment.object == original.hull)
      #expect(
        assignment.sequence < manufacture.sequence && manufacture.sequence < attachment.sequence)
    }
    #expect(try NativeHollowManifestSourceBirth.preparing(request) == birth)
    #expect(try NativeHollowManifestSourceBirth.preparing(request, existing: birth) == birth)
  }

  @Test func approvedTemplateAndExplicitLocalFitDoNotInstallCatalogueCapacities() throws {
    let birth = try NativeHollowManifestSourceBirth.preparing(input())
    let geometry = try NativeC03SealGeometry.onager.get()
    #expect(birth.rootDesign == geometry.rootDesign)
    #expect(birth.master.template == geometry.sealDesign)
    #expect(birth.master.template.rawMesh.vertices.count == 64)
    #expect(birth.master.template.rawMesh.faces.count == 96)
    let fit = birth.fit
    #expect(fit.hullEnergy == 220 && fit.recharge == 3.1 && fit.sealEnergy == 16)
    #expect(fit.maximumSpeed == 39 && fit.acceleration == 11)
    #expect(fit.pitch == 0.91 && fit.yaw == 0.84 && fit.roll == 1.03)
    #expect(fit.fittedMissiles == 0 && fit.fittedGuns == 0 && fit.fittedShields == 0)
    #expect(fit.fittedEscapeEquipment == 0 && !fit.fittedECM && fit.ordinaryCargoTonnes == 0)
    #expect(NativeHollowManifestSourceBirth.UnresolvedDependency.allCases.count == 6)
  }

  @Test func supersededInspectionStatisticsAndInventedAccommodationCannotPassCurrentBirth() throws {
    let birth = try NativeHollowManifestSourceBirth.preparing(input())
    for (field, value) in [("hullEnergy", 230.0), ("recharge", 3.2), ("maximumSpeed", 37.7)] {
      let fit = try changed(birth.fit, field: field, replacement: value)
      let invalid = try changed(birth, field: "fit", replacement: object(fit))
      #expect(!invalid.shapeValid)
      #expect(throws: (any Error).self) { try NativeHollowManifestBirthCodec.encode(invalid) }
    }
    let original = try #require(birth.originals.first)
    for field in ["operatingCrew", "intrinsicCrewQuarters"] {
      let altered = try changed(original, field: field, replacement: 6)
      let originals = [try object(altered), try object(birth.originals[1])]
      let invalid = try changed(birth, field: "originals", replacement: originals)
      #expect(!invalid.shapeValid)
    }
    #expect(birth.shapeValid)
  }

  @Test func wrongOwnerLocationHistoryAndSaleBalanceRefuseWithoutChangingInput() throws {
    let original = try input()
    var wrongDock = try #require(object(original.dock) as? [String: Any])
    wrongDock["station"] = try object(original.sale.dock.station)
    wrongDock["actor"] = try object(original.sale.dock.actor)
    let wrongSale = try changed(original.sale, field: "quantity", replacement: 3)
    for invalid in [
      try changed(original, field: "owner", replacement: UUID().uuidString),
      try changed(original, field: "dock", replacement: wrongDock),
      try changed(original, field: "sale", replacement: object(wrongSale)),
      try changed(original, field: "physicalTime", replacement: 9),
      try changed(original, field: "inventoryRevision", replacement: UInt64(Int64.max)),
    ] {
      #expect(!invalid.shapeValid)
      #expect(throws: (any Error).self) { try NativeHollowManifestSourceBirth.preparing(invalid) }
    }
    let laterSaleDock = try changed(original.sale.dock, field: "sequence", replacement: 3)
    let laterSale = try changed(original.sale, field: "dock", replacement: object(laterSaleDock))
    let backdated = try changed(original, field: "sale", replacement: object(laterSale))
    #expect(laterSale.valid && !backdated.shapeValid)
    #expect(original.shapeValid && original.firstSourceSequence == 500)
  }

  @Test func sourceSequenceCapacityReservesWholeBirthBeforeAnyOutput() throws {
    let limit = UInt64(Int64.max)
    for sequence in [UInt64(0), limit - 7, limit, UInt64.max] {
      let request = try input(sequence: sequence)
      #expect(throws: (any Error).self) { try NativeHollowManifestSourceBirth.preparing(request) }
    }
    let last = try NativeHollowManifestSourceBirth.preparing(input(sequence: limit - 8))
    #expect(last.nextSourceSequence == limit - 1 && last.shapeValid)
  }

  @Test func changedCommissionOrWitnessCannotResetExistingOriginals() throws {
    let request = try input()
    let existing = try NativeHollowManifestSourceBirth.preparing(request)
    for field in ["owner", "mission", "commission", "carrier"] {
      let foreign = try changed(request, field: field, replacement: UUID().uuidString)
      #expect(throws: (any Error).self) {
        try NativeHollowManifestSourceBirth.preparing(foreign, existing: existing)
      }
    }
    let changedTime = try changed(request, field: "physicalTime", replacement: 21)
    #expect(throws: (any Error).self) {
      try NativeHollowManifestSourceBirth.preparing(changedTime, existing: existing)
    }
    #expect(existing.input == request && existing.nextSourceSequence == 507)
    #expect(try NativeHollowManifestSourceBirth.preparing(request, existing: existing) == existing)
  }

  @Test func discardingOrRefusingProposalDoesNotConsumeSequenceOrReplacePublishedValue() throws {
    let request = try input()
    let discarded = try NativeHollowManifestSourceBirth.preparing(request)
    let retry = try NativeHollowManifestSourceBirth.preparing(request)
    #expect(discarded == retry && request.firstSourceSequence == 500)
    let corrupted = try changed(retry, field: "nextSourceSequence", replacement: 508)
    #expect(throws: (any Error).self) {
      try NativeHollowManifestSourceBirth.preparing(request, existing: corrupted)
    }
    #expect(retry.shapeValid && retry.nextSourceSequence == 507)
    // This proves local pure-value rollback only; there is no production save publisher here.
  }

  @Test func decodedManufactureAndGeometryRecordsRemainUntrustedAndMustExactlyMatch() throws {
    let birth = try NativeHollowManifestSourceBirth.preparing(input())
    let decoded = try JSONDecoder().decode(
      NativeHollowManifestSourceBirth.self, from: JSONEncoder().encode(birth))
    #expect(decoded == birth && decoded.shapeValid)
    var operations = birth.operations
    operations[2] = try changed(operations[2], field: "parent", replacement: UUID().uuidString)
    let wrongParent = try changed(birth, field: "operations", replacement: object(operations))
    let fewer = try changed(birth, field: "originals", replacement: object([birth.originals[0]]))
    var master = try #require(object(birth.master) as? [String: Any])
    master["template"] = try object(birth.rootDesign)
    let wrongGeometry = try changed(birth, field: "master", replacement: master)
    for bad in [wrongParent, fewer, wrongGeometry] {
      #expect(!bad.shapeValid)
      #expect(throws: (any Error).self) {
        try NativeHollowManifestSourceBirth.preparing(birth.input, existing: bad)
      }
    }
    let fields = try #require(object(birth) as? [String: Any])
    #expect(
      Set(fields.keys)
        == Set([
          "input", "rootDesign", "master", "originals", "operations", "fit", "nextSourceSequence",
        ]))
    let original = try #require(object(birth.originals[0]) as? [String: Any])
    #expect(original["actor"] == nil && original["pose"] == nil && original["velocity"] == nil)
  }
}
