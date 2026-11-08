import Testing

@testable import L337Core

// Pure geometry exercises the real original port. It creates no arrival or docking receipt.
private func originalEntranceStation(depth: Double, x: Double = 0, y: Double = 0) throws
  -> SpaceBody
{
  let record = try #require(ShipCatalogue.ship("SH028"))
  let port = try #require(record.nativeDocking)
  try #require(record.name == "Lion Citadel" && port.valid)
  var station = SpaceBody(id: 0, hull: .station, position: .init(0, 0, 0))
  station.rotation = 0
  station.rotationRate = 0
  station.orientation.x = .init(-1, 0, 0)
  station.orientation.y = .init(0, 1, 0)
  station.orientation.z = .init(0, 0, -1)
  try #require(station.orientation.validRotation)
  let player = port.center + port.outward * depth + .init(x, y, 0)
  station.position = station.orientation.apply(player) * -1
  return station
}

@Test func originalEntranceGateWaitsForTheActualInteriorPlane() throws {
  for depth in [1.0, 0.5, 0.0] {
    let station = try originalEntranceStation(depth: depth)
    #expect(!station.containsPlayer)
    #expect(station.canEnter(roll: 0, speed: 48))
  }
  for depth in [-0.5, -1.0, -24.0] {
    let station = try originalEntranceStation(depth: depth)
    #expect(station.containsPlayer)
    #expect(station.canEnter(roll: 0, speed: 48))
  }
  let inside = try originalEntranceStation(depth: -0.5)
  // The real doorway lies beyond the obsolete station-centred90m gate.
  #expect(inside.position.length > 90)
}

@Test func originalEntranceGateKeepsItsStrictTransverseAndInteriorBounds() throws {
  for coordinate in [-90.0, 90.0] {
    #expect(!(try originalEntranceStation(depth: -0.5, x: coordinate)).containsPlayer)
    #expect(!(try originalEntranceStation(depth: -0.5, y: coordinate)).containsPlayer)
  }
  for coordinate in [-89.0, 89.0] {
    #expect((try originalEntranceStation(depth: -0.5, x: coordinate)).containsPlayer)
    #expect((try originalEntranceStation(depth: -0.5, y: coordinate)).containsPlayer)
  }
  #expect(!(try originalEntranceStation(depth: -90)).containsPlayer)
  #expect((try originalEntranceStation(depth: -89)).containsPlayer)
}

@Test func originalEntranceGateDoesNotReplaceTheExistingEntryRefusals() throws {
  let exterior = try originalEntranceStation(depth: 0.5)
  #expect(!exterior.containsPlayer && exterior.canEnter(roll: 0, speed: 48))
  let tooFarOutside = try originalEntranceStation(depth: 2)
  #expect(!tooFarOutside.containsPlayer && !tooFarOutside.canEnter(roll: 0, speed: 48))
  let tooDeep = try originalEntranceStation(depth: -25)
  #expect(tooDeep.containsPlayer && !tooDeep.canEnter(roll: 0, speed: 48))
  for (x, y) in [(25.0, 0.0), (0.0, 8.0)] {
    let wall = try originalEntranceStation(depth: -0.5, x: x, y: y)
    #expect(wall.containsPlayer && !wall.canEnter(roll: 0, speed: 48))
  }
  let inside = try originalEntranceStation(depth: -0.5)
  #expect(inside.containsPlayer && !inside.canEnter(roll: 0, speed: 144))
  #expect(inside.containsPlayer && !inside.canEnter(roll: 0.2, speed: 48))
}
