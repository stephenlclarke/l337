import Foundation
import Testing

@testable import L337Core

struct OriginalFleetPhysicalRecordUnitTests {
  @Test func okapiAndSaigaEmptyBudgetsBindActualCalibrationsWithoutNativeOrLoadedMassAuthority() throws {
    let record = try OriginalFleetPhysicalData.record(for: "SH029")
    let ship = try #require(ShipCatalogue.ship("SH029"))
    let physical = try #require(ship.physicalSourceContract)
    #expect(record.dryMassKilograms == 45520 && record.metresPerSourceUnit == 1)
    #expect(record.detailedSourceSHA256 == "0d0741f3c0a1eed7595b65274eab5726bc1b22c258b6943f6fdb5332931e91b7")
    #expect(physical.model.sourceSHA256 == "585cb9a7f47fb13f6249c09f2ccc262eb852c98ad10721a95730b68fc4eb7b5c")
    #expect(physical.metresPerSourceUnit == 1 && physical.nativeTriangles == 120)
    #expect(physical.engineering?.id == ship.id)
    #expect(physical.engineering?.centreOfMassMetres == record.centreOfMassMetres)
    #expect(physical.engineering?.inertiaAboutCentreOfMassKgM2 == record.inertiaAboutCentreOfMassKgM2)
    let runtime = try #require(OriginalFleetRuntimeHullSource.source(for: ship.id))
    #expect(runtime.engineering?.id == ship.id && runtime.mesh.vertices == physical.physicalMesh.vertices)
    let saiga = try #require(ShipCatalogue.ship("SH061")?.physicalSourceContract)
    let saigaRecord = try OriginalFleetPhysicalData.record(for: "SH061")
    #expect(saigaRecord.dryMassKilograms == 284291 && saigaRecord.metresPerSourceUnit == 20)
    #expect(saiga.metresPerSourceUnit == 20 && saiga.engineering?.id == "SH061")
    #expect(saiga.engineering?.centreOfMassMetres == saigaRecord.centreOfMassMetres)
    #expect(saiga.engineering?.inertiaAboutCentreOfMassKgM2 == saigaRecord.inertiaAboutCentreOfMassKgM2)
    #expect(saiga.nativeTriangles == 1720)
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH061") == nil)
    #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
      id: "SH061", sourceFaces: 1720, maximum: 512)) {
      try OriginalFleetCurrentHullSource(id: "SH061")
    }
  }

  @Test func frozenSourceBudgetsKeepMetresOriginalOriginAndFullPositiveInertia() throws {
    #expect(OriginalFleetPhysicalData.registrations.count == 143)
    for id in OriginalFleetPhysicalData.registrations.keys {
      let record = try OriginalFleetPhysicalData.record(for: id)
      let binding = try #require(OriginalFleetPhysicalData.registrations[id])
      #expect(record.validates(source: binding))
      #expect(record.coordinateUnits == "metres")
      #expect(record.metresPerSourceUnit == binding.calibration.metresPerSourceUnit)
      #expect(record.sourceOriginUnchanged && record.sourceGeometryNotEdited)
      #expect(record.dryMassKilograms > 0 && record.stockMassKg > 0)
      #expect(record.roundingReserveKg >= 0 && record.roundingReserveKg < 1)
      #expect(record.reserveLocationMetres == record.centreOfMassMetres)
      #expect(record.inertiaAboutCentreOfMassKgM2.count == 9)
      #expect(record.status == "NEW_AUTHORED_SOURCE_BUDGET_NOT_NATIVE_QUALIFICATION")
    }
    // Literals are reproducible outputs of the adopted new model, not recovered measurements.
    let zebu = try OriginalFleetPhysicalData.record(for: "SH036")
    let eagle = try OriginalFleetPhysicalData.record(for: "SH043")
    #expect(zebu.dryMassKilograms == 64051 && eagle.dryMassKilograms == 295038)
    #expect(zebu.centreOfMassMetres.contains { abs($0) > 0.01 })
  }

  @Test(arguments: ["SH008", "SH009", "SH026", "SH123", "Zebu"])
  func absentSourceCannotBorrowAnotherMassByNameOrFamily(_ id: String) {
    #expect(throws: OriginalFleetPhysicalData.Failure.unissued(id)) {
      try OriginalFleetPhysicalData.record(for: id)
    }
  }

  @Test func alteredAndMissingPhysicalResourcesRefuseTheAtomicColdLoad() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.copyItem(at: OriginalFleetPhysicalData.folder, to: root)
    #expect(try OriginalFleetPhysicalData.load(from: root).count == 143)
    let file = root.appendingPathComponent("SH036.json")
    let original = try Data(contentsOf: file)
    var changed = original
    changed[changed.startIndex] = 0x20
    try changed.write(to: file)
    #expect(throws: OriginalFleetPhysicalData.Failure.invalidResource("SH036")) {
      try OriginalFleetPhysicalData.load(from: root)
    }
    try original.write(to: file)
    try FileManager.default.removeItem(at: file)
    #expect(throws: OriginalFleetPhysicalData.Failure.unavailable) {
      try OriginalFleetPhysicalData.load(from: root)
    }
  }

  @Test func sourceBudgetValidationRejectsChangedUnitsOriginAndSingularTensor() throws {
    let file = OriginalFleetPhysicalData.folder.appendingPathComponent("SH036.json")
    let original = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    let registration = try #require(OriginalFleetPhysicalData.registrations["SH036"])
    for key in ["metresPerSourceUnit", "sourceOriginUnchanged", "inertiaAboutCentreOfMassKgM2"] {
      var invalid = original
      switch key {
      case "metresPerSourceUnit": invalid[key] = 2
      case "sourceOriginUnchanged": invalid[key] = false
      default: invalid[key] = Array(repeating: 0.0, count: 9)
      }
      let decoded = try JSONDecoder().decode(
        OriginalFleetPhysicalRecord.self, from: JSONSerialization.data(withJSONObject: invalid))
      #expect(!decoded.validates(source: registration))
    }
  }

  @Test func relativeCalibrationIsExplicitPerSourceAndCannotBorrowAMetreOrOtherScale() throws {
    let id = "SH001"
    let file = OriginalFleetPhysicalData.folder.appendingPathComponent(id + ".json")
    let original = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    let registration = try #require(OriginalFleetPhysicalData.registrations[id])
    let record = try OriginalFleetPhysicalData.record(for: id)
    #expect(record.dryMassKilograms == 62470)
    #expect(record.metresPerSourceUnitExact == "40000/3411")
    for key in ["metresPerSourceUnit", "metresPerSourceUnitExact", "targetDetailedLengthMetres",
      "sourceCoordinateUnits", "scaleStatus", "roleMapSHA256"] {
      var invalid = original
      switch key {
      case "metresPerSourceUnit": invalid[key] = 1
      case "targetDetailedLengthMetres": invalid[key] = 41
      case "roleMapSHA256": invalid[key] = OriginalFleetPhysicalData.roleMapSHA256
      default: invalid[key] = "metres"
      }
      let decoded = try JSONDecoder().decode(
        OriginalFleetPhysicalRecord.self, from: JSONSerialization.data(withJSONObject: invalid))
      #expect(!decoded.validates(source: registration))
    }
    for object in ["SH040", "SH125", "SH156", "SH161", "SH162", "SH164", "SH171"] {
      #expect(try OriginalFleetPhysicalData.record(for: object).dryMassKilograms > 0)
    }
    let saigaFile = OriginalFleetPhysicalData.folder.appendingPathComponent("SH061.json")
    let saigaJSON = try #require(
      JSONSerialization.jsonObject(with: Data(contentsOf: saigaFile)) as? [String: Any])
    let saigaBinding = try #require(OriginalFleetPhysicalData.registrations["SH061"])
    let saiga = try OriginalFleetPhysicalData.record(for: "SH061")
    #expect(saigaBinding.calibration == .existingRelative(scale: 20, exact: "20"))
    #expect(saiga.metresPerSourceUnitExact == "20" && saiga.targetDetailedLengthMetres == nil)
    #expect(saiga.scaleStatus == "EXISTING_PER_ID_CALIBRATION_RETAINED_NO_R3_TARGET_FIT")
    for key in ["metresPerSourceUnit", "metresPerSourceUnitExact", "targetDetailedLengthMetres",
      "sourceCoordinateUnits", "scaleStatus"] {
      var invalid = saigaJSON
      switch key {
      case "metresPerSourceUnit": invalid[key] = 1
      case "targetDetailedLengthMetres": invalid[key] = 40
      case "scaleStatus": invalid[key] = "NEW_ROOT_ADOPTED_UNIFORM_ENGINEERING_SCALE_NOT_RECOVERED"
      default: invalid[key] = "metres"
      }
      let decoded = try JSONDecoder().decode(
        OriginalFleetPhysicalRecord.self, from: JSONSerialization.data(withJSONObject: invalid))
      #expect(!decoded.validates(source: saigaBinding))
    }
  }
}
