import Foundation
import Testing

@testable import L337Core

struct CurrentNewtBisonAccountingTests {
  @Test
  func genuineBisonBirthSealsTwelveProfilesAndFiniteCarrierCellsWithoutDecodeRefill() throws {
    let game = try NativePeopleTestFixture.disabled(large: true, seed: 31)
    let logical = try NativePeopleTestFixture.source(game)
    let record = try #require(game.commander.savedEMPState?.records[logical])
    let original = record.custody.original
    let physical = try #require(original.body.physical)
    let stock = try #require(physical.currentNewtKitStock)
    let issue = stock.issue
    let source = try #require(CurrentNewtKitSource.source(for: issue))
    #expect(physical.catalogueShipID == "SH005" && stock.phase == .stowed)
    #expect(physical.identity == issue.birthActor && physical.spawnIdentity == issue.birthSpawn)
    #expect(issue.birthSpawn.producer == .ambient && issue.person.ordinal == 7)
    #expect(issue.birthActor == logical && record.crewTotal == 12)
    #expect(source.configuration == CurrentBisonWideShoePhysicalSource.configurationID)
    #expect(Set(issue.birthLoad.people.map { $0.identity.ordinal }) == Set(0..<12))
    #expect(issue.birthLoad.people.allSatisfy { $0.identity.source == logical })
    #expect(Set(issue.birthLoad.people.map { $0.profile.id }).count == 12)
    #expect(issue.birthLoad.people.allSatisfy { $0.profile.massKilograms == 100 })
    let born = try #require(issue.carrierCells)
    #expect(born.count == 12 && Set(born.map(\.componentID)).count == 12)
    #expect(born.allSatisfy { $0.commissionedAt == issue.issuedAt && $0.electricalJoules == 1_380_000 })
    let time = issue.issuedAt + 600
    let later = try #require(source.carrierCells(issue: issue, load: issue.birthLoad, at: time))
    #expect(later.count == 12 && later.allSatisfy { $0.electricalJoules == 1_354_800 })
    #expect(later[7].originalOccupant == nil && later[2].originalOccupant?.ordinal == 2)
    let decoded = try JSONDecoder().decode(CurrentNewtKitIssue.self, from: JSONEncoder().encode(issue))
    let restored = try #require(source.carrierCells(issue: decoded, load: issue.birthLoad, at: time))
    #expect(decoded == issue && restored.map(\.electricalJoules) == later.map(\.electricalJoules))
    #expect(restored.map(\.oxygenKilograms) == later.map(\.oxygenKilograms))
    #expect(restored.map(\.sorbentCapacityKilogramsCO2) == later.map(\.sorbentCapacityKilogramsCO2))
    let exhausted = try #require(source.carrierCells(issue: decoded, load: issue.birthLoad,
      at: issue.issuedAt + 100_000))
    #expect(exhausted.allSatisfy { $0.exhausted && $0.electricalJoules == 0 })
    #expect(record.deceasedOrdinals.isEmpty && record.crewAboard == 12)
    #expect(game.commander.savedEMPState?.records[logical] == record)
  }

  @Test
  func actualBornBisonMatchesIndependentFullMomentsAndCommodityCellsKeepTheirOwnFractions() throws {
    let game = try NativePeopleTestFixture.disabled(large: true, seed: 31)
    let logical = try NativePeopleTestFixture.source(game)
    let body = try #require(game.bodies.first { $0.physical?.empSource == logical })
    let stock = try #require(body.physical?.currentNewtKitStock)
    let source = try #require(CurrentNewtKitSource.source(for: stock.issue))
    let load = try #require(game.currentNewtKitLoad(for: body))
    let cell = try #require(game.currentNewtCellComponentContract(for: body))
    let actual = try #require(source.loadedMechanicalMass(stock: stock, load: load, cell: cell))
    let model = try #require(source.loadModel)
    let inventory = try #require(model.masses(load))
    let ref = CurrentBisonWideShoePhysicalSource.bornAll12
    let expected = try #require(CurrentNewtKitMass.combined([
      .init(massKilograms: ref.massKilograms, centreOfMassMetres: ref.centreMetres,
        inertiaKgM2: ref.inertiaKgM2),
    ] + inventory))
    #expect(source.matchesMass(actual, expected))
    let components = try #require(source.components(stock: stock,
      at: game.commander.flightSimulation.physicalTime, parent: game.currentNewtBodyState(body),
      load: load, cell: cell))
    #expect(components.filter { $0.id.hasPrefix("original-person-ordinal-") }.count == 12)
    #expect(components.first { $0.id == "original-person-ordinal-2" }?.collisionMesh == nil)
    #expect(source.movingDriveComponentIDs.count == 6 && source.driveContactPairs.count == 2)
    #expect(source.driveFollowerComponentIDs.count == 2)
    #expect(source.movingDriveComponentIDs.subtracting(source.driveFollowerComponentIDs).count == 4)
    #expect(source.driveContactPairs.allSatisfy { $0.driverID.hasPrefix("new-moving-tube-cap-") })
    var readings = load.resources
    readings.fuel = 0
    readings.scoopRemainder = 0.25
    let mixed = CurrentNewtKitLoad(catalogueShipID: load.catalogueShipID, r3SHA256: load.r3SHA256,
      cargo: [.init(commodity: .gold, quantity: 1), .init(commodity: .platinum, quantity: 1),
        .init(commodity: .gemstones, quantity: 1)], cargoProvenance: load.cargoProvenance,
      resources: readings, missiles: 0, ecmEnabled: false, hasFuelScoops: false, people: load.people)
    try #require(model.matchesInventory(mixed))
    let allocations = try #require(model.allocations(mixed))
    let cargo = allocations.filter { $0.id.hasPrefix("actual-cargo-") }
    #expect(cargo.count == 3 && Set(cargo.map(\.id)).count == 3)
    #expect(abs(cargo.reduce(0) { $0 + $1.mass.massKilograms } - 2.001) < 1e-10)
    #expect(abs(allocations.reduce(0) { $0 + $1.mass.massKilograms } - 4.501) < 1e-10)
    #expect(cargo[0].mass.centreOfMassMetres != cargo[1].mass.centreOfMassMetres)
    #expect(cargo[1].mass.centreOfMassMetres != cargo[2].mass.centreOfMassMetres)
    #expect(!allocations.contains { $0.id.lowercased().contains("ecm") })
  }
}
