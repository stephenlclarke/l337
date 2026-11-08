import Foundation
import Testing

@testable import L337Core

/// IDs below describe UNTRUSTED MODEL INPUT, not real requests, crews, consent or slots.
/// Positive console custody uses the existing actual native opening fixture. UNRUN.
struct NativeAssemblyCapacityConsoleUnitTests {
  private func register(mission: UUID = ScriptIdentity.uuid("untrusted-c23-model-case"))
    -> NativeAssemblyCapacityRegisterCandidate
  {
    .init(mission: mission,
      proposals: (0..<5).map { ScriptIdentity.uuid("untrusted-c23-request-\($0)") },
      crews: (0..<3).map { ScriptIdentity.uuid("untrusted-c23-crew-label-\($0)") }, protectedSlot: 3)
  }

  private func filled(_ register: NativeAssemblyCapacityRegisterCandidate,
    side: NativeAssemblyCapacityDraft.Side = .port) throws -> NativeAssemblyCapacityDraft
  {
    var draft = try NativeAssemblyCapacityDraft(register: register, side: side)
    for proposal in register.proposals {
      draft = try draft.setting(.init(proposal: proposal, allocation: .waiting))
    }
    for index in 0..<3 {
      draft = try draft.setting(.init(proposal: register.proposals[index],
        allocation: .working(slot: index, crew: register.crews[index])))
    }
    return draft
  }

  @Test func bothCandidateTestsAccountForFiveRequestsAndKeepTheProtectedSlotFree() throws {
    let input = register()
    let port = try filled(input)
    let starboard = try filled(input, side: .starboard)
    let report = try port.assess()
    #expect(report.candidateWithinLimits && report.submitted == 5)
    #expect(report.working == 3 && report.waiting == 2 && report.freeModelSlots == 1)
    #expect(report.protectedSlotFree && report.target == "assembly-of-orbits-work-port")
    #expect(try starboard.assess().target == "assembly-of-orbits-work-starboard")
    #expect(starboard != port)
    let decoded = try JSONDecoder().decode(NativeAssemblyCapacityDraft.self,
      from: JSONEncoder().encode(port))
    #expect(decoded == port && decoded.shapeValid)
    #expect(try decoded.assess() == report)
    let same = try port.setting(try #require(port.choices.first))
    #expect(same == port)
    let incomplete = try port.removing(input.proposals[4])
    #expect(try incomplete.assess().issues.contains(.unsubmitted(input.proposals[4])))
    #expect(try !incomplete.assess().candidateWithinLimits)
    #expect(port.choices.count == 5 && incomplete.revision == port.revision + 1)
    var waiting = try NativeAssemblyCapacityDraft(register: input, side: .port)
    for proposal in input.proposals {
      waiting = try waiting.setting(.init(proposal: proposal, allocation: .waiting))
    }
    let idle = try waiting.assess()
    #expect(idle.candidateWithinLimits && idle.working == 0 && idle.waiting == 5)
    #expect(idle.feedback.contains { $0.contains("does not dispatch") })
  }

  @Test func capacityConflictsRemainEditableAndUnknownOrMalformedInputsCannotBeInterpreted() throws {
    let input = register()
    let original = try filled(input)
    let crowded = try original.setting(.init(proposal: input.proposals[3],
      allocation: .working(slot: 3, crew: input.crews[0])))
    let report = try crowded.assess()
    #expect(report.issues.contains(.workingCapacityExceeded))
    #expect(report.issues.contains(.protectedSlotClaimed(input.proposals[3])))
    #expect(report.issues.contains(.crewConflict(input.crews[0], [input.proposals[0], input.proposals[3]])))
    #expect(!report.candidateWithinLimits && !report.protectedSlotFree)
    let collision = try original.setting(.init(proposal: input.proposals[2],
      allocation: .working(slot: 0, crew: input.crews[2])))
    #expect(try collision.assess().issues.contains(.slotConflict(0, [input.proposals[0], input.proposals[2]])))
    let repaired = try crowded.setting(.init(proposal: input.proposals[3], allocation: .waiting))
    #expect(try repaired.assess().candidateWithinLimits)
    #expect(original.choices.count == 5 && original.choices[3].allocation == .waiting)
    let foreign = ScriptIdentity.uuid("untrusted-c23-outside-label")
    #expect(throws: (any Error).self) {
      try original.setting(.init(proposal: foreign, allocation: .waiting))
    }
    #expect(throws: (any Error).self) {
      try original.setting(.init(proposal: input.proposals[0], allocation: .working(slot: 4, crew: input.crews[0])))
    }
    #expect(throws: (any Error).self) {
      try original.setting(.init(proposal: input.proposals[0], allocation: .working(slot: 0, crew: foreign)))
    }
    var raw = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    var registerData = try #require(raw["register"] as? [String: Any])
    registerData["proposals"] = Array(repeating: input.proposals[0].uuidString, count: 96)
    raw["register"] = registerData
    let malformed = try JSONDecoder().decode(NativeAssemblyCapacityDraft.self,
      from: JSONSerialization.data(withJSONObject: raw))
    #expect(!malformed.shapeValid)
    #expect(throws: (any Error).self) { try malformed.assess() }
  }

  @Test func actualLoanBoundsReadOnlyPreviewAndCandidateDataCannotGrantPhysicalWork() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    let unaccepted = await fixture.runtime.snapshot()
    #expect(throws: (any Error).self) { try unaccepted.assemblyCapacityContext() }
    let accepted = try await fixture.confirm(.accept)
    #expect(throws: (any Error).self) { try accepted.assemblyCapacityContext() }
    let collected = try await fixture.confirm(.collectReference)
    let context = try collected.assemblyCapacityContext()
    let draft = try filled(register(mission: context.mission))
    let before = collected.commander
    let files = try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent())
    #expect(try collected.previewAssemblyCapacity(draft, context: context).candidateWithinLimits)
    #expect(context.isCurrent(in: collected))
    #expect(collected.commander == before)
    #expect(collected.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(collected.assemblyOfOrbitsMission?.completionReceipt == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.files.save.deletingLastPathComponent()) == files)
    let foreign = try filled(register())
    #expect(throws: (any Error).self) { try collected.previewAssemblyCapacity(foreign, context: context) }
    var stale = collected
    stale.nativeStationRuntimeEpoch = UUID()
    #expect(!context.isCurrent(in: stale))
    #expect(throws: (any Error).self) { try stale.previewAssemblyCapacity(draft, context: context) }
    var missing = collected
    if let inventory = missing.commander.savedEquipmentInventory {
      missing.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.id != context.reference.original })
    }
    #expect(!context.isCurrent(in: missing))
    #expect(throws: (any Error).self) { try missing.previewAssemblyCapacity(draft, context: context) }
  }

  @Test func currentColdLoadKeepsTheOriginalButRequiresANewConsoleContext() async throws {
    let fixture = try await AssemblyOpeningFixture()
    defer { fixture.clean() }
    _ = try await fixture.confirm(.accept)
    let collected = try await fixture.confirm(.collectReference)
    let context = try collected.assemblyCapacityContext()
    let draft = try filled(register(mission: context.mission), side: .starboard)
    let untrustedDraftBytes = try JSONEncoder().encode(draft)
    try await fixture.runtime.save(to: fixture.files.save)
    try await fixture.runtime.load(from: fixture.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(!context.isCurrent(in: loaded))
    #expect(throws: (any Error).self) { try loaded.previewAssemblyCapacity(draft, context: context) }
    let current = try loaded.assemblyCapacityContext()
    #expect(current.reference.original == context.reference.original)
    #expect(current.reference.issueCommand == context.reference.issueCommand)
    let decoded = try JSONDecoder().decode(NativeAssemblyCapacityDraft.self, from: untrustedDraftBytes)
    #expect(try loaded.previewAssemblyCapacity(decoded, context: current).candidateWithinLimits)
    #expect(loaded.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(loaded.commander.equipmentInventory == collected.commander.equipmentInventory)
    #expect(loaded.commander.scriptState.savedClueJournal == collected.commander.scriptState.savedClueJournal)
  }
}
