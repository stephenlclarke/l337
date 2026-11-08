import Testing

@testable import L337Core

struct NativeC01InquiryCurrentContextPlacementRefusalTests {
  @Test(arguments: ["duplicate-body-id", "duplicate-actor", "missing-physical"])
  func currentProjectedContextDoesNotAuthorizeMalformedIdentityState(form: String) throws {
    var game = try ordinaryScene()
    let first = try #require(game.bodies.firstIndex { $0.id == 9001 })
    let second = try #require(game.bodies.firstIndex { $0.id == 9002 })
    let originalPhysical = try #require(game.bodies[first].physical)
    switch form {
    case "duplicate-body-id": game.bodies[second].id = game.bodies[first].id
    case "duplicate-actor": game.bodies[second].physical = originalPhysical
    default: game.bodies[second].physical = nil
    }
    // Capture AFTER mutation: this is the actual current projection, not the
    // old valid context used by the existing duplicate-body staleness test.
    let context = try #require(game.gameplayContext())
    try #require(game.gameplayContext() == context)
    let bodyIDs = Set(game.bodies.map(\.id))
    let physicalIDs = game.bodies.compactMap { $0.physical?.identity }
    try #require(game.bodies.allSatisfy { $0.energy.isFinite })
    try #require(Set(context.actors.map(\.identity)) == Set(physicalIDs))
    switch form {
    case "duplicate-body-id":
      try #require(bodyIDs.count == game.bodies.count - 1)
      try #require(physicalIDs.count == game.bodies.count)
      try #require(Set(physicalIDs).count == game.bodies.count)
    case "duplicate-actor":
      try #require(bodyIDs.count == game.bodies.count)
      try #require(physicalIDs.count == game.bodies.count)
      try #require(Set(physicalIDs).count == game.bodies.count - 1)
    default:
      try #require(bodyIDs.count == game.bodies.count)
      try #require(physicalIDs.count == game.bodies.count - 1)
      try #require(Set(physicalIDs).count == physicalIDs.count)
      try #require(context.actors.count == physicalIDs.count)
    }
    try expectCurrentMalformedRefusal(game, context: context)
  }

  @Test(arguments: ["positive-infinity", "negative-infinity"])
  func currentProjectedInfiniteEnergyRefusesWithCompleteUniqueIdentities(form: String) throws {
    var game = try ordinaryScene()
    let index = try #require(game.bodies.firstIndex { $0.id == 9002 })
    let identity = try #require(game.bodies[index].physical?.identity)
    let invalidEnergy = form == "positive-infinity" ? Double.infinity : -Double.infinity
    game.bodies[index].energy = invalidEnergy
    let context = try #require(game.gameplayContext())
    // Infinity compares equal to itself. NaN would fail this prerequisite and
    // exercise context inequality instead of the finite-energy guard.
    try #require(game.gameplayContext() == context)
    try #require(Set(game.bodies.map(\.id)).count == game.bodies.count)
    let physicalIDs = game.bodies.compactMap { $0.physical?.identity }
    try #require(physicalIDs.count == game.bodies.count)
    try #require(Set(physicalIDs).count == game.bodies.count)
    try #require(Set(context.actors.map(\.identity)) == Set(physicalIDs))
    let projected = try #require(context.actors.first { $0.identity == identity })
    try #require(projected.energy == invalidEnergy && !projected.energy.isFinite)
    try expectCurrentMalformedRefusal(game, context: context)
  }

  private func ordinaryScene() throws -> Game {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try #require(!game.bodies.contains { $0.id == 9001 || $0.id == 9002 })
    // Ordinary fixture bodies use the existing public SpaceBody constructor;
    // actual native adoption supplies physical actors and context projection.
    // Neither body is claimed to be an admitted C01 fixture or a capability.
    game.bodies.append(.init(id: 9001, hull: .cobra, position: .init(1000, 0, 1000)))
    game.bodies.append(.init(id: 9002, hull: .cobra, position: .init(-1000, 0, 1000)))
    game.ensurePhysicalActors()
    try #require(Set(game.bodies.map(\.id)).count == game.bodies.count)
    let physicalIDs = game.bodies.compactMap { $0.physical?.identity }
    try #require(physicalIDs.count == game.bodies.count)
    try #require(Set(physicalIDs).count == game.bodies.count)
    try #require(game.bodies.allSatisfy { $0.energy.isFinite })
    try #require(game.commander.scriptState.savedC01Inquiry == nil)
    return game
  }

  private func expectCurrentMalformedRefusal(_ game: Game, context: EncounterContext) throws {
    try #require(game.gameplayContext() == context)
    try #require(context.system == game.systemIdentity)
    try #require(context.visit == game.commander.flightSimulation.visit)
    try #require(context.revision == game.gameplayRevision)
    try #require(context.physicalTime == game.commander.flightSimulation.physicalTime)
    let center = context.anchors.planet.position
    try #require(center.finite && center.length.isFinite && context.anchors.planet.radius > 0)
    let commander = game.commander
    let bodies = game.bodies
    let celestials = game.celestials
    let bodyID = game.nextBodyID
    let revision = game.gameplayRevision
    let epoch = game.nativeStationRuntimeEpoch
    let energy = game.energy
    let front = game.frontShield
    let rear = game.rearShield
    // If identity/finite-energy guards were removed, this valid query at the
    // actual planet centre would reach celestial unsafePosition, not staleContext.
    #expect(game.c01InquiryPlacementEnvelopeRefusal(
      center: center, radius: 1, context: context) == .staleContext)
    #expect(game.gameplayContext() == context)
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.celestials == celestials && game.nextBodyID == bodyID)
    #expect(game.gameplayRevision == revision && game.nativeStationRuntimeEpoch == epoch)
    #expect(game.energy == energy && game.frontShield == front && game.rearShield == rear)
    #expect(game.commander.scriptState.savedC01Inquiry == nil)
  }
}
