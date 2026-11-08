import Foundation
import Testing

@testable import L337Core

struct CurrentNewtKitAccountingTests {
  @Test
  func actualBornLoadKeepsCommodityUnitsFuelFractionAndInstalledECMMass() throws {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let bodyCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate)
    let ownedPreparationRequired1 = game.currentNewtKitLoad(for: body)
    let actual = try #require(ownedPreparationRequired1)
    let source = try #require(CurrentNewtKitSource.current)
    let model = try #require(source.loadModel)
    var resources = actual.resources
    resources.fuel = 12
    resources.scoopRemainder = 0
    func load(cargo: [CommodityAmount], remainder: Double, ecm: Bool) -> CurrentNewtKitLoad {
      var readings = resources
      readings.scoopRemainder = remainder
      return .init(catalogueShipID: actual.catalogueShipID, r3SHA256: actual.r3SHA256,
        cargo: cargo, cargoProvenance: actual.cargoProvenance, resources: readings,
        missiles: actual.missiles, ecmEnabled: ecm, hasFuelScoops: actual.hasFuelScoops,
        people: actual.people)
    }
    let empty = load(cargo: [], remainder: 0, ecm: false)
    let mixed = load(cargo: [.init(commodity: .gold, quantity: 10),
      .init(commodity: .gemstones, quantity: 30)], remainder: 0.25, ecm: false)
    try #require(model.matchesInventory(empty) && model.matchesInventory(mixed))
    let emptyParts = try #require(model.allocations(empty))
    let mixedParts = try #require(model.allocations(mixed))
    let baseline = emptyParts.reduce(0) { $0 + $1.mass.massKilograms }
    let total = mixedParts.reduce(0) { $0 + $1.mass.massKilograms }
    #expect(abs(total - baseline - 10.53) < 1e-9)
    let beds = mixedParts.filter { $0.id.hasPrefix("storage-bed-") }
    #expect(beds.count == 2 && Set(beds.map(\.id)).count == 2)
    #expect(abs(beds.reduce(0) { $0 + $1.mass.massKilograms } - 10.03) < 1e-9)
    let enabled = try #require(model.masses(load(cargo: [], remainder: 0, ecm: true)))
    #expect(abs(enabled.reduce(0) { $0 + $1.massKilograms } - baseline) < 1e-9)
    #expect(body.physical?.currentNewtKitStock?.issue.birthLoad == actual)
  }

  @Test
  func sourceWorkCannotOverdrawShortenOrKeepMovingAtTheRodStop() throws {
    let source = try #require(CurrentNewtKitSource.current)
    let full = CurrentNewtKitStock.WorkState(loweredFraction: 1,
      rodMetres: source.stroke, rodVelocity: 0,
      guideWorkJoules: source.dropWork, ejectionWorkJoules: source.ejectWork)
    #expect(source.validWork(full))
    #expect(!source.validWork(.init(loweredFraction: 0, rodMetres: source.stroke,
      rodVelocity: 0, guideWorkJoules: 0, ejectionWorkJoules: source.ejectWork)))
    #expect(!source.validWork(.init(loweredFraction: 1, rodMetres: source.stroke,
      rodVelocity: 1, guideWorkJoules: source.dropWork, ejectionWorkJoules: source.ejectWork)))
    #expect(!source.validWork(.init(loweredFraction: 1, rodMetres: source.stroke * 0.5,
      rodVelocity: 0, guideWorkJoules: source.dropWork, ejectionWorkJoules: source.ejectWork)))
    #expect(!source.validWork(.init(loweredFraction: 1, rodMetres: source.stroke + 0.001,
      rodVelocity: 0, guideWorkJoules: source.dropWork,
      ejectionWorkJoules: source.maximumForceNewtons * (source.stroke + 0.001))))
  }
}


extension CurrentNewtKitAccountingTests {
  @Test(arguments: ["nil-history", "empty-history", "actual-disabled-history"])
  func realBornStockSurvivesActualNativeFrameWithObservedEMPHistory(history: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await observedRecordRuntime(history: history, storage: storage)
    let before = await runtime.snapshot()
    let beforeBodyCandidate = before.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let beforeBody = try #require(beforeBodyCandidate)
    let identity = try #require(beforeBody.nativeGeometryIdentity())
    let stock = try #require(beforeBody.nativeGeometryStock())
    let loadCandidate = before.currentNewtKitLoad(for: beforeBody)
    let load = try #require(loadCandidate)
    let cellCandidate = before.currentNewtCellComponentContract(for: beforeBody)
    let cell = try #require(cellCandidate)
    let start = before.commander.flightSimulation.physicalTime
    try #require(cell.occupied && load.people.contains(where: { $0.identity == stock.issue.person }))

    // The production actor entry reaches tick -> native interval -> query scene ->
    // colliders -> attached geometry -> observed cell/load on the executor stack.
    // A direct helper-only test would omit the stack chain in the matched crash.
    _ = await runtime.advance(delta: 0.02)
    let after = await runtime.snapshot()
    #expect(abs(after.commander.flightSimulation.physicalTime - (start + 0.02)) < 1e-9)
    let afterBodyCandidate = after.bodies.first { $0.physical?.identity == identity }
    let afterBody = try #require(afterBodyCandidate)
    let afterStock = try #require(afterBody.nativeGeometryStock())
    let afterLoadCandidate = after.currentNewtKitLoad(for: afterBody)
    let afterLoad = try #require(afterLoadCandidate)
    let afterCellCandidate = after.currentNewtCellComponentContract(for: afterBody)
    let afterCell = try #require(afterCellCandidate)
    #expect(afterStock.issue == stock.issue)
    #expect(afterLoad.people == load.people && afterCell.occupied)
    #expect(afterCell.kitID == cell.kitID && afterCell.mass == cell.mass)
    let geometryCandidate = try after.currentNewtGeometryComponents(for: afterBody)
    let geometry = try #require(geometryCandidate)
    #expect(!geometry.isEmpty && geometry.allSatisfy(\.validForCurrentNewtQuery))
    #expect(geometry.contains(where: { $0.id == "actual-identified-person" }))
    if history == "nil-history" {
      #expect(after.commander.savedEMPState == nil)
    } else if history == "empty-history" {
      #expect(after.commander.savedEMPState?.records.isEmpty == true)
    } else {
      let logical = stock.issue.person.source
      #expect(after.commander.savedEMPState?.records[logical]?.hull.binding == identity)
      #expect(after.commander.savedEMPState?.records[logical]?.source == logical)
    }
    #expect(after.commander.nativePeople == before.commander.nativePeople)
  }

  @inline(never)
  private func observedRecordRuntime(history: String, storage: NativeStationTestStorage)
    async throws -> GameRuntime
  {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try #require(game.commander.savedEMPState == nil)
    if history == "empty-history" {
      // Empty bounded history grants no EMP event, actor, person or installed kit.
      game.commander.savedEMPState = EMPState()
    } else if history == "actual-disabled-history" {
      try #require(try releaseDamagedEMPBoundary(&game, seed: nil))
      try #require(game.commander.savedEMPState?.records.count == 1)
    }
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await runtime.save(to: storage.url)
    return runtime
  }

  @Test
  func observedRecordReadStillRejectsAStaleCompleteBodyWithoutMutation() throws {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    let bodyCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate)
    let cellCandidate = game.currentNewtCellComponentContract(for: body)
    try #require(cellCandidate != nil)
    var stale = body
    stale.position.x += 1
    let before = game
    let staleCell = game.currentNewtCellComponentContract(for: stale)
    #expect(staleCell == nil)
    #expect(throws: (any Error).self) { _ = try game.currentNewtGeometryComponents(for: stale) }
    let unchanged = game.commander == before.commander && game.bodies == before.bodies
    #expect(unchanged)
    let actualCell = game.currentNewtCellComponentContract(for: body)
    #expect(actualCell?.kitID == cellCandidate?.kitID)
  }
}
