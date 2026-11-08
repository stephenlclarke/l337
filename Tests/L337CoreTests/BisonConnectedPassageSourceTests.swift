import Foundation
import Testing

@testable import L337Core

/// Historical f775 joins; the current mechanism candidate is tested separately.
struct BisonConnectedPassageSourceTests {
  private func load() throws -> BisonColdLoopCandidate {
    let parent = try BisonBedFeedCandidateV4.load()
    return try BisonColdLoopCandidate.load(from: BisonColdLoopCandidate.resourceFolder(), parent: parent)
  }

  @Test
  func connectedInterfacesReachExistingBoresWithoutQualifyingFunctionOrStocks() throws {
    let source = try load()
    #expect(BisonColdLoopCandidate.passageSourceCommit == "f7755ce0cc0226360afc341760c2c9e418443f93")
    #expect(source.passageInputs.physicalBase == BisonColdLoopCandidate.baselineSourceCommit)
    let pump = try #require(source.passageBaseline.connectedFixedAssemblies.first { $0.id == "pump" })
    let valve = try #require(source.passageBaseline.connectedFixedAssemblies.first { $0.id == "valve" })
    #expect(pump.housing.massKg == source.design.mainCircuit.pumpDryMassKg)
    #expect(valve.housing.massKg == source.design.regulator.valveDryMassKg)
    #expect(pump.interfaces.map(\.axis) == [2, 2] && pump.interfaces.map(\.sideMetres) == [0.012, 0.012])
    #expect(valve.interfaces.map(\.axis) == [0, 1] && valve.interfaces.map(\.sideMetres) == [0.008, 0.008])
    #expect(pump.interfaces[0].centreMetres[2] == pump.outer.minimumMetres[2])
    #expect(pump.interfaces[1].centreMetres[2] == pump.outer.maximumMetres[2])
    #expect(pump.interfaces[0].centreMetres[0] == source.layout.geometry.mainReturn[1][0])
    #expect(pump.interfaces[0].centreMetres[1] == source.layout.geometry.mainReturn[1][1])
    #expect(valve.interfaces[0].centreMetres[0] == valve.outer.minimumMetres[0])
    #expect(valve.interfaces[1].centreMetres[1] == valve.outer.maximumMetres[1])
    #expect(valve.interfaces[0].centreMetres[1] == source.layout.geometry.bypass[2][1])
    #expect(valve.interfaces[1].centreMetres[0] == source.layout.geometry.bypass[2][0])
    #expect(pump.fluid.volumeCubicMetres == pump.fluidVolumeCubicMetres)
    #expect(valve.fluid.volumeCubicMetres == valve.fluidVolumeCubicMetres)
    #expect(pump.fluidBoxes.count == 2 && valve.fluidBoxes.count == 3)
    #expect(!pump.pumpOrValveFunctionQualified && !valve.pressureIntegrityQualified)
    #expect(!source.passageBaseline.actualOpenStateObserved && !source.passageBaseline.quietTransitionObserved)
    #expect(!source.passageBaseline.conductivityFloorQualified && !source.sourceQualifiedForBirth)
    #expect(!source.design.allocation.sourceActualStocksObserved)
  }

  @Test
  func bothNominalLoadedReferencesUsePaidFluidRedistributionAndRefittedHousing() throws {
    struct Baseline: Decodable {
      let extraWorkingFluid: BisonCommissioningCandidateV3.SourceMassState
      let portableStates: [BisonCommissioningCandidateV3.SourceMassState]
      let wall: BisonBedFeedCandidateV4.Rigid.Wall
    }
    let source = try load()
    let folder = try BisonColdLoopCandidate.resourceFolder()
    let data = try Data(contentsOf: folder.appendingPathComponent("cold-source-delta.json"))
    let baseline = try JSONDecoder().decode(Baseline.self, from: data)
    #expect(source.passageBaseline.baseDry.id == "canonical-dry-connected-pump-valve")
    #expect(source.passageBaseline.extraWorkingFluid.inertiaAboutCentreOfMassKgM2
      != baseline.extraWorkingFluid.inertiaAboutCentreOfMassKgM2)
    #expect(source.passageBaseline.wall.wallCellEffectiveDensityKgPerCubicMetre != baseline.wall.wallCellEffectiveDensityKgPerCubicMetre)
    for (current, old) in zip(source.passageBaseline.portableStates, baseline.portableStates) {
      #expect(current.id == old.id + "-connected-passages")
      #expect(current.massKg == old.massKg)
      #expect(current.inertiaAboutCentreOfMassKgM2 != old.inertiaAboutCentreOfMassKgM2)
    }
    #expect(source.passageBaseline.fluidRedistributionRawMoments == source.passageExactDelta.liquidRedistribution)
    #expect(source.passageBaseline.fluidRedistributionRawMoments.massKg != 0)
    #expect(source.passageContacts.cases.allSatisfy { value in source.passageBaseline.portableStates.contains { $0.id == value.state } })
    #expect(source.passageExactDelta.unchangedBudgets.nominalOccupiedKg == 372.455)
    #expect(source.passageExactDelta.unchangedBudgets.propaneKg == 0.945)
    #expect(source.passageExactDelta.unchangedBudgets.nitrogenKg == 0.010)
    #expect(!source.passageBaseline.wall.materialQualificationObserved && !source.passageBaseline.rigidRuntimeConsumerUpdated)
    #expect(throws: BisonColdLoopCandidate.Refusal.unsupportedRuntimeDimension(.momentumConservingQuietTransition)) {
      try source.requireRuntimeSupport(.momentumConservingQuietTransition)
    }
  }

  @Test(arguments: ["missing-correction", "baseline-only", "sealed-cavity", "removed-port",
    "whole-box-housing", "old-fluid-moments", "old-contact-cases", "invented-function"])
  func successorRejectsMissingOrAlteredConnectedStructureAndMomentInputs(fault: String) throws {
    let parent = try BisonBedFeedCandidateV4.load()
    let folder = try BisonColdLoopCandidate.resourceFolder()
    var assets = try BisonCommissioningCandidateV3.readAssets(from: folder, expectedPins: BisonColdLoopCandidate.assetPins)
    if fault == "missing-correction" {
      assets.removeValue(forKey: "connected-passage-source.json")
    } else if fault == "baseline-only" {
      for name in assets.keys.filter({ $0.hasPrefix("connected-") }) { assets.removeValue(forKey: name) }
    } else if fault == "old-contact-cases" {
      assets["connected-load-controls.json"] = assets["changed-load-controls.json"]
    } else {
      let bytes = try #require(assets["connected-passage-source.json"])
      let decoded = try JSONSerialization.jsonObject(with: bytes)
      var value = try #require(decoded as? [String: Any])
      if fault == "old-fluid-moments" {
        let priorBytes = try #require(assets["cold-source-delta.json"])
        let decodedPrior = try JSONSerialization.jsonObject(with: priorBytes)
        let prior = try #require(decodedPrior as? [String: Any])
        value["extraWorkingFluid"] = prior["extraWorkingFluid"]
        value["portableStates"] = prior["portableStates"]
      } else if fault == "invented-function" {
        value["pumpOrValveFunctionQualified"] = true
      } else {
        var assemblies = try #require(value["connectedFixedAssemblies"] as? [[String: Any]])
        if fault == "sealed-cavity" { assemblies[0]["fluidBoxes"] = [] }
        if fault == "removed-port" {
          var ports = try #require(assemblies[1]["interfaces"] as? [[String: Any]])
          ports.removeLast()
          assemblies[1]["interfaces"] = ports
        }
        if fault == "whole-box-housing" {
          let priorBytes = try #require(assets["cold-layout.json"])
          let decodedPrior = try JSONSerialization.jsonObject(with: priorBytes)
          let prior = try #require(decodedPrior as? [String: Any])
          let pieces = try #require(prior["pieces"] as? [[String: Any]])
          let wholeBox = try #require(pieces.first { $0["id"] as? String == "pump-fixed-assembly" })
          assemblies[0]["housing"] = wholeBox
        }
        value["connectedFixedAssemblies"] = assemblies
      }
      assets["connected-passage-source.json"] = try JSONSerialization.data(withJSONObject: value)
    }
    if fault == "missing-correction" || fault == "baseline-only" {
      #expect(throws: BisonColdLoopCandidate.Refusal.resourceSet) {
        try BisonColdLoopCandidate.decode(assets, parent: parent)
      }
    } else {
      let name = fault == "old-contact-cases" ? "connected-load-controls.json" : "connected-passage-source.json"
      #expect(throws: BisonColdLoopCandidate.Refusal.resourceIdentity(name)) {
        try BisonColdLoopCandidate.decode(assets, parent: parent)
      }
    }
  }
}
