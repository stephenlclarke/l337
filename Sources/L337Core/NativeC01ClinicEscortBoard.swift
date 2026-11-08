import Foundation

extension Game {
  func c01ClinicEscortBriefing(_ opening: NativeGlassMeridianState) -> [String] {
    guard opening.laneRepair?.installation != nil else { return [] }
    if opening.clinicEscort?.arrival != nil {
      if opening.completion != nil { return c01CompletionHistory(opening) }
      return [
        "The registered clinic tender survived and Lareria main station accepted its berth.",
        "The original timing standard remains installed; the original8kg recorder stays aboard.",
        "Next: return to Captain Venn at Avenor to release the booking evidence.",
        "At Avenor, explicitly choose the evidence outcome, then confirm original recorder receiving. No payment or final clue at this berth.",
      ]
    }
    if opening.surveyor?.loss != nil {
      return [
        "The original recorder was genuinely lost. Confirmed lane and escort history remains recorded.",
        "A copy cannot replace it. No final archive, payment or clue has been granted.",
      ]
    }
    var lines = [
      "SOREL: We will follow the corrected lane. Stay near the tender until station control confirms its berth.",
      "At Lareria, select the actual maintenance cradle. Return reviews launch; Return confirms, Esc closes.",
      "Clinic control must offer an unused original Harrier and an actual consenting pilot. No launch fee.",
      "Stay within1500m of the registered clinic tender. It slows to hold when you fall behind.",
      "Destination: Lareria main station. Only its actual berth acceptance completes this escort.",
      "The original8kg recorder remains aboard and the same timing standard remains installed.",
    ]
    if let state = opening.clinicEscort, let current = state.current {
      if current.loss != nil {
        lines += [
          "The previous tender was genuinely lost; that hull and its actual crew outcome remain recorded.",
          "Return to clinic control for a remaining unused hull and available pilot. Reloading cannot refill its finite reserve.",
          "Loss or replacement earns no arrival, payment or clue. Confirmed relay work is retained.",
        ]
      } else {
        lines.append("The same registered tender is in flight. Travel and loading preserve its identity and condition.")
      }
    }
    return lines
  }

  var c01ClinicEscortLines: [String] {
    guard !docked, screen == .front,
      let opening = glassMeridianMission?.savedGlassMeridian,
      let state = opening.clinicEscort
    else { return [] }
    if state.arrival != nil {
      return ["CLINIC TENDER BERTH ACCEPTED", "NEXT: AVENOR EVIDENCE CONTACT - ORIGINAL RECORDER RETAINED"]
    }
    var lines = ["CLINIC ESCORT - LARERIA MAIN STATION"]
    if let review = c01ClinicEscortRuntime.review {
      lines += ["PILOT: " + review.pilotName, "ORIGINAL HARRIER / NO FEE",
        "RETURN CONFIRMS LAUNCH - ESC CLOSES"]
    } else if let launch = state.current, launch.loss == nil,
      let actor = c01ClinicTenderActor(launch: launch)
    {
      lines.append(String(format: "CLINIC TENDER %.0fm / STAY WITHIN1500m", actor.body.position.length))
      lines.append(c01ClinicEscortRuntime.reason)
      lines.append("WAIT FOR ACTUAL STATION BERTH ACCEPTANCE")
    } else {
      lines.append(c01ClinicEscortRuntime.reason)
      lines.append("RETURN REVIEWS ACTUAL CLINIC OFFER - ESC CLOSES")
    }
    return lines
  }
}

extension Display {
  static func c01ClinicEscortPanel(
    _ game: Game, layout: CockpitLayout, into frame: inout Frame
  ) {
    let columns = max(20, Int((layout.width * 0.5 - 24) / (6 * layout.font)))
    let lines = game.c01ClinicEscortLines.flatMap { ShowroomText.wrap($0, width: columns) }
    for (index, line) in lines.enumerated() {
      let y = 100 + Double(index) * layout.row
      guard y < layout.flightClip.maxY - layout.row else { break }
      frame.label(line, 12, y, scale: layout.font, ink: .cyan)
    }
  }
}
