import Foundation

/// Exact authored v2 definitions, never observed unit state or a commissioning
/// receipt. No function here creates an actor, private unit identity, charge,
/// operative flag, temperature, pressure or seal observation.
struct CurrentBisonWideShoeCommissioning: Decodable, Sendable {
  struct StateDefinition: Decodable, Sendable {
    let physicalBodyOrdinal: Int?
    let physicalBodyDisplacementCubicMetres: Double
    let cavityVolumeCubicMetres: Double
    let connectedFreeGasVolumeCubicMetres: Double
    let initialAbsolutePressurePascals: Double
    let initialGasTemperatureKelvin: Double
    let initialControlSetpointKelvin: Double
    let initialPhysicalBodyTemperatureKelvin: Double?
    let initialGasMassKg: Double
    let initialOxygenMassKg: Double
    let initialNitrogenMassKg: Double
    let gasComponentID: String
    let oxygenDemandUpperBoundKgPerSecond: Double
    let carbonDioxideOutputUpperBoundKgPerSecond: Double
    let expectedCirculation: String
    let expectedCryothermalLoop: String
    let expectedElectricalIsolation: String
    let expectedMechanicalRestraint: String
    let expectedPressureEqualisationValve: String
    let expectedPressureSeal: String
    let expectedSorbent: String
    let expectedTransferSeal: String
    let initialMetabolicState: String

    var valid: Bool {
      let positive = [cavityVolumeCubicMetres, connectedFreeGasVolumeCubicMetres,
        initialAbsolutePressurePascals, initialGasTemperatureKelvin, initialControlSetpointKelvin,
        initialGasMassKg, initialOxygenMassKg, initialNitrogenMassKg]
      return positive.allSatisfy { $0.isFinite && $0 > 0 }
        && physicalBodyDisplacementCubicMetres.isFinite && physicalBodyDisplacementCubicMetres >= 0
        && connectedFreeGasVolumeCubicMetres <= cavityVolumeCubicMetres
        && (initialPhysicalBodyTemperatureKelvin.map { $0.isFinite && $0 > 0 } ?? true)
        && oxygenDemandUpperBoundKgPerSecond.isFinite && oxygenDemandUpperBoundKgPerSecond >= 0
        && carbonDioxideOutputUpperBoundKgPerSecond.isFinite && carbonDioxideOutputUpperBoundKgPerSecond >= 0
        && initialOxygenMassKg + initialNitrogenMassKg == initialGasMassKg
        && !gasComponentID.isEmpty
    }
  }

  struct CarrierCellDefinition: Decodable, Sendable {
    let originalCellOrdinal: Int
    let sourceComponentID: String
    let expectedAtBirth: StateDefinition
    let afterProvedPhysicalBodyRemoval: StateDefinition
  }

  struct PortablePodDefinition: Decodable, Sendable {
    let sourceComponentID: String
    let selectedPersonPhysicalComponentID: String
    let expectedAtBirth: StateDefinition
    let afterProvedPhysicalBodyRemoval: StateDefinition
  }

  struct PaidPair: Decodable, Sendable {
    let actuatorMovingComponentIDs: [String]
    let capComponentID: String
    let shoeComponentID: String
    let capContactFaceInCarrierMetres: [[Double]]
    let shoeContactFaceInCarrierMetres: [[Double]]
    let forceNormalInCarrier: [Double]
    let forcePointInCarrierMetres: [Double]
    let maximumNormalForceNewtons: Double
    let ordinaryContactAndPaidWorkRequired: Bool
  }

  struct PassivePair: Decodable, Sendable {
    let rodComponentID: String
    let shoeComponentID: String
    let actualAnnularMaterialQuads: [[[Double]]]
    let outerContactBoundaryInCarrierMetres: [[Double]]
    let innerVoidBoundaryInCarrierMetres: [[Double]]
    let nominalAppliedActuatorForceNewtons: Double
    let ordinaryUnilateralReactionRequired: Bool
    let noOpenBoreForceOrPairExemption: Bool
  }

  struct ServiceDefinition: Decodable, Sendable {
    let unitCount: Int
    let carrierUnitCount: Int
    let portableUnitCount: Int
    let clockOrigin: String
    let continuousPowerWatts: Double
    let onceOnlyStartupJoules: Double
    let initialUsableElectricalJoules: Double
    let initialUsableOxygenKg: Double
    let initialSorbentCapacityKgCO2: Double
    let noSilentResetRechargeOrDisabledCarrierTopUp: Bool
  }

  struct Requirements: Decodable, Sendable {
    let actualParentBirthActorAndAll12OriginalProfileBindingsRequired: Bool
    let actualPortableOriginal7BindingRequired: Bool
    let actualPressureTemperatureAndSealTestsRequired: Bool
    let completeBeforeFirstBodySnapshot: Bool
    let initialValuesDoNotProveLaterOperatingState: Bool
    let noDefaultAtmosphereTemperatureSealOrOperativeState: Bool
    let noGenericStockPersonRoleActorOrEMPImmunityGrant: Bool
    let privateActualCommissioningIdentityPerUnitRequired: Bool
    let sourceDeclarationIsNotObservedState: Bool
  }

  let schemaVersion: Int
  let id: String
  let status: String
  let parentConfigurationID: String
  let parentConfigurationSHA256: String
  let parentConfigurationBytes: Int
  let carrierCells: [CarrierCellDefinition]
  let portablePod: PortablePodDefinition
  let driveContactPairs: [PaidPair]
  let passiveDriveMaterialContactPairs: [PassivePair]
  let movingDriveComponentIDs: [String]
  let actualCommissioningRequirements: Requirements
  let finiteServicePerUnit: ServiceDefinition
  let materialContactIntegrationRequirements: String

  static func decode(_ bytes: Data) -> Self? {
    guard bytes.count == CurrentBisonWideShoePhysicalSource.commissioningByteCount,
      ScriptPackLibrary.hash(bytes) == CurrentBisonWideShoePhysicalSource.commissioningSHA256,
      let value = try? JSONDecoder().decode(Self.self, from: bytes),
      value.schemaVersion == 1,
      value.id == "SH005-current-newt-person7-wide-shoes-commissioning-v2",
      value.status == "NEW_EXPLICIT_INITIAL_STATE_SOURCE_ENGINEERING_FOLLOW_UP_PENDING_NOT_ISSUANCE_PROOF",
      value.parentConfigurationID == CurrentBisonWideShoePhysicalSource.configurationID,
      value.parentConfigurationSHA256 == CurrentBisonWideShoePhysicalSource.sourceSHA256,
      value.parentConfigurationBytes == CurrentBisonWideShoePhysicalSource.sourceByteCount,
      value.declarationsAreCoherent else { return nil }
    return value
  }

  /// Nominal common-source geometry only. Actual independently integrated
  /// poses, material support and unilateral response still require native proof.
  func matchesParts(retained: [CurrentNewtKitSource.Part], released: [CurrentNewtKitSource.ReleasedPart]) -> Bool {
    guard declarationsAreCoherent else { return false }
    let moving = Set(retained.filter { $0.stowed != $0.extended }.map(\.id))
    guard moving == Set(movingDriveComponentIDs), moving.count == 6,
      driveContactPairs.allSatisfy({ pair in
        retained.contains { $0.id == pair.capComponentID && $0.mesh.vertices.count == 8 }
          && released.contains { $0.id == pair.shoeComponentID && $0.collisionMesh?.vertices.count == 8 }
          && Set(pair.actuatorMovingComponentIDs).isSubset(of: moving)
      }),
      passiveDriveMaterialContactPairs.allSatisfy({ pair in
        retained.contains { $0.id == pair.rodComponentID && $0.mesh.vertices.count == 16 }
          && released.contains { $0.id == pair.shoeComponentID && $0.collisionMesh?.vertices.count == 8 }
      }) else { return false }
    let paidGroups = driveContactPairs.flatMap(\.actuatorMovingComponentIDs)
    return Set(paidGroups) == moving && paidGroups.count == moving.count
  }

  private var declarationsAreCoherent: Bool {
    let r = actualCommissioningRequirements
    let service = finiteServicePerUnit
    guard service.unitCount == 13, service.carrierUnitCount == 12, service.portableUnitCount == 1,
      service.clockOrigin == "actual-complete-configuration-birth-issue.issuedAt",
      service.continuousPowerWatts == 42, service.onceOnlyStartupJoules == 120000,
      service.initialUsableElectricalJoules == 1500000, service.initialUsableOxygenKg == 1,
      service.initialSorbentCapacityKgCO2 == 0.75,
      service.noSilentResetRechargeOrDisabledCarrierTopUp,
      r.actualParentBirthActorAndAll12OriginalProfileBindingsRequired,
      r.actualPortableOriginal7BindingRequired, r.actualPressureTemperatureAndSealTestsRequired,
      r.completeBeforeFirstBodySnapshot, r.initialValuesDoNotProveLaterOperatingState,
      r.noDefaultAtmosphereTemperatureSealOrOperativeState,
      r.noGenericStockPersonRoleActorOrEMPImmunityGrant,
      r.privateActualCommissioningIdentityPerUnitRequired, r.sourceDeclarationIsNotObservedState,
      carrierCells.count == 12, Set(carrierCells.map(\.originalCellOrdinal)) == Set(0..<12),
      driveContactPairs.count == 2, passiveDriveMaterialContactPairs.count == 2,
      Set(movingDriveComponentIDs).count == 6 else { return false }
    for unit in carrierCells {
      guard unit.sourceComponentID == "crew-environment-cell-" + String(unit.originalCellOrdinal),
        unit.expectedAtBirth.valid, unit.afterProvedPhysicalBodyRemoval.valid,
        unit.expectedAtBirth.physicalBodyOrdinal == (unit.originalCellOrdinal == 7 ? nil : unit.originalCellOrdinal),
        unit.afterProvedPhysicalBodyRemoval.physicalBodyOrdinal == nil else { return false }
    }
    guard portablePod.expectedAtBirth.valid, portablePod.afterProvedPhysicalBodyRemoval.valid,
      portablePod.expectedAtBirth.physicalBodyOrdinal == 7,
      portablePod.afterProvedPhysicalBodyRemoval.physicalBodyOrdinal == nil,
      Set(driveContactPairs.map(\.capComponentID)).count == 2,
      Set(driveContactPairs.map(\.shoeComponentID)).count == 2,
      Set(passiveDriveMaterialContactPairs.map(\.rodComponentID)).count == 2,
      Set(passiveDriveMaterialContactPairs.map(\.shoeComponentID)) == Set(driveContactPairs.map(\.shoeComponentID))
    else { return false }
    return driveContactPairs.allSatisfy { pair in
      pair.actuatorMovingComponentIDs.count == 3 && pair.maximumNormalForceNewtons == 2000
        && pair.ordinaryContactAndPaidWorkRequired
        && Self.quad(pair.capContactFaceInCarrierMetres) && Self.quad(pair.shoeContactFaceInCarrierMetres)
        && Self.vector(pair.forcePointInCarrierMetres) && pair.forceNormalInCarrier == [1, 0, 0]
    } && passiveDriveMaterialContactPairs.allSatisfy { pair in
      pair.nominalAppliedActuatorForceNewtons == 0 && pair.ordinaryUnilateralReactionRequired
        && pair.noOpenBoreForceOrPairExemption
        && pair.actualAnnularMaterialQuads.count == 4 && pair.actualAnnularMaterialQuads.allSatisfy(Self.quad)
        && Self.quad(pair.outerContactBoundaryInCarrierMetres) && Self.quad(pair.innerVoidBoundaryInCarrierMetres)
    }
  }

  private static func vector(_ value: [Double]) -> Bool { value.count == 3 && value.allSatisfy(\.isFinite) }
  private static func quad(_ value: [[Double]]) -> Bool { value.count == 4 && value.allSatisfy(vector) }
}
