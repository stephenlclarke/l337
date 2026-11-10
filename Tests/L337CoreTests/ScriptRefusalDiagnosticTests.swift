import Foundation
import Testing

@testable import L337Core

extension GameRuntime {
  func beginScriptRefusalObservation() { scriptRefusalDiagnostic = ScriptRefusalDiagnostic() }
  func scriptRefusalObservationDetail() -> String? { scriptRefusalDiagnostic?.detail() }
}

private func refusalChecks(_ detail: String, boundary: ScriptRefusalBoundary) -> UInt16? {
  let prefix = "SCRIPT_REFUSAL "
  guard detail.hasPrefix(prefix),
    let record = detail.dropFirst(prefix.count).split(separator: ";").first(where: {
      $0.hasPrefix(boundary.rawValue + "=")
    }),
    let value = String(record).components(separatedBy: ",checks=").last?.split(separator: ",").first
  else {
    return nil
  }
  return UInt16(value)
}

@Test func scriptRefusalObservationIsBoundedFirstOnlyAndDoesNotRenderErrorData() throws {
  let diagnostics = ScriptRefusalDiagnostic()
  let game = Game(executive: false)
  let secret = "private-path-and-error-description"
  let error = NSError(
    domain: NSCocoaErrorDomain, code: 260,
    userInfo: [NSLocalizedDescriptionKey: secret, NSFilePathErrorKey: secret])
  diagnostics.record(.publication, .init(stage: .storeWrite, error: error, game: game))
  for _ in 0..<64 {
    diagnostics.record(
      .publication, .init(stage: .commandPublish, error: SaveError.invalidCommander, game: game))
  }
  diagnostics.record(
    .resolver,
    .init(stage: .freightPublish, error: NSError(domain: secret, code: 42), game: game))
  let detail = try #require(diagnostics.detail())
  #expect(detail.contains("publication=storeWrite,error=cocoa:260"))
  #expect(detail.contains("resolver=freightPublish,error=other"))
  #expect(!detail.contains(secret) && !detail.contains("commandPublish"))
  #expect(detail.utf8.count < 2048 && detail.utf8.allSatisfy { (32...126).contains($0) })
}

@Test func scriptRefusalObservationPreservesNativeAndStoreValidationRefusals() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.ensureScriptCalendar(origin: .newCommander)
  try game.commander.prepareEquipment(legacy: false)
  let initiallyValid =
    game.commander.valid && game.scriptWorldSave.valid
    && ScriptFreightVersionedSave.validateClaims(game.commander)
    && (game.commander.usesFreightNativeSaveVersion
      || !game.commander.usesProviderContractSaveVersion)
    && game.scriptWorldSave.consistent(with: game.commander)
  try #require(initiallyValid)
  var invalid = game
  invalid.commander.cargo = []
  let before = invalid.commander
  let diagnostics = ScriptRefusalDiagnostic()
  var nativeRefused = false
  do {
    _ = try GameRuntime.prepareNativeSaveState(
      invalid, diagnostics: diagnostics, diagnosticBoundary: .resolver)
  } catch {
    nativeRefused = error is SaveError
  }
  #expect(nativeRefused && invalid.commander == before)
  let nativeDetail = try #require(diagnostics.detail())
  #expect(nativeDetail.contains("resolver=nativeSaveValidation,error=save.invalidCommander"))
  #expect(!nativeDetail.contains("publication="))
  let nativeChecks = try #require(refusalChecks(nativeDetail, boundary: .resolver))
  #expect(nativeChecks & 4 == 0 && nativeDetail.contains("count=0"))
  var world = game.scriptWorldSave
  world.energy = -1
  let target = FileManager.default.temporaryDirectory
    .appendingPathComponent("refusal-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: target.appendingPathExtension("missions")) }
  defer { try? FileManager.default.removeItem(at: target) }
  var storeRefused = false
  do {
    _ = try ScriptSaveStore.write(
      commander: game.commander, world: world, to: target, diagnostics: diagnostics)
  } catch {
    storeRefused = error is SaveError
  }
  #expect(storeRefused)
  let storeDetail = try #require(diagnostics.detail())
  #expect(storeDetail.contains("publication=storeValidation,error=save.invalidCommander"))
  #expect(storeDetail.contains("resolver=nativeSaveValidation,error=save.invalidCommander"))
  let retainedNativeChecks = try #require(refusalChecks(storeDetail, boundary: .resolver))
  #expect(retainedNativeChecks == nativeChecks)
  let storeChecks = try #require(refusalChecks(storeDetail, boundary: .publication))
  #expect(storeChecks & 1 == 1 && storeChecks & 2 == 0 && storeChecks & 96 == 96)
  #expect(storeDetail.contains("predicate=4"))
  let pointerExists = FileManager.default.fileExists(atPath: target.path)
  #expect(!pointerExists)
}

@Test func scriptSceneRefusalIdentifiesUnadmittedJumpWithoutPublishing() throws {
  var game = Game(executive: false)
  game.screen = .status
  game.ensureScriptCalendar(origin: .newCommander)
  try game.commander.prepareEquipment(legacy: false)
  let baseline = game.scriptWorldSave
  let baselineValid =
    game.commander.valid && baseline.valid
    && ScriptFreightVersionedSave.validateClaims(game.commander)
    && (game.commander.usesFreightNativeSaveVersion
      || !game.commander.usesProviderContractSaveVersion)
    && baseline.consistent(with: game.commander)
  let noJourney =
    game.commander.scriptState.calendarLedger.map {
      $0.pendingJourney == nil && !$0.legacyUntrackedJourney
    } ?? false
  try #require(baselineValid && noJourney)
  var world = baseline
  world.jumpCountdown = 1
  let stillStructurallyValid = world.valid
  try #require(stillStructurallyValid)
  let diagnostics = ScriptRefusalDiagnostic()
  let target = FileManager.default.temporaryDirectory
    .appendingPathComponent("scene-refusal-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: target.appendingPathExtension("missions")) }
  defer { try? FileManager.default.removeItem(at: target) }
  var refused = false
  do {
    _ = try ScriptSaveStore.write(
      commander: game.commander, world: world, to: target, diagnostics: diagnostics)
  } catch {
    refused = error is SaveError
  }
  #expect(refused)
  let detail = try #require(diagnostics.detail())
  #expect(detail.contains("publication=sceneUnadmittedJump,error=save.invalidCommander"))
  let pointerExists = FileManager.default.fileExists(atPath: target.path)
  #expect(!pointerExists)
}

extension GameRuntime {
  /// Freeze only the completed confirmation turn; later board-open commands cannot pollute it.
  func finishSeedPublicationRefusalObservation() -> String? {
    let detail = scriptRefusalDiagnostic?.detail()
    scriptRefusalDiagnostic = nil
    return detail
  }

  /// Unit control: reject a staged commander through the real publisher, then compare rollback.
  fileprivate func verifySeedPublicationRollbackControl() throws -> String {
    let before = game
    let observation = ScriptRefusalDiagnostic()
    scriptRefusalDiagnostic = observation
    var refused = false
    do {
      try scriptCommand { candidate in
        candidate.commander.cargo = []
        candidate.commander.credits += 17
      }
    } catch {
      refused = error is SaveError
    }
    #expect(refused)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    let detail = try #require(observation.detail())
    #expect(detail.contains("publication=nativeSaveValidation,error=save.invalidCommander"))
    #expect(detail.contains("cargoCount=0"))
    #expect(refusalChecks(detail, boundary: .publication).map { $0 & 4 == 0 } == true)
    // Later outer catches must never overwrite the first native failure.
    observation.record(
      .publication, .init(stage: .commandPublish, error: SaveError.invalidCommander, game: game))
    #expect(observation.detail() == detail)
    return detail
  }
}

/// These are ordinary small unit controls, called inside the existing W03 method so the
/// four-selector qualification also executes the new recorder/rollback regression checks.
func verifySeedPublicationRefusalControls() async throws {
  try scriptRefusalObservationIsBoundedFirstOnlyAndDoesNotRenderErrorData()
  try scriptRefusalObservationPreservesNativeAndStoreValidationRefusals()
  var game = Game(executive: false)
  game.screen = .status
  game.ensureScriptCalendar(origin: .newCommander)
  try game.commander.prepareEquipment(legacy: false)
  let url = FileManager.default.temporaryDirectory
    .appendingPathComponent("seed-publication-control-" + UUID().uuidString)
  defer { try? FileManager.default.removeItem(at: url) }
  defer { try? FileManager.default.removeItem(at: url.appendingPathExtension("missions")) }
  let runtime = GameRuntime(game: game, saveURL: url)
  try #require(await runtime.snapshot().requiresScriptDurability)
  await runtime.beginScriptRefusalObservation()
  #expect(await runtime.finishSeedPublicationRefusalObservation() == nil)
  let detail = try await runtime.verifySeedPublicationRollbackControl()
  #expect(await runtime.finishSeedPublicationRefusalObservation() == detail)
  #expect(await runtime.scriptRefusalObservationDetail() == nil)
  #expect(detail.utf8.count < 12288)
  #expect(!FileManager.default.fileExists(atPath: url.path))
}
