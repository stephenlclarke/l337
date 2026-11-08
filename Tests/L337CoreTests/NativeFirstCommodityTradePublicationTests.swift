import Foundation
import Testing

@testable import L337Core

private func commodityTradeFileTree(_ root: URL) throws -> [String: Data] {
  let normalizedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
  let prefix = normalizedRoot.path.hasSuffix("/") ? normalizedRoot.path : normalizedRoot.path + "/"
  let listing = try #require(FileManager.default.enumerator(at: normalizedRoot,
    includingPropertiesForKeys: [.isRegularFileKey], options: [])?.allObjects as? [URL])
  var result: [String: Data] = [:]
  for file in listing where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
    let normalizedFile = file.standardizedFileURL.resolvingSymlinksInPath()
    try #require(normalizedFile.path.hasPrefix(prefix))
    let relative = String(normalizedFile.path.dropFirst(prefix.count))
    try #require(!relative.isEmpty && result[relative] == nil)
    result[relative] = try Data(contentsOf: normalizedFile)
  }
  return result
}

private extension GameRuntime {
  func chooseCommodityTradePublicationTestScreen(index: Int) {
    game.screen = .buy
    game.selection = index
  }
}

struct NativeFirstCommodityTradePublicationTests {
  @Test func genuineWriterRefusalRollsBackTradeAndRetryPublishesOneCurrentReceipt() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "first-ordinary-trade-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let container = root.appendingPathComponent("save")
    let backup = root.appendingPathComponent("backup")
    let url = container.appendingPathComponent("commander.json")
    let runtime = GameRuntime(game: Game(executive: false))
    try await runtime.startNewCommander()
    try await runtime.save(to: url)
    let initial = await runtime.snapshot()
    try #require(initial.nativeMainStationDockEvidenceIsCurrent && initial.commander.valid)
    let items = initial.market
    let cargo = initial.commander.cargo
    let credits = initial.commander.availableCredits
    let index = try #require(items.indices.first {
      Commodity.all[$0].unit == "t" && items[$0].quantity > 0
        && items[$0].price <= credits && cargo[$0] == 0
    })
    await runtime.chooseCommodityTradePublicationTestScreen(index: index)
    let before = await runtime.snapshot()
    let files = try commodityTradeFileTree(container)
    try FileManager.default.moveItem(at: container, to: backup)
    try Data("blocked save directory".utf8).write(to: container)
    await runtime.key("right")
    let refused = await runtime.snapshot()
    #expect(refused.message == "MISSION SAVE FAILED - ACTION NOT COMMITTED")
    #expect(refused.commander == before.commander && refused.market == before.market)
    #expect(refused.bodies == before.bodies && refused.jumpCountdown == before.jumpCountdown)
    #expect(refused.commander.scriptState.firstNativeCommodityTrade == nil)
    let backupFiles = try commodityTradeFileTree(backup)
    let missingFiles = files.keys.filter { backupFiles[$0] == nil }.sorted()
    let unexpectedFiles = backupFiles.keys.filter { files[$0] == nil }.sorted()
    let changedFiles = files.keys.sorted().compactMap { key -> String? in
      guard let expected = files[key], let actual = backupFiles[key], expected != actual else { return nil }
      return "\(key): \(ScriptPackLibrary.hash(expected)) -> \(ScriptPackLibrary.hash(actual))"
    }
    #expect(backupFiles == files,
      "Missing backup files (\(missingFiles.count)): \(Array(missingFiles.prefix(16)).map { String($0.prefix(256)) }); unexpected (\(unexpectedFiles.count)): \(Array(unexpectedFiles.prefix(16)).map { String($0.prefix(256)) }); changed SHA256 (\(changedFiles.count)): \(Array(changedFiles.prefix(16)).map { String($0.prefix(512)) })")
    #expect(try Data(contentsOf: container) == Data("blocked save directory".utf8))
    try FileManager.default.removeItem(at: container)
    try FileManager.default.moveItem(at: backup, to: container)
    await runtime.key("right")
    let committed = await runtime.snapshot()
    let receipt = try #require(committed.commander.scriptState.firstNativeCommodityTrade)
    #expect(receipt.valid && receipt.side == .buy && receipt.quantity == 1)
    #expect(committed.commander.cargo[index] == before.commander.cargo[index] + 1)
    #expect(committed.market[index].quantity == before.market[index].quantity - 1)
    #expect(committed.commander.scriptState.firstNativeCommoditySale == nil)
    let bytes = try Data(contentsOf: url)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    #expect(pointer.schemaVersion == 141)
    let (stored, _) = try ScriptSaveStore.read(bytes, from: url)
    #expect(stored == committed.commander)
    #expect(stored.scriptState.firstNativeCommodityTrade == receipt)
    #expect(NativeAssemblyOfOrbitsTrade.current(in: stored) == receipt)
    let reloaded = GameRuntime(game: Game(executive: false))
    try await reloaded.load(from: url)
    let restored = await reloaded.snapshot()
    #expect(restored.commander == stored)
    #expect(restored.commander.scriptState.firstNativeCommodityTrade?.operation == receipt.operation)
    let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
    let missionsURL = generation.appendingPathComponent("missions.json")
    let missions = try Data(contentsOf: missionsURL)
    var rootObject = try #require(JSONSerialization.jsonObject(with: missions) as? [String: Any])
    var badReceipt = try #require(rootObject[NativeFirstCommodityTradeSave.field] as? [String: Any])
    badReceipt["unitPrice"] = receipt.unitPrice + 1
    rootObject[NativeFirstCommodityTradeSave.field] = badReceipt
    let corrupted = try JSONSerialization.data(withJSONObject: rootObject)
    var pointerObject = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    var hashes = try #require(pointerObject["hashes"] as? [String: String])
    hashes["missions.json"] = ScriptPackLibrary.hash(corrupted)
    pointerObject["hashes"] = hashes
    try corrupted.write(to: missionsURL)
    try JSONSerialization.data(withJSONObject: pointerObject).write(to: url)
    let corruptFiles = try commodityTradeFileTree(container)
    let preRefusal = await reloaded.snapshot()
    // Update the actual typed chunk hash too, so refusal reaches native receipt validation.
    #expect(throws: (any Error).self) {
      try ScriptSaveStore.read(Data(contentsOf: url), from: url)
    }
    do {
      try await reloaded.load(from: url)
      Issue.record("A forged price in the current typed generation must refuse")
    } catch {}
    let postRefusal = await reloaded.snapshot()
    #expect(postRefusal.commander == preRefusal.commander && postRefusal.bodies == preRefusal.bodies)
    #expect(try commodityTradeFileTree(container) == corruptFiles)
    try missions.write(to: missionsURL)
    try bytes.write(to: url)
    #expect(try ScriptSaveStore.read(Data(contentsOf: url), from: url).0 == stored)
    try await reloaded.load(from: url)
    // A later real sale keeps both histories, without minting another first trade.
    await runtime.key("left")
    let sold = await runtime.snapshot()
    #expect(sold.commander.scriptState.firstNativeCommodityTrade == receipt)
    #expect(sold.commander.scriptState.firstNativeCommoditySale != nil)
    let (soldStored, _) = try ScriptSaveStore.read(Data(contentsOf: url), from: url)
    #expect(soldStored == sold.commander && soldStored.scriptState.firstNativeCommodityTrade == receipt)
  }
}
