import Foundation

extension Game {
  /// Original C25 history and next requirements only. Reading never issues a permission,
  /// reference, observation, settlement, fee, clue or trial commander.
  func memoryAtlasGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeMemoryAtlasDefinition.applies(pack) else { return nil }
    guard NativeMemoryAtlasDefinition.matches(pack),
      memoryAtlasPack != nil, NativeMemoryAtlasSave.validateClaims(commander),
      NativeMemoryAtlasWatcherSourceSave.validateClaims(commander)
    else {
      return memoryAtlasUnavailableGallery(
        reason: "The original The Memory Atlas content or case record cannot currently be verified.")
    }
    let titles = NativeMemoryAtlasOriginalStage.allCases.map(\.objective)
    guard titles == pack.manifest.mission.milestones else {
      return memoryAtlasUnavailableGallery(reason: "Restore the original The Memory Atlas objectives.")
    }
    let reward = pack.manifest.mission.reward
    guard let instance = memoryAtlasMission else {
      let quote = memoryAtlasReview(.accept)
      return .init(name: pack.manifest.mission.title, status: quote.allowed ? .available : .locked,
        objective: quote.issues.first ?? "Review Vale's commission at Reris in Galaxy 1. Collect the original instrument separately.",
        briefing: pack.manifest.mission.briefing,
        destination: "Reris / Galaxy 1", reward: reward, prerequisites: quote.issues,
        completed: 0, milestones: memoryAtlasGalleryMilestones(titles, completed: 0, canContinue: false),
        trialDigest: nil, savedInstance: nil)
    }
    guard let state = instance.savedMemoryAtlas else {
      return memoryAtlasUnavailableGallery(reason: "The original The Memory Atlas case cannot currently be verified.")
    }
    let collected = state.collection != nil
    let held = collected
      && (try? NativeMemoryAtlasCustody.resolve(instance: instance, commander: commander)) != nil
    let completed = collected ? 2 : 1
    var issues = instance.suspension.map { _ in ["Review the suspended original The Memory Atlas case before continuing."] } ?? []
    let custody: String
    let objective: String
    let destination: String
    if !collected {
      custody = "Vale retains the original instrument. Your acceptance has not issued it or reserved cargo space."
      objective = "Collect Vale's original instrument at Reris when your hold has one free tonne."
      destination = "Reris / Galaxy 1"
    } else if held {
      custody = "The same original reference instrument is aboard and occupies one tonne. It is still owed to Vale."
      objective = "Obtain access to the three independent orbital landmarks at Nedasen. Keep the original reference aboard."
      destination = "Nedasen / Galaxy 1"
      // No actual landmark/instrument source, mesh or diary consent supplier has been admitted yet.
      // Requirements remain visible; names, proximity and journal counts never qualify them.
      issues.append("The original Nedasen landmarks and their independent instrument readings are not currently available.")
    } else {
      custody = "The original instrument is no longer held. Its recorded issue has not created a replacement."
      objective = "Review the original instrument's custody before continuing the The Memory Atlas survey."
      destination = "Original loan / Reris / Galaxy 1"
      issues.append("The original reference is unavailable; survey work cannot use another item's identity.")
    }
    let status: GalleryStatus = issues.isEmpty ? .active : .locked
    let requirements = "Survey requirements: observe all three original orbital landmarks independently of travel diaries. Keep each same front-view, nearest unobstructed target at 250-1,500 range units and within two degrees for 12 uninterrupted seconds. Unfinished readings reset on interruption or load; completed readings persist. Compare two actual landmark instruments with the original watcher; each measured error must be at most 20m. Recollection remains testimony. The original custodian controls diary consent; no private diary fields may be published by the hazard-only settlement. Actual living reception and both selected branch proofs remain separate."
    return .init(name: pack.manifest.mission.title, status: status,
      objective: issues.first ?? objective,
      briefing: pack.manifest.mission.briefing + "\n\n" + custody + "\n\n" + requirements
        + "\n\n" + instance.journal.joined(separator: "\n"),
      destination: destination, reward: reward, prerequisites: issues,
      completed: completed,
      milestones: memoryAtlasGalleryMilestones(titles, completed: completed,
        canContinue: issues.isEmpty && !collected),
      trialDigest: nil, savedInstance: instance.id)
  }

  /// Current missing content keeps original saved custody/history; it grants no replacement.
  func memoryAtlasMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativeMemoryAtlasDefinition.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return memoryAtlasUnavailableGallery(
      reason: "Restore the original The Memory Atlas content. The saved case and instrument history remain recorded.")
  }

  private func memoryAtlasGalleryMilestones(_ titles: [String], completed: Int,
    canContinue: Bool) -> [MissionMilestone]
  {
    titles.enumerated().map { index, title in
      let state: String
      if index < completed { state = "Complete" }
      else if index == completed && canContinue && index < 2 { state = "Current" }
      else { state = index < 2 ? "Upcoming" : "Unavailable" }
      return .init(title: title, state: state)
    }
  }

  private func memoryAtlasUnavailableGallery(reason: String) -> GalleryMission {
    .init(name: "The Memory Atlas", status: .locked, objective: reason,
      briefing: "Review the original The Memory Atlas commission, retained instrument and case history.",
      destination: "Original case / Reris / Galaxy 1", reward: "No settlement available.",
      prerequisites: [reason], completed: 0, milestones: [], trialDigest: nil,
      savedInstance: memoryAtlasMission?.id)
  }
}
