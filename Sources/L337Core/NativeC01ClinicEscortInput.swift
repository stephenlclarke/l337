import Foundation

/// Availability and consent stay in the WHOLE opaque native quote. The extra physical
/// identity only keeps the visible selection fixed; it does not authorize source stock.
final class NativeC01ClinicReview: Sendable {
  let quote: NativeC01ClinicPeopleQuote
  let cradle: ActorIdentity
  var pilotName: String { quote.pilotName }

  fileprivate init(quote: NativeC01ClinicPeopleQuote, cradle: ActorIdentity) {
    self.quote = quote
    self.cradle = cradle
  }
}

struct NativeC01ClinicEscortRuntime: Sendable {
  var review: NativeC01ClinicReview?
  var attainedSample: NativeC01ClinicAttainedSample?
  var controls: [NativeC01ClinicControlProof] = []
  var pendingDeaths: [NativeC01ClinicFatalTransition] = []
  var reason = "Select the maintenance cradle; Return reviews the actual clinic launch offer."
}

extension Game {
  mutating func interruptC01ClinicReview() {
    guard c01ClinicEscortRuntime.review != nil else { return }
    c01ClinicEscortRuntime.review = nil
    c01ClinicEscortRuntime.reason = "Launch review closed. No hull, pilot or money transferred."
  }
}


extension Game {
  mutating func handleC01ClinicEscortKey(_ key: String) -> Bool {
    if c01ClinicEscortRuntime.review != nil,
      ["escape", "k", "pause", "pause-toggle"].contains(key)
    {
      interruptC01ClinicReview()
      if key == "escape" { return true }
    }
    guard key == "return" else { return false }
    if let review = c01ClinicEscortRuntime.review {
      do { try confirmC01ClinicLaunch(review) } catch {
        interruptC01ClinicReview()
        notify("CLINIC OFFER CHANGED - SELECT THE CRADLE AND REVIEW AGAIN")
      }
      return true
    }
    guard !docked, !paused, screen == .front, energy > 0, !playerEMPDisabled,
      let body = bodies.first(where: { $0.id == weaponsTargetID }),
      c01ClinicCradleActor(body) != nil, body.energy > 0,
      let physical = body.physical,
      body.position.length <= NativeC01ClinicEscort.stayNearMetres
    else { return false }
    guard scriptDurabilityAvailable, let quote = c01ClinicPeopleQuote() else {
      notify("NO CURRENT CONSENTING PILOT AND UNUSED CLINIC HULL AVAILABLE")
      return true
    }
    interruptFlightTool()
    c01ClinicEscortRuntime.review = .init(quote: quote, cradle: physical.identity)
    c01ClinicEscortRuntime.reason = "RETURN CONFIRMS THIS PILOT AND EXISTING HULL - NO FEE; ESC CLOSES"
    return true
  }

  private mutating func confirmC01ClinicLaunch(_ review: NativeC01ClinicReview) throws {
    guard !docked, !paused, screen == .front, energy > 0, !playerEMPDisabled,
      scriptDurabilityAvailable,
      let selected = bodies.first(where: { $0.id == weaponsTargetID }),
      selected.physical?.identity == review.cradle, selected.energy > 0,
      selected.position.length <= NativeC01ClinicEscort.stayNearMetres,
      c01ClinicCradleActor(selected) != nil,
      var mission = glassMeridianMission, var opening = mission.savedGlassMeridian,
      var state = opening.clinicEscort, state.arrival == nil,
      state.current == nil || state.current?.loss != nil,
      state.launches.count < NativeC01ClinicEscort.maximumLaunches,
      mission.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let intent = try validateC01ClinicPeopleQuote(review.quote)
    let previous = mission
    state.launches.append(intent.launch)
    guard NativeC01ClinicEscortSave.shapeValid(state) else { throw SaveError.invalidCommander }
    opening.clinicEscort = state
    mission.savedGlassMeridian = opening
    mission.revision += 1
    mission.journal.append("Clinic pilot accepted the local escort leg in the same registered Harrier. No fee or replacement hull.")
    commander.scriptState.instances[mission.id] = mission
    do {
      let assignment = try prepareC01ClinicPeopleAssignment(intent)
      try commitC01ClinicPeopleAssignment(assignment)
    } catch {
      commander.scriptState.instances[previous.id] = previous
      throw error
    }
    // Actual guidance acts only on a later physical step. Release writes no body condition,
    // pose, velocity, spin, spawn identity or native allocator counter.
    cancelAutoTarget()
    interruptFlightTool()
    c01ClinicEscortRuntime.reason = "CLINIC TENDER RELEASED - STAY WITHIN1500m UNTIL ACTUAL BERTH ACCEPTANCE"
  }
}
