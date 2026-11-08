import Foundation

extension Game {
  /// Retained destruction of an unread registered marker makes the fixed survey
  /// impossible. A missing body, unload or completed marker supplies no such fact.
  var originalSurveyMarkerLossNotice: String? {
    guard let source = originalSurveyState, source.owner == commander.equipmentOwnerID,
      source.terminalOperation == nil, let permission = source.permission,
      source.readings.count < NativeOriginalSurvey.targets.count,
      let mission = commander.scriptState.instances[permission.mission], mission.outcome == .active,
      let encounter = mission.ownedEncounters[NativeOriginalSurvey.encounterID],
      encounter.admitted, encounter.galaxy == 0, encounter.system == 185
    else { return nil }
    for ordinal in source.readings.count..<NativeOriginalSurvey.targets.count {
      let alias = NativeOriginalSurvey.targets[ordinal]
      guard let marker = encounter.actors[alias], marker.alias == alias,
        marker.identity == NativeOriginalSurvey.markerIdentity(
          mission: permission.mission, digest: source.digest, ordinal: ordinal),
        marker.presence == .destroyed
      else { continue }
      return "SURVEY \(source.readings.count)/3 - \(alias) destroyed before measurement. Return to Avenor to cancel."
    }
    return nil
  }
}
