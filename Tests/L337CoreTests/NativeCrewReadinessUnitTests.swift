import Foundation
import Testing

@testable import L337Core

struct NativeCrewReadinessUnitTests {
  @Test(arguments: [("SH005", 12, 22000), ("SH006", 14, 26000), ("SH013", 6, 10000), ("SH014", 7, 12000)])
  func realPaidFourHullCrewControlsOnlyNormalPlayerLaunch(spec: (String, Int, Int)) async throws {
    let (shipID, required, cost) = spec
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage, shipID: shipID)
    let before = await runtime.snapshot()
    try #require(before.commander.valid && before.docked)
    #expect(before.commander.nativeCrewMissing == required - 1)
    var refused = before
    refused.launch()
    #expect(refused.docked && refused.commander == before.commander && refused.bodies == before.bodies)
    #expect(refused.message.contains("CREW MISSING \(required - 1)"))
    // Understaffing is saveable state, not a Commander.valid or NPC admission freeze.
    try await runtime.save(to: storage.url)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    #expect(await reader.snapshot().commander.valid)
    #expect(await reader.snapshot().commander.nativeCrewMissing == required - 1)
    try await NativeCrewTestFixture.fill(runtime)
    let ready = await runtime.snapshot()
    #expect(ready.commander.credits == before.commander.credits - cost)
    #expect(ready.commander.assignedNativeCrew.count == required - 1)
    #expect(Set(ready.commander.assignedNativeCrew.map(\.identity)).count == required - 1)
    #expect(Set(ready.commander.assignedNativeCrew.compactMap { $0.location.place }) == Set(1..<required))
    #expect(ready.commander.cargo == before.commander.cargo)
    #expect(ready.commander.accommodation == before.commander.accommodation)
    if shipID == "SH005" || shipID == "SH006" {
      #expect(ready.commander.ship.catalogue.purchasePolicy == .blueprintFabrication)
    } else {
      #expect(ready.commander.ship.catalogue.purchasePolicy == .pendingFabrication)
    }
    await runtime.key("escape")
    await runtime.key("0")
    let launched = await runtime.snapshot()
    #expect(!launched.docked && launched.commander.valid)
    #expect(launched.commander.nativeCrewMissing == 0)
    #expect(launched.commander.nativePeople?.crewService == ready.commander.nativePeople?.crewService)
  }

  @Test func currentStarterStillLaunchesWithCommanderAndCrewFocusCannotBuyStaleHardware() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage, shipID: "SH025")
    var game = await runtime.snapshot()
    #expect(game.commander.nativeCrewMissing == 0 && game.commander.assignedNativeCrew.isEmpty)
    game.screen = .equipment
    game.selection = try #require(EquipmentGroups.itemIndices.first)
    let hardware = try #require(game.equipmentPurchaseContext)
    let before = game.commander
    game.moveEquipmentSelection(-1)
    #expect(game.equipmentCrewSelected && game.equipmentPurchaseContext == nil)
    #expect(!game.passengerBerthSelected)
    _ = game.performEquipmentMutation(.purchase(hardware))
    #expect(game.commander == before)
    game.purchase()
    #expect(game.screen == .contracts && game.contractBoard.selected?.people == .crew(.status))
    #expect(game.commander.nativePeople?.crewService == nil && game.commander.credits == before.credits)
    let person = try NativeCrewTestFixture.identity(0, in: game)
    #expect(!game.nativeCrewQuote(.hire(person)).allowed)
    await runtime.key("0")
    #expect(await runtime.snapshot().docked == false)
    #expect(await runtime.snapshot().commander.nativePeople?.crewService == nil)
  }

  @Test func ownedHullTransferRetainsPeopleWhileProjectionAndUnauthorizedExchangeDoNotMutate() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage)
    for index in 0..<3 { try await NativeCrewTestFixture.hire(index, runtime: runtime) }
    let game = await runtime.snapshot()
    let before = game.commander
    let projected = try before.projectedEquipmentTransfer(to: "SH006")
    #expect(projected.hullInstanceID == before.hullInstanceID)
    #expect(projected.nativePeople?.crewService == before.nativePeople?.crewService)
    #expect(before.nativeCrewTransferIssue(to: "SH025") != nil)
    var denied = before
    #expect(throws: EquipmentRuntimeError.self) {
      try denied.transferEquipment(to: "SH006", hullID: UUID())
    }
    #expect(denied == before)
    var wrong = before
    wrong.nativeStations?.currentMainDock = nil
    let wrongBefore = wrong
    #expect(throws: EquipmentRuntimeError.self) {
      try wrong.transferEquipment(to: "SH006", hullID: UUID(), crewEpoch: game.nativeStationRuntimeEpoch)
    }
    #expect(wrong == wrongBefore)
    // This exercises the real owned fitting/crew transaction on controlled initial ownership.
    // It does not establish a purchasable four-hull fabrication service or hull-price debit.
    var moved = before
    let newHull = UUID()
    try moved.transferEquipment(to: "SH006", hullID: newHull, crewEpoch: game.nativeStationRuntimeEpoch)
    #expect(moved.valid && moved.hullInstanceID == newHull)
    #expect(Set(moved.assignedNativeCrew.map(\.identity)) == Set(before.assignedNativeCrew.map(\.identity)))
    #expect(moved.assignedNativeCrew.map(\.contract) == before.assignedNativeCrew.map(\.contract))
    #expect(moved.assignedNativeCrew.allSatisfy { $0.location.hull == newHull })
    #expect(moved.nativePeople?.crewService?.receipts.last?.kind == .exchange)
    #expect(moved.credits == before.credits && moved.cargo == before.cargo)
  }

  @Test func voluntaryDisembarkEnablesSmallerActualExchangeAndFailedWriterRollsBack() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeEarnedPeregrineFixture.runtime(storage: storage)
    let earned = try #require(await runtime.snapshot().commander.fleetBlueprintAcquisition(for: "SH025"))
    for index in 0..<3 { try await NativeCrewTestFixture.hire(index, runtime: runtime) }
    let initial = await runtime.snapshot()
    let smaller = try #require(ShipCatalogue.ship("SH025"))
    let blocked = try #require(initial.shipTradeQuote(for: smaller))
    #expect(!blocked.allowed && blocked.issues.contains { $0.contains("Disembark crew") })
    let contracts = initial.commander.assignedNativeCrew.map(\.contract)
    let ids = initial.commander.assignedNativeCrew.map(\.identity)
    for id in ids {
      try await NativePeopleTestFixture.confirm(runtime, row: .crew(.disembark(id)))
      let current = await runtime.snapshot()
      let count = current.commander.assignedNativeCrew.count
      #expect(Set(current.commander.assignedNativeCrew.compactMap { $0.location.place })
        == Set((0..<count).map { $0 + 1 }))
    }
    let disembarked = await runtime.snapshot()
    #expect(disembarked.commander.credits == initial.commander.credits)
    let station = try #require(disembarked.commander.nativeStations?.currentMainDock?.station)
    let people = try #require(disembarked.commander.nativePeople?.crewService?.people)
    #expect(Array(people.prefix(3)).map(\.identity) == ids)
    #expect(Array(people.prefix(3)).map(\.contract) == contracts)
    #expect(people.prefix(3).allSatisfy { $0.location == .station(station) })
    await runtime.nativeCommand { game in
      game.screen = .status
      game.openShowroom()
      game.showroom.selection = "SH025"
      game.key("showroom-trade")
    }
    try #require(await runtime.snapshot().shipTradeQuote?.allowed == true)
    await runtime.key("right")
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    await runtime.key("return")
    #expect(await runtime.snapshot().commander == before.commander)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    await runtime.key("return")
    let after = await runtime.snapshot()
    #expect(after.commander.shipID == "SH025" && after.commander.valid)
    #expect(after.commander.nativePeople?.crewService == disembarked.commander.nativePeople?.crewService)
    let balance = try #require(before.shipTradeQuote).balance
    #expect(after.commander.credits == balance)
    #expect(after.commander.fleetBlueprintAcquisition(for: "SH025") == earned)
    try await runtime.save(to: storage.url)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    let cold = await reader.snapshot()
    #expect(cold.commander == after.commander)
    #expect(cold.commander.fleetBlueprintAcquisition(for: "SH025") == earned)
  }

  @Test func genuineArrivalAndDisembarkKeepSamePersonAtLaterStationWithoutOriginRefill() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let flight = try OriginalSealedDispatchFixture()
    defer { flight.files.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage)
    try await NativeCrewTestFixture.fill(runtime)
    let source = await runtime.snapshot()
    let person = try #require(source.commander.assignedNativeCrew.first)
    try await flight.travel(runtime, path: [7, 185])
    let arrived = await runtime.snapshot()
    try #require(arrived.nativeMainStationDockEvidenceIsCurrent)
    let station = try #require(arrived.commander.nativeStations?.currentMainDock?.station)
    #expect(station.system == SystemIdentity(galaxy: 0, system: 185))
    try await NativePeopleTestFixture.confirm(runtime, row: .crew(.disembark(person.identity)))
    let landed = await runtime.snapshot()
    let same = try #require(landed.nativeCrewPeople.first { $0.identity == person.identity })
    #expect(same.location == .station(station) && same.contract == person.contract)
    #expect(landed.nativeCrewPeople.count == 13)
    #expect(landed.nativeCrewPeople.filter { $0.location.station == station }.map(\.identity) == [person.identity])
    #expect(landed.nativeCrewQuote(.hire(person.identity)).allowed)
    #expect(landed.nativeCrewQuote(.hire(person.identity)).price == 0)
    let originalStation = NativeCrewService.sourceStation(owner: try #require(landed.commander.equipmentOwnerID))
    #expect(landed.nativeCrewPeople.filter { $0.location.station == originalStation }.count == 8)
    try await runtime.save(to: storage.url)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    #expect(
      await reader.snapshot().commander.nativePeople?.crewService
        == landed.commander.nativePeople?.crewService)
  }

  @Test(arguments: [false, true])
  func actualLossOrEscapeClosesOnlyAboardCrewWithoutRescueOrReplenishment(escape: Bool) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage, escapeReady: escape)
    try await NativeCrewTestFixture.fill(runtime)
    await runtime.key("escape")
    await runtime.key("0")
    let before = await runtime.snapshot()
    try #require(!before.docked && before.commander.assignedNativeCrew.count == 5)
    if escape { await runtime.key("escape-pod") }
    else {
      try await runtime.supplyFatalHullHit()
      _ = await runtime.advance(delta: 0.1)
    }
    let after = await runtime.snapshot()
    let source = try #require(after.commander.nativePeople?.crewService)
    let oldHull = try #require(before.commander.hullInstanceID)
    #expect(source.people.count == 13 && after.commander.assignedNativeCrew.isEmpty)
    #expect(source.receipts.last?.kind == (escape ? .escape : .loss))
    #expect(source.receipts.last?.changes.count == 5 && source.receipts.last?.price == 0)
    #expect(source.people.filter { $0.location.station == source.registration.station }.count == 8)
    #expect(source.people.prefix(5).allSatisfy {
      $0.location == (escape ? .leftOnEscape(hull: oldHull) : .lost(hull: oldHull))
    })
    #expect(after.commander.credits == before.commander.credits && after.commander.valid)
    #expect(after.commander.nativePeople?.admissions.isEmpty == true)
    if escape { #expect(after.docked) }
    var retry = after
    try retry.closeNativeCrew(escape ? .escape : .loss)
    #expect(retry.commander == after.commander)
  }
}
