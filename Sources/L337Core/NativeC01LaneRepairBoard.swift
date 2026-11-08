import Foundation

extension Game {
  func c01LaneRepairBriefing(_ opening: NativeGlassMeridianState) -> [String] {
    if opening.surveyor?.loss != nil {
      return ["The original recorder was genuinely lost. Confirmed calibration history remains recorded; no payment or final clue."]
    }
    if opening.timingStandard?.loss != nil {
      return ["The original timing standard was genuinely lost. Completed relay evidence remains; no copy is issued."]
    }
    if opening.laneRepair?.installation != nil {
      return [
        "All three distinct Lareria relays were calibrated with the original timing standard.",
        "That same1t standard is installed. The original8kg recorder stays protected aboard.",
      ] + c01ClinicEscortBriefing(opening)
    }
    let completed = opening.laneRepair?.receipts.count ?? 0
    return [
      "Rebuild the lane at Lareria (G01-S091): \(completed)/3 original relay calibrations confirmed.",
      "Select relay-inner, relay-middle or relay-outer. Return reviews, then confirms arming; Esc cancels or stops.",
      "Hold the actual original work face50-150m away, relative speed<=1m/s, aim<=2deg for20s measured physical work per relay. The first unobstructed mesh contact must be the selected relay.",
      "Partial work and distinct completed targets persist. Repeating one target does not replace another; culling or destruction grants no work.",
      "The same original1t standard remains aboard until the third successful calibration commits installation. The original8kg recorder remains aboard throughout. No kit, money, payment or clue is transferred here.",
    ]
  }

  var c01LaneRepairWorkLines: [String] {
    guard !docked, screen == .front,
      let mission = glassMeridianMission, let state = mission.savedGlassMeridian?.laneRepair,
      let body = bodies.first(where: { $0.id == weaponsTargetID }),
      let target = c01LaneRepairTarget(body)
    else { return [] }
    let seconds = state.progress.first(where: { $0.target == target })?.seconds ?? 0
    var lines = [
      "MERIDIAN " + target.rawValue.uppercased(),
      String(format: "CALIBRATION %.2f /20s - DISTINCT RELAYS %d/3", seconds, state.receipts.count),
    ]
    if state.receipts.contains(where: { $0.target == target }) {
      lines.append(state.installation == nil
        ? "CALIBRATED - SAME STANDARD RETAINED FOR OTHER RELAYS"
        : "STANDARD INSTALLED - ORIGINAL RECORDER RETAINED")
    } else {
      lines.append(c01LaneRepairWorkRuntime.reason)
      lines.append("WORK FACE50-150m / RELATIVE<=1m/s / AIM<=2deg")
      lines.append("RETURN REVIEW/ARM - ESC STOPS; THIRD RELAY INSTALLS ORIGINAL1t STANDARD")
    }
    return lines
  }
}

extension Display {
  static func c01LaneRepairWorkPanel(
    _ game: Game, layout: CockpitLayout, into frame: inout Frame
  ) {
    let font = layout.font
    let columns = max(20, Int((layout.width * 0.5 - 24) / (6 * font)))
    let lines = game.c01LaneRepairWorkLines.flatMap { ShowroomText.wrap($0, width: columns) }
    for (index, line) in lines.enumerated() {
      let y = 100 + Double(index) * layout.row
      guard y < layout.flightClip.maxY - layout.row else { break }
      frame.label(line, 12, y, scale: font, ink: .cyan)
    }
  }
}
