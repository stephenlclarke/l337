import Foundation

private typealias MissionActorAdmissionOwnerFacts = (
  id: UUID, definition: String, version: String, digest: String, revision: UInt64,
  outcome: ScriptOutcome
)

/// Immutable values for one admission validation; never a shared simulation owner.
private final class MissionActorAdmissionOwnerSnapshot: Sendable {
  private let storedOwner: ScriptInstance
  private let storedPack: ScriptPack

  var owner: ScriptInstance {
    _read { yield storedOwner }
  }

  var pack: ScriptPack {
    _read { yield storedPack }
  }

  var authorityFacts: MissionActorAdmissionOwnerFacts {
    (
      storedOwner.id, storedOwner.definition, storedOwner.version, storedOwner.digest,
      storedOwner.revision, storedOwner.outcome
    )
  }

  func installedEncounter(_ id: String) -> ScriptOwnedEncounter? {
    storedOwner.ownedEncounters[id]
  }

  init(
    original: borrowing Game, source: MissionActorAdmissionSource,
    instances: [UUID: ScriptInstance]
  ) throws {
    guard let owner = instances[source.instanceID],
      owner.id == source.instanceID, owner.revision == source.instanceRevision,
      owner.digest == source.packDigest, owner.definition == source.definition,
      owner.version == source.version,
      let pack = Self.installedPack(for: owner, in: original.scriptPacks),
      pack.digest == source.packDigest,
      owner.ownedEncounters[source.encounterID] == source.installedBaseEncounter,
      source.retention.id == source.encounterID,
      source.transitContext != nil
        || source.actors.indices.allSatisfy({
          source.retention.actors[source.actors[$0].alias]?.location(in: source.retention)
            == source.system
        })
    else { throw MissionPackError("Actor admission source no longer matches its installed owner.") }
    storedOwner = consume owner
    storedPack = consume pack
  }

  /// Match the first installed pack without capturing the full owner or iterating full pack values.
  @inline(never)
  private static func installedPack(
    for owner: borrowing ScriptInstance, in packs: [ScriptPack]
  ) -> ScriptPack? {
    let definition = owner.definition
    let version = owner.version
    let digest = owner.digest
    for index in packs.indices {
      if packs[index].manifest.stateID == definition, packs[index].manifest.version == version,
        packs[index].digest == digest
      {
        return packs[index]
      }
    }
    return nil
  }
}

// Attempt-local scratch only: never Sendable, stored simulation state or admission authority.
private final class ScriptEncounterAttemptScratch {
  let definition: ScriptEncounterDefinition
  let previousGeometry: [String: ShipDesign]
  var publishesGeometry = false
  var alreadyAdmitted = false
  var encounter: ScriptOwnedEncounter?
  var source: MissionActorAdmissionSource?
  var preparation: NativeMissionActorAdmissionPreparation?
  var nativePlan: NativeMissionActorAdmissionPlan?
  var selected: ScriptInstance?
  var staged: ScriptInstance?
  var count = 0
  init(definition: consuming ScriptEncounterDefinition, previousGeometry: [String: ShipDesign]) {
    self.definition = consume definition
    self.previousGeometry = previousGeometry
  }
}

public struct ScriptActorDefinition: Codable, Sendable {
  public let id: String
  public let hull: Hull?
  public var npc: String? = nil
  public let x: Double
  public let y: Double
  public let z: Double
  public let hostile: Bool
}
public struct ScriptEncounterDefinition: Codable, Sendable {
  public let id: String
  public let galaxy: Int
  public let system: Int
  public let profile: String
  public let actors: [ScriptActorDefinition]
}
public enum ScriptActorPresence: String, Codable, Sendable {
  case prepared, present, outside, unloaded, destroyed, inTransit, arrivalPending
}
private struct ScriptOwnedActorValue: Codable, Sendable, Equatable {
  let identity: UUID
  let alias: String
  var body: SpaceBody
  var presence: ScriptActorPresence
  var destroyedByPlayer: Bool?
  var transitLocation: SystemIdentity?
}

/// Actor copies retain a COW value instead of an inline physical body tree.
public struct ScriptOwnedActor: Codable, Sendable, Equatable {
  private var storage: [ScriptOwnedActorValue]

  init(
    identity: UUID, alias: String, body: SpaceBody, presence: ScriptActorPresence,
    destroyedByPlayer: Bool? = nil, transitLocation: SystemIdentity? = nil
  ) {
    storage = [
      .init(
        identity: identity, alias: alias, body: body, presence: presence,
        destroyedByPlayer: destroyedByPlayer, transitLocation: transitLocation)
    ]
  }

  public init(from decoder: any Decoder) throws {
    storage = [try ScriptOwnedActorValue(from: decoder)]
  }

  public func encode(to encoder: any Encoder) throws {
    try storage[0].encode(to: encoder)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    // Compare all fields even for a shared buffer, including NaN-bearing body values.
    lhs.storage[0] == rhs.storage[0]
  }

  public var identity: UUID {
    _read { yield storage[0].identity }
  }

  public var alias: String {
    _read { yield storage[0].alias }
  }

  /// Canonical pose is relative to the main station's non-spinning reference basis.
  public var body: SpaceBody {
    _read { yield storage[0].body }
    _modify { yield &storage[0].body }
  }

  public var presence: ScriptActorPresence {
    _read { yield storage[0].presence }
    _modify { yield &storage[0].presence }
  }

  public var destroyedByPlayer: Bool? {
    _read { yield storage[0].destroyedByPlayer }
    _modify { yield &storage[0].destroyedByPlayer }
  }

  /// Relocation requires a retained successful native transit arrival; nil is the declared origin.
  var transitLocation: SystemIdentity? {
    _read { yield storage[0].transitLocation }
    _modify { yield &storage[0].transitLocation }
  }
  func location(in encounter: ScriptOwnedEncounter) -> SystemIdentity {
    transitLocation ?? .init(galaxy: encounter.galaxy, system: encounter.system)
  }
  var valid: Bool {
    guard PackValidation.localID(alias) else { return false }
    // Borrow the one stored body; do not repeatedly materialize its full value
    // while deeper C01 source/history validators remain on the executor stack.
    return Self.bodyValid(storage[0].body, identity: storage[0].identity, presence: storage[0].presence)
  }

  @inline(never)
  private static func bodyValid(
    _ body: borrowing SpaceBody, identity: UUID, presence: ScriptActorPresence
  ) -> Bool {
    guard body.missionActorID == identity,
      body.position.finite, body.position.length <= 1e9, body.orientation.validRotation,
      body.energy.isFinite, (0...10_000_000).contains(body.energy),
      Self.npcValid(body),
      body.rotation.isFinite, body.rotationRate.isFinite, (0...32).contains(body.missiles),
      (-1..<1_000_000_000).contains(body.id)
    else { return false }
    if presence == .destroyed { return body.energy == 0 }
    return true
  }

  @inline(never)
  private static func npcValid(_ body: borrowing SpaceBody) -> Bool {
    if case .none = body.scriptNPC { return true }
    guard body.scriptNPC!.valid,
      body.energy <= body.scriptNPC!.fit.definition.energy,
      body.missiles <= body.scriptNPC!.fit.definition.missiles
    else { return false }
    return true
  }
}
public struct ScriptOwnedEncounter: Codable, Sendable, Equatable {
  public let id: String
  public let galaxy: Int
  public let system: Int
  public var admitted = false
  public var actors: [String: ScriptOwnedActor]
  public var destroyed: Bool {
    admitted && !actors.isEmpty && actors.values.allSatisfy { $0.presence == .destroyed }
  }
  var valid: Bool {
    PackValidation.localID(id) && (0..<8).contains(galaxy) && (0...256).contains(system)
      && (1...128).contains(actors.count)
      && Set(actors.values.map(\.identity)).count == actors.count
      && actorsValid()
      && (admitted
        ? actors.values.allSatisfy { $0.presence != .prepared && $0.body.id >= 0 }
        : actors.values.allSatisfy { $0.presence == .prepared && $0.transitLocation == nil })
  }
  @inline(never)
  private func actorsValid() -> Bool {
    for index in actors.indices {
      guard Self.actorValid(actors.values[index], key: actors.keys[index]) else { return false }
    }
    return true
  }

  @inline(never)
  private static func actorValid(_ actor: borrowing ScriptOwnedActor, key: String) -> Bool {
    guard key == actor.alias else { return false }
    return actor.valid
  }
}

/// Unencoded authority from the actual encounter handler or installed retained record.
enum MissionActorAdmissionMode: Sendable, Equatable { case prepared, retained }

enum MissionActorAdmissionAuthority: Sendable, Equatable {
  case missionHandler
  case worldJob(identity: UUID, pulse: UInt64)
  case retained
  case transit(UUID)
  case inductionArkBerth(UUID)
  case inductionRescueBerth(UUID)
  case c03Initial
  case c03Retained
}

struct MissionActorAdmissionPart: Sendable {
  let alias: String?
  let componentID: UUID?
  let energy: Double
  let maximumEnergy: Double
  let solid: Bool
  /// Measured vertices in actor-local coordinates, with authored transforms already applied.
  let mesh: Mesh

  fileprivate init(
    alias: String?, componentID: UUID?, energy: Double, maximumEnergy: Double,
    solid: Bool, mesh: Mesh
  ) {
    self.alias = alias
    self.componentID = componentID
    self.energy = energy
    self.maximumEnergy = maximumEnergy
    self.solid = solid
    self.mesh = mesh
  }
}

struct MissionActorAdmissionTemplate: Sendable {
  let actorID: UUID
  let alias: String
  let presence: ScriptActorPresence
  /// Station-relative condition. The old scene ID and physical identity are stripped.
  let canonicalBody: SpaceBody
  let maximumHullEnergy: Double
  let declaredHostile: Bool
  let parts: [MissionActorAdmissionPart]
  let minimum: Vector3
  let maximum: Vector3
  let radius: Double
  let nativeUnits: Int
  /// Condition only: historical NPC targets/attribution must be rebound by native policy.
  let retainedNativeCondition: NPCState?
  let retainedNativeVelocity: Vector3?
  let retainedNativeLaserCooldown: Double?
  let c03Context: C03ActorAdmissionContext?
  let c03WakeContext: NativeC03WakeAdmissionContext?
  let c03RegisterContext: NativeC03RegisterAdmissionContext?

  fileprivate init(
    actor: ScriptOwnedActor, canonicalBody: SpaceBody, maximumHullEnergy: Double,
    declaredHostile: Bool, parts: [MissionActorAdmissionPart], minimum: Vector3,
    maximum: Vector3, radius: Double, nativeUnits: Int, initialNativeCondition: NPCState? = nil,
    c03Context: C03ActorAdmissionContext? = nil,
    c03WakeContext: NativeC03WakeAdmissionContext? = nil,
    c03RegisterContext: NativeC03RegisterAdmissionContext? = nil
  ) {
    actorID = actor.identity
    alias = actor.alias
    presence = actor.presence
    self.canonicalBody = canonicalBody
    self.maximumHullEnergy = maximumHullEnergy
    self.declaredHostile = declaredHostile
    self.parts = parts
    self.minimum = minimum
    self.maximum = maximum
    self.radius = radius
    self.nativeUnits = nativeUnits
    retainedNativeCondition = actor.body.physical?.npc ?? initialNativeCondition
    retainedNativeVelocity = actor.body.physical?.velocity
    retainedNativeLaserCooldown = actor.body.physical?.laserCooldown
    self.c03Context = c03Context
    self.c03WakeContext = c03WakeContext
    self.c03RegisterContext = c03RegisterContext
  }
}

struct MissionActorAdmissionSource: Sendable {
  let mode: MissionActorAdmissionMode
  let authority: MissionActorAdmissionAuthority
  let instanceID: UUID
  let instanceRevision: UInt64
  let packDigest: String
  let definition: String
  let version: String
  let encounterID: String
  let system: SystemIdentity
  let profile: String
  /// Exact pre-admission retention snapshot, for a prevalidated native retention patch.
  let retention: ScriptOwnedEncounter
  let actors: [MissionActorAdmissionTemplate]
  fileprivate let installedBaseEncounter: ScriptOwnedEncounter?
  fileprivate let transitContext: OriginalWorldJourneyContext?
  fileprivate let c03Context: C03ActorAdmissionContext?
  fileprivate let c03WakeContext: NativeC03WakeAdmissionContext?
  fileprivate let c03RegisterContext: NativeC03RegisterAdmissionContext?

  fileprivate init(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    instance: borrowing ScriptInstance, pack: borrowing ScriptPack, encounter: ScriptOwnedEncounter,
    definition: borrowing ScriptEncounterDefinition, actors: [MissionActorAdmissionTemplate],
    installedBaseEncounter: ScriptOwnedEncounter?,
    transitContext: OriginalWorldJourneyContext? = nil,
    c03Context: C03ActorAdmissionContext? = nil,
    c03WakeContext: NativeC03WakeAdmissionContext? = nil,
    c03RegisterContext: NativeC03RegisterAdmissionContext? = nil
  ) {
    self.mode = mode
    self.authority = authority
    instanceID = instance.id
    instanceRevision = instance.revision
    packDigest = pack.digest
    self.definition = instance.definition
    version = instance.version
    encounterID = encounter.id
    system =
      transitContext?.route.destination.location ?? actors.first.flatMap { template in
        encounter.actors[template.alias]?.transitLocation
      } ?? .init(galaxy: encounter.galaxy, system: encounter.system)
    profile = definition.profile
    retention = encounter
    self.actors = actors
    self.installedBaseEncounter = installedBaseEncounter
    self.transitContext = transitContext
    self.c03Context = c03Context
    self.c03WakeContext = c03WakeContext
    self.c03RegisterContext = c03RegisterContext
  }
}

/// Prepared before native publication; the owned adapter applies it without lookup or failure.
struct MissionActorRetentionPatch: Sendable {
  let instanceID: UUID
  let instanceRevision: UInt64
  let packDigest: String
  let encounterID: String
  let expectedEncounter: ScriptOwnedEncounter?
  let updatedEncounter: ScriptOwnedEncounter
  private let definition: String
  private let version: String

  fileprivate let c03Install: C03PreparedActorInstall?

  fileprivate init(
    source: MissionActorAdmissionSource, updated: ScriptOwnedEncounter,
    c03Install: C03PreparedActorInstall? = nil
  ) {
    instanceID = source.instanceID
    instanceRevision = source.instanceRevision
    packDigest = source.packDigest
    encounterID = source.encounterID
    expectedEncounter = (source.c03Context?.initial == true || source.c03WakeContext?.initial == true
      || source.c03RegisterContext?.initial == true)
      ? nil : source.retention
    self.c03Install = c03Install
    updatedEncounter = updated
    definition = source.definition
    version = source.version
  }

  func matches(_ instance: ScriptInstance) -> Bool {
    instance.id == instanceID && instance.revision == instanceRevision
      && instance.definition == definition && instance.version == version
      && instance.digest == packDigest && instance.ownedEncounters[encounterID] == expectedEncounter
  }

  /// Stage an entire selected instance before native commit, for direct postcommit publication.
  func preparingInstance(_ instance: ScriptInstance) throws -> ScriptInstance {
    guard matches(instance) else {
      throw MissionPackError("Actor retention changed before admission.")
    }
    if let c03Install {
      guard instance == c03Install.expected else { throw SaveError.invalidCommander }
      return c03Install.selected
    }
    var staged = instance
    apply(to: &staged)
    return staged
  }

  func validateC03Commit(in game: borrowing Game) throws {
    guard let c03Install else { return }
    guard game.acceptsHollowManifestInstalledCase(c03Install.pin),
      game.withReadOnlyScriptState({ $0.instances[instanceID] == c03Install.expected }),
      game.withReadOnlyScriptState({ $0.geometry == c03Install.previousGeometry }),
      C03PreparedActorInstall.eventCapacity(
        next: game.withReadOnlyScriptState({ $0.nextEvent }),
        pending: game.withReadOnlyScriptState({ $0.pendingEvents.count }), demand: 0)
    else { throw NativeMissionActorAdmissionError.stalePlan }
  }

  fileprivate func apply(to instance: inout ScriptInstance) {
    instance.ownedEncounters[encounterID] = updatedEncounter
  }
}

extension MissionActorAdmissionSource {
  /// Only the native preparation supplies new scene addresses; no historical address is reused.
  func prepareRetentionPatch(
    sceneBodyIDs: [UUID: Int], nativeBodies: [SpaceBody],
    stagedFlight: FlightSimulationState, original: borrowing Game
  ) throws -> MissionActorRetentionPatch {
    if let context = c03RegisterContext {
      return try original.prepareC03RegisterRetentionPatch(
        source: self, context: context, bodyIDs: sceneBodyIDs,
        bodies: nativeBodies, flight: stagedFlight)
    }
    if let context = c03WakeContext {
      return try original.prepareC03WakeRetentionPatch(
        source: self, context: context, bodyIDs: sceneBodyIDs,
        bodies: nativeBodies, flight: stagedFlight)
    }
    if let c03Context {
      return try original.prepareC03RetentionPatch(
        source: self, context: c03Context, bodyIDs: sceneBodyIDs,
        bodies: nativeBodies, flight: stagedFlight)
    }
    return try prepareRetentionPatch(sceneBodyIDs: sceneBodyIDs, nativeBodies: nativeBodies)
  }

  func prepareRetentionPatch(sceneBodyIDs: [UUID: Int], nativeBodies: [SpaceBody] = []) throws
    -> MissionActorRetentionPatch
  {
    var eligible = Set<UUID>()
    for index in actors.indices {
      if actors[index].presence != .destroyed, actors[index].canonicalBody.energy > 0 {
        eligible.insert(actors[index].actorID)
      }
    }
    guard Set(sceneBodyIDs.keys).isSubset(of: eligible),
      Set(sceneBodyIDs.values).count == sceneBodyIDs.count,
      sceneBodyIDs.values.allSatisfy({ (1..<1_000_000_000).contains($0) }),
      mode != .prepared || Set(sceneBodyIDs.keys) == eligible
    else { throw MissionPackError("Native actor addresses must cover the exact eligible cohort.") }
    var updated = retention
    for index in actors.indices {
      let alias = actors[index].alias
      let actorID = actors[index].actorID
      guard let bodyID = sceneBodyIDs[actorID] else { continue }
      guard var actor = updated.actors[alias], actor.identity == actorID else {
        throw MissionPackError("Actor retention mapping changed before native admission.")
      }
      switch authority {
      case .transit:
        actor.body = actors[index].canonicalBody
        actor.transitLocation = system
      case .inductionArkBerth, .inductionRescueBerth:
        actor.body = actors[index].canonicalBody
      default: break
      }
      if definition == NativeGlassMeridian.stateID, packDigest == NativeGlassMeridian.digest,
        encounterID == NativeC01Surveyor.encounter
      {
        guard
          let admitted = nativeBodies.first(where: {
            $0.missionActorID == actorID && $0.missionInstanceID == instanceID && $0.id == bodyID
          }), let physical = admitted.physical,
          NativeC01Surveyor.passiveFit(admitted),
          NativeC01Surveyor.nativeValid(
            physical, recorder: actor.alias == NativeC01Surveyor.aliases[1])
        else { throw NativeMissionActorAdmissionError.invalidCondition }
        // These are the actual staged native addresses and conserved inertia, before any commit.
        actor.body.physical = physical
      }
      if definition == NativeGlassMeridian.stateID, packDigest == NativeGlassMeridian.digest,
        encounterID == NativeC01TimingStandard.encounter
      {
        guard let part = NativeC01TimingStandard.Part(rawValue: actor.alias),
          let admitted = nativeBodies.first(where: {
            $0.missionActorID == actorID && $0.missionInstanceID == instanceID && $0.id == bodyID
          }), let physical = admitted.physical,
          admitted.scriptNPC?.fit == actor.body.scriptNPC?.fit,
          NativeC01TimingStandard.nativeValid(physical, part: part)
        else { throw NativeMissionActorAdmissionError.invalidCondition }
        actor.body.physical = physical
      }
      if definition == NativeGlassMeridian.stateID, packDigest == NativeGlassMeridian.digest,
        encounterID == NativeC01LaneRepair.encounter
      {
        guard let target = NativeC01LaneRepair.Target(rawValue: actor.alias),
          let admitted = nativeBodies.first(where: {
            $0.missionActorID == actorID && $0.missionInstanceID == instanceID && $0.id == bodyID
          }), let physical = admitted.physical,
          admitted.scriptNPC?.fit == actor.body.scriptNPC?.fit,
          NativeC01LaneRepair.nativeValid(physical, target: target)
        else { throw NativeMissionActorAdmissionError.invalidCondition }
        actor.body.physical = physical
      }
      if definition == NativeGlassMeridian.stateID, packDigest == NativeGlassMeridian.digest,
        encounterID == NativeC01ClinicEscort.sourceEncounter
      {
        let cradle = actor.alias == NativeC01ClinicEscort.cradleTarget
        guard cradle || NativeC01ClinicEscort.stockOrdinal(alias: actor.alias) != nil,
          let admitted = nativeBodies.first(where: {
            $0.missionActorID == actorID && $0.missionInstanceID == instanceID && $0.id == bodyID
          }), let physical = admitted.physical,
          admitted.scriptNPC?.fit == actor.body.scriptNPC?.fit,
          NativeC01ClinicEscort.nativeValid(physical, cradle: cradle)
        else { throw NativeMissionActorAdmissionError.invalidCondition }
        actor.body.physical = physical
      }
      actor.body.id = bodyID
      actor.presence = .present
      updated.actors[alias] = actor
    }
    if mode == .prepared {
      updated.admitted = true
    }
    guard updated.valid else { throw MissionPackError("Native actor retention patch is invalid.") }
    return .init(source: self, updated: updated)
  }
}

extension Game {
  /// End the computed Commander receiver's lifetime before nested admission starts.
  /// Every call reads the current Game and returns only immutable COW/scalar source facts.
  @inline(never)
  private func currentMissionActorAdmissionSourceValues() -> (
    instances: [UUID: ScriptInstance], geometry: [String: ShipDesign], galaxy: Int, system: Int
  ) {
    retainedMissionActorAdmissionSourceValues()
  }

  @inline(never)
  private func currentMissionActorAdmissionOwner(_ id: UUID) -> MissionActorAdmissionOwnerFacts? {
    withReadOnlyScriptState { state in
      guard let owner = state.instances[id] else { return nil }
      return (
        owner.id, owner.definition, owner.version, owner.digest, owner.revision, owner.outcome
      )
    }
  }

  /// A normal command still reads actual installed retention; its full-owner temporary returns here.
  @inline(never)
  private func currentMissionActorAdmissionInstalledEncounter(
    instanceID: UUID, encounterID: String
  ) -> ScriptOwnedEncounter? {
    withReadOnlyScriptState { $0.instances[instanceID]?.ownedEncounters[encounterID] }
  }

  @inline(never)
  private func currentMissionActorAdmissionWorldJob(_ id: UUID) -> ScriptWorldJob? {
    retainedMissionActorAdmissionWorldJob(id)
  }

  /// Rechecks a sealed source against actual installed authority without a caller snapshot.
  /// Prepared retention stays private to its adapter and must also match the staged patch.
  @inline(never)
  func validateMissionActorAdmissionSource(_ source: MissionActorAdmissionSource) throws {
    guard [source.c03Context != nil, source.c03WakeContext != nil, source.c03RegisterContext != nil]
      .filter({ $0 }).count <= 1 else {
      throw NativeMissionActorAdmissionError.invalidCondition
    }
    if let context = source.c03RegisterContext {
      guard acceptsHollowManifestRegisterAdmissionContext(context),
        source.actors.allSatisfy({ $0.c03Context == nil && $0.c03WakeContext == nil
          && $0.c03RegisterContext === context }),
        source.retention == context.retention,
        source.installedBaseEncounter == context.installedEncounter
      else { throw NativeMissionActorAdmissionError.stalePlan }
      return
    }
    if let context = source.c03WakeContext {
      guard acceptsHollowManifestWakeAdmissionContext(context),
        source.actors.allSatisfy({ $0.c03Context == nil && $0.c03RegisterContext == nil
          && $0.c03WakeContext === context }),
        source.retention == context.retention,
        source.installedBaseEncounter == context.installedEncounter
      else { throw NativeMissionActorAdmissionError.stalePlan }
      return
    }
    if let context = source.c03Context {
      guard acceptsHollowManifestInstalledCase(context.pin),
        source.actors.allSatisfy({ $0.c03WakeContext == nil && $0.c03RegisterContext == nil
          && $0.c03Context === context }),
        withReadOnlyCommander({ $0.flightSimulation }) == context.flight,
        scriptAnchor == context.station, source.retention == context.retention,
        source.installedBaseEncounter == context.installedEncounter,
        context.lives.values.allSatisfy({ acceptsHollowManifestOriginalLife($0) })
      else { throw NativeMissionActorAdmissionError.stalePlan }
      return
    }
    let currentInputs = currentMissionActorAdmissionSourceValues()
    let snapshot = try validatedMissionActorAdmissionOwner(
      source, instances: currentInputs.instances)
    // No mutation or suspension occurs between this actual-owner validation and its refresh.
    // Reuse only this invocation-local snapshot; it is never stored in an admission plan.
    let refreshed = try Self.refreshMissionActorAdmissionSource(
      original: self, source: source, owner: snapshot.owner, pack: snapshot.pack,
      installedOwner: snapshot,
      galaxy: currentInputs.galaxy, system: currentInputs.system)
    guard refreshed.profile == source.profile else {
      throw MissionPackError("Actor admission profile changed before publication.")
    }
  }

  @inline(never)
  private static func refreshMissionActorAdmissionSource(
    original: borrowing Game, source: borrowing MissionActorAdmissionSource,
    owner: borrowing ScriptInstance, pack: borrowing ScriptPack,
    installedOwner: MissionActorAdmissionOwnerSnapshot, galaxy: Int, system: Int
  ) throws -> MissionActorAdmissionSource {
    switch source.mode {
    case .retained:
      if case .transit(let leg) = source.authority, let context = source.transitContext {
        return try original.transitMissionActorAdmissionSource(leg, context: context)
      }
      if case .inductionArkBerth(let job) = source.authority {
        return try original.inductionArkBerthAdmissionSource(job)
      }
      if case .inductionRescueBerth(let job) = source.authority {
        return try original.inductionRescueBerthAdmissionSource(job)
      }
      guard source.authority == .retained,
        owner.ownedEncounters[source.encounterID] == source.retention,
        source.system == .init(galaxy: galaxy, system: system)
      else { throw MissionPackError("Retained actor admission source changed before publication.") }
      return try original.sealMissionActorAdmissionSource(
        mode: .retained, authority: .retained, pack: pack, state: owner,
        encounter: source.retention, installedOwner: installedOwner)
    case .prepared:
      switch source.authority {
      case .missionHandler:
        return try original.preparedMissionActorAdmissionSource(
          pack: pack, state: owner, encounter: source.retention, installedOwner: installedOwner)
      case .worldJob(let identity, let pulse):
        return try original.preparedMissionActorAdmissionSource(
          pack: pack, state: owner, encounter: source.retention,
          worldJob: identity, pulse: pulse, installedOwner: installedOwner)
      case .retained, .transit, .inductionArkBerth, .inductionRescueBerth,
        .c03Initial, .c03Retained:
        throw MissionPackError("A prepared cohort cannot substitute retained admission authority.")
      }
    }
  }

  /// Finish installed-owner lookup/comparison temporaries before nested source refresh.
  @inline(never)
  private func validatedMissionActorAdmissionOwner(
    _ source: MissionActorAdmissionSource, instances: [UUID: ScriptInstance]
  ) throws -> MissionActorAdmissionOwnerSnapshot {
    try MissionActorAdmissionOwnerSnapshot(original: self, source: source, instances: instances)
  }

  /// Reads only actual installed retained ownership; there is no caller-supplied state/body path.
  func retainedMissionActorAdmissionSources() throws -> [MissionActorAdmissionSource] {
    let instances = retainedMissionActorInstances
    var sources: [MissionActorAdmissionSource] = []
    if let c03 = try c03ActorAdmissionSource() { sources.append(c03) }
    if let wakes = try c03WakeActorAdmissionSource() { sources.append(wakes) }
    if let archive = try c03RegisterActorAdmissionSource() { sources.append(archive) }
    for id in instances.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
      guard let instance = instances[id], let pack = scriptPack(for: instance)
      else { continue }
      if NativeHollowManifestCommission.marked(instance) { continue }
      guard instance.id == id else {
        throw MissionPackError("Retained actor instance key mismatch.")
      }
      for key in instance.ownedEncounters.keys.sorted() {
        guard let encounter = instance.ownedEncounters[key], encounter.admitted,
          encounter.actors.values.contains(where: {
            $0.location(in: encounter) == missionActorAdmissionSystemIdentity
              && ![.inTransit, .arrivalPending].contains($0.presence)
          })
        else { continue }
        guard encounter.id == key else {
          throw MissionPackError("Retained encounter key mismatch.")
        }
        sources.append(
          try sealMissionActorAdmissionSource(
            mode: .retained, authority: .retained, pack: pack, state: instance,
            encounter: encounter))
      }
    }
    return sources
  }

  /// The destination adapter reuses the whole native admission transaction. Its input is an
  /// installed due journey, never a caller-built body, synthetic arrival or source-system restore.
  func transitMissionActorAdmissionSource(_ legID: UUID, context: OriginalWorldJourneyContext)
    throws
    -> MissionActorAdmissionSource
  {
    guard let leg = withReadOnlyScriptState({ $0.wormholeTransit?.legs[legID] }),
      leg.valid,
      [.inTransit, .arrivalPending].contains(leg.phase), let departure = leg.departure,
      let due = leg.dueAt, withReadOnlyScriptState({ $0.calendarSeconds }) >= due,
      context.route == leg.route, context.matches(self, at: missionActorAdmissionSystemIdentity),
      missionActorAdmissionSystemIdentity == context.route.destination.location, !docked,
      let owner = withReadOnlyScriptState({ $0.instances[leg.instance] }),
      let pack = scriptPack(for: owner),
      let encounter = owner.ownedEncounters[leg.encounter],
      var actor = encounter.actors[leg.alias], actor.identity == leg.actor,
      [.inTransit, .arrivalPending].contains(actor.presence), actor.body == departure.body,
      !bodies.indices.contains(where: { bodies[$0].missionActorID == leg.actor }),
      let anchor = scriptAnchor
    else {
      throw MissionPackError(
        "Native transit arrival requires its exact due retained actor and destination world.")
    }
    let definition = try validateMissionActorAdmissionEncounter(
      mode: .retained, pack: pack, state: owner, encounter: encounter)
    guard let spec = definition.actors.first(where: { $0.id == leg.alias }) else {
      throw MissionPackError("The transit actor is no longer declared.")
    }
    let pose = withReadOnlyCommander { $0.flightSimulation.pose }
    actor.body.position = anchor.orientation.inverse(
      pose.shipPoint(context.route.exit.position) - anchor.position)
    actor.body.orientation = context.route.exit.orientation.relative(to: pose.orientation).relative(
      to: anchor.orientation)
    // The source-frame transit steering ends here. No local approach/escort arrival is emitted.
    actor.body.scriptNPC?.intent = nil
    if let velocity = departure.body.physical?.velocity {
      actor.body.scriptNPC?.velocity = anchor.orientation.inverse(pose.shipVector(velocity))
    }
    let template = try Self.missionActorAdmissionTemplate(
      actor, specification: spec, npcDefinitions: pack.manifest.npcs ?? [],
      installedModels: pack.models, geometry: withReadOnlyScriptState { $0.geometry })
    return .init(
      mode: .retained, authority: .transit(legID), instance: owner, pack: pack,
      encounter: encounter, definition: definition, actors: [template],
      installedBaseEncounter: encounter, transitContext: context)
  }

  /// Called only by this file's validated prepared-encounter handler when native admission is wired.
  /// A world job supplies its actual UUID and pending pulse, never a Boolean authorization.
  private func preparedMissionActorAdmissionSource(
    pack: borrowing ScriptPack, state: borrowing ScriptInstance, encounter: ScriptOwnedEncounter,
    worldJob: UUID? = nil, pulse: UInt64? = nil,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionSource {
    let installedEncounter: ScriptOwnedEncounter?
    if let installedOwner {
      installedEncounter = installedOwner.installedEncounter(encounter.id)
    } else {
      installedEncounter = currentMissionActorAdmissionInstalledEncounter(
        instanceID: state.id, encounterID: encounter.id)
    }
    guard installedEncounter?.admitted != true
    else {
      throw MissionPackError("An admitted retained cohort cannot become a fresh prepared source.")
    }
    let authority = try missionActorAdmissionAuthority(
      pack: pack, state: state, encounterID: encounter.id,
      galaxy: encounter.galaxy, system: encounter.system, worldJob: worldJob, pulse: pulse,
      installedOwner: installedOwner)
    return try sealMissionActorAdmissionSource(
      mode: .prepared, authority: authority, pack: pack, state: state, encounter: encounter,
      installedOwner: installedOwner)
  }

  private func missionActorAdmissionAuthority(
    pack: borrowing ScriptPack, state: borrowing ScriptInstance, encounterID: String,
    galaxy: Int, system: Int, worldJob: UUID?, pulse: UInt64?,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionAuthority {
    let storedFacts: MissionActorAdmissionOwnerFacts?
    if let installedOwner {
      storedFacts = installedOwner.authorityFacts
    } else {
      storedFacts = currentMissionActorAdmissionOwner(state.id)
    }
    guard let stored = storedFacts, stored.id == state.id,
      stored.definition == state.definition, stored.version == state.version,
      stored.digest == state.digest, stored.revision == state.revision
    else { throw MissionPackError("Prepared actors require the actual command candidate owner.") }
    guard state.definition == pack.manifest.stateID, state.version == pack.manifest.version,
      state.digest == pack.digest,
      scriptPacks.contains(where: {
        $0.manifest.stateID == stored.definition && $0.manifest.version == stored.version
          && $0.digest == stored.digest
      })
    else { throw MissionPackError("Prepared authority requires its exact installed content.") }
    let authority: MissionActorAdmissionAuthority
    if let worldJob, let pulse {
      guard let job = currentMissionActorAdmissionWorldJob(worldJob), job.identity == worldJob,
        job.origin == state.id, job.status == .active, job.suspension == nil,
        job.pending?.sequence == pulse, job.valid, worldJobOwnerAlive(job),
        pack.manifest.worldJobs?.contains(job.definition) == true,
        job.definition.controlledEncounters?.contains(encounterID) == true,
        job.definition.galaxy == galaxy, job.definition.system == system
      else { throw MissionPackError("The actual pending world job must control this encounter.") }
      authority = .worldJob(identity: worldJob, pulse: pulse)
    } else {
      guard worldJob == nil, pulse == nil, state.outcome == .active, stored.outcome == .active
      else {
        throw MissionPackError("Prepared actors require an active mission command authority.")
      }
      authority = .missionHandler
    }
    return authority
  }

  private func sealMissionActorAdmissionSource(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    pack: borrowing ScriptPack, state: borrowing ScriptInstance, encounter: ScriptOwnedEncounter,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionSource {
    let definition = try validateMissionActorAdmissionEncounter(
      mode: mode, pack: pack, state: state, encounter: encounter)
    return try constructMissionActorAdmissionSource(
      mode: mode, authority: authority, pack: pack, state: state, encounter: encounter,
      definition: definition, installedOwner: installedOwner)
  }

  /// Finish full record validation before any template-construction frame becomes active.
  private func validateMissionActorAdmissionEncounter(
    mode: MissionActorAdmissionMode, pack: borrowing ScriptPack, state: borrowing ScriptInstance,
    encounter: ScriptOwnedEncounter
  ) throws -> ScriptEncounterDefinition {
    let ownerDefinition = state.definition
    let ownerVersion = state.version
    let ownerDigest = state.digest
    guard state.definition == pack.manifest.stateID, state.version == pack.manifest.version,
      state.digest == pack.digest,
      scriptPacks.contains(where: {
        $0.manifest.stateID == ownerDefinition && $0.manifest.version == ownerVersion
          && $0.digest == ownerDigest
      }),
      encounter.valid,
      let definition = NativeHollowManifestCommission.encounterDefinition(
        pack: pack, state: state, id: encounter.id),
      definition.valid, definition.galaxy == encounter.galaxy,
      definition.system == encounter.system,
      Set(definition.actors.map(\.id)) == Set(encounter.actors.keys),
      mode == .retained ? encounter.admitted : !encounter.admitted,
      pack.manifest.capabilities.contains(
        definition.profile == "classic-local-freeze-v1"
          ? "classic-encounters-v2" : "profiled-encounters-v2")
    else { throw MissionPackError("The actor source must match its exact installed encounter.") }
    return definition
  }

  /// The encounter and every actor/NPC were validated above on this same immutable value.
  private func constructMissionActorAdmissionSource(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    pack: borrowing ScriptPack, state: borrowing ScriptInstance,
    encounter: borrowing ScriptOwnedEncounter, definition: borrowing ScriptEncounterDefinition,
    installedOwner: MissionActorAdmissionOwnerSnapshot? = nil
  ) throws -> MissionActorAdmissionSource {
    let currentInputs = currentMissionActorAdmissionSourceValues()
    let installedEncounter: ScriptOwnedEncounter?
    if let installedOwner {
      installedEncounter = installedOwner.installedEncounter(encounter.id)
    } else {
      installedEncounter = currentMissionActorAdmissionInstalledEncounter(
        instanceID: state.id, encounterID: encounter.id)
    }
    let templates = try Self.constructMissionActorAdmissionTemplates(
      original: self, mode: mode, pack: pack, state: state,
      encounter: encounter, definition: definition,
      geometry: currentInputs.geometry)
    return Self.finishMissionActorAdmissionSource(
      mode: mode, authority: authority, pack: pack, state: state, encounter: encounter,
      definition: definition, templates: consume templates, installedEncounter: installedEncounter)
  }

  /// Reserve template-construction values only after the actual Game facts have been read.
  @inline(never)
  private static func constructMissionActorAdmissionTemplates(
    original: borrowing Game, mode: MissionActorAdmissionMode, pack: borrowing ScriptPack,
    state: borrowing ScriptInstance, encounter: borrowing ScriptOwnedEncounter,
    definition: borrowing ScriptEncounterDefinition,
    geometry: borrowing [String: ShipDesign]
  ) throws -> [MissionActorAdmissionTemplate] {
    var templates: [MissionActorAdmissionTemplate] = []
    for spec in definition.actors.sorted(by: { $0.id < $1.id }) {
      var actor = try Self.validatedMissionActorAdmissionActor(
        spec, encounter: encounter, instanceID: state.id, packDigest: pack.digest,
        glassMeridian: state.savedGlassMeridian)
      if mode == .retained {
        if actor.location(in: encounter) != original.missionActorAdmissionSystemIdentity
          || [.inTransit, .arrivalPending].contains(actor.presence)
        {
          continue
        }
        actor = try original.isolationWorkRetainedActor(actor, in: state)
      }
      let template = try Self.missionActorAdmissionTemplate(
        actor, specification: spec,
        npcDefinitions: NativeHollowManifestCommission.profiles(pack: pack, state: state),
        installedModels: NativeHollowManifestCommission.designs(pack: pack, state: state), geometry: geometry,
        initialNativeCondition: mode == .prepared
          ? try Self.preparedNativeMissionResources(state: state, actor: actor) : nil)
      if mode == .prepared {
        try Self.validatePreparedMissionActorCondition(
          actor, spec: spec, template: template,
          mechanicallyDisabled: NativeInductionCrewLogPack.mechanicallyDisabled(
            actor, state: state),
          preparedOrientation: NativeC01Surveyor.preparedOrientation(state: state, actor: actor)
        )
      }
      templates.append(template)
    }
    return templates
  }

  private static func preparedNativeMissionResources(
    state: borrowing ScriptInstance, actor: ScriptOwnedActor
  ) throws -> NPCState? {
    if NativeIsolationWorkPack.marked(state) {
      return try NativeIsolationWorkPack.initialResources(state: state, actor: actor)
    }
    if state.definition == NativeGlassMeridian.stateID, state.digest == NativeGlassMeridian.digest,
      actor.alias == NativeC01Surveyor.aliases[0]
    {
      return try NativeC01Surveyor.initialResources(state: state, actor: actor)
    }
    if let resources = try NativeC01ClinicEscort.initialResources(state: state, actor: actor) {
      return resources
    }
    if let resources = try NativeC01LaneRepair.initialResources(state: state, actor: actor) {
      return resources
    }
    if NativeInductionUtilityPack.marked(state) {
      return try NativeInductionUtilityPack.initialResources(state: state, actor: actor)
    }
    if NativeInductionCrewLogPack.marked(state) {
      return try NativeInductionCrewLogPack.initialResources(state: state, actor: actor)
    }
    return try NativeInductionArkPack.initialCondition(state: state, actor: actor)
  }

  /// Construct the owned result only after per-actor validation and template frames have returned.
  @inline(never)
  private static func finishMissionActorAdmissionSource(
    mode: MissionActorAdmissionMode, authority: MissionActorAdmissionAuthority,
    pack: borrowing ScriptPack, state: borrowing ScriptInstance,
    encounter: borrowing ScriptOwnedEncounter, definition: borrowing ScriptEncounterDefinition,
    templates: consuming [MissionActorAdmissionTemplate], installedEncounter: ScriptOwnedEncounter?
  ) -> MissionActorAdmissionSource {
    return .init(
      mode: mode, authority: authority, instance: state, pack: pack,
      encounter: copy encounter, definition: definition, actors: consume templates,
      installedBaseEncounter: installedEncounter)
  }

  /// Return the same selected actor after its identity/body-read temporaries have ended.
  @inline(never)
  private static func validatedMissionActorAdmissionActor(
    _ spec: ScriptActorDefinition, encounter: ScriptOwnedEncounter, instanceID: UUID,
    packDigest: String,
    glassMeridian: NativeGlassMeridianState? = nil
  ) throws -> ScriptOwnedActor {
    guard let actor = encounter.actors[spec.id], actor.alias == spec.id,
      actor.identity == ScriptIdentity.uuid(
            "script-actor-v2:\(instanceID):\(packDigest):\(encounter.id):\(spec.id)")
        || NativeGlassMeridian.authorizesReplacement(
          glassMeridian, actor: actor,
          encounter: encounter.id, instance: instanceID, packDigest: packDigest),
      actor.body.missionInstanceID == instanceID, actor.body.scriptShot == nil
    else { throw MissionPackError("Actor source identity or canonical condition is invalid.") }
    return actor
  }

  /// These stock-only temporaries are needed after measured template construction returns.
  /// Retained actors keep their existing spent condition and never enter this phase.
  @inline(never)
  private static func validatePreparedMissionActorCondition(
    _ actor: ScriptOwnedActor, spec: ScriptActorDefinition,
    template: MissionActorAdmissionTemplate,
    mechanicallyDisabled: Bool = false, preparedOrientation: Basis3? = nil
  ) throws {
    try validatePreparedMissionActorPose(
      actor, spec: spec, orientation: preparedOrientation ?? Basis3())
    try validatePreparedMissionActorEnergy(
      actor, template: template, mechanicallyDisabled: mechanicallyDisabled)
    if let resources = preparedMissionActorNPCResources(actor) {
      try validatePreparedMissionActorNPCResources(resources)
    } else {
      try validatePreparedMissionActorClassicResources(actor)
    }
  }

  @inline(never)
  private static func validatePreparedMissionActorPose(
    _ actor: borrowing ScriptOwnedActor, spec: ScriptActorDefinition, orientation: Basis3
  ) throws {
    guard actor.body.id == -1, actor.body.physical == nil,
      actor.body.position == .init(spec.x, spec.y, spec.z),
      actor.body.orientation == orientation, actor.body.hostile == spec.hostile
    else {
      throw MissionPackError(
        "A prepared actor must retain its actual authored initial condition.")
    }
  }

  @inline(never)
  private static func validatePreparedMissionActorEnergy(
    _ actor: borrowing ScriptOwnedActor, template: borrowing MissionActorAdmissionTemplate,
    mechanicallyDisabled: Bool = false
  ) throws {
    let maximumHullEnergy = template.maximumHullEnergy
    let expectedEnergy =
      NativeC01Surveyor.isPreparedDisabledHarrier(actor) ? 64 : maximumHullEnergy
    guard actor.body.energy == expectedEnergy,
      template.parts.allSatisfy({ part in
        if part.alias == nil {
          return part.energy == expectedEnergy && part.maximumEnergy == maximumHullEnergy
        }
        return mechanicallyDisabled && part.alias == "drive"
          ? part.energy == 0 && !part.solid : part.energy == part.maximumEnergy
      })
    else {
      throw MissionPackError(
        "A prepared actor must retain its actual authored initial condition.")
    }
  }

  private struct PreparedMissionActorNPCResources: Sendable {
    let npc: ScriptNPCState
    let missiles: Int
    let ecmEnabled: Bool
  }

  /// End body-read temporaries before validating only the immutable NPC resource facts.
  @inline(never)
  private static func preparedMissionActorNPCResources(
    _ actor: borrowing ScriptOwnedActor
  ) -> PreparedMissionActorNPCResources? {
    guard let npc = actor.body.scriptNPC else { return nil }
    return .init(npc: npc, missiles: actor.body.missiles, ecmEnabled: actor.body.ecmEnabled)
  }

  @inline(never)
  private static func validatePreparedMissionActorNPCResources(
    _ resources: borrowing PreparedMissionActorNPCResources
  ) throws {
    guard preparedMissionActorNPCScalarsArePristine(resources),
      preparedMissionActorGunsArePristine(resources.npc.guns),
      preparedMissionActorComponentGunsArePristine(resources.npc.components)
    else {
      throw MissionPackError(
        "Prepared NPC resources cannot substitute spent retained state.")
    }
  }

  @inline(never)
  private static func preparedMissionActorNPCScalarsArePristine(
    _ resources: borrowing PreparedMissionActorNPCResources
  ) -> Bool {
    let npc = resources.npc
    guard npc.shots == 0, npc.fuel == npc.fit.definition.fuel,
      npc.velocity == .init(0, 0, 0),
      resources.missiles == npc.fit.definition.missiles,
      resources.ecmEnabled == npc.fit.definition.ecm
    else { return false }
    return true
  }

  @inline(never)
  private static func preparedMissionActorGunsArePristine(
    _ guns: borrowing [String: ScriptNPCGunState]
  ) -> Bool {
    guns.values.allSatisfy({ $0 == ScriptNPCGunState() })
  }

  @inline(never)
  private static func preparedMissionActorComponentGunsArePristine(
    _ components: borrowing [String: ScriptNPCComponentState]
  ) -> Bool {
    components.values.allSatisfy({
      $0.guns.values.allSatisfy { $0 == ScriptNPCGunState() }
    })
  }

  @inline(never)
  private static func validatePreparedMissionActorClassicResources(
    _ actor: borrowing ScriptOwnedActor
  ) throws {
    guard actor.body.missiles == actor.body.hull.navalMissiles,
      actor.body.ecmEnabled == actor.body.hull.hasECM
    else {
      throw MissionPackError(
        "Prepared classic stock differs from its actual hull defaults.")
    }
  }

  /// Uses the current invocation's immutable dictionaries; no Game or interpreter is captured.
  @inline(never)
  private static func measuredMissionActorAdmissionMesh(
    _ reference: String, modelHashes: [String: String], installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign], scale: Double, offset: Vector3, pose: Basis3
  ) throws -> Mesh {
    let installed = try validatedMissionActorAdmissionGeometry(
      reference, modelHashes: modelHashes, installedModels: installedModels, geometry: geometry)
    return transformedMissionActorAdmissionMesh(installed, scale: scale, offset: offset, pose: pose)
  }

  /// Keep the full installed-design equality and validity frame out of mesh transformation.
  @inline(never)
  private static func validatedMissionActorAdmissionGeometry(
    _ reference: String, modelHashes: [String: String], installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign]
  ) throws -> ShipDesign {
    guard let digest = modelHashes[reference], let installed = installedModels[reference],
      geometry[digest] == installed, ScriptPackLibrary.scriptGeometryValid(installed)
    else { throw MissionPackError("Exact admitted NPC geometry is unavailable or changed.") }
    return installed
  }

  @inline(never)
  private static func transformedMissionActorAdmissionMesh(
    _ installed: ShipDesign, scale: Double, offset: Vector3, pose: Basis3
  ) -> Mesh {
    let raw: Mesh
    if let geometry = try? NativeC01SurveyorGeometry.harrier.get(), installed == geometry.design
    {
      raw = geometry.collision
    } else {
      raw = installed.rawMesh
    }
    return Mesh(
      vertices: raw.vertices.map { offset + pose.apply($0 * scale) }, faces: raw.faces,
      preserveWinding: true)
  }

  /// Private to this invocation's declaration validation and subsequent construction.
  private enum MissionActorAdmissionFit: Sendable {
    case npc(ScriptNPCState, ScriptNPCDefinition)
    case classic(Hull)
  }

  @inline(never)
  private static func missionActorAdmissionTemplate(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    npcDefinitions: [ScriptNPCDefinition], installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign],
    initialNativeCondition: NPCState? = nil
  ) throws -> MissionActorAdmissionTemplate {
    let fit = try validateMissionActorAdmissionFit(
      actor, specification: specification, npcDefinitions: npcDefinitions)
    return try constructMissionActorAdmissionTemplate(
      actor, specification: specification, fit: fit, installedModels: installedModels,
      geometry: geometry, initialNativeCondition: initialNativeCondition)
  }

  /// Full structural equality finishes before any mesh, bounds or canonical-body frame starts.
  @inline(never)
  private static func validateMissionActorAdmissionFit(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    npcDefinitions: [ScriptNPCDefinition]
  ) throws -> MissionActorAdmissionFit {
    if let npcID = specification.npc {
      guard actor.body.hull == .cobra, let npc = actor.body.scriptNPC,
        let definition = npcDefinitions.first(where: { $0.id == npcID }),
        definition == npc.fit.definition
      else { throw MissionPackError("Retained NPC fit differs from its actual declaration.") }
      return .npc(npc, definition)
    } else {
      guard let hull = specification.hull, actor.body.hull == hull, actor.body.scriptNPC == nil
      else {
        throw MissionPackError("Retained classic hull differs from its actual declaration.")
      }
      return .classic(hull)
    }
  }

  /// Uses only the exact selected fit returned by the immediately preceding validation phase.
  @inline(never)
  private static func constructMissionActorAdmissionTemplate(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    fit: MissionActorAdmissionFit, installedModels: [String: ShipDesign],
    geometry: [String: ShipDesign],
    initialNativeCondition: NPCState? = nil
  ) throws -> MissionActorAdmissionTemplate {
    let constructed = try constructMissionActorAdmissionParts(
      actor, fit: fit, installedModels: installedModels, geometry: geometry)
    return try finalizeMissionActorAdmissionTemplate(
      actor, specification: specification, parts: constructed.parts,
      maximumEnergy: constructed.maximumEnergy, initialNativeCondition: initialNativeCondition)
  }

  private struct MissionActorAdmissionParts: Sendable {
    let parts: [MissionActorAdmissionPart]
    let maximumEnergy: Double
  }

  /// Parts and their full geometry checks finish before bounds/canonical-body storage is needed.
  @inline(never)
  private static func constructMissionActorAdmissionParts(
    _ actor: ScriptOwnedActor, fit: MissionActorAdmissionFit,
    installedModels: [String: ShipDesign], geometry: [String: ShipDesign]
  ) throws -> MissionActorAdmissionParts {
    var parts: [MissionActorAdmissionPart] = []
    let maximumEnergy: Double
    switch fit {
    case .npc(let npc, let definition):
      maximumEnergy = definition.energy
      parts.append(
        .init(
          alias: nil, componentID: nil, energy: actor.body.energy, maximumEnergy: maximumEnergy,
          solid: true,
          mesh: try measuredMissionActorAdmissionMesh(
            definition.model, modelHashes: npc.fit.models, installedModels: installedModels,
            geometry: geometry, scale: definition.scale, offset: .init(0, 0, 0), pose: Basis3())))
      for spec in definition.components ?? [] {
        guard let state = npc.components[spec.id],
          state.identity == ScriptIdentity.uuid("script-component-v2:\(actor.identity):\(spec.id)")
        else { throw MissionPackError("Retained component identity differs from its owner.") }
        parts.append(
          .init(
            alias: spec.id, componentID: state.identity, energy: state.energy,
            maximumEnergy: spec.energy, solid: spec.solid,
            mesh: try measuredMissionActorAdmissionMesh(
              spec.model, modelHashes: npc.fit.models, installedModels: installedModels,
              geometry: geometry, scale: spec.scale * definition.scale,
              offset: spec.position * definition.scale, pose: spec.orientation)))
      }
    case .classic(let hull):
      guard hull != .constrictor, let mesh = ShipCatalogue.nativeMesh(hull) else {
        throw MissionPackError("Classic hull \(hull.rawValue) has no exact mission geometry.")
      }
      maximumEnergy = hull.navalEnergy ?? 100
      parts.append(
        .init(
          alias: nil, componentID: nil, energy: actor.body.energy, maximumEnergy: maximumEnergy,
          solid: true, mesh: mesh))
    }
    return .init(parts: parts, maximumEnergy: maximumEnergy)
  }

  @inline(never)
  private static func finalizeMissionActorAdmissionTemplate(
    _ actor: ScriptOwnedActor, specification: ScriptActorDefinition,
    parts: [MissionActorAdmissionPart], maximumEnergy: Double, initialNativeCondition: NPCState?
  ) throws -> MissionActorAdmissionTemplate {
    guard actor.body.energy <= maximumEnergy,
      actor.body.physical?.npc?.resources?.valid ?? true,
      actor.body.physical?.velocity.finite ?? true,
      actor.body.physical.map({ $0.laserCooldown.isFinite && $0.laserCooldown >= 0 }) ?? true
    else { throw MissionPackError("Retained actor condition exceeds its actual source bounds.") }
    let solids = parts.filter { $0.solid && ($0.alias == nil || $0.energy > 0) }
    let vertices = solids.flatMap(\.mesh.vertices)
    guard let first = vertices.first,
      vertices.allSatisfy({ $0.finite && $0.length.isFinite }),
      parts.allSatisfy({ part in
        !part.mesh.faces.isEmpty
          && part.mesh.faces.allSatisfy {
            $0.count >= 3 && $0.allSatisfy(part.mesh.vertices.indices.contains)
          }
      })
    else { throw MissionPackError("Actor admission requires measured finite collision geometry.") }
    var minimum = first
    var maximum = first
    for vertex in vertices.dropFirst() {
      minimum = .init(min(minimum.x, vertex.x), min(minimum.y, vertex.y), min(minimum.z, vertex.z))
      maximum = .init(max(maximum.x, vertex.x), max(maximum.y, vertex.y), max(maximum.z, vertex.z))
    }
    var canonical = actor.body
    canonical.id = -1
    canonical.physical = nil
    canonical.destroyedByPlayer = nil
    canonical.navalTarget = false
    canonical.playerMissileTarget = nil
    canonical.enemyMissile = false
    canonical.missileSourceID = nil
    canonical.blackjackIdentity = nil
    canonical.blackjackRole = nil
    canonical.blackjackLaserCooldown = nil
    return .init(
      actor: actor, canonicalBody: canonical, maximumHullEnergy: maximumEnergy,
      declaredHostile: specification.hostile, parts: parts, minimum: minimum, maximum: maximum,
      radius: vertices.map(\.length).max() ?? 0, nativeUnits: solids.count,
      initialNativeCondition: initialNativeCondition)
  }
}

extension ScriptEncounterDefinition {
  static let classicHulls: Set<Hull> = [
    .cobra, .viper, .sidewinder, .constrictor, .thargoid, .thargon,
  ]
  var valid: Bool {
    PackValidation.localID(id) && (0..<8).contains(galaxy) && (0...256).contains(system)
      && ["classic-local-freeze-v1", "profiled-local-freeze-v1"].contains(profile)
      && (1...128).contains(actors.count)
      && Set(actors.map(\.id)).count == actors.count
      && actors.allSatisfy {
        PackValidation.localID($0.id)
          && (profile == "classic-local-freeze-v1"
            ? $0.hull.map(Self.classicHulls.contains) == true && $0.npc == nil
            : $0.hull == nil && $0.npc.map(PackValidation.localID) == true)
          && [$0.x, $0.y, $0.z].allSatisfy { $0.isFinite && abs($0) <= 1_000_000 }
      }
  }
}

public struct ScriptReferenceFrame: Codable, Sendable, Equatable {
  public var galaxy: Int
  public var system: Int
  public var station: SpaceBody
  var valid: Bool {
    (0..<8).contains(galaxy) && (0...256).contains(system) && station.id == 0
      && station.hull == .station
      && station.position.finite && station.orientation.validRotation && station.energy.isFinite
      && station.rotation.isFinite && station.rotationRate.isFinite
  }
}

extension Game {
  var scriptAnchor: SpaceBody? {
    let system = missionActorAdmissionSystemIdentity
    return Self.resolveScriptAnchor(
      bodies: bodies, frame: scriptReferenceFrame, galaxy: system.galaxy, system: system.system)
  }

  // Borrow only the inputs used by anchor selection; do not materialize a Game or Commander.
  @inline(never)
  private static func resolveScriptAnchor(
    bodies: borrowing [SpaceBody], frame: borrowing ScriptReferenceFrame?,
    galaxy: Int, system: Int
  ) -> SpaceBody? {
    for index in bodies.indices where bodies[index].id == 0 && bodies[index].hull == .station {
      return bodies[index].energy > 0 ? bodies[index] : nil
    }
    guard let frame = copy frame, frame.galaxy == galaxy,
      frame.system == system, frame.station.energy > 0
    else { return nil }
    return frame.station
  }
  mutating func advanceScriptReferenceFrame(delta: Double) {
    guard !bodies.contains(where: { $0.id == 0 && $0.hull == .station }),
      var frame = scriptReferenceFrame, frame.galaxy == commander.galaxy,
      frame.system == commander.system
    else { return }
    frame.station.position = frame.station.position.rotated(
      pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    frame.station.orientation.rotate(pitch: pitch * delta, roll: roll * delta, yaw: yaw * delta)
    frame.station.position =
      frame.station.position - autoPilot.velocity * delta - Vector3(0, 0, speed * delta * 18)
    frame.station.rotation += frame.station.rotationRate * delta
    scriptReferenceFrame = frame
  }
  func scriptEncounterSnapshot(_ instance: ScriptInstance) -> ScriptValue {
    .object(
      instance.ownedEncounters.mapValues { encounter in
        .object([
          "admitted": .bool(encounter.admitted), "destroyed": .bool(encounter.destroyed),
          "total": .integer(Int64(encounter.actors.count)),
          "destroyed_count": .integer(
            Int64(encounter.actors.values.filter { $0.presence == .destroyed }.count)),
          "actors": .object(
            encounter.actors.mapValues { actor in
              .object([
                "identity": .string(actor.identity.uuidString),
                "presence": .string(actor.presence.rawValue),
                "energy": .number(actor.body.energy),
                "position": [.inTransit, .arrivalPending].contains(actor.presence)
                  ? .null
                  : .array([
                    .number(actor.body.position.x), .number(actor.body.position.y),
                    .number(actor.body.position.z),
                  ]),
                "npc": scriptNPCSnapshot(actor.body.scriptNPC),
                "missiles": .integer(Int64(actor.body.missiles)),
              ])
            }),
        ])
      })
  }
  /// Returns a later native result. A saved plan is not an admission receipt.
  @inline(never)
  mutating func ensureScriptEncounter(
    _ id: String, pack: ScriptPack, state: inout ScriptInstance,
    worldJobID: UUID? = nil, worldJobPulse: UInt64? = nil
  )
    throws -> (String, [String: ScriptValue])
  {
    let attempt = try makeScriptEncounterAttempt(
      id, pack: pack, state: state, worldJobID: worldJobID, worldJobPulse: worldJobPulse)
    defer { restoreScriptEncounterGeometry(attempt) }
    try prepareScriptEncounterPlan(attempt, id: id, pack: pack, state: state)
    if attempt.alreadyAdmitted {
      return ("encounter.admitted", ["encounter_id": .string(id), "existing": .bool(true)])
    }
    try Self.prepareScriptEncounterAdmissionSource(
      self, attempt: attempt, pack: pack, state: state,
      worldJobID: worldJobID, worldJobPulse: worldJobPulse)
    try Self.prepareScriptEncounterNativeAdmission(self, attempt: attempt)
    return try publishScriptEncounterAdmission(attempt, id: id, state: &state)
  }

  @inline(never)
  private mutating func makeScriptEncounterAttempt(
    _ id: String, pack: ScriptPack, state: borrowing ScriptInstance,
    worldJobID: UUID?, worldJobPulse: UInt64?
  ) throws -> ScriptEncounterAttemptScratch {
    guard state.outcome == .active || worldJobID != nil,
      pack.manifest.capabilities.contains("classic-encounters-v2")
        || pack.manifest.capabilities.contains("profiled-encounters-v2"),
      let definition = pack.manifest.encounters?.first(where: { $0.id == id })
    else {
      throw MissionPackError(
        "Declare the classic encounter capability and an exact encounter definition.")
    }
    try Self.validateScriptEncounterAdmissionAuthority(
      self, id: id, pack: pack, state: state, definition: definition,
      worldJobID: worldJobID, worldJobPulse: worldJobPulse)
    let previousGeometry = withReadOnlyScriptState { $0.geometry }
    return .init(definition: consume definition, previousGeometry: previousGeometry)
  }

  @inline(never)
  private mutating func restoreScriptEncounterGeometry(_ attempt: ScriptEncounterAttemptScratch) {
    if !attempt.publishesGeometry { commander.scriptState.geometry = attempt.previousGeometry }
  }

  /// Each borrowed Game read ends before the next admission phase starts.
  @inline(never)
  private static func validateScriptEncounterAdmissionAuthority(
    _ game: borrowing Game, id: String, pack: ScriptPack, state: borrowing ScriptInstance,
    definition: ScriptEncounterDefinition, worldJobID: UUID?, worldJobPulse: UInt64?
  ) throws {
    _ = try game.missionActorAdmissionAuthority(
      pack: pack, state: state, encounterID: id, galaxy: definition.galaxy,
      system: definition.system, worldJob: worldJobID, pulse: worldJobPulse)
  }

  @inline(never)
  private static func prepareScriptEncounterAdmissionSource(
    _ game: borrowing Game, attempt: ScriptEncounterAttemptScratch,
    pack: ScriptPack, state: borrowing ScriptInstance, worldJobID: UUID?, worldJobPulse: UInt64?
  ) throws {
    attempt.source = try game.preparedMissionActorAdmissionSource(
      pack: pack, state: state, encounter: attempt.encounter!,
      worldJob: worldJobID, pulse: worldJobPulse)
  }

  @inline(never)
  private static func prepareScriptEncounterNativeAdmission(
    _ game: borrowing Game, attempt: ScriptEncounterAttemptScratch
  ) throws {
    attempt.preparation = try game.prepareMissionActorAdmission(attempt.source!)
  }

  /// Actor/body construction storage returns before source/native validation starts.
  @inline(never)
  private mutating func prepareScriptEncounterPlan(
    _ attempt: ScriptEncounterAttemptScratch, id: String, pack: ScriptPack,
    state: borrowing ScriptInstance
  ) throws {
    let definition = attempt.definition
    var plan = state.ownedEncounters[id]
    if plan == nil {
      var actors: [String: ScriptOwnedActor] = [:]
      for spec in definition.actors {
        let identity = ScriptIdentity.uuid(
          "script-actor-v2:\(state.id):\(pack.digest):\(id):\(spec.id)")
        var body = SpaceBody(
          id: -1, hull: spec.hull ?? .cobra, position: .init(spec.x, spec.y, spec.z),
          hostile: spec.hostile)
        if let npcID = spec.npc,
          let definition = pack.manifest.npcs?.first(where: { $0.id == npcID })
        {
          body.scriptNPC = try makeScriptNPC(definition, pack: pack, identity: identity)
          body.energy = definition.energy
          body.missiles = definition.missiles
          body.ecmEnabled = definition.ecm
          body.rotationRate = 0
        }
        body.missionActorID = identity
        body.missionInstanceID = state.id
        try NativeInductionCrewLogPack.initialBody(&body, state: state, alias: spec.id)
        actors[spec.id] = ScriptOwnedActor(
          identity: identity, alias: spec.id, body: body, presence: .prepared)
      }
      plan = ScriptOwnedEncounter(
        id: id, galaxy: definition.galaxy, system: definition.system, actors: actors)
    }
    guard let encounter = plan else { throw MissionPackError("Encounter plan was not prepared.") }
    attempt.encounter = consume encounter
    attempt.alreadyAdmitted = attempt.encounter!.admitted
  }

  /// Native preparation returns before selected-instance staging and commit storage starts.
  @inline(never)
  private mutating func publishScriptEncounterAdmission(
    _ attempt: ScriptEncounterAttemptScratch, id: String, state: inout ScriptInstance
  ) throws -> (String, [String: ScriptValue]) {
    func pending(_ reason: String) -> (String, [String: ScriptValue]) {
      ("encounter.pending", ["encounter_id": .string(id), "reason": .string(reason)])
    }
    switch attempt.preparation! {
    case .pending(let reason):
      Self.publishPendingScriptEncounter(attempt, id: id, state: &state)
      switch reason {
      case .unavailableArrival:
        return pending("unavailableArrival")
      case .outsideLocalBubble:
        return pending("outsideLocalBubble")
      case .nativeUnits:
        return pending("nativeUnits")
      case .allocatorCapacity:
        return pending("allocatorCapacity")
      case .native(let refusal):
        switch refusal {
        case .staleContext:
          return pending("native.staleContext")
        case .populationLimit:
          return pending("native.populationLimit")
        case .reservedCapacity:
          return pending("native.reservedCapacity")
        case .missionSuppression:
          return pending("native.missionSuppression")
        case .unsafePosition:
          return pending("native.unsafePosition")
        case .unqualifiedOriginalHull:
          return pending("native.unqualifiedOriginalHull")
        }
      }
    case .unchanged:
      throw MissionPackError("A fresh prepared cohort requires complete native admission.")
    case .ready(let plan):
      attempt.nativePlan = plan
      try Self.stageScriptEncounterRetention(attempt, id: id, state: state)
      _ = try commitMissionActorAdmission(plan)
      Self.publishStagedScriptEncounter(attempt, state: &state)
      try recordIsolationWorkAdmission(in: &state)
      return (
        "encounter.admitted",
        [
          "encounter_id": .string(id), "count": .integer(Int64(attempt.count)),
          "existing": .bool(false),
        ]
      )
    }
  }

  @inline(never)
  private static func publishPendingScriptEncounter(
    _ attempt: ScriptEncounterAttemptScratch, id: String, state: inout ScriptInstance
  ) {
    state.ownedEncounters[id] = attempt.encounter!
    attempt.publishesGeometry = true
  }

  @inline(never)
  private static func stageScriptEncounterRetention(
    _ attempt: ScriptEncounterAttemptScratch, id: String, state: borrowing ScriptInstance
  ) throws {
    attempt.selected = copy state
    attempt.selected!.ownedEncounters[id] = attempt.encounter!
    attempt.staged = try attempt.nativePlan!.retentionPatch.preparingInstance(attempt.selected!)
    attempt.count = attempt.nativePlan!.sceneBodyIDs.count
  }

  @inline(never)
  private static func publishStagedScriptEncounter(
    _ attempt: ScriptEncounterAttemptScratch, state: inout ScriptInstance
  ) {
    state = attempt.staged!
    attempt.publishesGeometry = true
  }
  /// Native facts retain canonical location/condition and never infer death from disappearance.
  @discardableResult
  mutating func persistScriptActors(unloading: Bool = false) -> Set<Int> {
    let refused = persistC03ActorsPreservingRefusals(unloading: unloading)
    persistGenericScriptActors(unloading: unloading)
    return refused
  }

  @discardableResult
  mutating func persistC03ActorsPreservingRefusals(unloading: Bool = false) -> Set<Int> {
    do {
      try captureC03OwnedActors(unloading: unloading)
      return []
    } catch {
      return c03RecognizedBodyIDs().union(c03WakeRecognizedBodyIDs())
        .union(c03RegisterRecognizedBodyIDs()).union(c03EvacuationRecognizedBodyIDs())
    }
  }

  private mutating func persistGenericScriptActors(unloading: Bool) {
    guard !commander.scriptState.instances.isEmpty else { return }
    refreshScriptPersistenceStation()
    let system = missionActorAdmissionSystemIdentity
    guard
      let anchor = Self.resolveScriptAnchor(
        bodies: bodies, frame: scriptReferenceFrame, galaxy: system.galaxy, system: system.system)
    else { return }
    persistScriptShots(anchor: anchor, unloading: unloading)
    captureScriptActors(anchor: anchor, unloading: unloading)
  }

  // Station loss and reference-frame refresh finish before actor capture allocates its records.
  @inline(never)
  private mutating func refreshScriptPersistenceStation() {
    if let actual = bodies.first(where: { $0.id == 0 && $0.hull == .station }) {
      if actual.energy <= 0 { recordScriptWorldResourceLoss(actual) }
      if commander.scriptState.stationResources[contractStation.key] != nil {
        commander.scriptState.stationResources[contractStation.key]?.energy = max(0, actual.energy)
      }
      scriptReferenceFrame = ScriptReferenceFrame(
        galaxy: commander.galaxy, system: commander.system, station: actual)
    }
  }

  @inline(never)
  private mutating func captureScriptActors(anchor: borrowing SpaceBody, unloading: Bool) {
    if unloading {
      for body in bodies where body.missionActorID != nil && body.energy <= 0 {
        recordScriptActorRemoval(body, destroyed: true)
      }
    }
    let actual = Dictionary(
      bodies.compactMap { body in body.missionActorID.map { ($0, body) } },
      uniquingKeysWith: { first, _ in first })
    for instanceID in commander.scriptState.instances.keys {
      guard var instance = commander.scriptState.instances[instanceID] else { continue }
      if NativeHollowManifestCommission.marked(instance) { continue }
      for encounterID in instance.ownedEncounters.keys {
        guard var encounter = instance.ownedEncounters[encounterID], encounter.admitted
        else { continue }
        for alias in encounter.actors.keys {
          guard var saved = encounter.actors[alias],
            ![.destroyed, .inTransit, .arrivalPending].contains(saved.presence),
            saved.location(in: encounter) == systemIdentity,
            let body = actual[saved.identity], body.missionInstanceID == instanceID
          else { continue }
          captureIsolationWorkPose(body, in: &instance)
          saved.body = body
          saved.body.energy = max(0, body.energy)
          saved.body.position = anchor.orientation.inverse(body.position - anchor.position)
          saved.body.orientation = body.orientation.relative(to: anchor.orientation)
          saved.body.scriptNPC?.velocity = anchor.orientation.inverse(
            body.scriptNPC?.velocity ?? .init(0, 0, 0))
          if unloading && saved.presence == .present { saved.presence = .unloaded }
          encounter.actors[alias] = saved
        }
        instance.ownedEncounters[encounterID] = encounter
      }
      commander.scriptState.instances[instanceID] = instance
    }
  }
  /// Every cohort's hard native/source checks precede any restoration publication. Plans are
  /// deliberately discarded here; later preparation uses fresh counters after earlier commits.
  @discardableResult
  func validateRetainedMissionActorRestoration() throws -> [MissionActorAdmissionSource] {
    let sources = try retainedMissionActorAdmissionSources()
    try validateRetainedMissionActorSources(sources)
    return sources
  }

  /// Source collection returns before the later admission-validation loop reserves its values.
  @inline(never)
  private func validateRetainedMissionActorSources(
    _ sources: borrowing [MissionActorAdmissionSource]
  ) throws {
    for index in sources.indices { _ = try prepareMissionActorAdmission(sources[index]) }
  }

  /// Reprojects the same world actor after genuine native launch/arrival/camera travel.
  mutating func restoreScriptActors() throws {
    try validateRetainedMissionProjectileRestoration()
    let sources = try validateRetainedMissionActorRestoration()
    guard !retainedMissionActorInstances.isEmpty, !docked, let anchor = scriptAnchor else {
      return
    }
    // All hard source/current-binding checks finished before even the station can reappear.
    restoreNativeMissionStationIfEligible()
    try restoreRetainedMissionActors(sources)
    try restoreScriptShots(anchor: anchor)
  }

  /// Retire actor admission temporaries before the subsequent projectile restoration phase.
  @inline(never)
  private mutating func restoreRetainedMissionActors(
    _ sources: borrowing [MissionActorAdmissionSource]
  ) throws {
    for index in sources.indices {
      let source = sources[index]
      switch try prepareMissionActorAdmission(source) {
      case .pending, .unchanged: continue
      case .ready(let plan):
        let instanceID = source.instanceID
        guard let current = withReadOnlyScriptState({ $0.instances[instanceID] }) else {
          throw MissionPackError("Retained actor owner disappeared before native preparation.")
        }
        let staged = try plan.retentionPatch.preparingInstance(current)
        _ = try commitMissionActorAdmission(plan)
        commander.scriptState.instances[instanceID] = staged
      }
    }
  }
  mutating func recordScriptActorRemoval(_ body: SpaceBody, destroyed: Bool) {
    if isC03EvacuationBody(body) {
      do { try recordC03EvacuationRemoval(body, destroyed: destroyed) } catch {
        notify("ORIGINAL EVACUATION STATE UNAVAILABLE - REMOVAL NOT RETAINED", voiced: false)
      }
      return
    }
    if isC03RegisterBody(body) {
      do { try recordC03RegisterRemoval(body, destroyed: destroyed) } catch {
        notify("ORIGINAL REGISTER STATE UNAVAILABLE - REMOVAL NOT RETAINED", voiced: false)
      }
      return
    }
    if isC03WakeBody(body) {
      do { try recordC03WakeActorRemoval(body, destroyed: destroyed) } catch {
        notify("ORIGINAL WAKE STATE UNAVAILABLE - REMOVAL NOT RETAINED", voiced: false)
      }
      return
    }
    if isC03OriginalBody(body) {
      do { try recordC03ActorRemoval(body, destroyed: destroyed) } catch {
        notify("ORIGINAL FREIGHTER STATE UNAVAILABLE - REMOVAL NOT RETAINED", voiced: false)
      }
      return
    }
    if destroyed { recordScriptWorldResourceLoss(body) }
    recordScriptShotRemoval(body)
    guard let identity = body.missionActorID, let instanceID = body.missionInstanceID,
      var instance = commander.scriptState.instances[instanceID]
    else { return }
    for key in instance.ownedEncounters.keys.sorted() {
      guard var encounter = instance.ownedEncounters[key], encounter.admitted,
        let alias = encounter.actors.first(where: { $0.value.identity == identity })?.key,
        var actor = encounter.actors[alias], actor.presence == .present, actor.body.id == body.id
      else { continue }
      if destroyed {
        guard body.energy <= 0 else { return }
        let previous = actor.body
        actor.body = body
        actor.body.energy = 0
        if let anchor = scriptAnchor {
          actor.body.position = anchor.orientation.inverse(body.position - anchor.position)
          actor.body.orientation = body.orientation.relative(to: anchor.orientation)
          actor.body.scriptNPC?.velocity = anchor.orientation.inverse(
            body.scriptNPC?.velocity ?? .init(0, 0, 0))
        } else {
          // Without a station frame, retain the last canonical pose while preserving actual
          // terminal condition. Never label the current camera pose as station-relative.
          actor.body.position = previous.position
          actor.body.orientation = previous.orientation
          actor.body.scriptNPC?.velocity = previous.scriptNPC?.velocity ?? .init(0, 0, 0)
        }
        actor.presence = .destroyed
        actor.destroyedByPlayer = body.destroyedByPlayer == true
      } else {
        actor.presence = .outside
      }
      encounter.actors[alias] = actor
      instance.ownedEncounters[key] = encounter
      captureIsolationWorkPose(body, in: &instance)
      if destroyed { recordIsolationWorkModuleLoss(body, in: &instance) }
      commander.scriptState.instances[instanceID] = instance
      emitScriptEvent(
        destroyed ? "actor.destroyed" : "actor.removed",
        values: [
          "actor_id": .string(identity.uuidString), "alias": .string(alias),
          "encounter_id": .string(key),
          "destroyed_by_player": .bool(body.destroyedByPlayer == true),
        ], only: instanceID, drain: false)
      return
    }
  }
}

extension Commander {
  /// Borrow only the same immutable source fields before nested admission validation.
  /// This transient tuple is neither an authority token nor a cached state owner.
  fileprivate func missionActorAdmissionSourceValues() -> (
    instances: [UUID: ScriptInstance], geometry: [String: ShipDesign], galaxy: Int, system: Int
  ) {
    let state = scriptState
    return (state.instances, state.geometry, galaxy, system)
  }
}

extension Game {
  /// A real facility launches its retained original hull via the existing native admission policy.
  func inductionArkBerthAdmissionSource(_ id: UUID) throws -> MissionActorAdmissionSource {
    guard !docked, !paused, let owner = commander.scriptState.instances[id],
      owner.definition == NativeInductionArkPack.stateID,
      owner.digest == NativeInductionArkPack.digest,
      let state = owner.savedNativeArk, let dock = state.dockedContact, state.loss == nil,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station,
      let pack = nativeInductionArkPack,
      let encounter = owner.ownedEncounters[NativeInductionArkPack.encounter], encounter.admitted,
      var actor = encounter.actors[NativeInductionArkPack.alias], actor.presence == .unloaded,
      actor.body.energy > 0, actor.identity == state.authorization.actor,
      !bodies.contains(where: { $0.missionActorID == actor.identity }),
      let exit = currentNativeMainStationAnchor(at: commander.flightSimulation.physicalTime),
      let anchor = scriptAnchor, let profile = actor.body.scriptNPC?.fit.definition
    else { throw SaveError.invalidCommander }
    let definition = try validateMissionActorAdmissionEncounter(
      mode: .retained, pack: pack, state: owner, encounter: encounter)
    guard let spec = definition.actors.first(where: { $0.id == actor.alias }) else {
      throw SaveError.invalidCommander
    }
    let pose = commander.flightSimulation.pose
    let direction = exit.exitDirection.unit
    var orientation = Basis3()
    orientation.z = direction
    orientation.y = exit.orientation.y
    orientation.x = orientation.y.cross(orientation.z).unit
    actor.body.position = anchor.orientation.inverse(
      pose.shipPoint(exit.exitPosition) - anchor.position)
    actor.body.orientation = orientation.relative(to: pose.orientation).relative(
      to: anchor.orientation)
    let stationVelocity =
      commander.nativeStations?.stationInertia.first(where: {
        if case .main(let identity) = $0.station { return identity == dock.station }
        return false
      })?.velocity ?? .init(0, 0, 0)
    guard stationVelocity.length <= profile.speed else {
      throw NativeMissionActorAdmissionError.invalidCondition
    }
    actor.body.scriptNPC?.velocity = anchor.orientation.inverse(pose.shipVector(stationVelocity))
    let goal = exit.position + direction * 1200
    actor.body.scriptNPC?.intent = .init(
      request: "native-ark-berth-exit", mode: .approach, target: nil, player: false,
      offset: anchor.orientation.inverse(pose.shipPoint(goal) - anchor.position),
      speed: min(1, 144 / profile.speed), tolerance: 50)
    let template = try Self.missionActorAdmissionTemplate(
      actor, specification: spec,
      npcDefinitions: pack.manifest.npcs ?? [], installedModels: pack.models,
      geometry: commander.scriptState.geometry)
    return .init(
      mode: .retained, authority: .inductionArkBerth(id), instance: owner, pack: pack,
      encounter: encounter, definition: definition, actors: [template],
      installedBaseEncounter: encounter)
  }
}

extension Game {
  func inductionRescueBerthAdmissionSource(_ id: UUID) throws -> MissionActorAdmissionSource {
    guard !docked, !paused, let owner = commander.scriptState.instances[id],
      owner.definition == NativeInductionCrewLogPack.stateID,
      owner.digest == NativeInductionCrewLogPack.digest,
      let state = owner.savedNativeCrewLog, let flight = state.flight,
      let dock = flight.dockedContact, state.livingCrew.count == 2,
      case .living(let facility) = nativeOriginalMainStationDestination,
      facility.identity == dock.station,
      let pack = nativeInductionCrewLogPack,
      let encounter = owner.ownedEncounters[NativeInductionCrewLogPack.encounter],
      encounter.admitted,
      var actor = encounter.actors["launch"], actor.presence == .unloaded,
      actor.body.energy > 0, actor.identity == flight.authorization.actor,
      !bodies.contains(where: { $0.missionActorID == actor.identity }),
      let exit = currentNativeMainStationAnchor(at: commander.flightSimulation.physicalTime),
      let anchor = scriptAnchor, let profile = actor.body.scriptNPC?.fit.definition
    else { throw SaveError.invalidCommander }
    let definition = try validateMissionActorAdmissionEncounter(
      mode: .retained, pack: pack, state: owner, encounter: encounter)
    guard let spec = definition.actors.first(where: { $0.id == actor.alias }) else {
      throw SaveError.invalidCommander
    }
    let pose = commander.flightSimulation.pose
    let direction = exit.exitDirection.unit
    var orientation = Basis3()
    orientation.z = direction
    orientation.y = exit.orientation.y
    orientation.x = orientation.y.cross(orientation.z).unit
    actor.body.position = anchor.orientation.inverse(
      pose.shipPoint(exit.exitPosition) - anchor.position)
    actor.body.orientation = orientation.relative(to: pose.orientation).relative(
      to: anchor.orientation)
    let stationVelocity =
      commander.nativeStations?.stationInertia.first(where: {
        if case .main(let identity) = $0.station { return identity == dock.station }
        return false
      })?.velocity ?? .init(0, 0, 0)
    guard stationVelocity.length <= profile.speed else {
      throw NativeMissionActorAdmissionError.invalidCondition
    }
    actor.body.scriptNPC?.velocity = anchor.orientation.inverse(pose.shipVector(stationVelocity))
    let goal = exit.position + direction * 1200
    actor.body.scriptNPC?.intent = .init(
      request: "native-rescue-berth-exit", mode: .approach, target: nil, player: false,
      offset: anchor.orientation.inverse(pose.shipPoint(goal) - anchor.position),
      speed: min(1, 144 / profile.speed), tolerance: 50)
    let template = try Self.missionActorAdmissionTemplate(
      actor, specification: spec,
      npcDefinitions: pack.manifest.npcs ?? [], installedModels: pack.models,
      geometry: commander.scriptState.geometry)
    return .init(
      mode: .retained, authority: .inductionRescueBerth(id), instance: owner, pack: pack,
      encounter: encounter, definition: definition, actors: [template],
      installedBaseEncounter: encounter)
  }
}

extension Game {
  /// Closed native C01 extension; no caller-supplied body can add another encounter or source.
  func c01SurveyorAdmissionSource(
    pack: ScriptPack, state: ScriptInstance, encounter: ScriptOwnedEncounter
  ) throws -> MissionActorAdmissionSource {
    guard pack.manifest.stateID == NativeGlassMeridian.stateID,
      pack.digest == NativeGlassMeridian.digest,
      NativeC01Surveyor.definition(state, id: encounter.id) != nil,
      let opening = state.savedGlassMeridian, NativeC01Surveyor.shapeValid(opening),
      NativeGlassMeridian.readingsValid(opening), NativeGlassMeridian.lossesValid(opening)
    else { throw NativeMissionActorAdmissionError.invalidTemplate }
    return try preparedMissionActorAdmissionSource(pack: pack, state: state, encounter: encounter)
  }
}

extension Game {
  func c01TimingStandardAdmissionSource(
    pack: ScriptPack, state: ScriptInstance,
    encounter: ScriptOwnedEncounter
  ) throws -> MissionActorAdmissionSource {
    guard pack.manifest.stateID == NativeGlassMeridian.stateID,
      pack.digest == NativeGlassMeridian.digest,
      NativeC01TimingStandard.definition(state, id: encounter.id) != nil,
      let opening = state.savedGlassMeridian, let leaf = opening.timingStandard,
      NativeC01TimingStandardSave.historyJoins(leaf, mission: state, commander: commander),
      opening.surveyor?.held == true, leaf.capture == nil, leaf.loss == nil
    else {
      throw NativeMissionActorAdmissionError.invalidTemplate
    }
    return try preparedMissionActorAdmissionSource(pack: pack, state: state, encounter: encounter)
  }
}

extension Game {
  func c01LaneRepairAdmissionSource(
    pack: ScriptPack, state: ScriptInstance, encounter: ScriptOwnedEncounter
  ) throws -> MissionActorAdmissionSource {
    guard pack.manifest.stateID == NativeGlassMeridian.stateID,
      pack.digest == NativeGlassMeridian.digest,
      NativeC01LaneRepair.definition(state, id: encounter.id) != nil,
      let opening = state.savedGlassMeridian, let leaf = opening.laneRepair,
      NativeC01LaneRepairSave.historyJoins(leaf, mission: state, commander: commander),
      opening.surveyor?.held == true, opening.timingStandard?.held == true,
      leaf.installation == nil
    else { throw NativeMissionActorAdmissionError.invalidTemplate }
    return try preparedMissionActorAdmissionSource(pack: pack, state: state, encounter: encounter)
  }
}

extension Game {
  func c01ClinicSourceAdmissionSource(
    pack: ScriptPack, state: ScriptInstance, encounter: ScriptOwnedEncounter
  ) throws -> MissionActorAdmissionSource {
    guard pack.manifest.stateID == NativeGlassMeridian.stateID,
      pack.digest == NativeGlassMeridian.digest,
      encounter.id == NativeC01ClinicEscort.sourceEncounter,
      NativeC01ClinicEscort.definition(state, id: encounter.id) != nil,
      let opening = state.savedGlassMeridian, let leaf = opening.clinicEscort,
      NativeC01ClinicEscortSave.historyJoins(leaf, mission: state, commander: commander),
      opening.surveyor?.held == true, opening.laneRepair?.installation != nil,
      leaf.arrival == nil
    else { throw NativeMissionActorAdmissionError.invalidTemplate }
    return try preparedMissionActorAdmissionSource(pack: pack, state: state, encounter: encounter)
  }
}


extension ScriptOwnedEncounter {
  private enum CodingKeys: String, CodingKey, CaseIterable { case id, galaxy, system, admitted, actors }

  public init(from decoder: any Decoder) throws {
    let fields = try decoder.container(keyedBy: EncounterRecordKey.self)
    guard Set(fields.allKeys.map(\.stringValue)).isSubset(of: Set(CodingKeys.allCases.map(\.rawValue)))
    else { throw SaveError.invalidCommander }
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let actors = try values.nestedContainer(keyedBy: EncounterRecordKey.self, forKey: .actors)
    guard (1...128).contains(actors.allKeys.count) else { throw SaveError.invalidCommander }
    self.init(
      id: try values.decode(String.self, forKey: .id),
      galaxy: try values.decode(Int.self, forKey: .galaxy),
      system: try values.decode(Int.self, forKey: .system),
      admitted: try values.decode(Bool.self, forKey: .admitted),
      actors: try values.decode([String: ScriptOwnedActor].self, forKey: .actors))
  }

  private struct EncounterRecordKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
  }
}

final class C03ActorAdmissionContext: Sendable {
  let pin: NativeHollowManifestInstalledCase
  let initial: Bool
  let reference: ShipPose
  let anchors: SystemAnchors
  let flight: FlightSimulationState
  let station: SpaceBody
  let retention: ScriptOwnedEncounter
  let installedEncounter: ScriptOwnedEncounter?
  let declarations: ScriptEncounterDefinition
  let profiles: [ScriptNPCDefinition]
  let designs: [String: ShipDesign]
  let geometry: [String: ShipDesign]
  let projections: [UUID: NativeC03RetainedMotion.AdmissionProjection]
  let lives: [NativeHollowManifestState.Slot: NativeHollowManifestOriginalLife]

  fileprivate init(
    pin: NativeHollowManifestInstalledCase, initial: Bool, reference: ShipPose,
    anchors: SystemAnchors, flight: FlightSimulationState, station: SpaceBody,
    retention: ScriptOwnedEncounter, declarations: ScriptEncounterDefinition,
    profiles: [ScriptNPCDefinition], designs: [String: ShipDesign],
    geometry: [String: ShipDesign],
    projections: [UUID: NativeC03RetainedMotion.AdmissionProjection],
    lives: [NativeHollowManifestState.Slot: NativeHollowManifestOriginalLife]
  ) {
    self.pin = pin
    self.initial = initial
    self.reference = reference
    self.anchors = anchors
    self.flight = flight
    self.station = station
    self.retention = retention
    installedEncounter = initial ? nil : retention
    self.declarations = declarations
    self.profiles = profiles
    self.designs = designs
    self.geometry = geometry
    self.projections = projections
    self.lives = lives
  }
}

private final class C03PreparedActorInstall: Sendable {
  let pin: NativeHollowManifestInstalledCase
  let expected: ScriptInstance
  let selected: ScriptInstance
  let previousGeometry: [String: ShipDesign]
  let additions: [String: ShipDesign]

  init(
    pin: NativeHollowManifestInstalledCase, expected: ScriptInstance, selected: ScriptInstance,
    previousGeometry: [String: ShipDesign], additions: [String: ShipDesign]
  ) {
    self.pin = pin
    self.expected = expected
    self.selected = selected
    self.previousGeometry = previousGeometry
    self.additions = additions
  }

  static func eventCapacity(next: UInt64, pending: Int, demand: Int) -> Bool {
    demand >= 0 && demand <= 2 && pending >= 0 && pending <= 4096 - demand
      && next <= UInt64(Int64.max) - 1 - UInt64(demand)
  }
}


extension Game {
  @inline(never)
  private func c03ActorAdmissionSource() throws -> MissionActorAdmissionSource? {
    guard !docked, systemIdentity == NativeHollowManifestDefinition.freighterWorld,
      withReadOnlyScriptState({ $0.instances.values.contains(where: {
        NativeHollowManifestCommission.marked($0)
      }) })
    else { return nil }
    let pin = try hollowManifestInstalledCase()
    guard let instance = withReadOnlyScriptState({ $0.instances[pin.missionID] }),
      let pack = scriptPack(for: instance)
    else { throw SaveError.invalidCommander }
    guard let station = scriptAnchor, station.energy > 0, bodies.contains(station),
      let anchors = commander.flightSimulation.anchors, let projected = gameplayContext(),
      NativeC03AnchorFrames.matches(
        canonical: anchors, current: projected, flight: commander.flightSimulation, station: station)
    else { return nil }
    let flight = withReadOnlyCommander({ $0.flightSimulation })
    let initial = pin.state.phase == .unadmitted
    var lives: [NativeHollowManifestState.Slot: NativeHollowManifestOriginalLife] = [:]
    for slot in NativeHollowManifestState.Slot.allCases {
      if pin.state.terminals.contains(where: { $0.effect.admission.slot == slot }) { continue }
      let life = try hollowManifestOriginalLife(slot: slot)
      guard acceptsHollowManifestOriginalLife(life), life.pin.missionID == pin.missionID else {
        throw SaveError.invalidCommander
      }
      lives[slot] = life
    }
    let layout = try NativeC03FreighterRoute.candidateLayout(
      anchors: initial ? anchors : pin.state.routeAnchors)
    var axes = Basis3()
    axes.x = layout.u
    axes.y = layout.v
    axes.z = layout.normal
    let reference =
      initial
      ? ShipPose(position: (layout.firstCentre + layout.secondCentre) * 0.5, orientation: axes)
      : pin.state.sourceFrame
    guard let reference else { throw SaveError.invalidCommander }
    try NativeC03RetainedMotion.validateAdmissionFrames(
      flight: flight, reference: reference, station: station)
    let declared = try NativeHollowManifestCommission.admissionDeclarations(
      birth: pin.state.birth, anchors: initial ? anchors : pin.state.routeAnchors!,
      sourceFrame: reference, encounter: NativeHollowManifestCommission.encounter)
    var geometry = withReadOnlyScriptState({ $0.geometry })
    var hashes: [String: String] = [:]
    for (name, design) in declared.designs {
      let digest: String
      if let first = pin.state.admissions.first {
        digest =
          name == NativeHollowManifestCommission.rootModel
          ? first.geometry.rootGeometryHash : first.geometry.sealGeometryHash
      } else {
        digest = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      }
      if let installed = geometry[digest] {
        guard installed == design else { throw SaveError.invalidCommander }
      } else {
        geometry[digest] = design
      }
      hashes[name] = digest
    }
    var encounter: ScriptOwnedEncounter
    if initial {
      guard instance.ownedEncounters.isEmpty else { throw SaveError.invalidCommander }
      var actors: [String: ScriptOwnedActor] = [:]
      for slot in NativeHollowManifestState.Slot.allCases {
        let logical = NativeHollowManifestCommission.logicalActor(
          mission: pin.missionID, slot: slot)
        guard let spec = declared.encounter.actors.first(where: { $0.id == slot.rawValue }),
          let profile = declared.profiles.first(where: { $0.id == spec.npc })
        else { throw SaveError.invalidCommander }
        let centre = slot == .first ? layout.firstCentre : layout.secondCentre
        var body = SpaceBody(
          id: -1, hull: .cobra,
          position: station.orientation.inverse(flight.pose.shipPoint(centre) - station.position),
          hostile: false)
        body.orientation = axes.relative(to: flight.pose.orientation).relative(
          to: station.orientation)
        body.energy = pin.state.birth.fit.hullEnergy
        body.missiles = 0
        body.ecmEnabled = false
        body.rotation = 0
        body.rotationRate = 0
        body.missionInstanceID = pin.missionID
        body.missionActorID = logical
        body.scriptNPC = .init(
          fit: .init(definition: profile, models: hashes), fuel: 0,
          guns: [:],
          components: [
            slot.rawValue: .init(
              identity: NativeHollowManifestCommission.component(logicalActor: logical, slot: slot),
              energy: pin.state.birth.fit.sealEnergy, guns: [:])
          ])
        actors[slot.rawValue] = .init(
          identity: logical, alias: slot.rawValue, body: body, presence: .prepared)
      }
      encounter = .init(id: declared.encounter.id, galaxy: 1, system: 113, actors: actors)
    } else {
      guard NativeHollowManifestCommission.admittedActorClaimsMatch(instance),
        let owned = instance.ownedEncounters[NativeHollowManifestCommission.encounter]
      else { throw SaveError.invalidCommander }
      encounter = owned
    }
    var projections: [UUID: NativeC03RetainedMotion.AdmissionProjection] = [:]
    if !initial {
      for actor in encounter.actors.values
      where [.outside, .unloaded].contains(actor.presence) && actor.body.energy > 0 {
        guard
          let latest = pin.state.latestAdmissions.first(where: { $0.slot.rawValue == actor.alias }),
          let admission = pin.state.admissions.first(where: { $0.reference == latest })
        else { throw SaveError.invalidCommander }
        projections[actor.identity] = try NativeC03RetainedMotion.projectForAdmission(
          owned: actor, original: admission.original, reference: reference, flight: flight,
          station: station)
      }
    }
    let context = C03ActorAdmissionContext(
      pin: pin, initial: initial, reference: reference,
      anchors: initial ? anchors : pin.state.routeAnchors!, flight: flight, station: station,
      retention: encounter, declarations: declared.encounter, profiles: declared.profiles,
      designs: declared.designs, geometry: geometry, projections: projections, lives: lives)
    var templates: [MissionActorAdmissionTemplate] = []
    for spec in declared.encounter.actors.sorted(by: { $0.id < $1.id }) {
      guard let actor = encounter.actors[spec.id] else { throw SaveError.invalidCommander }
      let condition = initial ? Self.c03InitialNativeCondition(fit: pin.state.birth.fit) : nil
      let base = try Self.missionActorAdmissionTemplate(
        actor, specification: spec,
        npcDefinitions: declared.profiles, installedModels: declared.designs, geometry: geometry,
        legacy: nil, initialNativeCondition: condition)
      let canonical = projections[actor.identity]?.body ?? base.canonicalBody
      if initial {
        try Self.validatePreparedMissionActorCondition(
          actor, spec: spec, template: base,
          legacy: nil,
          preparedPose: .init(position: canonical.position, orientation: canonical.orientation))
      }
      templates.append(
        .init(
          actor: actor, canonicalBody: canonical,
          maximumHullEnergy: base.maximumHullEnergy, declaredHostile: base.declaredHostile,
          parts: base.parts, minimum: base.minimum, maximum: base.maximum, radius: base.radius,
          nativeUnits: base.nativeUnits, initialNativeCondition: condition, c03Context: context))
    }
    return .init(
      mode: initial ? .prepared : .retained,
      authority: initial ? .c03Initial : .c03Retained, instance: instance, pack: pack,
      encounter: encounter, definition: declared.encounter, actors: templates,
      installedBaseEncounter: initial ? nil : encounter, c03Context: context)
  }

  private static func c03InitialNativeCondition(fit: NativeHollowManifestSourceBirth.InspectionFit)
    -> NPCState
  {
    var npc = NPCState(
      role: .mission, origin: NativeHollowManifestDefinition.freighterWorld,
      destination: NativeHollowManifestDefinition.freighterWorld)
    npc.hasFuelScoops = false
    npc.resources = .init(
      profile: .nativeHull, energyCapacity: fit.hullEnergy,
      energyRecharge: fit.recharge, frontCapacity: 0, rearCapacity: 0, shieldRecharge: 0,
      frontShield: 0, rearShield: 0, heatCapacity: 240, heatCooling: 12, fuel: 0, fuelCapacity: 0)
    return npc
  }
}


extension C03ActorAdmissionContext {
  func projectedIntent(
    alias: String, logical: UUID, actor: ActorIdentity,
    flight: FlightSimulationState
  ) throws -> ScriptNPCIntent {
    guard let slot = NativeHollowManifestState.Slot(rawValue: alias),
      let routeSlot = NativeC03FreighterRoute.Slot(rawValue: alias),
      let original = pin.state.birth.originals.first(where: { $0.slot == slot }),
      let profile = profiles.first(where: { $0.components?.first?.id == alias })
    else { throw SaveError.invalidCommander }
    let endpoints: NativeC03FreighterRoute.Endpoints
    let target: NativeC03FreighterRoute.Waypoint
    let revision: UInt64
    if initial {
      let layout = try NativeC03FreighterRoute.candidateLayout(anchors: anchors)
      endpoints = slot == .first ? layout.first : layout.second
      target = .first
      revision = 1
    } else {
      guard let route = pin.state.routes.first(where: { $0.admission.slot == slot }),
        route.admission.revision < UInt64(Int64.max) - 1
      else { throw SaveError.invalidCommander }
      endpoints = try .init(first: route.first, second: route.second)
      target = route.target == .first ? .first : .second
      revision = route.admission.revision + 1
    }
    let binding = try NativeC03FreighterRoute.Binding(
      source: original.source,
      mission: pin.missionID, sourceRevision: revision, actor: logical, actorAlias: alias,
      physicalActor: actor, slot: routeSlot, endpoints: endpoints)
    return try NativeC03FreighterRouteRuntime.projectIntent(
      binding: binding, target: target,
      flight: flight, station: station, profile: profile)
  }
}

extension Game {
  @inline(never)
  fileprivate func prepareC03RetentionPatch(
    source: borrowing MissionActorAdmissionSource, context: C03ActorAdmissionContext,
    bodyIDs: [UUID: Int], bodies admitted: [SpaceBody], flight: FlightSimulationState
  ) throws -> MissionActorRetentionPatch {
    let sourceInstanceID = source.instanceID
    guard acceptsHollowManifestInstalledCase(context.pin),
      let expected = withReadOnlyScriptState({ $0.instances[sourceInstanceID] }),
      expected.ownedEncounters[source.encounterID] == context.installedEncounter,
      (1...2).contains(admitted.count), admitted.count == bodyIDs.count,
      Set(admitted.compactMap(\.missionActorID)) == Set(bodyIDs.keys),
      Set(admitted.map(\.id)).count == admitted.count,
      !context.initial || admitted.count == 2,
      context.pin.state.nextSourceSequence < UInt64(Int64.max) - UInt64(admitted.count)
    else { throw SaveError.invalidCommander }
    var updated = context.retention
    var admissions: [NativeHollowManifestState.Admission] = []
    for slot in NativeHollowManifestState.Slot.allCases {
      guard var owned = updated.actors[slot.rawValue] else { throw SaveError.invalidCommander }
      guard let bodyID = bodyIDs[owned.identity] else { continue }
      guard
        let body = admitted.first(where: { $0.id == bodyID && $0.missionActorID == owned.identity }
        ),
        body.missionInstanceID == source.instanceID, let physical = body.physical,
        let spawn = physical.spawnIdentity, let npc = body.scriptNPC,
        let component = npc.components[slot.rawValue],
        let original = context.pin.state.birth.originals.first(where: { $0.slot == slot }),
        let rootHash = npc.fit.models[NativeHollowManifestCommission.rootModel],
        let sealHash = npc.fit.models[NativeHollowManifestCommission.sealModel]
      else { throw SaveError.invalidCommander }
      let old = context.pin.state.latestAdmissions.first(where: { $0.slot == slot })
      guard context.initial || (old != nil && old!.revision < UInt64(Int64.max) - 1) else {
        throw SaveError.invalidCommander
      }
      let revision = context.initial ? 1 : old!.revision + 1
      let binding = NativeHollowManifestOriginalSealBinding(
        slot: slot,
        mission: source.instanceID, owner: context.pin.owner,
        source: original.source, hull: original.hull, captain: original.captain,
        seal: original.seal, master: original.master, imprint: original.imprint,
        actor: physical.identity, component: component.identity, sourceRevision: revision,
        issuedSequence: context.pin.state.nextSourceSequence + UInt64(admissions.count),
        issuedTime: flight.physicalTime)
      let geometry = NativeHollowManifestSealGeometryReference(
        rootGeometryHash: rootHash,
        sealGeometryHash: sealHash, revision: 1,
        componentPose: .init(
          position: NativeC03SealGeometry.componentPosition,
          orientation: NativeC03SealGeometry.componentOrientation), rootScale: 1, componentScale: 1)
      admissions.append(
        .init(
          reference: .init(slot: slot, revision: revision),
          original: binding, logicalActor: owned.identity, spawn: spawn, geometry: geometry))
      // The native allocator supplied these fresh addresses. Only this scratch is modified.
      owned.body.id = body.id
      owned.body.physical = physical
      owned.presence = .present
      owned.body = try NativeC03RetainedMotion.capture(
        body: body, owned: owned,
        original: binding, flight: flight, reference: context.reference)
      if let projection = context.projections[owned.identity] {
        guard
          NativeC03RetainedMotion.preparedAdmissionMatches(
            projection,
            original: binding, owned: owned, body: body, flight: flight)
        else { throw NativeMissionActorAdmissionError.invalidCondition }
      }
      updated.actors[slot.rawValue] = owned
    }
    let next: NativeHollowManifestState
    if context.initial {
      next = try .preparingFirstAdmission(
        from: context.pin.state, admissions: admissions,
        stagedFlight: flight, sourceFrame: context.reference, anchors: context.anchors,
        encounter: source.encounterID, initialTargets: [.first: .first, .second: .first])
    } else {
      next = try .preparingRetainedAdmission(
        from: context.pin.state,
        admissions: admissions, stagedFlight: flight)
    }
    updated.admitted = true
    var selected = expected
    selected.savedHollowManifest = next
    selected.ownedEncounters[source.encounterID] = updated
    // G2 intentionally refuses admitted prefixes until the actual producer/life owner composes.
    guard updated.valid, NativeHollowManifestCommission.admittedActorClaimsMatch(selected),
      NativeHollowManifestCommission.prefixValid(selected)
    else { throw SaveError.invalidCommander }
    let previous = withReadOnlyScriptState({ $0.geometry })
    var additions: [String: ShipDesign] = [:]
    for (hash, design) in context.geometry where previous[hash] == nil { additions[hash] = design }
    guard additions.count <= 2 else { throw SaveError.invalidCommander }
    let install = C03PreparedActorInstall(
      pin: context.pin, expected: expected, selected: selected,
      previousGeometry: previous, additions: additions)
    return .init(source: source, updated: updated, c03Install: install)
  }

  mutating func publishC03AdmissionGeometry(_ patch: MissionActorRetentionPatch) {
    guard let install = patch.c03Install else { return }
    for (hash, design) in install.additions { commander.scriptState.geometry[hash] = design }
  }
}


private final class C03PreparedCapture {
  let pin: NativeHollowManifestInstalledCase
  let selected: ScriptInstance
  let flight: FlightSimulationState
  let observed: [SpaceBody]
  let event: (body: SpaceBody, alias: String, destroyed: Bool)?

  init(
    pin: NativeHollowManifestInstalledCase, selected: ScriptInstance,
    flight: FlightSimulationState, observed: [SpaceBody],
    event: (body: SpaceBody, alias: String, destroyed: Bool)?
  ) {
    self.pin = pin
    self.selected = selected
    self.flight = flight
    self.observed = observed
    self.event = event
  }
}

extension Game {
  func isC03OriginalBody(_ body: borrowing SpaceBody) -> Bool {
    guard let id = body.missionInstanceID, let instance = commander.scriptState.instances[id]
    else { return false }
    return NativeHollowManifestCommission.marked(instance)
  }

  /// Fallible C03 work precedes all generic persistence mutations and every writer call.
  mutating func persistScriptActorsChecked(unloading: Bool = false) throws {
    try captureC03OwnedActors(unloading: unloading)
    persistGenericScriptActors(unloading: unloading)
  }

  @inline(never)
  private func prepareC03Capture(
    unloading: Bool,
    removal: SpaceBody? = nil, destroyed: Bool = false
  ) throws -> C03PreparedCapture? {
    guard
      withReadOnlyScriptState({ $0.instances.values.contains(where: {
        NativeHollowManifestCommission.marked($0) && $0.savedHollowManifest?.phase != .unadmitted
      }) })
    else { return nil }
    let pin = try hollowManifestInstalledCase()
    guard var selected = withReadOnlyScriptState({ $0.instances[pin.missionID] }),
      var encounter = selected.ownedEncounters[NativeHollowManifestCommission.encounter],
      let reference = pin.state.sourceFrame,
      NativeHollowManifestCommission.admittedActorClaimsMatch(selected)
    else { throw SaveError.invalidCommander }
    var event: (body: SpaceBody, alias: String, destroyed: Bool)?
    if let removal {
      guard
        let actor = encounter.actors.values.first(where: { $0.identity == removal.missionActorID }),
        actor.body.id == removal.id
      else { throw SaveError.invalidCommander }
      if actor.presence != .present { return nil }
      guard destroyed ? removal.energy <= 0 : removal.energy > 0 else {
        throw SaveError.invalidCommander
      }
      event = (removal, actor.alias, destroyed)
    }
    let demand = event != nil && selected.outcome == .active ? 1 : 0
    guard
      C03PreparedActorInstall.eventCapacity(
        next: withReadOnlyScriptState({ $0.nextEvent }),
        pending: withReadOnlyScriptState({ $0.pendingEvents.count }), demand: demand)
    else { throw SaveError.invalidCommander }
    let flight = withReadOnlyCommander({ $0.flightSimulation })
    var observed: [SpaceBody] = []
    for slot in NativeHollowManifestState.Slot.allCases {
      guard var owned = encounter.actors[slot.rawValue] else { throw SaveError.invalidCommander }
      if [.destroyed, .inTransit, .arrivalPending].contains(owned.presence) { continue }
      if owned.location(in: encounter) != systemIdentity { continue }
      if let removal, removal.missionActorID != owned.identity { continue }
      let matches = bodies.filter { $0.missionActorID == owned.identity }
      if matches.isEmpty && [.outside, .unloaded].contains(owned.presence) { continue }
      guard matches.count == 1, let body = matches.first,
        body.missionInstanceID == pin.missionID, body.id == owned.body.id,
        let latest = pin.state.latestAdmissions.first(where: { $0.slot == slot }),
        let admission = pin.state.admissions.first(where: { $0.reference == latest })
      else { throw SaveError.invalidCommander }
      if body.energy <= 0 {
        // Only the proper real root-effect owner can admit this fact, before removal.
        guard
          pin.state.terminals.contains(where: {
            $0.effect.incident.victim == body.physical?.identity
          })
        else { throw SaveError.invalidCommander }
      }
      if body.energy > 0 {
        let life = try hollowManifestOriginalLife(slot: slot)
        guard acceptsHollowManifestOriginalLife(life), life.pin.missionID == pin.missionID else {
          throw SaveError.invalidCommander
        }
      }
      owned.body = try NativeC03RetainedMotion.capture(
        body: body, owned: owned,
        original: admission.original, flight: flight, reference: reference)
      if unloading && owned.presence == .present { owned.presence = .unloaded }
      if let event, event.body.id == body.id {
        owned.presence = destroyed ? .destroyed : .outside
        if destroyed { owned.destroyedByPlayer = body.destroyedByPlayer == true }
      }
      encounter.actors[slot.rawValue] = owned
      observed.append(body)
    }
    guard observed.count <= 2 else { throw SaveError.invalidCommander }
    selected.ownedEncounters[encounter.id] = encounter
    guard NativeHollowManifestCommission.admittedActorClaimsMatch(selected) else {
      throw SaveError.invalidCommander
    }
    return .init(pin: pin, selected: selected, flight: flight, observed: observed, event: event)
  }

  @inline(never)
  private mutating func publishC03Capture(_ prepared: C03PreparedCapture) throws {
    let demand = prepared.event != nil && prepared.selected.outcome == .active ? 1 : 0
    guard acceptsHollowManifestInstalledCase(prepared.pin),
      withReadOnlyCommander({ $0.flightSimulation }) == prepared.flight,
      prepared.observed.allSatisfy({ actual in bodies.contains(actual) }),
      C03PreparedActorInstall.eventCapacity(
        next: withReadOnlyScriptState({ $0.nextEvent }),
        pending: withReadOnlyScriptState({ $0.pendingEvents.count }), demand: demand)
    else { throw NativeMissionActorAdmissionError.stalePlan }
    commander.scriptState.instances[prepared.pin.missionID] = prepared.selected
    if let event = prepared.event, let logical = event.body.missionActorID {
      emitScriptEvent(
        event.destroyed ? "actor.destroyed" : "actor.removed",
        values: [
          "actor_id": .string(logical.uuidString), "alias": .string(event.alias),
          "encounter_id": .string(NativeHollowManifestCommission.encounter),
          "destroyed_by_player": .bool(event.body.destroyedByPlayer == true),
        ], only: prepared.pin.missionID, drain: false)
    }
  }

  /// Owned captures publish Commander fields only. Restore their common beforeimage
  /// on either refusal; no half-captured source reaches a writer, cull or death settlement.
  private mutating func captureC03OwnedActors(unloading: Bool) throws {
    guard withReadOnlyScriptState({ $0.instances.values.contains(where: NativeHollowManifestCommission.marked) })
    else { return }
    let before = commander
    do {
      try captureC03Actors(unloading: unloading)
      try captureC03WakeActors(unloading: unloading)
      try captureC03RegisterActor(unloading: unloading)
      try captureC03EvacuationActors(unloading: unloading)
    } catch {
      commander = before
      throw error
    }
  }

  private mutating func captureC03Actors(unloading: Bool) throws {
    if let prepared = try prepareC03Capture(unloading: unloading) {
      try publishC03Capture(prepared)
    }
  }

  private mutating func recordC03ActorRemoval(_ body: SpaceBody, destroyed: Bool) throws {
    if let prepared = try prepareC03Capture(unloading: false, removal: body, destroyed: destroyed) {
      try publishC03Capture(prepared)
    }
  }
}

extension Game {
  @inline(never)
  private func c03WakeActorAdmissionSource() throws -> MissionActorAdmissionSource? {
    guard let context = try hollowManifestWakeAdmissionContext() else { return nil }
    guard acceptsHollowManifestWakeAdmissionContext(context),
      let instance = withReadOnlyScriptState({ $0.instances[context.pin.missionID] }),
      let pack = scriptPack(for: instance)
    else { throw SaveError.invalidCommander }
    var templates: [MissionActorAdmissionTemplate] = []
    for spec in context.declaration.actors.sorted(by: { $0.id < $1.id }) {
      guard let actor = context.retention.actors[spec.id] else { throw SaveError.invalidCommander }
      let initial = context.initial ? NativeC03EvidenceInitialCondition.state(for: .wakeFragment) : nil
      let base = try Self.missionActorAdmissionTemplate(
        actor, specification: spec, npcDefinitions: context.profiles,
        installedModels: context.designs, geometry: context.geometry, legacy: nil,
        initialNativeCondition: initial)
      let canonical = context.projections[actor.identity]?.body ?? base.canonicalBody
      if context.initial {
        try Self.validatePreparedMissionActorCondition(
          actor, spec: spec, template: base, legacy: nil,
          preparedPose: .init(position: canonical.position, orientation: canonical.orientation))
      }
      templates.append(.init(
        actor: actor, canonicalBody: canonical, maximumHullEnergy: base.maximumHullEnergy,
        declaredHostile: base.declaredHostile, parts: base.parts, minimum: base.minimum,
        maximum: base.maximum, radius: base.radius, nativeUnits: base.nativeUnits,
        initialNativeCondition: initial, c03WakeContext: context))
    }
    return .init(
      mode: context.initial ? .prepared : .retained,
      authority: context.initial ? .c03Initial : .c03Retained,
      instance: instance, pack: pack, encounter: context.retention,
      definition: context.declaration, actors: templates,
      installedBaseEncounter: context.installedEncounter, c03WakeContext: context)
  }

  @inline(never)
  fileprivate func prepareC03WakeRetentionPatch(
    source: borrowing MissionActorAdmissionSource, context: NativeC03WakeAdmissionContext,
    bodyIDs: [UUID: Int], bodies admitted: [SpaceBody], flight: FlightSimulationState
  ) throws -> MissionActorRetentionPatch {
    let sourceInstanceID = source.instanceID
    guard acceptsHollowManifestWakeAdmissionContext(context),
      let expected = withReadOnlyScriptState({ $0.instances[sourceInstanceID] }),
      source.instanceID == context.pin.missionID,
      expected.ownedEncounters[source.encounterID] == context.installedEncounter,
      source.encounterID == NativeC03WakeTrail.encounter,
      admitted.count == bodyIDs.count,
      admitted.allSatisfy({ body in body.missionActorID.flatMap({ bodyIDs[$0] }) == body.id })
    else { throw NativeMissionActorAdmissionError.stalePlan }
    let prepared = try NativeC03WakeTrail.preparingAdmission(
      context: context, admitted: admitted, flight: flight)
    var selected = expected
    selected.savedHollowManifest = prepared.state
    selected.ownedEncounters[source.encounterID] = prepared.encounter
    var candidate = commander
    candidate.flightSimulation = flight
    candidate.scriptState.instances[source.instanceID] = selected
    candidate.scriptState.geometry = context.geometry
    guard NativeHollowManifestSave.validateClaims(candidate) else { throw SaveError.invalidCommander }
    let previous = context.previousGeometry
    let additions = context.geometry.filter { previous[$0.key] == nil }
    guard additions.count <= 3 else { throw SaveError.invalidCommander }
    let install = C03PreparedActorInstall(
      pin: context.pin, expected: expected, selected: selected,
      previousGeometry: previous, additions: additions)
    return .init(source: source, updated: prepared.encounter, c03Install: install)
  }
}

extension Game {
  @inline(never)
  private func c03RegisterActorAdmissionSource() throws -> MissionActorAdmissionSource? {
    guard let context = try hollowManifestRegisterAdmissionContext() else { return nil }
    guard acceptsHollowManifestRegisterAdmissionContext(context),
      let instance = withReadOnlyScriptState({ $0.instances[context.pin.missionID] }),
      let pack = scriptPack(for: instance),
      let spec = context.declaration.actors.first,
      let actor = context.retention.actors[spec.id]
    else { throw SaveError.invalidCommander }
    let initial = context.initial ? NativeC03EvidenceInitialCondition.state(for: .custodyArchive) : nil
    let base = try Self.missionActorAdmissionTemplate(
      actor, specification: spec, npcDefinitions: [NativeC03RegisterGeometry.profile],
      installedModels: context.designs, geometry: context.geometry, legacy: nil,
      initialNativeCondition: initial)
    let canonical = context.projection?.body ?? base.canonicalBody
    if context.initial {
      try Self.validatePreparedMissionActorCondition(
        actor, spec: spec, template: base, legacy: nil,
        preparedPose: .init(position: canonical.position, orientation: canonical.orientation))
    }
    let template = MissionActorAdmissionTemplate(
      actor: actor, canonicalBody: canonical, maximumHullEnergy: base.maximumHullEnergy,
      declaredHostile: base.declaredHostile, parts: base.parts, minimum: base.minimum,
      maximum: base.maximum, radius: base.radius, nativeUnits: base.nativeUnits,
      initialNativeCondition: initial, c03RegisterContext: context)
    return .init(
      mode: context.initial ? .prepared : .retained,
      authority: context.initial ? .c03Initial : .c03Retained,
      instance: instance, pack: pack, encounter: context.retention,
      definition: context.declaration, actors: [template],
      installedBaseEncounter: context.installedEncounter, c03RegisterContext: context)
  }

  @inline(never)
  fileprivate func prepareC03RegisterRetentionPatch(
    source: borrowing MissionActorAdmissionSource, context: NativeC03RegisterAdmissionContext,
    bodyIDs: [UUID: Int], bodies admitted: [SpaceBody], flight: FlightSimulationState
  ) throws -> MissionActorRetentionPatch {
    let sourceInstanceID = source.instanceID
    guard acceptsHollowManifestRegisterAdmissionContext(context),
      let expected = withReadOnlyScriptState({ $0.instances[sourceInstanceID] }),
      source.instanceID == context.pin.missionID,
      source.encounterID == NativeC03RegisterState.encounter,
      expected.ownedEncounters[source.encounterID] == context.installedEncounter,
      admitted.count == 1, bodyIDs.count == 1,
      admitted.allSatisfy({ body in body.missionActorID.flatMap({ bodyIDs[$0] }) == body.id })
    else { throw NativeMissionActorAdmissionError.stalePlan }
    let prepared = try NativeC03RegisterState.preparingAdmission(
      context: context, admitted: admitted, flight: flight)
    var selected = expected
    selected.savedHollowManifest = prepared.state
    selected.ownedEncounters[source.encounterID] = prepared.encounter
    var candidate = commander
    candidate.flightSimulation = flight
    candidate.scriptState.instances[source.instanceID] = selected
    candidate.scriptState.geometry = context.geometry
    guard NativeHollowManifestSave.validateClaims(candidate) else { throw SaveError.invalidCommander }
    let previous = context.previousGeometry
    let additions = context.geometry.filter { previous[$0.key] == nil }
    guard additions.count <= 2 else { throw SaveError.invalidCommander }
    let install = C03PreparedActorInstall(
      pin: context.pin, expected: expected, selected: selected,
      previousGeometry: previous, additions: additions)
    return .init(source: source, updated: prepared.encounter, c03Install: install)
  }
}
