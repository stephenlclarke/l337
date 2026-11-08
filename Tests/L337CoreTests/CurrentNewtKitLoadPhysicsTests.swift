import Foundation
import Testing

@testable import L337Core

struct CurrentNewtKitLoadPhysicsTests {
  @Test func installedHardwareRemainsWhenECMIsDisabledAndInventoryEmpty() throws {
    for enabled in [false, true] {
      let (model, load) = try fixture(ecm: enabled)
      #expect(model.matches(load, selectedPerson: load.people[0].identity))
      let components = try #require(model.masses(load))
      #expect(abs(components.reduce(0) { $0 + $1.massKilograms } - 180) < 1e-8)
    }
  }

  @Test func nativeKilogramsGramsAndActualFuelRemainderContributeToMass() throws {
    let cargo: [CommodityAmount] = [
      .init(commodity: .food, quantity: 2), .init(commodity: .gold, quantity: 12),
      .init(commodity: .gemstones, quantity: 500),
    ]
    let (model, load) = try fixture(cargo: cargo, fuel: 129, remainder: 0.25, missiles: 3)
    #expect(model.matches(load, selectedPerson: load.people[0].identity))
    let components = try #require(model.masses(load))
    #expect(abs(components.reduce(0) { $0 + $1.massKilograms } - 2601) < 1e-8)
  }

  @Test func positiveNativeQuantitiesCannotBypassPhysicalCapacityOrRecordedEquipment() throws {
    let (model, excessiveGold) = try fixture(cargo: [.init(commodity: .gold, quantity: 60_001)])
    #expect(!model.matches(excessiveGold, selectedPerson: excessiveGold.people[0].identity))
    let (_, overfullFuel) = try fixture(fuel: 130, remainder: 0.1)
    #expect(!model.matches(overfullFuel, selectedPerson: overfullFuel.people[0].identity))
    let (_, tooManyMissiles) = try fixture(missiles: 6)
    #expect(!model.matches(tooManyMissiles, selectedPerson: tooManyMissiles.people[0].identity))
    for unknown in [nil, true] as [Bool?] {
      let (_, wrongScoops) = try fixture(scoops: unknown)
      #expect(!model.matches(wrongScoops, selectedPerson: wrongScoops.people[0].identity))
    }
  }

  @Test func ordinaryShieldAndThermalClockDoNotEraseOrChangeInventoryMass() throws {
    let (model, load) = try fixture(fuel: 100, evolvedReadings: true)
    #expect(model.matches(load, selectedPerson: load.people[0].identity))
    let components = try #require(model.masses(load))
    #expect(abs(components.reduce(0) { $0 + $1.massKilograms } - 380) < 1e-8)
  }

  private func fixture(cargo: [CommodityAmount] = [], fuel: Int = 0, remainder: Double = 0,
    missiles: Int = 0, ecm: Bool = false, scoops: Bool? = false, evolvedReadings: Bool = false)
    throws -> (CurrentNewtKitLoadModel, CurrentNewtKitLoad)
  {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let file = root.appendingPathComponent("Sources/L337Core/Resources/OriginalFleetPhysical")
      .appendingPathComponent(CurrentNewtKitPhysicalSource.resourceFileName)
    let data = try Data(contentsOf: file)
    let source = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let model = try #require(CurrentNewtKitLoadModel.decode(source["ordinaryLoadModel"]))
    let performance = try #require(ShipCatalogue.ship("SH029")?.game)
    var readings = try #require(NPCResources.stock(performance))
    readings.fuel = fuel
    readings.scoopRemainder = remainder
    if evolvedReadings {
      readings.frontShield -= 1
      readings.laserHeat = 1
    }
    let actor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 42)
    let identity = EMPCrewIdentity(source: actor, ordinal: 0)
    let load = CurrentNewtKitLoad(catalogueShipID: "SH029", r3SHA256: model.r3SHA256,
      cargo: cargo, cargoProvenance: .generated, resources: readings, missiles: missiles,
      ecmEnabled: ecm, hasFuelScoops: scoops,
      people: [.init(identity: identity, profile: .init(id: CurrentNewtKitPhysicalSource.personProfileID,
        sourceSHA256: CurrentNewtKitPhysicalSource.sourceSHA256, massKilograms: 100,
        dimensionsMetres: .init(0.56, 0.38, 1.72)))])
    return (model, load)
  }
}
