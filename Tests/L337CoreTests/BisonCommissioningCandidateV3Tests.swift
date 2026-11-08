import Foundation
import Testing

@testable import L337Core

struct BisonCommissioningCandidateV3Tests {
  @Test
  func exactCurrentPackagePreservesSourceRolesAndFiniteExternalPreparation() throws {
    let source = try BisonCommissioningCandidateV3.load()
    let base = try #require(CurrentNewtKitSource.bison)
    #expect(source.header.id == BisonCommissioningCandidateV3.configurationID)
    #expect(source.header.id != base.configuration && source.header.acceptedIncrement == 0)
    #expect(source.header.baseBisonSourceSHA256 == base.sourceSHA256)
    #expect(source.proposedUnitDefinitions.count == 13)
    #expect(source.proposedUnitDefinitions[7].location == .carrierCell(7))
    #expect(source.proposedUnitDefinitions[7].proposedOriginalBodyOrdinal == nil)
    #expect(source.proposedUnitDefinitions[12].location == .portable)
    #expect(source.proposedUnitDefinitions[12].proposedOriginalBodyOrdinal == 7)
    #expect(source.thermal.custody.carrierOccupiedOrdinals == [0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 11])
    #expect(source.baseDeclarations.crewPhysicalProfiles.map(\.profileID) == base.personSlots.map { $0.profile.id })
    #expect(source.thermal.carrier.gasKelvin == 280 && source.thermal.carrier.bodyReferenceKelvin == 310)
    #expect(source.thermal.portable.bodyAndGasKelvin == 190 && source.thermal.portable.coldCO2Kelvin == 185)
    #expect(source.thermal.custody.originalRoles == 12)
    #expect(!source.thermal.custody.actualIdentitiesOrAwakeStatesGranted)
    #expect(!source.thermal.biologicalCryostasisAndOperatingCrewFitnessQualified)
    let prep = source.thermal.preparationPlant
    #expect(prep.bodyKg == 101 && prep.bodyKgIsConservativePreparationUpperBound)
    #expect(prep.serviceBodyMassAtActualIssueKg == 100 && prep.notCarriedOrInventedAtBirth)
    #expect(prep.finiteElectricalEnergyJoules == 1000000000 && prep.finiteOxygenStockKg == 30.5)
    #expect(prep.finiteCO2StockKg == 14.05 && prep.CaOIsPaidMaterialStockNotRegeneratedByThisPlant)
    #expect(source.baseDeclarations.actualInventoryLoadModel.cargo.nativeUnitByCommodityIndex.count == 17)
    #expect(source.finiteOperations.requiredOperations.count == 8 && source.finiteOperations.actualOperationsPerformed.isEmpty)
    #expect(!source.sourceQualifiedForBirth && !base.sourceQualifiedForBirth)
    #expect(!CurrentNewtKitSource.resourceFileNames.contains("candidate-source.json"))
  }

  @Test
  func changedFiniteGeometryAndMassSnapshotsRemainUnqualifiedSourceRecords() throws {
    let source = try BisonCommissioningCandidateV3.load()
    let base = try #require(CurrentNewtKitSource.bison)
    #expect(source.material.innerVerticesMetres.count == 48 && source.material.innerFaces.count == 92)
    #expect(!source.material.canonicalDryMassAndMomentsMatched)
    #expect(source.momentFit.status == "PASS_POSITIVE_FINITE_WALL_AGGREGATE_MATCH")
    #expect(!source.momentFit.actualMaterialQualificationObserved && !source.momentFit.canonicalStockFacetDensitiesPreserved)
    #expect(source.material.connectedFreeGasVolumeCubicMetres == 1.4520530167055308)
    let states = source.physicalDelta.portableStates
    #expect(states.count == 2 && states[0].massKg == 371.5 && states[1].massKg == 371.5)
    #expect(states[0].massKg != base.podMass.massKilograms)
    #expect(states[0].inertiaAboutCentreOfMassKgM2 != states[1].inertiaAboutCentreOfMassKgM2)
    #expect(source.physicalDelta.variableInternalMassStateNotProvedByInstantaneousContactCases)
    #expect(source.contactReference.cases.count == 8 && source.contactReference.actualObservations.isEmpty)
    #expect(!source.radiator.thermalMaterialOrViewQualified)
    // Exact8fba closes the source ledger; actual warm-dump apparatus and
    // delivered phase/flow remain unqualified, with no physical observations.
    #expect(source.header.unaffectedBaseProofCommit == BisonCommissioningCandidateV3.parentSourceCommit)
    #expect(source.carrierReviewInputs.baseCommit == BisonCommissioningCandidateV3.parentSourceCommit)
    #expect(source.thermalBudget.allConditionalBudgetChecksPass)
    #expect(source.thermalBudget.carrierRejectedSixHourJoules == 67622400)
    #expect(source.thermalBudget.carrierFixedElectricalSixHourJoules == 10886400)
    #expect(source.thermalBudget.carrierElectricalStoredOrExportedJoules == 0)
    #expect(source.adoptedCriteria.carrierResidualDumpRequiredRatingWattsPerCell == 42)
    #expect(source.thermalBudget.carrierEnvelopeTemperatureRiseKelvin == 3.330707492324827)
    #expect(source.knownOpenSourceFindings.contains(.coldCircuitPhaseAndDeliveredFlow))
    #expect(!source.sourceQualifiedForBirth)
  }

  @Test(arguments: ["missing-preparation", "injected-authority", "old-all190", "collapsed-mass-state",
    "budget-as-observation", "extra-asset", "v2-as-candidate", "changed-base-profile", "source-id-alias", "missing-finite-operation", "reverted-carrier-heat", "stale-review-provenance"])
  func currentHashAndNamespaceRejectForgedOrIncompleteSource(fault: String) throws {
    let folder = try BisonCommissioningCandidateV3.resourceFolder()
    var assets = try BisonCommissioningCandidateV3.readAssets(from: folder)
    var base = try BisonCommissioningCandidateV3.readBaseSource()
    func edit(_ name: String, _ change: (inout [String: Any]) throws -> Void) throws {
      let bytes = try #require(assets[name])
      let decoded = try JSONSerialization.jsonObject(with: bytes)
      var object = try #require(decoded as? [String: Any])
      try change(&object)
      assets[name] = try JSONSerialization.data(withJSONObject: object)
    }
    switch fault {
    case "missing-preparation": assets.removeValue(forKey: "thermal-design.json")
    case "injected-authority":
      try edit("candidate-source.json") { object in
        object["qualifiedBirth"] = true
        object["actualObservations"] = ["forged"]
      }
    case "old-all190":
      try edit("thermal-design.json") { object in
        var carrier = try #require(object["carrier"] as? [String: Any])
        carrier["gasKelvin"] = 190
        carrier["bodyReferenceKelvin"] = 190
        object["carrier"] = carrier
      }
    case "collapsed-mass-state":
      try edit("source-physical-delta.json") { object in
        var states = try #require(object["portableStates"] as? [[String: Any]])
        states[1] = states[0]
        object["portableStates"] = states
      }
    case "budget-as-observation": try edit("thermal-results.json") { $0["actualObservations"] = ["forged"] }
    case "extra-asset": assets["legacy-alias.json"] = base
    case "v2-as-candidate": assets["candidate-source.json"] = base
    case "changed-base-profile":
      let decoded = try JSONSerialization.jsonObject(with: base)
      var object = try #require(decoded as? [String: Any])
      var profiles = try #require(object["crewPhysicalProfiles"] as? [[String: Any]])
      profiles[7]["massKg"] = 200
      object["crewPhysicalProfiles"] = profiles
      base = try JSONSerialization.data(withJSONObject: object)
    case "source-id-alias":
      try edit("candidate-source.json") { $0["id"] = CurrentBisonWideShoePhysicalSource.configurationID }
    case "missing-finite-operation":
      try edit("finite-operation-requirements.json") { object in
        var operations = try #require(object["requiredOperations"] as? [[String: Any]])
        operations.removeLast()
        object["requiredOperations"] = operations
      }
    case "reverted-carrier-heat":
      try edit("thermal-results.json") { $0["carrierRejectedSixHourJoules"] = 66420000 }
    case "stale-review-provenance":
      try edit("CARRIER-REVIEW-INPUTS.json") { $0["baseCommit"] = BisonCommissioningCandidateV3.sourceCommit }
    default: Issue.record("Unknown source-forgery control"); return
    }
    #expect(throws: (any Error).self) {
      try BisonCommissioningCandidateV3.decode(assets, baseSourceBytes: base)
    }
  }

  @Test(arguments: BisonCommissioningCandidateV3.RuntimeDimension.allCases)
  func actualUnsupportedOwnersRefuseWithoutConstantPhysicsFallback(dimension: BisonCommissioningCandidateV3.RuntimeDimension) throws {
    let source = try BisonCommissioningCandidateV3.load()
    #expect(throws: BisonCommissioningCandidateV3.Refusal.unsupportedRuntimeDimension(dimension)) {
      try source.requireRuntimeSupport(dimension)
    }
  }

  @Test
  func actualCurrentRequestCannotAliasCandidateOrChangeRetainedUnknownUnits() throws {
    let candidate = try BisonCommissioningCandidateV3.load()
    let (initialGame, request, owner, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var game = initialGame
    let context = try #require(game.gameplayContext())
    var proposed = request
    proposed.currentNewtKitConfiguration = candidate.header.id
    let base = try #require(CurrentNewtKitSource.bison)
    #expect(!base.permitsBirth(proposed, context: context) && !base.permitsBirthDefinition(proposed, context: context))
    let before = game
    #expect(throws: BisonUnitJournalError.staleContext) {
      try game.reserveBisonUnobservedUnits(request: proposed, context: context)
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    let journal = try #require(game.commander.savedBisonUnitAllocations)
    #expect(try journal.owner(for: request, in: game) == owner)
    #expect(owner.units.count == 13 && owner.units.allSatisfy {
      $0.gas == .unobserved && $0.thermal == .unobserved && $0.electrical == .unobserved
        && $0.mechanical == .unobserved && $0.operative == .unobserved && $0.physicalRoster == .unobserved
    })
  }

  @Test(arguments: ["extra-file", "symlink-root"])
  func dedicatedResourceFolderCannotBroadenExistingNamespace(fault: String) throws {
    let bundled = try BisonCommissioningCandidateV3.resourceFolder()
    let assets = try BisonCommissioningCandidateV3.readAssets(from: bundled)
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    let resources = folder.appendingPathComponent("candidate", isDirectory: true)
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    for (name, bytes) in assets { try bytes.write(to: resources.appendingPathComponent(name)) }
    let input: URL
    if fault == "extra-file" {
      try Data().write(to: resources.appendingPathComponent("unlisted.json"))
      input = resources
    } else {
      input = folder.appendingPathComponent("alias")
      try FileManager.default.createSymbolicLink(at: input, withDestinationURL: resources)
    }
    #expect(throws: (any Error).self) { try BisonCommissioningCandidateV3.readAssets(from: input) }
  }
}
