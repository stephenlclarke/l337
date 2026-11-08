import Foundation

struct ScriptWorldSave: Codable, Sendable, Equatable {
  var libraryScreen: ScriptLibraryState?
  var simulation: ScriptSimulationSave?
  var referenceFrame: ScriptReferenceFrame?
  var contractScreen: ContractScreenSave?
  var bodies: [SpaceBody]
  var market: [MarketItem]
  var docked: Bool
  var mainStation: Bool
  var screen: Screen
  var speed: Double
  var time: Double
  var energy: Double
  var frontShield: Double
  var rearShield: Double
  var laserHeat: Double
  var jumpCountdown: Double?
  var selectedSystem: Int
  var nextBodyID: Int
  var bisonUnitJournalCheckpoint: BisonUnitJournalCheckpoint? = nil
  var valid: Bool {
    (simulation?.valid ?? true) && (referenceFrame?.valid ?? true)
      && (contractScreen?.valid ?? true) && (libraryScreen?.valid ?? true) && bodies.count <= 1024
      && bodies.reduce(0, { $0 + $1.scriptNativeUnits }) <= 1024
      && Set(bodies.map(\.id)).count == bodies.count
      && Set(bodies.compactMap(\.missionActorID)).count
        == bodies.filter { $0.missionActorID != nil }.count
      && bodies.allSatisfy { body in
        body.id >= 0 && (body.scriptNPC?.valid ?? true)
          && (body.scriptNPC == nil || body.missionActorID != nil)
          && (body.scriptShot?.valid ?? true)
          && (body.scriptShot == nil
            || body.hull == .missile && body.scriptNPC == nil
              && body.missionActorID == nil && body.missionInstanceID == nil)
          && [
            body.position.x, body.position.y, body.position.z, body.energy, body.rotation,
            body.rotationRate,
          ].allSatisfy { $0.isFinite && abs($0) <= 1e12 }
      }
      && market.count == 17
      && market.allSatisfy {
        (0...1_000_000).contains($0.price) && (0...1_000_000).contains($0.quantity)
      }
      && [speed, time, laserHeat].allSatisfy {
        $0.isFinite && (0...1e12).contains($0)
      }
      && [energy, frontShield, rearShield].allSatisfy { $0.isFinite && $0 >= 0 }
      && (jumpCountdown.map { $0.isFinite && (0...1e12).contains($0) } ?? true)
      && (0...256).contains(selectedSystem) && (0..<1_000_000_000).contains(nextBodyID)
      && nextBodyID >= (bodies.map(\.id).max() ?? 0)
  }
  func consistent(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication
  ) -> Bool {
    guard BisonUnitJournalSave.sceneIsConsistent(bodies, commander: commander) else { return false }
    guard commander.nativeSalvageSceneIsConsistent(bodies, docked: docked, atColdBoundary: true)
    else {
      diagnostics?.recordSceneFailure(
        .sceneSalvage, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    return consistentAfterNativeSalvage(
      with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
  }
  // Complete each category before the next category's record/body storage becomes active.
  @inline(never)
  private func consistentAfterNativeSalvage(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    guard
      consistentEMPScene(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else { return false }
    guard
      consistentNativeStationScene(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else { return false }
    guard
      consistentCapacityAndInterface(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else { return false }
    guard
      consistentMainStationResource(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else { return false }
    guard
      let records = missionActorConsistencyRecords(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else { return false }
    guard
      consistentProjectiles(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else { return false }
    guard
      consistentCalendarJourney(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else { return false }
    return consistentMissionActors(
      with: commander, records: records, diagnostics: diagnostics,
      diagnosticBoundary: diagnosticBoundary)
  }

  @inline(never)
  private func consistentEMPScene(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    if let emp = commander.savedEMPState {
      guard
        emp.sceneIsConsistent(
          bodies, flight: commander.flightSimulation, people: commander.nativePeople)
      else {
        diagnostics?.recordSceneFailure(
          .sceneEMP, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    } else if bodies.contains(where: {
      $0.physical?.empSource != nil || $0.physical?.empCrewPod != nil
        || $0.physical?.spawnIdentity?.producer == .emp
    }) {
      diagnostics?.recordSceneFailure(
        .sceneEMPUnowned, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    return true
  }

  @inline(never)
  private func consistentNativeStationScene(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    if let stations = commander.nativeStations {
      guard
        stations.sceneIsConsistent(
          bodies: bodies, docked: docked, mainStation: mainStation,
          system: .init(galaxy: commander.galaxy, system: commander.system),
          flight: commander.flightSimulation)
      else {
        diagnostics?.recordSceneFailure(
          .sceneStations, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    } else if bodies.contains(where: { $0.nativeStationIdentity != nil }) {
      diagnostics?.recordSceneFailure(
        .sceneStationUnowned, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    return true
  }

  @inline(never)
  private func consistentCapacityAndInterface(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    guard
      [
        (energy, commander.performance.energy), (frontShield, commander.shieldCapacity),
        (rearShield, commander.rearShieldCapacity),
      ].allSatisfy({ level, capacity in
        capacity.isFinite && capacity > 0 && level <= max(1e12, capacity)
      })
    else {
      diagnostics?.recordSceneFailure(
        .sceneCapacity, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    if screen == .library, let saved = libraryScreen, saved.mode != .books {
      guard let selected = saved.selected, commander.scriptState.books[selected] != nil else {
        diagnostics?.recordSceneFailure(
          .sceneLibrary, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    if screen == .gameOver,
      commander.scriptState.instances.values.contains(where: {
        $0.courier?.terminal == nil && $0.courier?.pendingLoss == nil
          && $0.contract?.offer.courier?.variant == .package
      })
    {
      diagnostics?.recordSceneFailure(
        .sceneCourierFatal, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    if screen == .gameOver,
      commander.scriptState.instances.values.contains(where: {
        $0.contract?.offer.freightPlan != nil && $0.savedOwnedCargo?.terminal == nil
          && $0.savedOwnedCargo?.pendingLoss == nil
      })
    {
      diagnostics?.recordSceneFailure(
        .sceneFreightFatal, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    return true
  }

  @inline(never)
  private func consistentMainStationResource(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    let stationKey = "main-orbital:\(commander.galaxy):\(commander.system)"
    if let resource = commander.scriptState.stationResources[stationKey] {
      let actual = bodies.first { $0.id == 0 && $0.hull == .station }
      if resource.destroyed {
        guard actual == nil, !(docked && mainStation),
          referenceFrame.map({ $0.station.energy <= 0 }) ?? true
        else {
          diagnostics?.recordSceneFailure(
            .sceneMainDestroyed, commander: commander, boundary: diagnosticBoundary)
          return false
        }
      } else if let actual, actual.energy != resource.energy {
        diagnostics?.recordSceneFailure(
          .sceneMainEnergy, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    return true
  }

  @inline(never)
  private func missionActorConsistencyRecords(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> [UUID: (UUID, Int, Int, ScriptOwnedActor)]? {
    var records: [UUID: (UUID, Int, Int, ScriptOwnedActor)] = [:]
    for instance in commander.scriptState.instances.values {
      for encounter in instance.ownedEncounters.values {
        for actor in encounter.actors.values {
          guard records[actor.identity] == nil else {
            diagnostics?.recordSceneFailure(
              .sceneActorDuplicate, commander: commander, boundary: diagnosticBoundary)
            return nil
          }
          let location = actor.location(in: encounter)
          records[actor.identity] = (instance.id, location.galaxy, location.system, actor)
        }
      }
    }
    return records
  }

  @inline(never)
  private func consistentProjectiles(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    let shotBodies = bodies.filter { $0.scriptShot != nil }
    let expectedShots = commander.scriptState.projectiles.values.filter { $0.presence == .present }
    guard shotBodies.count == expectedShots.count,
      expectedShots.allSatisfy({ $0.galaxy == commander.galaxy && $0.system == commander.system })
    else {
      diagnostics?.recordSceneFailure(
        .sceneShotPopulation, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    for body in shotBodies {
      guard let shot = body.scriptShot,
        let record = commander.scriptState.projectiles[shot.identity],
        record.presence == .present, record.body.id == body.id, let anchor = referenceFrame?.station
      else {
        diagnostics?.recordSceneFailure(
          .sceneShotBinding, commander: commander, boundary: diagnosticBoundary)
        return false
      }
      var canonical = shot
      canonical.velocity = anchor.orientation.inverse(shot.velocity)
      guard canonical == record.body.scriptShot else {
        diagnostics?.recordSceneFailure(
          .sceneShotCanonical, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    return true
  }

  @inline(never)
  private func consistentCalendarJourney(
    with commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    if let ledger = commander.scriptState.calendarLedger {
      if let journey = ledger.pendingJourney {
        guard !docked, jumpCountdown != nil, journey.galaxy == commander.galaxy,
          journey.origin == commander.system
        else {
          diagnostics?.recordSceneFailure(
            .scenePendingJourney, commander: commander, boundary: diagnosticBoundary)
          return false
        }
      } else if jumpCountdown != nil && !ledger.legacyUntrackedJourney {
        diagnostics?.recordSceneFailure(
          .sceneUnadmittedJump, commander: commander, boundary: diagnosticBoundary)
        return false
      }
      if ledger.legacyUntrackedJourney && (docked || jumpCountdown == nil) {
        diagnostics?.recordSceneFailure(
          .sceneLegacyJourney, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    return true
  }

  @inline(never)
  private func consistentMissionActors(
    with commander: Commander, records: [UUID: (UUID, Int, Int, ScriptOwnedActor)],
    diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) -> Bool {
    let physical = bodies.filter { $0.missionActorID != nil }
    let expected = records.values.filter { $0.3.presence == .present }
    guard physical.count == expected.count,
      expected.allSatisfy({ $0.1 == commander.galaxy && $0.2 == commander.system })
    else {
      diagnostics?.recordSceneFailure(
        .sceneActorPopulation, commander: commander, boundary: diagnosticBoundary)
      return false
    }
    for body in physical {
      var canonicalNPC = body.scriptNPC
      if let velocity = canonicalNPC?.velocity, let anchor = referenceFrame?.station {
        canonicalNPC?.velocity = anchor.orientation.inverse(velocity)
      }
      guard let identity = body.missionActorID, let record = records[identity],
        body.missionInstanceID == record.0, record.3.presence == .present,
        body.id == record.3.body.id, body.hull == record.3.body.hull,
        canonicalNPC == record.3.body.scriptNPC,
        body.energy == record.3.body.energy, body.missiles == record.3.body.missiles,
        body.ecmEnabled == record.3.body.ecmEnabled, body.hostile == record.3.body.hostile
      else {
        diagnostics?.recordSceneFailure(
          .sceneActorBinding, commander: commander, boundary: diagnosticBoundary)
        return false
      }
    }
    return true
  }
}
struct ScriptSavePointer: Codable {
  let format: String
  let schemaVersion: Int
  let generation: String
  let hashes: [String: String]
  var scope: String? = nil
  var valueCodec: String? = nil
  var bisonUnitJournalCheckpoint: BisonUnitJournalCheckpoint? = nil
}

/// Publication is synchronous inside GameRuntime: no actor reentrancy can overwrite newer simulation state.
enum ScriptSaveStore {
  @discardableResult
  static func write(
    commander: Commander, world: ScriptWorldSave, to url: URL, scope: String = "commander",
    exclusive: Bool = false, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication,
    clueTrust: ScriptClueTrustCatalog = .production,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> AlienStoragePublication? {
    try BisonUnitJournalSave.validateArchive(commander: commander, world: world,
      pointer: world.bisonUnitJournalCheckpoint)
    try validateForPublication(
      commander: commander, world: world, scope: scope, diagnostics: diagnostics,
      diagnosticBoundary: diagnosticBoundary, clueTrust: clueTrust,
      navigationBinding: navigationBinding)
    return try publishValidated(
      commander: commander, world: world, to: url, scope: scope, exclusive: exclusive,
      diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
  }
  /// Select only the current native mission envelopes; older families retain their fallback.
  static func nativeMissionPublicationVersion(_ commander: borrowing Commander, alien: Bool) -> Int?
  {
    if NativeC01ReservationAuditSave.hasClaims(commander) {
      return alien
        ? NativeC01ReservationAuditSave.alienVersion : NativeC01ReservationAuditSave.version
    }
    let defensive = NativeDefensiveFlightSave.hasClaims(commander)
    let surveyor = NativeC01SurveyorSave.hasClaims(commander)
    let lesson = NativeSafeGunnerySave.hasClaims(commander)
    let practice = NativePracticeSave.hasClaims(commander)
    let crewLog = NativeInductionCrewLogSave.hasClaims(commander)
    guard defensive || surveyor || lesson || practice || crewLog else { return nil }
    return max(
      NativeDefensiveFlightSave.publicationVersion(
        defensive: defensive, lesson: lesson, practice: practice, crewLog: crewLog, alien: alien
      ) ?? (alien ? NativeInductionCrewLogSave.alienVersion : NativeInductionCrewLogSave.version),
      surveyor ? (alien ? NativeC01SurveyorSave.alienVersion : NativeC01SurveyorSave.version) : 0)
  }

  /// Current feature namespaces are selected from actual retained claims, never invented predecessors.
  @inline(never)
  static func publicationSchema(_ commander: borrowing Commander, alien: Bool) -> Int {
    if NativeSecondCommoditySaleSave.hasClaims(commander) {
      return alien ? NativeSecondCommoditySaleSave.alienVersion : NativeSecondCommoditySaleSave.version
    }
    if CurrentNewtKitSave.hasClaims(commander) {
      return alien ? CurrentNewtKitSave.alienVersion : CurrentNewtKitSave.version
    }
    if NativeMemoryAtlasWatcherEnvelope.hasClaims(commander) {
      return alien ? NativeMemoryAtlasWatcherEnvelope.alienVersion : NativeMemoryAtlasWatcherEnvelope.version
    }
    if NativeFirstCommodityTradeSave.hasClaims(commander) {
      return alien ? NativeFirstCommodityTradeSave.alienVersion : NativeFirstCommodityTradeSave.version
    }
    if let inquiry = NativeC01InquirySave.publicationVersion(commander, alien: alien) {
      return inquiry
    }
    return featurePublicationSchema(commander, alien: alien)
  }

  /// The existing feature selection, also used to compose each current inquiry archive's raw gates.
  @inline(never)
  static func featurePublicationSchema(_ commander: borrowing Commander, alien: Bool) -> Int {
    if let version = nativeMissionPublicationVersion(commander, alien: alien) {
      return version
    }
    if NativeInductionArkSave.hasClaims(commander) {
      return alien ? NativeInductionArkSave.alienVersion : NativeInductionArkSave.version
    }
    if NativeWayfarerInductionSave.hasClaims(commander) {
      return alien ? NativeWayfarerInductionSave.alienVersion : NativeWayfarerInductionSave.version
    }
    if NativeFirstCommoditySaleSave.hasClaims(commander) {
      return alien ? NativeFirstCommoditySaleSave.alienVersion : NativeFirstCommoditySaleSave.version
    }
    if NativeGlassMeridianSave.hasClaims(commander) {
      return alien ? NativeGlassMeridianSave.alienVersion : NativeGlassMeridianSave.version
    }
    if NativeFleetDiscoverySave.hasClaims(commander) {
      return alien ? NativeFleetDiscoverySave.alienVersion : NativeFleetDiscoverySave.version
    }
    if NativeFlightReceptionSave.hasClaims(commander) {
      return alien ? NativeFlightReceptionSave.alienVersion : NativeFlightReceptionSave.version
    }
    if WayfarerFieldReliefSave.hasClaims(commander) {
      return alien ? WayfarerFieldReliefSave.alienVersion : WayfarerFieldReliefSave.version
    }
    if NativeMeasuredExtractionSave.hasClaims(commander) {
      return alien ? NativeMeasuredExtractionSave.alienVersion : NativeMeasuredExtractionSave.version
    }
    if WayfarerRecordRecoverySave.hasClaims(commander) {
      return alien ? WayfarerRecordRecoverySave.alienVersion : WayfarerRecordRecoverySave.version
    }
    if NativeIdentifiedSalvageSave.hasClaims(commander) {
      return alien ? NativeIdentifiedSalvageSave.alienVersion : NativeIdentifiedSalvageSave.version
    }
    if NativeOriginalSurveySave.hasClaims(commander) {
      return alien ? NativeOriginalSurveySave.alienVersion : NativeOriginalSurveySave.version
    }
    if NativeOriginalEvacuationSave.hasClaims(commander) {
      return alien ? NativeOriginalEvacuationSave.alienVersion : NativeOriginalEvacuationSave.version
    }
    if NativeOriginalRescueJourneySave.hasClaims(commander) {
      return alien ? NativeOriginalRescueJourneySave.alienVersion : NativeOriginalRescueJourneySave.version
    }
    if NativeOrbitalOutlookJourneySave.hasClaims(commander) {
      return alien ? NativeOrbitalOutlookJourneySave.alienVersion : NativeOrbitalOutlookJourneySave.version
    }
    if NativeStationPassengerJourneySave.hasClaims(commander) {
      return alien ? NativeStationPassengerJourneySave.alienVersion : NativeStationPassengerJourneySave.version
    }
    if OriginalConsentedFreightSupplySave.hasClaims(commander) {
      return alien ? OriginalConsentedFreightSupplySave.alienVersion : OriginalConsentedFreightSupplySave.version
    }
    if WayfarerRepairLoopSave.hasClaims(commander) {
      return alien ? WayfarerRepairLoopSave.alienVersion : WayfarerRepairLoopSave.version
    }
    if WayfarerColdChainSave.seedTransferHasClaims(commander) {
      return alien ? WayfarerRepairLoopSave.alienVersion : WayfarerRepairLoopSave.version
    }
    if WayfarerColdChainSave.hasClaims(commander) {
      return alien ? WayfarerColdChainSave.alienVersion : WayfarerColdChainSave.version
    }
    if ScriptNavigationTradeSave.hasClaims(commander) {
      return alien ? ScriptNavigationTradeSave.alienVersion : ScriptNavigationTradeSave.version
    }
    if commander.scriptState.savedClueJournal != nil {
      return alien ? ScriptClueVersionedSave.alienVersion : ScriptClueVersionedSave.version
    }
    if commander.usesFreightNativeSaveVersion {
      return alien ? ScriptFreightVersionedSave.alienVersion : ScriptFreightVersionedSave.version
    }
    if alien { return 27 }
    if commander.usesEconomyMiningSaveVersion { return 26 }
    if commander.usesRingMiningSaveVersion { return 25 }
    if commander.usesElectricalSaveVersion { return 25 }
    if commander.usesModularDriveSaveVersion { return 25 }
    if commander.usesNativePeopleSaveVersion { return 24 }
    if commander.scriptState.financeLedger != nil { return 23 }
    if commander.usesEMPSaveVersion { return 22 }
    return 21
  }

  /// Readonly current-format/size preflight for private C01 birth storage.
  /// Nil navigation binding is the actual non-navigation path; callers needing
  /// one must forward the genuine binding or let the original guard refuse.
  static func validateC01InquiryPrivateBirthCandidate(
    commander: Commander, world: ScriptWorldSave, scope: String,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws {
    try validateForPublication(commander: commander, world: world, scope: scope,
      diagnostics: nil, diagnosticBoundary: .publication, clueTrust: .production,
      navigationBinding: navigationBinding)
    try validateSemanticPublicationSizes(commander: commander, diagnostics: nil,
      diagnosticBoundary: .publication)
  }

  // Keep the original read-only parameter convention for the unchanged logical guard expressions.
  @inline(never)
  private static func validateForPublication(
    commander: Commander, world: ScriptWorldSave, scope: String,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary,
    clueTrust: ScriptClueTrustCatalog, navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    guard ["commander", "gallery"].contains(scope), commander.scriptState.calendarLedger != nil,
      commander.valid, world.valid, NativePracticeSave.sceneValid(world, commander: commander),
      NativeC01InquirySave.retainedSourceAndWorldValid(commander, world: world),
      ScriptFreightVersionedSave.validateClaims(commander),
      NativeDefensiveFlightSave.validateClaims(commander),
      NativeSafeGunnerySave.validateClaims(commander),
      NativePracticeSave.validateClaims(commander),
      NativeInductionCrewLogSave.validateClaims(commander),
      NativeInductionArkSave.validateClaims(commander),
      NativeWayfarerInductionSave.validateClaims(commander),
      NativeFirstCommoditySaleSave.validateClaims(commander),
      NativeSecondCommoditySaleSave.validateClaims(commander),
      NativeFirstCommodityTradeSave.validateClaims(commander),
      NativeUnderTowSave.validateClaims(commander),
      NativeBorrowedVoiceSave.validateClaims(commander),
      NativeTitheCommissionSave.validateClaims(commander),
      NativeQuietChoirSave.validateClaims(commander),
      NativeMemoryAtlasSave.validateClaims(commander),
      NativeMemoryAtlasWatcherSourceSave.validateClaims(commander),
      NativeSignedPassageOpeningSave.validateClaims(commander),
      NativeAssemblyOfOrbitsSave.validateClaims(commander),
      NativeGlassMeridianSave.validateClaims(commander),
      NativeFleetDiscoverySave.validateClaims(commander),
      NativeFlightReceptionSave.validateClaims(commander),
      WayfarerFieldReliefSave.validateClaims(commander, requireRecordedLoss: true),
      NativeMeasuredExtractionSave.validateClaims(commander, requireRecordedLoss: true),
      WayfarerRecordRecoverySave.validateClaims(commander, requireRecordedLoss: true),
      NativeIdentifiedSalvageSave.validateClaims(commander, requireRecordedLoss: true),
      NativeOriginalSurveySave.validateClaims(commander),
      NativeOriginalEvacuationSave.validateClaims(commander),
      NativeOriginalRescueJourneySave.validateClaims(commander),
      NativeOrbitalOutlookJourneySave.validateClaims(commander),
      NativeStationPassengerJourneySave.validateClaims(commander),
      OriginalConsentedFreightSupplySave.validateClaims(commander),
      NativeIsolationWorkParentSave.validateClaims(commander),
      NativeIsolationWorkSave.validateClaims(commander),
      NativeIsolationContractSave.validateClaims(commander),
      commander.usesFreightNativeSaveVersion || !commander.usesProviderContractSaveVersion,
      world.consistent(
        with: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    else {
      if let diagnostics, !diagnostics.contains(diagnosticBoundary) {
        // True guard prefix; bits 32/64/1/2/4/8/16: scope, calendar, commander, world, claims,
        // envelope, scene. Later bits are unobserved, not evidence their predicates failed.
        let checks = ScriptRefusalObservation.storeChecks(commander, world: world, scope: scope)
        diagnostics.record(
          diagnosticBoundary,
          .init(
            stage: .storeValidation, error: SaveError.invalidCommander, commander: commander,
            checks: checks))
      }
      throw SaveError.invalidCommander
    }
    guard ScriptClueVersionedSave.validateClaims(commander, trust: clueTrust),
      ScriptNavigationTradeSave.validateClaims(commander, binding: navigationBinding),
      WayfarerColdChainSave.validateClaims(commander),
      WayfarerRepairLoopSave.validateClaims(commander),
      OriginalConsentedFreightSupplySave.validateClaims(commander)
    else {
      throw SaveError.invalidCommander
    }
  }
  // The original deliberate header copy and all encoding/file work begin only after validation returns.
  @inline(never)
  private static func publishValidated(
    commander: Commander, world: ScriptWorldSave, to url: URL, scope: String, exclusive: Bool,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary
  ) throws -> AlienStoragePublication? {
    try validateSemanticPublicationSizes(
      commander: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    let generation = UUID().uuidString
    let root = url.appendingPathExtension("missions")
    let directory = root.appendingPathComponent(generation, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let alienPublication = try AlienStorageVersionedSave.stage(commander, in: directory)
    let encoder = ScriptValueStorage.encoder()
    let chunks = try encodePublicationChunks(
      commander: commander, world: world, alienPublication: alienPublication, encoder: encoder)
    return try publishEncodedChunks(
      commander: commander, chunks: chunks, encoder: encoder, alienPublication: alienPublication,
      directory: directory, generation: generation, to: url, scope: scope, exclusive: exclusive,
      diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
  }

  @inline(never)
  private static func validateSemanticPublicationSizes(
    commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) throws {
    let semantic = JSONEncoder()
    let scriptSizeValid = try commander.withReadOnlyScriptState {
      try semantic.encode($0).count <= 33_554_432
    }
    guard scriptSizeValid, try semantic.encode(commander.contracts).count <= 33_554_432
    else {
      try refuseSemanticPublicationSize(
        commander: commander, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    }
  }

  @inline(never)
  private static func refuseSemanticPublicationSize(
    commander: Commander, diagnostics: ScriptRefusalDiagnostic?,
    diagnosticBoundary: ScriptRefusalBoundary
  ) throws -> Never {
    diagnostics?.record(
      diagnosticBoundary,
      .init(stage: .storeSize, error: SaveError.invalidCommander, commander: commander))
    throw SaveError.invalidCommander
  }

  /// Own the one deliberate header copy without retaining its preparation frame in encoding.
  private final class PreparedPublicationHeader: Sendable, Encodable {
    let commander: Commander
    init(_ commander: consuming Commander) {
      self.commander = consume commander
    }

    @inline(never)
    func encode(to encoder: any Encoder) throws { try commander.encode(to: encoder) }
  }

  @inline(never)
  private static func preparePublicationHeader(
    commander: borrowing Commander, alienPublication: AlienStoragePublication?
  ) -> PreparedPublicationHeader {
    var header = copy commander
    header.publishAlienStorage(alienPublication)
    header.scriptState = ScriptEngineState()
    header.contracts = ScriptContractState()
    return PreparedPublicationHeader(consume header)
  }

  @inline(never)
  private static func encodePublicationHeader(
    commander: borrowing Commander, alienPublication: AlienStoragePublication?, encoder: JSONEncoder
  ) throws -> Data {
    let header = preparePublicationHeader(commander: commander, alienPublication: alienPublication)
    return try encodePreparedPublicationHeader(header, encoder: encoder)
  }

  @inline(never)
  private static func encodePreparedPublicationHeader(
    _ header: PreparedPublicationHeader, encoder: JSONEncoder
  ) throws -> Data {
    try encoder.encode(header)
  }

  @inline(never)
  private static func encodePublicationMissions(
    commander: borrowing Commander, encoder: JSONEncoder
  ) throws -> Data {
    try encoder.encode(commander.scriptState)
  }

  @inline(never)
  private static func encodePublicationWorld(
    world: borrowing ScriptWorldSave, encoder: JSONEncoder
  ) throws -> Data {
    try encoder.encode(world)
  }

  @inline(never)
  private static func encodePublicationContracts(
    commander: borrowing Commander, encoder: JSONEncoder
  ) throws -> Data {
    try encoder.encode(commander.contracts)
  }

  @inline(never)
  private static func encodePublicationChunks(
    commander: borrowing Commander, world: borrowing ScriptWorldSave,
    alienPublication: AlienStoragePublication?, encoder: JSONEncoder
  ) throws -> [String: Data] {
    [
      "commander.json": try encodePublicationHeader(
        commander: commander, alienPublication: alienPublication, encoder: encoder),
      "missions.json": try encodePublicationMissions(commander: commander, encoder: encoder),
      "world.json": try encodePublicationWorld(world: world, encoder: encoder),
      "contracts.json": try encodePublicationContracts(commander: commander, encoder: encoder),
    ]
  }

  @inline(never)
  private static func publishEncodedChunks(
    commander: Commander, chunks encoded: [String: Data], encoder: JSONEncoder,
    alienPublication: AlienStoragePublication?, directory: URL, generation: String,
    to url: URL, scope: String, exclusive: Bool,
    diagnostics: ScriptRefusalDiagnostic?, diagnosticBoundary: ScriptRefusalBoundary
  ) throws -> AlienStoragePublication? {
    var chunks = encoded
    if let alienPublication {
      let store = try AlienStoragePageStore(directory: directory)
      let rootData = try store.readGenerationRoot()
      guard ScriptPackLibrary.hash(rootData) == alienPublication.after.reference?.rootHash else {
        throw AlienStorageError.hashMismatch
      }
      chunks[AlienStorageVersionedSave.rootName] = rootData
    }
    guard chunks["commander.json"]!.count <= 4_194_304,
      chunks["missions.json"]!.count <= 134_217_728,
      chunks["world.json"]!.count <= 8_388_608
        && chunks["contracts.json"]!.count <= 134_217_728
    else {
      diagnostics?.record(
        diagnosticBoundary,
        .init(stage: .storeSize, error: SaveError.invalidCommander, commander: commander))
      throw SaveError.invalidCommander
    }
    let schema = publicationSchema(commander, alien: alienPublication != nil)
    for (name, data) in chunks {
      let location: ScriptSaveJSONPreflight.InquiryArchiveLocation =
        name == "commander.json" ? .commander : name == "world.json" ? .world
        : name == "missions.json" ? .missions : .contracts
      try NativeSecondCommoditySaleSave.validateFields(data, location: location, schema: schema)
      let kitSchema = NativeSecondCommoditySaleSave.contains(schema)
        && CurrentNewtKitSave.hasClaims(commander)
        ? (alienPublication != nil ? CurrentNewtKitSave.alienVersion : CurrentNewtKitSave.version)
        : schema
      try CurrentNewtKitSave.validateFields(data, location: location, schema: kitSchema)
      try BisonUnitJournalSave.validateFields(data, location: name == "commander.json" ? .commander
        : name == "world.json" ? .world : .other)
    }
    // Never replace an old generation; a failed publication leaves the previous pointer valid.
    if alienPublication != nil {
      let store = try AlienStoragePageStore(directory: directory)
      for key in chunks.keys.sorted() where key != AlienStorageVersionedSave.rootName {
        let limit =
          key == "commander.json" ? 4_194_304 : key == "world.json" ? 8_388_608 : 134_217_728
        try store.writeGenerationChunk(chunks[key]!, name: key, maximumBytes: limit)
      }
    } else {
      for key in chunks.keys.sorted() {
        try chunks[key]!.write(to: directory.appendingPathComponent(key), options: .atomic)
      }
    }
    let pointer = ScriptSavePointer(
      format: "elite-script-save",
      schemaVersion: publicationSchema(commander, alien: alienPublication != nil),
      generation: generation,
      hashes: chunks.mapValues(ScriptPackLibrary.hash), scope: scope,
      valueCodec: ScriptValueStorage.codec,
      bisonUnitJournalCheckpoint: try BisonUnitJournalSave.checkpoint(commander))
    let bytes = try encoder.encode(pointer)
    try CommanderSavePublication.write(bytes, to: url, exclusive: exclusive)
    return alienPublication
  }
  static func generationDirectory(_ generation: String, from url: URL) throws -> URL {
    guard UUID(uuidString: generation)?.uuidString == generation else {
      throw SaveError.invalidCommander
    }
    return url.appendingPathExtension("missions").appendingPathComponent(
      generation, isDirectory: true)
  }
  static func read(
    _ pointerBytes: Data, from url: URL, clueTrust: ScriptClueTrustCatalog = .production,
    navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws -> (Commander, ScriptWorldSave) {
    guard pointerBytes.count <= 262144 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(pointerBytes)
    try NativeMemoryAtlasWatcherEnvelope.validateFields(pointerBytes, location: .pointer, schema: nil)
    try NativeFirstCommodityTradeSave.validateFields(pointerBytes, location: .pointer, schema: nil)
    try NativeSecondCommoditySaleSave.validateFields(pointerBytes, location: .pointer, schema: nil)
    _ = try NativeC01InquirySave.validateFields(pointerBytes, location: .pointer, schema: nil)
    try NativeDefensiveFlightSave.validateFields(pointerBytes, part: .contracts, schema: nil)
    try NativeSafeGunnerySave.validateFields(pointerBytes, part: .contracts, schema: nil)
    try NativePracticeSave.validateFields(pointerBytes, part: .contracts, schema: nil)
    try NativeUnderTowSave.validateFields(pointerBytes, part: .contracts)
    try NativeBorrowedVoiceSave.validateFields(pointerBytes, part: .contracts)
    try NativeTitheCommissionSave.validateFields(pointerBytes, part: .contracts)
    try NativeQuietChoirSave.validateFields(pointerBytes, part: .contracts)
    try NativeMemoryAtlasSave.validateFields(pointerBytes, part: .contracts)
    try NativeSignedPassageOpeningSave.validateFields(pointerBytes, part: .contracts)
    try NativeAssemblyOfOrbitsSave.validateFields(pointerBytes, part: .contracts)
    try NativeIsolationWorkParentSave.validateFields(pointerBytes, part: .contracts)
    try NativeIsolationWorkSave.validateFields(pointerBytes, part: .contracts)
    try ScriptSaveJSONPreflight.validateRepairLoopFields(pointerBytes, part: .contracts)
    try ScriptClueVersionedSave.validateFields(pointerBytes, part: .contracts, schema: nil)
    try ScriptNavigationTradeSave.validateFields(pointerBytes, part: .contracts, schema: nil)
    try CurrentNewtKitSave.validateFields(pointerBytes, location: .pointer, schema: nil)
    try BisonUnitJournalSave.validateFields(pointerBytes, location: .pointer)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: pointerBytes)
    let secondEnvelope = NativeSecondCommoditySaleSave.contains(pointer.schemaVersion)
    let inquiryComposition = try NativeC01InquiryArchiveComposition.prepare(pointer, from: url)
    let newtEnvelope = CurrentNewtKitSave.contains(pointer.schemaVersion)
      || (secondEnvelope && inquiryComposition?.hasNewtClaims == true)
    let watcherEnvelope = NativeMemoryAtlasWatcherEnvelope.contains(pointer.schemaVersion)
      || ((newtEnvelope || secondEnvelope) && inquiryComposition?.hasWatcherClaims == true)
    let tradeEnvelope = NativeFirstCommodityTradeSave.contains(pointer.schemaVersion)
      || ((watcherEnvelope || newtEnvelope || secondEnvelope)
        && inquiryComposition?.hasTradeClaims == true)
    let inquiryEnvelope = NativeC01InquirySave.contains(pointer.schemaVersion)
      || ((tradeEnvelope || watcherEnvelope || newtEnvelope || secondEnvelope)
        && inquiryComposition?.hasInquiryClaims == true)
    let featureEnvelopeSchema = inquiryComposition?.featureSchema ?? pointer.schemaVersion
    // The closed current service envelope admits W02, W03 or both after feature validation.
    let reservationEnvelope = NativeC01ReservationAuditSave.contains(featureEnvelopeSchema)
    let surveyorEnvelope =
      reservationEnvelope || NativeC01SurveyorSave.contains(featureEnvelopeSchema)
    let defensiveFlightEnvelope = NativeDefensiveFlightSave.contains(featureEnvelopeSchema)
    let safeGunneryEnvelope = NativeSafeGunnerySave.contains(featureEnvelopeSchema)
    let practiceEnvelope = NativePracticeSave.contains(featureEnvelopeSchema)
    let crewLogEnvelope = NativeInductionCrewLogSave.contains(featureEnvelopeSchema)
    let arkEnvelope = NativeInductionArkSave.contains(featureEnvelopeSchema)
    let inductionEnvelope =
      defensiveFlightEnvelope || surveyorEnvelope || safeGunneryEnvelope || practiceEnvelope
      || arkEnvelope || NativeWayfarerInductionSave.contains(featureEnvelopeSchema)
    let commerceEnvelope = NativeFirstCommoditySaleSave.contains(featureEnvelopeSchema)
    let glassEnvelope = NativeGlassMeridianSave.contains(featureEnvelopeSchema)
    let fleetEnvelope = NativeFleetDiscoverySave.contains(featureEnvelopeSchema)
    let flightReceptionEnvelope = NativeFlightReceptionSave.contains(featureEnvelopeSchema)
    let fieldReliefEnvelope = WayfarerFieldReliefSave.contains(featureEnvelopeSchema)
    let measuredExtractionEnvelope = NativeMeasuredExtractionSave.contains(featureEnvelopeSchema)
    let recordRecoveryEnvelope = WayfarerRecordRecoverySave.contains(featureEnvelopeSchema)
    let identifiedSalvageEnvelope = NativeIdentifiedSalvageSave.contains(featureEnvelopeSchema)
    let survey = NativeOriginalSurveySave.contains(featureEnvelopeSchema)
    let evacuation = NativeOriginalEvacuationSave.contains(featureEnvelopeSchema)
    let originalRescue = NativeOriginalRescueJourneySave.contains(featureEnvelopeSchema)
    let outlook = NativeOrbitalOutlookJourneySave.contains(featureEnvelopeSchema)
    let stationJourney = NativeStationPassengerJourneySave.contains(featureEnvelopeSchema)
    let supply = OriginalConsentedFreightSupplySave.contains(featureEnvelopeSchema)
    let serviceEnvelope = WayfarerRepairLoopSave.contains(featureEnvelopeSchema)
    let coldChain = WayfarerColdChainSave.contains(featureEnvelopeSchema)
    let clues = ScriptClueVersionedSave.contains(featureEnvelopeSchema)
    let navigation = ScriptNavigationTradeSave.contains(featureEnvelopeSchema)
    let freight =
      featureEnvelopeSchema == ScriptFreightVersionedSave.version
      || featureEnvelopeSchema == ScriptFreightVersionedSave.alienVersion
    let alien =
      pointer.schemaVersion == NativeSecondCommoditySaleSave.alienVersion
      || pointer.schemaVersion == CurrentNewtKitSave.alienVersion
      || pointer.schemaVersion == NativeC01InquirySave.alienVersion
      || pointer.schemaVersion == NativeFirstCommodityTradeSave.alienVersion
      || pointer.schemaVersion == NativeMemoryAtlasWatcherEnvelope.alienVersion
      || pointer.schemaVersion == 27
      || pointer.schemaVersion == NativePracticeSave.alienVersion
      || pointer.schemaVersion == NativeSafeGunnerySave.alienVersion
      || pointer.schemaVersion == NativeDefensiveFlightSave.alienVersion
      || NativeInductionArkSave.isAlien(pointer.schemaVersion)
      || NativeWayfarerInductionSave.isAlien(pointer.schemaVersion)
      || pointer.schemaVersion == NativeFirstCommoditySaleSave.alienVersion
      || pointer.schemaVersion == NativeC01ReservationAuditSave.alienVersion
      || pointer.schemaVersion == NativeC01SurveyorSave.alienVersion
      || pointer.schemaVersion == NativeGlassMeridianSave.alienVersion
      || pointer.schemaVersion == NativeFleetDiscoverySave.alienVersion
      || pointer.schemaVersion == NativeFlightReceptionSave.alienVersion
      || pointer.schemaVersion == WayfarerFieldReliefSave.alienVersion
      || pointer.schemaVersion == NativeMeasuredExtractionSave.alienVersion
      || pointer.schemaVersion == WayfarerRecordRecoverySave.alienVersion
      || pointer.schemaVersion == NativeIdentifiedSalvageSave.alienVersion
      || pointer.schemaVersion == NativeOriginalSurveySave.alienVersion
      || pointer.schemaVersion == NativeOriginalEvacuationSave.alienVersion
      || pointer.schemaVersion == NativeOriginalRescueJourneySave.alienVersion
      || pointer.schemaVersion == NativeOrbitalOutlookJourneySave.alienVersion
      || pointer.schemaVersion == NativeStationPassengerJourneySave.alienVersion
      || pointer.schemaVersion == OriginalConsentedFreightSupplySave.alienVersion
      || pointer.schemaVersion == WayfarerRepairLoopSave.alienVersion
      || pointer.schemaVersion == WayfarerColdChainSave.alienVersion
      || pointer.schemaVersion == ScriptClueVersionedSave.alienVersion
      || pointer.schemaVersion == ScriptNavigationTradeSave.alienVersion
      || pointer.schemaVersion == ScriptFreightVersionedSave.alienVersion
    var names: Set<String> = ["commander.json", "missions.json", "world.json", "contracts.json"]
    if alien { names.insert(AlienStorageVersionedSave.rootName) }
    guard pointer.format == "elite-script-save",
      pointer.schemaVersion >= 21,
      pointer.schemaVersion <= 27 || freight || clues || navigation || coldChain
        || serviceEnvelope || supply || stationJourney || outlook || originalRescue || evacuation
        || survey || identifiedSalvageEnvelope || inductionEnvelope || commerceEnvelope
        || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope || inquiryEnvelope || tradeEnvelope || watcherEnvelope
        || newtEnvelope || secondEnvelope,
      UUID(uuidString: pointer.generation)?.uuidString == pointer.generation,
      Set(pointer.hashes.keys) == names,
      ["commander", "gallery"].contains(pointer.scope ?? "")
    else { throw SaveError.invalidCommander }
    guard pointer.valueCodec == ScriptValueStorage.codec else { throw SaveError.invalidCommander }
    let storedLimit = 134_217_728
    let directory = try generationDirectory(pointer.generation, from: url)
    var chunks: [String: Data] = [:]
    var limits = [
      ("commander.json", 4_194_304), ("missions.json", storedLimit), ("world.json", 8_388_608),
    ]
    limits.append(("contracts.json", storedLimit))
    if alien {
      limits.append((AlienStorageVersionedSave.rootName, AlienStoragePageCodec.maximumRootBytes))
    }
    for (name, limit) in limits {
      let location = directory.appendingPathComponent(name)
      let properties = try location.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard properties.isRegularFile == true, properties.isSymbolicLink != true,
        (properties.fileSize ?? Int.max) <= limit
      else { throw SaveError.invalidCommander }
      let data: Data
      if let retained = inquiryComposition?.chunks[name] {
        data = retained
      } else {
        data = try CommanderSaveInput.read(
          from: location, maximumBytes: limit, denySymbolicLinks: true)
      }
      guard data.count <= limit, ScriptPackLibrary.hash(data) == pointer.hashes[name] else {
        throw SaveError.invalidCommander
      }
      if inquiryComposition == nil {
        try NativeSecondCommoditySaleSave.validateFields(
          data, location: name == "commander.json" ? .commander
            : name == "missions.json" ? .missions : name == "world.json" ? .world : .contracts,
          schema: pointer.schemaVersion)
        try ScriptSaveJSONPreflight.validate(data)
        let inquiryLocation: ScriptSaveJSONPreflight.InquiryArchiveLocation =
          name == "missions.json" ? .missions
          : name == "commander.json" ? .commander
          : name == "contracts.json" ? .contracts : .world
        try CurrentNewtKitSave.validateFields(
          data, location: inquiryLocation, schema: pointer.schemaVersion)
        try NativeMemoryAtlasWatcherEnvelope.validateFields(
          data, location: inquiryLocation, schema: pointer.schemaVersion)
        try NativeFirstCommodityTradeSave.validateFields(
          data, location: inquiryLocation, schema: pointer.schemaVersion)
        _ = try NativeC01InquirySave.validateFields(
          data, location: inquiryLocation, schema: pointer.schemaVersion)
      }
      try BisonUnitJournalSave.validateFields(data, location: name == "commander.json" ? .commander
        : name == "world.json" ? .world : .other)
      if name == "world.json" {
        try ScriptClueVersionedSave.validateFields(data, part: .contracts, schema: nil)
        try ScriptNavigationTradeSave.validateFields(data, part: .contracts, schema: nil)
      }
      let nativePart: ScriptFreightVersionedSave.Part? =
        name == "commander.json"
        ? .commander
        : name == "missions.json" ? .missions : name == "contracts.json" ? .contracts : nil
      var featureSchema = featureEnvelopeSchema
      // Composition already checked these exact hash-pinned bytes before its typed decode.
      if inquiryComposition == nil {
        try NativeUnderTowSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeBorrowedVoiceSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeTitheCommissionSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeQuietChoirSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeMemoryAtlasSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeSignedPassageOpeningSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeAssemblyOfOrbitsSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeIsolationWorkParentSave.validateFields(data, part: nativePart ?? .contracts)
        try NativeIsolationWorkSave.validateFields(data, part: nativePart ?? .contracts)
      }
      if let nativePart {
        try NativeDefensiveFlightSave.validateArchiveFields(
          data, part: nativePart, schema: featureEnvelopeSchema, alien: alien)
        // Both service profiles were checked against the actual envelope before lower gates run.
        if inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
          || flightReceptionEnvelope
          || fieldReliefEnvelope
          || measuredExtractionEnvelope
          || recordRecoveryEnvelope
          || identifiedSalvageEnvelope
          || survey || evacuation
          || originalRescue || outlook
          || coldChain || serviceEnvelope
          || supply
          || stationJourney
        {
          featureSchema = try WayfarerColdChainSave.mappedSchema(
            data, part: nativePart, alien: alien)
        }
      } else {
        try NativeDefensiveFlightSave.validateFields(data, part: .contracts, schema: nil)
        try NativeSafeGunnerySave.validateFields(data, part: .contracts, schema: nil)
        try NativePracticeSave.validateFields(data, part: .contracts, schema: nil)
        try ScriptSaveJSONPreflight.validateRepairLoopFields(data, part: .contracts)
      }
      if name == "commander.json" {
        // This helper's >=27 branch describes Alien storage, not every newer envelope.
        let alienHeaderSchema =
          secondEnvelope || newtEnvelope || watcherEnvelope || tradeEnvelope || inquiryEnvelope
            || inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
            || flightReceptionEnvelope
            || fieldReliefEnvelope
            || measuredExtractionEnvelope
            || recordRecoveryEnvelope
            || identifiedSalvageEnvelope
            || survey || evacuation
            || originalRescue || outlook || freight
            || clues || navigation
            || coldChain
            || serviceEnvelope || supply
            || stationJourney
          ? (alien ? 27 : 26) : pointer.schemaVersion
        try AlienStorageVersionedSave.validateHeader(data, schema: alienHeaderSchema)
        try ScriptSaveJSONPreflight.validateFreightFields(
          data, part: .commander, schema: featureSchema)
      } else if name == "missions.json" {
        try ScriptSaveJSONPreflight.validateFreightFields(
          data, part: .missions, schema: featureSchema)
      } else if name == "contracts.json" {
        try ScriptSaveJSONPreflight.validateFreightFields(
          data, part: .contracts, schema: featureSchema)
      }
      if name == "commander.json", pointer.schemaVersion < 26 {
        try EconomyMiningVersionedSave.rejectFields(data)
      }
      if name == "commander.json", pointer.schemaVersion < 25 {
        try RingMiningVersionedSave.rejectFields(data)
        try HyperspaceDriveVersionedSave.rejectFields(data)
      }
      if pointer.schemaVersion < 25, ["commander.json", "world.json"].contains(name) {
        try ElectricalVersionedSave.rejectFields(data)
      }
      if name == "commander.json", pointer.schemaVersion < 24 {
        try NativePeopleVersionedSave.rejectFields(data)
      }
      if name == "commander.json" {
        try ScriptFinanceVersionedSave.rejectFields(data, part: .commander)
      } else if name == "missions.json", pointer.schemaVersion < 23 {
        try ScriptFinanceVersionedSave.rejectFields(data, part: .missions)
      }
      if pointer.schemaVersion < 22 {
        if name == "commander.json" { try EMPVersionedSave.rejectFields(data, part: .commander) }
        if name == "world.json" { try EMPVersionedSave.rejectFields(data, part: .world) }
      }
      if name == "commander.json" {
        try ScriptSaveJSONPreflight.rejectCourierFields(data, location: .currentCommanderHeader)
      }
      chunks[name] = data
    }
    var commander: Commander
    if let composition = inquiryComposition {
      commander = composition.commander
    } else {
      commander = try ScriptValueStorage.decoder(typed: true).decode(
        Commander.self, from: chunks["commander.json"]!)
      guard alien == commander.usesAlienStorageSaveVersion else {
        throw SaveError.invalidCommander
      }
      if alien {
        try AlienStorageVersionedSave.hydrate(
          &commander, rootHash: pointer.hashes[AlienStorageVersionedSave.rootName]!,
          directory: directory)
      }
    }
    if inquiryComposition == nil {
      let missionsDecoder = ScriptValueStorage.decoder(typed: true)
      commander.scriptState = try missionsDecoder.decode(
        ScriptEngineState.self, from: chunks["missions.json"]!)
    }
    guard secondEnvelope == NativeSecondCommoditySaleSave.hasClaims(commander),
      newtEnvelope == CurrentNewtKitSave.hasClaims(commander),
      inquiryEnvelope == NativeC01InquirySave.hasClaims(commander),
      tradeEnvelope == NativeFirstCommodityTradeSave.hasClaims(commander),
      watcherEnvelope == NativeMemoryAtlasWatcherEnvelope.hasClaims(commander) else {
      throw SaveError.invalidCommander
    }
    guard
      pointer.schemaVersion < 23
        ? commander.scriptState.financeLedger == nil
        : pointer.schemaVersion == 23 ? commander.scriptState.financeLedger != nil : true,
      pointer.schemaVersion >= 27
        || (pointer.schemaVersion == 26) == commander.usesEconomyMiningSaveVersion,
      pointer.schemaVersion >= 26
        || (pointer.schemaVersion == 25)
          == (commander.usesRingMiningSaveVersion || commander.usesElectricalSaveVersion
            || commander.usesModularDriveSaveVersion),
      pointer.schemaVersion >= 25
        || (pointer.schemaVersion == 24) == commander.usesNativePeopleSaveVersion
    else {
      throw SaveError.invalidCommander
    }
    if inquiryComposition == nil {
      commander.contracts = try ScriptValueStorage.decoder(typed: true).decode(
        ScriptContractState.self, from: chunks["contracts.json"]!)
    }
    guard
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook
        || stationJourney || supply
        || serviceEnvelope
        || coldChain || clues
        || navigation
        || freight == commander.usesFreightNativeSaveVersion,
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook
        || stationJourney || supply
        || serviceEnvelope
        || coldChain
        || navigation
        || clues == (commander.scriptState.savedClueJournal != nil),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook
        || stationJourney || supply
        || serviceEnvelope
        || coldChain
        || navigation == ScriptNavigationTradeSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook
        || stationJourney || supply
        || serviceEnvelope
        || coldChain == WayfarerColdChainSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook
        || stationJourney || supply
        || serviceEnvelope
          == (WayfarerRepairLoopSave.hasClaims(commander)
            || WayfarerColdChainSave.seedTransferHasClaims(commander)),
      commander.usesFreightNativeSaveVersion || !commander.usesProviderContractSaveVersion,
      ScriptClueVersionedSave.validateClaims(commander, trust: clueTrust),
      ScriptNavigationTradeSave.validateClaims(commander, binding: navigationBinding),
      WayfarerColdChainSave.validateClaims(commander),
      WayfarerRepairLoopSave.validateClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook
        || stationJourney
        || supply == OriginalConsentedFreightSupplySave.hasClaims(commander),
      reservationEnvelope == NativeC01ReservationAuditSave.hasClaims(commander),
      reservationEnvelope
        || defensiveFlightEnvelope == NativeDefensiveFlightSave.hasClaims(commander),
      reservationEnvelope || defensiveFlightEnvelope
        || surveyorEnvelope == NativeC01SurveyorSave.hasClaims(commander),
      reservationEnvelope || defensiveFlightEnvelope || surveyorEnvelope
        || safeGunneryEnvelope == NativeSafeGunnerySave.hasClaims(commander),
      reservationEnvelope || defensiveFlightEnvelope || surveyorEnvelope || safeGunneryEnvelope
        || (featureEnvelopeSchema == 123 || featureEnvelopeSchema == 124
          || featureEnvelopeSchema == 125 || featureEnvelopeSchema == 126)
        || practiceEnvelope == NativePracticeSave.hasClaims(commander),
      reservationEnvelope || defensiveFlightEnvelope || surveyorEnvelope || safeGunneryEnvelope
        || practiceEnvelope
        || crewLogEnvelope == NativeInductionCrewLogSave.hasClaims(commander),
      reservationEnvelope || defensiveFlightEnvelope || surveyorEnvelope || safeGunneryEnvelope
        || practiceEnvelope
        || arkEnvelope == NativeInductionArkSave.hasClaims(commander),
      reservationEnvelope || defensiveFlightEnvelope || surveyorEnvelope || safeGunneryEnvelope
        || practiceEnvelope
        || inductionEnvelope == NativeWayfarerInductionSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope == NativeFirstCommoditySaleSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope
        || glassEnvelope == NativeGlassMeridianSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope
        || fleetEnvelope == NativeFleetDiscoverySave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope == NativeFlightReceptionSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope == WayfarerFieldReliefSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope == NativeMeasuredExtractionSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope == WayfarerRecordRecoverySave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope == NativeIdentifiedSalvageSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope
        || survey == NativeOriginalSurveySave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation == NativeOriginalEvacuationSave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation
        || originalRescue == NativeOriginalRescueJourneySave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook == NativeOrbitalOutlookJourneySave.hasClaims(commander),
      inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
        || flightReceptionEnvelope
        || fieldReliefEnvelope
        || measuredExtractionEnvelope
        || recordRecoveryEnvelope
        || identifiedSalvageEnvelope || survey
        || evacuation || originalRescue
        || outlook
        || stationJourney == NativeStationPassengerJourneySave.hasClaims(commander),
      NativeDefensiveFlightSave.validateClaims(commander),
      NativeSafeGunnerySave.validateClaims(commander),
      NativePracticeSave.validateClaims(commander),
      NativeInductionCrewLogSave.validateClaims(commander),
      NativeInductionArkSave.validateClaims(commander),
      NativeWayfarerInductionSave.validateClaims(commander),
      NativeFirstCommoditySaleSave.validateClaims(commander),
      NativeSecondCommoditySaleSave.validateClaims(commander),
      NativeFirstCommodityTradeSave.validateClaims(commander),
      NativeUnderTowSave.validateClaims(commander),
      NativeBorrowedVoiceSave.validateClaims(commander),
      NativeTitheCommissionSave.validateClaims(commander),
      NativeQuietChoirSave.validateClaims(commander),
      NativeMemoryAtlasSave.validateClaims(commander),
      NativeMemoryAtlasWatcherSourceSave.validateClaims(commander),
      NativeSignedPassageOpeningSave.validateClaims(commander),
      NativeAssemblyOfOrbitsSave.validateClaims(commander),
      NativeGlassMeridianSave.validateClaims(commander),
      NativeFleetDiscoverySave.validateClaims(commander),
      NativeFlightReceptionSave.validateClaims(commander),
      WayfarerFieldReliefSave.validateClaims(commander, requireRecordedLoss: true),
      NativeMeasuredExtractionSave.validateClaims(commander, requireRecordedLoss: true),
      WayfarerRecordRecoverySave.validateClaims(commander, requireRecordedLoss: true),
      NativeIdentifiedSalvageSave.validateClaims(commander, requireRecordedLoss: true),
      NativeOriginalSurveySave.validateClaims(commander),
      NativeOriginalEvacuationSave.validateClaims(commander),
      NativeOriginalRescueJourneySave.validateClaims(commander),
      NativeOrbitalOutlookJourneySave.validateClaims(commander),
      NativeStationPassengerJourneySave.validateClaims(commander),
      OriginalConsentedFreightSupplySave.validateClaims(commander)
    else {
      throw SaveError.invalidCommander
    }
    if inductionEnvelope || commerceEnvelope || glassEnvelope || fleetEnvelope
      || flightReceptionEnvelope
      || fieldReliefEnvelope
      || measuredExtractionEnvelope
      || recordRecoveryEnvelope
      || identifiedSalvageEnvelope || survey
      || evacuation || originalRescue
      || outlook || freight
      || clues || navigation
      || coldChain
      || serviceEnvelope
      || supply
      || stationJourney,
      !ScriptFreightVersionedSave.validateClaims(commander)
    {
      throw SaveError.invalidCommander
    }
    guard NativeIsolationWorkParentSave.validateClaims(commander),
      NativeIsolationWorkSave.validateClaims(commander),
      NativeIsolationContractSave.validateClaims(commander)
    else {
      throw SaveError.invalidCommander
    }
    let world = try ScriptValueStorage.decoder(typed: true).decode(
      ScriptWorldSave.self, from: chunks["world.json"]!)
    try BisonUnitJournalSave.validateArchive(commander: commander, world: world,
      pointer: pointer.bisonUnitJournalCheckpoint)
    guard commander.scriptState.calendarLedger != nil else { throw SaveError.invalidCommander }
    let retainedBisonJournal = commander.savedBisonUnitAllocations
    try commander.prepareEquipment()
    guard commander.savedBisonUnitAllocations == retainedBisonJournal else { throw SaveError.invalidCommander }
    let semantic = JSONEncoder()
    guard try semantic.encode(commander.scriptState).count <= 33_554_432,
      try semantic.encode(commander.contracts).count <= 33_554_432,
      commander.valid, world.valid, NativePracticeSave.sceneValid(world, commander: commander),
      NativeC01InquirySave.retainedSourceAndWorldValid(commander, world: world),
      world.consistent(with: commander)
    else {
      throw SaveError.invalidCommander
    }
    return (commander, world)
  }
}

extension Game {
  var scriptWorldSave: ScriptWorldSave {
    ScriptWorldSave(
      libraryScreen: library, simulation: scriptSimulationSave,
      referenceFrame: scriptReferenceFrame,
      contractScreen: commander.contracts.boards.isEmpty ? nil : contractBoard.save, bodies: bodies,
      market: market, docked: docked,
      mainStation: dockedAtMainStation,
      screen: screen, speed: speed, time: scriptStartupTime ?? time, energy: energy,
      frontShield: frontShield,
      rearShield: rearShield, laserHeat: laserHeat, jumpCountdown: jumpCountdown,
      selectedSystem: selectedSystem, nextBodyID: nextBodyID)
  }
  private func isUnboundRestoredCobra(_ body: SpaceBody) -> Bool {
    guard body.hull == .cobra, body.scriptNPC == nil else { return false }
    if body.physical?.ordnance?.profile == .alienSeeker { return false }
    if let payload = body.physical?.payload, case .salvage(let identity) = payload,
      salvageLotForGeometry(identity) != nil
    {
      return false
    }
    if let id = body.physical?.catalogueShipID, !OriginalDetailedHullStage.blocksRuntime(id),
      ShipCatalogue.rawMesh(id) != nil
    {
      return false
    }
    return true
  }

  mutating func restoreScriptWorld(_ world: ScriptWorldSave) {
    restoreScriptSimulation(world.simulation)
    scriptReferenceFrame = world.referenceFrame
    // Keep serialized mission and traffic records. A retired marker alone cannot re-enter flight.
    bodies = world.bodies.filter { !isUnboundRestoredCobra($0) }
    // An unchanged snapshot must not materialize a pristine market in owned state.
    if world.market != market { market = world.market }
    docked = world.docked
    dockedAtMainStation = world.mainStation
    // Pending contacts restore through Contacts, not a stale UI selection token.
    screen = world.screen.isFlight ? world.screen : .status
    speed = world.speed
    time = world.time
    energy = world.energy
    frontShield = world.frontShield
    rearShield = world.rearShield
    laserHeat = world.laserHeat
    jumpCountdown = world.jumpCountdown
    selectedSystem = world.selectedSystem
    nextBodyID = world.nextBodyID
    if let saved = world.contractScreen {
      contractBoard.restoredSelection = saved.selection
      contractBoard.previous = saved.previous
      contractBoard.action = saved.action
      contractBoard.scroll = saved.scroll
    }
    if world.screen == .library, let saved = world.libraryScreen {
      library = saved
      if [.handoff, .help, .library, .mission, .demo, .title, .gameOver].contains(library.previous)
      {
        library.previous = .status
      }
      screen = .library
    }
    if world.screen == .contracts, docked, dockedAtMainStation, let saved = world.contractScreen {
      screen = .contracts
      refreshContractRows(restoring: saved)
    }
  }
}
