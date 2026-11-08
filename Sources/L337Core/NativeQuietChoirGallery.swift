import Foundation

extension Game {
  /// Original commissioning history and future requirements; reading creates no field evidence.
  func quietChoirGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeQuietChoirDefinition.applies(pack) else { return nil }
    guard NativeQuietChoirDefinition.matches(pack), quietChoirPack != nil,
      NativeQuietChoirSave.validateClaims(commander)
    else { return quietChoirUnavailableGallery(reason: "The original Quiet Choir content or case cannot currently be verified.") }
    let titles = NativeC02OriginalStage.allCases.map(\.objective)
    guard let instance = quietChoirMission else {
      let quote = quietChoirReview(.accept)
      return .init(name: pack.manifest.mission.title, status: quote.allowed ? .available : .locked,
        objective: quote.issues.first ?? "Review Holt's investigation at Omdogan in Galaxy 4.",
        briefing: pack.manifest.mission.briefing, destination: "Omdogan / Galaxy 4",
        reward: pack.manifest.mission.reward, prerequisites: quote.issues, completed: 0,
        milestones: quietChoirMilestones(titles, accepted: false), trialDigest: nil, savedInstance: nil)
    }
    let reason = instance.suspension == nil
      ? "The original Lobagom reference emitters and receiver-calibration producer are not currently available."
      : "Review the suspended original Quiet Choir survey before continuing."
    return .init(name: pack.manifest.mission.title, status: .locked, objective: reason,
      briefing: pack.manifest.mission.briefing + "\n\n" + instance.journal.joined(separator: "\n")
        + "\n\nCommission accepted. No calibration trace, recovered collector, culture transfer, probe repair, gathering observation, transmitter shutdown, protocol, payment or clue has been obtained.",
      destination: "Lobagom / Galaxy 4", reward: pack.manifest.mission.reward,
      prerequisites: [reason], completed: 1, milestones: quietChoirMilestones(titles, accepted: true),
      trialDigest: nil, savedInstance: instance.id)
  }

  func quietChoirMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativeQuietChoirDefinition.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return quietChoirUnavailableGallery(reason: "Restore the original Quiet Choir content. Its current saved commission remains recorded.")
  }

  private func quietChoirMilestones(_ titles: [String], accepted: Bool) -> [MissionMilestone] {
    titles.enumerated().map { index, title in
      .init(title: title, state: index == 0 ? (accepted ? "Complete" : "Current") : "Unavailable")
    }
  }

  private func quietChoirUnavailableGallery(reason: String) -> GalleryMission {
    let accepted = quietChoirMission != nil && NativeQuietChoirSave.validateClaims(commander)
    return .init(name: "A Choir Beneath the Static", status: .locked, objective: reason,
      briefing: "Review the original signal commission and its current saved history.",
      destination: "Omdogan / Galaxy 4", reward: "No settlement available.", prerequisites: [reason],
      completed: accepted ? 1 : 0,
      milestones: accepted ? quietChoirMilestones(NativeC02OriginalStage.allCases.map(\.objective), accepted: true) : [],
      trialDigest: nil, savedInstance: quietChoirMission?.id)
  }
}
