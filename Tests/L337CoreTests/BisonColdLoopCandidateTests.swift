import Foundation
import Testing

@testable import L337Core

struct BisonColdLoopCandidateTests {
  private func load() throws -> BisonColdLoopCandidate {
    let folder = try BisonColdLoopCandidate.resourceFolder()
    let parent = try BisonBedFeedCandidateV4.load()
    return try BisonColdLoopCandidate.load(from: folder, parent: parent)
  }

  @Test
  func exactColdSourceSeparatesRequirementsSamplesAndActualStocks() throws {
    let source = try load()
    #expect(source.inputs.baseCommit == BisonBedFeedCandidateV4.sourceCommit)
    #expect(source.design.coolant.species == "pure liquid propane")
    #expect(source.design.coolant.chargedMassKg == 0.945)
    #expect(source.design.accumulator.nitrogenMassKg == 0.010)
    #expect(!source.design.allocation.sourceActualStocksObserved && !source.design.coolant.actualPureChargeOrPhaseObserved)
    #expect(source.design.coldExchanger.minimumCO2GasConductivity == 0.007)
    #expect(source.criteria.unchangedAcceptance.minimumBoundaryConductanceWattsPerKelvin == 80)
    #expect(source.results.primary.sampledColdRows == 48 && source.results.primary.warmPressureStates.count == 121)
    #expect(source.primaryNotes.newBoundsNotPublishedGuarantees.contains { $0.contains("continuous") })
    #expect(!source.results.porePopulationAndTransportQualified && !source.results.coreBodyOrActualContactQualified)
    #expect(!source.operation.bodyBoundary.coreSkinContactCryobiologyQualified)
    #expect(!source.operation.bodyBoundary.arbitraryLocalHeatFluxQualified)
    #expect(source.design.power.unchangedTotalWatts == 42 && source.results.derived.residualColdDumpWatts == 1)
    #expect(source.parent.totalThermalCO2SourceStockKg == 14 && source.parent.allCircuitGasSourceReserveKg == 0.025)
    #expect(!source.delta.preparation.actualPreparationObserved)
    #expect(source.delta.additionalPreparationHeatJoules == 2582050)
    #expect(source.operation.custody.originalOperatingRoles == 12 && source.operation.custody.carrierBodies == 11)
    #expect(source.operation.custody.carrierCell7Empty && source.operation.custody.original7OnlyFrozenNewt)
    #expect(source.operation.custody.privateUnitsRemainUnobserved)
    #expect(!source.operation.custody.identityConsentAwakeFitnessOrAuthorityGranted && !source.sourceQualifiedForBirth)
  }

  @Test
  func finiteLayoutAndNominalTensorsDoNotBecomeOperatingOrQuietState() throws {
    let source = try load()
    #expect(source.layout.geometry.bodyChannels.count == 48 && source.layout.geometry.bodyVerticalPorts.count == 96)
    #expect(source.layout.geometry.coldSlots.count == 80 && source.layout.geometry.ventColumns.count == 4)
    #expect(source.layout.geometry.adapters.count == 2 && source.delta.macroCertificates.count == 25)
    #expect(source.design.allocation.bodyPanelPadPumpAccumulatorPipesFromCradleKg == 18)
    #expect(source.design.allocation.coldPlatesMatrixAndHeadersFromDewarKg == 5)
    #expect(source.delta.baseDry.id == "canonical-dry-reference-gate-open")
    #expect(source.delta.portableStates.count == 2 && source.contacts.cases.count == 8)
    #expect(source.delta.portableStates[0].id == "nominal-cold-loop-phase-state-0-connected-passages-proposed-mechanisms-open")
    #expect(source.delta.portableStates[0].inertiaAboutCentreOfMassKgM2
      != source.parent.rigid.portableStates[0].inertiaAboutCentreOfMassKgM2)
    #expect(!source.delta.wall.materialQualificationObserved && !source.delta.rigidRuntimeConsumerUpdated)
    #expect(!source.delta.actualDiaphragmOrFlowStateQualified && !source.delta.microcellPopulationQualified)
    #expect(source.operation.quietTransition.maximumSecondsUnchanged == 1)
    #expect(!source.operation.quietTransition.actualQuietOrSettledStateObserved)
    #expect(source.operation.quietTransition.requirements.contains { $0.contains("Conserve total P and L") })
    #expect(throws: BisonCommissioningCandidateV3.Refusal.unsupportedRuntimeDimension(.operatingVariableMassTensor)) {
      try source.parent.parent.requireRuntimeSupport(.operatingVariableMassTensor)
    }
  }

  @Test(arguments: ["observed-stock", "dilute-value-as-floor", "quiet-reset", "sampled-continuum",
    "operating-tensor", "diagnostic-floor-waiver", "missing-ports", "wrong-parent"])
  func changedRequirementsCannotAcquireSourceIdentityOrRuntimeAuthority(fault: String) throws {
    let folder = try BisonColdLoopCandidate.resourceFolder()
    var assets = try BisonCommissioningCandidateV3.readAssets(from: folder, expectedPins: BisonColdLoopCandidate.assetPins)
    let parent = try BisonBedFeedCandidateV4.load()
    let name: String
    switch fault {
    case "sampled-continuum": name = "cold-loop-results.json"
    case "operating-tensor": name = "mechanism-source.json"
    case "quiet-reset": name = "finite-operation-requirements.json"
    case "missing-ports": name = "cold-layout.json"
    case "wrong-parent": name = "INPUTS.json"
    default: name = "cold-loop-design.json"
    }
    let bytes = try #require(assets[name])
    let decoded = try JSONSerialization.jsonObject(with: bytes)
    var object = try #require(decoded as? [String: Any])
    switch fault {
    case "observed-stock":
      var allocation = try #require(object["allocation"] as? [String: Any])
      allocation["sourceActualStocksObserved"] = true
      object["allocation"] = allocation
    case "dilute-value-as-floor", "diagnostic-floor-waiver":
      var exchanger = try #require(object["coldExchanger"] as? [String: Any])
      exchanger["minimumCO2GasConductivity"] = fault == "dilute-value-as-floor" ? 0.008651528 : 0.006
      object["coldExchanger"] = exchanger
    case "quiet-reset":
      var quiet = try #require(object["quietTransition"] as? [String: Any])
      quiet["actualQuietOrSettledStateObserved"] = true
      quiet["resetAngularVelocity"] = true
      object["quietTransition"] = quiet
    case "sampled-continuum":
      var primary = try #require(object["primary"] as? [String: Any])
      primary["continuousEnvelopeQualified"] = true
      object["primary"] = primary
    case "operating-tensor": object["rigidRuntimeConsumerUpdated"] = true
    case "missing-ports":
      var geometry = try #require(object["geometry"] as? [String: Any])
      geometry.removeValue(forKey: "bodyVerticalPorts")
      object["geometry"] = geometry
    case "wrong-parent": object["baseCommit"] = BisonCommissioningCandidateV3.sourceCommit
    default: Issue.record("Unknown cold-loop control"); return
    }
    assets[name] = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: BisonColdLoopCandidate.Refusal.resourceIdentity(name)) {
      try BisonColdLoopCandidate.decode(assets, parent: parent)
    }
  }

  @Test(arguments: BisonColdLoopCandidate.RuntimeDimension.allCases)
  func everyNewColdPhysicalOwnerRemainsUnsupported(dimension: BisonColdLoopCandidate.RuntimeDimension) throws {
    let source = try load()
    #expect(throws: BisonColdLoopCandidate.Refusal.unsupportedRuntimeDimension(dimension)) {
      try source.requireRuntimeSupport(dimension)
    }
    #expect(!source.sourceQualifiedForBirth)
  }

  @Test
  func sharedReaderDoesNotAliasParentOrDefaultResourceSets() throws {
    let folder = try BisonColdLoopCandidate.resourceFolder()
    #expect(throws: BisonCommissioningCandidateV3.Refusal.resourceSet) {
      try BisonCommissioningCandidateV3.readAssets(from: folder)
    }
    #expect(throws: BisonCommissioningCandidateV3.Refusal.resourceSet) {
      try BisonCommissioningCandidateV3.readAssets(from: folder, expectedPins: BisonBedFeedCandidateV4.assetPins)
    }
    let source = try load()
    #expect(source.parent.header.id == BisonBedFeedCandidateV4.configurationID)
    #expect(!source.parent.sourceQualifiedForBirth)
  }

  @Test(arguments: ["missing-file", "extra-file", "symlink-root"])
  func coldResourceLookupRejectsIncompleteOrAliasedFolder(fault: String) throws {
    let original = try BisonColdLoopCandidate.resourceFolder()
    let parent = try BisonBedFeedCandidateV4.load()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let candidate = root.appendingPathComponent("cold")
    if fault == "symlink-root" {
      try FileManager.default.createSymbolicLink(at: candidate, withDestinationURL: original)
    } else {
      try FileManager.default.copyItem(at: original, to: candidate)
      if fault == "missing-file" {
        try FileManager.default.removeItem(at: candidate.appendingPathComponent("cold-layout.json"))
      } else {
        try Data().write(to: candidate.appendingPathComponent("runtime-grant.json"))
      }
    }
    #expect(throws: BisonCommissioningCandidateV3.Refusal.resourceSet) {
      try BisonColdLoopCandidate.load(from: candidate, parent: parent)
    }
  }
}
