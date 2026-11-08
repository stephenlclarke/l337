import Foundation

/// A captured UI selection, NOT an optical measurement, original-register permission or
/// mission authority. Only actual current Game data can produce it; it is never Codable.
struct NativeAssemblyCalibrationSelection: Equatable, Sendable {
  private let mission: UUID
  private let revision: UInt64
  private let digest: String
  private let reference: NativeAssemblyReferenceBinding
  private let targeting: OwnedEquipmentItem
  private let player: ActorIdentity
  private let actor: ActorIdentity
  private let bodyID: Int
  private let epoch: UUID

  private init(game: borrowing Game, instance: ScriptInstance,
    reference: NativeAssemblyReferenceBinding, targeting: OwnedEquipmentItem,
    player: ActorIdentity, actor: ActorIdentity, bodyID: Int)
  {
    mission = instance.id
    revision = instance.revision
    digest = instance.digest
    self.reference = reference
    self.targeting = targeting
    self.player = player
    self.actor = actor
    self.bodyID = bodyID
    epoch = game.nativeStationRuntimeEpoch
  }

  /// Cheap input consistency only. No ray, mesh/model query, clock credit or source consent.
  /// Range/aim/occlusion remain the actual actor-side private optical acquisition's job.
  static func capture(in game: borrowing Game) -> Self? {
    guard !game.isMissionTrial, game.trialTitle == nil, !game.docked, !game.paused,
      game.screen == .front, !game.playerEMPDisabled, game.energy.isFinite, game.energy > 0,
      game.jumpCountdown == nil, game.pendingNativeStationDock == nil,
      game.commander.flightSimulation.valid, game.commander.equipmentStateValid,
      let instance = game.assemblyOfOrbitsMission,
      game.assemblyOfOrbitsPack?.digest == instance.digest,
      NativeAssemblyOfOrbitsSave.validateClaims(game.commander),
      let reference = try? NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: game.commander),
      let inventory = game.commander.equipmentInventory,
      let targeting = game.commander.fittedEquipment(at: .targetingCore),
      inventory.items.filter({ $0.id == targeting.id }) == [targeting],
      targeting.location == .init(hullInstanceID: inventory.activeHull, slot: .targetingCore),
      TargetingTier.from(targeting.node.key) != nil,
      game.commander.fittedComponent(at: .targetingCore) == targeting.component,
      reference.owner == inventory.owner, reference.carrier == inventory.activeHull,
      reference.inventoryRevision == inventory.revision,
      let body = game.informationTargetBody, body.energy.isFinite, body.energy > 0,
      body.scriptShot == nil, game.bodies.filter({ $0.id == body.id }).count == 1,
      let physical = body.physical, physical.identity.entity > 0,
      let player = game.commander.flightSimulation.player, player.entity == 0,
      physical.identity.system == player.system, physical.identity.visit == player.visit,
      game.bodies.filter({ $0.physical?.identity == physical.identity }).count == 1
    else { return nil }
    return .init(game: game, instance: instance, reference: reference,
      targeting: targeting, player: player, actor: physical.identity, bodyID: body.id)
  }

  func isCurrent(in game: borrowing Game) -> Bool { Self.capture(in: game) == self }
}

extension Game {
  var canStartAssemblyCalibration: Bool { NativeAssemblyCalibrationSelection.capture(in: self) != nil }

  /// Stop remains available after loss of target/fit; it cannot award or spend anything.
  var canCancelAssemblyCalibration: Bool {
    nativeAssemblyCalibrationDisplay.map { $0.mode != .off } ?? false
  }

  var assemblyCalibrationHUDLines: [String] {
    nativeAssemblyCalibrationDisplay.map { NativeAssemblyCalibrationHUD.lines(for: $0) } ?? []
  }
}
