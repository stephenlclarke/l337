import Foundation
import Testing

@testable import L337Core

struct ScriptNPCPlayerSurfaceAimTests {
  @Test func originalPlayerSurfaceAimReachesTheHullWhereItsFullRangeOriginRayMisses() throws {
    let commander = Commander()
    try #require(commander.shipID == "SH025")
    let mesh = commander.playerMesh
    let muzzle = Vector3(0, 0, 150)
    let range = 6000.0
    let centerHit = GameplayRaycast.nearest(
      origin: muzzle, direction: (muzzle * -1).unit, maxDistance: range,
      bodies: [], playerMesh: mesh)
    #expect(centerHit == nil)

    let surface = Game.nativePlayerSurfaceAim(from: muzzle, mesh: mesh)
    let actual = GameplayRaycast.nearest(
      origin: muzzle, direction: (surface - muzzle).unit, maxDistance: range,
      bodies: [], playerMesh: mesh)
    let hit = try #require(actual)
    #expect(hit.target == .player)
    #expect(hit.distance > 0 && hit.distance <= range && hit.point.finite)
  }
}
