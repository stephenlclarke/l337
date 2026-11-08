import Foundation
import Testing

@testable import L337Core

@Test func currentMountSavesPreserveOwnedLasersWithoutInventingSideWeapons()
  async throws
{
  var game = try missionGearGame()
  let pulse = try #require(game.commander.fittedEquipment(at: .laser(.front)))
  try game.commander.grantEquipment(
    "Military Laser", at: .laser(.front), provenance: .grant("mount save fixture"))
  try game.commander.grantEquipment(
    "Fuel Scoops", at: .utility(.fuelScoops), provenance: .grant("mount save fixture"))
  #expect(game.commander.equipment == ["Military Laser", "Fuel Scoops", HyperspaceDriveTier.basic.label])
  let drive = try #require(game.commander.fittedEquipment(at: .drive))
  #expect(drive.node == HyperspaceDriveDefinition.node(for: .basic))
  #expect(drive.provenance == .standard)
  #expect(drive.component?.origin == HyperspaceDriveDefinition.template(for: .basic))
  #expect(game.commander.equipmentInventory?.items.filter { $0.location?.slot == .drive }.count == 1)
  let current = try #require(game.commander.equipmentInventory)
  let oldPulse = try #require(current.items.first { $0.id == pulse.id })
  #expect(oldPulse == pulse.moved(to: nil) && oldPulse.provenance == .standard)
  #expect([LaserMount.left, .right, .rear].allSatisfy { game.commander.laser(on: $0) == nil })
  try game.commander.grantEquipment(
    "Beam Laser", at: .laser(.rear), provenance: .grant("mount save fixture"))
  try game.commander.grantEquipment(
    "Mining Laser", at: .laser(.front), provenance: .grant("mount save fixture"))
  let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  let url = directory.appendingPathComponent("commander.json")
  defer { try? FileManager.default.removeItem(at: directory) }
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: url)
  let saved = await runtime.snapshot()
  let bytes = try Data(contentsOf: url)
  try await runtime.load(from: url)
  let restored = await runtime.snapshot()
  let reloadedBytes = try Data(contentsOf: url)
  #expect(restored.commander == saved.commander && reloadedBytes == bytes)
  #expect(restored.commander.laserMounts == game.commander.laserMounts)
  #expect(restored.commander.fittedEquipment(at: .drive) == drive)
  #expect(restored.commander.equipmentInventory == game.commander.equipmentInventory)
  #expect(restored.commander.equipmentPurchaseHistory == game.commander.equipmentPurchaseHistory)
  #expect(restored.commander.equipmentInventory?.items.contains(oldPulse) == true)
  #expect(game.commander.laser(on: .rear) == .beam && game.commander.laser(on: .front) == .mining)
  #expect(game.commander.laser(on: .right) == nil)
  let encoded = try JSONEncoder().encode(game.commander)
  let object = try JSONSerialization.jsonObject(with: encoded)
  var corrupt = try #require(object as? [String: Any])
  corrupt["mountedLasers"] = ["front": "invalid"]
  #expect(throws: DecodingError.self) {
    try JSONDecoder().decode(Commander.self, from: JSONSerialization.data(withJSONObject: corrupt))
  }
}
