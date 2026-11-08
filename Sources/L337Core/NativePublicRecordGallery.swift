import Foundation

extension Game {
  /// Original commissioning history and future requirements; reading creates no field evidence.
  func publicRecordGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativePublicRecordDefinition.applies(pack) else { return nil }
    guard NativePublicRecordDefinition.matches(pack), publicRecordPack != nil,
      NativePublicRecordSave.validateClaims(commander)
    else { return publicRecordUnavailableGallery(reason: "The original Public Record content or case cannot currently be verified.") }
    let titles = NativePublicRecordOriginalStage.allCases.map(\.objective)
    guard let instance = publicRecordMission else {
      let quote = publicRecordReview(.accept)
      return .init(name: pack.manifest.mission.title, status: quote.allowed ? .available : .locked,
        objective: quote.issues.first ?? "Review Sol's case at Fenias in Galaxy 5.",
        briefing: pack.manifest.mission.briefing, destination: "Fenias / Galaxy 5",
        reward: pack.manifest.mission.reward, prerequisites: quote.issues, completed: 0,
        milestones: publicRecordMilestones(titles, accepted: false), trialDigest: nil, savedInstance: nil)
    }
    let reason = instance.suspension == nil
      ? "Sol's actual finite original reference source at Fenias is not currently available."
      : "Review the suspended original Public Record case before continuing."
    return .init(name: pack.manifest.mission.title, status: .locked, objective: reason,
      briefing: pack.manifest.mission.briefing + "\n\n" + instance.journal.joined(separator: "\n")
        + "\n\nCommission accepted. No reference, actual observer consent/routing decision/controller reading, independent evidence version/hash, living technical witness/delegate reception, anonymised archive/privacy audit/reply escrow proof, fee or clue has been obtained.",
      destination: "Fenias / Galaxy 5", reward: pack.manifest.mission.reward,
      prerequisites: [reason], completed: 1, milestones: publicRecordMilestones(titles, accepted: true),
      trialDigest: nil, savedInstance: instance.id)
  }

  func publicRecordMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativePublicRecordDefinition.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return publicRecordUnavailableGallery(reason: "Restore the original Public Record content. Its current saved commission remains recorded.")
  }

  private func publicRecordMilestones(_ titles: [String], accepted: Bool) -> [MissionMilestone] {
    titles.enumerated().map { index, title in
      .init(title: title, state: index == 0 ? (accepted ? "Complete" : "Current") : "Unavailable")
    }
  }

  private func publicRecordUnavailableGallery(reason: String) -> GalleryMission {
    let accepted = publicRecordMission != nil && NativePublicRecordSave.validateClaims(commander)
    return .init(name: "Public Record", status: .locked, objective: reason,
      briefing: "Review the original case commission and its current saved history.",
      destination: "Fenias / Galaxy 5", reward: "No settlement available.", prerequisites: [reason],
      completed: accepted ? 1 : 0,
      milestones: accepted ? publicRecordMilestones(NativePublicRecordOriginalStage.allCases.map(\.objective), accepted: true) : [],
      trialDigest: nil, savedInstance: publicRecordMission?.id)
  }
}
