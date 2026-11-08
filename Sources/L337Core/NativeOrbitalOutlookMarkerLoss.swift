import Foundation

extension Game {
  /// The original passengers still need a real care return when a finite unread
  /// viewing marker is destroyed. Missing bodies and completed views are not loss.
  var orbitalOutlookMarkerLossNotice: String? {
    guard let source = commander.nativePeople?.outlookJourney,
      source.owner == commander.equipmentOwnerID, source.terminalOperation == nil,
      let boarding = source.boarding, source.readings.count < NativeOrbitalOutlookJourney.views.count,
      let mission = commander.scriptState.instances[boarding.mission], mission.outcome == .active,
      let encounter = mission.ownedEncounters[NativeOrbitalOutlookJourney.encounterID],
      encounter.admitted, encounter.galaxy == 0, encounter.system == 185
    else { return nil }
    for ordinal in source.readings.count..<NativeOrbitalOutlookJourney.views.count {
      let alias = NativeOrbitalOutlookJourney.views[ordinal]
      guard let marker = encounter.actors[alias], marker.alias == alias,
        marker.identity == NativeOrbitalOutlookJourney.markerIdentity(
          mission: boarding.mission, ordinal: ordinal), marker.presence == .destroyed
      else { continue }
      return "OUTLOOK \(source.readings.count)/3 - \(alias) destroyed before viewing. Return both passengers to Avenor care; review Cancel."
    }
    return nil
  }
}
