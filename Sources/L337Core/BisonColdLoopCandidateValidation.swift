import Foundation

extension BisonColdLoopCandidate {
  /// Structural provenance/scope joins only. No heat, geometry, flow, pressure,
  /// phase, interpolation, momentum stop or engineering calculation occurs here.
  var structuralSourceCoherence: Bool {
    guard inputs.baseCommit == Self.parentSourceCommit,
      criteria.sourceBase == inputs.baseCommit,
      criteria.actualObservations.isEmpty, criteria.criteriaWaived.isEmpty,
      criteria.status == "ORIGINAL_CRITERIA_RETAINED_WITH_EXPLICIT_NEW_QUALIFICATION_INPUTS",
      primaryNotes.actualObservations.isEmpty, primaryNotes.sources.count == 5,
      !primaryNotes.newBoundsNotPublishedGuarantees.isEmpty,
      operation.status == "SOURCE_REQUIREMENTS_ONLY_NO_ACTUAL_OPERATION_OR_RUNTIME_AUTHORITY",
      operation.actualObservations.isEmpty, operation.qualificationRequired.count == 8,
      !operation.bodyBoundary.coreSkinContactCryobiologyQualified,
      !operation.bodyBoundary.arbitraryLocalHeatFluxQualified,
      !operation.quietTransition.actualQuietOrSettledStateObserved,
      operation.quietTransition.maximumSecondsUnchanged == criteria.unchangedAcceptance.maximumQuietSeconds,
      operation.quietTransition.requirements.count == 5,
      !operation.ownership.runtimeChangesInThisSlice, !operation.ownership.shippingResourceChangesInThisSlice,
      operation.ownership.playableIncrement == 0,
      operation.custody.originalOperatingRoles == 12, operation.custody.carrierBodies == 11,
      operation.custody.carrierCell7Empty, operation.custody.original7OnlyFrozenNewt,
      operation.custody.privateUnitsRemainUnobserved,
      !operation.custody.identityConsentAwakeFitnessOrAuthorityGranted else { return false }
    for name in ["bed-feed-design.json", "bed-feed-results.json", "candidate-source.json", "rigid-source-delta.json"] {
      guard let pin = BisonBedFeedCandidateV4.assetPins[name],
        inputs.files.contains(where: { $0.path == name && $0.bytes == pin.bytes && $0.sha256 == pin.sha256 })
      else { return false }
    }
    guard inputs.files.contains(where: { $0.path == "Bison-v2.json"
      && $0.sha256 == CurrentBisonWideShoePhysicalSource.sourceSHA256 }),
      inputs.files.contains(where: { $0.path == "Commissioning-v2.json"
        && $0.sha256 == CurrentBisonWideShoePhysicalSource.commissioningSHA256 }) else { return false }
    return requirementScopeIsCoherent && sourceRecordsAreCoherent && passageSourceIsCoherent
      && mechanismSourceIsCoherent
  }

  private var requirementScopeIsCoherent: Bool {
    let limits = criteria.unchangedAcceptance
    guard limits.minimumBoundaryConductanceWattsPerKelvin == 80,
      limits.maximumOccupiedMassKg == 372.5, limits.fixedElectricalWatts == 42,
      limits.canonicalDryMassCOMFullInertiaAndLidStock, limits.thermalCO2StockKg == 14,
      limits.maximumQuietSeconds == 1, !limits.nativeOrOperatingAuthorityFromSource,
      parent.totalThermalCO2SourceStockKg == limits.thermalCO2StockKg,
      parent.allCircuitGasSourceReserveKg == 0.025,
      design.status == "NEW_FINITE_COLD_LOOP_SOURCE_NOT_QUALIFIED_OR_OBSERVED",
      design.actualObservations.isEmpty, !design.allocation.sourceActualStocksObserved,
      !design.accumulator.actualBladderOrPressureObserved, !design.coolant.actualPureChargeOrPhaseObserved,
      !design.mainCircuit.actualPumpFlowOrEfficiencyObserved, !design.regulator.actualMixingFractionOrControlObserved,
      !design.bodyPanel.actualBodyContactOrCoreThermalTransportObserved,
      !design.coldExchanger.actualPoreCoverageOrTransportQualified,
      !design.target.biologicalCoreOrActualBodyContactQualified,
      design.coolant.chargedMassKg == 0.945, design.allocation.newPaidPropaneStockKg == design.coolant.chargedMassKg,
      design.accumulator.nitrogenMassKg == 0.010,
      design.allocation.newPaidNitrogenStockKg == design.accumulator.nitrogenMassKg,
      design.allocation.bodyPanelPadPumpAccumulatorPipesFromCradleKg == 18,
      design.allocation.coldPlatesMatrixAndHeadersFromDewarKg == 5,
      design.allocation.maximumOccupiedMassKgUnchanged == limits.maximumOccupiedMassKg,
      design.power.unchangedTotalWatts == limits.fixedElectricalWatts,
      design.target.minimumBoundaryConductanceWattsPerKelvin == limits.minimumBoundaryConductanceWattsPerKelvin,
      design.target.maximumQuietSeconds == limits.maximumQuietSeconds,
      design.coldExchanger.minimumCO2GasConductivity == 0.007,
      design.coldExchanger.minimumActivePoreFraction == 0.5,
      design.coldExchanger.minimumMatrixJointFactor == 0.5,
      design.coldExchanger.minimumMatrixPlateContactConductanceWattsPerKelvin == 2000,
      design.coolant.massFlowKgPerSecond == 0.11,
      design.mainCircuit.maximumPumpHeadPascals == 60000,
      design.mainCircuit.minimumPumpOverallEfficiency == 0.4,
      design.accumulator.gasCompressibilityRange == [0.9, 1.1] else { return false }
    return true
  }

  private var sourceRecordsAreCoherent: Bool {
    let pin = Self.assetPins["cold-loop-design.json"]?.sha256
    guard results.sourceDesignSHA256 == pin, layout.sourceDesignSHA256 == pin, passageBaseline.sourceDesignSHA256 == pin,
      passageBaseline.layoutSHA256 == Self.assetPins["cold-layout.json"]?.sha256,
      results.status == "CONDITIONAL_COLD_LOOP_SOURCE_NOT_APPARATUS_QUALIFICATION",
      results.actualObservations.isEmpty, results.allConditionalChecksPass,
      !results.coreBodyOrActualContactQualified, !results.porePopulationAndTransportQualified,
      results.primary.sampledColdRows == 48, results.primary.warmPressureStates.count == 121,
      results.derived.allocatedElectricalWatts == design.power.unchangedTotalWatts,
      results.derived.residualColdDumpWatts == 1,
      layout.status == "FINITE_COLD_LAYOUT_REFERENCE_NOT_QUALIFIED", layout.actualObservations.isEmpty,
      layout.geometry.bodyChannels.count == design.bodyPanel.channelCount,
      layout.geometry.bodyHeaders.count == design.bodyPanel.headersCount,
      layout.geometry.bodyHeaderBottomPorts.count == 2, layout.geometry.bodyVerticalPorts.count == 96,
      layout.geometry.coldSlots.count == 80, layout.geometry.ventColumns.count == 4,
      layout.geometry.adapters.count == 2, layout.geometry.plateCentresZMetres.count == design.coldExchanger.plateCount,
      layout.geometry.matrixCell.pitchMetres == design.coldExchanger.matrixPitchMetres,
      layout.geometry.coldGasCollector.dimensionsMetres == [0.33, 0.13, 0.0018],
      passageBaseline.status == "CONNECTED_FIXED_HOUSINGS_AND_PORTS_SOURCE_NOT_FUNCTION_OR_OPERATION_QUALIFICATION", passageBaseline.actualObservations.isEmpty,
      !passageBaseline.actualDiaphragmOrFlowStateQualified, !passageBaseline.bodyCoreOrContactQualified,
      !passageBaseline.microcellPopulationQualified, !passageBaseline.rigidRuntimeConsumerUpdated,
      !passageBaseline.wall.materialQualificationObserved, !passageBaseline.preparation.actualPreparationObserved,
      passageBaseline.preparation.addedHeatJoules == passageBaseline.additionalPreparationHeatJoules,
      passageBaseline.additionalPreparationHeatJoules == 2582050,
      passageBaseline.portableStates.count == 2, passageBaseline.phaseStates.count == 2,
      passageBaseline.phaseStates.allSatisfy({ $0.bodyIndependentThermalCO2TotalKg == criteria.unchangedAcceptance.thermalCO2StockKg }),
      passageBaseline.macroCertificates.count == 25, passageBaseline.macroCertificates.allSatisfy(\.noBoundaryCrossing),
      passageBaseline.wall.wallCellMassKg.count == 92, passageBaseline.wall.wallCellEffectiveDensityKgPerCubicMetre.count == 92,
      passageContacts.cases.count == 8, passageContacts.paidForceNewtons == parent.contacts.paidForceNewtons,
      passageContacts.paidWorkJoules == parent.contacts.paidWorkJoules else { return false }
    return passageContacts.cases.allSatisfy { value in
      passageBaseline.portableStates.contains(where: { $0.id == value.state })
    }
  }
  private var passageSourceIsCoherent: Bool {
    guard passageInputs.physicalBase == Self.baselineSourceCommit,
      passageCriteria.physicalBase == passageInputs.physicalBase,
      passageExactDelta.physicalBase == passageInputs.physicalBase,
      passageCriteria.sourceBase == passageExactDelta.authorParent,
      passageInputs.baselineFilesPinnedByRetainedManifest,
      passageInputs.baselineStageManifestSHA256 == "05931c67d61aa4d71886e3f81fdb26d1f1ac2f5ff8a125f7d8f855a3ff94a9e2",
      !passageInputs.conductivityQualificationGranted,
      passageCriteria.actualObservations.isEmpty, !passageCriteria.nativeCompilerRenderer,
      !passageCriteria.qualificationOpen.isEmpty,
      passageInputs.firstCriteriaSHA256 == Self.assetPins["connected-passage-criteria.json"]?.sha256,
      passageExactDelta.firstCriteriaSHA256 == passageInputs.firstCriteriaSHA256,
      passageExactDelta.sourceSHA256 == Self.assetPins["connected-passage-source.json"]?.sha256,
      passageExactDelta.acceptedPlayableIncrement == 0, passageExactDelta.actualObservations.isEmpty,
      passageExactDelta.criteriaWaived.isEmpty, passageExactDelta.effectiveDensitiesAreNewUnqualifiedMaterialRequirements,
      !passageExactDelta.nativeCompilerRendererRun, !passageExactDelta.runtimeConsumerChanged,
      !passageExactDelta.shippingResourceChanged, !passageExactDelta.stillOpen.isEmpty,
      passageBaseline.baselineSourceSHA256 == Self.assetPins["cold-source-delta.json"]?.sha256,
      passageBaseline.criteriaWaived.isEmpty, !passageBaseline.actualOpenStateObserved, !passageBaseline.conductivityFloorQualified,
      !passageBaseline.pressureIntegrityQualified, !passageBaseline.pumpOrValveFunctionQualified, !passageBaseline.quietTransitionObserved,
      passageBaseline.connectedFixedAssemblies.count == 2, passageExactDelta.geometry.count == 2,
      passageBaseline.fluidRedistributionRawMoments == passageExactDelta.liquidRedistribution,
      passageExactDelta.newPortableStates.count == passageBaseline.portableStates.count else { return false }
    for (assembly, geometry) in zip(passageBaseline.connectedFixedAssemblies, passageExactDelta.geometry) {
      guard assembly.id == geometry.id, assembly.interfaces.count == 2,
        assembly.interfaces == geometry.portInterfaces,
        assembly.centralCavityDimensionsMetres == geometry.centralCavityDimensionsMetres,
        assembly.housing.massKg == geometry.paidFixedMassKg,
        assembly.fluidVolumeCubicMetres == geometry.fluidVolumeCubicMetres,
        assembly.fluid.volumeCubicMetres == assembly.fluidVolumeCubicMetres,
        assembly.housingEffectiveDensityKgPerCubicMetre == geometry.housingEffectiveDensityKgPerCubicMetre,
        assembly.fluid.centreMetres.count == 3, assembly.fluid.volumeInertiaMetres5.count == 9,
        assembly.geometryMomentConvention.contains("unit density 1 kg/m3"),
        !assembly.actualOpenStateObserved, !assembly.pressureIntegrityQualified,
        !assembly.pumpOrValveFunctionQualified else { return false }
    }
    for (state, record) in zip(passageBaseline.portableStates, passageExactDelta.newPortableStates) {
      guard state.id == record.id, state.massKg == record.massKg,
        state.centreMetres == record.centreMetres,
        state.inertiaAboutCentreOfMassKgM2 == record.inertiaAboutCentreOfMassKgM2 else { return false }
    }
    let b = passageExactDelta.unchangedBudgets
    return b.pumpKg == design.mainCircuit.pumpDryMassKg && b.valveKg == design.regulator.valveDryMassKg
      && b.pumpFluidCubicMetres == design.mainCircuit.pumpFluidVolumeCubicMetres
      && b.valveFluidCubicMetres == design.regulator.valveFluidVolumeCubicMetres
      && b.cradleKg == design.allocation.bodyPanelPadPumpAccumulatorPipesFromCradleKg
      && b.dewarKg == design.allocation.coldPlatesMatrixAndHeadersFromDewarKg
      && b.propaneKg == design.coolant.chargedMassKg && b.nitrogenKg == design.accumulator.nitrogenMassKg
      && b.thermalCO2Kg == parent.totalThermalCO2SourceStockKg
      && b.electricWatts == design.power.unchangedTotalWatts && b.maxOccupiedKg == criteria.unchangedAcceptance.maximumOccupiedMassKg
      && b.minimumBoundaryConductanceWattsPerKelvin == criteria.unchangedAcceptance.minimumBoundaryConductanceWattsPerKelvin
      && b.maximumQuietSeconds == operation.quietTransition.maximumSecondsUnchanged
      && b.forceNewtons == passageContacts.paidForceNewtons && b.workJoules == passageContacts.paidWorkJoules
      && b.operatingRoles == operation.custody.originalOperatingRoles && b.carrierBodies == operation.custody.carrierBodies
      && b.carrier7Empty && b.original7OnlyFrozenNewt
  }

}
