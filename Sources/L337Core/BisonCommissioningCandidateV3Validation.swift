import Foundation

extension BisonCommissioningCandidateV3 {
  /// Structural/source coherence only. Geometry, thermodynamics, material
  /// performance and live physical operations are never recomputed or certified.
  var coherentDefinitions: Bool {
    guard header.id == Self.configurationID,
      header.status == "NEW_ENGINEERING_SOURCE_NOT_QUALIFIED_OR_OBSERVED",
      header.baseBisonSourceSHA256 == CurrentBisonWideShoePhysicalSource.sourceSHA256,
      header.baseCommissioningSHA256 == CurrentBisonWideShoePhysicalSource.commissioningSHA256,
      header.acceptedIncrement == 0, header.actualObservations.isEmpty, !header.qualifiedBirth,
      !header.sharedRuntimeOrShippingResourceChanges,
      header.supersedesAuthoredCommissioningInputsNotRecoveredHumanRequirements,
      header.unaffectedBaseProofCommit == Self.parentSourceCommit, !header.reviewCorrection.isEmpty,
      carrierReviewInputs.baseCommit == Self.parentSourceCommit,
      carrierReviewInputs.files.count == 5,
      carrierReviewInputs.files.contains(where: { $0.path == "thermal-design.json"
        && $0.sha256 == Self.assetPins["thermal-design.json"]?.sha256 }),
      carrierReviewInputs.files.contains(where: { $0.path == "thermal-results-a81.json"
        && $0.sha256 == "3351b4057462c178a1b1b7e4b6b342dc0b9fcf812bf3be603aedcb8c6f9c92f1" }),
      inputs.newSourceIsNotObservedCommissioning,
      Set(header.artifacts.map(\.path)).count == header.artifacts.count,
      Set(inputs.files.map(\.path)).count == inputs.files.count else { return false }
    for (name, pin) in Self.assetPins where name != "candidate-source.json" {
      guard header.artifacts.contains(where: { $0.path == name && $0.bytes == pin.bytes && $0.sha256 == pin.sha256 })
      else { return false }
    }
    guard let baseInput = inputs.files.first(where: { $0.path == "Bison-v2.json" }),
      baseInput.sha256 == header.baseBisonSourceSHA256,
      baseInput.bytes == CurrentBisonWideShoePhysicalSource.sourceByteCount,
      inputs.files.contains(where: { $0.path == "Commissioning-v2.json"
        && $0.sha256 == header.baseCommissioningSHA256
        && $0.bytes == CurrentBisonWideShoePhysicalSource.commissioningByteCount }),
      inputs.files.contains(where: { $0.path == "SH040-current.toml" && $0.sha256 == material.outerSourceSHA256 }),
      baseDeclarations.id == CurrentBisonWideShoePhysicalSource.configurationID,
      baseDeclarations.crewPhysicalProfiles.count == 12,
      Set(baseDeclarations.crewPhysicalProfiles.map(\.ordinal)) == Set(0..<12),
      Set(baseDeclarations.crewPhysicalProfiles.map(\.profileID)).count == 12,
      baseDeclarations.crewPhysicalProfiles.allSatisfy({ $0.massKg == material.body.massKg
        && vector($0.dimensionsMetres) && vector($0.centreMetres)
        && $0.inertiaAboutCentreOfMassKgM2.count == 9 && $0.inertiaAboutCentreOfMassKgM2.allSatisfy(\.isFinite) }),
      baseDeclarations.actualInventoryLoadModel.catalogueShipID == "SH005",
      baseDeclarations.actualInventoryLoadModel.equipment.additionalModules == "REFUSE_UNMODELED_ACTUAL_MODULES",
      baseDeclarations.actualInventoryLoadModel.equipment.actualFuelScoopsMustBeFalse,
      baseDeclarations.actualInventoryLoadModel.cargo.nativeUnitByCommodityIndex.count == 17 else { return false }
    return materialDefinitionsCoherent && thermalDefinitionsCoherent && referenceDefinitionsCoherent
  }

  private func vector(_ values: [Double]) -> Bool { values.count == 3 && values.allSatisfy(\.isFinite) }
  private func envelope(_ value: Envelope) -> Bool {
    !value.id.isEmpty && value.massKg.isFinite && value.massKg > 0 && vector(value.centreMetres)
      && vector(value.dimensionsMetres) && value.dimensionsMetres.allSatisfy({ $0 > 0 })
  }
  private var materialDefinitionsCoherent: Bool {
    guard !material.compiler, !material.native, !material.actualSealOrCommissioningObserved,
      material.newAssumptions, !material.canonicalDryMassAndMomentsMatched,
      material.exactInnerFreeSpaceIsOuterMinusCertifiedDisjointBoxes,
      material.unchangedOuterVertices, material.unchangedCollisionFaces,
      material.innerVerticesMetres.count == 48, material.innerVerticesMetres.allSatisfy(vector),
      material.innerFaces.count == 92,
      material.innerFaces.allSatisfy({ $0.count == 3 && $0.allSatisfy({ (0..<48).contains($0) }) }),
      material.finiteHardware.count == 11, material.finiteHardware.allSatisfy(envelope),
      envelope(material.body), material.body.massKg == 100,
      envelope(material.additionalTankEnvelope), material.additionalTankEnvelope.massKg == 5,
      envelope(material.existingIsolatorEnvelope), material.existingIsolatorEnvelope.massKg == 1,
      material.disjointInsideCertificates.count == 14,
      material.disjointInsideCertificates.allSatisfy({ $0.noBoundaryCrossing && $0.minimumCornerDistanceMetres > 0 }),
      momentFit.status == "PASS_POSITIVE_FINITE_WALL_AGGREGATE_MATCH",
      !momentFit.actualMaterialQualificationObserved, !momentFit.canonicalStockFacetDensitiesPreserved,
      momentFit.wallMaterialDistributionIsNewAssumption, momentFit.dryMassKg == 248,
      vector(momentFit.unchangedDryCentreMetres), momentFit.unchangedDryInertiaAboutCentreKgM2.count == 9,
      momentFit.wallCellMassKg.count == 92, momentFit.wallCellDensityKgPerCubicMetre.count == 92,
      physicalDelta.status == "NEW_SOURCE_CANDIDATE_NOT_SHIPPING_OR_OBSERVED",
      physicalDelta.actualObservations.isEmpty, physicalDelta.canonicalDryAggregatePreserved,
      physicalDelta.canonicalOuterGeometryPreserved, !physicalDelta.canonicalWallFacetDensityDistributionPreserved,
      physicalDelta.newFiniteGasMassDistribution,
      physicalDelta.variableInternalMassStateNotProvedByInstantaneousContactCases,
      physicalDelta.freeGasVolumeCubicMetres == material.connectedFreeGasVolumeCubicMetres,
      physicalDelta.portableStates.map(\.id) == ["closed-thermal-candidate-0.0", "closed-thermal-candidate-1.0"],
      physicalDelta.portableStates.allSatisfy({ $0.massKg == 371.5 && vector($0.centreMetres)
        && $0.inertiaAboutCentreOfMassKgM2.count == 9 && $0.inertiaAboutCentreOfMassKgM2.allSatisfy(\.isFinite) }),
      radiator.rendererAndCollisionUnchanged, !radiator.thermalMaterialOrViewQualified,
      radiator.requestedSquareMetres == thermal.portable.radiatorAreaSquareMetres,
      radiator.patches.map(\.sourceFaceIndex) == [82, 83, 84] else { return false }
    return true
  }

  private var thermalDefinitionsCoherent: Bool {
    let c = thermal.custody
    let p = thermal.preparationPlant
    guard thermal.status == "NEW_ENGINEERING_CANDIDATE_NOT_QUALIFIED_OR_OBSERVED",
      thermal.actualObservations.isEmpty, !thermal.nativeTestsRun,
      !thermal.biologicalCryostasisAndOperatingCrewFitnessQualified,
      !c.actualIdentitiesOrAwakeStatesGranted, c.originalRoles == 12,
      c.carrierEmptyOrdinal == 7, c.portableBodyOrdinal == 7,
      c.carrierOccupiedOrdinals == [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11],
      thermal.carrier.gasKelvin == 280, thermal.carrier.bodyReferenceKelvin == 310,
      thermal.carrier.newMaterialPerformanceAssumptionsRequireQualification,
      thermal.portable.bodyAndGasKelvin == 190, thermal.portable.coldCO2Kelvin == 185,
      thermal.portable.newReactionAndPackingPerformanceRequireQualification,
      thermal.portable.ventedMassKg == 0, thermal.portable.extraPaidMechanicalPairs == 0,
      thermal.portable.ratedOccupiedMassLimitKgUnchanged == adoptedCriteria.portableMassMaximumKg,
      thermal.portable.maximumOperationalCapturedCO2Kg == adoptedCriteria.maximumOperationalCO2CaptureKg,
      thermal.portable.heatLocations.allMassRetainedInClosedThermalCircuit,
      thermal.portable.heatLocations.reactionHeatIsPositiveAtHotNode,
      thermal.portable.heatLocations.hotLeakReturnsToColdNodeAndIsIncludedInCoolingLoad,
      !thermal.finiteGasOperations.qualifiedActualPressureSealOrStockObserved,
      !thermal.finiteGasOperations.equalisationOrServiceToResetPackOrClock,
      thermal.finiteGasOperations.coldCircuitSeparateFromRespiratoryGas,
      thermal.unchangedPerUnitElectrical.initialJoules == 1500000,
      thermal.unchangedPerUnitElectrical.startupJoules == 120000,
      thermal.unchangedPerUnitElectrical.continuousWatts == 42,
      thermal.unchangedPerUnitElectrical.ratedSeconds == 21600,
      p.notCarriedOrInventedAtBirth, p.bodyKgIsConservativePreparationUpperBound,
      p.bodyKg == 101, p.serviceBodyMassAtActualIssueKg == material.body.massKg,
      p.preparationBreathingSupportSeparateFromServiceCartridges,
      p.externalColdPlateSupportsPreparationWithoutConsumingPortableCO2OrCaO,
      p.CaOIsPaidMaterialStockNotRegeneratedByThisPlant,
      p.gasStockAlreadyIncludedInCarriedCharge, p.finiteElectricalEnergyJoules == 1000000000,
      p.finiteOxygenStockKg == 30.5, p.finiteNitrogenStockKg == 19.55,
      p.finiteCO2StockKg == 14.05, p.finiteFreshCalciumOxideStockKg == 20 else { return false }
    return true
  }

  private var referenceDefinitionsCoherent: Bool {
    guard finiteOperations.status == "REQUIRED_FINITE_OPERATIONS_NOT_ACTUAL_RECORDS",
      finiteOperations.acceptedIncrement == 0, finiteOperations.actualOperationsPerformed.isEmpty,
      !finiteOperations.sharedRuntimeHunksChanged, finiteOperations.requiredOperations.count == 8,
      finiteOperations.requiredOperations.allSatisfy({ !$0.operation.isEmpty && !$0.inputs.isEmpty && !$0.actualRequirement.isEmpty }),
      thermalBudget.status == "CONDITIONAL_BUDGET_NOT_APPARATUS_QUALIFICATION",
      thermalBudget.actualObservations.isEmpty, thermalBudget.newAssumptionsRequireQualification,
      thermalBudget.carrierRejectedSixHourJoules == adoptedCriteria.carrierTotalServiceHullHeatJoules,
      thermalBudget.carrierRejectedSixHourJoules == 67622400,
      thermalBudget.carrierFixedElectricalSixHourJoules == adoptedCriteria.carrierFixedElectricalServiceHeatJoules,
      thermalBudget.carrierFixedElectricalSixHourJoules == 10886400,
      thermalBudget.carrierElectricalStoredOrExportedJoules == 0,
      adoptedCriteria.carrierResidualDumpRequiredRatingWattsPerCell == 42,
      !thermalBudget.carrierResidualElectricalDestination.isEmpty,
      thermalBudget.allConditionalBudgetChecksPass, thermalBudget.checks.values.allSatisfy({ $0 }),
      adoptedCriteria.actualObservations.isEmpty, adoptedCriteria.canonicalSourceFrozen,
      adoptedCriteria.newMaterialAndPhysiologicalQualification == "OPEN",
      adoptedCriteria.portableNoVentOrAddedPaidPairs,
      thermalBudget.CO2RequiredFlowKgPerSecond == adoptedCriteria.minimumNearDepletionUptakeKgPerSecond,
      contactReference.actualObservations.isEmpty, contactReference.cases.count == 8,
      contactReference.paidGrossForceNewtons == 4000, contactReference.paidWorkJoules == 2400,
      contactReference.cases.allSatisfy({ value in
        physicalDelta.portableStates.contains(where: { $0.id == value.state })
          && (value.q == 0 || value.q == 0.3) && value.lambdaNewtons.count == 4
          && value.rotation.count == 3 && value.rotation.allSatisfy(vector)
      }) else { return false }
    return true
  }
}
