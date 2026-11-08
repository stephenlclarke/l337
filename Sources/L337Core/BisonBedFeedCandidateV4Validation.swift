import Foundation

extension BisonBedFeedCandidateV4 {
  /// Only schema/provenance and source-scope joins. No geometry, flow, energy,
  /// kinetic metric or phase calculation is performed or qualified here.
  var structuralSourceCoherence: Bool {
    guard header.id == Self.configurationID, header.status == "NEW_SOURCE_NOT_QUALIFIED_OR_OBSERVED",
      header.acceptedIncrement == 0, header.actualObservations.isEmpty, !header.qualifiedBirth,
      header.parentCommit == Self.parentSourceCommit, header.baseThermalSourceCommit == Self.thermalBaseCommit,
      inputs.baseCommit == Self.thermalBaseCommit, inputs.implementationParentCommit == Self.parentSourceCommit,
      inputs.originalFreezeUnchanged, primaryNotes.actualObservations.isEmpty,
      !primaryNotes.newUnqualifiedInputs.isEmpty,
      criteria.actualObservations.isEmpty, criteria.parentCommit == Self.parentSourceCommit,
      criteria.thermalBaseCommit == Self.thermalBaseCommit,
      exactDelta.id == header.id, exactDelta.baseCommit == header.parentCommit,
      exactDelta.actualObservations.isEmpty, exactDelta.acceptedIncrement == 0,
      !exactDelta.qualifiedBirth, !exactDelta.shippingOrRuntimeFilesChanged,
      exactDelta.oldFrozenSourcesUnchanged else { return false }
    for (name, pin) in Self.assetPins where name != "candidate-source.json" {
      guard header.artifacts.contains(where: { $0.path == name && $0.bytes == pin.bytes && $0.sha256 == pin.sha256 })
      else { return false }
    }
    guard inputs.files.contains(where: { $0.path == "carrier-heat-candidate-source.json"
      && $0.sha256 == BisonCommissioningCandidateV3.assetPins["candidate-source.json"]?.sha256 }),
      inputs.files.contains(where: { $0.path == "Bison-v2.json"
        && $0.sha256 == CurrentBisonWideShoePhysicalSource.sourceSHA256 }),
      inputs.files.contains(where: { $0.path == "Commissioning-v2.json"
        && $0.sha256 == CurrentBisonWideShoePhysicalSource.commissioningSHA256 }) else { return false }
    return designAndInventorySourceCoherence && layoutAndRecordSourceCoherence
  }

  private var designAndInventorySourceCoherence: Bool {
    let f = design.feed
    let p = design.phase
    let bed = design.reactor
    guard design.status == "NEW_FINITE_PHASE_FEED_CANDIDATE_NOT_QUALIFIED_OR_OBSERVED",
      design.actualObservations.isEmpty, !f.singlePhaseAndValveTransientsObserved,
      !p.actualPhaseOrFiniteStockObserved, !p.compressibilityOrHeatCapacityObserved,
      !bed.ErgunMultiplierOrViscosityObserved, !bed.reactionKineticsQualified,
      p.totalThermalCO2StockKg == criteria.unchangedLimits.CO2ThermalStockKg,
      p.totalThermalCO2StockKg == parent.thermal.portable.chargedSolidCO2Kg,
      p.totalThermalCO2StockKg == 14, bed.maximumGasInventoryKg == 0.025,
      bed.maximumGasInventoryKg == criteria.allGasReserveKg,
      parent.thermal.finiteGasOperations.maximumColdCircuitInFlightCO2Kg == 0.002,
      f.qualifiedGammaRange == [1.2, 1.4], p.qualifiedCompressibilityFactorRange == [0.9, 1.1],
      f.minimumMeteringDischargeCoefficient == 0.7, bed.minimumScreenDischargeCoefficient == 0.5,
      bed.maximumQualifiedErgunMultiplier == 5, bed.maximumViscosityPascalSeconds == 0.00005,
      f.minimumMeteringStagnationKelvin == 350, f.maximumMeteringStagnationKelvin == 355,
      f.minimumRecuperatorConductanceWattsPerKelvin == 0.3,
      f.antiIceMaximumElectricalWattsWithin42 == 3.5,
      bed.restrictorThroatDimensionsMetres == [0.009, 0.001, 0.0002],
      bed.restrictorBodyDimensionsMetres == [0.4, 0.187, 0.0002],
      bed.innerDimensionsMetres == [0.4, 0.187, 0.23],
      bed.screenHoleCountX == 500, bed.screenHoleCountY == 231,
      bed.maximumCapturedAndGasKg == criteria.maximumCapturedPlusReservedGasKg,
      bed.maximumCapturedAndGasKg == 12,
      design.sourcing.externalHardwareOrExtraEquipmentSlots == 0, design.sourcing.extraPaidPairs == 0,
      !design.sourcing.nativeGeometryChanged, design.sourcing.newPhysicalSourceUnobserved,
      design.sourcing.feedDryMassDebitedFromExistingHeatpathKg == 5,
      criteria.unchangedLimits.electricalWattsPerUnit == parent.thermal.unchangedPerUnitElectrical.continuousWatts,
      criteria.unchangedLimits.loadedMaximumKg == parent.adoptedCriteria.portableMassMaximumKg,
      results.currentCarrierServiceHeatJoules == parent.thermalBudget.carrierRejectedSixHourJoules,
      exactDelta.currentCarrierServiceHeatJoules == results.currentCarrierServiceHeatJoules else { return false }
    return true
  }

  private func vector(_ values: [Double]) -> Bool { values.count == 3 && values.allSatisfy(\.isFinite) }
  private func massRecord(_ value: BisonCommissioningCandidateV3.SourceMassState) -> Bool {
    value.massKg.isFinite && value.massKg > 0 && vector(value.centreMetres)
      && value.inertiaAboutCentreOfMassKgM2.count == 9 && value.inertiaAboutCentreOfMassKgM2.allSatisfy(\.isFinite)
  }
  private var layoutAndRecordSourceCoherence: Bool {
    let layout = results.layout
    let divider = layout.innerPressureDivider
    guard results.status == "CONDITIONAL_FINITE_PHASE_FEED_SOURCE_NOT_QUALIFIED",
      results.actualObservations.isEmpty, results.allConditionalChecksPass,
      !results.phaseValveTransientOrKineticsQualified,
      results.sourceDesignSHA256 == Self.assetPins["bed-feed-design.json"]?.sha256,
      header.artifacts.contains(where: { $0.path == "build-bed-feed.py" && $0.sha256 == results.generatorSHA256 }),
      !results.oldSaturatedIdealChoke.equilibriumGasConditionPass,
      results.hydraulics.empiricalCorrelationQualificationRequired,
      results.fixed42ElectricalTotalWatts == criteria.unchangedLimits.electricalWattsPerUnit,
      results.totalGasInventoryUpperBoundKg == exactDelta.allGasBoundKg,
      Set(results.gasInventoryUpperComponentsKg.keys) == ["coldFeed", "postThrottleAndEntireBed", "preheater", "tankHeadspace"],
      results.phaseStates.count == 3,
      results.phaseStates.allSatisfy({ $0.bodyIndependentThermalCO2TotalKg == design.phase.totalThermalCO2StockKg }),
      divider.noUnmeteredBypassInGeometricConstruction, !divider.sealStrengthAndUniformDistributionQualified,
      divider.dimensionsMetres == design.reactor.restrictorBodyDimensionsMetres,
      divider.apertureDimensionsMetres == design.reactor.restrictorThroatDimensionsMetres,
      layout.screens.count == 2, layout.screens.allSatisfy({ $0.holeCount == [500, 231] }),
      layout.feedOuterBoxes.count == 3, layout.feedOuterBoxes.allSatisfy({ vector($0.minimumMetres) && vector($0.maximumMetres) }),
      rigid.status == "FINITE_PHASE_FEED_RIGID_CANDIDATE_NOT_QUALIFIED",
      rigid.actualObservations.isEmpty, !rigid.wall.materialQualificationObserved,
      rigid.canonicalDryAggregatePreserved, rigid.canonicalOuterGeometryUnchanged,
      rigid.bodyRespirationAndSorbentPreserved, massRecord(rigid.baseDry),
      rigid.wall.wallCellMassKg.count == 92, rigid.wall.wallCellEffectiveDensityKgPerCubicMetre.count == 92,
      rigid.freeRespiratoryGasVolumeCubicMetres == exactDelta.newRespiratoryFreeGasCubicMetres,
      layout.freeRespiratoryGasVolumeCubicMetres == rigid.freeRespiratoryGasVolumeCubicMetres,
      rigid.portableStates.count == 2, exactDelta.portableStates.count == 2,
      rigid.portableStates.allSatisfy(massRecord), contacts.cases.count == 8,
      contacts.paidForceNewtons == criteria.unchangedLimits.paidForceNewtons,
      contacts.paidWorkJoules == criteria.unchangedLimits.paidWorkJoules else { return false }
    for (record, other) in zip(rigid.portableStates, exactDelta.portableStates) {
      guard record.id == other.id, record.massKg == other.massKg,
        record.centreMetres == other.centreMetres,
        record.inertiaAboutCentreOfMassKgM2 == other.inertiaAboutCentreOfMassKgM2 else { return false }
    }
    return contacts.cases.allSatisfy { value in
      rigid.portableStates.contains(where: { $0.id == value.state })
        && (value.q == 0 || value.q == 0.3) && value.lambdaNewtons.count == 4
        && value.rotation.count == 3 && value.rotation.allSatisfy(vector)
    }
  }
}
