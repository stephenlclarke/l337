import Foundation

/// Pure preparation only. The installed G2/G3 source owner must authenticate every supplied
/// binding and atomically install both originals before this becomes a runtime controller.
enum NativeC03FreighterRouteRuntime {
  typealias Route = NativeC03FreighterRoute
  enum Failure: Error { case invalidStep, invalidRevision, missingProfile }

  /// Turn-local data, not a second persisted route or permission to install an intent.
  struct PreparedSteering: Sendable {
    let target: Route.Waypoint
    let revision: UInt64
    let intent: ScriptNPCIntent
  }

  /// Reusable by an actual admission plan with its staged flight. Projection alone cannot
  /// observe arrival, advance a route revision, allocate an actor or change physical condition.
  static func projectIntent(
    binding: Route.Binding, target: Route.Waypoint,
    flight: FlightSimulationState, station: SpaceBody?, profile: ScriptNPCDefinition
  ) throws -> ScriptNPCIntent {
    let approach = try Route.Scheduler(binding: binding, target: target)
      .approach(flight: flight, station: station, profile: profile)
    let intent = ScriptNPCIntent(
      request: binding.slot == .first ? "c03-route-a" : "c03-route-b",
      mode: .approach, target: nil, player: false, offset: approach.offset,
      speed: approach.speedFraction, tolerance: approach.tolerance)
    guard intent.valid else { throw Route.Failure.invalidProfile }
    return intent
  }

  /// Prepare one structurally matched live original before the existing steering snapshot.
  /// No caller may treat this result or a constructed Binding as actual source authority.
  static func prepareSteering(
    binding: Route.Binding, target: Route.Waypoint, revision: UInt64,
    owned: ScriptOwnedActor, body: SpaceBody, flight: FlightSimulationState,
    station: SpaceBody?, delta: Double
  ) throws -> PreparedSteering {
    guard delta.isFinite, delta > 0 else { throw Failure.invalidStep }
    guard revision > 0, revision < UInt64(Int64.max) else { throw Failure.invalidRevision }
    guard let profile = body.scriptNPC?.fit.definition else { throw Failure.missingProfile }
    let refreshed = try projectIntent(
      binding: binding, target: target, flight: flight, station: station, profile: profile)
    var observed = body
    observed.scriptNPC?.intent = refreshed
    var scheduler = Route.Scheduler(binding: binding, target: target)
    let switched = try scheduler.considerArrival(
      source: binding.source, sourceRevision: binding.sourceRevision,
      owned: owned, body: observed, flight: flight, station: station)
    guard !switched || revision < UInt64(Int64.max) - 1 else {
      throw Failure.invalidRevision
    }
    let intent =
      switched
      ? try projectIntent(
        binding: binding, target: scheduler.target, flight: flight,
        station: station, profile: profile)
      : refreshed
    return .init(
      target: scheduler.target, revision: switched ? revision + 1 : revision, intent: intent)
  }
}

/// Ephemeral steering classification. Recognition can suppress stale guidance but grants no
/// control; only the actual installed-case provider can supply entries for preparation below.
struct C03FreighterRoutePass {
  let recognizedBodyIDs: Set<Int>
  let refusedBodyIDs: Set<Int>
}

private struct C03FreighterIntentUpdate {
  let index: Int
  let expected: SpaceBody
  let intent: ScriptNPCIntent
}

/// One selected instance, never a Game/Commander snapshot or independently installed authority.
private final class C03FreighterRoutePatch {
  let pin: NativeHollowManifestInstalledCase
  let flight: FlightSimulationState
  let station: SpaceBody?
  let instance: ScriptInstance
  let updates: [C03FreighterIntentUpdate]
  init(
    pin: NativeHollowManifestInstalledCase, flight: FlightSimulationState,
    station: SpaceBody?, instance: ScriptInstance, updates: [C03FreighterIntentUpdate]
  ) {
    self.pin = pin
    self.flight = flight
    self.station = station
    self.instance = instance
    self.updates = updates
  }
}

/// Only the real provider preparation below can construct an installable selected patch.
struct C03FreighterRoutePreparation {
  let recognizedBodyIDs: Set<Int>
  fileprivate let patch: C03FreighterRoutePatch?
  var isPrepared: Bool { patch != nil }
  fileprivate init(recognizedBodyIDs: Set<Int>, patch: C03FreighterRoutePatch?) {
    self.recognizedBodyIDs = recognizedBodyIDs
    self.patch = patch
  }
}

extension Game {
  @inline(never)
  mutating func prepareC03FreighterRoutePass(delta: Double) -> C03FreighterRoutePass {
    let preparation = prepareC03FreighterRouteSteering(delta: delta)
    guard installC03FreighterRouteSteering(preparation), let patch = preparation.patch else {
      return .init(
        recognizedBodyIDs: preparation.recognizedBodyIDs,
        refusedBodyIDs: preparation.recognizedBodyIDs)
    }
    return .init(
      recognizedBodyIDs: preparation.recognizedBodyIDs,
      refusedBodyIDs: preparation.recognizedBodyIDs.subtracting(
        patch.updates.map { $0.expected.id }))
  }

  /// Preparation and installation are real production phases. A caller cannot supply source
  /// entries or construct a patch; tests can retain an authentic preparation to exercise staleness.
  @inline(never)
  func prepareC03FreighterRouteSteering(delta: Double) -> C03FreighterRoutePreparation {
    let inputs = c03LiveRouteInputs()
    let refused = C03FreighterRoutePreparation(
      recognizedBodyIDs: inputs.recognizedBodyIDs, patch: nil)
    guard !inputs.recognizedBodyIDs.isEmpty, delta.isFinite, delta > 0,
      !docked, !paused, let pin = inputs.pin, (1...2).contains(inputs.originals.count)
    else { return refused }
    do {
      let patch = try prepareC03FreighterRoutePatch(
        pin: pin, originals: inputs.originals, recognizedBodyIDs: inputs.recognizedBodyIDs,
        flight: storedFlightSimulation(),
        station: bodies.first { $0.id == 0 && $0.hull == .station }, delta: delta)
      return .init(recognizedBodyIDs: inputs.recognizedBodyIDs, patch: patch)
    } catch {
      return refused
    }
  }

  @inline(never)
  mutating func installC03FreighterRouteSteering(_ preparation: C03FreighterRoutePreparation)
    -> Bool
  {
    guard let patch = preparation.patch else { return false }
    let current = c03LiveRouteInputs()
    let prepared = Set(patch.updates.map { $0.expected.id })
    let recognizedLive = Set(
      bodies.filter { $0.energy > 0 && preparation.recognizedBodyIDs.contains($0.id) }.map(\.id))
    guard current.pin != nil,
      current.recognizedBodyIDs == preparation.recognizedBodyIDs,
      Set(current.originals.map { $0.owned.body.id }) == prepared,
      acceptsHollowManifestInstalledCase(patch.pin), storedFlightSimulation() == patch.flight,
      !docked, !paused, prepared == recognizedLive,
      bodies.first(where: { $0.id == 0 && $0.hull == .station }) == patch.station,
      patch.updates.allSatisfy({
        let update = $0
        return bodies.indices.contains(update.index) && bodies[update.index] == update.expected
          && bodies.filter { $0.id == update.expected.id }.count == 1
      })
    else { return false }
    // All fallible/source/body checks returned. Both selected intents and typed route history
    // publish without another lookup, callback, event enqueue or native condition replacement.
    commander.scriptState.instances[patch.pin.missionID] = patch.instance
    for update in patch.updates { bodies[update.index].scriptNPC?.intent = update.intent }
    return true
  }

  @inline(never)
  private func prepareC03FreighterRoutePatch(
    pin: NativeHollowManifestInstalledCase,
    originals: [(
      slot: NativeHollowManifestState.Slot, owned: ScriptOwnedActor,
      admission: NativeHollowManifestState.Admission, route: NativeHollowManifestState.Route
    )], recognizedBodyIDs: Set<Int>, flight: FlightSimulationState,
    station: SpaceBody?, delta: Double
  ) throws -> C03FreighterRoutePatch {
    guard acceptsHollowManifestInstalledCase(pin),
      let encounterID = pin.state.ownedEncounterID,
      var instance = withReadOnlyScriptState({ $0.instances[pin.missionID] }),
      var encounter = instance.ownedEncounters[encounterID], encounter.admitted,
      Set(originals.map { $0.slot }).count == originals.count,
      Set(originals.map { $0.owned.body.id }).count == originals.count
    else { throw NativeC03FreighterRoute.Failure.invalidJoin }
    var routes = pin.state.routes
    var updates: [C03FreighterIntentUpdate] = []
    for original in originals {
      guard original.owned.alias == original.slot.rawValue,
        encounter.actors[original.owned.alias] == original.owned,
        original.admission.reference == original.route.admission,
        original.admission.reference.slot == original.slot,
        original.admission.original.slot == original.slot,
        pin.state.latestAdmissions.contains(original.admission.reference),
        pin.state.admissions.contains(original.admission),
        let routeIndex = routes.firstIndex(of: original.route),
        recognizedBodyIDs.contains(original.owned.body.id),
        bodies.filter({ $0.id == original.owned.body.id }).count == 1,
        let index = bodies.firstIndex(where: { $0.id == original.owned.body.id }),
        let slot = NativeC03FreighterRoute.Slot(rawValue: original.slot.rawValue)
      else { throw NativeC03FreighterRoute.Failure.invalidJoin }
      let binding = try NativeC03FreighterRoute.Binding(
        source: original.admission.original.source, mission: pin.missionID,
        sourceRevision: original.admission.original.sourceRevision,
        actor: original.owned.identity, actorAlias: original.owned.alias,
        physicalActor: original.admission.original.actor, slot: slot,
        endpoints: .init(first: original.route.first, second: original.route.second))
      let prepared = try NativeC03FreighterRouteRuntime.prepareSteering(
        binding: binding, target: original.route.target == .first ? .first : .second,
        revision: original.route.revision, owned: original.owned, body: bodies[index],
        flight: flight, station: station, delta: delta)
      routes[routeIndex] = .init(
        admission: original.route.admission, first: original.route.first,
        second: original.route.second, target: prepared.target == .first ? .first : .second,
        revision: prepared.revision)
      var actor = original.owned
      actor.body.scriptNPC?.intent = prepared.intent
      encounter.actors[actor.alias] = actor
      updates.append(.init(index: index, expected: bodies[index], intent: prepared.intent))
    }
    guard encounter.valid else { throw NativeC03FreighterRoute.Failure.invalidJoin }
    instance.savedHollowManifest = try pin.state.replacingRoutes(candidateRoutes: routes)
    instance.ownedEncounters[encounterID] = encounter
    return .init(pin: pin, flight: flight, station: station, instance: instance, updates: updates)
  }
}


extension Game {
  /// Native path preparation may consume only a genuinely installed current source intent.
  /// A prepared-but-uninstalled route, recognized body or caller pass cannot authorize it.
  func c03NativeRouteIntentIsCurrent(_ body: borrowing SpaceBody, delta: Double) -> Bool {
    let preparation = prepareC03FreighterRouteSteering(delta: delta)
    guard let patch = preparation.patch, acceptsHollowManifestInstalledCase(patch.pin),
      nativeGuidanceStoredMission(id: patch.pin.missionID) == patch.instance
    else { return false }
    let bodyID = body.id
    guard let update = patch.updates.first(where: { $0.expected.id == bodyID }),
      update.expected == body, update.intent == body.scriptNPC?.intent
    else { return false }
    return true
  }
}


extension Game {
  /// Pure post-camera planning from the actual opening source. The projected Flight state
  /// is used only to express the same installed world waypoint in the selected view frame.
  /// It is never an applied step, current pose, arrival or source permission.
  func c03NativeProjectedIntent(_ body: borrowing SpaceBody, path: CurrentNewtOuterMotion,
    station: SpaceBody?) -> ScriptNPCIntent?
  {
    guard c03NativeRouteIntentIsCurrent(body, delta: path.motion.duration),
      let pin = c03LiveRouteInputs().pin
    else { return nil }
    let bodyID = body.id
    guard let original = c03LiveRouteInputs().originals.first(where: { $0.owned.body.id == bodyID }),
      let slot = NativeC03FreighterRoute.Slot(rawValue: original.slot.rawValue),
      let profile = body.scriptNPC?.fit.definition
    else { return nil }
    do {
      let binding = try NativeC03FreighterRoute.Binding(source: original.admission.original.source,
        mission: pin.missionID, sourceRevision: original.admission.original.sourceRevision,
        actor: original.owned.identity, actorAlias: original.owned.alias,
        physicalActor: original.admission.original.actor, slot: slot,
        endpoints: .init(first: original.route.first, second: original.route.second))
      var projected = storedFlightSimulation()
      projected.pose = path.motion.end
      return try NativeC03FreighterRouteRuntime.projectIntent(binding: binding,
        target: original.route.target == .first ? .first : .second,
        flight: projected, station: station, profile: profile)
    } catch { return nil }
  }
}
