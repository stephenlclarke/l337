import Foundation
import Testing

@testable import L337Core

@Test func salvageAdmissionObservationRetainsOnlyFirstGenericAndStructuralFailures() {
  let diagnostic = NativeSalvageAdmissionDiagnostic()
  let wreck = WreckIdentity(system: .init(galaxy: 0, system: 69), site: 88, lineage: 2)
  let generic = SalvageLotIdentity(section: .init(wreck: wreck, section: 8), lot: 0)
  let structural = SalvageLotIdentity(section: .init(wreck: wreck, section: 0), lot: 0)
  diagnostic.record(lot: generic, structural: false, stage: "receipt", reason: "unsafePosition")
  diagnostic.record(lot: structural, structural: true, stage: "parent.placement",
    reason: String(repeating: "x", count: 1000))
  for _ in 0..<100 {
    diagnostic.record(lot: structural, structural: true, stage: "scene", reason: "later")
  }
  let records = diagnostic.observations
  #expect(records.count == 2)
  #expect(records.first?.lot == generic && records.first?.stage == "receipt")
  #expect(records.last?.lot == structural && records.last?.stage == "parent.placement")
  #expect(records.last?.reason.count == 160)
  #expect(diagnostic.detail().utf8.count < 700)
}


@Test func salvageAdmissionObservationPreservesCommanderSceneAndAllocationState() {
  var game = Game(executive: false)
  let commander = game.commander
  let bodies = game.bodies
  let revision = game.gameplayRevision
  let lot = SalvageLotIdentity(
    section: .init(wreck: .init(system: .init(galaxy: 0, system: 69), site: 88, lineage: 2),
      section: 0), lot: 0)
  game.recordNativeSalvageAdmissionRefusal(lot: lot, stage: "receipt", reason: "unsafePosition")
  #expect(game.nativeSalvageAdmissionDiagnostic == nil)
  game.nativeSalvageAdmissionDiagnostic = .init()
  game.recordNativeSalvageAdmissionRefusal(lot: lot, stage: "receipt", reason: "unsafePosition")
  #expect(game.nativeSalvageAdmissionDiagnostic?.observations.count == 1)
  #expect(game.commander == commander && game.bodies == bodies)
  #expect(game.gameplayRevision == revision)
}
