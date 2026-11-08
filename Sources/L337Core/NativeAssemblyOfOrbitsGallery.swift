import Foundation

extension Game {
  /// Original C23 history and next requirements only. Reading never issues a permission,
  /// reference, observation, settlement, fee, clue or trial commander.
  func assemblyOfOrbitsGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeAssemblyOfOrbitsDefinition.applies(pack) else { return nil }
    guard NativeAssemblyOfOrbitsDefinition.matches(pack),
      assemblyOfOrbitsPack != nil, NativeAssemblyOfOrbitsSave.validateClaims(commander)
    else {
      return assemblyOfOrbitsUnavailableGallery(
        reason: "The original Assembly content or case record cannot currently be verified.")
    }
    let titles = pack.manifest.mission.milestones
    guard titles.count == 9 else {
      return assemblyOfOrbitsUnavailableGallery(reason: "Restore the original Assembly objectives.")
    }
    let reward = pack.manifest.mission.reward
    guard let instance = assemblyOfOrbitsMission else {
      let quote = assemblyOfOrbitsReview(.accept)
      return .init(name: pack.manifest.mission.title, status: quote.allowed ? .available : .locked,
        objective: quote.issues.first ?? "Review Voss's commission at Irkenan in Galaxy 7. Collect the original instrument separately.",
        briefing: pack.manifest.mission.briefing,
        destination: "Irkenan / Galaxy 7", reward: reward, prerequisites: quote.issues,
        completed: 0, milestones: assemblyOfOrbitsGalleryMilestones(titles, completed: 0, canContinue: false),
        trialDigest: nil, savedInstance: nil)
    }
    guard let state = instance.savedAssemblyOfOrbits else {
      return assemblyOfOrbitsUnavailableGallery(reason: "The original Assembly case cannot currently be verified.")
    }
    let collected = state.collection != nil
    let held = collected
      && (try? NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: commander)) != nil
    let completed = collected ? 2 : 1
    var issues = instance.suspension.map { _ in ["Review the suspended original Assembly case before continuing."] } ?? []
    let custody: String
    let objective: String
    let destination: String
    if !collected {
      custody = "Voss retains the original instrument. Your acceptance has not issued it or reserved cargo space."
      objective = "Collect Voss's original instrument at Irkenan when your hold has one free tonne."
      destination = "Irkenan / Galaxy 7"
    } else if held {
      custody = "The same original reference instrument is aboard and occupies one tonne. It is still owed to Voss."
      objective = "Obtain access to the three consented registers at Darik. Keep the original reference aboard."
      destination = "Darik / Galaxy 7"
      // No real register/corridor birth, mesh or consent supplier has been admitted yet.
      // Requirements remain visible; names, proximity and journal counts never qualify them.
      issues.append("The original Darik registers and their consented readings are not currently available.")
    } else {
      custody = "The original instrument is no longer held. Its recorded issue has not created a replacement."
      objective = "Review the original instrument's custody before continuing the Assembly survey."
      destination = "Original loan / Irkenan / Galaxy 7"
      issues.append("The original reference is unavailable; survey work cannot use another item's identity.")
    }
    let status: GalleryStatus = issues.isEmpty ? .active : .locked
    let requirements = "Survey requirements: compare all three original occupancy/work registers with actual corridor use. Obtain consent for each register. Keep the same front-view, nearest unobstructed target at 250-1,500 range units, within two degrees of aim, for 12 uninterrupted seconds. Unfinished readings reset after interruption or load; completed readings remain recorded."
    return .init(name: pack.manifest.mission.title, status: status,
      objective: issues.first ?? objective,
      briefing: pack.manifest.mission.briefing + "\n\n" + custody + "\n\n" + requirements
        + "\n\n" + instance.journal.joined(separator: "\n"),
      destination: destination, reward: reward, prerequisites: issues,
      completed: completed,
      milestones: assemblyOfOrbitsGalleryMilestones(titles, completed: completed,
        canContinue: issues.isEmpty && !collected),
      trialDigest: nil, savedInstance: instance.id)
  }

  /// Current missing content keeps original saved custody/history; it grants no replacement.
  func assemblyOfOrbitsMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativeAssemblyOfOrbitsDefinition.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return assemblyOfOrbitsUnavailableGallery(
      reason: "Restore the original Assembly content. The saved case and instrument history remain recorded.")
  }

  private func assemblyOfOrbitsGalleryMilestones(_ titles: [String], completed: Int,
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

  private func assemblyOfOrbitsUnavailableGallery(reason: String) -> GalleryMission {
    .init(name: "An Assembly of Orbits", status: .locked, objective: reason,
      briefing: "Review the original Assembly commission, retained instrument and case history.",
      destination: "Original case / Irkenan / Galaxy 7", reward: "No settlement available.",
      prerequisites: [reason], completed: 0, milestones: [], trialDigest: nil,
      savedInstance: assemblyOfOrbitsMission?.id)
  }
}
