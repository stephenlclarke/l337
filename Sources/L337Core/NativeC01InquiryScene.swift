import Foundation

/// Retained latest-state consistency only. This grants no source approval or native capability.
enum NativeC01InquiryScene {
  @inline(never)
  static func currentLifeMatches(
    _ root: borrowing NativeC01InquiryState?, world: borrowing ScriptWorldSave,
    commander: borrowing Commander
  ) -> Bool {
    let owned = copy root
    if case .none = owned { return !world.bodies.contains(where: tagged) }
    return presentRootMatches(owned!, world: world, commander: commander)
  }

  @inline(never)
  private static func presentRootMatches(
    _ root: borrowing NativeC01InquiryState, world: borrowing ScriptWorldSave,
    commander: borrowing Commander
  ) -> Bool {
    guard root.shapeValid, root.owner == commander.equipmentOwnerID else { return false }
    let currentSystem = SystemIdentity(galaxy: commander.galaxy, system: commander.system)
    let visit = commander.flightSimulation.visit
    var parts: [NativeC01InquiryPartLife] = []
    var actors: [ActorIdentity: Int] = [:]
    var spawns: [SpawnIdentity: Int] = [:]
    var bodyIDs: [Int: Int] = [:]
    for life in root.fixtureLifecycle {
      for part in [life.support, life.head0, life.head1, life.head2] {
        let index = parts.count
        let binding = part.binding
        guard actors.updateValue(index, forKey: binding.actor) == nil,
          spawns.updateValue(index, forKey: binding.spawn) == nil,
          part.physicalTime <= commander.flightSimulation.physicalTime
        else { return false }
        if binding.actor.system == currentSystem && binding.actor.visit == visit {
          guard bodyIDs.updateValue(index, forKey: binding.bodyID) == nil else { return false }
        }
        parts.append(part)
      }
    }
    var counts = Array(repeating: 0, count: parts.count)
    for body in world.bodies {
      var candidates = Set<Int>()
      if let actor = body.physical?.identity, let index = actors[actor] { candidates.insert(index) }
      if let spawn = body.physical?.spawnIdentity, let index = spawns[spawn] {
        candidates.insert(index)
      }
      if let index = bodyIDs[body.id] { candidates.insert(index) }
      if candidates.isEmpty && !tagged(body) { continue }
      guard candidates.count == 1, let index = candidates.first, tagged(body),
        matches(body, part: parts[index], commander: commander)
      else { return false }
      counts[index] += 1
      guard counts[index] == 1 else { return false }
    }
    for (index, part) in parts.enumerated() {
      switch part.presence {
      case .present: guard counts[index] == 1 else { return false }
      case .destroyed: guard counts[index] <= 1 else { return false }
      case .parked, .removed: guard counts[index] == 0 else { return false }
      }
    }
    return true
  }

  private static func tagged(_ body: SpaceBody) -> Bool {
    body.physical?.spawnIdentity?.producer.rawValue == "c01Inquiry"
  }

  @inline(never)
  private static func matches(
    _ body: SpaceBody, part: borrowing NativeC01InquiryPartLife,
    commander: borrowing Commander
  ) -> Bool {
    guard let physical = body.physical, let spawn = physical.spawnIdentity,
      body.id == part.binding.bodyID, physical.identity == part.binding.actor,
      spawn == part.binding.spawn,
      physical.identity.system == SystemIdentity(galaxy: commander.galaxy, system: commander.system),
      physical.identity.visit == commander.flightSimulation.visit,
      body.scriptNPC == nil, body.scriptShot == nil,
      body.missionActorID == nil, body.missionInstanceID == nil,
      physical.npc == nil, physical.ordnance == nil, physical.payload == nil,
      physical.rock == nil, physical.empSource == nil, physical.empCrewPod == nil,
      physical.catalogueShipID == nil,
      body.energy == part.energy, physical.velocity == part.velocity,
      physical.angularVelocity == part.angularVelocity,
      part.physicalTime == commander.flightSimulation.physicalTime
    else { return false }
    let camera = commander.flightSimulation.pose
    let pose = ShipPose(position: camera.systemPoint(body.position),
      orientation: body.orientation.transformed(by: camera.orientation))
    guard pose == part.pose else { return false }
    switch part.presence {
    case .present:
      return body.energy > 0 && physical.deathIncidentID == nil && physical.deathOrigin == nil
    case .destroyed(let incident):
      return body.energy == 0 && incident.victim == physical.identity
        && NativeC01InquiryLifecycleFacts.terminalStampMatches(
          incident, incidentID: physical.deathIncidentID, origin: physical.deathOrigin)
    case .parked, .removed: return false
    }
  }
}
