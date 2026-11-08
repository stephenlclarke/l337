import Foundation

/// Proposed movement/status only. These values neither allocate nor authorize an actor,
/// seal a control proof, emit an event, recharge energy or establish native arrival.
struct ScriptNPCFlightDecision: Sendable {
  struct Notice: Sendable {
    enum Kind: String, Sendable {
      case arrived = "actor.arrived"
      case targetLost = "actor.target.lost"
    }
    let kind: Kind
    let intent: ScriptNPCIntent
  }
  let orientation: Basis3
  let translation: OuterNPCTranslation
  let intent: ScriptNPCIntent?
  let pending: Notice?
}

extension Game {
  /// Read one actual selected outer snapshot. Never call the mutating guidance or transit
  /// observers here; the native owner retains their original once-only installation.
  func prepareScriptNPCFlightDecision(
    _ body: SpaceBody, owned: [UUID: SpaceBody], station: SpaceBody?, delta: Double
  ) -> ScriptNPCFlightDecision? {
    guard body.energy > 0, let npc = body.scriptNPC else { return nil }
    if c01SurveyorActor(body) != nil || c01TimingStandardPart(body) != nil
      || c01LaneRepairTarget(body) != nil || c01ClinicCradleDeclared(body)
    {
      return nil
    }
    let definition = npc.fit.definition
    let clinic: NativeArkDockGuidance?
    if let physical = body.physical,
      let course = c01ClinicCourse(body, profile: definition, delta: delta),
      c01ClinicEscortRuntime.controls.filter({ $0.actor != physical.identity }).count
        < NativeC01ClinicEscort.maximumLaunches
    {
      clinic = .init(
        desired: storedFlightSimulation().pose.shipVector(course.worldVelocity),
        orientation: course.worldOrientation.relative(
          to: storedFlightSimulation().pose.orientation))
    } else {
      clinic = nil
    }
    let guidance =
      clinic
      ?? inductionArkDockGuidance(body, profile: definition, delta: delta)
      ?? inductionRescueDockGuidance(body, profile: definition, delta: delta)
    return scriptNPCFlightDecision(
      body, npc: npc, owned: owned, station: station,
      guidance: guidance, delta: delta)
  }

  /// Shared exact decision math. The old actual loop supplies its already installed
  /// guidance; pure outer preparation supplies only the read-only course projection.
  func scriptNPCFlightDecision(
    _ body: SpaceBody, npc: ScriptNPCState, owned: [UUID: SpaceBody], station: SpaceBody?,
    guidance: NativeArkDockGuidance?, delta: Double, allowNativeTransit: Bool = true,
    allowGenericArrival: Bool = true
  ) -> ScriptNPCFlightDecision {
    let definition = npc.fit.definition
    var orientation = body.orientation
    var proposedIntent = npc.intent
    var pending: ScriptNPCFlightDecision.Notice?
    var desired = Vector3(0, 0, 0)
    if let guidance {
      orientation = guidance.orientation
      desired = guidance.desired
    } else {
      if allowNativeTransit, npc.intent == nil, let goal = nativeTransitExitClearanceGoal(body) {
        let offset = goal - body.position
        if offset.length > 1e-6 {
          orientation = OuterNPCTranslation.steer(
            orientation, toward: offset, profile: definition, delta: delta)
          desired =
            orientation.z
            * min(
              definition.speed,
              sqrt(2 * definition.acceleration * offset.length))
        }
      }
      if var intent = npc.intent {
        if allowNativeTransit { intent = nativeTransitSteeringIntent(body, intent: intent) }
        let transitGoal = allowNativeTransit ? nativeTransitSteeringGoal(body, intent: intent) : nil
        var goal: Vector3?
        var targetVelocity = Vector3(0, 0, 0)
        if intent.mode == .hold {
          goal = body.position
        } else if intent.mode == .approach, let station {
          goal =
            transitGoal
            ?? (station.position + station.orientation.apply(intent.offset))
        } else if intent.player {
          goal = intent.offset
        } else if let identity = intent.target, let target = owned[identity], target.energy > 0 {
          goal = target.position + target.modelVector(intent.offset)
          targetVelocity = target.scriptNPC?.velocity ?? .init(0, 0, 0)
        }
        if let goal {
          let offset = goal - body.position
          let aim = intent.mode == .flee ? offset * -1 : offset
          if intent.mode != .hold && aim.length > 1e-6 {
            orientation = OuterNPCTranslation.steer(
              orientation, toward: aim, profile: definition, delta: delta)
          }
          var speed = definition.speed * intent.speed
          if transitGoal != nil && aim.length > 1e-6
            && orientation.z.dot(aim.unit) < 0.98
          {
            speed = 0
          }
          if [.hold, .approach, .follow].contains(intent.mode) {
            speed = min(
              speed, sqrt(2 * definition.acceleration * max(0, offset.length - intent.tolerance)))
          }
          desired = orientation.z * speed
          if intent.mode == .follow { desired = desired + targetVelocity }
          desired = desired.limited(to: definition.speed)
          if allowGenericArrival && intent.status == .requested
            && [.hold, .approach, .follow].contains(intent.mode)
            && transitGoal == nil
            && offset.length <= intent.tolerance && (npc.velocity - targetVelocity).length < 1
          {
            intent.status = .reached
            pending = .init(kind: .arrived, intent: intent)
          }
        } else if intent.status != .lost {
          intent.status = .lost
          pending = .init(kind: .targetLost, intent: intent)
        }
        proposedIntent = intent
      }
    }
    return .init(
      orientation: orientation,
      translation: .init(
        position: body.position, velocity: npc.velocity, desired: desired,
        acceleration: definition.acceleration, delta: delta),
      intent: proposedIntent, pending: pending)
  }
}
