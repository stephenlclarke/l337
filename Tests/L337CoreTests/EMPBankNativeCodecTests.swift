import Foundation
import Testing

@testable import L337Core

private enum EMPBankNativeFixture {
  static func game(useOwnedStarter: Bool = false) throws -> Game {
    var game = try EMPBankOwnershipFixture.historyGame(useOwnedStarter: useOwnedStarter)
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    return game
  }

  static func files(at directory: URL) throws -> [String: Data] {
    let enumerator = try #require(FileManager.default.enumerator(atPath: directory.path))
    var files: [String: Data] = [:]
    for case let relative as String in enumerator {
      let file = directory.appendingPathComponent(relative)
      guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
        continue
      }
      try #require(!relative.isEmpty && files[relative] == nil)
      files[relative] = try Data(contentsOf: file)
    }
    return files
  }
}

struct EMPBankNativeCodecTests {
  @Test func currentNativeSaveColdReloadRetainsExactPhysicalModuleBankAndReleaseHistory()
    async throws
  {
    let game = try EMPBankNativeFixture.game(useOwnedStarter: true)
    let expected = try EMPBankOwnershipFixture.item(game.commander)
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    try await runtime.save(to: file)
    let savedGame = await runtime.snapshot()
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(saved == savedGame.commander)
    #expect(try EMPBankOwnershipFixture.item(saved) == expected)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    #expect(pointer.schemaVersion >= 22)
    let restored = GameRuntime()
    try await restored.load(from: file, persistMigrations: false)
    let loaded = await restored.snapshot()
    #expect(loaded.commander == saved && loaded.commander.valid)
    let actual = try EMPBankOwnershipFixture.item(loaded.commander)
    #expect(actual == expected && actual.empBank?.remaining == 4)
    #expect(actual.empBank?.lastDischarge == expected.empBank?.lastDischarge)
    #expect(actual.empBank?.lastDischarge != nil)
    // This is real native roundtrip evidence when run, not production bank admission proof.
  }

  @Test func failedExplicitNativeWritePreservesPriorGenerationBankAndCommanderUntilRetry()
    async throws
  {
    let game = try EMPBankNativeFixture.game(useOwnedStarter: true)
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let directory = folder.appendingPathComponent("save")
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    try await runtime.save(to: file)
    let before = await runtime.snapshot().commander
    let bank = try EMPBankOwnershipFixture.item(before)
    let property = try EMPBankNativeFixture.files(at: directory)
    let backup = folder.appendingPathComponent("backup")
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked".utf8).write(to: directory)
    await #expect(throws: (any Error).self) { try await runtime.save(to: file) }
    #expect(await runtime.snapshot().commander == before)
    #expect(try EMPBankNativeFixture.files(at: backup) == property)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    try await runtime.save(to: file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(try EMPBankOwnershipFixture.item(saved) == bank)
    #expect(await runtime.snapshot().commander == saved)
    let cold = GameRuntime()
    try await cold.load(from: file, persistMigrations: false)
    #expect(try EMPBankOwnershipFixture.item(await cold.snapshot().commander) == bank)
  }

  @Test func actualDurableHullExchangeWriteFailureRetainsBankThenRetryAndColdReloadPreserveIt()
    async throws
  {
    var game = try EMPBankNativeFixture.game()
    game.screen = .showroom
    game.showroom.selection = "SH001"
    game.commander.credits = 10_000_000
    try #require(game.requiresScriptDurability)
    let quote = try #require(game.shipTradeQuote)
    try #require(quote.allowed)
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let directory = folder.appendingPathComponent("save")
    let file = directory.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game, saveURL: file)
    try await runtime.save(to: file)
    let before = await runtime.snapshot().commander
    let bank = try EMPBankOwnershipFixture.item(before)
    let property = try EMPBankNativeFixture.files(at: directory)
    let backup = folder.appendingPathComponent("backup")
    try FileManager.default.moveItem(at: directory, to: backup)
    try Data("blocked".utf8).write(to: directory)
    await runtime.key("showroom-trade")
    await runtime.key("right")
    let beforeFailure = await runtime.snapshot()
    await runtime.key("return")
    let refused = await runtime.snapshot()
    #expect(refused.commander == before && refused.bodies == beforeFailure.bodies)
    #expect(refused.inventoryContextEpoch == beforeFailure.inventoryContextEpoch)
    #expect(refused.showroom.trading)
    #expect(try EMPBankNativeFixture.files(at: backup) == property)
    try FileManager.default.removeItem(at: directory)
    try FileManager.default.moveItem(at: backup, to: directory)
    await runtime.key("return")
    let accepted = await runtime.snapshot().commander
    #expect(accepted.shipID == "SH001" && accepted.credits == quote.balance && accepted.valid)
    let transferred = try EMPBankOwnershipFixture.item(accepted)
    #expect(transferred.moved(to: nil) == bank.moved(to: nil))
    #expect(transferred.empBank == bank.empBank)
    #expect(accepted.equipmentPurchaseHistory == before.equipmentPurchaseHistory)
    #expect(accepted.hullInstanceID != before.hullInstanceID)
    #expect(try NativeSaveTestFixture.readVersionedCommander(from: file) == accepted)
    let cold = GameRuntime()
    try await cold.load(from: file, persistMigrations: false)
    #expect(await cold.snapshot().commander == accepted)
  }

  @Test func rawAndPre22NativeInputsRejectBankPresenceIncludingNullWithoutRejectingAuthoredText()
    async throws
  {
    let game = try EMPBankNativeFixture.game()
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: game)
    try await runtime.save(to: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: Data(contentsOf: file))
    let old = ScriptSavePointer(
      format: pointer.format, schemaVersion: 21, generation: pointer.generation,
      hashes: pointer.hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
    #expect(throws: SaveError.invalidCommander) {
      _ = try ScriptSaveStore.read(ScriptValueStorage.encoder().encode(old), from: file)
    }
    let bank = try #require(EMPBankOwnershipFixture.item(game.commander).empBank)
    let encodedBank = try JSONSerialization.jsonObject(with: JSONEncoder().encode(bank))
    // A wrong-node/null field must be caught by the raw guard itself, before item decode.
    for key in ["empBank", "empGrades"] {
      for field in [NSNull() as Any, encodedBank] {
        for inventoryKey in ["savedEquipmentInventory", "ownedEquipment"] {
          let raw: [String: Any] = [inventoryKey: ["items": [[
            "node": ["key": "Fuel Scoops"], key: field,
          ]]]]
          let bytes = try JSONSerialization.data(withJSONObject: raw)
          #expect(throws: SaveError.invalidCommander) {
            try EMPVersionedSave.rejectFields(bytes, part: .commander)
          }
        }
      }
    }
    let harmless: [String: Any] = [
      "name": "empBank", "scriptState": ["data": ["empBank": NSNull()]],
      "savedEquipmentInventory": ["items": []],
    ]
    try EMPVersionedSave.rejectFields(
      JSONSerialization.data(withJSONObject: harmless), part: .commander)
    let raw = folder.appendingPathComponent("raw.json")
    try JSONEncoder().encode(game.commander).write(to: raw)
    let cold = GameRuntime()
    let before = await cold.snapshot().commander
    await #expect(throws: (any Error).self) { try await cold.load(from: raw) }
    #expect(await cold.snapshot().commander == before)
  }

  @Test func malformedForeignOrFutureBankLoadCannotPublishCommanderOrRewriteExistingGeneration()
    async throws
  {
    let game = try EMPBankNativeFixture.game(useOwnedStarter: true)
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let writer = GameRuntime(game: game)
    try await writer.save(to: file)
    let originalPointer = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: originalPointer)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: file)
    let header = generation.appendingPathComponent("commander.json")
    let originalHeader = try Data(contentsOf: header)
    let originalObject = try #require(
      JSONSerialization.jsonObject(with: originalHeader) as? [String: Any])
    let cold = GameRuntime()
    let before = await cold.snapshot().commander
    for kind in ["module", "balance", "future", "missingBank", "missingGrades", "nullGrades", "missingPaid"] {
      var object = originalObject
      var inventory = try #require(object["savedEquipmentInventory"] as? [String: Any])
      var items = try #require(inventory["items"] as? [[String: Any]])
      let index = try #require(items.firstIndex { $0["empBank"] != nil })
      var bank = try #require(items[index]["empBank"] as? [String: Any])
      switch kind {
      case "module": bank["module"] = UUID().uuidString
      case "balance": bank["remaining"] = 9
      default: break
      }
      items[index]["empBank"] = bank
      switch kind {
      case "future":
        bank["physicalTime"] = game.commander.flightSimulation.physicalTime + 1
        items[index]["empBank"] = bank
      case "missingBank": items[index].removeValue(forKey: "empBank")
      case "missingGrades": items[index].removeValue(forKey: "empGrades")
      case "nullGrades": items[index]["empGrades"] = NSNull()
      case "missingPaid":
        var grades = try #require(items[index]["empGrades"] as? [String: Any])
        grades.removeValue(forKey: "paid")
        items[index]["empGrades"] = grades
      default: break
      }
      inventory["items"] = items
      object["savedEquipmentInventory"] = inventory
      let malformed = try JSONSerialization.data(withJSONObject: object)
      try malformed.write(to: header)
      var hashes = pointer.hashes
      hashes["commander.json"] = ScriptPackLibrary.hash(malformed)
      let altered = ScriptSavePointer(
        format: pointer.format, schemaVersion: pointer.schemaVersion, generation: pointer.generation,
        hashes: hashes, scope: pointer.scope, valueCodec: pointer.valueCodec)
      try ScriptValueStorage.encoder().encode(altered).write(to: file)
      let property = try EMPBankNativeFixture.files(at: folder)
      await #expect(throws: (any Error).self) {
        try await cold.load(from: file, persistMigrations: false)
      }
      #expect(await cold.snapshot().commander == before)
      #expect(try EMPBankNativeFixture.files(at: folder) == property)
      try originalHeader.write(to: header)
      try originalPointer.write(to: file)
    }
    try await cold.load(from: file, persistMigrations: false)
    #expect(
      try EMPBankOwnershipFixture.item(await cold.snapshot().commander).empBank
        == EMPBankOwnershipFixture.item(game.commander).empBank)
  }

  @Test func emptyCurrentEMPBankAndBaseGradesSurviveNativeSaveWithoutRefilling() async throws {
    var game = try EMPBankOwnershipFixture.game(initialBalance: nil, useOwnedStarter: true)
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    let expected = try EMPBankOwnershipFixture.item(game.commander)
    #expect(expected.empBank?.remaining == 0 && expected.empGrades == .base)
    let folder = try missionGearFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let file = folder.appendingPathComponent("commander.json")
    let writer = GameRuntime(game: game)
    try await writer.save(to: file)
    let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
    #expect(try EMPBankOwnershipFixture.item(saved) == expected)
    let cold = GameRuntime()
    try await cold.load(from: file, persistMigrations: false)
    let loaded = await cold.snapshot()
    #expect(try EMPBankOwnershipFixture.item(loaded.commander) == expected)
    #expect(try EMPBankOwnershipFixture.item(loaded.commander).empBank?.remaining == 0)
    #expect(try EMPBankOwnershipFixture.item(loaded.commander).empGrades == .base)
    #expect(loaded.commander.valid)
    // The positive current roundtrip pairs with the actual malformed native-generation refusals.
  }
}
