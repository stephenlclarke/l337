import Foundation
import Testing

@testable import L337Core

enum NativeCrewTestFixture {
  /// Controlled initial owned hull and funds, followed by a genuine attained station arrival.
  /// This establishes service custody, not four-hull purchase or fabrication eligibility.
  static func runtime(
    storage: NativeStationTestStorage, shipID: String = "SH013", escapeReady: Bool = false,
    initialCredits: Int = 1_000_000
  ) async throws -> GameRuntime {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.galaxy = 0
    game.commander.system = 7
    game.systems = Universe.systemsIncludingPlugh(number: 0)
    game.selectedSystem = 7
    game.market = MarketItem.at(game.currentSystem)
    try #require((1...20_000_000).contains(initialCredits))
    game.commander.credits = initialCredits
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    if escapeReady {
      let item = try #require(Equipment.all.first { $0.name == "Escape Pod" })
      let quote = try game.quoteEquipmentPurchase(item)
      let purchased = try game.applyEquipmentPurchase(quote)
      try #require(purchased)
    }
    try #require(game.commander.shipID == "SH025")
    game.launch()
    try #require(!game.docked && game.commander.valid)
    if shipID != "SH025" {
      let before = game
      try game.commander.transferEquipment(to: shipID, hullID: UUID())
      game.preserveEquipmentResourceFractions(from: before)
    }
    try #require(game.commander.valid)
    try ScriptFinanceTestFixture.approachMain(&game)
    let runtime = GameRuntime(game: game, saveURL: storage.url)
    try await ScriptFinanceTestFixture.enterMain(runtime)
    try #require(await runtime.snapshot().nativeMainStationDockEvidenceIsCurrent)
    return runtime
  }
  static func identity(_ index: Int, in game: Game) throws -> NativeStationPersonIdentity {
    try #require(game.nativeCrewPeople.indices.contains(index))
    return game.nativeCrewPeople[index].identity
  }
  static func hire(_ index: Int, runtime: GameRuntime) async throws {
    let id = try identity(index, in: await runtime.snapshot())
    let quote = await runtime.snapshot().nativeCrewQuote(.hire(id))
    try #require(quote.allowed, "\(quote.issues)")
    try await NativePeopleTestFixture.confirm(runtime, row: .crew(.hire(id)))
    try #require(await runtime.snapshot().commander.assignedNativeCrew.contains { $0.identity == id })
  }
  static func fill(_ runtime: GameRuntime) async throws {
    let game = await runtime.snapshot()
    let missing = try #require(game.commander.nativeCrewMissing)
    let station = try #require(game.commander.nativeStations?.currentMainDock?.station)
    let candidates = game.nativeCrewPeople.filter { $0.location.station == station }
    try #require(candidates.count >= missing)
    for person in candidates.prefix(missing) {
      try await NativePeopleTestFixture.confirm(runtime, row: .crew(.hire(person.identity)))
    }
    try #require(await runtime.snapshot().commander.nativeCrewMissing == 0)
  }
  static func reviewFirst(_ runtime: GameRuntime) async throws -> ScriptPagePresentation {
    let id = try identity(0, in: await runtime.snapshot())
    return try await NativePeopleTestFixture.review(runtime, row: .crew(.hire(id)))
  }
}

struct NativeCrewServiceUnitTests {
  @Test func actualFiniteSourceQuoteBackAndPaidFirstContractDoNotMintPeopleOrCabins() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage)
    let before = await runtime.snapshot()
    #expect(before.commander.nativePeople?.crewService == nil)
    #expect(before.nativeCrewPeople.count == 13)
    #expect(Set(before.nativeCrewPeople.map(\.identity)).count == 13)
    #expect(before.nativeCrewPeople.allSatisfy { $0.identity.valid && $0.contract == nil })
    #expect(before.nativeCrewPeople.allSatisfy {
      !["mira-talen", "oren-vey", "lysa-renn", "tovan-hale"].contains($0.identity.person)
        && $0.identity.id != before.commander.equipmentOwnerID
    })
    for _ in 0..<3 {
      let page = try await NativeCrewTestFixture.reviewFirst(runtime)
      #expect(await runtime.snapshot().contractBoard.action == .back)
      await runtime.scriptPageKey("return", expected: page)
      #expect(await runtime.snapshot().commander == before.commander)
    }
    try await NativeCrewTestFixture.hire(0, runtime: runtime)
    let after = await runtime.snapshot()
    let source = try #require(after.commander.nativePeople?.crewService)
    #expect(after.commander.credits == before.commander.credits - 2000)
    #expect(source.people.count == 13 && source.receipts.count == 1)
    #expect(source.people[0].identity == before.nativeCrewPeople[0].identity)
    #expect(source.people[0].location == .aboard(hull: try #require(after.commander.hullInstanceID), place: 1))
    #expect(source.people[0].contract == source.receipts[0].operation)
    #expect(source.people.filter { $0.location.station == source.registration.station }.count == 12)
    #expect(after.commander.assignedNativeCrew.count == 1 && after.commander.nativeCrewMissing == 4)
    #expect(after.commander.cargo == before.commander.cargo)
    #expect(after.commander.accommodation == before.commander.accommodation)
    #expect(after.commander.equipmentInventory == before.commander.equipmentInventory)
    #expect(after.requiresScriptDurability && after.commander.valid)
    #expect(after.commander.nativePeople?.admissions.isEmpty == true)
    #expect(after.nativeCrewQuote(.hire(source.people[0].identity)).allowed == false)
  }

  @Test func currentColdLoadKeepsExactPaidContractAndVoluntaryReassignmentCostsZero() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage)
    try await NativeCrewTestFixture.hire(0, runtime: runtime)
    let hired = await runtime.snapshot()
    let person = try #require(hired.commander.assignedNativeCrew.first)
    try await NativePeopleTestFixture.confirm(runtime, row: .crew(.disembark(person.identity)))
    let landed = await runtime.snapshot()
    let current = try #require(landed.commander.nativePeople?.crewService?.people.first)
    #expect(current.identity == person.identity && current.contract == person.contract)
    #expect(current.location == .station(try #require(landed.commander.nativeStations?.currentMainDock?.station)))
    #expect(landed.commander.credits == hired.commander.credits)
    #expect(landed.nativeCrewQuote(.hire(person.identity)).price == 0)
    #expect(landed.nativeCrewQuote(.hire(person.identity)).allowed)
    try await NativeCrewTestFixture.hire(0, runtime: runtime)
    let reassigned = await runtime.snapshot()
    #expect(reassigned.commander.credits == hired.commander.credits)
    #expect(reassigned.commander.assignedNativeCrew.first?.contract == person.contract)
    try await runtime.save(to: storage.url)
    let reader = GameRuntime()
    try await reader.load(from: storage.url, persistMigrations: false)
    let cold = await reader.snapshot()
    #expect(cold.commander.nativePeople?.crewService == reassigned.commander.nativePeople?.crewService)
    #expect(cold.commander.credits == reassigned.commander.credits && cold.commander.valid)
    #expect(cold.nativeCrewPeople.count == 13 && cold.commander.nativeCrewMissing == 4)
    var custody = try #require(cold.commander.nativePeople)
    let original = custody
    custody.crewService?.people[0].contract = nil
    #expect(original == cold.commander.nativePeople && custody != original)
    var corrupt = cold.commander
    corrupt.savedNativePeopleCustody = custody
    #expect(!corrupt.valid)
  }

  @Test func failedActualFirstHireWriterRollsBackSourceDebitAssignmentAndPriorFiles() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage)
    try await runtime.save(to: storage.url)
    let page = try await NativeCrewTestFixture.reviewFirst(runtime)
    await runtime.scriptPageKey("right", expected: page)
    let before = await runtime.snapshot()
    let files = try ScriptFinanceTestFixture.files(storage.directory)
    try storage.blockWriter()
    await runtime.scriptPageKey("return", expected: page)
    let failed = await runtime.snapshot()
    #expect(failed.commander == before.commander)
    #expect(failed.commander.nativePeople?.crewService == nil)
    #expect(try ScriptFinanceTestFixture.files(storage.backup) == files)
    try storage.restoreWriter()
    try await NativeCrewTestFixture.hire(0, runtime: runtime)
    #expect(await runtime.snapshot().commander.credits == before.commander.credits - 2000)
    #expect(await runtime.snapshot().commander.nativePeople?.crewService?.receipts.count == 1)
  }

  @Test(arguments: ["cash", "epoch", "hull", "occupied-place", "lost-consent"])
  func staleExactCrewQuoteCannotPublishPartialChanges(boundary: String) async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage)
    _ = try await NativeCrewTestFixture.reviewFirst(runtime)
    let reviewed = await runtime.snapshot()
    let quote = try #require(reviewed.contractBoard.peopleQuote)
    try #require(quote.allowed)
    if boundary == "occupied-place" || boundary == "lost-consent" {
      try await NativeCrewTestFixture.hire(boundary == "lost-consent" ? 0 : 1, runtime: runtime)
    }
    var changed = await runtime.snapshot()
    changed.contractBoard = reviewed.contractBoard // Retain only the obsolete painted review.
    switch boundary {
    case "cash": changed.commander.credits = 0
    case "epoch": changed.invalidateNativeStationAuthority()
    case "hull": try changed.commander.transferEquipment(to: "SH014", hullID: UUID())
    default: break
    }
    let before = changed.commander
    #expect(throws: (any Error).self) { try changed.confirmNativePeople(quote) }
    #expect(changed.commander == before)
    if boundary == "lost-consent" {
      #expect(changed.nativeCrewQuote(.hire(try NativeCrewTestFixture.identity(0, in: changed))).allowed == false)
    }
  }

  @Test func reservedMissionPeopleDuplicateAssignmentsAndUnknownSavedKeysAreRejected() async throws {
    let storage = try NativeStationTestStorage()
    defer { storage.clean() }
    let runtime = try await NativeCrewTestFixture.runtime(storage: storage)
    let game = await runtime.snapshot()
    let owner = try #require(game.commander.equipmentOwnerID)
    for (batch, person) in [
      (NativeStationPassengerJourney.batch, "mira-talen"),
      (NativeStationPassengerJourney.batch, "oren-vey"),
      (NativeOrbitalOutlookJourney.batch, "lysa-renn"),
      (NativeOrbitalOutlookJourney.batch, "tovan-hale"),
    ] {
      let id = NativeStationPersonIdentity(owner: owner, batch: batch, person: person)
      #expect(id.valid && !game.nativeCrewQuote(.hire(id)).allowed)
    }
    try await NativeCrewTestFixture.hire(0, runtime: runtime)
    try await NativeCrewTestFixture.hire(1, runtime: runtime)
    let good = await runtime.snapshot().commander
    for duplicatePerson in [false, true] {
      var bad = good
      var custody = try #require(bad.nativePeople)
      if duplicatePerson {
        let person = try #require(custody.crewService?.people[0])
        custody.crewService?.people[1] = person
      } else {
        let location = try #require(custody.crewService?.people[0].location)
        custody.crewService?.people[1].location = location
      }
      bad.savedNativePeopleCustody = custody
      #expect(!bad.valid)
    }
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(good)) as? [String: Any])
    try NativeCrewService.validateFields(JSONEncoder().encode(good), part: .commander)
    var custody = try #require(object["savedNativePeopleCustody"] as? [String: Any])
    var source = try #require(custody["crewService"] as? [String: Any])
    source["freePeople"] = 13
    custody["crewService"] = source
    object["savedNativePeopleCustody"] = custody
    let bytes = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: SaveError.self) { try NativeCrewService.validateFields(bytes, part: .commander) }
    var bounded = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(good)) as? [String: Any])
    var boundedCustody = try #require(bounded["savedNativePeopleCustody"] as? [String: Any])
    var boundedSource = try #require(boundedCustody["crewService"] as? [String: Any])
    let receipts = try #require(boundedSource["receipts"] as? [[String: Any]])
    let first = try #require(receipts.first)
    boundedSource["receipts"] = Array(repeating: first, count: 1025)
    boundedCustody["crewService"] = boundedSource
    bounded["savedNativePeopleCustody"] = boundedCustody
    let oversized = try JSONSerialization.data(withJSONObject: bounded)
    #expect(throws: SaveError.self) {
      try NativeCrewService.validateFields(oversized, part: .commander)
    }
    // The current Codable leaf is bounded even when decoded directly, outside the file wrapper.
    let leaf = try JSONSerialization.data(withJSONObject: boundedSource)
    #expect(throws: SaveError.self) {
      try JSONDecoder().decode(NativeCrewServiceState.self, from: leaf)
    }
  }
}
