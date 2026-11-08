import Foundation
import Testing

@testable import L337Core

struct NativeSalvageAuthorityTests {
  @Test func coldWorkRefusalReportsStorageCustodyWithoutCommittingTheRequest() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    game.launch()
    try #require(!game.docked && game.commander.valid && game.commander.alienStorageStateValid)
    let allocated = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocated)
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH029"))
    let section = try #require(profile.sections.first)
    let wreck = WreckIdentity(system: game.systemIdentity, site: 710,
      lineage: game.commander.flightSimulation.visit)
    // This is an untrusted unit request, submitted to the custody guard before source admission.
    var body = SpaceBody(id: 710, hull: .cobra, position: .init(0, 0, 200))
    body.physical = .init(
      identity: actor, population: .civilian, catalogueShipID: "SH029",
      salvage: .init(
        category: .wreck, ownership: .abandoned, claimant: nil, wreck: wreck,
        section: nil, lot: nil, bounds: profile.bounds, workSurfaces: []))
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
      technology: game.currentSystem.technology, ownership: .abandoned)
    // An invalid caller-supplied storage reference must fail before wreck/work admission.
    game.commander.savedAlienStorageReference = .init(
      owner: UUID(), revision: 0, worldRevision: 0, rootHash: String(repeating: "0", count: 64))
    try #require(!game.commander.alienStorageStateValid)
    let before = game
    let accepted = game.beginNativeSalvageWork(body: body, section: section, source: source)
    #expect(!accepted && game.nativeSalvageWork == nil)
    #expect(game.message == "SALVAGE REFUSED - STORAGE CUSTODY")
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.energy == before.energy && game.laserHeat == before.laserHeat)
    #expect(game.dischargeAudio.events == before.dischargeAudio.events)
  }

  @Test func suspendedWorkInputRequiresReleaseBeforeARepeatedHoldCanResume() {
    var game = Game(executive: false)
    game.observeFlightFire(held: true)
    game.interruptFlightTool()
    #expect(game.workFireSuspended)
    let held = game.admitFlightFire(held: true)
    #expect(!held && game.workFireSuspended)
    game.observeFlightFire(held: false)
    #expect(!game.workFireSuspended)
    let pressedAgain = game.admitFlightFire(held: true)
    #expect(pressedAgain && !game.workFireSuspended)
  }

  @Test(arguments: ["owner", "hull", "epoch", "actor", "section", "source", "cycle"])
  func staleHotAuthorityRefusesWorkAndEveryColdFlushWithoutChangingCustody(change: String) throws {
    let diagnostic = ASANAllocatorDiagnostic.begin(.staleSalvage, argument: change)
    defer { diagnostic?.checkpoint(.bodyExit) }
    var (game, _) = try NativePagedSalvageFixture.empGame()
    diagnostic?.checkpoint(.fixtureReady)
    let observedCutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    let original = try #require(game.nativeSalvageWork)
    diagnostic?.checkpoint(.hotWorkReady)
    let body = try #require(game.bodies.first { $0.physical?.identity == original.actor })
    let source = original.plan.source
    var cycle = original.cycle
    if change == "owner" {
      cycle = .init(
        id: cycle.id, owner: UUID(), version: cycle.version, inspection: cycle.inspection,
        beganAt: cycle.beganAt, observedAt: cycle.observedAt, progress: cycle.progress,
        currentWorkSeconds: cycle.currentWorkSeconds, damagedTechnology: cycle.damagedTechnology,
        releases: cycle.releases, lastRelease: cycle.lastRelease,
        lastOperation: cycle.lastOperation,
        depleted: cycle.depleted, destroyedAt: cycle.destroyedAt)
    }
    var section = original.section
    if change == "section" {
      section = .init(
        index: section.index, kind: section.kind, localPosition: section.localPosition,
        normal: section.normal, radius: section.radius, workSeconds: section.workSeconds + 1,
        structural: section.structural, technologyDefinitionIDs: section.technologyDefinitionIDs,
        sourceFaceIndex: section.sourceFaceIndex)
    }
    let stale = NativeSalvageHotWork(
      section: section, seed: original.seed, plan: original.plan,
      actor: change == "actor"
        ? .init(
          system: original.actor.system, visit: original.actor.visit,
          entity: original.actor.entity + 1)
        : original.actor,
      hull: change == "hull" ? UUID() : original.hull,
      epoch: change == "epoch" ? UUID() : original.epoch,
      wreckRecord: change == "source" ? UUID() : original.wreckRecord,
      wreckSource: original.wreckSource, catalogueShipID: original.catalogueShipID,
      originalCycle: change == "cycle"
        ? original.originalCycle.observing(
          at: original.cycle.observedAt,
          progress: original.originalCycle.progress, seconds: 0.01, damaged: false, operation: 999)
        : original.originalCycle,
      cycle: cycle)
    game.nativeSalvageWork = stale
    #expect(!game.nativeSalvageHotWorkIsCurrent(stale))
    let commander = game.commander
    let energy = game.energy
    let heat = game.laserHeat
    let observedWorkBegin = game.beginNativeSalvageWork(
      body: body, section: original.section, source: source)
    #expect(!observedWorkBegin)
    let observedWorkFlush = game.flushNativeSalvageWork()
    #expect(!observedWorkFlush)
    let observedWreck = game.observeNativeSalvageWreck(body)
    #expect(observedWreck)
    let observedWreckFlush = game.flushNativeSalvageWrecks()
    #expect(!observedWreckFlush)
    #expect(game.commander == commander && game.energy == energy && game.laserHeat == heat)
    #expect(game.nativeSalvageWork?.cycle == stale.cycle)
    diagnostic?.checkpoint(.preFinalFlush)
    game.nativeSalvageWork = original
    let observedWorkFlush2 = game.flushNativeSalvageWork()
    #expect(observedWorkFlush2)
    diagnostic?.checkpoint(.finalFlushDone)
  }

  @Test func freshFactorySealsTheWholeOriginalLedgerAndNeverClampsExcessOldPartial() throws {
    let (game, wreckSource) = try NativePagedSalvageFixture.empGame()
    let body = try #require(
      game.bodies.first { $0.physical?.salvage?.wreck == wreckSource.identity })
    let ownedPreparationRequired1 = game.salvageProfile(for: body)
    let profile = try #require(ownedPreparationRequired1)
    let section = try #require(profile.sections.first)
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: game.currentSystem.economy,
      technology: game.currentSystem.technology, ownership: .abandoned)
    let original = game.commander.salvageLedger
    let facts = try #require(
      original.freshNativeInspection(
        wreck: wreckSource.identity, section: section, source: source))
    #expect(facts.matches(original))
    var changed = original
    let observedWreckUpdate = changed.updateWreck(
      identity: wreckSource.identity,
      motion: .init(
        pose: .init(position: .init(1, 0, 0)), velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0), energy: 100))
    #expect(
      observedWreckUpdate)
    #expect(!facts.matches(changed))
    let shorter = SalvageSectionProfile(
      index: section.index, kind: section.kind, localPosition: section.localPosition,
      normal: section.normal, radius: section.radius, workSeconds: 0.1,
      structural: section.structural, technologyDefinitionIDs: section.technologyDefinitionIDs,
      sourceFaceIndex: section.sourceFaceIndex)
    var partial = original
    let observedWorkResult = partial.advance(
      wreck: wreckSource.identity, section: section, pose: .init(),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0), tool: .cutter,
      elapsed: 0.25, operation: 1, conditions: NativePagedSalvageFixture.permitted)
    #expect(
      observedWorkResult
        == .progress(seconds: 0.25, required: section.workSeconds))
    let before = partial
    #expect(
      partial.freshNativeInspection(wreck: wreckSource.identity, section: shorter, source: source) == nil)
    #expect(
      partial == before
        && partial.progress(.init(wreck: wreckSource.identity, section: section.index)) == 0.25)
  }
}
