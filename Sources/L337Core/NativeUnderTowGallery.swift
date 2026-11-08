import Foundation

extension Game {
  /// Original C24 history and next requirements only. Reading never issues a permission,
  /// reference, observation, settlement, fee, clue or trial commander.
  func underTowGalleryEntry(_ pack: ScriptPack) -> GalleryMission? {
    guard NativeUnderTowDefinition.applies(pack) else { return nil }
    guard NativeUnderTowDefinition.matches(pack),
      underTowPack != nil, NativeUnderTowSave.validateClaims(commander)
    else {
      return underTowUnavailableGallery(
        reason: "The original Under Tow content or case record cannot currently be verified.")
    }
    let titles = pack.manifest.mission.milestones
    guard titles.count == 9 else {
      return underTowUnavailableGallery(reason: "Restore the original Under Tow objectives.")
    }
    let reward = pack.manifest.mission.reward
    guard let instance = underTowMission else {
      let quote = underTowReview(.accept)
      return .init(name: pack.manifest.mission.title, status: quote.allowed ? .available : .locked,
        objective: quote.issues.first ?? "Review Penn's commission at Luera in Galaxy 8. Collect the original instrument separately.",
        briefing: pack.manifest.mission.briefing,
        destination: "Luera / Galaxy 8", reward: reward, prerequisites: quote.issues,
        completed: 0, milestones: underTowGalleryMilestones(titles, completed: 0, canContinue: false),
        trialDigest: nil, savedInstance: nil)
    }
    guard let state = instance.savedUnderTow else {
      return underTowUnavailableGallery(reason: "The original Under Tow case cannot currently be verified.")
    }
    let collected = state.collection != nil
    let held = collected
      && (try? NativeUnderTowCustody.resolve(instance: instance, commander: commander)) != nil
    let completed = collected ? 2 : 1
    var issues = instance.suspension.map { _ in ["Review the suspended original Under Tow case before continuing."] } ?? []
    let custody: String
    let objective: String
    let destination: String
    if !collected {
      custody = "Penn retains the original instrument. Your acceptance has not issued it or reserved cargo space."
      objective = "Collect Penn's original instrument at Luera when your hold has one free tonne."
      destination = "Luera / Galaxy 8"
    } else if held {
      custody = "The same original reference instrument is aboard and occupies one tonne. It is still owed to Penn."
      objective = "Obtain access to the three original rescue collars at Allion. Keep the original reference aboard."
      destination = "Allion / Galaxy 8"
      // No actual rescue-collar/load-limit source, mesh or consent supplier has been admitted yet.
      // Requirements remain visible; names, proximity and journal counts never qualify them.
      issues.append("The original Allion rescue collars and their signed independent load limits are not currently available.")
    } else {
      custody = "The original instrument is no longer held. Its recorded issue has not created a replacement."
      objective = "Review the original instrument's custody before continuing the Under Tow survey."
      destination = "Original loan / Luera / Galaxy 8"
      issues.append("The original reference is unavailable; survey work cannot use another item's identity.")
    }
    let status: GalleryStatus = issues.isEmpty ? .active : .locked
    let requirements = "Survey requirements: measure all three original rescue collars and their signed independent load limits. Obtain each source's permission. Keep the same front-view, nearest unobstructed target at 250-1,500 range units and within two degrees for 12 uninterrupted seconds. Unfinished readings reset on interruption or load; completed readings persist. Later, the source-owned rig must test both compatible 2m/2m and 3m/3m couplers at 50 load units for 15 seconds and reject a 61-unit command. Named tug, crew and compatible receiving remain separate requirements."
    return .init(name: pack.manifest.mission.title, status: status,
      objective: issues.first ?? objective,
      briefing: pack.manifest.mission.briefing + "\n\n" + custody + "\n\n" + requirements
        + "\n\n" + instance.journal.joined(separator: "\n"),
      destination: destination, reward: reward, prerequisites: issues,
      completed: completed,
      milestones: underTowGalleryMilestones(titles, completed: completed,
        canContinue: issues.isEmpty && !collected),
      trialDigest: nil, savedInstance: instance.id)
  }

  /// Current missing content keeps original saved custody/history; it grants no replacement.
  func underTowMissingGalleryEntry(_ instance: ScriptInstance) -> GalleryMission? {
    guard NativeUnderTowDefinition.marked(instance),
      commander.scriptState.instances[instance.id] == instance, scriptPack(for: instance) == nil
    else { return nil }
    return underTowUnavailableGallery(
      reason: "Restore the original Under Tow content. The saved case and instrument history remain recorded.")
  }

  private func underTowGalleryMilestones(_ titles: [String], completed: Int,
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

  private func underTowUnavailableGallery(reason: String) -> GalleryMission {
    .init(name: "Under Tow", status: .locked, objective: reason,
      briefing: "Review the original Under Tow commission, retained instrument and case history.",
      destination: "Original case / Luera / Galaxy 8", reward: "No settlement available.",
      prerequisites: [reason], completed: 0, milestones: [], trialDigest: nil,
      savedInstance: underTowMission?.id)
  }
}
