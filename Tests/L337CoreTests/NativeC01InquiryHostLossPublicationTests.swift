import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryHostLossPublicationTests {
  @Test func absentRootDoesNotPublishOrChangeTheOrdinaryRuntime() async throws {
    let files = try ScriptFreightFixture()
    defer { files.clean() }
    let runtime = GameRuntime(game: Game(executive: false), saveURL: files.save)
    let before = await runtime.snapshot()
    try #require(before.commander.scriptState.savedC01Inquiry == nil)
    let disk = try ScriptFinanceTestFixture.files(files.root)
    for _ in 0..<3 { await runtime.commitC01InquiryOperatorHostLoss() }
    let after = await runtime.snapshot()
    #expect(after.commander == before.commander && after.bodies == before.bodies)
    #expect(after.celestials == before.celestials)
    #expect(after.nextBodyID == before.nextBodyID && after.gameplayRevision == before.gameplayRevision)
    #expect(after.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
    #expect(after.energy == before.energy && after.frontShield == before.frontShield)
    #expect(after.rearShield == before.rearShield)
    #expect(after.commander.scriptState.savedC01Inquiry == nil)
    #expect(try ScriptFinanceTestFixture.files(files.root) == disk)
  }
}

/// NONREGISTERED genuine-fixture oracle. G1 must supply its actual approved
/// inquiry runtime AFTER real original-host destruction and before this new
/// post-tick publication. No public DTO, approval, host loss, root, birth or
/// writer acknowledgment is fabricated here. No skipped/expected-failure test.
func c01InquiryActualHostLossWriterFailureRetryOracle(
  runtime: GameRuntime, files: ScriptFreightFixture
) async throws {
  // Actual private loaders must succeed; candidate shape and hash cannot issue
  // either approval. This oracle has no caller-provided approval switch.
  _ = try NativeC01CharterArchiveApproval.load()
  _ = try NativeCharterArchiveRegistryApproval.load()
  try #require(await runtime.scriptSaveURL == files.save)
  try #require(FileManager.default.fileExists(atPath: files.save.path))
  let before = await runtime.snapshot()
  let original = try #require(before.commander.scriptState.savedC01Inquiry)
  try #require(original.shapeValid && original.owner == before.commander.equipmentOwnerID)
  try #require(original.institutionalSource.availability == .available)
  guard case .destroyed(let host) = before.nativeOriginalMainStationDestination else {
    Issue.record("G1 must supply the actual destroyed original host")
    return
  }
  try #require(host == original.institutionalSource.host)
  // Existing real producer, not construction of its fileprivate plan.
  let realPlan = try #require(try before.prepareC01InquiryOperatorHostLoss())
  try #require(realPlan.before == original.institutionalSource && realPlan.after.shapeValid)
  let parent = files.save.deletingLastPathComponent()
  let disk = try ScriptFinanceTestFixture.files(parent)
  let preserved = try files.blockWrites("c01-inquiry-host-loss", destination: files.save)
  var restored = false
  defer {
    if !restored {
      try? files.restoreWrites(preserved, files: disk, destination: files.save)
    }
  }
  await runtime.commitC01InquiryOperatorHostLoss()
  let refused = await runtime.snapshot()
  #expect(refused.message == "INQUIRY HOST LOSS NOT SAVED - PHYSICAL LOSS RETAINED FOR RETRY")
  #expect(refused.commander == before.commander)
  #expect(refused.bodies == before.bodies && refused.celestials == before.celestials)
  #expect(refused.energy == before.energy && refused.frontShield == before.frontShield)
  #expect(refused.rearShield == before.rearShield && refused.nextBodyID == before.nextBodyID)
  #expect(refused.gameplayRevision == before.gameplayRevision)
  #expect(refused.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
  #expect(refused.commander.scriptState.savedC01Inquiry == original)
  guard case .destroyed(let refusedHost) = refused.nativeOriginalMainStationDestination else {
    Issue.record("Failed writer rewound the real host loss")
    return
  }
  #expect(refusedHost == host)
  #expect(try ScriptFinanceTestFixture.files(preserved) == disk)

  // Real current-runtime UI mutation distinguishes a latest-game retry from
  // reinstalling the first attempt's Game copy. It grants no physical advance.
  let retryWidth = before.viewportWidth == 1777 ? 1778.0 : 1777.0
  await runtime.setViewport(width: retryWidth, height: 997)
  let latest = await runtime.snapshot()
  try #require(latest.viewportWidth != before.viewportWidth)
  try files.restoreWrites(preserved, files: disk, destination: files.save)
  restored = true
  await runtime.commitC01InquiryOperatorHostLoss()
  let published = await runtime.snapshot()
  let committed = try #require(published.commander.scriptState.savedC01Inquiry)
  #expect(committed.shapeValid && committed.owner == original.owner)
  #expect(committed.caseRecord == original.caseRecord && committed.priorCases == original.priorCases)
  #expect(committed.nextCaseOrdinal == original.nextCaseOrdinal)
  #expect(committed.fixtureLifecycle == original.fixtureLifecycle)
  let source = committed.institutionalSource
  let prior = original.institutionalSource
  #expect(source.availability == .unavailable)
  let operation = try #require(source.unavailabilityOperation)
  #expect(source.revision == (try NativeC01InquiryOperatorSubjectData.nextRevision(prior.revision)))
  #expect(source.owner == prior.owner && source.host == prior.host && source.pins == prior.pins)
  #expect(source.birthOperation == prior.birthOperation && source.duties == prior.duties)
  #expect(source.activationArrival == prior.activationArrival)
  #expect(source.activationPhysicalTime == prior.activationPhysicalTime)
  #expect(source.subjects == (try prior.subjects.map {
    try NativeC01InquiryOperatorSubjectData.recordingHostLoss($0, operation: operation)
  }))
  #expect(published.bodies == latest.bodies && published.celestials == latest.celestials)
  #expect(published.energy == latest.energy && published.frontShield == latest.frontShield)
  #expect(published.rearShield == latest.rearShield)
  #expect(published.viewportWidth == retryWidth && published.viewportHeight == 997)
  guard case .destroyed(let publishedHost) = published.nativeOriginalMainStationDestination else {
    Issue.record("Successful source publication rewound the real host loss")
    return
  }
  #expect(publishedHost == host)
  let (cold, _) = try ScriptSaveStore.read(Data(contentsOf: files.save), from: files.save)
  #expect(cold.scriptState.savedC01Inquiry == committed)

  // An already unavailable source produces no second plan, revision or write.
  let committedDisk = try ScriptFinanceTestFixture.files(parent)
  await runtime.commitC01InquiryOperatorHostLoss()
  let repeated = await runtime.snapshot()
  #expect(repeated.commander == published.commander && repeated.bodies == published.bodies)
  #expect(repeated.commander.scriptState.savedC01Inquiry == committed)
  #expect(repeated.nativeStationRuntimeEpoch == published.nativeStationRuntimeEpoch)
  #expect(repeated.gameplayRevision == published.gameplayRevision)
  #expect(try ScriptFinanceTestFixture.files(parent) == committedDisk)
}
