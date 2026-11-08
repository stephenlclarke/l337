import Foundation
import Testing

@testable import L337Core

struct BisonBedFeedCandidateV4Tests {
  @Test
  func exactV4SeparatesGasScopesAndUnqualifiedFeedRequirements() throws {
    let source = try BisonBedFeedCandidateV4.load()
    #expect(source.header.id != source.parent.header.id)
    #expect(source.header.parentCommit == BisonCommissioningCandidateV3.sourceCommit)
    #expect(source.inputs.implementationParentCommit == source.header.parentCommit)
    #expect(source.totalThermalCO2SourceStockKg == 14)
    #expect(source.allCircuitGasSourceReserveKg == 0.025)
    #expect(source.priorOutsideTankInFlightSourceBoundKg == 0.002)
    #expect(source.results.gasInventoryUpperComponentsKg["tankHeadspace"] != nil)
    #expect(source.results.phaseStates.allSatisfy { $0.bodyIndependentThermalCO2TotalKg == 14 })
    #expect(source.design.feed.qualifiedGammaRange == [1.2, 1.4])
    #expect(source.design.phase.qualifiedCompressibilityFactorRange == [0.9, 1.1])
    #expect(!source.design.phase.actualPhaseOrFiniteStockObserved)
    #expect(!source.design.phase.compressibilityOrHeatCapacityObserved)
    #expect(!source.design.feed.singlePhaseAndValveTransientsObserved)
    #expect(!source.design.reactor.ErgunMultiplierOrViscosityObserved && !source.design.reactor.reactionKineticsQualified)
    #expect(source.design.feed.minimumMeteringDischargeCoefficient == 0.7)
    #expect(source.design.reactor.maximumQualifiedErgunMultiplier == 5)
    #expect(source.design.feed.minimumRecuperatorConductanceWattsPerKelvin == 0.3)
    #expect(source.results.layout.innerPressureDivider.noUnmeteredBypassInGeometricConstruction)
    #expect(!source.results.layout.innerPressureDivider.sealStrengthAndUniformDistributionQualified)
    #expect(source.results.layout.screens.count == 2)
    #expect(source.results.layout.screens.allSatisfy { $0.holeCount == [500, 231] })
    #expect(!source.results.oldSaturatedIdealChoke.equilibriumGasConditionPass)
    #expect(!source.results.phaseValveTransientOrKineticsQualified && source.results.actualObservations.isEmpty)
    #expect(source.results.currentCarrierServiceHeatJoules == 67622400)
    #expect(!source.sourceQualifiedForBirth)
  }

  @Test
  func changedPhaseRigidSnapshotsCannotBecomeOperatingTensor() throws {
    let source = try BisonBedFeedCandidateV4.load()
    #expect(source.rigid.freeRespiratoryGasVolumeCubicMetres == 1.4518772072318467)
    #expect(source.rigid.freeRespiratoryGasVolumeCubicMetres != source.parent.material.connectedFreeGasVolumeCubicMetres)
    #expect(source.rigid.portableStates.count == 2 && source.contacts.cases.count == 8)
    #expect(source.rigid.portableStates[0].inertiaAboutCentreOfMassKgM2
      != source.parent.physicalDelta.portableStates[0].inertiaAboutCentreOfMassKgM2)
    #expect(source.rigid.portableStates[0].id == "finite-phase-feed-state-0")
    #expect(!source.rigid.wall.materialQualificationObserved && source.rigid.actualObservations.isEmpty)
    #expect(source.rigid.canonicalDryAggregatePreserved && source.rigid.canonicalOuterGeometryUnchanged)
    #expect(source.criteria.unchangedLimits.CO2ThermalStockKg == 14)
    #expect(source.criteria.unchangedLimits.paidForceNewtons == 4000 && source.criteria.unchangedLimits.paidWorkJoules == 2400)
    let priorHeatpath = try #require(source.parent.thermal.portable.finiteCryothermalHardwareAllocationKg["heatpathAndWallCollector"])
    #expect(source.results.layout.remainingHotHeatpathMassKg < priorHeatpath)
    // Third phase record is source packing stress, not an operating grant.
    #expect(source.results.phaseStates[2].capturedCO2Kg == 12)
    #expect(source.criteria.maximumCapturedPlusReservedGasKg == 12)
    #expect(throws: BisonCommissioningCandidateV3.Refusal.unsupportedRuntimeDimension(.operatingVariableMassTensor)) {
      try source.parent.requireRuntimeSupport(.operatingVariableMassTensor)
    }
  }

  @Test(arguments: ["v3-selector-alias", "wrong-parent", "missing-divider", "unmetered-bypass", "added-gas",
    "inflight-bound-as-allgas", "observed-phase-grant", "old-rigid-schema", "extra-file", "observed-EOS",
    "no-superheat", "weakened-resistance"])
  func exactV4RejectsChangedSchemaScopeAndForgedAuthority(fault: String) throws {
    let folder = try BisonBedFeedCandidateV4.resourceFolder()
    var assets = try BisonCommissioningCandidateV3.readAssets(from: folder, expectedPins: BisonBedFeedCandidateV4.assetPins)
    let parent = try BisonCommissioningCandidateV3.load()
    func edit(_ name: String, _ action: (inout [String: Any]) throws -> Void) throws {
      let bytes = try #require(assets[name])
      let decoded = try JSONSerialization.jsonObject(with: bytes)
      var value = try #require(decoded as? [String: Any])
      try action(&value)
      assets[name] = try JSONSerialization.data(withJSONObject: value)
    }
    switch fault {
    case "v3-selector-alias": try edit("candidate-source.json") { $0["id"] = parent.header.id }
    case "wrong-parent": try edit("candidate-source.json") { $0["parentCommit"] = BisonBedFeedCandidateV4.thermalBaseCommit }
    case "missing-divider", "unmetered-bypass":
      try edit("bed-feed-results.json") { value in
        var layout = try #require(value["layout"] as? [String: Any])
        if fault == "missing-divider" { layout.removeValue(forKey: "innerPressureDivider") }
        else {
          var divider = try #require(layout["innerPressureDivider"] as? [String: Any])
          divider["noUnmeteredBypassInGeometricConstruction"] = false
          layout["innerPressureDivider"] = divider
        }
        value["layout"] = layout
      }
    case "added-gas", "observed-EOS":
      try edit("bed-feed-design.json") { value in
        var phase = try #require(value["phase"] as? [String: Any])
        if fault == "added-gas" { phase["totalThermalCO2StockKg"] = 14.025 }
        else { phase["compressibilityOrHeatCapacityObserved"] = true }
        value["phase"] = phase
      }
    case "inflight-bound-as-allgas", "weakened-resistance":
      try edit("bed-feed-design.json") { value in
        var reactor = try #require(value["reactor"] as? [String: Any])
        if fault == "inflight-bound-as-allgas" { reactor["maximumGasInventoryKg"] = 0.002 }
        else { reactor["maximumQualifiedErgunMultiplier"] = 1 }
        value["reactor"] = reactor
      }
    case "observed-phase-grant", "no-superheat":
      try edit("bed-feed-design.json") { value in
        var feed = try #require(value["feed"] as? [String: Any])
        if fault == "observed-phase-grant" { feed["singlePhaseAndValveTransientsObserved"] = true }
        else {
          feed["minimumMeteringStagnationKelvin"] = 190
          feed["maximumMeteringStagnationKelvin"] = 190
        }
        value["feed"] = feed
      }
    case "old-rigid-schema":
      let parentFolder = try BisonCommissioningCandidateV3.resourceFolder()
      let prior = try BisonCommissioningCandidateV3.readAssets(from: parentFolder)
      assets["rigid-source-delta.json"] = prior["source-physical-delta.json"]
    case "extra-file": assets["alias.json"] = Data()
    default: Issue.record("Unknown V4 source control"); return
    }
    #expect(throws: (any Error).self) { try BisonBedFeedCandidateV4.decode(assets, parent: parent) }
  }

  @Test(arguments: BisonBedFeedCandidateV4.FeedRuntimeDimension.allCases)
  func newFeedOwnersRefuseActualApparatusUse(dimension: BisonBedFeedCandidateV4.FeedRuntimeDimension) throws {
    let source = try BisonBedFeedCandidateV4.load()
    #expect(throws: BisonBedFeedCandidateV4.Refusal.unsupportedFeedRuntimeDimension(dimension)) {
      try source.requireFeedRuntimeSupport(dimension)
    }
  }

  @Test
  func actualV4RequestCannotAllocateOrChangeReviewedPrivateOwner() throws {
    let source = try BisonBedFeedCandidateV4.load()
    let (initialGame, request, owner, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var game = initialGame
    let context = try #require(game.gameplayContext())
    var proposed = request
    proposed.currentNewtKitConfiguration = source.header.id
    let before = game
    #expect(throws: BisonUnitJournalError.staleContext) {
      try game.reserveBisonUnobservedUnits(request: proposed, context: context)
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    let journal = try #require(game.commander.savedBisonUnitAllocations)
    #expect(try journal.owner(for: request, in: game) == owner)
    #expect(owner.units.allSatisfy { $0.thermal == .unobserved && $0.gas == .unobserved && $0.operative == .unobserved })
    #expect(!source.sourceQualifiedForBirth)
  }

  @Test
  func reviewedReaderKeepsDefaultAndDistinctV4ResourceSets() throws {
    let previous = try BisonCommissioningCandidateV3.resourceFolder()
    let current = try BisonBedFeedCandidateV4.resourceFolder()
    let oldAssets = try BisonCommissioningCandidateV3.readAssets(from: previous)
    #expect(oldAssets.count == 12)
    #expect(throws: BisonCommissioningCandidateV3.Refusal.resourceSet) {
      try BisonCommissioningCandidateV3.readAssets(from: current)
    }
    let newAssets = try BisonCommissioningCandidateV3.readAssets(from: current, expectedPins: BisonBedFeedCandidateV4.assetPins)
    #expect(newAssets.count == 9)
    let parent = try BisonCommissioningCandidateV3.load()
    let source = try BisonBedFeedCandidateV4.decode(newAssets, parent: parent)
    #expect(source.header.id == BisonBedFeedCandidateV4.configurationID)
  }
}
