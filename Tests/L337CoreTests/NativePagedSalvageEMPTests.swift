import Foundation
import Testing

@testable import L337Core

/// EMP custody unit coverage; generated-site and alien-attachment coverage stays separate.
struct NativePagedSalvageEMPTests {
  @Test func genuineEMPInspectionAndWorkBypassEveryFullOrdinaryLifetimePool() async throws {
    var (game, source) = try NativePagedSalvageFixture.empGame(fullOrdinaryPools: true)
    let original = game.commander.salvageLedger
    #expect(original.wreckMotion(for: source.identity) != nil)
    #expect(game.salvageSites.isEmpty)
    let wreck = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[source.identity])
    #expect(wreck.source == .emp(actor: source.actor, sequence: source.sequence))
    #expect(wreck.seed == original.nativeInspectionSeed)
    let observedCutterResult = game.fireSalvageCutter(delta: 0.1)
    #expect(observedCutterResult)
    let hot = try #require(game.nativeSalvageWork)
    #expect(hot.plan.section == source.section)
    #expect(!hot.plan.source.roles.contains(.thargoid))
    let expected = SalvageLootProfiles.plan(
      section: hot.plan.section, seed: original.nativeInspectionSeed, source: hot.plan.source)
    #expect(hot.plan == expected && hot.cycle.currentWorkSeconds == 0.1)
    #expect(hot.cycle.releases == 0 && hot.cycle.progress.nextLot == 0)
    #expect(game.commander.salvageLedger == original)
    #expect(game.commander.alienStorageState?.current.snapshot.sources.isEmpty == true)
    let observedWorkFlush = game.flushNativeSalvageWork()
    #expect(observedWorkFlush)
    #expect(game.commander.salvageLedger == original)
    let snapshot = try #require(game.commander.alienStorageState?.current.snapshot)
    try snapshot.validate()
    var pages = AlienStorageMemoryPages()
    let archive = try AlienStoragePageCodec.encode(snapshot: snapshot, previous: nil, into: &pages)
    let observedDecodedSnapshot = try AlienStoragePageCodec.decode(
      reference: archive.reference, expectedOwner: snapshot.owner, rootData: archive.rootData,
      from: pages)
    #expect(
      observedDecodedSnapshot == snapshot)
    #expect(pages.pages.values.allSatisfy { $0.count <= AlienStoragePageCodec.maximumPageBytes })
    let body = try #require(
      game.bodies.first {
        $0.physical?.salvage?.wreck == source.identity && $0.physical?.payload == nil
      })
    game.selectFlightTool(.salvageCutter)
    try NativePagedSalvageFixture.engageSalvageTarget(&game, body: body, section: hot.plan.section)
    let folder = try NativePagedSalvageFixture.folder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    await runtime.setControls(NativePagedSalvageFixture.firingControls)
    var released = await runtime.snapshot()
    for _ in 0..<2000 {
      released = await NativePagedSalvageFixture.advanceHeldWork(runtime, delta: 0.02)
      if released.commander.alienStorageState?.current.salvage.native.works[
        hot.cycle.inspection.id]?.releases == 1
      {
        break
      }
    }
    let native = try #require(released.commander.alienStorageState?.current.salvage)
    #expect(native.native.works[hot.cycle.inspection.id]?.releases == 1)
    #expect(!native.pending.isEmpty && native.pending.count <= 8)
    #expect(released.commander.salvageLedger.pendingLots == original.pendingLots)
    #expect(released.commander.salvageLedger.inventory == original.inventory)
    // Actual native spawn admission shares only the original producer sequence.
    // Compare the complete old semantic ledger after accounting for that one allocator.
    var actualFields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(released.commander.salvageLedger))
        as? [String: Any])
    let oldFields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    actualFields["sequence"] = oldFields["sequence"]
    let retained = try JSONDecoder().decode(
      SalvageLedger.self, from: JSONSerialization.data(withJSONObject: actualFields))
    #expect(retained == original)
    #expect(native.native.plans[hot.cycle.inspection.id]?.plan == expected)
    #expect(native.native.works[hot.cycle.inspection.id]?.currentWorkSeconds == 0)

  }

}
