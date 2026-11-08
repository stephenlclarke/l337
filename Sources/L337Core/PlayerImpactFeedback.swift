import Foundation

/// A brief presentation of a committed physical hit, never a damage or saving authority.
struct PlayerImpactFeedback: Equatable, Sendable {
  static let duration = 0.35
  let runtime: UUID
  let player: ActorIdentity
  let event: UInt64
  let physicalTime: Double
  let contact: Vector3
  let front: Bool
  let shielded: Bool

  fileprivate init(
    runtime: UUID, player: ActorIdentity, event: UInt64, physicalTime: Double,
    contact: Vector3, shielded: Bool
  ) {
    self.runtime = runtime
    self.player = player
    self.event = event
    self.physicalTime = physicalTime
    self.contact = contact
    front = contact.z >= 0
    self.shielded = shielded
  }
}

extension Game {
  /// Call only after the ordinary or mission kernel commits an actual player hit.
  /// Environmental damage never enters this path, and no resource is changed here.
  mutating func recordPlayerImpactFeedback(
    contact: Vector3, event: UInt64,
    before: (front: Double, rear: Double, energy: Double)
  ) {
    let flight = commander.flightSimulation
    guard !docked, let player = flight.player, contact.finite,
      flight.physicalTime.isFinite, flight.physicalTime >= 0,
      event > 0, event < UInt64.max, event + 1 == flight.nextIncident,
      [before.front, before.rear, before.energy, frontShield, rearShield, energy]
        .allSatisfy(\.isFinite)
    else { return }
    let shieldLoss = max(0, before.front - frontShield) + max(0, before.rear - rearShield)
    let energyLoss = max(0, before.energy - energy)
    guard shieldLoss.isFinite, energyLoss.isFinite, shieldLoss > 0 || energyLoss > 0 else {
      return
    }
    if let previous = playerImpactFeedback,
      previous.runtime == nativeStationRuntimeEpoch, previous.player == player,
      previous.event >= event
    {
      return
    }
    playerImpactFeedback = .init(
      runtime: nativeStationRuntimeEpoch, player: player, event: event,
      physicalTime: flight.physicalTime, contact: contact, shielded: shieldLoss > 0)
  }

  var visiblePlayerImpactFeedback: PlayerImpactFeedback? {
    guard !docked, screen.isFlight, let feedback = playerImpactFeedback,
      feedback.runtime == nativeStationRuntimeEpoch,
      feedback.player == commander.flightSimulation.player,
      feedback.event < commander.flightSimulation.nextIncident
    else { return nil }
    let now = commander.flightSimulation.physicalTime
    let expires = feedback.physicalTime + PlayerImpactFeedback.duration
    return now.isFinite && now >= feedback.physicalTime && now < expires ? feedback : nil
  }
}

extension Display {
  /// This is a cockpit shield indicator. It does not invent a world-space beam endpoint.
  static func drawPlayerImpactFeedback(_ game: borrowing Game, into frame: inout Frame) {
    guard let feedback = game.visiblePlayerImpactFeedback else { return }
    let clip = frame.flightClip
    let margin = min(26.0, min(clip.width, clip.height) / 4)
    guard margin > 0 else { return }
    let point = Game.viewPosition(feedback.contact, screen: game.screen)
    let dx = point.x
    var dy = -point.y
    if abs(dx) + abs(dy) < 1e-9 { dy = feedback.front ? -1 : 1 }
    let horizontal = max(1, clip.width / 2 - margin)
    let vertical = max(1, clip.height / 2 - margin)
    let factor = min(horizontal / max(abs(dx), 1e-9), vertical / max(abs(dy), 1e-9))
    let x = clip.x + clip.width / 2 + dx * factor
    let y = clip.y + clip.height / 2 + dy * factor
    let age = game.commander.flightSimulation.physicalTime - feedback.physicalTime
    let strength = max(0, 1 - age / PlayerImpactFeedback.duration)
    for (radius, opacity) in [(22.0, 0.18), (13.0, 0.4), (5.0, 0.9)] {
      frame.point(x, y, radius: min(radius, margin), opacity: opacity * strength, ink: .orange)
    }
    let title =
      feedback.shielded
      ? (feedback.front ? "FORE SHIELD HIT" : "AFT SHIELD HIT") : "HULL HIT"
    let font = GameTypography.scale
    frame.label(
      title, clip.x + (clip.width - Double(title.count) * 6 * font) / 2,
      clip.y + 12, scale: font, ink: .orange)
  }

}
