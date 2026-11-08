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
