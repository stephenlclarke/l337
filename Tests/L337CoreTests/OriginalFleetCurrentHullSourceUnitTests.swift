import Testing

@testable import L337Core

struct OriginalFleetCurrentHullSourceUnitTests {
  @Test func everyEngineeringSourceBindsItsExactMetreNativeModelWithoutNormalisingOrBorrowing() throws {
    let ids = Array(OriginalFleetPendingSourceRegistrations.records.keys)
      + Array(OriginalFleetPhysicalData.larvaalMetreRegistrations.keys)
      + OriginalFleetPhysicalData.baselineRegistrations.keys.filter {
        OriginalFleetPhysicalData.baselineRegistrations[$0]?.calibration == .declaredMetres
      }
    for id in ids {
      let source = try OriginalFleetCurrentHullSource(id: id)
      let expected = try #require(OriginalFleetPhysicalData.registrations[id])
      #expect(source.contract.id == id && source.engineering.id == id && source.model.id == id)
      #expect(source.model.sourceSHA256 == expected.nativeSourceSHA256)
      #expect(source.model.sourcePath == expected.nativeSourcePath)
      #expect(source.nativeTriangles > 0 && source.nativeTriangles <= 512)
      #expect(source.mesh.vertices == source.model.nativeDesign.rawMesh.vertices)
      #expect(source.mesh.faces == source.model.nativeDesign.rawMesh.faces)
      #expect(source.mesh.materials == source.model.nativeDesign.rawMesh.materials)
      #expect(source.mesh.faceTextures == source.model.nativeDesign.rawMesh.faceTextures)
      #expect(source.envelope.clearanceRadius > 0)
    }
    let zebu = try OriginalFleetCurrentHullSource(id: "SH036")
    #expect(zebu.contract.name == "Zebu" && zebu.nativeTriangles == 192)
    #expect(zebu.mesh.vertices.first == .init(3.52, 0, -19))
    #expect(zebu.engineering.dryMassKilograms == 64051)
    let harvester = try OriginalFleetCurrentHullSource(id: "SH122")
    let physical = try #require(ShipCatalogue.ship("SH122")?.physicalSourceContract)
    #expect(harvester.engineering.dryMassKilograms == 49810 && harvester.nativeTriangles == 312)
    #expect(physical.engineering?.centreOfMassMetres == harvester.engineering.centreOfMassMetres)
    #expect(physical.engineering?.inertiaAboutCentreOfMassKgM2
      == harvester.engineering.inertiaAboutCentreOfMassKgM2)
    #expect(OriginalFleetRuntimeHullSource.source(for: "SH122") == nil)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
      id: "SH122", sourceFaces: 312)) {
      try OriginalDetailedHullStage.requireRuntime("SH122")
    }
  }

  @Test func relativeSourcesKeepTheirCalibrationAndRefuseOverLimitGeometry() throws {
    for (id, binding) in OriginalFleetPhysicalData.relativeRegistrations {
      let contract = try #require(OriginalFleetR3Data.contract(for: id))
      guard contract.objectKind == .ship else { continue }
      let model = try OriginalFleetShowroomModels.model(for: id)
      if model.nativeDesign.faces.count > 512 {
        #expect(throws: OriginalFleetCurrentHullSource.Failure.nativeLODUnqualified(
          id: id, sourceFaces: model.nativeDesign.faces.count, maximum: 512)) {
          try OriginalFleetCurrentHullSource(id: id)
        }
      } else {
        let source = try OriginalFleetCurrentHullSource(id: id)
        #expect(source.mesh.vertices == model.nativeDesign.rawMesh.vertices.map {
          $0 * binding.calibration.metresPerSourceUnit
        })
        #expect(source.mesh.faces == model.nativeDesign.rawMesh.faces)
        #expect(source.model.coordinateUnits == nil)
      }
    }
    for id in ["SH040", "SH156", "SH161", "SH162", "SH164"] {
      #expect(throws: OriginalFleetCurrentHullSource.Failure.missingCurrentContract(id)) {
        try OriginalFleetCurrentHullSource(id: id)
      }
    }
  }

  @Test func neverForSaleCapitalKeepsItsOwnSourceWithoutAcquiringPurchaseRights() throws {
    let capital = try OriginalFleetCurrentHullSource(id: "SH043")
    #expect(capital.contract.purchasePolicy == .never && !capital.contract.playerFlyable)
    #expect(capital.contract.acquisition == nil)
    #expect(capital.contract.performance?.price == 0)
    #expect(capital.engineering.dryMassKilograms == 295038)
  }

  @Test func missingMassUnitsOrObjectContractHasNoPreviewOrFamilyFallback() {
    for id in ["SH008", "SH009", "SH123"] {
      #expect(throws: OriginalFleetPhysicalData.Failure.unissued(id)) {
        try OriginalFleetCurrentHullSource(id: id)
      }
    }
    for id in ["Zebu", "SH036-extra", "SH141", "SH162"] {
      #expect(throws: OriginalFleetCurrentHullSource.Failure.missingCurrentContract(id)) {
        try OriginalFleetCurrentHullSource(id: id)
      }
    }
  }
}
