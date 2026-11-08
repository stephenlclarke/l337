import Foundation
import Testing

@testable import L337Core

/// Use the actual original Kite source and its native hull binding. The existing
/// physical adoption owner allocates the identity and engagement intention later.
/// No retired Cobra/Constrictor discriminator or catalogue alias supplies a mesh.
func selectedLegacyBeamEmitter(id: Int, position: Vector3) throws -> SpaceBody {
  let sourceCandidate = OriginalFleetRuntimeHullSource.source(for: "SH031")
  let source = try #require(sourceCandidate)
  try OriginalDetailedHullStage.requireRuntime(source.ship.id)
  let hull = try #require(source.ship.nativeHull)
  try #require(ShipCatalogue.nativeShip(hull)?.id == source.ship.id)
  let nativeMesh = try #require(ShipCatalogue.nativeMesh(hull))
  try #require(!nativeMesh.vertices.isEmpty && !nativeMesh.faces.isEmpty)
  try #require(nativeMesh.vertices == source.mesh.vertices && nativeMesh.faces == source.mesh.faces)
  return .init(id: id, hull: hull, position: position, hostile: true)
}

struct SelectedLegacyNPCBeamTests {
  private func game(work: Bool, blocker: Bool = false) throws -> Game {
    var game = Game(executive: false)
    // Retain the current starting hull, fit, resources and actual player mesh.
    try OriginalDetailedHullStage.requireRuntime(game.commander.shipID)
    game.docked = false
    game.screen = .front
    game.commander.flightSimulation.enter(game.systemIdentity, arriving: true)
    game.commander.flightSimulation.pose.position = .init(0, 0, -3000)
    game.bodies = [try selectedLegacyBeamEmitter(id: 10, position: .init(0, 0, 1400))]
    if blocker { game.bodies.append(.init(id: 11, hull: .asteroid, position: .init(0, 0, 500))) }
    game.celestials = []
    game.speed = 0
    if work { game.workBraking = .init(velocity: .init(0, 0, 5000), angularVelocity: .init(0, 0, 0)) }
    else { game.speed = 10; game.yaw = 0.3 }
    game.ensurePhysicalActors()
    game.gameplayCombatTrace = .init()
    return game
  }

  private func prepared(_ game: inout Game) throws
    -> (MissionCollisionQueryGeometry, SelectedNPCBeamPlan, CurrentNewtNativeClockEvidence)
  {
    let opening = game.commander.flightSimulation
    let bodies = game.bodies
    let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate)
    var frameRefusal: CurrentNewtPreparationRefusal? = nil
    let frameCandidate = game.prepareCurrentNewtNPCFrame(path, report: {
      if frameRefusal == nil { frameRefusal = $0 }
    })
    let frameReason = frameRefusal?.summary ?? "NPC frame refusal checkpoint missing (instrumentation incomplete)"
    let frame = try #require(frameCandidate, Comment(rawValue: frameReason))
    let ownedBeamRequired1 = game.bodies.first { $0.id == 10 }?.physical?.identity
    let owner = try #require(ownedBeamRequired1)
    let entry = try #require(frame.entries[owner])
    let geometry = try game.prepareSelectedNPCBeamGeometry(for: path)
    let ownedBeamRequired2 = game.prepareSelectedLegacyNPCBeam(entry: entry, geometry: geometry)
    let plan = try #require(ownedBeamRequired2)
    let ownedBeamExpected3 = game.commander.flightSimulation == opening && game.bodies == bodies
    #expect(ownedBeamExpected3)
    let result = game.advanceCurrentNewtNativeInterval(path, npcFrame: frame)
    let evidence = try #require(result.evidence)
    try #require(evidence.completedOuterInterval)
    let ownedBeamExpected4 = game.commander.flightSimulation.physicalTime == opening.physicalTime + 0.05
    #expect(ownedBeamExpected4)
    return (geometry, plan, evidence)
  }

  @Test
  func movingWorkCameraPreservesOriginalShieldBankWorldHitAndActualClock() throws {
    var game = try game(work: true)
    let (geometry, plan, evidence) = try prepared(&game)
    let ownedBeamRequired5 = game.querySelectedLegacyNPCBeam(plan, evidence: evidence)
    let query = try #require(ownedBeamRequired5)
    let contact = try #require(query.contact)
    try #require(contact.hit.target == .player)
    try #require(contact.hit.point.z >= 0)
    let world = geometry.selectedFrame.systemPoint(contact.hit.point)
    // Mapping the selected hit into the closing camera would pick the wrong bank.
    let ownedBeamRequired6 = game.commander.flightSimulation.pose.shipPoint(world).z < 0
    try #require(ownedBeamRequired6)
    let front = game.frontShield, rear = game.rearShield
    let time = game.commander.flightSimulation.physicalTime
    let originCandidate = game.makeAttackOrigin(owner: query.owner)
    let origin = try #require(originCandidate)
    let beforeHit = game.commander.flightSimulation
    let effectCandidate = game.applySelectedNativeNPCBeamHit(contact, origin: origin,
      damage: 5, emissionPosition: query.launch, evidence: evidence)
    let effect = try #require(effectCandidate)
    let ownedBeamExpected7 = effect.applying(to: beforeHit) == game.commander.flightSimulation
    #expect(ownedBeamExpected7)
    let ownedBeamExpected8 = game.frontShield < front && game.rearShield == rear
    #expect(ownedBeamExpected8)
    #expect(effect.incident.position == world)
    #expect(effect.incident.physicalTime == time && effect.incident.origin.emittedAt == time)
    #expect(effect.incident.origin.owner == query.owner)
    #expect(contact.selectedEmitter == query.owner && contact.selectedLaunch == query.launch)
  }

  @Test
  func aDestroyedOccluderDoesNotRemainInTheNextSelectedNativeQuery() throws {
    var game = try game(work: false, blocker: true)
    let (_, plan, evidence) = try prepared(&game)
    let ownedBeamRequired9 = game.querySelectedLegacyNPCBeam(plan, evidence: evidence)
    let first = try #require(ownedBeamRequired9)
    let contact = try #require(first.contact)
    try #require(contact.hit.target == .body(11))
    let ownedBeamRequired10 = game.bodies.first { $0.id == 11 }?.energy
    let health = try #require(ownedBeamRequired10)
    let originCandidate2 = game.makeAttackOrigin(owner: first.owner)
    let origin = try #require(originCandidate2)
    let beamEffectCandidate = game.applySelectedNativeNPCBeamHit(contact, origin: origin,
      damage: health + 1, emissionPosition: first.launch, evidence: evidence)
    _ = try #require(beamEffectCandidate)
    let ownedBeamRequired11 = game.bodies.first { $0.id == 11 }?.energy == 0
    try #require(ownedBeamRequired11)
    let counters = game.commander.flightSimulation
    let ownedBeamRequired12 = game.querySelectedLegacyNPCBeam(plan, evidence: evidence)
    let second = try #require(ownedBeamRequired12)
    #expect(second.contact?.hit.target == .player)
    let ownedBeamExpected13 = game.commander.flightSimulation == counters
    #expect(ownedBeamExpected13) // Re-query grants no second shot.
  }

  @Test
  func changedEndpointEpochOrTimeCannotAuthorizeSelectedGeometry() throws {
    var game = try game(work: false)
    let (_, plan, evidence) = try prepared(&game)
    var moved = game
    moved.bodies[0].position.x += 1
    let ownedBeamExpected14 = moved.querySelectedLegacyNPCBeam(plan, evidence: evidence) == nil
    #expect(ownedBeamExpected14)
    var later = game
    later.commander.flightSimulation.advancePhysicalTime(0.01)
    let ownedBeamExpected15 = later.querySelectedLegacyNPCBeam(plan, evidence: evidence) == nil
    #expect(ownedBeamExpected15)
    var epoch = game
    epoch.nativeStationRuntimeEpoch = UUID()
    let ownedBeamExpected16 = epoch.querySelectedLegacyNPCBeam(plan, evidence: evidence) == nil
    #expect(ownedBeamExpected16)
  }

  @Test
  func anArbitraryPlainGeometryRayCarriesNoSelectedEmitterAuthority() throws {
    var game = try game(work: false)
    let (geometry, plan, evidence) = try prepared(&game)
    let source = try #require(geometry.selectedBody(id: plan.bodyID))
    let direction = geometry.playerSurfaceAim(from: source.position) - source.position
    let contactCandidate = try geometry.nearestCollision(from: source.position,
      direction: direction.unit, range: direction.length + 1, radius: 0,
      excludingBodyIDs: [source.id], includePlayer: true)
    let contact = try #require(contactCandidate)
    #expect(contact.selectedGeometry == nil && contact.selectedEmitter == nil && contact.selectedLaunch == nil)
    let originCandidate3 = game.makeAttackOrigin(owner: plan.owner)
    let origin = try #require(originCandidate3)
    let before = game.commander.flightSimulation
    let ownedBeamExpected17 = game.applySelectedNativeNPCBeamHit(contact, origin: origin, damage: 5,
      emissionPosition: plan.launch, evidence: evidence) == nil
    #expect(ownedBeamExpected17)
    let ownedBeamExpected18 = game.commander.flightSimulation == before
    #expect(ownedBeamExpected18)
  }

  @Test
  func unchangedSynchronousNativeQueryKeepsOriginalContactAndPermutationRanking() throws {
    var game = try game(work: false, blocker: true)
    let sourceCandidate = game.bodies.first { $0.id == 10 }
    let source = try #require(sourceCandidate)
    let direction = Game.nativePlayerSurfaceAim(from: source.position, mesh: game.commander.playerMesh) - source.position
    let first = try game.nearestMissionCollision(from: source.position, direction: direction.unit,
      range: direction.length + 1, radius: 0, excludingBodyIDs: [10], includePlayer: true)
    game.bodies.reverse()
    let second = try game.nearestMissionCollision(from: source.position, direction: direction.unit,
      range: direction.length + 1, radius: 0, excludingBodyIDs: [10], includePlayer: true)
    #expect(first == second)
    #expect(first?.hit.target == .body(11) && first?.selectedGeometry == nil)
  }
}

extension SelectedLegacyNPCBeamTests {
  @Test
  func precedingMovingBlockerUsesTheOriginalOrderedPursuitGeometry() throws {
    var game = try self.game(work: true)
    game.workBraking = .init(velocity: .init(0, 0, 25), angularVelocity: .init(0, 0, 0))
    game.bodies.insert(try selectedLegacyBeamEmitter(id: 11, position: .init(35, 0, 500)), at: 0)
    game.ensurePhysicalActors()
    let ownedBeamRequired19 = game.bodies.first { $0.id == 10 }?.physical?.identity
    let source = try #require(ownedBeamRequired19)
    var original = game
    // Run the two original forward controller steps; never advance/copy a future clock.
    let matchingIndex = original.bodies.firstIndex { $0.id == 11 }
    original.enemyAction(index: try #require(matchingIndex), dt: 0.05)
    let matchingIndex2 = original.bodies.firstIndex { $0.id == 10 }
    original.enemyAction(index: try #require(matchingIndex2), dt: 0.05)
    let referenceCandidate = original.gameplayCombatTrace?.incidents.last { $0.origin.owner == source }
    let reference = try #require(referenceCandidate)
    let (geometry, plan, evidence) = try prepared(&game)
    let ownedBeamRequired20 = game.querySelectedLegacyNPCBeam(plan, evidence: evidence)
    let query = try #require(ownedBeamRequired20)
    let contact = try #require(query.contact)
    let victim = game.bodies.first { $0.physical?.identity == reference.victim }
    #expect(contact.hit.target == (victim.map { GameplayHitTarget.body($0.id) } ?? .player))
    let world = geometry.selectedFrame.systemPoint(contact.hit.point)
    #expect((world - reference.position).length <= 1024 * Double.ulpOfOne * max(1, world.length))
  }

  @Test
  func selectedMissionContactRejoinsActualFitComponentHealthAndRealIncident() throws {
    var (game, _, index) = try actualMissionBridgeGame()
    var target = game.bodies[index]
    target.position = .init(0, 0, 500)
    target.orientation = .init()
    target.rotation = 0
    target.rotationRate = 0
    game.bodies = [target, try selectedLegacyBeamEmitter(id: 91_001, position: .init(0, 0, 1200))]
    game.celestials = []
    game.speed = 0
    game.ensurePhysicalActors()
    let ownedBeamRequired21 = game.bodies.first { $0.id == 91_001 }?.physical?.identity
    let owner = try #require(ownedBeamRequired21)
    let pathCandidate2 = game.prepareCurrentNewtOuterMotion(delta: 0.05)
    let path = try #require(pathCandidate2)
    var frameRefusal: CurrentNewtPreparationRefusal? = nil
    let frameCandidate = game.prepareCurrentNewtNPCFrame(path, report: {
      if frameRefusal == nil { frameRefusal = $0 }
    })
    let frameReason = frameRefusal?.summary ?? "NPC frame refusal checkpoint missing (instrumentation incomplete)"
    let frame = try #require(frameCandidate, Comment(rawValue: frameReason))
    let geometry = try game.prepareSelectedNPCBeamGeometry(for: path)
    let planCandidate = game.prepareSelectedLegacyNPCBeam(
      entry: try #require(frame.entries[owner]), geometry: geometry)
    let plan = try #require(planCandidate)
    let ownedBeamRequired22 = game.advanceCurrentNewtNativeInterval(path, npcFrame: frame).evidence
    let evidence = try #require(ownedBeamRequired22)
    let ownedBeamRequired23 = game.querySelectedLegacyNPCBeam(plan, evidence: evidence)
    let query = try #require(ownedBeamRequired23)
    let contact = try #require(query.contact)
    try #require(contact.selectedTargetBody?.scriptNPC != nil)
    let before = game.commander.flightSimulation
    _ = try game.preflightSelectedNativeMissionContact(contact, owner: owner, damage: 1, evidence: evidence)
    let ownedBeamExpected24 = game.commander.flightSimulation == before
    #expect(ownedBeamExpected24)
    let originCandidate4 = game.makeAttackOrigin(owner: owner)
    let origin = try #require(originCandidate4)
    let afterEmission = game.commander.flightSimulation
    let result = try game.applySelectedNativeMissionContact(contact, origin: origin, damage: 1,
      emissionPosition: query.launch, evidence: evidence)
    let ownedBeamExpected25 = result.clockEffect.applying(to: afterEmission) == game.commander.flightSimulation
    #expect(ownedBeamExpected25)
    #expect(result.receipt.damageAdmitted && result.receipt.target == contact.hit.target)
    #expect(result.receipt.victimComponentID == contact.componentUUID)
    #expect(result.clockEffect.incident.position == geometry.selectedFrame.systemPoint(contact.hit.point))
  }
}
