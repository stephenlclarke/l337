import Foundation
import Testing

@testable import L337Core

struct BisonMovingMechanismSourceTests {
  private func load() throws -> BisonColdLoopCandidate {
    let parent = try BisonBedFeedCandidateV4.load()
    return try BisonColdLoopCandidate.load(from: BisonColdLoopCandidate.resourceFolder(), parent: parent)
  }

  @Test
  func exactProposedPiecesRetainPaidMassesAndUnqualifiedMaterials() throws {
    let source = try load()
    #expect(BisonColdLoopCandidate.sourceCommit == "b442f551ad3bb7a4b53e70b13b47d979c0f1f753")
    #expect(source.mechanismInputs.baselineCommit == BisonColdLoopCandidate.passageSourceCommit)
    // These external parent names and APIs remain unchanged by the consumer rename.
    let rigidPin = try #require(BisonBedFeedCandidateV4.assetPins["rigid-source-delta.json"])
    #expect(source.inputs.files.contains { $0.path == "rigid-source-delta.json"
      && $0.bytes == rigidPin.bytes && $0.sha256 == rigidPin.sha256 })
    #expect(source.passageBaseline.baselineSourceSHA256 == BisonColdLoopCandidate.assetPins["cold-source-delta.json"]?.sha256)
    #expect(source.passageContacts.paidForceNewtons == source.parent.contacts.paidForceNewtons)
    #expect(source.passageContacts.paidWorkJoules == source.parent.contacts.paidWorkJoules)
    #expect(source.delta.baselineConnectedSourceSHA256 == BisonColdLoopCandidate.assetPins["connected-passage-source.json"]?.sha256)
    let pump = try #require(source.delta.proposedAssemblies.first { $0.id == "pump" })
    let valve = try #require(source.delta.proposedAssemblies.first { $0.id == "valve" })
    #expect(pump.parts.count == 23 && valve.parts.count == 13)
    #expect(pump.parts.filter { $0.group == "pump-rotor" }.count == 11)
    #expect(valve.parts.filter { $0.group == "valve-gate" }.count == 4)
    #expect(pump.parts.filter { $0.group == "fixed" }.count == 12)
    #expect(valve.parts.filter { $0.group == "fixed" }.count == 9)
    #expect(pump.allDry.massKg == 0.3 && valve.allDry.massKg == 0.08)
    #expect(pump.housing.massKg < pump.allDry.massKg && valve.housing.massKg < valve.allDry.massKg)
    #expect(abs(pump.housing.massKg + pump.parts.reduce(0) { $0 + $1.physical.massKg } - pump.allDry.massKg) < 1e-12)
    #expect(abs(valve.housing.massKg + valve.parts.reduce(0) { $0 + $1.physical.massKg } - valve.allDry.massKg) < 1e-12)
    #expect(pump.parts.contains { $0.id == "pump-pitched-blade-3" })
    #expect(valve.parts.contains { $0.id == "valve-shaft-seal" })
    #expect(valve.parts.contains { $0.id == "valve-actuator-rotor" && $0.domain == "dry" })
    #expect(pump.housingGeometry.volumeCubicMetres < pump.outerDimensionsMetres.reduce(1, *))
    #expect(pump.parts.allSatisfy { !$0.materialOrJointQualified && $0.physical.inertiaAboutCentreOfMassKgM2.count == 9 })
    #expect(valve.parts.allSatisfy { !$0.materialOrJointQualified && $0.physical.centreMetres.count == 3 })
    #expect(pump.unobservedDryVoid == nil && valve.unobservedDryVoid?.volumeCubicMetres
      == source.mechanismExactDelta.sealedDryActuatorVoidCubicMetres)
    #expect(!source.delta.newInternalVoidContentsObserved && !source.delta.mechanismMaterialOrClearanceQualified)
    #expect(!source.delta.torqueFlowOrActuatorPerformanceQualified && !source.delta.pressureIntegrityQualified)
    #expect(!source.delta.pumpOrValveFunctionQualified && !source.delta.actualMotionObserved)
    #expect(!source.delta.quietTransitionObserved && !source.sourceQualifiedForBirth)
    for dimension in BisonColdLoopCandidate.RuntimeDimension.allCases {
      #expect(throws: BisonColdLoopCandidate.Refusal.unsupportedRuntimeDimension(dimension)) {
        try source.requireRuntimeSupport(dimension)
      }
    }
  }

  @Test(arguments: [0, 1, 2])
  func eachPositionRetainsFullMovingMomentsAndItsExactJointFrame(index: Int) throws {
    let source = try load()
    let reference = source.movingBodyReferences.configurations[index]
    let configuration = source.delta.configurationReferences[index]
    #expect(reference.gateAngleRadians == configuration.gateAngleRadians)
    #expect(reference.pumpAngleRadians == configuration.pumpAngleRadians)
    #expect(!reference.wallRefittedAtThisAngle && !configuration.wallRefittedAtThisAngle)
    #expect(!configuration.actualMotionOrRestObserved)
    let pump = try #require(reference.movingRigidBodies.first { $0.id == "pump-rotor" })
    let valve = try #require(reference.movingRigidBodies.first { $0.id == "valve-gate" })
    #expect(pump.positiveCoordinateAxisInSourceFrame == [0, 0, 1])
    #expect(valve.positiveCoordinateAxisInSourceFrame == [0, -1, 0])
    #expect(pump.jointOriginInSourceMetres == [-0.07, -0.38, -0.4])
    #expect(valve.jointOriginInSourceMetres == [0.060000000000000005, -0.27, -0.12960000000000002])
    #expect(pump.poseAngleRadians == reference.pumpAngleRadians && valve.poseAngleRadians == reference.gateAngleRadians)
    #expect(abs(pump.massKg - 0.0038203769490518192) < 1e-15)
    #expect(abs(valve.massKg - 0.0019107629216738452) < 1e-15)
    #expect(pump.inertiaAboutCentreOfMassKgM2.count == 9 && valve.inertiaAboutCentreOfMassKgM2.count == 9)
    #expect(pump.centreMetres.count == 3 && valve.centreMetres.count == 3)
    // Each pose retains a substantial product of inertia, not a diagonal proxy.
    let crossIndex = [1, 2, 5][index]
    #expect(abs(valve.inertiaAboutCentreOfMassKgM2[crossIndex]) > 1e-9)
    #expect(valve.inertiaAboutCentreOfMassKgM2[1] == valve.inertiaAboutCentreOfMassKgM2[3])
    #expect(valve.inertiaAboutCentreOfMassKgM2[2] == valve.inertiaAboutCentreOfMassKgM2[6])
    #expect(valve.inertiaAboutCentreOfMassKgM2[5] == valve.inertiaAboutCentreOfMassKgM2[7])
    #expect(pump.primitivePartIDs == source.delta.proposedAssemblies[0].parts.filter { $0.group == pump.id }.map(\.id))
    #expect(valve.primitivePartIDs == source.delta.proposedAssemblies[1].parts.filter { $0.group == valve.id }.map(\.id))
    #expect(!pump.actualMotionStateObserved && !valve.actualMotionStateObserved)
    #expect(pump.explicitVelocitySpinAndFluidExcessEnergyRequired && valve.explicitVelocitySpinAndFluidExcessEnergyRequired)
  }

  @Test
  func fixedWallAndDisplacedFluidSupersedeHousingOnlyReferencesWithoutExtraStock() throws {
    let source = try load()
    #expect(source.delta.proposedFluidRedistributionRawMoments == source.mechanismExactDelta.liquidPhysicalMomentDelta)
    #expect(source.delta.fluidRedistributionRawMoments == source.mechanismExactDelta.liquidPhysicalMomentDelta)
    #expect(source.delta.baselineConnectedFluidRedistributionRawMoments == source.passageBaseline.fluidRedistributionRawMoments)
    #expect(source.delta.proposedFluidRedistributionRawMoments != source.passageBaseline.fluidRedistributionRawMoments)
    #expect(source.delta.extraWorkingFluid.massKg == source.passageBaseline.extraWorkingFluid.massKg)
    #expect(source.delta.extraWorkingFluid.inertiaAboutCentreOfMassKgM2
      != source.passageBaseline.extraWorkingFluid.inertiaAboutCentreOfMassKgM2)
    #expect(source.delta.wall.wallCellEffectiveDensityKgPerCubicMetre
      != source.passageBaseline.wall.wallCellEffectiveDensityKgPerCubicMetre)
    // The genuine independent exports differ only within their ten-decimal closure.
    #expect(source.delta.wall.retainedLidMassKg != source.passageBaseline.wall.retainedLidMassKg)
    #expect(abs(source.delta.wall.retainedLidMassKg - source.passageBaseline.wall.retainedLidMassKg) < 1e-10)
    #expect(source.mechanismSourceIsCoherent)
    let folder = try BisonColdLoopCandidate.resourceFolder()
    let bytes = try Data(contentsOf: folder.appendingPathComponent("mechanism-source.json"))
    var altered = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var wall = try #require(altered["wall"] as? [String: Any])
    wall["retainedLidMassKg"] = source.passageBaseline.wall.retainedLidMassKg + 1e-8
    altered["wall"] = wall
    let changedLid = try JSONDecoder().decode(BisonColdLoopCandidate.Delta.self,
      from: JSONSerialization.data(withJSONObject: altered))
    #expect(!changedLid.mechanismDefinitionIsCoherent(in: source))
    #expect(source.delta.baseDry.massKg == source.mechanismExactDelta.canonicalDryMassKg)
    #expect(abs(source.delta.baseDry.massKg - 248) < 1e-10)
    #expect(source.delta.configurationReferences.allSatisfy { !$0.wallRefittedAtThisAngle })
    #expect(source.delta.configurationReferences[1].dry.inertiaAboutCentreOfMassKgM2
      != source.delta.configurationReferences[0].dry.inertiaAboutCentreOfMassKgM2)
    #expect(source.delta.proposedAssemblies[0].fluid.volumeCubicMetres == source.design.mainCircuit.pumpFluidVolumeCubicMetres)
    #expect(abs(source.delta.proposedAssemblies[1].fluid.volumeCubicMetres - source.design.regulator.valveFluidVolumeCubicMetres) < 1e-18)
    #expect(source.contacts.cases.allSatisfy { value in source.delta.portableStates.contains { $0.id == value.state } })
    #expect(source.contacts.cases.map(\.state) != source.passageContacts.cases.map(\.state))
    #expect(source.delta.portableStates.allSatisfy { $0.massKg <= 372.5 })
    #expect(source.design.power.unchangedTotalWatts == 42 && source.design.coolant.chargedMassKg == 0.945)
    #expect(source.design.accumulator.nitrogenMassKg == 0.010 && source.parent.totalThermalCO2SourceStockKg == 14)
    #expect(source.design.mainCircuit.maximumPumpHeadPascals == 60000 && source.design.coolant.massFlowKgPerSecond == 0.11)
    #expect(source.delta.proposalLimits.contains { $0.contains("old conditional performance is not inherited acceptance") })
    #expect(!source.delta.conductivityFloorQualified && !source.delta.rigidRuntimeConsumerUpdated)
  }

  @Test(arguments: ["missing-source", "missing-bodies", "passage-only", "extra-state",
    "stale-source", "stale-controls", "changed-body-inertia", "changed-wall"])
  func exactMechanismResourceSetRejectsMissingStaleAndAlteredInputs(fault: String) throws {
    let parent = try BisonBedFeedCandidateV4.load()
    var assets = try BisonCommissioningCandidateV3.readAssets(from: BisonColdLoopCandidate.resourceFolder(),
      expectedPins: BisonColdLoopCandidate.assetPins)
    let name: String
    switch fault {
    case "missing-source":
      name = "mechanism-source.json"
      assets.removeValue(forKey: name)
    case "missing-bodies":
      name = "moving-body-references.json"
      assets.removeValue(forKey: name)
    case "passage-only":
      name = "mechanism-source.json"
      for key in assets.keys.filter({ $0.hasPrefix("mechanism-") || $0 == "moving-body-references.json" }) {
        assets.removeValue(forKey: key)
      }
    case "extra-state":
      name = "actual-motion.json"
      assets[name] = Data()
    case "stale-source":
      name = "mechanism-source.json"
      assets[name] = assets["connected-passage-source.json"]
    case "stale-controls":
      name = "mechanism-load-controls.json"
      assets[name] = assets["connected-load-controls.json"]
    case "changed-body-inertia":
      name = "moving-body-references.json"
      let bytes = try #require(assets[name])
      var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      var positions = try #require(object["configurations"] as? [[String: Any]])
      var bodies = try #require(positions[0]["movingRigidBodies"] as? [[String: Any]])
      bodies[0]["inertiaAboutCentreOfMassKgM2"] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
      positions[0]["movingRigidBodies"] = bodies
      object["configurations"] = positions
      assets[name] = try JSONSerialization.data(withJSONObject: object)
    case "changed-wall":
      name = "mechanism-source.json"
      let bytes = try #require(assets[name])
      var value = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      let oldBytes = try #require(assets["connected-passage-source.json"])
      let old = try #require(JSONSerialization.jsonObject(with: oldBytes) as? [String: Any])
      value["wall"] = old["wall"]
      assets[name] = try JSONSerialization.data(withJSONObject: value)
    default: Issue.record("Unknown mechanism resource control"); return
    }
    let refusal: BisonColdLoopCandidate.Refusal = ["missing-source", "missing-bodies", "passage-only", "extra-state"].contains(fault)
      ? .resourceSet : .resourceIdentity(name)
    #expect(throws: refusal) { try BisonColdLoopCandidate.decode(assets, parent: parent) }
  }

  @Test(arguments: ["material", "performance", "pressure", "quiet", "motion", "void-contents",
    "stale-fluid", "density-unit", "axis", "position", "part-binding", "wall-refit", "seal", "thermal", "phase-budget"])
  func declaredRecordsRefuseInventedQualificationAndForeignGeometryBindings(fault: String) throws {
    let source = try load()
    let folder = try BisonColdLoopCandidate.resourceFolder()
    let decoder = JSONDecoder()
    if ["axis", "position", "part-binding"].contains(fault) {
      let bytes = try Data(contentsOf: folder.appendingPathComponent("moving-body-references.json"))
      var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      var configurations = try #require(object["configurations"] as? [[String: Any]])
      if fault == "position" {
        configurations[0]["pumpAngleRadians"] = 1.0
      } else {
        var bodies = try #require(configurations[0]["movingRigidBodies"] as? [[String: Any]])
        if fault == "axis" {
          bodies[0]["positiveCoordinateAxisInSourceFrame"] = [1, 0, 0]
        } else {
          bodies[0]["primitivePartIDs"] = ["foreign-part"]
        }
        configurations[0]["movingRigidBodies"] = bodies
      }
      object["configurations"] = configurations
      let changed = try decoder.decode(BisonColdLoopCandidate.MovingBodyReferences.self,
        from: JSONSerialization.data(withJSONObject: object))
      #expect(!changed.isCoherent(with: source.delta))
    } else {
      let bytes = try Data(contentsOf: folder.appendingPathComponent("mechanism-source.json"))
      var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
      switch fault {
      case "material": object["mechanismMaterialOrClearanceQualified"] = true
      case "performance": object["torqueFlowOrActuatorPerformanceQualified"] = true
      case "pressure": object["pressureIntegrityQualified"] = true
      case "quiet": object["quietTransitionObserved"] = true
      case "motion": object["actualMotionObserved"] = true
      case "void-contents": object["newInternalVoidContentsObserved"] = true
      case "stale-fluid": object["proposedFluidRedistributionRawMoments"] = object["baselineConnectedFluidRedistributionRawMoments"]
      case "thermal": object["conductivityFloorQualified"] = true
      case "phase-budget":
        var phases = try #require(object["phaseStates"] as? [[String: Any]])
        phases[0]["CaORemainingKg"] = 999.0
        object["phaseStates"] = phases
      case "seal":
        var assemblies = try #require(object["proposedAssemblies"] as? [[String: Any]])
        var parts = try #require(assemblies[1]["parts"] as? [[String: Any]])
        let sealIndex = try #require(parts.firstIndex { $0["id"] as? String == "valve-shaft-seal" })
        parts[sealIndex]["materialOrJointQualified"] = true
        assemblies[1]["parts"] = parts
        object["proposedAssemblies"] = assemblies
      case "density-unit":
        var assemblies = try #require(object["proposedAssemblies"] as? [[String: Any]])
        var parts = try #require(assemblies[0]["parts"] as? [[String: Any]])
        parts[0]["proposedEffectiveDensityKgPerCubicMetre"] = 1.0
        assemblies[0]["parts"] = parts
        object["proposedAssemblies"] = assemblies
      case "wall-refit":
        var positions = try #require(object["configurationReferences"] as? [[String: Any]])
        positions[1]["wallRefittedAtThisAngle"] = true
        object["configurationReferences"] = positions
      default: Issue.record("Unknown mechanism declaration control"); return
      }
      let changed = try decoder.decode(BisonColdLoopCandidate.Delta.self,
        from: JSONSerialization.data(withJSONObject: object))
      #expect(!changed.mechanismDefinitionIsCoherent(in: source))
    }
    #expect(!source.sourceQualifiedForBirth && !source.delta.actualMotionObserved)
  }
}
