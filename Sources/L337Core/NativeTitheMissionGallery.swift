import Foundation

extension Game {
  /// Original stage projection. Reading or installing content cannot create field evidence.
  func titheCommissionGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeTitheCommissionDefinition.applies(pack) else { return nil }
    guard NativeTitheCommissionDefinition.matches(pack), titheCommissionPack != nil,
      NativeTitheCommissionSave.validateClaims(commander)
    else { return titheUnavailableGallery("The original Tithe definition or current case cannot be verified.") }
    let titles = NativeTitheOriginalStage.allCases.map(\.objective)
    guard let instance = titheCommissionMission else {
      let review = reviewTitheCommission()
      return .init(name: pack.manifest.mission.title,
        status: review.allowed ? .available : .locked,
        objective: review.issues.first ?? NativeTitheOriginalStage.accept.objective,
        briefing: pack.manifest.mission.briefing, destination: "Rakenor / Galaxy 7",
        reward: pack.manifest.mission.reward, prerequisites: review.issues, completed: 0,
        milestones: titheGalleryMilestones(titles, accepted: false), trialDigest: nil, savedInstance: nil)
    }
    let reason = instance.suspension == nil
      ? "The original Zordaik signals, service-drone ledger and later physical sources remain unavailable."
      : "Restore and verify the original Tithe commission before continuing."
    return .init(name: pack.manifest.mission.title, status: .locked, objective: reason,
      briefing: pack.manifest.mission.briefing + "\n\n" + instance.journal.joined(separator: "\n")
        + "\n\nNo ledger recovery, programmer issue, civilian receiving, control change, resource settlement, final audit, payment or clue is supplied by this definition.",
      destination: "Zordaik / Galaxy 7", reward: pack.manifest.mission.reward,
      prerequisites: [reason], completed: 1, milestones: titheGalleryMilestones(titles, accepted: true),
      trialDigest: nil, savedInstance: instance.id)
  }

  func titheCommissionMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativeTitheCommissionDefinition.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return titheUnavailableGallery("Restore the original Tithe content. Current case and mark DATA remain recorded; restoring content does not issue a desk or grant.")
  }

  private func titheGalleryMilestones(_ titles: [String], accepted: Bool) -> [MissionMilestone] {
    titles.enumerated().map { index, title in
      .init(title: title, state: index == 0 ? (accepted ? "Complete" : "Current") : "Unavailable")
    }
  }

  private func titheUnavailableGallery(_ reason: String) -> GalleryMission {
    .init(name: "The Tithe of Worlds", status: .locked, objective: reason,
      briefing: "Review the original resource-seizure investigation and permanent-mark warning.",
      destination: "Rakenor / Galaxy 7", reward: "No settlement available.", prerequisites: [reason],
      completed: 0, milestones: titheGalleryMilestones(NativeTitheOriginalStage.allCases.map(\.objective), accepted: false),
      trialDigest: nil, savedInstance: titheCommissionMission?.id)
  }
}
