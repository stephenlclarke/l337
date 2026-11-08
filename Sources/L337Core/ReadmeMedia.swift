import Foundation

/// Export fixtures only. These scenes never enter a player's commander or save session.
public enum ReadmeMedia {
  /// Bounded export-fixture diagnostics; these phases confer no gameplay authority.
  private enum CapturePhase: String, Error, Sendable, CustomStringConvertible {
    case packBinding
    case originalHull
    case launchedCohort
    case introductionTraffic
    case retainedActor
    case forwardWeapon
    case attackerCount
    case playerImpactScreenNotFlight
    case playerImpactDocked
    case playerImpactCapturePaused
    case noStoredPlayerImpactFeedbackWithoutRecordedShots
    case noStoredPlayerImpactFeedbackWithoutRecordedShotsWithRetainedForwardAim
    case noStoredPlayerImpactFeedbackWithoutRecordedShotsPendingNativeDock
    case noStoredPlayerImpactFeedbackWithRecordedShots
    case noStoredPlayerImpactFeedbackCombatSuspendedWithoutRecordedShots
    case noStoredPlayerImpactFeedbackCombatSuspendedWithRecordedShots
    case noStoredPlayerImpactFeedbackOtherSuspendedWithoutRecordedShots
    case noStoredPlayerImpactFeedbackOtherSuspendedWithRecordedShots
    case storedPlayerImpactFeedbackNotVisible
    case nonpositivePlayerEnergy
    case currentGun
    case playerContactOrRange
    case attainment
    case admissionUnavailableArrival
    case admissionOutsideLocalBubble
    case admissionNativeUnits
    case admissionAllocatorCapacity
    case admissionNativeStaleContext
    case admissionNativePopulationLimit
    case admissionNativeReservedCapacity
    case admissionNativeMissionSuppression
    case admissionNativeUnsafePosition
    case admissionNativeUnqualifiedOriginalHull
    case admissionPendingUnknown

    var description: String { "Original docking capture refused at " + rawValue + "." }

    static func pendingReason(_ reason: String?) -> CapturePhase {
      guard let reason else { return .admissionPendingUnknown }
      switch reason {
      case "unavailableArrival": return .admissionUnavailableArrival
      case "outsideLocalBubble": return .admissionOutsideLocalBubble
      case "nativeUnits": return .admissionNativeUnits
      case "allocatorCapacity": return .admissionAllocatorCapacity
      case "native.staleContext": return .admissionNativeStaleContext
      case "native.populationLimit": return .admissionNativePopulationLimit
      case "native.reservedCapacity": return .admissionNativeReservedCapacity
      case "native.missionSuppression": return .admissionNativeMissionSuppression
      case "native.unsafePosition": return .admissionNativeUnsafePosition
      case "native.unqualifiedOriginalHull": return .admissionNativeUnqualifiedOriginalHull
      default: return .admissionPendingUnknown
      }
    }
  }

  public static let introductionFrameCount = 48
  public static let introductionFrameDelay = 0.16
  public static let galleryFrameDelay = 0.10
  /// Include both endpoints: 36 equal angular steps are exactly one and a half turns.
  public static let galleryAngles = (0...36).map { Double($0) * .pi / 12 }
  public static var galleryShipIDs: [String] { ShipCatalogue.all.map(\.id) }
  public static var frameCount: Int {
    introductionFrameCount + galleryShipIDs.count * galleryAngles.count
  }
  public static var duration: Double {
    Double(introductionFrameCount) * introductionFrameDelay
      + Double(galleryShipIDs.count * galleryAngles.count) * galleryFrameDelay
  }

  package static func introductionCommander() async throws -> Game {
    let runtime = GameRuntime()
    try await runtime.startNewCommander()
    return await runtime.snapshot()
  }

  package static func launchIntroductionFlight(_ game: inout Game) throws {
    game.key("0")
    guard !game.docked, game.screen.isFlight,
      let index = game.bodies.firstIndex(where: {
        $0.id == 1 && $0.physical?.catalogueShipID == NativeFleetLaunchSource.traderShipID
          && $0.physical?.npc?.role == .trader && $0.physical?.npc?.routeProvenance == .generated
      })
    else { throw CapturePhase.introductionTraffic }
    game.bodies[index].position = .init(-35, 10, 320)
  }

  public enum CaptureComposition: String, CaseIterable, Sendable {
    case balanced, closeEscort, wideApproach

    var stationDistance: Double {
      switch self {
      case .balanced: 2400
      case .closeEscort: 2000
      case .wideApproach: 2800
      }
    }

    var muzzleClearanceRatio: Double {
      switch self {
      case .balanced: 8
      case .closeEscort: 7.5
      case .wideApproach: 9.5
      }
    }

    // Directions frame the four real metre hulls. Range is based on the admitted muzzle,
    // without scaling a ship or forcing its tracked gun into an invented firing state.
    var positions: [Vector3] {
      switch self {
      case .balanced:
        [
          .init(-48, 22, 145), .init(50, 27, 170),
          .init(-55, -30, 190), .init(65, -29, 225),
        ]
      case .closeEscort:
        [
          .init(-40, 17, 120), .init(44, 25, 150),
          .init(-53, -32, 180), .init(56, -20, 200),
        ]
      case .wideApproach:
        [
          .init(-55, 25, 170), .init(58, 26, 190),
          .init(-63, -30, 210), .init(75, -34, 250),
        ]
      }
    }
  }

  public static let captureShipIDs = ["SH002", "SH027", "SH031", "SH103"]

  /// A disposable encounter uses the same geometry, aiming, collision, damage and feedback
  /// paths as gameplay. No beam graphics, gun states or player-hit indicators are authored here.
  public static func dockingUnderAttackScene(
    sourceDirectory: URL, composition: CaptureComposition = .balanced
  ) async throws -> Game {
    let pack = try ScriptPackLibrary.read(sourceDirectory)
    guard pack.manifest.id == "media.original-docking-capture",
      pack.manifest.npcs?.map(\.model) == captureShipIDs.map({ "catalogue:" + $0 })
    else { throw CapturePhase.packBinding }
    var fittedHashes: [String] = []
    for (index, id) in captureShipIDs.enumerated() {
      let reference = "catalogue:" + id
      guard let ship = ShipCatalogue.ship(id), let performance = ship.game,
        let npc = pack.manifest.npcs?[index],
        npc.energy == performance.energy, npc.recharge == performance.recharge,
        npc.speed == performance.speed, npc.acceleration == performance.acceleration,
        npc.pitch == performance.pitch, npc.yaw == performance.yaw, npc.roll == performance.roll,
        npc.fuel == Double(performance.fuel) / 10,
        let original = ship.originalDefinition, ship.name == original.name,
        original.approvedMeshAvailable, let native = ship.nativeDesign, native.license == "MIT",
        let fitted = pack.models[reference], fitted.license == native.license,
        fitted == (try? ScriptPackLibrary.currentCatalogueNPCDesign(id))
      else { throw CapturePhase.originalHull }
      fittedHashes.append(ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(fitted)))
    }
    // Use the same current born-berthed authority as a fresh player, without any save writer.
    let runtime = GameRuntime()
    try await runtime.startNewCommander()
    var game = await runtime.snapshot()
    game.screen = .status
    game.commander.retaliationEnabled = false
    game.commander.autoECM = false
    game.scriptPacks = [pack]
    let instance = try game.acceptScriptMission(pack)
    game.launch()
    game.emitScriptEvent("station.undocked")
    let pendingPhase: CapturePhase = game.withReadOnlyScriptState { [instance] state in
      for index in state.pendingEvents.indices {
        guard state.pendingEvents[index].kind == "encounter.pending",
          state.pendingEvents[index].instance == instance,
          state.pendingEvents[index].values["encounter_id"]?.string == "opponents"
        else { continue }
        return CapturePhase.pendingReason(state.pendingEvents[index].values["reason"]?.string)
      }
      return .admissionPendingUnknown
    }
    game.drainScriptEvents()
    guard !game.docked,
      let station = game.bodies.first(where: { $0.id == 0 && $0.hull == .station }),
      let encounter = game.commander.scriptState.instances[instance]?.ownedEncounters["opponents"],
      encounter.actors.count == captureShipIDs.count
    else { throw CapturePhase.launchedCohort }
    guard encounter.admitted else { throw pendingPhase }

    // Preserve each world pose while moving the capture camera onto the real entrance axis.
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(
      station.entrancePosition + station.entranceNormal * composition.stationDistance)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    for index in game.bodies.indices {
      let body = game.bodies[index]
      game.bodies[index].position = pose.shipPoint(previous.systemPoint(body.position))
      game.bodies[index].orientation = body.orientation.transformed(by: previous.orientation)
        .relative(to: pose.orientation)
    }
    for index in game.celestials.indices {
      game.celestials[index].position = pose.shipPoint(
        previous.systemPoint(game.celestials[index].position))
    }
    game.commander.flightSimulation.pose = pose
    // Stage a stationary capture camera. The launch cruise speed would carry it through
    // the close formation before the guns can track the player's hull surface.
    game.speed = 0

    let aliases = ["lead", "wing", "port", "upper"]
    let rolls = [-0.28, 0.22, 0.35, -0.18]
    for (offset, alias) in aliases.enumerated() {
      guard let actor = encounter.actors[alias],
        let index = game.bodies.firstIndex(where: { $0.missionActorID == actor.identity })
      else { throw CapturePhase.retainedActor }
      guard let npc = game.bodies[index].scriptNPC,
        npc.fit.definition.model == "catalogue:" + captureShipIDs[offset],
        npc.fit.models[npc.fit.definition.model] == fittedHashes[offset]
      else { throw CapturePhase.originalHull }
      guard let weapon = npc.fit.definition.lasers?.first(where: { $0.id == "forward" }),
        weapon.muzzle.length > 0, npc.fit.definition.scale == 1
      else { throw CapturePhase.forwardWeapon }
      let position =
        composition.positions[offset].unit
        * (weapon.muzzle.length * composition.muzzleClearanceRatio)
      var facing = Basis3()
      facing.z = position.unit * -1
      facing.x = Vector3(0, 1, 0).cross(facing.z).unit
      facing.y = facing.z.cross(facing.x)
      var oblique = Basis3()
      oblique.rotate(
        pitch: offset.isMultiple(of: 2) ? 0.08 : -0.08, roll: 0,
        yaw: offset.isMultiple(of: 2) ? 0.20 : -0.20)
      oblique.rotate(pitch: 0, roll: rolls[offset], yaw: 0)
      game.bodies[index].position = position
      let orientation = oblique.transformed(by: facing)
      game.bodies[index].orientation = orientation
      game.bodies[index].scriptNPC?.intent = .init(
        request: "capture-flyby", mode: .attack, target: nil, player: true,
        offset: position + orientation.z * 300, speed: 0, tolerance: 1)
      game.bodies[index].rotation = 0
      game.bodies[index].rotationRate = 0
    }
    game.persistScriptActors()
    game.screen = .front
    game.commander.shipDisplayStyle = .shadedPanels

    // Let real frame time and bounded gun tracking produce the first simultaneous player hits.
    // Refusing or missing guns never receive invented cooldown, aim, range or damage.
    var lastFailure: CapturePhase?
    for _ in 0..<12 {
      game.tick(delta: 0.1)
      lastFailure = try captureHasFourCurrentPlayerHits(game, instance: instance)
      if case .none = lastFailure {
        game.prepareFlightWeaponDisplay()
        return game
      }
    }
    throw lastFailure ?? CapturePhase.attainment
  }

  private static func captureHasFourCurrentPlayerHits(_ game: borrowing Game, instance: UUID) throws
    -> CapturePhase?
  {
    let attackers = game.bodies.filter { $0.missionInstanceID == instance && $0.scriptNPC != nil }
    guard attackers.count == captureShipIDs.count else { throw CapturePhase.attackerCount }
    guard game.visiblePlayerImpactFeedback != nil else {
      if !game.screen.isFlight { return .playerImpactScreenNotFlight }
      if game.docked { return .playerImpactDocked }
      if game.paused { return .playerImpactCapturePaused }
      if game.playerImpactFeedback == nil {
        let hasRecordedShots = attackers.contains { ($0.scriptNPC?.shots ?? 0) > 0 }
        let failure: CapturePhase = game.withReadOnlyScriptState { [instance, hasRecordedShots] state in
          guard let suspension = state.instances[instance]?.suspension else {
            return hasRecordedShots
              ? .noStoredPlayerImpactFeedbackWithRecordedShots
              : .noStoredPlayerImpactFeedbackWithoutRecordedShots
          }
          if suspension.hasPrefix("Native mission combat refused: ") {
            return hasRecordedShots
              ? .noStoredPlayerImpactFeedbackCombatSuspendedWithRecordedShots
              : .noStoredPlayerImpactFeedbackCombatSuspendedWithoutRecordedShots
          }
          return hasRecordedShots
            ? .noStoredPlayerImpactFeedbackOtherSuspendedWithRecordedShots
            : .noStoredPlayerImpactFeedbackOtherSuspendedWithoutRecordedShots
        }
        if case .noStoredPlayerImpactFeedbackWithoutRecordedShots = failure,
          game.pendingNativeStationDock != nil
        {
          return .noStoredPlayerImpactFeedbackWithoutRecordedShotsPendingNativeDock
        }
        if case .noStoredPlayerImpactFeedbackWithoutRecordedShots = failure,
          attackers.contains(where: { $0.scriptNPC?.guns["forward"]?.aim != nil })
        {
          return .noStoredPlayerImpactFeedbackWithoutRecordedShotsWithRetainedForwardAim
        }
        return failure
      }
      return .storedPlayerImpactFeedbackNotVisible
    }
    guard game.energy > 0 else { return .nonpositivePlayerEnergy }
    for body in attackers {
      guard let npc = body.scriptNPC,
        let weapon = npc.fit.definition.lasers?.first(where: { $0.id == "forward" }),
        let gun = npc.guns[weapon.id], let range = gun.beamRange,
        gun.cooldown > weapon.interval - 0.05, npc.shots > 0
      else { return .currentGun }
      let muzzle = body.position + body.orientation.apply(weapon.muzzle * npc.fit.definition.scale)
      let direction = body.orientation.apply(gun.aim ?? weapon.direction).unit
      let contact = try game.nearestMissionCollision(
        from: muzzle, direction: direction, range: weapon.range, radius: 0,
        excludingBodyIDs: [body.id], includePlayer: true)
      guard contact?.hit.target == .player,
        abs((contact?.hit.distance ?? -1) - range) <= 1e-6
      else { return .playerContactOrRange }
    }
    return nil
  }

}
