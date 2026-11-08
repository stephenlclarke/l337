import Foundation
import Testing

@testable import L337Core

/// Proposed IDs are PLAYER MODEL LABELS. The fixture supplies only the existing actual
/// commission/reference. No register, crew, corridor consent or work receipt is fabricated.
struct NativeAssemblyCapacityDraftSaveTests {
  private func draft(mission: UUID, side: NativeAssemblyCapacityDraft.Side)
    throws -> NativeAssemblyCapacityDraft
  {
    let input = NativeAssemblyCapacityRegisterCandidate(mission: mission,
      proposals: (0..<5).map { ScriptIdentity.uuid("c23-player-proposal-\($0)") },
      crews: (0..<3).map { ScriptIdentity.uuid("c23-player-crew-label-\($0)") }, protectedSlot: 3)
    var proposal = try NativeAssemblyCapacityDraft(register: input, side: side)
    for id in input.proposals { proposal = try proposal.setting(.init(proposal: id, allocation: .waiting)) }
    for index in 0..<3 {
      proposal = try proposal.setting(.init(proposal: input.proposals[index],
        allocation: .working(slot: index, crew: input.crews[index])))
    }
    return proposal
  }

  @Test func actualConsoleDraftWriterRefusalRetriesOnceAndBothSidesSurviveIndependentColdLoad()
    async throws
  {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let context = try await fixture.runtime.assemblyCapacityContext()
    let port = try draft(mission: context.mission, side: .port)
    let starboard = try draft(mission: context.mission, side: .starboard)
    let original = try #require(collected.assemblyOfOrbitsMission)
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    var candidate = collected
    let changed = try candidate.saveAssemblyCapacityDraft(port, context: context)
    try #require(changed && candidate.commander.valid
      && NativeAssemblyOfOrbitsSave.validateClaims(candidate.commander))
    #expect(candidate.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.capacityDrafts == ["port": port])
    let preserved = try fixture.files.blockWrites("assembly-player-plan")
    await #expect(throws: (any Error).self) {
      try await fixture.runtime.scriptCommand { game in
        do { return try game.saveAssemblyCapacityDraft(port, context: context) }
        catch { Issue.record(error); throw error }
      }
    }
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == collected.commander && refused.bodies == collected.bodies)
    #expect(refused.market == collected.market && refused.jumpCountdown == collected.jumpCountdown)
    #expect(context.isCurrent(in: refused))
    #expect(try ScriptFinanceTestFixture.files(preserved) == files)
    #expect(try Data(contentsOf: fixture.files.save.deletingLastPathComponent()) == Data([1]))
    try fixture.files.restoreWrites(preserved, files: files)
    let storedPort = try await fixture.runtime.saveAssemblyCapacityDraft(port, context: context)
    #expect(storedPort)
    let afterPort = await fixture.runtime.snapshot()
    #expect(!context.isCurrent(in: afterPort))
    let current = try await fixture.runtime.assemblyCapacityContext()
    let storedStarboard = try await fixture.runtime.saveAssemblyCapacityDraft(starboard, context: current)
    #expect(storedStarboard)
    let after = await fixture.runtime.snapshot()
    let mission = try #require(after.assemblyOfOrbitsMission)
    #expect(mission.savedAssemblyOfOrbits?.capacityDrafts == ["port": port, "starboard": starboard])
    #expect(mission.revision == original.revision + 2)
    #expect(mission.savedAssemblyOfOrbits?.acceptance == original.savedAssemblyOfOrbits?.acceptance)
    #expect(mission.savedAssemblyOfOrbits?.collection == original.savedAssemblyOfOrbits?.collection)
    #expect(mission.gearIssues == original.gearIssues && mission.receipts == original.receipts)
    #expect(mission.milestones == [0, 1] && mission.journal == original.journal)
    #expect(mission.outcome == .active && mission.completionReceipt == nil)
    #expect(after.commander.scriptState.nextEvent == collected.commander.scriptState.nextEvent)
    #expect(after.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(after.commander.credits == collected.commander.credits && after.commander.cargo == collected.commander.cargo)
    #expect(after.commander.nativePeople == collected.commander.nativePeople)
    #expect(after.commander.scriptState.savedClueJournal == collected.commander.scriptState.savedClueJournal)
    let beforeDuplicate = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let sameContext = try await fixture.runtime.assemblyCapacityContext()
    let duplicate = try await fixture.runtime.saveAssemblyCapacityDraft(starboard, context: sameContext)
    let unchanged = await fixture.runtime.snapshot()
    #expect(!duplicate && sameContext.isCurrent(in: unchanged))
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == beforeDuplicate)
    var coldGame = Game(executive: false)
    coldGame.scriptPacks = [try ScriptPackLibrary.read(ScriptPackLibrary.bundledAssemblyOfOrbitsDirectory)]
    let cold = GameRuntime(game: coldGame)
    try await cold.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(!sameContext.isCurrent(in: loaded))
    let coldContext = try await cold.assemblyCapacityContext()
    let recalledPort = try await cold.savedAssemblyCapacityDraft(.port, context: coldContext)
    let recalledStarboard = try await cold.savedAssemblyCapacityDraft(.starboard, context: coldContext)
    #expect(recalledPort == port && recalledStarboard == starboard)
    #expect(coldContext.reference.original == context.reference.original)
    #expect(coldContext.reference.issueCommand == context.reference.issueCommand)
    #expect(loaded.commander.equipmentInventory == after.commander.equipmentInventory)
    #expect(loaded.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(loaded.assemblyOfOrbitsMission?.completionReceipt == nil)
    #expect(try loaded.previewAssemblyCapacity(port, context: coldContext).candidateWithinLimits)
  }

  @Test func conflictingPlayerPlanStaysEditableWhileForeignStaleAndMissingConsoleChangesRefuse()
    async throws
  {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    await #expect(throws: (any Error).self) { try await fixture.runtime.assemblyCapacityContext() }
    _ = try await fixture.confirm(.collectReference)
    let context = try await fixture.runtime.assemblyCapacityContext()
    let valid = try draft(mission: context.mission, side: .port)
    let conflict = try valid.setting(.init(proposal: valid.register.proposals[3],
      allocation: .working(slot: 3, crew: valid.register.crews[0])))
    let assessment = try conflict.assess()
    try #require(conflict.shapeValid && !assessment.candidateWithinLimits)
    let saved = try await fixture.runtime.saveAssemblyCapacityDraft(conflict, context: context)
    #expect(saved)
    let before = await fixture.runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let current = try await fixture.runtime.assemblyCapacityContext()
    let recalled = try await fixture.runtime.savedAssemblyCapacityDraft(.port, context: current)
    #expect(recalled == conflict)
    #expect(try recalled?.assess().issues.contains(.protectedSlotClaimed(valid.register.proposals[3])) == true)
    let foreign = try draft(mission: UUID(), side: .port)
    await #expect(throws: (any Error).self) {
      try await fixture.runtime.saveAssemblyCapacityDraft(foreign, context: current)
    }
    await #expect(throws: (any Error).self) {
      try await fixture.runtime.saveAssemblyCapacityDraft(valid, context: context)
    }
    var missing = before
    let inventory = try #require(missing.commander.savedEquipmentInventory)
    missing.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
      owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
      items: inventory.items.filter { $0.id != current.reference.original })
    #expect(throws: (any Error).self) { try missing.saveAssemblyCapacityDraft(valid, context: current) }
    let refused = await fixture.runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
    let cleared = try await fixture.runtime.clearAssemblyCapacityDraft(.port, context: current)
    #expect(cleared)
    let after = await fixture.runtime.snapshot()
    #expect(after.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.capacityDrafts == nil)
    #expect(after.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(after.commander.credits == before.commander.credits && after.commander.cargo == before.commander.cargo)
    let fresh = try await fixture.runtime.assemblyCapacityContext()
    let nilFiles = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let absent = try await fixture.runtime.clearAssemblyCapacityDraft(.starboard, context: fresh)
    #expect(!absent)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == nilFiles)
  }

  @Test func currentCaseDraftsAreBoundedSideBoundAndCannotSmuggleNativeWorkClaims() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    _ = try await fixture.confirm(.collectReference)
    let context = try await fixture.runtime.assemblyCapacityContext()
    let proposal = try draft(mission: context.mission, side: .port)
    _ = try await fixture.runtime.saveAssemblyCapacityDraft(proposal, context: context)
    let game = await fixture.runtime.snapshot()
    let instance = try #require(game.assemblyOfOrbitsMission)
    let raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(instance)) as? [String: Any])
    let leaf = try #require(raw[NativeAssemblyOfOrbitsSave.field] as? [String: Any])
    let drafts = try #require(leaf["capacityDrafts"] as? [String: Any])
    let plan = try #require(drafts["port"] as? [String: Any])
    func archive(_ altered: [String: Any]) throws -> Data {
      var value = raw
      value[NativeAssemblyOfOrbitsSave.field] = altered
      return try JSONSerialization.data(withJSONObject: ["instances": [instance.id.uuidString: value]])
    }
    try NativeAssemblyOfOrbitsSave.validateFields(archive(leaf), part: .missions)
    var changedSide = leaf
    changedSide["capacityDrafts"] = ["starboard": plan]
    var tooMany = leaf
    tooMany["capacityDrafts"] = ["port": plan, "starboard": plan, "forward": plan]
    var empty = leaf
    empty["capacityDrafts"] = [String: Any]()
    var null = leaf
    null["capacityDrafts"] = NSNull()
    var premature = leaf
    premature.removeValue(forKey: "collection")
    var foreign = leaf
    var foreignPlan = plan
    var register = try #require(plan["register"] as? [String: Any])
    register["mission"] = UUID().uuidString
    foreignPlan["register"] = register
    foreign["capacityDrafts"] = ["port": foreignPlan]
    var workClaim = leaf
    var invented = plan
    invented["nativeWorkCompleted"] = true
    workClaim["capacityDrafts"] = ["port": invented]
    for altered in [changedSide, tooMany, empty, null, premature, foreign, workClaim] {
      #expect(throws: (any Error).self) {
        try NativeAssemblyOfOrbitsSave.validateFields(archive(altered), part: .missions)
      }
    }
    #expect(game.assemblyOfOrbitsMission?.milestones == [0, 1])
    let unchanged = await fixture.runtime.snapshot()
    #expect(game.commander.nativePeople == unchanged.commander.nativePeople)
    #expect(game.assemblyOfOrbitsMission?.completionReceipt == nil)
  }
}

extension NativeAssemblyCapacityDraftSaveTests {
  @Test func unboundActualActorsCannotSaveOrClearButCanRecallAnExistingPlayerProposal()
    async throws
  {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let originalFiles = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let unbound = GameRuntime(game: collected)
    let context = try await unbound.assemblyCapacityContext()
    let before = await unbound.snapshot()
    try #require(!before.scriptDurabilityAvailable && context.isCurrent(in: before))
    let plan = try draft(mission: context.mission, side: .port)
    let absent = try await unbound.savedAssemblyCapacityDraft(.port, context: context)
    #expect(absent == nil)
    var direct = before
    #expect(throws: MissionPackError.self) {
      try direct.saveAssemblyCapacityDraft(plan, context: context)
    }
    #expect(direct.commander == before.commander)
    await #expect(throws: MissionPackError.self) {
      try await unbound.saveAssemblyCapacityDraft(plan, context: context)
    }
    let refusedSave = await unbound.snapshot()
    #expect(refusedSave.commander == before.commander && refusedSave.bodies == before.bodies)
    #expect(refusedSave.market == before.market && refusedSave.jumpCountdown == before.jumpCountdown)
    #expect(context.isCurrent(in: refusedSave))
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == originalFiles)

    let bound = try await fixture.runtime.assemblyCapacityContext()
    let committed = try await fixture.runtime.saveAssemblyCapacityDraft(plan, context: bound)
    try #require(committed)
    let stored = await fixture.runtime.snapshot()
    let storedFiles = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    let unboundClear = GameRuntime(game: stored)
    let clearContext = try await unboundClear.assemblyCapacityContext()
    let clearBefore = await unboundClear.snapshot()
    try #require(!clearBefore.scriptDurabilityAvailable && clearContext.isCurrent(in: clearBefore))
    let recalled = try await unboundClear.savedAssemblyCapacityDraft(.port, context: clearContext)
    #expect(recalled == plan)
    var directClear = clearBefore
    #expect(throws: MissionPackError.self) {
      try directClear.clearAssemblyCapacityDraft(.port, context: clearContext)
    }
    #expect(directClear.commander == clearBefore.commander)
    await #expect(throws: MissionPackError.self) {
      try await unboundClear.clearAssemblyCapacityDraft(.port, context: clearContext)
    }
    let refusedClear = await unboundClear.snapshot()
    #expect(refusedClear.commander == clearBefore.commander && refusedClear.bodies == clearBefore.bodies)
    #expect(refusedClear.market == clearBefore.market && refusedClear.jumpCountdown == clearBefore.jumpCountdown)
    #expect(clearContext.isCurrent(in: refusedClear))
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == storedFiles)
    let retained = try await unboundClear.savedAssemblyCapacityDraft(.port, context: clearContext)
    #expect(retained == plan)
  }
}
