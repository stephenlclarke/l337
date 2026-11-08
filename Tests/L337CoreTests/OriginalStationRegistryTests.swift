import Foundation
import Testing

@testable import L337Core

struct OriginalStationRegistryTests {
  @Test(arguments: [0, 7, 237])
  func actualOriginalWorldLaunchUsesTheCompleteInstalledStationInventory(system: Int) throws {
    var game = Game(executive: false)
    game.screen = .status
    game.commander.system = system
    game.selectedSystem = system
    try game.commander.prepareEquipment(legacy: false)
    try #require(game.commander.valid)
    game.launch()
    try #require(!game.docked, Comment(rawValue: game.message))
    #expect(game.commander.valid && game.screen == .front)
    let world = try #require(game.commander.nativeStations)
    let sources = try NativeStationSource.requireBindings()
    let sites: [OriginalStationSite] = [.salamander, .frog, .dhole, .remoteUtility]
    let expected = Set(sites.map { $0.identity(world: world.ledger.world) })
    #expect(Set(sources.map(\.site)) == Set(sites) && sources.count == sites.count)
    #expect(Set(world.ledger.records.map(\.identity)) == expected)
    #expect(Set(world.poses.map(\.station)) == expected)
    #expect(world.ledger.records.count == expected.count && world.poses.count == expected.count)
    #expect(game.commander.equipmentOwnerID == world.ledger.world)
    let currentSites: [OriginalStationSite] = system == 7
      ? [.salamander, .frog, .dhole] : system == 237 ? [.remoteUtility] : []
    let currentExpected = Set(currentSites.map { $0.identity(world: world.ledger.world) })
    let actual = game.bodies.filter { $0.nativeStationIdentity != nil }
    #expect(actual.count == currentExpected.count)
    #expect(Set(actual.compactMap(\.nativeStationIdentity)) == currentExpected)
    #expect(actual.allSatisfy { game.nativeStationBodyIsCurrent($0) })
    let main = try #require(game.bodies.first { $0.id == 0 })
    #expect(main.nativeStationIdentity == nil && main.hull == .station)
    #expect(main.physical?.identity == game.commander.flightSimulation.anchors?.station.identity)
    #expect(world.ledger.currentDock == nil && world.currentMainDock == nil)
    let remote = OriginalStationSite.remoteUtility.identity(world: world.ledger.world)
    let utility = try #require(world.ledger.records.first { $0.identity == remote })
    #expect((utility.utilitySourceBirth != nil) == (system == 237))
    #expect(world.ledger.records.count <= NativeStationLedger.maximumSourceRecords)
    #expect(
      world.ledger.records.allSatisfy {
        NativeStationSource.authentic($0, owner: world.ledger.world)
      })
    let restored = try JSONDecoder().decode(
      NativeStationWorld.self,
      from: JSONEncoder().encode(world))
    #expect(restored == world && restored.valid)
  }

  @Test(arguments: ["missing", "duplicate"])
  func installedSourceInventoryCannotBeDroppedOrDuplicatedByACurrentSave(condition: String) throws {
    let world = try NativeStationWorld(owner: UUID())
    var root = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(world))
        as? [String: Any])
    var ledger = try #require(root["ledger"] as? [String: Any])
    var records = try #require(ledger["records"] as? [[String: Any]])
    if condition == "missing" {
      records.removeLast()
    } else {
      records[records.count - 1] = records[0]
    }
    ledger["records"] = records
    root["ledger"] = ledger
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        NativeStationWorld.self,
        from: JSONSerialization.data(withJSONObject: root))
    }
  }
}
