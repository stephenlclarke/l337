import Foundation

extension BisonColdLoopCandidate {
  /// Provenance and declared-record joins only. Historical hydraulic results
  /// are retained context; new obstructions acquire no inherited performance.
  var mechanismSourceIsCoherent: Bool {
    guard mechanismInputs.baselineCommit == Self.passageSourceCommit,
      mechanismInputs.baselineStageManifestSHA256 == "69fd14af0a4c398755d099fd0444d09fb15af7e106ff74ad47e546f4601ff24e",
      mechanismInputs.captureCommit == "f6765409e99146d3ecd54f299e4f901141c5f940",
      mechanismInputs.actualObservations.isEmpty, mechanismInputs.designNotesAreCommentaryNotParsedParameterFallback,
      mechanismInputs.firstCriteriaSHA256 == Self.assetPins["mechanism-criteria.json"]?.sha256,
      mechanismCriteria.physicalBase == mechanismInputs.baselineCommit,
      mechanismCriteria.captureBase == mechanismInputs.captureCommit,
      mechanismCriteria.actualObservations.isEmpty, !mechanismCriteria.nativeCompilerRenderer,
      !mechanismCriteria.qualificationOpen.isEmpty,
      mechanismExactDelta.firstCriteriaSHA256 == mechanismInputs.firstCriteriaSHA256,
      mechanismExactDelta.mechanismSourceSHA256 == Self.assetPins["mechanism-source.json"]?.sha256,
      mechanismExactDelta.baselineConnectedSourceSHA256 == Self.assetPins["connected-passage-source.json"]?.sha256,
      mechanismExactDelta.generatorSHA256 == delta.generatorSHA256,
      mechanismExactDelta.acceptedPlayableIncrement == 0, mechanismExactDelta.actualObservations.isEmpty,
      !mechanismExactDelta.apparatusMaterialTorqueFlowPressureThermalQuietQualified,
      !mechanismExactDelta.gasOrVacuumContentsObserved,
      !mechanismExactDelta.runtimeShippingNativeCompilerRendererUpdated,
      mechanismExactDelta.finiteMaterialPiecesIncludingResidualHousings == 38,
      mechanismExactDelta.changedQuiescentFourMaterialReferences == 8,
      mechanismExactDelta.outerEnvelopesExact,
      mechanismExactDelta.liquidPhysicalMomentDelta == delta.proposedFluidRedistributionRawMoments,
      mechanismExactDelta.liquidPhysicalMomentDelta == delta.fluidRedistributionRawMoments,
      mechanismExactDelta.canonicalDryMassKg == delta.baseDry.massKg,
      mechanismExactDelta.hotRadiatorPatchMassKg == delta.radiatorPatchWallMassKg,
      mechanismExactDelta.nominalWetMassKg == delta.portableStates.map(\.massKg),
      mechanismExactDelta.cavityLengthsMetres == delta.proposedAssemblies.map(\.cavityLengthMetres),
      mechanismExactDelta.paidAssemblyMassKg == [design.mainCircuit.pumpDryMassKg, design.regulator.valveDryMassKg],
      mechanismExactDelta.paidFluidVolumeCubicMetres.count == 2,
      zip(mechanismExactDelta.paidFluidVolumeCubicMetres,
        [design.mainCircuit.pumpFluidVolumeCubicMetres, design.regulator.valveFluidVolumeCubicMetres])
        .allSatisfy({ pair in abs(pair.0 - pair.1) < 1e-18 }),
      mechanismExactDelta.proposedResidualHousingDensitiesKgPerCubicMetre
        == delta.proposedAssemblies.map(\.housingProposedEffectiveDensityKgPerCubicMetre),
      mechanismExactDelta.originalInterfaces.count == passageBaseline.connectedFixedAssemblies.count,
      mechanismExactDelta.nominalClearances.count == delta.nominalJointClearances.count,
      contacts.cases.count == 8, contacts.paidForceNewtons == passageContacts.paidForceNewtons,
      contacts.paidWorkJoules == passageContacts.paidWorkJoules,
      contacts.cases.allSatisfy({ value in delta.portableStates.contains { $0.id == value.state } }),
      delta.mechanismDefinitionIsCoherent(in: self), movingBodyReferences.isCoherent(with: delta)
    else { return false }
    for (record, baseline) in zip(mechanismExactDelta.originalInterfaces, passageBaseline.connectedFixedAssemblies) {
      guard record.id == baseline.id, record.interfaces == baseline.interfaces else { return false }
    }
    for (record, declared) in zip(mechanismExactDelta.nominalClearances, delta.nominalJointClearances) {
      guard record.id == declared.id, record.minimumNominalMetres == declared.minimumNominalMetres,
        !record.coldToleranceOrMaterialQualified else { return false }
    }
    return mechanismInputs.files.contains { $0.path == "Bison-v2.json"
      && $0.sha256 == CurrentBisonWideShoePhysicalSource.sourceSHA256 }
      && mechanismInputs.files.contains { $0.path == "Commissioning-v2.json"
        && $0.sha256 == CurrentBisonWideShoePhysicalSource.commissioningSHA256 }
  }
}

extension BisonColdLoopCandidate.Delta {
  func mechanismDefinitionIsCoherent(in source: borrowing BisonColdLoopCandidate) -> Bool {
    let baseline = source.passageBaseline
    guard status == "PROPOSED_FINITE_MOVING_MECHANISMS_NOT_APPARATUS_OR_OPERATION_QUALIFICATION",
      geometryIsProposed, actualObservations.isEmpty, criteriaWaived.isEmpty,
      !actualMotionObserved, !actualOpenStateObserved, !newInternalVoidContentsObserved,
      !mechanismMaterialOrClearanceQualified, !torqueFlowOrActuatorPerformanceQualified,
      !pressureIntegrityQualified, !pumpOrValveFunctionQualified, !quietTransitionObserved,
      !conductivityFloorQualified, !actualDiaphragmOrFlowStateQualified,
      !bodyCoreOrContactQualified, !microcellPopulationQualified, !rigidRuntimeConsumerUpdated,
      !wall.materialQualificationObserved, !preparation.actualPreparationObserved,
      baselineConnectedSourceSHA256 == BisonColdLoopCandidate.assetPins["connected-passage-source.json"]?.sha256,
      baselineSourceSHA256 == BisonColdLoopCandidate.assetPins["cold-source-delta.json"]?.sha256,
      baselineLayoutSHA256 == BisonColdLoopCandidate.assetPins["cold-layout.json"]?.sha256,
      sourceDesignSHA256 == BisonColdLoopCandidate.assetPins["cold-loop-design.json"]?.sha256,
      baselineConnectedFluidRedistributionRawMoments == baseline.fluidRedistributionRawMoments,
      proposedFluidRedistributionRawMoments == fluidRedistributionRawMoments,
      geometryMomentConvention.contains("Unit-density geometry massKg encodes volume"),
      nominalLiquidDensityKgPerCubicMetre == baseline.nominalLiquidDensityKgPerCubicMetre,
      extraWorkingFluid.massKg == baseline.extraWorkingFluid.massKg,
      freeRespiratoryGasCubicMetres == baseline.freeRespiratoryGasCubicMetres,
      solidPoreDomainCubicMetres == baseline.solidPoreDomainCubicMetres,
      nominalAccumulatorLiquidCubicMetres == baseline.nominalAccumulatorLiquidCubicMetres,
      nominalDiaphragmLocalZMetres == baseline.nominalDiaphragmLocalZMetres,
      newMeteringCapacityKgPerSecond == baseline.newMeteringCapacityKgPerSecond,
      additionalPreparationHeatJoules == baseline.additionalPreparationHeatJoules,
      additionalPreparationElectricalJoules == baseline.additionalPreparationElectricalJoules,
      additionalPreparationRejectJoules == baseline.additionalPreparationRejectJoules,
      preparation.addedHeatJoules == baseline.preparation.addedHeatJoules,
      preparation.totalConservativeSeconds == baseline.preparation.totalConservativeSeconds,
      preparation.totalElectricalJoules == baseline.preparation.totalElectricalJoules,
      preparation.totalNitrogenStockRequiredKg == baseline.preparation.totalNitrogenStockRequiredKg,
      preparation.totalRejectedJoules == baseline.preparation.totalRejectedJoules,
      // Retain the producer's ten-decimal mass closure without rewriting source values.
      abs(wall.retainedLidMassKg - baseline.wall.retainedLidMassKg) < 1e-10,
      wall.wallCellMassKg.count == 92, wall.wallCellMassKg.allSatisfy({ $0.isFinite && $0 > 0 }),
      wall.wallCellEffectiveDensityKgPerCubicMetre.count == 92,
      wall.wallCellEffectiveDensityKgPerCubicMetre.allSatisfy({ $0.isFinite && $0 > 0 }),
      macroCertificates.count == 25, macroCertificates.allSatisfy(\.noBoundaryCrossing),
      phaseStates.count == 2, phaseStates.allSatisfy({ $0.bodyIndependentThermalCO2TotalKg == 14 }),
      zip(phaseStates, baseline.phaseStates).allSatisfy({ pair in Self.phaseFields(pair.0) == Self.phaseFields(pair.1) }),
      portableStates.count == 2, portableStates.allSatisfy(Self.validMass),
      Self.validMass(baseDry), Self.validMass(extraWorkingFluid), Self.validMass(hardware), Self.validMass(dewar),
      abs(baseDry.massKg - baseline.baseDry.massKg) < 1e-10,
      proposedAssemblies.map(\.id) == ["pump", "valve"],
      configurationReferences.count == 3, nominalJointClearances.count == 9,
      nominalJointClearances.allSatisfy({ !$0.coldToleranceOrMaterialQualified && $0.minimumNominalMetres > 0 }),
      proposalLimits.count == 5, referencePumpAngleRadians == 0, referenceGateAngleRadians == Double.pi / 2
    else { return false }
    let reference = configurationReferences[0]
    guard reference.pumpAngleRadians == referencePumpAngleRadians,
      reference.gateAngleRadians == referenceGateAngleRadians,
      reference.dry.massKg == baseDry.massKg, reference.dry.centreMetres == baseDry.centreMetres,
      reference.dry.inertiaAboutCentreOfMassKgM2 == baseDry.inertiaAboutCentreOfMassKgM2
    else { return false }
    for (assembly, prior) in zip(proposedAssemblies, baseline.connectedFixedAssemblies) {
      guard assembly.isCoherent(with: prior) else { return false }
    }
    return configurationReferences.allSatisfy { reference in
      !reference.actualMotionOrRestObserved && !reference.wallRefittedAtThisAngle
        && Self.validMass(reference.dry) && reference.portableStates.count == 2
        && reference.portableStates.allSatisfy(Self.validMass)
    }
  }

  private static func phaseFields(_ value: BisonBedFeedCandidateV4.Results.PhaseState) -> [Double] {
    [value.CaCO3Kg, value.CaORemainingKg, value.bedSolidVolumeCubicMetres, value.bedVoidGasCO2Kg,
      value.bodyIndependentThermalCO2TotalKg, value.capturedCO2Kg, value.dewarHeadGasCO2Kg,
      value.diffuserGasCO2Kg, value.feedLineGasCO2Kg, value.inletGasCO2Kg, value.outletGasCO2Kg,
      value.solidCO2Kg, value.totalUnreactedGasCO2Kg]
  }

  fileprivate static func validMass(_ value: BisonCommissioningCandidateV3.SourceMassState) -> Bool {
    value.massKg.isFinite && value.massKg > 0 && value.centreMetres.count == 3
      && value.centreMetres.allSatisfy(\.isFinite) && value.inertiaAboutCentreOfMassKgM2.count == 9
      && value.inertiaAboutCentreOfMassKgM2.allSatisfy(\.isFinite)
  }
}

extension BisonColdLoopCandidate.MechanismAssembly {
  fileprivate func isCoherent(with baseline: BisonColdLoopCandidate.ConnectedAssembly) -> Bool {
    let movingGroup = id == "pump" ? "pump-rotor" : "valve-gate"
    let expectedMoving = id == "pump" ? 11 : 4
    guard id == baseline.id, parts.count == (id == "pump" ? 23 : 13),
      Set(parts.map(\.id)).count == parts.count,
      parts.filter({ $0.group == movingGroup }).count == expectedMoving,
      parts.allSatisfy({ $0.group == movingGroup || $0.group == "fixed" }),
      outer.minimumMetres == baseline.outer.minimumMetres, outer.maximumMetres == baseline.outer.maximumMetres,
      outerDimensionsMetres == (id == "pump" ? [0.05, 0.05, 0.05] : [0.025, 0.025, 0.025]),
      allDry.massKg == baseline.housing.massKg,
      BisonColdLoopCandidate.Delta.validMass(allDry), BisonColdLoopCandidate.Delta.validMass(housing),
      housingProposedEffectiveDensityKgPerCubicMetre > 0,
      assemblyCentreMetres.count == 3, cavityLengthMetres > 0,
      housingGeometry.volumeCubicMetres > 0, housingGeometry.volumeInertiaMetres5.count == 9,
      fluid.volumeInertiaMetres5.count == 9, fluid.centreMetres.count == 3,
      abs(fluid.volumeCubicMetres - baseline.fluidVolumeCubicMetres) < 1e-18,
      fluidBase.volumeCubicMetres > fluid.volumeCubicMetres,
      fluidBase.volumeInertiaMetres5.count == 9,
      parts.allSatisfy({ part in
        !part.materialOrJointQualified && part.physical.id == part.id
          && ["wet", "dry", "outside"].contains(part.domain)
          && part.geometricVolumeCubicMetres > 0 && part.proposedEffectiveDensityKgPerCubicMetre > 0
          && abs(part.physical.massKg - part.geometricVolumeCubicMetres * part.proposedEffectiveDensityKgPerCubicMetre) < 1e-12
          && BisonColdLoopCandidate.Delta.validMass(part.physical)
          && !part.terms.isEmpty && part.terms.allSatisfy(\.structurallyValid)
      }) else { return false }
    switch cavity {
    case .cylinder(let radius, let terms):
      return id == "pump" && radius > 0 && terms.count == 3 && terms.allSatisfy(\.structurallyValid)
        && dryVoidTerms.isEmpty && unobservedDryVoid == nil && referenceAngleRadians == 0
    case .square(let side, let boxes):
      guard id == "valve", side > 0, boxes.count == 4, dryVoidTerms.count == 2,
        dryVoidTerms.allSatisfy(\.structurallyValid), let void = unobservedDryVoid else { return false }
      return void.volumeCubicMetres > 0 && void.volumeInertiaMetres5.count == 9
        && referenceAngleRadians == Double.pi / 2
    }
  }
}

extension BisonColdLoopCandidate.MechanismPrimitive {
  fileprivate var structurallyValid: Bool {
    guard centre.count == 3, centre.allSatisfy(\.isFinite), sign == 1 || sign == -1,
      rotation.count == 3, rotation.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) })
    else { return false }
    switch shape {
    case .box(let dimensions): return dimensions.count == 3 && dimensions.allSatisfy { $0.isFinite && $0 > 0 }
    case .sector(let inner, let outer, let z0, let z1, let a, let b):
      return [inner, outer, z0, z1, a, b].allSatisfy(\.isFinite)
        && inner >= 0 && outer > inner && z1 > z0 && b > a
    }
  }
}

extension BisonColdLoopCandidate.MovingBodyReferences {
  func isCoherent(with delta: borrowing BisonColdLoopCandidate.Delta) -> Bool {
    guard actualObservations.isEmpty, configurations.count == 3 else { return false }
    for (configuration, position) in zip(configurations, delta.configurationReferences) {
      guard !configuration.wallRefittedAtThisAngle,
        configuration.gateAngleRadians == position.gateAngleRadians,
        configuration.pumpAngleRadians == position.pumpAngleRadians,
        configuration.movingRigidBodies.map(\.id) == ["pump-rotor", "valve-gate"] else { return false }
      for (body, assembly) in zip(configuration.movingRigidBodies, delta.proposedAssemblies) {
        guard !body.actualMotionStateObserved, body.explicitVelocitySpinAndFluidExcessEnergyRequired,
          body.primitivePartIDs == assembly.parts.filter({ $0.group == body.id }).map(\.id),
          body.primitivePartIDs.count == (body.id == "pump-rotor" ? 11 : 4),
          body.positiveCoordinateAxisInSourceFrame == (body.id == "pump-rotor" ? [0, 0, 1] : [0, -1, 0]),
          body.poseAngleRadians == (body.id == "pump-rotor" ? configuration.pumpAngleRadians : configuration.gateAngleRadians),
          body.jointOriginInSourceMetres.count == 3, body.jointOriginInSourceMetres.allSatisfy(\.isFinite),
          body.centreMetres.count == 3, body.centreMetres.allSatisfy(\.isFinite),
          body.massKg.isFinite && body.massKg > 0,
          body.inertiaAboutCentreOfMassKgM2.count == 9, body.inertiaAboutCentreOfMassKgM2.allSatisfy(\.isFinite)
        else { return false }
      }
    }
    return true
  }
}
