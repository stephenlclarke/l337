import Foundation
import Testing

@testable import L337Core

/// Deliberately untrusted historical bytes for negative tests, never a live receipt factory.
private struct UntrustedC03LaboratoryRecord<F: Encodable>: Encodable {
  let operation: UUID
  let facts: F
}

struct NativeC03SealLaboratoryAnalysisUnitTests {
  private func copying(_ state: NativeHollowManifestState,
    inspections: [NativeHollowManifestSealInspection], laboratory: NativeHollowManifestLaboratoryReceipt?)
    -> NativeHollowManifestState
  {
    .init(birth: state.birth, phase: state.phase, nextSourceSequence: state.nextSourceSequence,
      admissions: state.admissions, firstAdmissions: state.firstAdmissions,
      latestAdmissions: state.latestAdmissions, terminals: state.terminals, consents: state.consents,
      firstCompromises: state.firstCompromises, latestSealDamage: state.latestSealDamage,
      damageRevision: state.damageRevision, withdrawals: state.withdrawals,
      routeAnchors: state.routeAnchors, sourceFrame: state.sourceFrame,
      ownedEncounterID: state.ownedEncounterID, routes: state.routes,
      inspections: inspections, laboratory: laboratory,
      wakeTrail: state.wakeTrail, custodyRegister: state.custodyRegister,
      crewSource: state.crewSource, crewLogAccess: state.crewLogAccess, caseFile: state.caseFile)
  }

  private func corruptingLast(_ actual: NativeHollowManifestSealInspection,
    other: NativeHollowManifestSealInspection, mode: Int) throws -> NativeHollowManifestSealInspection
  {
    let f = actual.facts
    let last = f.last
    var heights = last.reliefHeights
    if mode == 1 {
      try #require(!heights.isEmpty)
      heights[0] += 10 * NativeC03SealGeometry.maximumReliefHeightError
    }
    let changed = NativeC03SealProbe.Reading(
      actor: mode == 2 ? other.facts.last.actor : last.actor,
      component: mode == 2 ? other.facts.last.component : last.component,
      slot: last.slot, physicalTime: mode == 0 ? f.first.physicalTime : last.physicalTime,
      rootPose: last.rootPose, reliefHeights: heights,
      surfaceRanges: last.surfaceRanges, maximumProbeAngle: last.maximumProbeAngle)
    let facts = NativeHollowManifestSealInspection.Facts(evidence: f.evidence,
      admission: f.admission, original: f.original, request: f.request, reply: f.reply,
      player: f.player, carrier: f.carrier, inventoryRevision: f.inventoryRevision,
      instrument: f.instrument, epoch: f.epoch, sequence: f.sequence,
      firstFrame: f.firstFrame, lastFrame: f.lastFrame, first: f.first, last: changed)
    // Correctly rehash the FALSE candidate: the source/measurement join must still reject it.
    return .init(operation: try NativeHollowManifestSealInspection.identity(facts), facts: facts)
  }

  private func decoded<T: Decodable, F: Encodable>(_ type: T.Type,
    operation: UUID, facts: F) throws -> T
  {
    try JSONDecoder().decode(type, from: JSONEncoder().encode(
      UntrustedC03LaboratoryRecord(operation: operation, facts: facts)))
  }

  private func confirm(_ runtime: GameRuntime) async throws -> Game {
    let reviewed = try await reviewActualHollowLaboratory(runtime)
    try #require(reviewed.contractBoard.hollowManifestQuote?.allowed == true)
    await runtime.scriptPageKey("right", expected: reviewed.scriptPagePresentation)
    let chosen = await runtime.snapshot()
    try #require(chosen.contractBoard.action == .accept)
    await runtime.scriptPageKey("return", expected: chosen.scriptPagePresentation)
    let issued = await runtime.snapshot()
    try #require(issued.hollowManifestMission?.savedHollowManifest?.laboratory != nil)
    return issued
  }

  @Test func actualDistinctOriginalPatternsAreExaminedAndRetainedWithTheLoanAcrossColdLoad() async throws {
    let (runtime, commission) = try await actualHollowLaboratoryRuntime()
    defer { commission.clean() }
    let reviewed = try await reviewActualHollowLaboratory(runtime)
    let original = try #require(reviewed.hollowManifestMission?.savedHollowManifest)
    let comparison = try NativeC03SealLaboratoryAnalysis.examining(original)
    #expect(comparison.shapeValid && comparison.valid(in: original))
    #expect(comparison.facts.master == original.birth.master.id)
    #expect(comparison.facts.observations.map(\.slot) == NativeHollowManifestState.Slot.allCases)
    #expect(Set(comparison.facts.observations.map(\.seal)).count == 2)
    #expect(Set(comparison.facts.observations.map(\.component)).count == 2)
    #expect(Set(comparison.facts.observations.map(\.inspection)) == Set(original.inspections.map(\.operation)))
    #expect(comparison.facts.reliefDifferencesMetres.count == NativeC03SealGeometry.reliefs.count)
    #expect(reviewed.hollowManifestDetail().contains("PATTERN COMPARISON: TWO DISTINCT ORIGINAL SEALS MATCH"))
    let issued = try await confirm(runtime)
    let instance = try #require(issued.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let laboratory = try #require(state.laboratory)
    #expect(laboratory.facts.analysis == comparison && laboratory.valid(in: state))
    #expect(state.inspections == original.inspections && state.consents == original.consents)
    #expect(issued.commander.cargoTonnes == reviewed.commander.cargoTonnes + 1)
    #expect(issued.commander.credits == reviewed.commander.credits)
    #expect(issued.commander.scriptState.savedClueJournal == reviewed.commander.scriptState.savedClueJournal)
    try await runtime.save(to: commission.files.save)
    try await runtime.load(from: commission.files.save, persistMigrations: false)
    let restored = await runtime.snapshot()
    let cold = try #require(restored.hollowManifestMission?.savedHollowManifest)
    #expect(cold.laboratory?.facts.analysis == comparison)
    #expect(cold.laboratory?.valid(in: cold) == true)
    #expect(NativeHollowManifestSave.validateClaims(restored.commander))
    #expect(cold.inspections == original.inspections && cold.consents == original.consents)
    #expect(restored.hollowManifestMission?.milestones == [0, 1, 2])
    #expect(restored.hollowManifestMission?.outcome == .active)
  }

  @Test func partialDuplicateStaleDifferentAndCrossOriginalReadingsCannotBecomeAnExamination() async throws {
    let (runtime, commission) = try await actualHollowLaboratoryRuntime()
    defer { commission.clean() }
    let game = await runtime.snapshot()
    let state = try #require(game.hollowManifestMission?.savedHollowManifest)
    let first = try #require(state.inspections.first)
    let second = try #require(state.inspections.last)
    try #require(state.inspections.count == 2 && first.operation != second.operation)
    try #require(copying(state, inspections: state.inspections, laboratory: state.laboratory) == state)
    for observations in [[first], [first, first]] {
      let invalid = copying(state, inspections: observations, laboratory: state.laboratory)
      #expect(throws: SaveError.invalidCommander) {
        _ = try NativeC03SealLaboratoryAnalysis.examining(invalid)
      }
    }
    for mode in 0..<3 {
      let falseInspection = try corruptingLast(first, other: second, mode: mode)
      let invalid = copying(state, inspections: [falseInspection, second], laboratory: state.laboratory)
      #expect(!falseInspection.valid(in: invalid))
      #expect(throws: SaveError.invalidCommander) {
        _ = try NativeC03SealLaboratoryAnalysis.examining(invalid)
      }
    }
    let unchanged = await runtime.snapshot()
    #expect(state.laboratory == nil && game.commander == unchanged.commander)
  }

  @Test func internallyRehashedComparisonCannotSubstituteAnotherActualIdentityOrPassCurrentWriter() async throws {
    let (runtime, commission) = try await actualHollowLaboratoryRuntime()
    defer { commission.clean() }
    let issued = try await confirm(runtime)
    let instance = try #require(issued.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let laboratory = try #require(state.laboratory)
    let actual = laboratory.facts.analysis
    for values in [actual.facts.reliefDifferencesMetres + [0],
      Array(repeating: -1.0, count: actual.facts.reliefDifferencesMetres.count),
      Array(repeating: Double.infinity, count: actual.facts.reliefDifferencesMetres.count)]
    {
      let unbounded = NativeC03SealLaboratoryAnalysis.Facts(mission: actual.facts.mission,
        owner: actual.facts.owner, master: actual.facts.master,
        observations: actual.facts.observations, reliefDifferencesMetres: values)
      #expect(throws: SaveError.invalidCommander) {
        _ = try NativeC03SealLaboratoryAnalysis.identity(unbounded)
      }
    }
    let wrongMaster = try #require(actual.facts.observations.first?.seal)
    try #require(wrongMaster != actual.facts.master)
    let facts = NativeC03SealLaboratoryAnalysis.Facts(mission: actual.facts.mission,
      owner: actual.facts.owner, master: wrongMaster, observations: actual.facts.observations,
      reliefDifferencesMetres: actual.facts.reliefDifferencesMetres)
    let falseAnalysis = try decoded(NativeC03SealLaboratoryAnalysis.self,
      operation: NativeC03SealLaboratoryAnalysis.identity(facts), facts: facts)
    try #require(falseAnalysis.shapeValid)
    #expect(!falseAnalysis.valid(in: state))
    let f = laboratory.facts
    let falseFacts = NativeHollowManifestLaboratoryReceipt.Facts(mission: f.mission, owner: f.owner,
      issuer: f.issuer, dock: f.dock, carrier: f.carrier,
      beforeInventoryRevision: f.beforeInventoryRevision, afterInventoryRevision: f.afterInventoryRevision,
      beforeCredits: f.beforeCredits, afterCredits: f.afterCredits, issueCommand: f.issueCommand,
      issueSource: f.issueSource, originalKit: f.originalKit, inspections: f.inspections,
      analysis: falseAnalysis, sequence: f.sequence, physicalTime: f.physicalTime)
    let falseReceipt = try decoded(NativeHollowManifestLaboratoryReceipt.self,
      operation: NativeHollowManifestLaboratoryReceipt.identity(falseFacts), facts: falseFacts)
    let invalid = copying(state, inspections: state.inspections, laboratory: falseReceipt)
    #expect(!falseReceipt.valid(in: invalid))
    var candidate = issued
    candidate.commander.scriptState.instances[instance.id]?.savedHollowManifest = invalid
    #expect(!NativeHollowManifestSave.validateClaims(candidate.commander))
    let files = try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent())
    #expect(throws: (any Error).self) { try GameRuntime.writeCommander(&candidate, to: commission.files.save) }
    #expect(try ScriptFinanceTestFixture.files(commission.files.save.deletingLastPathComponent()) == files)
    #expect(NativeHollowManifestSave.validateClaims(issued.commander))
  }

  @Test func realLabWriterRefusalPublishesNeitherExaminationNorLoanAndRetryRetainsOne() async throws {
    let (runtime, commission) = try await actualHollowLaboratoryRuntime()
    defer { commission.clean() }
    let reviewed = try await reviewActualHollowLaboratory(runtime)
    try #require(reviewed.contractBoard.hollowManifestQuote?.allowed == true)
    await runtime.scriptPageKey("right", expected: reviewed.scriptPagePresentation)
    let before = await runtime.snapshot()
    let quote = try #require(before.contractBoard.hollowManifestQuote)
    try #require(quote.allowed && before.contractBoard.action == .accept)
    let directory = commission.files.save.deletingLastPathComponent()
    let files = try ScriptFinanceTestFixture.files(directory)
    let held = try commission.files.blockWrites("laboratory-comparison")
    await #expect(throws: (any Error).self) {
      try await runtime.scriptCommand { candidate in
        do { try candidate.confirmHollowManifestLaboratory(quote) }
        catch { Issue.record(error); throw error }
      }
    }
    let refused = await runtime.snapshot()
    #expect(refused.commander == before.commander)
    #expect(refused.hollowManifestMission?.savedHollowManifest?.laboratory == nil)
    #expect(try ScriptFinanceTestFixture.files(held) == files)
    #expect(try Data(contentsOf: directory) == Data([1]))
    try commission.files.restoreWrites(held, files: files)
    await runtime.scriptPageKey("return", expected: refused.scriptPagePresentation)
    let retried = await runtime.snapshot()
    let instance = try #require(retried.hollowManifestMission)
    let state = try #require(instance.savedHollowManifest)
    let examination = try #require(state.laboratory?.facts.analysis)
    #expect(examination.valid(in: state) && instance.gearIssues.count == 1)
    #expect(state.inspections == before.hollowManifestMission?.savedHollowManifest?.inspections)
    #expect(retried.commander.credits == before.commander.credits)
    #expect(retried.commander.cargoTonnes == before.commander.cargoTonnes + 1)
    #expect(retried.commander.scriptState.savedClueJournal == before.commander.scriptState.savedClueJournal)
    var replay = before
    replay.commander = retried.commander
    #expect(throws: (any Error).self) { try replay.confirmHollowManifestLaboratory(quote) }
    #expect(replay.commander == retried.commander)
  }
}
