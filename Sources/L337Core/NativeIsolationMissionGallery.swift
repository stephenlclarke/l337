import Foundation

extension Game {
  /// Original parent history only. Reading it grants no work, return or settlement authority.
  func isolationParentGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard pack.manifest.stateID == NativeIsolationWorkParent.stateID
      || pack.digest == NativeIsolationWorkParent.digest
    else { return nil }
    guard NativeIsolationWorkParent.matches(pack) else {
      return isolationParentGalleryUnavailable(pack, reason: "Restore the approved original Lerr isolation contract.")
    }
    guard scriptPacks.contains(where: NativeIsolationWorkPack.matches) else {
      return isolationParentGalleryUnavailable(pack, reason: "Restore the approved original Renas isolation source.")
    }
    guard NativeIsolationWorkParentSave.validateClaims(commander),
      NativeIsolationWorkSave.validateClaims(commander),
      NativeIsolationContractSave.validateClaims(commander)
    else {
      return isolationParentGalleryUnavailable(pack, reason: "The original isolation job record cannot currently be verified.")
    }
    guard let parent = isolationWorkParentMission else {
      let review = isolationWorkParentReview(.accept)
      return .init(name: pack.manifest.mission.title, status: review.allowed ? .available : .locked,
        objective: review.issues.first ?? "Review the original programmer loan with Lerr at Avenor.",
        briefing: pack.manifest.mission.briefing, destination: "Avenor / Galaxy 1",
        reward: pack.manifest.mission.reward, prerequisites: review.issues, completed: 0,
        milestones: pack.manifest.mission.milestones.map { .init(title: $0, state: "Upcoming") },
        trialDigest: nil, savedInstance: nil)
    }
    guard parent.definition == pack.manifest.stateID, parent.digest == pack.digest,
      let proof = parent.savedIsolationWorkParent,
      let source = commander.isolationInstance(
        NativeIsolationWorkPack.instance(source: proof.source))?.savedIsolationWork
    else {
      return isolationParentGalleryUnavailable(pack, reason: "The original isolation job record cannot currently be verified.")
    }
    // Historical return/loss must not be rejected because the original is no longer held.
    if proof.cutoff == nil,
      (try? NativeIsolationProgrammerCustody.resolve(parent: parent, commander: commander)) == nil
    {
      return isolationParentGalleryUnavailable(pack, reason: "The original programmer custody cannot currently be verified.")
    }
    let custody: String
    switch proof.cutoff {
    case nil: custody = "The original programmer is still owed to Lerr at Avenor."
    case .returned?: custody = "The same original programmer has been returned to Lerr."
    case .lost?: custody = "The original programmer was lost; its loss remains recorded."
    }
    let bothVerified = source.modules.count == 2 && source.modules.allSatisfy { $0.verification != nil }
    var issues = parent.suspension.map { [$0] } ?? []
    if parent.outcome == .active, isolationWorkFailure != nil {
      issues.append("An original source or programmer loss requires review of the retained job.")
    }
    let status: GalleryStatus
    let objective: String
    let reward: String
    switch parent.outcome {
    case .active:
      status = issues.isEmpty ? .active : .locked
      objective = issues.first ?? (bothVerified
        ? "Both original zero-flow verifications are recorded. Return the same programmer through a later actual Avenor arrival."
        : "Isolate and verify both original Renas feeders with the original programmer.")
      reward = pack.manifest.mission.reward
    case .complete:
      status = issues.isEmpty ? .complete : .locked
      objective = issues.first ?? "Both isolations and the original return were settled. The original job remains on record."
      reward = "970 CR paid; original programmer return recorded."
    case .failed, .abandoned:
      status = issues.isEmpty ? .failed : .locked
      objective = issues.first ?? "The original job ended unpaid. " + custody
      reward = "No reward or clue awarded for this ending."
    }
    let destination: String
    if parent.outcome == .active {
      destination = bothVerified ? "Avenor / Galaxy 1" : "Renas / Galaxy 1"
    } else if proof.cutoff == nil {
      destination = "Return original / Avenor / Galaxy 1"
    } else {
      destination = "Original job retained / Avenor / Galaxy 1"
    }
    let milestones = pack.manifest.mission.milestones.enumerated().map { index, title in
      let state: String
      if parent.milestones.contains(index) { state = "Complete" }
      else if parent.outcome == .active && issues.isEmpty && index == parent.milestones.count {
        state = "Current"
      } else { state = parent.outcome == .active ? "Upcoming" : "Not completed" }
      // Child physical proofs change the next instruction, never the parent's receipt count.
      let currentTitle = state == "Current" && bothVerified
        ? "Both verifications recorded; present the original to Lerr" : title
      return MissionMilestone(title: currentTitle, state: state)
    }
    return .init(name: pack.manifest.mission.title, status: status, objective: objective,
      briefing: pack.manifest.mission.briefing + "\n\n" + custody,
      destination: destination,
      reward: reward, prerequisites: issues, completed: parent.milestones.count,
      milestones: milestones, trialDigest: nil, savedInstance: parent.id)
  }

  private func isolationParentGalleryUnavailable(_ pack: ScriptPack, reason: String) -> GalleryMission {
    .init(name: "External isolation work", status: .locked, objective: reason,
      briefing: "Review the original isolation contract and its retained source records.",
      destination: "Case journal", reward: "No settlement available.", prerequisites: [reason],
      completed: 0,
      milestones: NativeIsolationWorkParent.matches(pack)
        ? pack.manifest.mission.milestones.map { .init(title: $0, state: "Unavailable") } : [],
      trialDigest: nil, savedInstance: isolationWorkParentMission?.id)
  }
}
