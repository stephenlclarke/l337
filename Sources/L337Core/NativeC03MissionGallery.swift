import Foundation

/// Read-only presentation, never a source, stage, contact or trial permission.
struct NativeC03CasePresentation: Sendable {
  let status: GalleryStatus
  let objective: String
  let destination: String
  let reward: String
  let issues: [String]
  let completed: Int
  let milestones: [MissionMilestone]
  let recentJournal: [String]
  let instance: UUID?
}

extension NativeHollowManifestStage {
  var galleryTitle: String {
    switch self {
    case .accept: "Accept Nia Toren's audit"
    case .inspectFreighters: "Read both original freighter seals with consent"
    case .analyseSeals: "Analyse the seals and borrow Iven's inspection kit"
    case .followCarrier: "Read the three original cargo-handler wakes"
    case .recoverRegister: "Recover the original custody register"
    case .rescueCrew: "Rescue the original crew and collect its unaltered log"
    case .reconstructLedger: "Reconcile both original documents with the seals"
    case .chooseRemedy: "Choose publication or the restitution tribunal"
    case .returnEquipment: "Return the original kit and evidence to the laboratory"
    case .closeCase: "Collect the audit fee and retain the hidden imprint"
    }
  }

  var galleryObjective: String {
    switch self {
    case .accept: "Speak to freight auditor Nia Toren at Narargan after one normal commodity sale."
    case .inspectFreighters: "Obtain each captain's consent and observe both original seals at Garrivek."
    case .analyseSeals: "Take both seal observations to Marek Iven at Torenran. Keep one tonne free for the loaned inspection kit."
    case .followCarrier: "Follow the three cargo-handler wake marks at Haldator with the original inspection kit."
    case .recoverRegister: "Recover the original register at Durenran: keep the original kit, face the archive from 50-150m and hold below 1m/s relative speed."
    case .rescueCrew: "Escort the original evacuation launch to Haldator station care, then request the ward's permission to transfer its unaltered crew log into the original inspection kit."
    case .reconstructLedger: "Bring the original register and rescued crew log in the same inspection kit to Garrivek."
    case .chooseRemedy: "Return to Iven at Torenran and choose publication or the restitution tribunal. Both preserve the evidence."
    case .returnEquipment: "Return the original inspection kit and seal the remaining evidence at Narargan."
    case .closeCase: "Confirm the resolved audit with Nia Toren at Narargan and collect 5,600 CR."
    }
  }

  var galleryDestination: String {
    switch self {
    case .accept, .returnEquipment, .closeCase: "Narargan / Galaxy 2"
    case .inspectFreighters, .reconstructLedger: "Garrivek / Galaxy 2"
    case .analyseSeals, .chooseRemedy: "Torenran / Galaxy 2"
    case .followCarrier, .rescueCrew: "Haldator / Galaxy 2"
    case .recoverRegister: "Durenran / Galaxy 2"
    }
  }
}

extension Game {
  /// Both the contract's current-case page and gallery consume this same fresh projection.
  /// Complete means a validated original terminal, not a count, name or last journal line.
  @inline(never)
  func hollowManifestCasePresentation() -> NativeC03CasePresentation {
    let stages = NativeHollowManifestStage.allCases
    let reward = "5,600 CR on a completed audit; an evidence journal discovery."
    guard let mission = hollowManifestMission else {
      let review = hollowManifestReview(.accept)
      return .init(status: review.allowed ? .available : .locked,
        objective: review.issues.first ?? NativeHollowManifestStage.accept.galleryObjective,
        destination: NativeHollowManifestStage.accept.galleryDestination, reward: reward,
        issues: review.issues, completed: 0,
        milestones: stages.map { .init(title: $0.galleryTitle, state: "Upcoming") },
        recentJournal: [], instance: nil)
    }
    guard let pin = try? hollowManifestInstalledCase(), pin.missionID == mission.id,
      mission.milestones.count <= stages.count,
      mission.milestones == Set(0..<mission.milestones.count),
      mission.outcome != .complete || mission.milestones.count == stages.count
    else {
      return .init(status: .locked, objective: "The original case record cannot currently be verified.",
        destination: "Case journal", reward: reward,
        issues: ["Restore the mission content and review the original case before continuing."],
        completed: 0, milestones: stages.map { .init(title: $0.galleryTitle, state: "Unavailable") },
        recentJournal: [], instance: mission.id)
    }
    let completed = mission.milestones.count
    let current = stages.indices.contains(completed) ? stages[completed] : nil
    var issues = mission.suspension.map { [$0] } ?? []
    // Only the validated original pre-care source loss blocks rescue. Later real ward
    // casualties do not erase the historical rescue or manufacture a second source loss.
    if commander.nativePeople?.hollowManifestCrew?.loss != nil {
      issues.append("The original evacuation launch and crew were lost. This audit cannot continue.")
    }
    let status: GalleryStatus
    if !issues.isEmpty { status = .locked }
    else {
      switch mission.outcome {
      case .active: status = .active
      case .complete: status = .complete
      case .failed, .abandoned: status = .failed
      }
    }
    let objective = issues.first
      ?? (mission.outcome == .complete
        ? "Audit closed. The fee was paid and the hidden imprint is retained in your journal."
        : current?.galleryObjective ?? "Review the retained case journal.")
    let milestones = stages.enumerated().map { index, stage in
      let state: String
      if index < completed { state = "Complete" }
      else if index == completed && issues.isEmpty { state = "Current" }
      else { state = "Upcoming" }
      return MissionMilestone(title: stage.galleryTitle, state: state)
    }
    return .init(status: status, objective: objective,
      destination: current?.galleryDestination ?? "Case closed / Narargan / Galaxy 2",
      reward: mission.outcome == .complete ? "5,600 CR paid; hidden imprint recorded." : reward,
      issues: issues, completed: completed, milestones: milestones,
      recentJournal: Array(mission.journal.suffix(3)), instance: mission.id)
  }

  func hollowManifestGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeHollowManifestCommission.applies(pack) else { return nil }
    guard NativeHollowManifestCommission.matches(pack) else {
      return .init(name: "The Hollow Manifest", status: .locked,
        objective: "This mission's content is unavailable.", briefing: "Restore the mission content before continuing.",
        destination: "Narargan / Galaxy 2", reward: "5,600 CR on a completed audit.",
        prerequisites: ["Mission content unavailable."], completed: 0, milestones: [],
        trialDigest: nil, savedInstance: hollowManifestMission?.id)
    }
    let presentation = hollowManifestCasePresentation()
    return .init(name: pack.manifest.mission.title, status: presentation.status,
      objective: presentation.objective,
      briefing: pack.manifest.mission.briefing + "\n\n" + presentation.recentJournal.joined(separator: "\n"),
      destination: presentation.destination, reward: presentation.reward,
      prerequisites: presentation.issues, completed: presentation.completed,
      milestones: presentation.milestones, trialDigest: nil, savedInstance: presentation.instance)
  }

  func hollowManifestCurrentCaseLines() -> [String] {
    let presentation = hollowManifestCasePresentation()
    return ["THE HOLLOW MANIFEST / CURRENT CASE"] + presentation.recentJournal
      + hollowManifestRegisterComparisonLines()
      + [presentation.objective, presentation.destination]
  }
}
