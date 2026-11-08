import Foundation
import Testing

@testable import L337Core

/// Failure-only read-only endpoint diagnostics. No source, sample, clock or state is injected.
private func assemblyExposureFailureDetails(start: NativeAssemblyOpticalSample?, end: borrowing Game) -> String {
  let report: NativeAssemblyOpticalAcquisitionReport
  do { report = try end.assemblySurveyOpticalAcquisitionReport() }
  catch { return "End optical acquisition threw: \(String(describing: error).prefix(512))" }
  let acquired = report.sample
  func describe(_ sample: NativeAssemblyOpticalSample?) -> String {
    guard let sample else { return "nil" }
    return "frame=\(sample.frame),time=\(sample.physicalTime),actor=\(sample.actor),part=\(String(describing: sample.part)),component=\(String(describing: sample.component)),case=\(sample.caseRevision),inventory=\(sample.reference.inventoryRevision),epoch=\(sample.epoch)"
  }
  let sameProbe: Bool
  let sameObservation: Bool
  if let start, let acquired {
    sameProbe = start.sameProbe(as: acquired)
    sameObservation = start.sameObservation(as: acquired)
  } else {
    sameProbe = false
    sameObservation = false
  }
  return "refusal=\(report.refusal ?? "none"); start{\(describe(start))}; end{\(describe(acquired))}; sameProbe=\(sameProbe),sameObservation=\(sameObservation); live frame=\(end.gameplayRevision),time=\(end.commander.flightSimulation.physicalTime),paused=\(end.paused),docked=\(end.docked),screen=\(end.screen),energy=\(end.energy),target=\(String(describing: end.informationTargetBody?.id)),message=\(end.message.prefix(512))"
}

/// Real opening/loan and paid purchase, followed by controlled camera placement only.
/// The ordinary station is an UNRELATED optical calibration target, never a Darik source.
/// The explicit test budget is unearned; no flown journey or campaign playability is claimed.
private final class AssemblyOpticalInstrumentFixture {
  let opening: AssemblyOpeningFixture
  var runtime: GameRuntime { opening.runtime }

  init(purchase: Bool = true) async throws {
    opening = try await AssemblyOpeningFixture()
    var ready = false
    defer { if !ready { opening.clean() } }
    _ = try await opening.confirm(.accept)
    _ = try await opening.confirm(.collectReference)
    if purchase {
      let station = await runtime.snapshot()
      let index = try #require(Equipment.all.firstIndex { $0.name == TargetingTier.basic.equipmentName })
      let item = Equipment.all[index]
      let price = station.shopPrice(item)
      let oldCount = try #require(station.commander.equipmentPurchaseHistory?.paid.count)
      try #require(price > 0 && station.nativeMainStationDockEvidenceIsCurrent)
      try #require(station.equipmentAvailable(item))
      try await runtime.scriptCommand { game in
        // Controlled test funding, not an earned reward, credit receipt or free equipment.
        game.commander.credits += price
        game.screen = .equipment
        game.selection = index
      }
      let funded = await runtime.snapshot()
      let context = try #require(funded.equipmentPurchaseContext)
      let result = await runtime.equipmentTransaction(.purchase(context))
      try #require(result.applied)
      let bought = await runtime.snapshot()
      let fitted = try #require(bought.commander.fittedEquipment(at: .targetingCore))
      let history = try #require(bought.commander.equipmentPurchaseHistory)
      let paid = try #require(history.paid.last)
      try #require(history.paid.count == oldCount + 1 && paid.price == price)
      try #require(bought.commander.credits == funded.commander.credits - price)
      try #require(fitted.node.key == TargetingTier.basic.equipmentName)
      try #require(paid.binding.request.newItem == fitted.id && paid.node == fitted.node)
      try #require(fitted.provenance == .paid(owner: history.owner, transaction: paid.transaction))
    }
    await runtime.nativeCommand { $0.screen = .status }
    await runtime.key("0")
    try await runtime.scriptCommand { game in
      try #require(!game.docked)
      try Self.frameCalibrationStation(&game)
    }
    ready = true
  }

  /// Bounding radius chooses camera setup only. The actual full-scene ray owns all hits.
  /// Keep every body/celestial, its geometry, position, identity and authority in place.
  static func frameCalibrationStation(_ game: inout Game, clearance: Double = 500) throws {
    let station = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
    let radius = try #require(game.gameplayMesh(for: station).vertices.map(\.length).max())
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.position + Vector3(radius + clearance, 0, 0))
    pose.orientation.y = previous.orientation.apply(.init(0, 1, 0))
    pose.orientation.z = previous.orientation.apply(.init(-1, 0, 0))
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    let identities = game.bodies.map { $0.physical?.identity }
    let ids = game.bodies.map(\.id)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 0
    game.screen = .front
    game.cancelAutoTarget()
    game.weaponsTargetID = station.id
    try #require(game.bodies.map(\.id) == ids)
    try #require(game.bodies.map { $0.physical?.identity } == identities)
  }

  func clean() { opening.clean() }
}

/// Authored source only. No sample, geometry/contact result or mission authority is injected.
struct NativeAssemblySurveyOpticsUnitTests {
  @Test func actualHeldInstrumentAndPurchasedTargetingAcquireOnlyReadOnlyOpticalData() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let game = await fixture.runtime.snapshot()
    let before = game.commander
    let files = try ScriptFinanceTestFixture.files(fixture.opening.files.save.deletingLastPathComponent())
    let opticalSampleValue = try game.assemblySurveyOpticalSample()
    let sample = try #require(opticalSampleValue)
    let instance = try #require(game.assemblyOfOrbitsMission)
    let reference = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: before)
    #expect(sample.reference == reference && sample.mission == instance.id)
    #expect(sample.targeting == before.fittedEquipment(at: .targetingCore))
    #expect(sample.targeting.component == nil)  // Ordinary Basic fit legitimately has no component record.
    #expect(sample.actor.entity == 1 && sample.player.entity == 0)
    #expect(sample.actor.system == NativeAssemblyOfOrbitsDefinition.issuer)
    #expect(sample.actor.system != .init(galaxy: 6, system: 43))
    #expect(sample.frame == game.gameplayRevision && sample.epoch == game.nativeStationRuntimeEpoch)
    #expect(sample.physicalTime == before.flightSimulation.physicalTime)
    #expect(NativeAssemblySurveyOpticalRules.surfaceRange.contains(sample.surfaceRange))
    #expect(sample.aimDegrees <= 2 && sample.surfacePoint.finite)
    let collisionContactValue = try game.nearestMissionCollision(from: .init(0, 0, 0),
      direction: .init(0, 0, 1), range: 1500, radius: 0, includePlayer: false)
    let contact = try #require(collisionContactValue)
    #expect(contact.hit.target == .body(0) && sample.surfaceRange == contact.hit.distance)
    #expect(sample.surfacePoint == sample.observerPose.systemPoint(contact.hit.point))
    let repeatedOpticalValue = try game.assemblySurveyOpticalSample()
    let repeatedOpticalSample = try #require(repeatedOpticalValue)
    #expect(sample.sameObservation(as: repeatedOpticalSample))
    let value: Any = sample
    #expect(!(value is any Encodable))
    #expect(game.commander == before && instance.milestones == [0, 1])
    #expect(instance.completionReceipt == nil)
    #expect(try ScriptFinanceTestFixture.files(fixture.opening.files.save.deletingLastPathComponent()) == files)
  }

  @Test func actualAdjacentTicksProduceAnUnqualifiedExposureWithoutReplayOrPauseCredit() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    var window = NativeAssemblySurveyExposureWindow()
    let initial = await fixture.runtime.snapshot()
    let original = try #require(initial.assemblyOfOrbitsMission)
    let initialOpticalValue = try initial.assemblySurveyOpticalSample()
    let start = try #require(initialOpticalValue)
    let end = await fixture.runtime.advance(delta: 0.05)
    try window.observe(start: start, end: end)
    try #require(window.status == .tracking && window.intervals == 1)
    let firstSeconds = window.seconds
    try window.observe(start: start, end: end)
    #expect(window.seconds == firstSeconds && window.intervals == 1)
    await fixture.runtime.nativeCommand { $0.paused = true }
    let paused = await fixture.runtime.advance(delta: 0.1)
    try window.observe(start: nil, end: paused)
    #expect(window.status == .paused && window.seconds == firstSeconds && window.intervals == 1)
    await fixture.runtime.nativeCommand { $0.paused = false }
    for _ in 0..<300 {
      if window.exposure != nil { break }
      let before = await fixture.runtime.snapshot()
      let intervalOpticalValue = try before.assemblySurveyOpticalSample()
      let sample = try #require(intervalOpticalValue)
      let after = await fixture.runtime.advance(delta: 0.05)
      try window.observe(start: sample, end: after)
      let validStatus = window.status == .tracking || window.status == .exposureReady
      let failureDetails = validStatus ? "" : assemblyExposureFailureDetails(start: sample, end: after)
      try #require(window.status == .tracking || window.status == .exposureReady,
        "Window status=\(window.status),seconds=\(window.seconds),intervals=\(window.intervals); \(failureDetails)")
    }
    let exposure = try #require(window.exposure)
    #expect(window.status == .exposureReady && exposure.seconds >= 12 && exposure.seconds < 12.1)
    #expect(exposure.first.sameProbe(as: exposure.last))
    #expect(abs(exposure.last.physicalTime - exposure.first.physicalTime - exposure.seconds) < 1e-8)
    #expect(exposure.intervals == window.intervals)
    let value: Any = exposure
    #expect(!(value is any Encodable))
    let complete = await fixture.runtime.snapshot()
    #expect(complete.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(complete.assemblyOfOrbitsMission?.receipts == original.receipts)
    #expect(complete.assemblyOfOrbitsMission?.savedAssemblyOfOrbits == original.savedAssemblyOfOrbits)
    #expect(complete.assemblyOfOrbitsMission?.completionReceipt == nil)
    #expect(complete.commander.scriptState.savedClueJournal == initial.commander.scriptState.savedClueJournal)
    // A view interruption clears runtime exposure; there is no completed mission reading to erase.
    await fixture.runtime.nativeCommand { $0.screen = .status }
    let interrupted = await fixture.runtime.snapshot()
    try window.observe(start: nil, end: interrupted)
    #expect(window.status == .interrupted && window.seconds == 0 && window.exposure == nil)
  }

  @Test func missingHardwareOrLoanAndInterruptedNativeFramesCannotSupplySurveyProgress() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let game = await fixture.runtime.snapshot()
    let hardwareSampleValue = try game.assemblySurveyOpticalSample()
    let sample = try #require(hardwareSampleValue)
    var trial = game
    trial.isMissionTrial = true
    #expect(try trial.assemblySurveyOpticalSample() == nil)
    var titleTrial = game
    titleTrial.trialTitle = "Negative isolated calibration"
    #expect(try titleTrial.assemblySurveyOpticalSample() == nil)
    var unselected = game
    unselected.weaponsTargetID = nil
    #expect(try unselected.assemblySurveyOpticalSample() == nil)
    var wrongView = game
    wrongView.screen = .rear
    #expect(try wrongView.assemblySurveyOpticalSample() == nil)
    var tooFar = game
    try AssemblyOpticalInstrumentFixture.frameCalibrationStation(&tooFar, clearance: 2000)
    #expect(try tooFar.assemblySurveyOpticalSample() == nil)
    var lookingAway = game
    var pose = lookingAway.commander.flightSimulation.pose
    pose.orientation.x = pose.orientation.x * -1
    pose.orientation.z = pose.orientation.z * -1
    NativeStationTestFixture.reframe(&lookingAway, to: pose)
    #expect(try lookingAway.assemblySurveyOpticalSample() == nil)
    // Corrupt only a negative value copy; this is not a real return or replacement receipt.
    var missingLoan = game
    if let inventory = missingLoan.commander.savedEquipmentInventory {
      missingLoan.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.id != sample.reference.original })
    }
    #expect(try missingLoan.assemblySurveyOpticalSample() == nil)
    var window = NativeAssemblySurveyExposureWindow()
    let firstEnd = await fixture.runtime.advance(delta: 0.05)
    try window.observe(start: sample, end: firstEnd)
    try #require(window.intervals == 1)
    _ = await fixture.runtime.advance(delta: 0.05)  // Deliberately missed observer interval.
    let gapStart = await fixture.runtime.snapshot()
    let nextOpticalValue = try gapStart.assemblySurveyOpticalSample()
    let next = try #require(nextOpticalValue)
    let nextEnd = await fixture.runtime.advance(delta: 0.05)
    try window.observe(start: next, end: nextEnd)
    #expect(window.intervals == 1 && window.seconds > 0 && window.seconds < 0.1)
    try window.observe(start: sample, end: firstEnd)  // Older genuine interval cannot replace current time.
    #expect(window.status == .interrupted && window.seconds == 0)
    let noHardware = try await AssemblyOpticalInstrumentFixture(purchase: false)
    defer { noHardware.clean() }
    let unfitted = await noHardware.runtime.snapshot()
    #expect(unfitted.commander.fittedEquipment(at: .targetingCore) == nil)
    #expect(try unfitted.assemblySurveyOpticalSample() == nil)
    #expect(try Game(executive: false).assemblySurveyOpticalSample() == nil)
    #expect(game.assemblyOfOrbitsMission?.milestones == [0, 1])
  }

  @Test func currentColdLoadInvalidatesPartialOpticsAndRetainsTheRealOriginalLoan() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let game = await fixture.runtime.snapshot()
    let loadSampleValue = try game.assemblySurveyOpticalSample()
    let sample = try #require(loadSampleValue)
    var window = NativeAssemblySurveyExposureWindow()
    let end = await fixture.runtime.advance(delta: 0.05)
    try window.observe(start: sample, end: end)
    try #require(window.seconds > 0 && window.exposure == nil)
    try await fixture.runtime.save(to: fixture.opening.files.save)
    let saved = await fixture.runtime.snapshot()
    try await fixture.runtime.load(from: fixture.opening.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(loaded.nativeStationRuntimeEpoch != sample.epoch)
    try window.observe(start: sample, end: loaded)
    #expect(window.seconds == 0 && window.intervals == 0 && window.exposure == nil)
    let instance = try #require(loaded.assemblyOfOrbitsMission)
    let reference = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: loaded.commander)
    #expect(reference.original == sample.reference.original && reference.issueCommand == sample.reference.issueCommand)
    #expect(loaded.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(loaded.commander.equipmentPurchaseHistory == saved.commander.equipmentPurchaseHistory)
    #expect(instance.milestones == [0, 1] && instance.completionReceipt == nil)
    #expect(instance.savedAssemblyOfOrbits == saved.assemblyOfOrbitsMission?.savedAssemblyOfOrbits)
    #expect(NativeAssemblyOfOrbitsSave.validateClaims(loaded.commander))
    var fresh = NativeAssemblySurveyExposureWindow()
    #expect(fresh.seconds == 0 && fresh.exposure == nil && fresh.status == .needsTarget)
    fresh.reset()
    #expect(fresh.intervals == 0)
  }
}

/// Explicit player controls for the unqualified calibration instrument, not a survey command.
struct NativeAssemblySurveyInstrumentControlsUnitTests {
  @Test func explicitStartMotionBracketsAndCancelNeverPublishMissionEvidence() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    var instrument = NativeAssemblySurveyInstrumentControls()
    let game = await fixture.runtime.snapshot()
    let original = try #require(game.assemblyOfOrbitsMission)
    #expect(instrument.readout.mode == .off && instrument.readout.seconds == 0)
    try instrument.finishMotion(in: game)  // No matching begin: no measurement or credit.
    #expect(instrument.readout.mode == .off)
    let started = try instrument.startCalibration(in: game)
    try #require(started)
    #expect(instrument.readout.mode == .seeking && instrument.readout.seconds == 0)
    try instrument.beginMotion(in: game)
    let end = await fixture.runtime.advance(delta: 0.05)
    try instrument.finishMotion(in: end)
    let measured = instrument.readout
    #expect(measured.mode == .tracking && measured.seconds > 0 && measured.fraction > 0)
    #expect(measured.requiredSeconds == 12 && measured.title == "SURFACE CALIBRATION")
    #expect(measured.explanation.contains("No register reading"))
    try instrument.finishMotion(in: end)  // A repeated finish cannot consume the interval twice.
    #expect(instrument.readout == measured)
    await fixture.runtime.nativeCommand { $0.paused = true }
    let paused = await fixture.runtime.snapshot()
    try instrument.beginMotion(in: paused)
    let stillPaused = await fixture.runtime.advance(delta: 0.1)
    try instrument.finishMotion(in: stillPaused)
    #expect(instrument.readout.mode == .paused && instrument.readout.seconds == measured.seconds)
    instrument.cancel()
    #expect(instrument.readout.mode == .off && instrument.readout.seconds == 0)
    try instrument.finishMotion(in: end)  // Cancellation also discards a retained pre-motion bracket.
    #expect(instrument.readout.mode == .off)
    let after = await fixture.runtime.snapshot()
    #expect(after.assemblyOfOrbitsMission?.milestones == original.milestones)
    #expect(after.assemblyOfOrbitsMission?.receipts == original.receipts)
    #expect(after.assemblyOfOrbitsMission?.completionReceipt == nil)
    #expect(after.commander.scriptState.savedClueJournal == game.commander.scriptState.savedClueJournal)
    let value: Any = instrument
    #expect(!(value is any Encodable))
  }

  @Test func refusedRearmAndCurrentLoadDiscardUnfinishedControlState() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    var instrument = NativeAssemblySurveyInstrumentControls()
    let initial = await fixture.runtime.snapshot()
    let started = try instrument.startCalibration(in: initial)
    try #require(started)
    try instrument.beginMotion(in: initial)
    let end = await fixture.runtime.advance(delta: 0.05)
    try instrument.finishMotion(in: end)
    try #require(instrument.readout.seconds > 0)
    try await fixture.runtime.save(to: fixture.opening.files.save)
    try await fixture.runtime.load(from: fixture.opening.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    try instrument.finishMotion(in: loaded)  // No begin, but epoch invalidation still takes effect.
    #expect(instrument.readout.mode == .off && instrument.readout.seconds == 0)
    let original = try #require(loaded.assemblyOfOrbitsMission)
    #expect(original.milestones == [0, 1])
    let custody = try NativeAssemblyOfOrbitsCustody.resolve(instance: original, commander: loaded.commander)
    #expect(custody.original == initial.assemblyOfOrbitsMission?.savedAssemblyOfOrbits?.collection?.facts.original)
    var blocked = initial
    blocked.screen = .status
    let blockedStart = try instrument.startCalibration(in: blocked)
    #expect(!blockedStart)
    #expect(instrument.readout.mode == .off && instrument.readout.seconds == 0)
    let noHardware = try await AssemblyOpticalInstrumentFixture(purchase: false)
    defer { noHardware.clean() }
    let unfitted = await noHardware.runtime.snapshot()
    let unfittedStart = try instrument.startCalibration(in: unfitted)
    #expect(!unfittedStart)
    #expect(instrument.readout.mode == .off)
  }
}

/// Actual shared-hook acceptance requirements. All methods remain UNRUN until G1 composes
/// the reserved runtime/menu/HUD hunks; calibration never authenticates a Darik register.
struct NativeAssemblyCalibrationIntegrationUnitTests {
  @Test func typedMenuStartAndActualNativeFramesProduceOnlyCalibrationDisplay() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let initial = await fixture.runtime.snapshot()
    let original = try #require(initial.assemblyOfOrbitsMission)
    let files = try ScriptFinanceTestFixture.files(fixture.opening.files.save.deletingLastPathComponent())
    #expect(initial.nativeAssemblyCalibrationDisplay == nil)
    try #require(MissionUIAction.assemblyCalibrationStart.isEnabled(in: initial))
    let intent = MissionUIIntent(action: .assemblyCalibrationStart, game: initial,
      presentation: initial.scriptPagePresentation)
    await fixture.runtime.missionUICommand(intent)
    let armed = await fixture.runtime.snapshot()
    #expect(armed.nativeAssemblyCalibrationDisplay?.mode == .seeking)
    #expect(armed.nativeAssemblyCalibrationDisplay?.seconds == 0)
    #expect(MissionUIAction.assemblyCalibrationCancel.isEnabled(in: armed))
    for _ in 0..<5 {
      let repeated = await fixture.runtime.snapshot()
      #expect(repeated.nativeAssemblyCalibrationDisplay == armed.nativeAssemblyCalibrationDisplay)
      #expect(repeated.commander == armed.commander)
    }
    #expect(try ScriptFinanceTestFixture.files(fixture.opening.files.save.deletingLastPathComponent()) == files)
    var measured = armed
    var firstInterruptedDetails: String?
    for _ in 0..<300 {
      if measured.nativeAssemblyCalibrationDisplay?.mode == .exposureReady { break }
      let previous = measured
      measured = await fixture.runtime.advance(delta: 0.05)
      try #require(measured.nativeAssemblyCalibrationDisplay != nil)
      if firstInterruptedDetails == nil, let current = measured.nativeAssemblyCalibrationDisplay,
        current.mode == .interrupted || current.mode == .paused
          || current.seconds < (previous.nativeAssemblyCalibrationDisplay?.seconds ?? 0)
      {
        let start = try? previous.assemblySurveyOpticalSample()
        firstInterruptedDetails = "mode=\(current.mode),seconds=\(current.seconds); "
          + assemblyExposureFailureDetails(start: start, end: measured)
      }
    }
    let readout = try #require(measured.nativeAssemblyCalibrationDisplay)
    #expect(readout.mode == .exposureReady && readout.seconds >= 12 && readout.seconds < 12.1,
      "Final mode=\(readout.mode),seconds=\(readout.seconds); first interruption=\(firstInterruptedDetails ?? "none observed")")
    #expect(measured.assemblyOfOrbitsMission?.milestones == original.milestones)
    #expect(measured.assemblyOfOrbitsMission?.receipts == original.receipts)
    #expect(measured.assemblyOfOrbitsMission?.savedAssemblyOfOrbits == original.savedAssemblyOfOrbits)
    #expect(measured.assemblyOfOrbitsMission?.completionReceipt == nil)
    #expect(measured.commander.scriptState.savedClueJournal == initial.commander.scriptState.savedClueJournal)
    let layout = CockpitLayout(game: measured, width: 640, height: 720)
    #expect(layout.extraLines.contains("NO REGISTER READING"))
    #expect(layout.extraLines.contains { $0.contains("UNVERIFIED") })
    let stop = MissionUIIntent(action: .assemblyCalibrationCancel, game: measured,
      presentation: measured.scriptPagePresentation)
    await fixture.runtime.missionUICommand(stop)
    let stopped = await fixture.runtime.snapshot()
    #expect(stopped.nativeAssemblyCalibrationDisplay == nil)
    #expect(!MissionUIAction.assemblyCalibrationCancel.isEnabled(in: stopped))
  }

  @Test func capturedSelectionCannotDriftAndStopRemainsAvailableAfterTargetLoss() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let initial = await fixture.runtime.snapshot()
    let intent = MissionUIIntent(action: .assemblyCalibrationStart, game: initial,
      presentation: initial.scriptPagePresentation)
    try #require(intent.isCurrent(in: initial))
    // Negative value-copy corruption only; no real return, refit, trial or source receipt.
    var noLoan = initial
    let instance = try #require(initial.assemblyOfOrbitsMission)
    let reference = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: initial.commander)
    if let inventory = noLoan.commander.savedEquipmentInventory {
      noLoan.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.id != reference.original })
    }
    #expect(!intent.isCurrent(in: noLoan))
    var noFit = initial
    if let inventory = noFit.commander.savedEquipmentInventory {
      noFit.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.location?.slot != .targetingCore })
    }
    #expect(!intent.isCurrent(in: noFit))
    var otherEpoch = initial
    otherEpoch.nativeStationRuntimeEpoch = UUID()
    #expect(!intent.isCurrent(in: otherEpoch))
    var trial = initial
    trial.isMissionTrial = true
    #expect(!intent.isCurrent(in: trial))
    try await fixture.runtime.scriptCommand { $0.weaponsTargetID = nil }
    let unselected = await fixture.runtime.snapshot()
    #expect(!intent.isCurrent(in: unselected))
    await fixture.runtime.missionUICommand(intent)
    #expect(await fixture.runtime.snapshot().nativeAssemblyCalibrationDisplay == nil)
    try await fixture.runtime.scriptCommand { $0.weaponsTargetID = 0 }
    let selected = await fixture.runtime.snapshot()
    let current = MissionUIIntent(action: .assemblyCalibrationStart, game: selected,
      presentation: selected.scriptPagePresentation)
    await fixture.runtime.missionUICommand(current)
    try await fixture.runtime.scriptCommand { $0.weaponsTargetID = nil }
    let lost = await fixture.runtime.snapshot()
    try #require(MissionUIAction.assemblyCalibrationCancel.isEnabled(in: lost))
    let stop = MissionUIIntent(action: .assemblyCalibrationCancel, game: lost,
      presentation: lost.scriptPagePresentation)
    var missingFit = lost
    if let inventory = missingFit.commander.savedEquipmentInventory {
      missingFit.commander.savedEquipmentInventory = try OwnedEquipmentInventory(
        owner: inventory.owner, activeHull: inventory.activeHull, revision: inventory.revision,
        items: inventory.items.filter { $0.location?.slot != .targetingCore })
    }
    #expect(MissionUIAction.assemblyCalibrationCancel.isEnabled(in: missingFit))
    #expect(stop.isCurrent(in: missingFit))
    await fixture.runtime.missionUICommand(stop)
    #expect(await fixture.runtime.snapshot().nativeAssemblyCalibrationDisplay == nil)
  }

  @Test func successfulCurrentLoadClearsProjectionAndFailedLoadPreservesLiveExposure() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let initial = await fixture.runtime.snapshot()
    await fixture.runtime.missionUICommand(.init(action: .assemblyCalibrationStart, game: initial,
      presentation: initial.scriptPagePresentation))
    let measured = await fixture.runtime.advance(delta: 0.05)
    let partial = try #require(measured.nativeAssemblyCalibrationDisplay)
    try #require(partial.mode == .tracking && partial.seconds > 0)
    let missing = fixture.opening.files.save.deletingLastPathComponent().appendingPathComponent("missing-current.json")
    await #expect(throws: (any Error).self) { try await fixture.runtime.load(from: missing, persistMigrations: false) }
    let retained = await fixture.runtime.snapshot()
    #expect(retained.nativeAssemblyCalibrationDisplay == partial)
    #expect(retained.nativeStationRuntimeEpoch == measured.nativeStationRuntimeEpoch)
    await fixture.runtime.key("pause")
    let paused = await fixture.runtime.advance(delta: 0.1)
    #expect(paused.nativeAssemblyCalibrationDisplay?.mode == .paused)
    #expect(paused.nativeAssemblyCalibrationDisplay?.seconds == partial.seconds)
    await fixture.runtime.key("pause")
    try await fixture.runtime.save(to: fixture.opening.files.save)
    let saved = await fixture.runtime.snapshot()
    try await fixture.runtime.load(from: fixture.opening.files.save, persistMigrations: false)
    let loaded = await fixture.runtime.snapshot()
    #expect(loaded.nativeAssemblyCalibrationDisplay == nil)
    #expect(loaded.nativeStationRuntimeEpoch != saved.nativeStationRuntimeEpoch)
    #expect(loaded.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(loaded.assemblyOfOrbitsMission?.savedAssemblyOfOrbits == saved.assemblyOfOrbitsMission?.savedAssemblyOfOrbits)
    #expect(loaded.assemblyOfOrbitsMission?.milestones == [0, 1])
    #expect(loaded.assemblyOfOrbitsMission?.completionReceipt == nil)
  }
}

/// Actual loan, paid targeting and unrelated real station calibration only. These input
/// regressions do not authenticate an original Darik register or grant mission progress.
struct NativeAssemblyCalibrationInputLifetimeUnitTests {
  @Test func queuedStartAndStopCannotResetOrCancelALaterCalibrationRun() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let runtime = fixture.runtime
    let initial = await runtime.snapshot()
    let start = MissionUIIntent(action: .assemblyCalibrationStart, game: initial,
      presentation: initial.scriptPagePresentation)
    try #require(start.isCurrent(in: initial))
    await runtime.missionUICommand(start)
    let armed = await runtime.snapshot()
    try #require(armed.nativeAssemblyCalibrationDisplay?.mode == .seeking)
    #expect(armed.inventoryContextEpoch != initial.inventoryContextEpoch)
    #expect(!start.isCurrent(in: armed))

    let oldStop = MissionUIIntent(action: .assemblyCalibrationCancel, game: armed,
      presentation: armed.scriptPagePresentation)
    let restart = MissionUIIntent(action: .assemblyCalibrationStart, game: armed,
      presentation: armed.scriptPagePresentation)
    try #require(oldStop.isCurrent(in: armed) && restart.isCurrent(in: armed))
    await runtime.missionUICommand(restart)
    let restarted = await runtime.snapshot()
    try #require(restarted.nativeAssemblyCalibrationDisplay?.mode == .seeking)
    #expect(restarted.inventoryContextEpoch != armed.inventoryContextEpoch)
    #expect(!oldStop.isCurrent(in: restarted) && !restart.isCurrent(in: restarted))
    let exposing = await runtime.advance(delta: 0.05)
    let exposure = try #require(exposing.nativeAssemblyCalibrationDisplay)
    try #require(exposure.mode == .tracking && exposure.seconds > 0)
    await runtime.missionUICommand(oldStop)
    await runtime.missionUICommand(start)
    await runtime.missionUICommand(restart)
    let protected = await runtime.snapshot()
    #expect(protected.nativeAssemblyCalibrationDisplay == exposure)
    #expect(protected.inventoryContextEpoch == exposing.inventoryContextEpoch)

    let stop = MissionUIIntent(action: .assemblyCalibrationCancel, game: protected,
      presentation: protected.scriptPagePresentation)
    try #require(stop.isCurrent(in: protected))
    await runtime.missionUICommand(stop)
    let stopped = await runtime.snapshot()
    #expect(stopped.nativeAssemblyCalibrationDisplay == nil)
    #expect(stopped.inventoryContextEpoch != protected.inventoryContextEpoch)
    // Returning to the same off state must not revive the original pre-arm command.
    #expect(!start.isCurrent(in: stopped) && !restart.isCurrent(in: stopped))
    await runtime.missionUICommand(start)
    await runtime.missionUICommand(stop)
    #expect(await runtime.snapshot().nativeAssemblyCalibrationDisplay == nil)

    let current = await runtime.snapshot()
    let fresh = MissionUIIntent(action: .assemblyCalibrationStart, game: current,
      presentation: current.scriptPagePresentation)
    try #require(fresh.isCurrent(in: current))
    await runtime.missionUICommand(fresh)
    let rearmed = await runtime.snapshot()
    #expect(rearmed.nativeAssemblyCalibrationDisplay?.mode == .seeking)
    #expect(rearmed.commander.equipmentInventory == initial.commander.equipmentInventory)
    #expect(rearmed.assemblyOfOrbitsMission == initial.assemblyOfOrbitsMission)
    #expect(rearmed.commander.credits == initial.commander.credits)
    #expect(rearmed.commander.scriptState.savedClueJournal == initial.commander.scriptState.savedClueJournal)
  }

  @Test func opticalRefusalConsumesTheStartInputAndCurrentLoadRequiresFreshCommands() async throws {
    let fixture = try await AssemblyOpticalInstrumentFixture()
    defer { fixture.clean() }
    let runtime = fixture.runtime
    // Controlled camera setup only. All existing physical bodies and source data remain.
    try await runtime.scriptCommand { game in
      try AssemblyOpticalInstrumentFixture.frameCalibrationStation(&game, clearance: 2000)
    }
    let outside = await runtime.snapshot()
    let optical = try outside.assemblySurveyOpticalSample()
    try #require(optical == nil)
    let start = MissionUIIntent(action: .assemblyCalibrationStart, game: outside,
      presentation: outside.scriptPagePresentation)
    // Menu selection does not fabricate the actual range/aim query done on dispatch.
    try #require(start.isCurrent(in: outside))
    let files = try ScriptFinanceTestFixture.files(fixture.opening.files.save.deletingLastPathComponent())
    await runtime.missionUICommand(start)
    let refused = await runtime.snapshot()
    #expect(refused.nativeAssemblyCalibrationDisplay == nil)
    #expect(refused.inventoryContextEpoch != outside.inventoryContextEpoch)
    #expect(!start.isCurrent(in: refused))
    await runtime.missionUICommand(start)
    let replayed = await runtime.snapshot()
    #expect(replayed.inventoryContextEpoch == refused.inventoryContextEpoch)
    #expect(replayed.commander == refused.commander)
    #expect(try ScriptFinanceTestFixture.files(fixture.opening.files.save.deletingLastPathComponent()) == files)

    try await runtime.scriptCommand { game in
      try AssemblyOpticalInstrumentFixture.frameCalibrationStation(&game)
    }
    let attainable = await runtime.snapshot()
    #expect(!start.isCurrent(in: attainable))
    let fresh = MissionUIIntent(action: .assemblyCalibrationStart, game: attainable,
      presentation: attainable.scriptPagePresentation)
    try #require(fresh.isCurrent(in: attainable))
    await runtime.missionUICommand(fresh)
    let armed = await runtime.snapshot()
    try #require(armed.nativeAssemblyCalibrationDisplay?.mode == .seeking)
    let stop = MissionUIIntent(action: .assemblyCalibrationCancel, game: armed,
      presentation: armed.scriptPagePresentation)
    try #require(stop.isCurrent(in: armed))
    try await runtime.save(to: fixture.opening.files.save)
    let saved = await runtime.snapshot()
    try await runtime.load(from: fixture.opening.files.save, persistMigrations: false)
    let loaded = await runtime.snapshot()
    #expect(loaded.nativeAssemblyCalibrationDisplay == nil)
    #expect(loaded.nativeStationRuntimeEpoch != saved.nativeStationRuntimeEpoch)
    #expect(!fresh.isCurrent(in: loaded) && !stop.isCurrent(in: loaded))
    await runtime.missionUICommand(fresh)
    await runtime.missionUICommand(stop)
    let after = await runtime.snapshot()
    #expect(after.nativeAssemblyCalibrationDisplay == nil)
    #expect(after.assemblyOfOrbitsMission == saved.assemblyOfOrbitsMission)
    #expect(after.commander.equipmentInventory == saved.commander.equipmentInventory)
    #expect(after.commander.credits == saved.commander.credits)
    #expect(after.commander.scriptState.savedClueJournal == saved.commander.scriptState.savedClueJournal)
    let instance = try #require(after.assemblyOfOrbitsMission)
    let held = try NativeAssemblyOfOrbitsCustody.resolve(instance: instance, commander: after.commander)
    let original = try NativeAssemblyOfOrbitsCustody.resolve(
      instance: try #require(saved.assemblyOfOrbitsMission), commander: saved.commander)
    #expect(held.original == original.original && held.issueCommand == original.issueCommand)
    #expect(instance.milestones == [0, 1] && instance.completionReceipt == nil)
  }
}
