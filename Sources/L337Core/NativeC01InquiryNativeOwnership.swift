import Foundation

/// A source consistency window, never a complete-world or native-query proof.
/// It retains values consumed at query opening, rather than an entire Game.
fileprivate final class NativeC01InquiryNativeSceneBefore: Sendable {
  let epoch: UUID
  let context: EncounterContext
  let flight: FlightSimulationState
  let nextBodyID: Int
  let bodies: [SpaceBody]
  let celestials: [CelestialBody]
  let world: NativeStationWorld?
  let stationResources: [String: ScriptStationResource]
  let mainDestination: NativeMainStationDestinationState

  private init(game: borrowing Game, context: EncounterContext) {
    epoch = game.nativeStationRuntimeEpoch
    self.context = context
    flight = game.storedFlightSimulation()
    nextBodyID = game.nextBodyID
    bodies = game.bodies
    celestials = game.celestials
    world = game.storedNativeStationWorld()
    stationResources = game.commander.scriptState.stationResources
    mainDestination = game.nativeOriginalMainStationDestination
  }

  static func captureCurrentSource(game: borrowing Game,
    staged: NativeC01InquiryFixtureStagedCohort) -> NativeC01InquiryNativeSceneBefore?
  {
    guard game.c01InquiryStagedCohortIsCurrentForNativeOwner(staged),
      let context = game.gameplayContext(), context == staged.context
    else { return nil }
    return .init(game: game, context: context)
  }

  /// Current installed inspection snapshot only. No staged-before-birth source
  /// is reused after installation, and no fullworld/event window is issued.
  static func captureInstalledInspection(game: borrowing Game) -> NativeC01InquiryNativeSceneBefore? {
    guard !game.docked, let context = game.gameplayContext() else { return nil }
    return .init(game: game, context: context)
  }

  func matches(current game: borrowing Game) -> Bool {
    guard epoch == game.nativeStationRuntimeEpoch,
      context == game.gameplayContext(), flight == game.storedFlightSimulation(),
      nextBodyID == game.nextBodyID,
      bodies == game.bodies, celestials == game.celestials,
      world == game.storedNativeStationWorld(),
      stationResources == game.commander.scriptState.stationResources
    else { return false }
    switch (mainDestination, game.nativeOriginalMainStationDestination) {
    case (.living(let before), .living(let current)): return before == current
    case (.destroyed(let before), .destroyed(let current)): return before == current
    case (.unavailable, .unavailable): return true
    default: return false
    }
  }
}

/// One immutable material binding retains the SAME atlas and world buffer.
/// The sealed view is a value; its keys do not grant native lifetime authority.
fileprivate final class NativeC01InquiryNativeMaterial: Sendable {
  /// Same-winding primitive identity only, not material-error or solid proof.
  struct PrimitivePair: Sendable {
    let nativeWorldTriangleIndex: Int
    let sourceTriangleIndex: Int
    let sourceFace: Int
  }
  private struct PrimitiveKey: Hashable {
    let sourceFace: Int
    let a: Int
    let b: Int
    let c: Int
  }
  let atlas: NativeC01InquiryCompoundMaterialAtlas
  let view: NativeC01InquiryCompoundMaterialAtlas.View
  let prepared: NativeC01InquiryCurveGeometry.Prepared
  let sourceFrame: ShipPose
  // The same immutable, once-evaluated native world buffer as the paid shadow.
  // This leaf grants no installed dispatch or correspondence permission.
  let nativeWorldGeometry: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Data
  let nativeWorldPrepared: NativeC01InquiryCurveGeometry.Prepared
  let nativeWorldTriangles: [NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Triangle]
  let primitivePairs: [PrimitivePair]
  // Current source-frame data only, never an accepted clock or live capability.
  let queryVertices: [Vector3]
  let viewVertices: [Vector3]
  let queryPose: ShipPose
  let viewScreen: Screen
  let sourcePhysicalTime: Double
  let sourceEpoch: UUID

  private init(atlas: NativeC01InquiryCompoundMaterialAtlas,
    view: NativeC01InquiryCompoundMaterialAtlas.View,
    prepared: NativeC01InquiryCurveGeometry.Prepared, sourceFrame: ShipPose,
    nativeWorldGeometry: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Data,
    nativeWorldPrepared: NativeC01InquiryCurveGeometry.Prepared,
    nativeWorldTriangles: [NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Triangle],
    primitivePairs: [PrimitivePair],
    queryVertices: [Vector3], viewVertices: [Vector3], queryPose: ShipPose, viewScreen: Screen,
    sourcePhysicalTime: Double, sourceEpoch: UUID)
  {
    self.atlas = atlas; self.view = view; self.prepared = prepared
    self.sourceFrame = sourceFrame; self.nativeWorldGeometry = nativeWorldGeometry
    self.nativeWorldPrepared = nativeWorldPrepared; self.nativeWorldTriangles = nativeWorldTriangles
    self.primitivePairs = primitivePairs
    self.queryVertices = queryVertices; self.viewVertices = viewVertices
    self.queryPose = queryPose; self.viewScreen = viewScreen
    self.sourcePhysicalTime = sourcePhysicalTime; self.sourceEpoch = sourceEpoch
  }

  /// Retain only actual immutable source values. No phase or owner is retained.
  static func capture(game: borrowing Game,
    birth: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    shadow: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation,
    nativeWorld: NativeC01InquiryNativeQueryWork.GeometryPreparation,
    owner: NativeC01InquiryNativeQueryWork,
    meter: NativeC01InquiryPreparationWork.Meter) throws -> NativeC01InquiryNativeMaterial?
  {
    try meter.records(4, .metadata)
    guard nativeWorld.owner === owner, nativeWorld.prepared.hull.isClosed,
      shadow.matches(current: game, birth: birth, owner: owner),
      birth.instantaneous.geometryPreparation === birth.geometry,
      birth.instantaneous.statePreparation === birth.state,
      birth.instantaneous.source.materialView.atlas === birth.inputs.source.atlas,
      birth.instantaneous.source.materialView.vertexIDs == birth.inputs.source.view.vertexIDs,
      birth.instantaneous.source.materialView.facetIDs == birth.inputs.source.view.facetIDs,
      birth.instantaneous.source.materialView.matches(birth.state.state.representation),
      birth.instantaneous.source.prepared.nativeID == birth.geometry.prepared.nativeID
    else { return nil }
    let world = nativeWorld.prepared
    guard world.sourceVertices.count == shadow.data.vertices.count,
      world.sourceFaces.count == shadow.data.faces.count else { return nil }
    for index in world.sourceVertices.indices {
      try meter.records(2, .metadata)
      let actual = world.sourceVertices[index]
      let original = shadow.data.vertices[index]
      guard original.nativeIndex == index,
        actual.x.bitPattern == original.world.x.bitPattern,
        actual.y.bitPattern == original.world.y.bitPattern,
        actual.z.bitPattern == original.world.z.bitPattern else { return nil }
    }
    for index in world.sourceFaces.indices {
      try meter.records(2, .metadata)
      let actual = world.sourceFaces[index]
      let original = shadow.data.faces[index]
      guard original.nativeIndex == index, actual.count == original.vertices.count else { return nil }
      for offset in actual.indices {
        try meter.records(2, .metadata)
        guard actual[offset] == original.vertices[offset] else { return nil }
      }
    }
    let triangles = try owner.routeNativeMaterialTriangles(prepared: world,
      vertices: shadow.data.vertices, faces: shadow.data.faces, meter: meter)
    guard let primitivePairs = try pairNativePrimitives(source: shadow.data.triangles,
      world: triangles, meter: meter) else { return nil }
    guard let snapshot = try captureQueryViewSnapshot(game: game,
      geometry: shadow.data, meter: meter) else { return nil }
    return .init(atlas: birth.inputs.source.atlas, view: birth.inputs.source.view,
      prepared: birth.geometry.prepared, sourceFrame: birth.instantaneous.source.referencePose,
      nativeWorldGeometry: shadow.data, nativeWorldPrepared: world, nativeWorldTriangles: triangles,
      primitivePairs: primitivePairs,
      queryVertices: snapshot.queryVertices, viewVertices: snapshot.viewVertices,
      queryPose: snapshot.queryPose, viewScreen: snapshot.viewScreen,
      sourcePhysicalTime: snapshot.sourcePhysicalTime, sourceEpoch: snapshot.sourceEpoch)
  }

  /// Compare actual shared-buffer indices; never match approximate positions
  /// or assume world triangulation retained the source polygon's ear choices.
  private static func pairNativePrimitives(
    source: [NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Triangle],
    world: [NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Triangle],
    meter: NativeC01InquiryPreparationWork.Meter
  ) throws -> [PrimitivePair]? {
    try meter.records(2, .metadata)
    guard !source.isEmpty, source.count == world.count else { return nil }
    var remaining: [PrimitiveKey: Int] = [:]
    for index in source.indices {
      try meter.records(1, .metadata)
      let triangle = source[index]
      guard triangle.nativeIndex == index,
        let key = try primitiveKey(triangle, meter: meter) else { return nil }
      try meter.records(1, .metadata)
      guard remaining.updateValue(index, forKey: key) == nil else { return nil }
    }
    var pairs: [PrimitivePair] = []
    for index in world.indices {
      try meter.records(1, .metadata)
      let triangle = world[index]
      guard triangle.nativeIndex == index,
        let key = try primitiveKey(triangle, meter: meter) else { return nil }
      try meter.records(1, .metadata)
      guard let sourceIndex = remaining.removeValue(forKey: key) else { return nil }
      try meter.records(1, .metadata)
      pairs.append(.init(nativeWorldTriangleIndex: index,
        sourceTriangleIndex: sourceIndex, sourceFace: key.sourceFace))
    }
    try meter.records(1, .metadata)
    guard remaining.isEmpty else { return nil }
    return pairs
  }

  private static func primitiveKey(
    _ triangle: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Triangle,
    meter: NativeC01InquiryPreparationWork.Meter
  ) throws -> PrimitiveKey? {
    try meter.records(2, .metadata)
    guard triangle.vertices.count == 3, !triangle.unresolvedSupport else { return nil }
    try meter.records(6, .metadata)
    let a = triangle.vertices[0], b = triangle.vertices[1], c = triangle.vertices[2]
    guard a != b, b != c, c != a else { return nil }
    // Distinct indices have one minimum. Rotate cyclically to that minimum;
    // reversal retains a different key and therefore cannot silently flip winding.
    try meter.records(2, .metadata)
    var first = a, second = b, third = c
    if b < first { first = b; second = c; third = a }
    if c < first { first = c; second = a; third = b }
    try meter.records(4, .metadata)
    return .init(sourceFace: triangle.sourceFace, a: first, b: second, c: third)
  }

  /// Source-frame values only. The caller supplies the actual common world
  /// buffer; this helper grants no native motion, lifetime or query authority.
  private static func captureQueryViewSnapshot(game: borrowing Game,
    geometry: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation.Data,
    meter: NativeC01InquiryPreparationWork.Meter
  ) throws -> (queryVertices: [Vector3], viewVertices: [Vector3], queryPose: ShipPose,
    viewScreen: Screen, sourcePhysicalTime: Double, sourceEpoch: UUID)?
  {
    try meter.records(4, .metadata)
    let flight = game.storedFlightSimulation()
    let queryPose = flight.pose
    let viewScreen = game.screen
    let sourcePhysicalTime = flight.physicalTime
    let sourceEpoch = game.nativeStationRuntimeEpoch
    guard queryPose.position.finite, queryPose.orientation.validRotation,
      viewScreen.isFlight, sourcePhysicalTime.isFinite, sourcePhysicalTime >= 0
    else { return nil }
    var queryVertices: [Vector3] = []
    var viewVertices: [Vector3] = []
    for index in geometry.vertices.indices {
      try meter.records(3, .metadata)
      let query = queryPose.shipPoint(geometry.vertices[index].world)
      let view = Game.viewPosition(query, screen: viewScreen)
      guard query.finite, query.length.isFinite, view.finite, view.length.isFinite else { return nil }
      queryVertices.append(query)
      viewVertices.append(view)
    }
    return (queryVertices: queryVertices, viewVertices: viewVertices, queryPose: queryPose,
      viewScreen: viewScreen, sourcePhysicalTime: sourcePhysicalTime, sourceEpoch: sourceEpoch)
  }

  func matches(game: borrowing Game, birth: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    shadow: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation) -> Bool
  {
    let flight = game.storedFlightSimulation()
    return sourceEpoch == game.nativeStationRuntimeEpoch && sourceEpoch == birth.inputs.staged.nativeEpoch
      && sourcePhysicalTime == flight.physicalTime && sourcePhysicalTime == birth.actualBirthPhysicalTime
      && queryPose == flight.pose && viewScreen == game.screen
      && queryVertices.count == nativeWorldGeometry.vertices.count
      && viewVertices.count == queryVertices.count
      && atlas === birth.inputs.source.atlas && view.atlas === atlas
      && view.vertexIDs == birth.inputs.source.view.vertexIDs
      && view.facetIDs == birth.inputs.source.view.facetIDs
      && view.matches(birth.state.state.representation)
      && prepared.nativeID == birth.geometry.prepared.nativeID
      && sourceFrame == birth.instantaneous.source.referencePose
      && nativeWorldGeometry === shadow.data
  }
}

/// A leaf has no permit, installation, version-parent or proof backreference.
/// The producer must map actual member actors to facets of ONE common hull.
fileprivate final class NativeC01InquiryNativeBirth: Sendable {
  struct Member: Sendable {
    let role: NativeC01InquiryFixtureGeometry.Part
    let binding: NativeC01InquiryFixtureBinding
  }
  let epoch: UUID
  let ownerSession: UUID
  let fixture: NativeC01InquiryFixtureRef
  let members: [Member]
  let material: NativeC01InquiryNativeMaterial
  let program: NativeC01InquiryNativePassiveProgramLeaf

  private init(staged: NativeC01InquiryFixtureStagedCohort,
    members: [Member], material: NativeC01InquiryNativeMaterial,
    program: NativeC01InquiryNativePassiveProgramLeaf)
  {
    epoch = staged.nativeEpoch; ownerSession = staged.ownerSession
    fixture = staged.fixture; self.members = members; self.material = material
    self.program = program
  }

  func matches(_ staged: NativeC01InquiryFixtureStagedCohort) -> Bool {
    guard epoch == staged.nativeEpoch, ownerSession == staged.ownerSession,
      fixture == staged.fixture, program.fixture == fixture, program.epoch == epoch,
      program.ownerSession == ownerSession, members.count == staged.bindings.count,
      members.count == staged.partRecipes.count,
      Set(members.map(\.role)).count == members.count,
      material.view.atlas === material.atlas
    else { return false }
    return members.indices.allSatisfy { index in
      members[index].binding == staged.bindings[index]
        && members[index].role == staged.partRecipes[index].kind
    }
  }
}

/// Negative source retirement only; no event, clock or lifetime permission.
enum NativeC01InquiryNativeSourceInvalidation: Sendable, Equatable {
  case damage, impulse, contact, liftoff, source, equipment, script, lifecycle
  case clockDiscontinuity, currentness, publication, preparationRefused
}

/// Immutable versions carry current entries only. They never retain previous
/// versions, permits or installations, so repeated steps cannot grow ancestry.
final class NativeC01InquiryNativeRegistry: Sendable {
  fileprivate final class Entry: Sendable {
    let birth: NativeC01InquiryNativeBirth
    let material: NativeC01InquiryNativeMaterial
    // Birth binds the actual instantaneous state. A future proposed curve is
    // not required or stored as attained material/placement authority.
    let state: NativeC01InquiryCompoundValidatedCurve.State
    let physicalTime: Double
    let retirement: NativeC01InquiryNativeSourceInvalidation?
    private init(birth: NativeC01InquiryNativeBirth,
      material: NativeC01InquiryNativeMaterial,
      state: NativeC01InquiryCompoundValidatedCurve.State, physicalTime: Double,
      retirement: NativeC01InquiryNativeSourceInvalidation?)
    {
      self.birth = birth; self.material = material
      self.state = state; self.physicalTime = physicalTime; self.retirement = retirement
    }

    /// Derive only a retired version of an EXISTING entry. No valid birth is issued.
    fileprivate func retiring(before event: NativeC01InquiryNativeSourceInvalidation) -> Entry {
      guard retirement == nil else { return self }
      return .init(birth: birth, material: material, state: state,
        physicalTime: physicalTime, retirement: event)
    }
  }
  fileprivate let entries: [Entry]
  private init(entries: [Entry]) { self.entries = entries }

  /// Empty state confers no source, material, placement or event authority.
  static func empty() -> NativeC01InquiryNativeRegistry { .init(entries: []) }

  /// Keep all native claims and first retirement causes, without mutating a
  /// registry shared by the live Game and a failed private publication candidate.
  fileprivate func retiringAllEntries(before event: NativeC01InquiryNativeSourceInvalidation)
    -> NativeC01InquiryNativeRegistry
  {
    guard entries.contains(where: { $0.retirement == nil }) else { return self }
    return .init(entries: entries.map { $0.retiring(before: event) })
  }
}

/// A claim decision is not registered geometry. Until a genuine installed
/// frame/dispatch producer exists, claimed members explicitly refuse fallback.
enum NativeC01InquiryGeometryClaimDisposition: Sendable, Equatable {
  enum Refusal: Sendable, Equatable {
    case missingRegisteredSource, inconsistentRegisteredClaim, staleRegisteredClaim
    case registeredDispatchUnavailable
  }
  case ordinary
  case refused(Refusal)
}

extension NativeC01InquiryNativeRegistry {
  fileprivate enum GeometryClaim {
    case none
    case exact(Entry)
    case inconsistent
  }

  /// Registry identity claims survive a lost/replaced public producer tag.
  /// This readonly lookup is currently unmetered and conveys no query approval.
  fileprivate func geometryClaim(bodyID: Int, actor: ActorIdentity?, spawn: SpawnIdentity?)
    -> GeometryClaim
  {
    var matched: Entry?
    for entry in entries {
      for member in entry.birth.members {
        let binding = member.binding
        let bodyMatch = binding.bodyID == bodyID
        let actorMatch = actor == binding.actor
        let spawnMatch = spawn == binding.spawn
        guard bodyMatch || actorMatch || spawnMatch else { continue }
        guard bodyMatch, actorMatch, spawnMatch, matched == nil else { return .inconsistent }
        matched = entry
      }
    }
    if let matched { return .exact(matched) }
    return .none
  }
}

extension Game {
  /// Refuse further native source use BEFORE effects. Empty/retired versions
  /// preserve identity; attained clock/model state is never reset here.
  mutating func invalidateC01InquiryNativeSource(before event: NativeC01InquiryNativeSourceInvalidation) {
    let current = c01InquiryNativeRegistry
    let retired = current.retiringAllEntries(before: event)
    guard retired !== current else { return }
    c01InquiryNativeRegistry = retired
  }

  /// Only absence of BOTH actual namespace and registry claims permits the
  /// existing ordinary body path. Phase material DATA cannot satisfy this gate.
  func c01InquiryGeometryClaimDisposition(for body: borrowing SpaceBody)
    -> NativeC01InquiryGeometryClaimDisposition
  {
    let bodyID = body.id
    let actor = body.physical?.identity
    let spawn = body.physical?.spawnIdentity
    let declaredClaim = spawn?.producer == .c01Inquiry
    switch c01InquiryNativeRegistry.geometryClaim(bodyID: bodyID, actor: actor, spawn: spawn) {
    case .none:
      return declaredClaim ? .refused(.missingRegisteredSource) : .ordinary
    case .inconsistent:
      return .refused(.inconsistentRegisteredClaim)
    case .exact(let entry):
      guard entry.retirement == nil, declaredClaim, entry.birth.epoch == nativeStationRuntimeEpoch,
        entry.birth.ownerSession == c01InquiryStepRuntime.ownerSession,
        entry.physicalTime == storedFlightSimulation().physicalTime
      else { return .refused(.staleRegisteredClaim) }
      // No genuine registered frame/coupled-motion dispatch exists yet. An
      // exact live registry address alone never authorizes independent geometry.
      return .refused(.registeredDispatchUnavailable)
    }
  }
}

/// Unavailable geometry is an error, never a collision miss or an empty hull.
struct NativeC01InquiryGeometryDispatchFailure: Error, Sendable, Equatable {
  let bodyID: Int?
  let reason: NativeC01InquiryGeometryClaimDisposition.Refusal
}

extension Game {
  /// Whole current claim scan. Registry/source lookup remains unmetered.
  /// No positive registered source is fabricated while its producer is absent.
  func c01InquiryGeometryDispatchFailure() -> NativeC01InquiryGeometryDispatchFailure? {
    for index in bodies.indices {
      switch c01InquiryGeometryClaimDisposition(for: bodies[index]) {
      case .ordinary: continue
      case .refused(let reason): return .init(bodyID: bodies[index].id, reason: reason)
      }
    }
    // A registry orphan must not disappear merely because its body is absent.
    if let entry = c01InquiryNativeRegistry.entries.first {
      return .init(bodyID: entry.birth.members.first?.binding.bodyID,
        reason: .inconsistentRegisteredClaim)
    }
    return nil
  }

  func requireC01InquiryOrdinaryGeometryScene() throws {
    if let failure = c01InquiryGeometryDispatchFailure() { throw failure }
  }

  /// Reject the ENTIRE frame before work/calendar/physical-clock effects.
  /// There is no C01-only parking, pose correction or accepted-time backfill.
  mutating func admitC01InquiryGeometryAdvance() -> Bool {
    guard c01InquiryGeometryDispatchFailure() == nil else {
      paused = true
      notify("FLIGHT PAUSED - SCENE UNAVAILABLE", voiced: false)
      return false
    }
    return true
  }
}

/// Actual native host/source snapshot for the NEW explicit initial-motion
/// recipe. It is not a fixture, native contact or placement permission.
fileprivate final class NativeC01InquiryNativeBirthHost {
  let intent: NativeC01InquiryFixtureBirthIntent
  let host: NativeMainStationDestinationContext
  let epoch: UUID
  let flight: FlightSimulationState
  let world: NativeStationWorld
  let body: SpaceBody
  let worldTranslation: Vector3

  private init(intent: NativeC01InquiryFixtureBirthIntent,
    host: NativeMainStationDestinationContext, epoch: UUID,
    flight: FlightSimulationState, world: NativeStationWorld,
    body: SpaceBody, worldTranslation: Vector3)
  {
    self.intent = intent; self.host = host; self.epoch = epoch; self.flight = flight
    self.world = world; self.body = body; self.worldTranslation = worldTranslation
  }

  static func capture(game: borrowing Game, intent: NativeC01InquiryFixtureBirthIntent)
    -> NativeC01InquiryNativeBirthHost?
  {
    guard game.c01InquiryFixtureBirthIntentIsCurrentForNativeOwner(intent),
      !game.docked, case .living(let host) = game.nativeOriginalMainStationDestination,
      let world = game.storedNativeStationWorld(), world.valid,
      NativeC01InquiryFixtureGeometry.metresPerWorldUnit == 1
    else { return nil }
    let flight = game.storedFlightSimulation()
    let candidates = game.bodies.filter { $0.id == 0 }
    guard candidates.count == 1, let body = candidates.first,
      body.hull == .station, body.energy > 0, body.nativeStationIdentity == nil,
      body.energy == host.resource.energy,
      body.nativeStationPhysicalIdentity == host.observation.actor,
      host.identity.system == game.storedSystemIdentity(), host.identity.world == world.ledger.world,
      host.runtimeEpoch == game.nativeStationRuntimeEpoch,
      world.sceneIsConsistent(bodies: game.bodies, docked: false,
        mainStation: game.dockedAtMainStation, system: game.storedSystemIdentity(), flight: flight),
      game.stationInertialIdentity(for: body, at: flight.physicalTime) == .main(host.identity),
      let sourceAnchor = flight.anchors?.station,
      let currentAnchor = game.currentNativeMainStationAnchor(at: flight.physicalTime),
      sourceAnchor.identity == host.observation.actor,
      (flight.pose.systemPoint(body.position) - currentAnchor.position).length < 1e-5,
      let actualVelocity = body.nativeStationPhysicalVelocity
    else { return nil }
    for axis in [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)] {
      guard (flight.pose.orientation.apply(body.orientation.apply(axis))
        - currentAnchor.orientation.apply(axis)).length < 1e-5 else { return nil }
    }
    let velocity: Vector3
    if let inertia = world.inertia(for: .main(host.identity)) {
      guard inertia.valid, inertia.physicalTime <= flight.physicalTime,
        inertia.offset(at: flight.physicalTime) != nil,
        actualVelocity == inertia.velocity
      else { return nil }
      velocity = inertia.velocity
    } else {
      // The registered original source explicitly has a fixed zero origin in
      // the absence of native inertia. Prove that case; missing motion/identity
      // information elsewhere must never be replaced with a zero velocity.
      let zero = Vector3(0, 0, 0)
      guard world.mainStations.contains(host.identity), sourceAnchor.position == zero,
        world.sourcePosition(for: .main(host.identity)) == zero,
        world.currentPosition(for: .main(host.identity), at: flight.physicalTime) == zero,
        currentAnchor.position == zero, actualVelocity == zero
      else { return nil }
      velocity = zero
    }
    guard velocity.finite, velocity.length.isFinite else { return nil }
    return .init(intent: intent, host: host, epoch: game.nativeStationRuntimeEpoch,
      flight: flight, world: world, body: body, worldTranslation: velocity)
  }

  func matches(current game: borrowing Game) -> Bool {
    guard epoch == game.nativeStationRuntimeEpoch,
      game.c01InquiryFixtureBirthIntentIsCurrentForNativeOwner(intent),
      game.acceptsNativeMainStationDestination(host),
      flight == game.storedFlightSimulation(), world == game.storedNativeStationWorld(),
      game.bodies.filter({ $0.id == body.id }) == [body]
    else { return false }
    return true
  }
}

/// Temporary genuine staging/source provenance, with no quaternion input and
/// no declaration that placement, lifetime, a closed joint or a step is valid.
/// Steady registry entries must not retain these inputs or their phase owner.
fileprivate final class NativeC01InquiryNativeBirthInputs {
  static let motionRevision = "c01-inquiry-host-translation-zero-world-spin-v1"
  let staged: NativeC01InquiryFixtureStagedCohort
  let source: NativeC01InquiryNativeQueryWork.SourcePreparation
  let host: NativeC01InquiryNativeBirthHost
  let sceneBefore: NativeC01InquiryNativeSceneBefore
  let expectedBefore: NativeC01InquiryNativeRegistry

  private init(staged: NativeC01InquiryFixtureStagedCohort,
    source: NativeC01InquiryNativeQueryWork.SourcePreparation,
    host: NativeC01InquiryNativeBirthHost, sceneBefore: NativeC01InquiryNativeSceneBefore,
    expectedBefore: NativeC01InquiryNativeRegistry)
  {
    self.staged = staged; self.source = source; self.host = host
    self.sceneBefore = sceneBefore; self.expectedBefore = expectedBefore
  }

  static func capture(game: borrowing Game, staged: NativeC01InquiryFixtureStagedCohort,
    source: NativeC01InquiryNativeQueryWork.SourcePreparation,
    host: NativeC01InquiryNativeBirthHost,
    meter: NativeC01InquiryPreparationWork.Meter) throws -> NativeC01InquiryNativeBirthInputs?
  {
    try meter.node(.control)
    guard host.matches(current: game), staged.sourceIntent === host.intent,
      staged.nativeEpoch == host.epoch, staged.context.physicalTime == host.flight.physicalTime,
      source.view.atlas === source.atlas,
      let scene = NativeC01InquiryNativeSceneBefore.captureCurrentSource(game: game, staged: staged)
    else { return nil }
    try meter.records(staged.partRecipes.count, .metadata)
    try meter.records(source.ancestor.mass.parts.count, .metadata)
    guard staged.partRecipes.count == 4, source.ancestor.mass.parts.count == 4,
      source.view.representation.mass.parts.count == 4 else { return nil }
    for index in staged.partRecipes.indices {
      try meter.records(1, .metadata)
      let recipe = staged.partRecipes[index]
      let mass = source.ancestor.mass.parts[index]
      guard recipe.kind == mass.kind, recipe.hull == .sidewinder,
        recipe.massKilograms == mass.massKilograms,
        recipe.velocity == host.worldTranslation, recipe.angularVelocity == .init(0, 0, 0)
      else { return nil }
    }
    return .init(staged: staged, source: source, host: host, sceneBefore: scene,
      expectedBefore: game.c01InquiryNativeRegistry)
  }

  func matches(current game: borrowing Game) -> Bool {
    host.matches(current: game) && sceneBefore.matches(current: game)
      && expectedBefore === game.c01InquiryNativeRegistry
      && game.c01InquiryStagedCohortIsCurrentForNativeOwner(staged)
  }
}

/// Immutable explicit program identity. It retains no prebirth snapshot,
/// candidate, registry ancestor or query owner. Installation remains unissued.
fileprivate final class NativeC01InquiryNativePassiveProgramLeaf: Sendable {
  struct Part: Sendable {
    let role: NativeC01InquiryFixtureGeometry.Part
    let massKilograms: Double
  }
  let owner: UUID
  let caseID: UUID
  let sourceBirth: UUID
  let epoch: UUID
  let ownerSession: UUID
  let actualBirthPhysicalTime: Double
  let initialSeed: NativeC01InquiryCompoundValidatedCurve.ConstrainedInitialSeed
  let fixture: NativeC01InquiryFixtureRef
  let parts: [Part]
  let lawRevision = NativeC01InquiryPassiveFixtureForceLaw.revision
  let metresPerWorldUnit = 1.0

  private init(preparation: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    initialSeed: NativeC01InquiryCompoundValidatedCurve.ConstrainedInitialSeed)
  {
    let staged = preparation.inputs.staged
    let root = staged.proposedRoot
    owner = root.owner; caseID = root.caseRecord.id
    sourceBirth = root.institutionalSource.birthOperation
    epoch = staged.nativeEpoch; ownerSession = staged.ownerSession; fixture = staged.fixture
    actualBirthPhysicalTime = preparation.actualBirthPhysicalTime
    self.initialSeed = initialSeed
    parts = preparation.inputs.source.ancestor.mass.parts.map {
      .init(role: $0.kind, massKilograms: $0.massKilograms)
    }
  }

  /// Source identity only. The complete native installation factory must still
  /// qualify this leaf with actual birth/material/world/placement premises.
  static func capture(game: borrowing Game,
    preparation: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    initial: NativeC01InquiryNativeQueryWork.GameBornInitialSeedPreparation,
    owner: NativeC01InquiryNativeQueryWork) -> NativeC01InquiryNativePassiveProgramLeaf?
  {
    guard preparation.matchesCurrentBirthSource(game: game, workOwner: owner),
      preparation.inputs.source.ancestor.mass.parts.count == 4,
      NativeC01InquiryFixtureGeometry.metresPerWorldUnit == 1
    else { return nil }
    guard initial.owner === owner, initial.birth === preparation else { return nil }
    return .init(preparation: preparation, initialSeed: initial.seed)
  }
}

/// Actual installed-source inspection, not a finite physics/event window.
/// This synchronous phase object is never stored in Game/Entry or sent across
/// actors. Revocation cannot mutate an immutable registry shared by a failed
/// private publication candidate and the live Game.
fileprivate final class NativeC01InquiryInstalledPassiveSourceOpening {
  let registry: NativeC01InquiryNativeRegistry
  let program: NativeC01InquiryNativePassiveProgramLeaf
  let root: NativeC01InquiryState
  let model: NativeC01InquiryModelSnapshot
  let entries: [NativeC01InquiryNativeRegistry.Entry]
  private var scene: NativeC01InquiryNativeSceneBefore?
  private(set) var revoked = false

  private init(registry: NativeC01InquiryNativeRegistry,
    program: NativeC01InquiryNativePassiveProgramLeaf, root: NativeC01InquiryState,
    model: NativeC01InquiryModelSnapshot, entries: [NativeC01InquiryNativeRegistry.Entry],
    scene: NativeC01InquiryNativeSceneBefore)
  {
    self.registry = registry; self.program = program; self.root = root
    self.model = model; self.entries = entries; self.scene = scene
  }

  static func capture(game: borrowing Game,
    meter: NativeC01InquiryPreparationWork.Meter) throws -> NativeC01InquiryInstalledPassiveSourceOpening?
  {
    try meter.records(1, .metadata)
    let registry = game.c01InquiryNativeRegistry
    guard !registry.entries.isEmpty else { return nil }
    // Deep retained-source/model validation is source inspection, not claimed
    // paid by the bounded field-record reservations around it.
    guard !game.docked, !game.paused, game.screen.isFlight,
      let root = game.commander.scriptState.savedC01Inquiry, root.shapeValid,
      root.owner == game.commander.equipmentOwnerID,
      root.institutionalSource.availability == .available,
      game.c01InquiryStepRuntime.hasNativeModelRegistration,
      let model = game.c01InquiryStepRuntime.liveModelSnapshotData,
      model.shapeValid, model.physicalTime == game.storedFlightSimulation().physicalTime,
      let generation = root.caseRecord.fixtureGenerations.last,
      generation.retirement == nil, generation.modelSnapshot == model,
      try NativeC01InquiryOperatorRetainedSource.validate(root),
      let scene = NativeC01InquiryNativeSceneBefore.captureInstalledInspection(game: game)
    else { return nil }
    var matching: [NativeC01InquiryNativeRegistry.Entry] = []
    var program: NativeC01InquiryNativePassiveProgramLeaf?
    for index in registry.entries.indices {
      try meter.records(1, .metadata)
      let entry = registry.entries[index]
      guard entry.retirement == nil else { return nil }
      if entry.birth.fixture.matches(generation) {
        let leaf = entry.birth.program
        guard leaf.owner == root.owner, leaf.caseID == root.caseRecord.id,
          leaf.sourceBirth == root.institutionalSource.birthOperation,
          leaf.epoch == game.nativeStationRuntimeEpoch,
          leaf.ownerSession == game.c01InquiryStepRuntime.ownerSession,
          leaf.fixture == entry.birth.fixture,
          leaf.lawRevision == NativeC01InquiryPassiveFixtureForceLaw.revision,
          leaf.metresPerWorldUnit == 1, leaf.parts.count == 4,
          entry.birth.epoch == leaf.epoch, entry.birth.ownerSession == leaf.ownerSession,
          entry.birth.members.count == 4, entry.physicalTime == model.physicalTime,
          entry.material.view.atlas === entry.material.atlas,
          entry.material.atlas === entry.birth.material.atlas
        else { return nil }
        if let previous = program {
          guard previous === leaf else { return nil }
        } else { program = leaf }
        try meter.records(1, .metadata)
        matching.append(entry)
      }
    }
    guard let program, (1...4).contains(matching.count) else { return nil }
    try meter.records(root.fixtureLifecycle.count, .metadata)
    let lives = root.fixtureLifecycle.filter {
      $0.caseID == program.caseID && $0.fixture == program.fixture
    }
    guard lives.count == 1, let life = lives.first, life.retirement == nil,
      life.modelSnapshot == model else { return nil }
    var roles: [NativeC01InquiryFixtureGeometry.Part] = []
    for entry in matching {
      guard try NativeC01InquiryNativeMaterialViewInspection.matches(entry.material.view,
        shape: entry.state.representation, meter: meter),
        (1...4).contains(entry.state.representation.mass.parts.count) else { return nil }
      for part in entry.state.representation.mass.parts {
        try meter.records(1, .metadata)
        var sourceMass: Double?
        for source in program.parts {
          try meter.records(1, .metadata)
          if source.role == part.kind { sourceMass = source.massKilograms }
        }
        guard sourceMass == part.massKilograms else { return nil }
        for prior in roles {
          try meter.records(1, .metadata)
          guard prior != part.kind else { return nil }
        }
        try meter.records(1, .metadata)
        roles.append(part.kind)
      }
    }
    guard roles.count == 4 else { return nil }
    let actualParts = [life.support, life.head0, life.head1, life.head2]
    try meter.records(actualParts.count, .metadata)
    guard program.parts.count == actualParts.count else { return nil }
    for index in actualParts.indices {
      try meter.records(1, .metadata)
      let part = actualParts[index]
      guard case .present = part.presence, part.physicalTime == model.physicalTime,
        part.binding == matching[0].birth.members[index].binding,
        matching[0].birth.members[index].role == program.parts[index].role
      else { return nil }
      var current: SpaceBody?
      var matches = 0
      for bodyIndex in scene.bodies.indices {
        try meter.records(1, .metadata)
        let body = scene.bodies[bodyIndex]
        if body.id == part.binding.bodyID {
          matches += 1; current = body
        } else if body.physical?.identity == part.binding.actor { return nil }
        else if body.physical?.spawnIdentity == part.binding.spawn { return nil }
      }
      guard matches == 1, let body = current, let physical = body.physical,
        physical.identity == part.binding.actor, physical.spawnIdentity == part.binding.spawn,
        body.energy == part.energy, body.energy > 0,
        physical.velocity == part.velocity, physical.angularVelocity == part.angularVelocity,
        body.rotation == 0, body.rotationRate == 0, body.scriptNPC == nil,
        body.scriptShot == nil, physical.npc == nil, physical.ordnance == nil,
        body.position.finite, body.orientation.validRotation
      else { return nil }
    }
    // Pose/shadow equivalence and current group/view correspondence are NOT
    // inferred by these checks. Full native material/geometry qualification
    // remains mandatory before any future Window or physics publication.
    guard scene.matches(current: game) else { return nil }
    return .init(registry: registry, program: program, root: root, model: model,
      entries: matching, scene: scene)
  }

  func matches(current game: borrowing Game) -> Bool {
    guard !revoked, let scene, scene.matches(current: game),
      game.c01InquiryNativeRegistry === registry,
      game.commander.scriptState.savedC01Inquiry == root,
      game.c01InquiryStepRuntime.liveModelSnapshotData == model,
      game.c01InquiryStepRuntime.ownerSession == program.ownerSession
    else { return false }
    return true
  }

  func invalidateBeforeSourceEventOrPublication() {
    revoked = true
    scene = nil
  }
}

/// Initial source correspondence DATA only. No Game, birth preparation,
/// phase owner, permit or history parent is retained by this immutable leaf.
fileprivate final class NativeC01InquiryNativeInitialCorrespondence: Sendable {
  private typealias S = NativeC01InquiryCompoundValidatedCurve
  let seed: NativeC01InquiryCompoundValidatedCurve.ConstrainedInitialSeed
  let material: NativeC01InquiryNativeMaterial
  let geometry: NativeC01InquiryCompoundValidatedCurve.ConstrainedMaterialGeometry
  let vertices: [NativeC01InquiryCompoundValidatedCurve.NativeQueryViewPositionError]

  private init(seed: S.ConstrainedInitialSeed, material: NativeC01InquiryNativeMaterial,
    geometry: S.ConstrainedMaterialGeometry, vertices: [S.NativeQueryViewPositionError])
  {
    self.seed = seed; self.material = material; self.geometry = geometry
    self.vertices = vertices
  }

  static func prepare(game: borrowing Game,
    birth: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    initial: NativeC01InquiryNativeQueryWork.GameBornInitialSeedPreparation,
    shadow: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation,
    material: NativeC01InquiryNativeMaterial, owner: NativeC01InquiryNativeQueryWork,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) throws -> NativeC01InquiryNativeInitialCorrespondence {
    try work.reservePreparedMetadataRecords(8)
    guard initial.owner === owner, initial.birth === birth,
      initial.seed.declaredAnchorTime == birth.actualBirthPhysicalTime,
      birth.matchesCurrentBirthSource(game: game, workOwner: owner),
      shadow.matches(current: game, birth: birth, owner: owner),
      material.matches(game: game, birth: birth, shadow: shadow)
    else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    let geometry = try S.prepareInitialSourceMaterialGeometry(initial.seed, work: &work)
    try work.reservePreparedMetadataRecords(6)
    let count = material.nativeWorldGeometry.vertices.count
    guard count > 0, geometry.view.atlas === material.atlas,
      geometry.view.vertexIDs.count == count,
      material.queryVertices.count == count, material.viewVertices.count == count
    else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    try work.reservePreparedMetadataRecords(geometry.view.vertexIDs.count)
    try work.reservePreparedMetadataRecords(geometry.view.facetIDs.count)
    guard geometry.view.vertexIDs == material.view.vertexIDs,
      geometry.view.facetIDs == material.view.facetIDs
    else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    var vertices: [S.NativeQueryViewPositionError] = []
    for index in material.nativeWorldGeometry.vertices.indices {
      try work.reservePreparedMetadataRecords(4)
      let vertex = material.nativeWorldGeometry.vertices[index]
      guard vertex.nativeIndex == index,
        vertex.materialVertexID == geometry.view.vertexIDs[index]
      else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
      try work.reservePreparedMetadataRecords(3)
      let represented = S.VectorBox.point(vertex.world)
      // The historical cut-named comparison consumes geometry DATA here from
      // the original INITIAL seed. No cut or elapsed event is asserted.
      let world = try S.prepareCutNativePositionError(geometry, vertex: index,
        representedPosition: represented, work: &work)
      let projected = try S.prepareNativeQueryViewPositionError(world,
        queryPose: material.queryPose, screen: material.viewScreen,
        representedWorldPoint: vertex.world,
        representedQueryPoint: material.queryVertices[index],
        representedViewPoint: material.viewVertices[index], work: &work)
      try work.reservePreparedMetadataRecords(1)
      vertices.append(projected)
    }
    try work.reservePreparedMetadataRecords(8)
    guard initial.owner === owner, initial.birth === birth,
      initial.seed.declaredAnchorTime == birth.actualBirthPhysicalTime,
      birth.matchesCurrentBirthSource(game: game, workOwner: owner),
      shadow.matches(current: game, birth: birth, owner: owner),
      material.matches(game: game, birth: birth, shadow: shadow)
    else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    try work.reservePreparedMetadataRecords(1)
    return .init(seed: initial.seed, material: material, geometry: geometry, vertices: vertices)
  }

  func matches(game: borrowing Game,
    birth: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    initialSeed: NativeC01InquiryCompoundValidatedCurve.ConstrainedInitialSeed,
    shadow: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation,
    material: NativeC01InquiryNativeMaterial, owner: NativeC01InquiryNativeQueryWork
  ) -> Bool {
    seed === initialSeed && self.material === material
      && vertices.count == material.nativeWorldGeometry.vertices.count
      && geometry.view.atlas === material.atlas
      && seed.declaredAnchorTime == birth.actualBirthPhysicalTime
      && birth.matchesCurrentBirthSource(game: game, workOwner: owner)
      && shadow.matches(current: game, birth: birth, owner: owner)
      && material.matches(game: game, birth: birth, shadow: shadow)
  }
}

/// A genuine birth-preparation bound program CANDIDATE, not an installed
/// native producer or a qualified source/time window. The NEW prescribed law
/// requires sole coupled integration; existing canonical spin cannot enact it.
fileprivate final class NativeC01InquiryNativePassiveProducerCandidate {
  typealias Invalidation = NativeC01InquiryNativeSourceInvalidation
  private var birth: NativeC01InquiryNativeQueryWork.GameBirthPreparation?
  private var initialClearance: NativeC01InquiryNativeQueryWork.BirthClearancePreparation?
  private var materialShadow: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation?
  private var material: NativeC01InquiryNativeMaterial?
  private var initialCorrespondence: NativeC01InquiryNativeInitialCorrespondence?
  private(set) var invalidation: Invalidation?
  let prescription = NativeC01InquiryPassiveFixtureForceLaw.Prescription.coupledPassiveCOM
  let program: NativeC01InquiryNativePassiveProgramLeaf
  fileprivate let owner: NativeC01InquiryNativeQueryWork

  private init(birth: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    program: NativeC01InquiryNativePassiveProgramLeaf, owner: NativeC01InquiryNativeQueryWork,
    initialClearance: NativeC01InquiryNativeQueryWork.BirthClearancePreparation,
    materialShadow: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation,
    material: NativeC01InquiryNativeMaterial,
    initialCorrespondence: NativeC01InquiryNativeInitialCorrespondence)
  {
    self.birth = birth; self.program = program; self.owner = owner
    self.initialClearance = initialClearance
    self.materialShadow = materialShadow; self.material = material
    self.initialCorrespondence = initialCorrespondence
  }

  static func capture(game: borrowing Game,
    birth: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    initial: NativeC01InquiryNativeQueryWork.GameBornInitialSeedPreparation,
    initialClearance: NativeC01InquiryNativeQueryWork.BirthClearancePreparation,
    materialShadow: NativeC01InquiryNativeQueryWork.MaterialShadowPreparation,
    material: NativeC01InquiryNativeMaterial,
    initialCorrespondence: NativeC01InquiryNativeInitialCorrespondence,
    owner: NativeC01InquiryNativeQueryWork) -> NativeC01InquiryNativePassiveProducerCandidate?
  {
    guard initialCorrespondence.matches(game: game, birth: birth, initialSeed: initial.seed,
      shadow: materialShadow, material: material, owner: owner),
      initialClearance.matches(current: game, birth: birth, material: material, owner: owner),
      materialShadow.matches(current: game, birth: birth, owner: owner),
      material.matches(game: game, birth: birth, shadow: materialShadow),
      birth.state.owner === owner, birth.geometry.owner === owner,
      birth.instantaneous.owner === owner, birth.inputs.source.owner === owner,
      birth.inputs.matches(current: game),
      birth.seed.materialView.atlas === birth.inputs.source.atlas,
      birth.state.source === birth.inputs.source,
      birth.state.state.representation.mass.parts.count == 4,
      NativeC01InquiryFixtureGeometry.metresPerWorldUnit == 1
    else { return nil }
    guard let program = NativeC01InquiryNativePassiveProgramLeaf.capture(game: game,
      preparation: birth, initial: initial, owner: owner) else { return nil }
    // This explicit producer prescription is the source of F=0/tauCOM=0.
    // Neither initial zero spin nor absent native controllers supplies it.
    return .init(birth: birth, program: program, owner: owner,
      initialClearance: initialClearance, materialShadow: materialShadow, material: material,
      initialCorrespondence: initialCorrespondence)
  }

  func matches(current game: borrowing Game) -> Bool {
    guard invalidation == nil, let birth, let initialClearance, let materialShadow,
      let material, let initialCorrespondence else { return false }
    return birth.inputs.matches(current: game)
      && initialCorrespondence.matches(game: game, birth: birth, initialSeed: program.initialSeed,
        shadow: materialShadow, material: material, owner: owner)
      && initialClearance.matches(current: game, birth: birth, material: material, owner: owner)
      && materialShadow.matches(current: game, birth: birth, owner: owner)
      && material.matches(game: game, birth: birth, shadow: materialShadow)
  }

  /// Must precede an actual source event/publication. Irreversible within this
  /// phase: old field candidates retain this latch and become unusable too.
  func invalidate(before event: Invalidation) {
    if invalidation == nil { invalidation = event }
    birth = nil
    initialClearance = nil
    materialShadow = nil
    material = nil
    initialCorrespondence = nil
  }

  fileprivate var currentBirth: NativeC01InquiryNativeQueryWork.GameBirthPreparation? {
    invalidation == nil ? birth : nil
  }

  // A leaf is never an Entry, admission permit, current frame or accepted interval.
  fileprivate func currentMaterial(game: borrowing Game) -> NativeC01InquiryNativeMaterial? {
    matches(current: game) ? material : nil
  }
}

/// No constructor is called yet. Only the complete genuine native producer may
/// issue this after actual world/provider/query/material/work qualification.
/// Source consistency and mathematical curve results alone cannot issue it.
final class NativeC01InquiryNativeRegistryInstallation: Sendable {
  fileprivate let staged: NativeC01InquiryFixtureStagedCohort
  fileprivate let sceneBefore: NativeC01InquiryNativeSceneBefore
  fileprivate let expectedBefore: NativeC01InquiryNativeRegistry
  fileprivate let after: NativeC01InquiryNativeRegistry
  fileprivate let birth: NativeC01InquiryNativeBirth

  private init(staged: NativeC01InquiryFixtureStagedCohort,
    sceneBefore: NativeC01InquiryNativeSceneBefore,
    expectedBefore: NativeC01InquiryNativeRegistry,
    after: NativeC01InquiryNativeRegistry, birth: NativeC01InquiryNativeBirth)
  {
    self.staged = staged; self.sceneBefore = sceneBefore
    self.expectedBefore = expectedBefore; self.after = after; self.birth = birth
  }

  fileprivate func preservesExistingEntriesAndAppendsBirth() -> Bool {
    let previous = expectedBefore.entries
    let next = after.entries
    guard next.count > 0, next.count - 1 == previous.count,
      let appended = next.last, appended.birth === birth,
      appended.material === birth.material,
      appended.material.view.atlas === appended.material.atlas,
      birth.matches(staged), appended.physicalTime == staged.context.physicalTime,
      appended.material.view.matches(appended.state.representation)
    else { return false }
    // Pointer identity retains prior lifetime/material/curve owners. Comparing
    // structural mesh data here would permit replacement with an unrelated atlas.
    return previous.indices.allSatisfy { index in
      previous[index] === next[index]
    }
  }
}

final class NativeC01InquiryNativeAdmissionPermit: Sendable {
  private let staged: NativeC01InquiryFixtureStagedCohort
  let registryInstallation: NativeC01InquiryNativeRegistryInstallation

  private init(staged: NativeC01InquiryFixtureStagedCohort,
    registryInstallation: NativeC01InquiryNativeRegistryInstallation)
  {
    self.staged = staged; self.registryInstallation = registryInstallation
  }

  func matches(_ staged: NativeC01InquiryFixtureStagedCohort,
    current game: borrowing Game) -> Bool
  {
    self.staged === staged
      && game.c01InquiryStagedCohortIsCurrentForNativeOwner(staged)
      && game.canInstallC01InquiryNativeRegistry(registryInstallation, for: staged)
  }
}

extension Game {
  func canInstallC01InquiryNativeRegistry(
    _ installation: NativeC01InquiryNativeRegistryInstallation,
    for staged: NativeC01InquiryFixtureStagedCohort) -> Bool
  {
    installation.staged === staged
      && nativeStationRuntimeEpoch == staged.nativeEpoch
      && installation.sceneBefore.epoch == staged.nativeEpoch
      && c01InquiryNativeRegistry === installation.expectedBefore
      && c01InquiryStagedCohortIsCurrentForNativeOwner(staged)
      && installation.sceneBefore.matches(current: self)
      && installation.preservesExistingEntriesAndAppendsBirth()
  }

  /// Only the already-prevalidated private candidate applies this assignment.
  /// All allocation, fallible full-claim checks and currentness checks precede
  /// live adoption. This method neither creates nor rechecks native permission.
  mutating func commitValidatedC01InquiryNativeRegistry(
    _ installation: NativeC01InquiryNativeRegistryInstallation)
  {
    c01InquiryNativeRegistry = installation.after
  }
}

/// The actual current provider population, not a docking/placement capability.
/// Geometry preparation, protected-route construction and all query work are
/// separate mandatory steps before any native permit can exist.
fileprivate final class NativeC01InquiryNativeProviders: Sendable {
  struct Provider: Sendable {
    let station: StationInertialIdentity
    let body: SpaceBody
    let actor: ActorIdentity
    let source: NativeC01InquiryProtectedPortPolicy.Source
    let mesh: Mesh
    let docking: NativeStationGeometry.Port
    let launch: NativeStationGeometry.Port
    let poseInSystem: ShipPose
    let inertia: NativeStationInertia?
    let metresPerNativeUnit: Double
  }

  let epoch: UUID
  let physicalTime: Double
  let providers: [Provider]
  private let sceneBefore: NativeC01InquiryNativeSceneBefore

  private init(sceneBefore: NativeC01InquiryNativeSceneBefore, providers: [Provider]) {
    self.sceneBefore = sceneBefore; epoch = sceneBefore.epoch
    physicalTime = sceneBefore.flight.physicalTime; self.providers = providers
  }

  func matches(current game: borrowing Game) -> Bool { sceneBefore.matches(current: game) }

  /// Native scene consistency includes ALL expected live original stations.
  /// Merely finding the station used by the selected mission is insufficient.
  static func capture(game: borrowing Game, staged: NativeC01InquiryFixtureStagedCohort)
    -> NativeC01InquiryNativeProviders?
  {
    guard let before = NativeC01InquiryNativeSceneBefore.captureCurrentSource(
      game: game, staged: staged), !game.docked,
      let world = before.world,
      world.sceneIsConsistent(bodies: before.bodies, docked: false,
        mainStation: game.dockedAtMainStation, system: game.systemIdentity, flight: before.flight)
    else { return nil }
    var providers: [Provider] = []
    for body in before.bodies where body.energy > 0 && body.hull == .station {
      guard let actor = body.physical?.identity,
        actor.system == game.systemIdentity, actor.visit == before.flight.visit,
        !providers.contains(where: { $0.actor == actor || $0.body.id == body.id }),
        let station = game.stationInertialIdentity(for: body, at: before.flight.physicalTime)
      else { return nil }
      let provider: Provider
      switch station {
      case .main(let identity):
        guard body.id == 0, body.nativeStationIdentity == nil,
          case .living(let destination) = before.mainDestination,
          destination.identity == identity, destination.observation.actor == actor,
          destination.runtimeEpoch == before.epoch,
          destination.resource.energy == body.energy,
          let anchor = game.currentNativeMainStationAnchor(at: before.flight.physicalTime),
          anchor.identity == actor,
          let ship = ShipCatalogue.ship("SH028"), ship.name == "Lion Citadel",
          ship.catalogue.family == "lion-citadel", ship.nativeHull == .station,
          let design = ship.nativeDesign, design.valid,
          let port = ship.nativeDocking, port.valid,
          port == MainStationGeometry.docking,
          actualBody(body, matches: anchor.position, orientation: anchor.orientation,
            flight: before.flight)
        else { return nil }
        provider = .init(station: station, body: body, actor: actor, source: .main,
          mesh: design.rawMesh, docking: port, launch: port,
          poseInSystem: Game.modelPose(of: body, player: before.flight.pose),
          inertia: world.inertia(for: station), metresPerNativeUnit: 1)
      case .originalStation(let identity):
        guard let source = NativeStationSource.binding(for: identity),
          let record = world.ledger.records.first(where: { $0.identity == identity }),
          record.tombstone == nil,
          NativeStationSource.authentic(record, owner: world.ledger.world),
          record.binding == .init(actor: actor, bodyID: body.id),
          source.geometry.docking.valid, source.geometry.launch.valid,
          ["SH034", "SH102", "SH141"].contains(source.catalogueShipID),
          let position = world.currentPosition(for: station, at: before.flight.physicalTime),
          let orientation = world.currentOrientation(for: identity, at: before.flight.physicalTime),
          world.bodyRigidPoseIsConsistent(body, flight: before.flight)
        else { return nil }
        provider = .init(station: station, body: body, actor: actor,
          source: .original(source.site), mesh: source.geometry.mesh,
          docking: source.geometry.docking, launch: source.geometry.launch,
          poseInSystem: .init(position: position, orientation: orientation),
          inertia: world.inertia(for: station), metresPerNativeUnit: 1)
      }
      providers.append(provider)
    }
    switch before.mainDestination {
    case .living(let destination):
      guard providers.filter({ $0.station == .main(destination.identity) }).count == 1
      else { return nil }
    case .destroyed(let identity):
      guard !providers.contains(where: { $0.station == .main(identity) }) else { return nil }
    case .unavailable: return nil
    }
    // No foreign callback or publication occurs during collection. Retain a
    // current source window; this does not qualify any forward motion interval.
    guard before.matches(current: game) else { return nil }
    return .init(sceneBefore: before, providers: providers)
  }

  private static func actualBody(_ body: borrowing SpaceBody, matches position: Vector3,
    orientation: Basis3, flight: borrowing FlightSimulationState) -> Bool
  {
    guard position.finite, orientation.validRotation,
      (flight.pose.systemPoint(body.position) - position).length < 1e-5
    else { return false }
    for axis in [Vector3(1, 0, 0), .init(0, 1, 0), .init(0, 0, 1)] {
      guard (flight.pose.orientation.apply(body.orientation.apply(axis)) - orientation.apply(axis)).length < 1e-5
      else { return false }
    }
    return true
  }
}

/// Synchronous phase-local work owner. Reference identity prevents a value copy
/// from refilling spent allowances. It never crosses an actor/await boundary and
/// issues no native event, placement, source or material authority.
final class NativeC01InquiryNativeQueryWork {
  typealias G = NativeC01InquiryCurveGeometry
  typealias Solver = NativeC01InquiryCompoundValidatedCurve
  typealias P = NativeC01InquiryPreparationWork
  enum Failure: Error {
    case exhausted, foreignPreparation, invalidReport
    case nativePreparation(NativeC01InquiryPreparationWork.Failure)
    case curvePreparation(P.Failure, Solver.Work, P.Report)
  }

  /// Prepared by this exact work owner. Retaining the wrapper identifies the
  /// actual preparation; a caller-authored Solver.Work report cannot mint it.
  final class CurvePreparation {
    let curve: Solver.Curve
    let initial: StatePreparation
    let setupReport: P.Report
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate init(curve: Solver.Curve, initial: StatePreparation,
      setupReport: P.Report, owner: NativeC01InquiryNativeQueryWork)
    {
      self.curve = curve; self.initial = initial
      self.setupReport = setupReport; self.owner = owner
    }
  }

  /// Actual construction and later view-extraction records are distinct.
  /// This phase-local wrapper is never reconstructed from a UUID or raw Report.
  final class GeometryPreparation {
    let prepared: G.Prepared
    let constructionAndInitialViewReport: NativeC01InquiryPreparationWork.Report
    let latestViewReport: NativeC01InquiryPreparationWork.Report?
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate init(prepared: G.Prepared, owner: NativeC01InquiryNativeQueryWork,
      constructionAndInitialViewReport: NativeC01InquiryPreparationWork.Report,
      latestViewReport: NativeC01InquiryPreparationWork.Report?)
    {
      self.prepared = prepared; self.owner = owner
      self.constructionAndInitialViewReport = constructionAndInitialViewReport
      self.latestViewReport = latestViewReport
    }
  }

  /// Actual source construction records, not an accepted cut or native birth.
  final class SourcePreparation {
    let ancestor: NativeC01InquiryCompoundRepresentation
    let atlas: NativeC01InquiryCompoundMaterialAtlas
    let view: NativeC01InquiryCompoundMaterialAtlas.View
    let shapeReport: NativeC01InquiryPreparationWork.Report
    let atlasReport: NativeC01InquiryPreparationWork.Report
    let viewReport: NativeC01InquiryPreparationWork.Report
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate init(ancestor: NativeC01InquiryCompoundRepresentation,
      atlas: NativeC01InquiryCompoundMaterialAtlas,
      view: NativeC01InquiryCompoundMaterialAtlas.View,
      shapeReport: NativeC01InquiryPreparationWork.Report,
      atlasReport: NativeC01InquiryPreparationWork.Report,
      viewReport: NativeC01InquiryPreparationWork.Report,
      owner: NativeC01InquiryNativeQueryWork)
    {
      self.ancestor = ancestor; self.atlas = atlas; self.view = view
      self.shapeReport = shapeReport; self.atlasReport = atlasReport
      self.viewReport = viewReport; self.owner = owner
    }
  }

  final class StatePreparation {
    let state: Solver.State
    let source: SourcePreparation
    let reports: [P.Report]
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate init(state: Solver.State, source: SourcePreparation,
      reports: [P.Report], owner: NativeC01InquiryNativeQueryWork)
    {
      self.state = state; self.source = source
      self.reports = reports; self.owner = owner
    }
  }

  /// Authenticated input provenance and actual instantaneous math candidate.
  /// Full native world/lifetime/placement checks and publication remain separate.
  final class GameBirthPreparation {
    fileprivate let inputs: NativeC01InquiryNativeBirthInputs
    let seed: Solver.TranslatedBirthSeed
    /// Actual source anchor retained by THIS preparation. G3 must read this
    /// and seed from the same object; this is not a native clock receipt.
    var actualBirthPhysicalTime: Double { inputs.staged.context.physicalTime }

    /// Source-specific readonly check for the mathematical seed adapter. It
    /// grants no admitted fixture, accepted prefix, native time or Window.
    func matchesCurrentBirthSource(game: borrowing Game,
      workOwner: NativeC01InquiryNativeQueryWork) -> Bool
    {
      guard !workOwner.stopped, state.owner === workOwner,
        geometry.owner === workOwner, instantaneous.owner === workOwner,
        inputs.source.owner === workOwner, state.source === inputs.source,
        seed.materialView.atlas === inputs.source.atlas
      else { return false }
      return inputs.matches(current: game)
        && foreignPopulation.matchesCurrentSource(game: game, workOwner: workOwner)
    }

    let state: StatePreparation
    let geometry: GeometryPreparation
    let instantaneous: InstantaneousPreparation
    let foreignPopulation: ForeignPopulationPreparation
    fileprivate init(inputs: NativeC01InquiryNativeBirthInputs,
      seed: Solver.TranslatedBirthSeed, state: StatePreparation,
      geometry: GeometryPreparation, instantaneous: InstantaneousPreparation,
      foreignPopulation: ForeignPopulationPreparation)
    {
      self.inputs = inputs; self.seed = seed; self.state = state
      self.geometry = geometry; self.instantaneous = instantaneous
      self.foreignPopulation = foreignPopulation
    }
  }

  /// Actual source operation result. This is not an accepted native event,
  /// prefix, clock, cut, body admission or Window permission.
  final class GameBornInitialSeedPreparation {
    let seed: Solver.ConstrainedInitialSeed
    let report: P.Report
    fileprivate let birth: GameBirthPreparation
    fileprivate let owner: NativeC01InquiryNativeQueryWork

    fileprivate init(seed: Solver.ConstrainedInitialSeed, report: P.Report,
      birth: GameBirthPreparation, owner: NativeC01InquiryNativeQueryWork)
    {
      self.seed = seed; self.report = report; self.birth = birth; self.owner = owner
    }
  }

  /// Actual current native collision population, not a motion/clearance receipt.
  /// Celestial spheres remain spheres; this phase never substitutes enclosing boxes.
  final class ForeignPopulationPreparation {
    struct Body {
      let sourceIndex: Int
      let bodyID: Int
      let actor: ActorIdentity
      let pose: ShipPose
      let geometry: GeometryPreparation
      let mesh: Mesh
    }
    struct Celestial {
      let sourceIndex: Int
      let kind: CelestialKind
      let centre: Vector3
      let radius: Double
    }
    let player: ActorIdentity
    let playerPose: ShipPose
    let playerGeometry: GeometryPreparation
    let bodies: [Body]
    let celestials: [Celestial]
    fileprivate let source: NativeC01InquiryNativeSceneBefore
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate let playerMesh: Mesh

    fileprivate init(player: ActorIdentity, playerPose: ShipPose,
      playerGeometry: GeometryPreparation, bodies: [Body], celestials: [Celestial],
      source: NativeC01InquiryNativeSceneBefore, owner: NativeC01InquiryNativeQueryWork,
      playerMesh: Mesh)
    {
      self.player = player; self.playerPose = playerPose; self.playerGeometry = playerGeometry
      self.bodies = bodies; self.celestials = celestials; self.source = source; self.owner = owner
      self.playerMesh = playerMesh
    }

    /// Existing full source snapshot comparison remains an unmetered deep read.
    /// It cannot prove motion between snapshots or qualify an accepted interval.
    func matchesCurrentSource(game: borrowing Game,
      workOwner: NativeC01InquiryNativeQueryWork) -> Bool
    {
      guard owner === workOwner, !workOwner.stopped, source.matches(current: game) else { return false }
      let currentPlayerMesh = game.commander.playerMesh
      guard currentPlayerMesh.vertices == playerMesh.vertices,
        currentPlayerMesh.faces == playerMesh.faces else { return false }
      for body in bodies {
        let current = game.gameplayMesh(for: source.bodies[body.sourceIndex])
        guard current.vertices == body.mesh.vertices, current.faces == body.mesh.faces else { return false }
      }
      return true
    }
  }

  /// Capture the actual player, every live body and every celestial. Geometry
  /// construction and the explicit inspections below spend this owner's residual
  /// allowance. Source mesh lookup and deep snapshot checks are not yet metered.
  /// No registry entry, clock, accepted prefix, motion or clearance is issued.
  func prepareGameForeignPopulation(game: borrowing Game,
    maximumTriangles: Int) throws -> ForeignPopulationPreparation
  {
    try requirePreparationPhase()
    do {
      try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
      guard maximumTriangles > 0,
        let source = NativeC01InquiryNativeSceneBefore.captureInstalledInspection(game: game),
        let player = source.flight.player, source.context.player.identity == player,
        source.flight.valid, (1..<1_000_000_000).contains(source.nextBodyID),
        source.flight.system == source.context.system, source.flight.visit == source.context.visit,
        player.system == source.context.system, player.visit == source.context.visit, player.entity == 0,
        let anchors = source.flight.anchors, anchors.system == source.context.system,
        anchors.station.identity.system == source.context.system,
        anchors.station.identity.visit == source.context.visit, anchors.station.identity.entity == 1,
        source.flight.pose.position.finite, source.flight.pose.orientation.validRotation,
        game.energy.isFinite, game.energy > 0
      else { throw P.Failure.invalidSource }
      let playerMesh = game.commander.playerMesh
      let playerGeometry = try prepareGeometry(mesh: playerMesh,
        maximumTriangles: maximumTriangles)
      var bodies: [ForeignPopulationPreparation.Body] = []
      for index in source.bodies.indices {
        try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
        let body = source.bodies[index]
        guard body.energy.isFinite, (0..<source.nextBodyID).contains(body.id) else {
          throw P.Failure.invalidSource
        }
        if let actor = body.physical?.identity {
          guard actor.system == source.context.system, actor.visit == source.context.visit,
            actor.entity > 0, actor.entity < source.flight.nextActor
          else { throw P.Failure.invalidSource }
          if body.id == 0 {
            guard body.hull == .station, actor == anchors.station.identity else {
              throw P.Failure.invalidSource
            }
          } else {
            guard actor.entity != 1 else { throw P.Failure.invalidSource }
          }
        }
        if body.id == 0, body.hull != .station { throw P.Failure.invalidSource }
        // Duplicate addresses are invalid even when one retained body is dead.
        for prior in source.bodies[..<index].indices {
          try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
          guard source.bodies[prior].id != body.id else { throw P.Failure.invalidSource }
          if let actor = body.physical?.identity {
            guard source.bodies[prior].physical?.identity != actor else { throw P.Failure.invalidSource }
          }
        }
        // Dead bodies remain in the source snapshot but have no live surface.
        guard body.energy > 0 else { continue }
        try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
        guard let physical = body.physical,
          physical.identity != player,
          physical.identity.system == source.context.system,
          physical.identity.visit == source.context.visit,
          physical.velocity.finite, physical.angularVelocity.finite
        else { throw P.Failure.invalidSource }
        try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
        let pose = Game.modelPose(of: body, player: source.flight.pose)
        guard pose.position.finite, pose.orientation.validRotation else {
          throw P.Failure.invalidSource
        }
        let mesh = game.gameplayMesh(for: body)
        let geometry = try prepareGeometry(mesh: mesh,
          maximumTriangles: maximumTriangles)
        bodies.append(.init(sourceIndex: index, bodyID: body.id, actor: physical.identity,
          pose: pose, geometry: geometry, mesh: mesh))
      }
      var celestials: [ForeignPopulationPreparation.Celestial] = []
      for index in source.celestials.indices {
        try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
        let celestial = source.celestials[index]
        guard celestial.position.finite, celestial.radius.isFinite, celestial.radius > 0 else {
          throw P.Failure.invalidSource
        }
        let centre = source.flight.pose.systemPoint(celestial.position)
        guard centre.finite else { throw P.Failure.invalidSource }
        celestials.append(.init(sourceIndex: index, kind: celestial.kind,
          centre: centre, radius: celestial.radius))
      }
      guard source.matches(current: game) else { throw P.Failure.invalidSource }
      let result = ForeignPopulationPreparation(player: player, playerPose: source.flight.pose,
        playerGeometry: playerGeometry, bodies: bodies, celestials: celestials,
        source: source, owner: self, playerMesh: playerMesh)
      guard result.matchesCurrentSource(game: game, workOwner: self) else { throw P.Failure.invalidSource }
      return result
    } catch {
      stop()
      throw error
    }
  }

  /// One actual native shadow vertex per source vertex, with the same stable
  /// material key and face topology. This is source DATA, not correspondence.
  final class MaterialShadowPreparation {
    struct Vertex: Sendable {
      let nativeIndex: Int
      let materialVertexID: Int
      let world: Vector3
    }
    struct Face: Sendable {
      let nativeIndex: Int
      let materialFacetID: NativeC01InquiryCompoundMaterialAtlas.FacetID
      let vertices: [Int]
      // Authentic proposed address only. Actual admission/currentness is separate.
      let stagedBinding: NativeC01InquiryFixtureBinding
    }
    struct Triangle: Sendable {
      let nativeIndex: Int
      let sourceFace: Int
      // Indices into the SAME world vertex buffer, not transformed copies.
      let vertices: [Int]
      let unresolvedSupport: Bool
    }
    final class Data: Sendable {
      let vertices: [Vertex]
      let faces: [Face]
      let triangles: [Triangle]

      fileprivate init(vertices: [Vertex], faces: [Face], triangles: [Triangle]) {
        self.vertices = vertices; self.faces = faces; self.triangles = triangles
      }
    }
    let data: Data
    let report: P.Report
    fileprivate let birth: GameBirthPreparation
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate let geometry: GeometryPreparation

    fileprivate init(data: Data, report: P.Report, birth: GameBirthPreparation,
      owner: NativeC01InquiryNativeQueryWork)
    {
      self.data = data; self.report = report; self.birth = birth; self.owner = owner
      geometry = birth.geometry
    }

    func matches(current game: borrowing Game, birth: GameBirthPreparation,
      owner: NativeC01InquiryNativeQueryWork) -> Bool
    {
      self.birth === birth && self.owner === owner && geometry === birth.geometry
        && birth.matchesCurrentBirthSource(game: game, workOwner: owner)
    }
  }

  /// Actual shared-shadow source construction, not a caller's map or pose.
  /// Every source point is transformed once; all facets reference those indices.
  /// Native physics/render/raycast adoption is still absent and cannot be inferred.
  func prepareGameBirthMaterialShadow(game: borrowing Game,
    birth: GameBirthPreparation) throws -> MaterialShadowPreparation
  {
    try requirePreparationPhase()
    do {
      guard birth.matchesCurrentBirthSource(game: game, workOwner: self) else {
        throw P.Failure.invalidSource
      }
      var work = try openGeometryWork()
      let outcome: P.Outcome<MaterialShadowPreparation.Data> = P.perform(work: &work) { meter in
        try meter.records(4, .metadata)
        // A currently claimed compound cannot fall back to independent body
        // geometry while preparing another source. Registry lookup is unmetered.
        for index in game.bodies.indices {
          try meter.records(1, .metadata)
          switch game.c01InquiryGeometryClaimDisposition(for: game.bodies[index]) {
          case .ordinary: break
          case .refused: throw P.Failure.invalidSource
          }
        }
        let view = birth.state.source.view
        let prepared = birth.geometry.prepared
        let pose = birth.instantaneous.source.referencePose
        guard birth.instantaneous.geometryPreparation === birth.geometry,
          birth.instantaneous.statePreparation === birth.state,
          prepared.sourceVertices.count == view.vertexIDs.count,
          prepared.sourceVertices.count == view.meshInMaterialFrame.vertices.count,
          prepared.sourceFaces.count == view.facetIDs.count,
          prepared.sourceFaces.count == view.meshInMaterialFrame.faces.count,
          pose.position.finite, pose.orientation.validRotation
        else { throw P.Failure.invalidSource }
        var vertices: [MaterialShadowPreparation.Vertex] = []
        for index in prepared.sourceVertices.indices {
          try meter.records(1, .metadata)
          let key = view.vertexIDs[index]
          let local = prepared.sourceVertices[index]
          guard view.atlas.vertices.indices.contains(key), local.finite,
            local == view.atlas.vertices[key], local == view.meshInMaterialFrame.vertices[index]
          else { throw P.Failure.invalidSource }
          for previous in vertices {
            try meter.records(1, .metadata)
            guard previous.materialVertexID != key else { throw P.Failure.invalidSource }
          }
          let point = pose.systemPoint(local)
          guard point.finite else { throw P.Failure.invalidSource }
          vertices.append(.init(nativeIndex: index, materialVertexID: key, world: point))
        }
        try meter.records(2, .metadata)
        let staged = birth.inputs.staged
        guard staged.partRecipes.count == 4,
          staged.bindings.count == staged.partRecipes.count else { throw P.Failure.invalidSource }
        var faces: [MaterialShadowPreparation.Face] = []
        for index in prepared.sourceFaces.indices {
          try meter.records(1, .metadata)
          let face = prepared.sourceFaces[index]
          let original = view.meshInMaterialFrame.faces[index]
          guard face.count == original.count, face.count >= 3 else { throw P.Failure.invalidSource }
          for offset in face.indices {
            try meter.records(1, .metadata)
            guard vertices.indices.contains(face[offset]), face[offset] == original[offset] else {
              throw P.Failure.invalidSource
            }
          }
          let facet = view.facetIDs[index]
          var binding: NativeC01InquiryFixtureBinding?
          for recipeIndex in staged.partRecipes.indices {
            try meter.records(1, .metadata)
            if staged.partRecipes[recipeIndex].kind == facet.role {
              guard binding == nil else { throw P.Failure.invalidSource }
              binding = staged.bindings[recipeIndex]
            }
          }
          guard let binding else { throw P.Failure.invalidSource }
          faces.append(.init(nativeIndex: index, materialFacetID: facet, vertices: face,
            stagedBinding: binding))
        }
        let triangles = try self.routeNativeMaterialTriangles(prepared: prepared,
          vertices: vertices, faces: faces, meter: meter)
        return .init(vertices: vertices, faces: faces, triangles: triangles)
      }
      let (data, report) = try adoptSourceOutcome(outcome, actualWork: work)
      guard birth.matchesCurrentBirthSource(game: game, workOwner: self) else {
        throw P.Failure.invalidSource
      }
      return .init(data: data, report: report, birth: birth, owner: self)
    } catch {
      stop()
      throw error
    }
  }

  /// Route actual prepared primitives without transforming a source point.
  /// Only genuine source operations in this file supply the live meter.
  fileprivate func routeNativeMaterialTriangles(prepared: G.Prepared,
    vertices: [MaterialShadowPreparation.Vertex], faces: [MaterialShadowPreparation.Face],
    meter: P.Meter) throws -> [MaterialShadowPreparation.Triangle]
  {
    try meter.records(1, .metadata)
    var triangles: [MaterialShadowPreparation.Triangle] = []
    for triangleIndex in prepared.triangles.indices {
      try meter.records(1, .metadata)
      let triangle = prepared.triangles[triangleIndex]
      guard triangle.vertices.count == 3, faces.indices.contains(triangle.sourceFace)
      else { throw P.Failure.invalidSource }
      try meter.records(1, .metadata)
      let face = faces[triangle.sourceFace]
      guard face.nativeIndex == triangle.sourceFace else { throw P.Failure.invalidSource }
      var triangleVertices: [Int] = []
      for pointIndex in triangle.vertices.indices {
        try meter.records(1, .metadata)
        let point = triangle.vertices[pointIndex]
        var sourceIndex: Int?
        for faceOffset in face.vertices.indices {
          try meter.records(2, .metadata)
          let candidateIndex = face.vertices[faceOffset]
          guard prepared.sourceVertices.indices.contains(candidateIndex),
            vertices.indices.contains(candidateIndex) else { throw P.Failure.invalidSource }
          let candidate = prepared.sourceVertices[candidateIndex]
          if candidate.x.bitPattern == point.x.bitPattern,
            candidate.y.bitPattern == point.y.bitPattern,
            candidate.z.bitPattern == point.z.bitPattern
          {
            guard sourceIndex == nil else { throw P.Failure.invalidSource }
            sourceIndex = candidateIndex
          }
        }
        guard let sourceIndex else { throw P.Failure.invalidSource }
        for previousIndex in triangleVertices.indices {
          try meter.records(1, .metadata)
          guard triangleVertices[previousIndex] != sourceIndex else { throw P.Failure.invalidSource }
        }
        triangleVertices.append(sourceIndex)
      }
      triangles.append(.init(nativeIndex: triangleIndex, sourceFace: triangle.sourceFace,
        vertices: triangleVertices, unresolvedSupport: triangle.unresolvedSupport))
    }
    return triangles
  }

  /// Complete instantaneous query traversal over this actual population and
  /// both real protected ports. It is not an accepted native birth or interval.
  fileprivate final class BirthClearancePreparation {
    enum Subject {
      case player, body(Int), celestial(Int), dockingPort(Int), launchPort(Int)
    }
    struct Pair {
      let subject: Subject
      let lowerBound: Double
      let requiredMargin: Solver.Interval
      let charge: GeometryCharge
    }
    let pairs: [Pair]
    fileprivate let birth: GameBirthPreparation
    fileprivate let ports: ProtectedPortsPreparation
    fileprivate let material: NativeC01InquiryNativeMaterial
    fileprivate let owner: NativeC01InquiryNativeQueryWork

    fileprivate init(pairs: [Pair], birth: GameBirthPreparation,
      ports: ProtectedPortsPreparation, material: NativeC01InquiryNativeMaterial,
      owner: NativeC01InquiryNativeQueryWork)
    {
      self.pairs = pairs; self.birth = birth; self.ports = ports
      self.material = material; self.owner = owner
    }

    func matches(current game: borrowing Game, birth: GameBirthPreparation,
      material: NativeC01InquiryNativeMaterial, owner: NativeC01InquiryNativeQueryWork) -> Bool
    {
      self.owner === owner && self.birth === birth && self.material === material
        && birth.matchesCurrentBirthSource(game: game, workOwner: owner)
        && ports.matches(current: game)
    }
  }

  /// Real source-to-query composition. All queries use the SAME residual work;
  /// no owner, allowance, selected-object subset or foreign curve is supplied.
  /// The native hull already contains WORLD points, so its query pose is identity.
  /// This is conditional pointwise source clearance, not installed geometry.
  /// Deep source/mesh checks and retained output storage are still unmetered.
  fileprivate func prepareGameBirthClearance(game: borrowing Game,
    birth: GameBirthPreparation, shadow: MaterialShadowPreparation,
    material: NativeC01InquiryNativeMaterial) throws -> BirthClearancePreparation
  {
    try requirePreparationPhase()
    do {
      try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
      guard shadow.matches(current: game, birth: birth, owner: self),
        material.matches(game: game, birth: birth, shadow: shadow) else {
        throw P.Failure.invalidSource
      }
      let population = birth.foreignPopulation
      let ports = try prepareGameProtectedPorts(game: game, staged: birth.inputs.staged)
      var pairs: [BirthClearancePreparation.Pair] = []
      pairs.append(try initialBirthSolidSeparation(birth, material: material,
        geometry: population.playerGeometry, pose: population.playerPose, subject: .player))
      for index in population.bodies.indices {
        try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
        let body = population.bodies[index]
        pairs.append(try initialBirthSolidSeparation(birth, material: material,
          geometry: body.geometry, pose: body.pose, subject: .body(body.sourceIndex)))
      }
      for index in population.celestials.indices {
        try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
        let sphere = population.celestials[index]
        pairs.append(try initialBirthSphereSeparation(birth, material: material,
          centre: sphere.centre, radius: sphere.radius, subject: .celestial(sphere.sourceIndex)))
      }
      for index in ports.providers.indices {
        try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
        let provider = ports.providers[index]
        pairs.append(try initialBirthSolidSeparation(birth, material: material,
          geometry: provider.docking.geometry, pose: provider.actual.poseInSystem,
          subject: .dockingPort(index)))
        pairs.append(try initialBirthSolidSeparation(birth, material: material,
          geometry: provider.launch.geometry, pose: provider.actual.poseInSystem,
          subject: .launchPort(index)))
      }
      guard shadow.matches(current: game, birth: birth, owner: self),
        material.matches(game: game, birth: birth, shadow: shadow),
        ports.matches(current: game) else { throw P.Failure.invalidSource }
      return .init(pairs: pairs, birth: birth, ports: ports, material: material, owner: self)
    } catch {
      stop()
      throw error
    }
  }

  private func initialBirthSolidSeparation(_ birth: GameBirthPreparation,
    material: NativeC01InquiryNativeMaterial, geometry: GeometryPreparation, pose: ShipPose, subject: BirthClearancePreparation.Subject
  ) throws -> BirthClearancePreparation.Pair {
    try requirePreparationPhase()
    try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
    guard birth.instantaneous.owner === self, geometry.owner === self else {
      stop(); throw Failure.foreignPreparation
    }
    var work = try openGeometryWork()
    let separation: Double
    do {
      separation = try HullSweepSafety.c01InitialSolidSeparation(
        material.nativeWorldPrepared.hull, pose: .init(),
        target: geometry.prepared.hull, pose: pose, work: &work)
    } catch {
      try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
      stop()
      throw error
    }
    try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
    let margin = Solver.Interval.point(birth.instantaneous.deviation)
    guard margin.valid, separation.isFinite, separation > margin.upper else {
      stop(); throw G.Failure.initialSolidUnproven
    }
    return .init(subject: subject, lowerBound: separation, requiredMargin: margin,
      charge: .init(queries: work.queries, triangles: work.triangles, nodes: work.nodes))
  }

  private func initialBirthSphereSeparation(_ birth: GameBirthPreparation,
    material: NativeC01InquiryNativeMaterial, centre: Vector3, radius: Double, subject: BirthClearancePreparation.Subject
  ) throws -> BirthClearancePreparation.Pair {
    try requirePreparationPhase()
    try debit(queries: 0, triangles: 1, nodes: 0, attempts: 0, cells: 0)
    guard birth.instantaneous.owner === self else { stop(); throw Failure.foreignPreparation }
    var work = try openGeometryWork()
    let separation: Double
    do {
      separation = try HullSweepSafety.c01InitialSphereSeparation(
        material.nativeWorldPrepared.hull, pose: .init(),
        centre: centre, radius: radius, work: &work)
    } catch {
      try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
      stop()
      throw error
    }
    try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
    let margin = Solver.Interval.point(birth.instantaneous.deviation)
    guard margin.valid, separation.isFinite, separation > margin.upper else {
      stop(); throw G.Failure.initialSolidUnproven
    }
    return .init(subject: subject, lowerBound: separation, requiredMargin: margin,
      charge: .init(queries: work.queries, triangles: work.triangles, nodes: work.nodes))
  }

  struct GeometryCharge {
    let queries: Int
    let triangles: Int
    let nodes: Int
  }

  /// A bounded current mathematical input, not genuine source/time/lifetime or
  /// placement authority. It has no curve and asserts no attained interval.
  final class InstantaneousPreparation {
    let source: G.InstantaneousSource
    let statePreparation: StatePreparation
    let geometryPreparation: GeometryPreparation
    let deviation: Double
    let charge: GeometryCharge
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate init(source: G.InstantaneousSource, state: StatePreparation,
      geometry: GeometryPreparation, deviation: Double, charge: GeometryCharge,
      owner: NativeC01InquiryNativeQueryWork)
    {
      self.source = source; statePreparation = state; geometryPreparation = geometry
      self.deviation = deviation; self.charge = charge; self.owner = owner
    }
  }

  /// Conditional pairwise geometry only. Complete live world/provider/current
  /// material identity and native source permission are not represented here.
  final class InstantaneousSeparation {
    let first: InstantaneousPreparation
    let second: InstantaneousPreparation
    let referenceSeparationLowerBound: Double
    let requiredMargin: Solver.Interval
    let charge: GeometryCharge
    fileprivate init(first: InstantaneousPreparation, second: InstantaneousPreparation,
      lowerBound: Double, requiredMargin: Solver.Interval, charge: GeometryCharge)
    {
      self.first = first; self.second = second
      referenceSeparationLowerBound = lowerBound; self.requiredMargin = requiredMargin
      self.charge = charge
    }
  }

  /// Uncalled factory until actual native source/time/fullworld proof exists.
  /// A later interval retains this exact current material/geometry binding.
  final class PreparedSource {
    let source: G.Source
    fileprivate let curvePreparation: CurvePreparation
    private init(initial: InstantaneousPreparation, curvePreparation: CurvePreparation) throws {
      guard initial.owner === curvePreparation.owner,
        initial.statePreparation === curvePreparation.initial
      else { throw Failure.foreignPreparation }
      self.curvePreparation = curvePreparation
      source = .init(curve: curvePreparation.curve, prepared: initial.source.prepared,
        referencePose: initial.source.referencePose, materialView: initial.source.materialView)
    }
  }

  enum Foreign {
    case ordinary(G.Foreign)
    case compound(instance: UUID, source: PreparedSource, clearance: Double, purpose: G.Purpose)
  }

  /// Diagnostic observations only. These counters never authorize native work.
  struct TerminalBirthInspectionObservation: Sendable {
    let reservedBudget: HullSweepBudget
    let observedBudget: HullSweepBudget
    let queries: Int
    let triangles: Int
    let nodes: Int
    let readExposure: Bool
    let invalidAccess: Bool
  }

  enum TerminalBirthInspectionRefusal: Sendable {
    case foreignOwner, unregisteredSession, invalidAccess, changedBudget, invalidCounters
  }

  enum TerminalBirthInspectionFinish: Sendable {
    case settled(TerminalBirthInspectionObservation)
    case invalid(TerminalBirthInspectionRefusal, TerminalBirthInspectionObservation)
    case alreadyFinished(TerminalBirthInspectionObservation)
  }

  struct TerminalBirthInspectionEvidence: Sendable {
    let firstFinalization: TerminalBirthInspectionFinish?
    let firstRejectedFinish: TerminalBirthInspectionFinish?
    let invalidPostFinalizationObservation: TerminalBirthInspectionObservation?
  }

  /// Trusted synchronous actor-local diagnostic storage, never a native permit.
  /// The owner retains only its identity/header, so this strong owner is acyclic.
  final class TerminalBirthInspection {
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    private let reservedBudget: HullSweepBudget
    private var storage: G.Work
    private var readExposure = false
    private var invalidAccess = false

    fileprivate init(owner: NativeC01InquiryNativeQueryWork, budget: HullSweepBudget) throws {
      self.owner = owner
      reservedBudget = budget
      storage = try G.Work(budget)
    }

    /// Only direct synchronous inout use is admissible. A read can expose a copy
    /// and invalidates settlement; inout itself cannot prevent caller resets.
    /// Invalid/post-finish access records failure and retires the owner, while
    /// yielding the original storage rather than inventing a replacement ledger.
    var work: G.Work {
      _read {
        owner.noteTerminalBirthInspectionAccess(self, read: true)
        defer { owner.retainPostFinalizationObservation(self) }
        yield storage
      }
      _modify {
        owner.noteTerminalBirthInspectionAccess(self, read: false)
        defer { owner.retainPostFinalizationObservation(self) }
        yield &storage
      }
    }

    var observation: TerminalBirthInspectionObservation { snapshot() }

    fileprivate func snapshot() -> TerminalBirthInspectionObservation {
      .init(reservedBudget: reservedBudget, observedBudget: storage.budget,
        queries: storage.queries, triangles: storage.triangles, nodes: storage.nodes,
        readExposure: readExposure, invalidAccess: invalidAccess)
    }

    fileprivate func recordInvalidAccess(read: Bool) {
      readExposure = readExposure || read
      invalidAccess = true
    }
  }

  private struct TerminalBirthReservation {
    let identity: ObjectIdentifier
    let budget: HullSweepBudget
    var firstFinalization: TerminalBirthInspectionFinish?
    var invalidPostFinalizationObservation: TerminalBirthInspectionObservation?
  }

  private var terminalBirthReservation: TerminalBirthReservation?
  private var firstRejectedTerminalBirthFinish: TerminalBirthInspectionFinish?

  var terminalBirthInspectionEvidence: TerminalBirthInspectionEvidence? {
    guard terminalBirthReservation != nil || firstRejectedTerminalBirthFinish != nil else { return nil }
    return .init(firstFinalization: terminalBirthReservation?.firstFinalization,
      firstRejectedFinish: firstRejectedTerminalBirthFinish,
      invalidPostFinalizationObservation:
        terminalBirthReservation?.invalidPostFinalizationObservation)
  }

  /// Reserve genuine residual capacity exclusively without charging unused work.
  /// No other preparation may use even the unreserved remainder during inspection.
  /// There is one successful opening per phase; all terminal paths retire it.
  func openTerminalBirthInspection(limit: HullSweepBudget? = nil) throws -> TerminalBirthInspection {
    try requirePreparationPhase()
    let budget = limit ?? geometry
    guard budget.distanceQueries > 0, budget.distanceQueries <= geometry.distanceQueries,
      budget.triangleTests > 0, budget.triangleTests <= geometry.triangleTests,
      budget.nodeVisits > 0, budget.nodeVisits <= geometry.nodeVisits,
      (0...20).contains(budget.subdivisionDepth),
      budget.subdivisionDepth <= geometry.subdivisionDepth
    else { stop(); throw Failure.exhausted }
    do {
      // Construct the sole Work directly in its final session storage. No local
      // Work copy, report fee, default allowance or fallible work after publication.
      let inspection = try TerminalBirthInspection(owner: self, budget: budget)
      terminalBirthReservation = .init(identity: ObjectIdentifier(inspection), budget: budget)
      return inspection
    } catch {
      stop()
      throw error
    }
  }

  /// The caller installs exactly one defer immediately after opening. It passes
  /// the original oracle &inspection.work, then finishes here even on throw.
  /// Deep currentness/assertions/header bookkeeping are not fully metered.
  func finishTerminalBirthInspection(_ inspection: TerminalBirthInspection)
    -> TerminalBirthInspectionFinish
  {
    defer { stop() }
    let observed = inspection.snapshot()
    guard inspection.owner === self else {
      return retainRejectedTerminalBirthFinish(.foreignOwner, observed)
    }
    guard let reserved = terminalBirthReservation,
      reserved.identity == ObjectIdentifier(inspection)
    else { return retainRejectedTerminalBirthFinish(.unregisteredSession, observed) }
    if reserved.firstFinalization != nil { return .alreadyFinished(observed) }

    let result: TerminalBirthInspectionFinish
    if observed.invalidAccess || observed.readExposure {
      result = .invalid(.invalidAccess, observed)
    } else if !Self.sameTerminalBudget(observed.reservedBudget, reserved.budget)
      || !Self.sameTerminalBudget(observed.observedBudget, reserved.budget)
      || reserved.budget.distanceQueries > geometry.distanceQueries
      || reserved.budget.triangleTests > geometry.triangleTests
      || reserved.budget.nodeVisits > geometry.nodeVisits
      || reserved.budget.subdivisionDepth > geometry.subdivisionDepth
    {
      result = .invalid(.changedBudget, observed)
    } else if observed.queries < 0 || observed.queries > reserved.budget.distanceQueries
      || observed.queries > geometry.distanceQueries
      || observed.triangles < 0 || observed.triangles > reserved.budget.triangleTests
      || observed.triangles > geometry.triangleTests
      || observed.nodes < 0 || observed.nodes > reserved.budget.nodeVisits
      || observed.nodes > geometry.nodeVisits
    {
      result = .invalid(.invalidCounters, observed)
    } else {
      // All axes were checked BEFORE any subtraction. This dedicated terminal
      // route can pay retained partial work after stop, but cannot resume work.
      geometry.distanceQueries -= observed.queries
      geometry.triangleTests -= observed.triangles
      geometry.nodeVisits -= observed.nodes
      result = .settled(observed)
    }
    terminalBirthReservation?.firstFinalization = result
    return result
  }

  private func retainRejectedTerminalBirthFinish(_ reason: TerminalBirthInspectionRefusal,
    _ observed: TerminalBirthInspectionObservation) -> TerminalBirthInspectionFinish
  {
    let result = TerminalBirthInspectionFinish.invalid(reason, observed)
    if firstRejectedTerminalBirthFinish == nil { firstRejectedTerminalBirthFinish = result }
    return result
  }

  private func noteTerminalBirthInspectionAccess(_ inspection: TerminalBirthInspection, read: Bool) {
    guard inspection.owner === self else { stop(); return }
    if !read, !stopped, let reserved = terminalBirthReservation,
      reserved.identity == ObjectIdentifier(inspection), reserved.firstFinalization == nil
    { return }
    inspection.recordInvalidAccess(read: read)
    stop()
  }

  private func retainPostFinalizationObservation(_ inspection: TerminalBirthInspection) {
    guard inspection.owner === self, let reserved = terminalBirthReservation,
      reserved.identity == ObjectIdentifier(inspection), reserved.firstFinalization != nil
    else { return }
    // Preserve the FIRST paid/invalid observation; later misuse cannot rewrite
    // it or receive a second debit. Retain the distinct failed later observation.
    terminalBirthReservation?.invalidPostFinalizationObservation = inspection.snapshot()
  }

  private static func sameTerminalBudget(_ first: HullSweepBudget, _ second: HullSweepBudget) -> Bool {
    first.distanceQueries == second.distanceQueries && first.triangleTests == second.triangleTests
      && first.nodeVisits == second.nodeVisits && first.subdivisionDepth == second.subdivisionDepth
  }

  private func requirePreparationPhase() throws {
    guard !stopped, terminalBirthReservation == nil else { stop(); throw Failure.exhausted }
  }

  private var geometry: HullSweepBudget
  private var ode: Solver.WorkBudget
  private var stopped = false

  /// Readonly bookkeeping DATA. A copied value cannot change or refill owner work.
  var remainingGeometryBudget: HullSweepBudget { geometry }

  init(geometry: HullSweepBudget, ode: Solver.WorkBudget) throws {
    guard geometry.distanceQueries > 0, geometry.triangleTests > 0,
      geometry.nodeVisits > 0, (0...20).contains(geometry.subdivisionDepth),
      ode.cellAttempts > 0, ode.cellAttempts < Int.max,
      ode.retainedCells > 0, ode.retainedCells < Int.max,
      ode.subdivisionDepth >= 0, ode.subdivisionDepth < Int.max
    else { throw Failure.exhausted }
    self.geometry = geometry; self.ode = ode
  }

  /// Build the real NEW source recipe from current Game-owned host motion.
  /// The existing placement screen/proposal is retained; it is not the later
  /// complete native solid/provider/material permission proof.
  fileprivate func prepareGameBirthInputs(game: borrowing Game) throws -> NativeC01InquiryNativeBirthInputs {
    try requirePreparationPhase()
    do {
      let intent = try game.prepareC01InquiryFixtureBirthIntent()
      guard let host = NativeC01InquiryNativeBirthHost.capture(game: game, intent: intent) else {
        throw P.Failure.invalidSource
      }
      let placement = try game.prepareC01InquiryFixturePlacementCandidate(intent)
      let model = try game.prepareC01InquiryInitialModel(intent)
      let source = try prepareAncestorSource()
      var work = try openGeometryWork()
      let outcome: P.Outcome<[NativeC01InquiryFixturePhysicalAdmission.Part]> = P.perform(work: &work) { meter in
        var parts: [NativeC01InquiryFixturePhysicalAdmission.Part] = []
        for mass in source.ancestor.mass.parts {
          try meter.records(1, .metadata)
          let descriptor = NativeC01InquiryFixtureGeometry.descriptor(for: mass.kind)
          let budget = NativeC01InquiryFixtureGeometry.physicalBudget(for: mass.kind)
          guard mass.massKilograms == budget.massKilograms else { throw P.Failure.invalidSource }
          // Actual recipe fields and fixed pose construction are prepaid. The
          // nominal actor hull is the existing source prototype's projection
          // slot; it supplies no mesh, mass, equipment or native authority.
          try meter.records(8, .metadata)
          parts.append(.init(kind: mass.kind, hull: .sidewinder,
            pose: .init(position: placement.frame.systemPoint(descriptor.centreNative),
              orientation: placement.frame.orientation), mesh: descriptor.mesh,
            velocity: host.worldTranslation, angularVelocity: .init(0, 0, 0),
            massKilograms: mass.massKilograms, maximumEnergy: budget.energy))
        }
        return parts
      }
      let (parts, _) = try adoptSourceOutcome(outcome, actualWork: work)
      guard host.matches(current: game) else { throw P.Failure.invalidSource }
      let proposal = try game.prepareC01InquiryFixtureStageProposal(placement,
        initialModel: model, parts: parts, population: .mission)
      let staged = try game.prepareC01InquiryFixtureStagedCohort(proposal)
      var inputWork = try openGeometryWork()
      // Inputs own a non-Sendable phase owner, so keep this meter synchronous
      // rather than returning them through the Sendable math Outcome wrapper.
      try inputWork.node()
      let meter = P.Meter(work: inputWork)
      let inputs: NativeC01InquiryNativeBirthInputs
      do {
        guard let captured = try NativeC01InquiryNativeBirthInputs.capture(game: game,
          staged: staged, source: source, host: host, meter: meter), captured.matches(current: game)
        else { throw P.Failure.invalidSource }
        inputs = captured
      } catch {
        try debit(queries: meter.work.queries, triangles: meter.work.triangles,
          nodes: meter.work.nodes, attempts: 0, cells: 0)
        throw error
      }
      try debit(queries: meter.work.queries, triangles: meter.work.triangles,
        nodes: meter.work.nodes, attempts: 0, cells: 0)
      return inputs
    } catch {
      stop()
      throw error
    }
  }

  /// The real Game-owned path accepts no caller quaternion, COM or momentum.
  /// It returns a source-bound state candidate, never a native birth permission.
  func prepareGameBornState(game: borrowing Game) throws -> GameBirthPreparation {
    try requirePreparationPhase()
    do {
      let inputs = try prepareGameBirthInputs(game: game)
      // Exact G3 API returns one frame report and at most one state report.
      // Reserve those bounded caller header inspections before the operation.
      try debit(queries: 0, triangles: 2, nodes: 0, attempts: 0, cells: 0)
      var work = try openGeometryWork()
      let outcome = Solver.prepareTranslatedBirth(sourceFrame: inputs.staged.sourceFrame,
        recipes: inputs.staged.partRecipes, materialView: inputs.source.view,
        prescribedWorldTranslation: inputs.host.worldTranslation,
        metricRevision: NativeC01InquiryFixtureGeometry.metricRevision,
        metresPerWorldUnit: NativeC01InquiryFixtureGeometry.metresPerWorldUnit, work: &work)
      let reports: [P.Report]
      switch outcome {
      case .prepared(_, let actual): reports = actual
      case .refused(_, let actual): reports = actual
      }
      // This is the same mutated residual ledger, not a fee inferred from a
      // report or a second debit for each ordered stage report.
      try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
      guard (1...2).contains(reports.count) else { throw Failure.invalidReport }
      var queries = 0, triangles = 0, nodes = 0
      for report in reports {
        let q = queries.addingReportingOverflow(report.queries)
        let t = triangles.addingReportingOverflow(report.triangles)
        let n = nodes.addingReportingOverflow(report.nodes)
        guard report.queries >= 0, report.triangles >= 0, report.nodes >= 0,
          !q.overflow, !t.overflow, !n.overflow else { throw Failure.invalidReport }
        queries = q.partialValue; triangles = t.partialValue; nodes = n.partialValue
      }
      guard queries == work.queries, triangles == work.triangles, nodes == work.nodes else {
        throw Failure.invalidReport
      }
      let seed: Solver.TranslatedBirthSeed
      switch outcome {
      case .prepared(let actual, _): seed = actual
      case .refused(let failure, _): throw Failure.nativePreparation(failure)
      }
      guard inputs.matches(current: game), seed.materialView.atlas === inputs.source.atlas else {
        throw P.Failure.invalidSource
      }
      let state = StatePreparation(state: seed.state, source: inputs.source,
        reports: reports, owner: self)
      let geometry = try prepareGeometry(mesh: inputs.source.view.meshInMaterialFrame,
        maximumTriangles: 512)
      guard geometry.prepared.hull.isClosed else { throw G.Failure.initialSolidUnproven }
      let instantaneous = try prepareInstantaneousState(state, geometry: geometry,
        referencePose: seed.nativeCOMShadow)
      guard inputs.matches(current: game) else { throw P.Failure.invalidSource }
      let foreignPopulation = try prepareGameForeignPopulation(game: game, maximumTriangles: 512)
      guard inputs.matches(current: game) else { throw P.Failure.invalidSource }
      return .init(inputs: inputs, seed: seed, state: state,
        geometry: geometry, instantaneous: instantaneous, foreignPopulation: foreignPopulation)
    } catch {
      stop()
      throw error
    }
  }

  /// Derive the source seed through the existing SAME-preparation adapter,
  /// using this phase's actual remaining work. It never accepts a caller seed,
  /// time, State, Boundary or report as source/payment. Deep currentness and
  /// program/source storage are still not fully metered by this operation.
  func prepareGameBornInitialSeed(game: borrowing Game,
    birth: GameBirthPreparation) throws -> GameBornInitialSeedPreparation
  {
    try requirePreparationPhase()
    var work = try openGeometryWork()
    let outcome = Solver.prepareConstrainedInitialSeed(birth,
      game: game, workOwner: self, work: &work)
    let (seed, report) = try adoptSourceOutcome(outcome, actualWork: work)
    return .init(seed: seed, report: report, birth: birth, owner: self)
  }

  /// Temporary provider geometry DATA. No entry/permit/lifetime is created.
  fileprivate final class ProtectedPortsPreparation {
    struct Port {
      let volume: NativeC01InquiryProtectedPortPolicy.Volume
      let constructionReport: P.Report
      let geometry: GeometryPreparation
    }
    struct Provider {
      let actual: NativeC01InquiryNativeProviders.Provider
      let docking: Port
      let launch: Port
    }
    let captured: NativeC01InquiryNativeProviders
    let providers: [Provider]
    private let owner: NativeC01InquiryNativeQueryWork
    fileprivate init(captured: NativeC01InquiryNativeProviders, providers: [Provider],
      owner: NativeC01InquiryNativeQueryWork)
    {
      self.captured = captured; self.providers = providers; self.owner = owner
    }
    func matches(current game: borrowing Game) -> Bool { captured.matches(current: game) }
  }

  /// Capture actual live providers, then construct BOTH port volumes and native
  /// hulls against this same allowance. Capture's deep source/world validation
  /// remains unmetered; this method does not claim complete native query work.
  fileprivate func prepareGameProtectedPorts(game: borrowing Game,
    staged: NativeC01InquiryFixtureStagedCohort) throws -> ProtectedPortsPreparation
  {
    try requirePreparationPhase()
    do {
      guard let captured = NativeC01InquiryNativeProviders.capture(game: game, staged: staged)
      else { throw P.Failure.invalidSource }
      var prepared: [ProtectedPortsPreparation.Provider] = []
      for provider in captured.providers {
        var work = try openGeometryWork()
        let inspection: P.Outcome<Bool> = P.perform(work: &work) { meter in
          // Actual provider metadata inspection, not payment for earlier capture.
          try meter.records(1, .metadata)
          guard provider.metresPerNativeUnit == 1,
            provider.poseInSystem.position.finite,
            provider.poseInSystem.orientation.validRotation
          else { throw P.Failure.invalidSource }
          return true
        }
        _ = try adoptSourceOutcome(inspection, actualWork: work)
        guard captured.matches(current: game) else { throw P.Failure.invalidSource }
        let docking = try prepareProtectedPort(source: provider.source, port: provider.docking)
        guard captured.matches(current: game) else { throw P.Failure.invalidSource }
        let launch = try prepareProtectedPort(source: provider.source, port: provider.launch)
        guard captured.matches(current: game) else { throw P.Failure.invalidSource }
        // Even equal source ports receive their own actual preparation. No
        // inferred cached native-ID or static catalogue-volume substitute.
        var appendWork = try openGeometryWork()
        let append: P.Outcome<Bool> = P.perform(work: &appendWork) { meter in
          try meter.records(1, .metadata)
          prepared.append(.init(actual: provider, docking: docking, launch: launch))
          return true
        }
        _ = try adoptSourceOutcome(append, actualWork: appendWork)
      }
      guard captured.matches(current: game) else { throw P.Failure.invalidSource }
      return .init(captured: captured, providers: prepared, owner: self)
    } catch {
      stop()
      throw error
    }
  }

  private func prepareProtectedPort(source: NativeC01InquiryProtectedPortPolicy.Source,
    port: NativeStationGeometry.Port) throws -> ProtectedPortsPreparation.Port
  {
    try requirePreparationPhase()
    var work = try openGeometryWork()
    let outcome = NativeC01InquiryProtectedPortPolicy.prepareVolume(for: source,
      port: port, work: &work)
    let (volume, report) = try adoptSourceOutcome(outcome, actualWork: work)
    let geometry = try prepareGeometry(mesh: volume.meshInStationFrame, maximumTriangles: 12)
    guard geometry.prepared.hull.isClosed else { throw G.Failure.initialSolidUnproven }
    return .init(volume: volume, constructionReport: report, geometry: geometry)
  }

  fileprivate final class PassiveFieldPreparation {
    let conditional: NativeC01InquiryPassiveFixtureForceLaw.ConditionalField
    let components: [NativeC01InquiryCutContactSet.Component]
    let reports: [P.Report]
    private let producer: NativeC01InquiryNativePassiveProducerCandidate
    fileprivate init(conditional: NativeC01InquiryPassiveFixtureForceLaw.ConditionalField,
      components: [NativeC01InquiryCutContactSet.Component], reports: [P.Report],
      producer: NativeC01InquiryNativePassiveProducerCandidate)
    {
      self.conditional = conditional; self.components = components
      self.reports = reports; self.producer = producer
    }
    func matches(current game: borrowing Game) -> Bool { producer.matches(current: game) }
  }

  /// Construct the actual native WORLD hull from the original shared buffer.
  /// This is preinstallation source preparation, never an accepted frame.
  fileprivate func prepareGameBirthNativeMaterial(game: borrowing Game,
    birth: GameBirthPreparation, shadow: MaterialShadowPreparation)
    throws -> NativeC01InquiryNativeMaterial
  {
    try requirePreparationPhase()
    do {
      guard shadow.matches(current: game, birth: birth, owner: self) else {
        throw P.Failure.invalidSource
      }
      var copyWork = try openGeometryWork()
      let copied: P.Outcome<Mesh> = P.perform(work: &copyWork) { meter in
        try meter.records(2, .metadata)
        var vertices: [Vector3] = []
        for index in shadow.data.vertices.indices {
          try meter.records(1, .metadata)
          vertices.append(shadow.data.vertices[index].world)
        }
        var faces: [[Int]] = []
        for index in shadow.data.faces.indices {
          try meter.records(1, .metadata)
          let face = shadow.data.faces[index]
          var indices: [Int] = []
          for offset in face.vertices.indices {
            try meter.records(1, .metadata)
            indices.append(face.vertices[offset])
          }
          faces.append(indices)
        }
        return .init(vertices: vertices, faces: faces, preserveWinding: true)
      }
      let (mesh, _) = try adoptSourceOutcome(copied, actualWork: copyWork)
      let nativeWorld = try prepareGeometry(mesh: mesh, maximumTriangles: 512)
      guard shadow.matches(current: game, birth: birth, owner: self) else {
        throw P.Failure.invalidSource
      }
      var materialWork = try openGeometryWork()
      let outcome: P.Outcome<NativeC01InquiryNativeMaterial> = P.perform(work: &materialWork) { meter in
        guard let material = try NativeC01InquiryNativeMaterial.capture(game: game,
          birth: birth, shadow: shadow, nativeWorld: nativeWorld, owner: self, meter: meter)
        else { throw P.Failure.invalidSource }
        return material
      }
      let (material, _) = try adoptSourceOutcome(outcome, actualWork: materialWork)
      guard shadow.matches(current: game, birth: birth, owner: self) else {
        throw P.Failure.invalidSource
      }
      return material
    } catch {
      stop()
      throw error
    }
  }

  /// Compare this actual PREINSTALL source, without issuing a cut, current
  /// native frame or accepted interval. All work is settled once, even on throw.
  fileprivate func prepareGameBirthInitialCorrespondence(game: borrowing Game,
    birth: GameBirthPreparation, initial: GameBornInitialSeedPreparation,
    shadow: MaterialShadowPreparation, material: NativeC01InquiryNativeMaterial
  ) throws -> NativeC01InquiryNativeInitialCorrespondence {
    try requirePreparationPhase()
    do {
      var work = try openGeometryWork()
      let result: Result<NativeC01InquiryNativeInitialCorrespondence, any Error>
      do {
        result = .success(try NativeC01InquiryNativeInitialCorrespondence.prepare(game: game,
          birth: birth, initial: initial, shadow: shadow, material: material,
          owner: self, work: &work))
      } catch { result = .failure(error) }
      // Adopt the actual mutated counters, including a partial failed prefix.
      // No report-derived fee, second seed adapter, reset or refill is used.
      try debit(queries: work.queries, triangles: work.triangles,
        nodes: work.nodes, attempts: 0, cells: 0)
      let actual = try result.get()
      guard actual.matches(game: game, birth: birth, initialSeed: initial.seed,
        shadow: shadow, material: material, owner: self)
      else { throw P.Failure.invalidSource }
      return actual
    } catch {
      stop()
      throw error
    }
  }

  fileprivate func preparePassiveProducerCandidate(game: borrowing Game,
    birth: GameBirthPreparation) throws -> NativeC01InquiryNativePassiveProducerCandidate
  {
    try requirePreparationPhase()
    let initial = try prepareGameBornInitialSeed(game: game, birth: birth)
    let materialShadow = try prepareGameBirthMaterialShadow(game: game, birth: birth)
    let material = try prepareGameBirthNativeMaterial(game: game, birth: birth, shadow: materialShadow)
    let initialCorrespondence = try prepareGameBirthInitialCorrespondence(game: game,
      birth: birth, initial: initial, shadow: materialShadow, material: material)
    let initialClearance = try prepareGameBirthClearance(game: game, birth: birth,
      shadow: materialShadow, material: material)
    guard let candidate = NativeC01InquiryNativePassiveProducerCandidate.capture(
      game: game, birth: birth, initial: initial, initialClearance: initialClearance,
      materialShadow: materialShadow, material: material,
      initialCorrespondence: initialCorrespondence, owner: self)
    else { stop(); throw P.Failure.invalidSource }
    return candidate
  }

  /// Prepare the explicit source-law inputs for the actual complete B x T.
  /// This is not a finite native window: sole coupled integration, full event
  /// clipping, material/cut authority and all native publication hooks are still
  /// required. Deep birth/current-source checks remain unmetered as in capture.
  fileprivate func preparePassiveFieldCandidate(game: borrowing Game,
    producer: NativeC01InquiryNativePassiveProducerCandidate,
    components: [NativeC01InquiryCutContactSet.Component],
    absoluteTimeRange: Solver.Interval) throws -> PassiveFieldPreparation
  {
    try requirePreparationPhase()
    guard producer.owner === self else { stop(); throw Failure.foreignPreparation }
    do {
      guard producer.matches(current: game),
        let birth = producer.currentBirth else { throw P.Failure.invalidSource }
      var work = try openGeometryWork()
      let domain: P.Outcome<[Solver.Interval]> = P.perform(work: &work) { meter in
        try meter.records(2, .metadata)
        guard (1...4).contains(components.count), absoluteTimeRange.valid,
          absoluteTimeRange.lower >= birth.inputs.staged.context.physicalTime
        else { throw P.Failure.invalidSource }
        var roles: [NativeC01InquiryFixtureGeometry.Part] = []
        var packed: [Solver.Interval] = []
        for index in components.indices {
          try meter.records(1, .metadata)
          let component = components[index]
          guard component.view.atlas === birth.inputs.source.atlas,
            (1...4).contains(component.state.representation.mass.parts.count)
          else { throw P.Failure.invalidSource }
          // These fields are copied in the EXACT 835/e931 order. The G3
          // consumer must still match actual representations/views/materials.
          try meter.records(13, .metadata)
          guard component.state.quaternion.components.count == 4 else {
            throw P.Failure.invalidSource
          }
          packed.append(contentsOf: component.state.quaternion.components)
          packed.append(contentsOf: component.state.centreOfMass.values)
          packed.append(contentsOf: component.state.linearMomentum.values)
          packed.append(contentsOf: component.state.worldAngularMomentum.values)
          for partIndex in component.state.representation.mass.parts.indices {
            try meter.records(1, .metadata)
            let part = component.state.representation.mass.parts[partIndex]
            var actualMass: Double?
            for sourceIndex in birth.inputs.source.ancestor.mass.parts.indices {
              try meter.records(1, .metadata)
              let source = birth.inputs.source.ancestor.mass.parts[sourceIndex]
              if source.kind == part.kind { actualMass = source.massKilograms }
            }
            guard actualMass == part.massKilograms else { throw P.Failure.invalidSource }
            for prior in roles {
              try meter.records(1, .metadata)
              guard prior != part.kind else { throw P.Failure.invalidSource }
            }
            try meter.records(1, .metadata)
            roles.append(part.kind)
          }
        }
        guard roles.count == 4 else { throw P.Failure.invalidSource }
        return packed
      }
      let (packed, domainReport) = try adoptSourceOutcome(domain, actualWork: work)
      guard producer.matches(current: game) else { throw P.Failure.invalidSource }
      var fieldWork = try openGeometryWork()
      let field = NativeC01InquiryPassiveFixtureForceLaw.prepareConditionalField(
        prescription: producer.prescription, stateDomain: packed,
        absoluteTimeRange: absoluteTimeRange, work: &fieldWork)
      let (conditional, fieldReport) = try adoptSourceOutcome(field, actualWork: fieldWork)
      guard producer.matches(current: game) else { throw P.Failure.invalidSource }
      return .init(conditional: conditional, components: components,
        reports: [domainReport, fieldReport], producer: producer)
    } catch {
      producer.invalidate(before: .preparationRefused)
      stop()
      throw error
    }
  }

  /// Source event hooks must call this BEFORE mutation or writer execution.
  /// No shared/native event hook is installed by this owned component.
  fileprivate func invalidatePassiveProducer(
    _ producer: NativeC01InquiryNativePassiveProducerCandidate,
    before event: NativeC01InquiryNativePassiveProducerCandidate.Invalidation) {
    guard producer.owner === self else { stop(); return }
    producer.invalidate(before: event)
    stop()
  }

  /// Source inspection only. This retains no prebirth candidate and exposes
  /// no finite native window, body admission or elapsed-time authority.
  final class InstalledPassiveSourcePreparation {
    let report: P.Report
    fileprivate let opening: NativeC01InquiryInstalledPassiveSourceOpening
    fileprivate let owner: NativeC01InquiryNativeQueryWork
    fileprivate init(opening: NativeC01InquiryInstalledPassiveSourceOpening,
      report: P.Report, owner: NativeC01InquiryNativeQueryWork)
    {
      self.opening = opening; self.report = report; self.owner = owner
    }
    func matches(current game: borrowing Game) -> Bool { opening.matches(current: game) }
  }

  func prepareInstalledPassiveSource(game: borrowing Game) throws -> InstalledPassiveSourcePreparation {
    try requirePreparationPhase()
    do {
      var work = try openGeometryWork()
      var captured: NativeC01InquiryInstalledPassiveSourceOpening?
      let inspected: P.Outcome<Bool> = P.perform(work: &work) { meter in
        captured = try NativeC01InquiryInstalledPassiveSourceOpening.capture(game: game, meter: meter)
        guard captured != nil else { throw P.Failure.invalidSource }
        return true
      }
      let (_, report) = try adoptSourceOutcome(inspected, actualWork: work)
      guard let captured, captured.matches(current: game) else { throw P.Failure.invalidSource }
      return .init(opening: captured, report: report, owner: self)
    } catch {
      stop()
      throw error
    }
  }

  /// The caller must place this before the actual event/write, never after it.
  /// Only an ephemeral query object is revoked. No shared Game leaf is mutated.
  func invalidateInstalledPassiveSource(_ source: InstalledPassiveSourcePreparation) {
    guard source.owner === self else { stop(); return }
    source.opening.invalidateBeforeSourceEventOrPublication()
    stop()
  }

  /// Exact callback-free field inputs and e931 result for this supplied domain.
  /// This carries conditional source/math data, not a native time/event window.
  final class InstalledPassiveFieldPreparation {
    let domain: Solver.ConstrainedCellDomain
    let external: NativeC01InquiryPassiveFixtureForceLaw.ConditionalField
    let field: NativeC01InquiryCutContactSet.MovingFieldDifferential
    let sourceReports: [P.Report]
    let fieldCharge: GeometryCharge
    private let source: InstalledPassiveSourcePreparation
    fileprivate init(domain: Solver.ConstrainedCellDomain,
      external: NativeC01InquiryPassiveFixtureForceLaw.ConditionalField,
      field: NativeC01InquiryCutContactSet.MovingFieldDifferential,
      reports: [P.Report], charge: GeometryCharge, source: InstalledPassiveSourcePreparation)
    {
      self.domain = domain; self.external = external; self.field = field
      sourceReports = reports; fieldCharge = charge; self.source = source
    }
    func matches(current game: borrowing Game) -> Bool { source.matches(current: game) }
  }

  /// Actual paid e931 range refusal, not an accepted cell or source event.
  final class InstalledPassiveFieldRangeRefusal {
    let domain: Solver.ConstrainedCellDomain
    let external: NativeC01InquiryPassiveFixtureForceLaw.ConditionalField
    let sourceReports: [P.Report]
    let fieldCharge: GeometryCharge
    private let source: InstalledPassiveSourcePreparation
    fileprivate init(domain: Solver.ConstrainedCellDomain,
      external: NativeC01InquiryPassiveFixtureForceLaw.ConditionalField,
      reports: [P.Report], charge: GeometryCharge, source: InstalledPassiveSourcePreparation)
    {
      self.domain = domain; self.external = external
      sourceReports = reports; fieldCharge = charge; self.source = source
    }
    func matches(current game: borrowing Game) -> Bool { source.matches(current: game) }
  }

  enum InstalledPassiveFieldOutcome {
    case prepared(InstalledPassiveFieldPreparation)
    case unresolvedMathematicalRange(InstalledPassiveFieldRangeRefusal)
  }

  /// G3's controller must count its attempt BEFORE preparing this domain and
  /// calling this field bridge. We debit only actual source/field work here;
  /// no prior attempt/preparation or native elapsed time is invented.
  func prepareInstalledPassiveField(game: borrowing Game,
    source: InstalledPassiveSourcePreparation, domain: Solver.ConstrainedCellDomain
  ) throws -> InstalledPassiveFieldOutcome {
    try requirePreparationPhase()
    guard source.owner === self else { stop(); throw Failure.foreignPreparation }
    do {
      guard source.matches(current: game) else { throw P.Failure.invalidSource }
      var sourceWork = try openGeometryWork()
      let inspected: P.Outcome<Bool> = P.perform(work: &sourceWork) { meter in
        try meter.records(3, .metadata)
        let original = domain.start.sourceBoundary.components
        let entries = source.opening.entries
        guard original.count == entries.count, (1...4).contains(original.count),
          domain.components.count == original.count,
          // The source anchor stays at actual birth, including continuations.
          // Native current-prefix provenance is a separate, unissued premise.
          domain.start.anchorTime == source.opening.program.actualBirthPhysicalTime,
          domain.absoluteTimeRange.lower >= source.opening.model.physicalTime,
          source.opening.program.lawRevision == NativeC01InquiryPassiveFixtureForceLaw.revision
        else { throw P.Failure.invalidSource }
        // SAME genuine birth seed, not matching-looking state/time scalars.
        // Accepted native prefix/history remains a separate unissued premise.
        try meter.records(1, .metadata)
        guard domain.start.initialSeed === source.opening.program.initialSeed
        else { throw P.Failure.invalidSource }
        for index in original.indices {
          try meter.records(1, .metadata)
          let component = original[index], entry = entries[index]
          guard component.view.atlas === entry.material.atlas,
            try NativeC01InquiryNativeMaterialViewInspection.matches(component.view,
              shape: component.state.representation, meter: meter)
          else { throw P.Failure.invalidSource }
          try meter.records(component.view.vertexIDs.count, .metadata)
          try meter.records(component.view.facetIDs.count, .metadata)
          guard component.view.vertexIDs == entry.material.view.vertexIDs,
            component.view.facetIDs == entry.material.view.facetIDs else {
            throw P.Failure.invalidSource
          }
          try meter.records(13, .metadata)
          guard component.state.quaternion.components == entry.state.quaternion.components,
            component.state.centreOfMass.values == entry.state.centreOfMass.values,
            component.state.linearMomentum.values == entry.state.linearMomentum.values,
            component.state.worldAngularMomentum.values == entry.state.worldAngularMomentum.values
          else { throw P.Failure.invalidSource }
          // The evolving domain keeps the same component source/view. G3's
          // private Domain constructor binds its exact full13 enclosure.
          try meter.records(domain.components[index].view.vertexIDs.count, .metadata)
          try meter.records(domain.components[index].view.facetIDs.count, .metadata)
          guard domain.components[index].view.atlas === component.view.atlas,
            domain.components[index].view.vertexIDs == component.view.vertexIDs,
            domain.components[index].view.facetIDs == component.view.facetIDs
          else { throw P.Failure.invalidSource }
        }
        return true
      }
      let (_, sourceReport) = try adoptSourceOutcome(inspected, actualWork: sourceWork)
      guard source.matches(current: game) else { throw P.Failure.invalidSource }
      var lawWork = try openGeometryWork()
      let law = NativeC01InquiryPassiveFixtureForceLaw.prepareConditionalField(
        prescription: .coupledPassiveCOM, stateDomain: domain.enclosure,
        absoluteTimeRange: domain.absoluteTimeRange, work: &lawWork)
      let (external, lawReport) = try adoptSourceOutcome(law, actualWork: lawWork)
      guard source.matches(current: game) else { throw P.Failure.invalidSource }
      var work = try openGeometryWork()
      let result: Result<NativeC01InquiryCutContactSet.MovingFieldOutcome, any Error>
      do {
        let operation = try NativeC01InquiryCutContactSet.prepareMovingOperator(
          domain.start.sourceBoundary, current: domain.components,
          externalRanges: external.externalRanges, work: &work)
        let differential = try NativeC01InquiryCutContactSet.prepareMovingDifferential(operation,
          physicalTimeRange: domain.absoluteTimeRange,
          externalJacobian: external.externalJacobian, work: &work)
        result = .success(NativeC01InquiryCutContactSet.prepareMovingFieldDifferential(differential,
          activeBasis: domain.start.activeBasis, work: &work))
      } catch { result = .failure(error) }
      // This exact mutated temporary includes partial failed G3 operations.
      // Debit ONCE, distinct from the two earlier source operation reports.
      let charge = GeometryCharge(queries: work.queries, triangles: work.triangles, nodes: work.nodes)
      try debit(queries: work.queries, triangles: work.triangles,
        nodes: work.nodes, attempts: 0, cells: 0)
      let actual = try result.get()
      guard source.matches(current: game) else { throw P.Failure.invalidSource }
      switch actual {
      case .bounds(let field):
        return .prepared(.init(domain: domain, external: external, field: field,
          reports: [sourceReport, lawReport], charge: charge, source: source))
      case .unresolved:
        // The same source remains current. Its paid mathematical range could
        // not be enclosed; only the real controller may choose refinement.
        return .unresolvedMathematicalRange(.init(domain: domain, external: external,
          reports: [sourceReport, lawReport], charge: charge, source: source))
      case .workExhausted:
        throw G.Failure.workBudgetExceeded
      }
    } catch {
      source.opening.invalidateBeforeSourceEventOrPublication()
      stop()
      throw error
    }
  }

  func prepareAncestorSource() throws -> SourcePreparation {
    try requirePreparationPhase()
    let parts = NativeC01InquiryFixtureGeometry.Part.allCases
    var work = try openGeometryWork()
    let shapeOutcome = NativeC01InquiryCompoundRepresentation.prepare(parts: parts, work: &work)
    let (shape, shapeReport) = try adoptSourceOutcome(shapeOutcome, actualWork: work)
    work = try openGeometryWork()
    let atlasOutcome = NativeC01InquiryCompoundMaterialAtlas.prepare(ancestor: shape, work: &work)
    let (atlas, atlasReport) = try adoptSourceOutcome(atlasOutcome, actualWork: work)
    work = try openGeometryWork()
    let viewOutcome = atlas.prepareView(parts: parts, work: &work)
    let (view, viewReport) = try adoptSourceOutcome(viewOutcome, actualWork: work)
    guard view.atlas === atlas else { stop(); throw Failure.foreignPreparation }
    return .init(ancestor: shape, atlas: atlas, view: view, shapeReport: shapeReport,
      atlasReport: atlasReport, viewReport: viewReport, owner: self)
  }

  /// Selecting an already catalogued component pays its NEW actual view work;
  /// it never rebuilds material points or grants an accepted cut/lifetime.
  func prepareComponentView(_ previous: SourcePreparation,
    parts: [NativeC01InquiryFixtureGeometry.Part]) throws -> SourcePreparation
  {
    try requirePreparationPhase()
    guard previous.owner === self else { stop(); throw Failure.foreignPreparation }
    var work = try openGeometryWork()
    let outcome = previous.atlas.prepareView(parts: parts, work: &work)
    let (view, report) = try adoptSourceOutcome(outcome, actualWork: work)
    guard view.atlas === previous.atlas else { stop(); throw Failure.foreignPreparation }
    return .init(ancestor: previous.ancestor, atlas: previous.atlas, view: view,
      shapeReport: previous.shapeReport, atlasReport: previous.atlasReport,
      viewReport: report, owner: self)
  }

  private func adoptSourceOutcome<Value: Sendable>(
    _ outcome: NativeC01InquiryPreparationWork.Outcome<Value>, actualWork: G.Work
  ) throws -> (Value, NativeC01InquiryPreparationWork.Report) {
    try requirePreparationPhase()
    let report: NativeC01InquiryPreparationWork.Report
    switch outcome {
    case .prepared(_, let actual): report = actual
    case .refused(_, let actual): report = actual
    }
    guard report.queries == actualWork.queries, report.triangles == actualWork.triangles,
      report.nodes == actualWork.nodes else { stop(); throw Failure.invalidReport }
    try debit(queries: actualWork.queries, triangles: actualWork.triangles,
      nodes: actualWork.nodes, attempts: 0, cells: 0)
    switch outcome {
    case .prepared(let value, _): return (value, report)
    case .refused(let failure, _): stop(); throw Failure.nativePreparation(failure)
    }
  }

  /// Actual C01 construction and metadata extraction, not the old unmetered
  /// constructor or a fee inferred from a matching geometry UUID.
  func prepareGeometry(mesh: Mesh, maximumTriangles: Int) throws -> GeometryPreparation {
    try requirePreparationPhase()
    var work = try openGeometryWork()
    let outcome = HullSweepSafety.c01PrepareGeometry(mesh: mesh,
      maximumTriangles: maximumTriangles, work: &work)
    return try adoptGeometry(outcome, actualWork: work, previous: nil)
  }

  /// A view-only call consumes a real construction from THIS phase owner.
  /// Cross-phase cached geometry requires its genuine lifetime/construction
  /// owner join; this method cannot accept an arbitrary cached PreparedHull.
  func prepareGeometryView(_ previous: GeometryPreparation) throws -> GeometryPreparation {
    try requirePreparationPhase()
    guard previous.owner === self else { stop(); throw Failure.foreignPreparation }
    var work = try openGeometryWork()
    let outcome = HullSweepSafety.c01PrepareGeometryView(previous.prepared.hull, work: &work)
    return try adoptGeometry(outcome, actualWork: work, previous: previous)
  }

  private func openGeometryWork() throws -> G.Work {
    try requirePreparationPhase()
    do { return try G.Work(geometry) }
    catch { stop(); throw error }
  }

  private func adoptGeometry(_ outcome: NativeC01InquiryPreparationWork.Outcome<G.Prepared>,
    actualWork: G.Work, previous: GeometryPreparation?) throws -> GeometryPreparation
  {
    try requirePreparationPhase()
    let report: NativeC01InquiryPreparationWork.Report
    switch outcome {
    case .prepared(_, let actual): report = actual
    case .refused(_, let actual): report = actual
    }
    // The bridge mutates this temporary residual ledger. Debit its REAL
    // returned consumption once into the owner, never both its report and its
    // writeback. It began with zero counters and the current residual budget.
    guard report.queries == actualWork.queries, report.triangles == actualWork.triangles,
      report.nodes == actualWork.nodes else { stop(); throw Failure.invalidReport }
    try debit(queries: actualWork.queries, triangles: actualWork.triangles,
      nodes: actualWork.nodes, attempts: 0, cells: 0)
    switch outcome {
    case .prepared(let prepared, _):
      return .init(prepared: prepared, owner: self,
        constructionAndInitialViewReport: previous?.constructionAndInitialViewReport ?? report,
        latestViewReport: previous == nil ? nil : report)
    case .refused(let failure, _):
      stop()
      throw Failure.nativePreparation(failure)
    }
  }

  /// Source DATA until the native producer joins the genuine current birth
  /// frame, initial angular/momentum source and complete current-world proof.
  func prepareInitialState(source: SourcePreparation, rawQuaternion: [Double],
    centreOfMass: Vector3, linearMomentum: Vector3, worldAngularMomentum: Vector3
  ) throws -> StatePreparation {
    try requirePreparationPhase()
    guard source.owner === self, source.view.atlas === source.atlas else {
      stop(); throw Failure.foreignPreparation
    }
    var work = try openGeometryWork()
    let outcome = Solver.prepareSeed(representation: source.view.representation,
      rawQuaternion: rawQuaternion, centreOfMass: centreOfMass,
      linearMomentum: linearMomentum, worldAngularMomentum: worldAngularMomentum, work: &work)
    let (state, report) = try adoptSourceOutcome(outcome, actualWork: work)
    return .init(state: state, source: source, reports: [report], owner: self)
  }

  /// The mathematical transfer prepares both selected State and View together.
  /// No caller-selected component or returned report grants an accepted cut.
  func prepareComponentState(_ parent: StatePreparation,
    parts: [NativeC01InquiryFixtureGeometry.Part]) throws -> StatePreparation
  {
    try requirePreparationPhase()
    guard parent.owner === self, parent.source.owner === self else {
      stop(); throw Failure.foreignPreparation
    }
    var work = try openGeometryWork()
    let outcome = parent.source.atlas.prepareTransfer(parent.state,
      view: parent.source.view, parts: parts, work: &work)
    let (transfer, report) = try adoptSourceOutcome(outcome, actualWork: work)
    guard transfer.componentView.atlas === parent.source.atlas else {
      stop(); throw Failure.foreignPreparation
    }
    // The combined report pays actual view selection AND state-transfer setup.
    // Ancestor/atlas construction remains the original separately paid work.
    let source = SourcePreparation(ancestor: parent.source.ancestor, atlas: parent.source.atlas,
      view: transfer.componentView, shapeReport: parent.source.shapeReport,
      atlasReport: parent.source.atlasReport, viewReport: report, owner: self)
    return .init(state: transfer.componentState, source: source, reports: [report], owner: self)
  }

  func prepareInstantaneousState(_ state: StatePreparation,
    geometry: GeometryPreparation, referencePose: ShipPose) throws -> InstantaneousPreparation
  {
    try requirePreparationPhase()
    guard state.owner === self, geometry.owner === self, state.source.owner === self,
      state.source.view.atlas === state.source.atlas
    else { stop(); throw Failure.foreignPreparation }
    let source = G.InstantaneousSource(state: state.state, prepared: geometry.prepared,
      referencePose: referencePose, materialView: state.source.view)
    var work = try openGeometryWork()
    let deviation: Double
    do {
      deviation = try NativeC01InquiryCurveGeometryConsumer.initialMaterialDeviation(source, work: &work)
    } catch {
      try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
      stop()
      throw error
    }
    try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
    guard deviation.isFinite, deviation >= 0 else { stop(); throw Failure.invalidReport }
    return .init(source: source, state: state, geometry: geometry, deviation: deviation,
      charge: .init(queries: work.queries, triangles: work.triangles, nodes: work.nodes), owner: self)
  }

  /// Actual closed-solid primitive and BOTH actual material deviations share
  /// this owner's residual work. The result alone cannot admit a body or event.
  func initialSolidSeparation(_ first: InstantaneousPreparation,
    from second: InstantaneousPreparation, clearance: Double = 0) throws -> InstantaneousSeparation
  {
    try requirePreparationPhase()
    guard first.owner === self, second.owner === self,
      clearance.isFinite, clearance >= 0
    else { stop(); throw Failure.foreignPreparation }
    let margin = Solver.Interval.point(first.deviation)
      + Solver.Interval.point(second.deviation) + Solver.Interval.point(clearance)
    guard margin.valid else { stop(); throw Failure.invalidReport }
    var work = try openGeometryWork()
    let separation: Double
    do {
      separation = try HullSweepSafety.c01InitialSolidSeparation(first.source.prepared.hull,
        pose: first.source.referencePose, target: second.source.prepared.hull,
        pose: second.source.referencePose, work: &work)
    } catch {
      try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
      stop()
      throw error
    }
    try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes, attempts: 0, cells: 0)
    guard separation.isFinite, separation > margin.upper else {
      stop(); throw G.Failure.initialSolidUnproven
    }
    return .init(first: first, second: second, lowerBound: separation, requiredMargin: margin,
      charge: .init(queries: work.queries, triangles: work.triangles, nodes: work.nodes))
  }

  /// Every real initial/remainder/foreign interval uses residual ODE AND setup
  /// work. This method does not make a proposed interval an attained state.
  func prepareCurve(_ initial: StatePreparation, duration: Double,
    maximumCellDuration: Double? = nil) throws -> CurvePreparation
  {
    try requirePreparationPhase()
    guard initial.owner === self else { stop(); throw Failure.foreignPreparation }
    var work = try openGeometryWork()
    let outcome = Solver.prepareMeasured(initial.state, duration: duration, budget: ode,
      maximumCellDuration: maximumCellDuration ?? duration, work: &work)
    let report: P.Report
    let actualODE: Solver.Work
    switch outcome {
    case .prepared(let curve, let actual): report = actual; actualODE = curve.work
    case .refused(_, let partial, let actual): report = actual; actualODE = partial
    }
    guard report.queries == work.queries, report.triangles == work.triangles,
      report.nodes == work.nodes else { stop(); throw Failure.invalidReport }
    try debit(queries: work.queries, triangles: work.triangles, nodes: work.nodes,
      attempts: actualODE.cellAttempts, cells: actualODE.retainedCells)
    switch outcome {
    case .prepared(let curve, _):
      return .init(curve: curve, initial: initial, setupReport: report, owner: self)
    case .refused(let failure, _, _):
      stop()
      throw Failure.curvePreparation(failure, actualODE, report)
    }
  }

  /// This calls the real G3 algorithm once against current remaining work.
  /// All input preparations must already belong to this exact phase owner.
  /// Results remain conditional geometry, never a complete-world/event receipt.
  func query(source: PreparedSource, foreign: [Foreign]) throws -> G.Outcome {
    try requirePreparationPhase()
    guard source.curvePreparation.owner === self else {
      stop(); throw Failure.foreignPreparation
    }
    // Reserve each owned input-binding inspection before traversing or
    // allocating its prepared query list. G3 separately charges its own passes.
    try debit(queries: 0, triangles: foreign.count, nodes: 0, attempts: 0, cells: 0)
    var inputs: [G.Foreign] = []
    for entry in foreign {
      switch entry {
      case .ordinary(let input):
        guard case .ordinary = input.motion else {
          stop(); throw Failure.foreignPreparation
        }
        inputs.append(input)
      case .compound(let instance, let compound, let clearance, let purpose):
        guard compound.curvePreparation.owner === self else {
          stop(); throw Failure.foreignPreparation
        }
        inputs.append(.init(instance: instance, compound: compound.source,
          clearance: clearance, purpose: purpose))
      }
    }
    guard geometry.distanceQueries > 0, geometry.triangleTests > 0,
      geometry.nodeVisits > 0, ode.cellAttempts > 0, ode.retainedCells > 0
    else { throw Failure.exhausted }
    let outcome = NativeC01InquiryCurveGeometryConsumer.query(source: source.source,
      foreign: inputs, budget: geometry, odeBudget: ode)
    let report: G.Report
    switch outcome {
    case .clear(let actual): report = actual
    case .contact(_, let actual): report = actual
    case .refused(_, let actual): report = actual
    }
    // Source/foreign inputCurveWork describe already debited preparations.
    // Charge only actual new geometry work and query refinement here. A later
    // query/remainder gets this owner's remaining work, never fresh originals
    // or a caller-supplied cumulative Report used as an allowance certificate.
    try debit(queries: report.queries, triangles: report.triangles, nodes: report.nodes,
      attempts: report.odeAttempts, cells: report.odeCells)
    if case .refused = outcome { stop() }
    return outcome
  }

  private func debit(queries: Int, triangles: Int, nodes: Int, attempts: Int, cells: Int) throws {
    guard !stopped, terminalBirthReservation == nil,
      queries >= 0, queries <= geometry.distanceQueries,
      triangles >= 0, triangles <= geometry.triangleTests,
      nodes >= 0, nodes <= geometry.nodeVisits,
      attempts >= 0, attempts <= ode.cellAttempts,
      cells >= 0, cells <= ode.retainedCells
    else {
      stop()
      throw Failure.invalidReport
    }
    geometry.distanceQueries -= queries
    geometry.triangleTests -= triangles
    geometry.nodeVisits -= nodes
    ode = .init(cellAttempts: ode.cellAttempts - attempts,
      subdivisionDepth: ode.subdivisionDepth, retainedCells: ode.retainedCells - cells)
  }

  private func stop() {
    // Preserve exact unspent counters for evidence. They are unusable after
    // this flag; forfeited allowance is not misreported as actual spent work.
    stopped = true
  }
}
