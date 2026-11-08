import Foundation

extension Game {
  /// Original commissioning history and future requirements; reading creates no field evidence.
  func borrowedVoiceGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeBorrowedVoiceDefinition.applies(pack) else { return nil }
    guard NativeBorrowedVoiceDefinition.matches(pack), borrowedVoicePack != nil,
      NativeBorrowedVoiceSave.validateClaims(commander)
    else { return borrowedVoiceUnavailableGallery(reason: "The original Borrowed Voice content or case cannot currently be verified.") }
    let titles = NativeBorrowedVoiceOriginalStage.allCases.map(\.objective)
    guard let instance = borrowedVoiceMission else {
      let quote = borrowedVoiceReview(.accept)
      return .init(name: pack.manifest.mission.title, status: quote.allowed ? .available : .locked,
        objective: quote.issues.first ?? "Review Dain's investigation at Taledea in Galaxy 3.",
        briefing: pack.manifest.mission.briefing, destination: "Taledea / Galaxy 3",
        reward: pack.manifest.mission.reward, prerequisites: quote.issues, completed: 0,
        milestones: borrowedVoiceMilestones(titles, accepted: false), trialDigest: nil, savedInstance: nil)
    }
    let reason = instance.suspension == nil
      ? "The original Ilasaeli distress beacons and independent casualty-sensor sources are not currently available."
      : "Review the suspended original Borrowed Voice survey before continuing."
    return .init(name: pack.manifest.mission.title, status: .locked, objective: reason,
      briefing: pack.manifest.mission.briefing + "\n\n" + instance.journal.joined(separator: "\n")
        + "\n\nCommission accepted. No verifier, beacon comparison, private witness statement, protected arrival or authenticated operation record has been obtained.",
      destination: "Ilasaeli / Galaxy 3", reward: pack.manifest.mission.reward,
      prerequisites: [reason], completed: 1, milestones: borrowedVoiceMilestones(titles, accepted: true),
      trialDigest: nil, savedInstance: instance.id)
  }

  func borrowedVoiceMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativeBorrowedVoiceDefinition.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return borrowedVoiceUnavailableGallery(reason: "Restore the original Borrowed Voice content. Its current saved commission remains recorded.")
  }

  private func borrowedVoiceMilestones(_ titles: [String], accepted: Bool) -> [MissionMilestone] {
    titles.enumerated().map { index, title in
      .init(title: title, state: index == 0 ? (accepted ? "Complete" : "Current") : "Unavailable")
    }
  }

  private func borrowedVoiceUnavailableGallery(reason: String) -> GalleryMission {
    let accepted = borrowedVoiceMission != nil && NativeBorrowedVoiceSave.validateClaims(commander)
    return .init(name: "The Borrowed Voice", status: .locked, objective: reason,
      briefing: "Review the original rescue-channel commission and its current saved history.",
      destination: "Taledea / Galaxy 3", reward: "No settlement available.", prerequisites: [reason],
      completed: accepted ? 1 : 0,
      milestones: accepted ? borrowedVoiceMilestones(NativeBorrowedVoiceOriginalStage.allCases.map(\.objective), accepted: true) : [],
      trialDigest: nil, savedInstance: borrowedVoiceMission?.id)
  }
}
