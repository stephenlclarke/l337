import Testing

@testable import L337Core

// Projection fixtures reference actual current meshes. Actor admission,
// occupied physics and gameplay qualification have separate source owners.
typealias RendererMeshSource = (hull: Hull, catalogueShipID: String?, mesh: Mesh)

func currentRendererMeshSources() throws -> [RendererMeshSource] {
  try #require(Set(ShipCatalogue.all.compactMap(\.nativeHull)) == Set([Hull.viper, .station]))
  let named = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
  try #require(named.ship.name == "Peregrine Mk V" && named.ship.nativeHull == nil)
  return [
    (.cobra, named.ship.id, named.mesh),
    (.viper, nil, Mesh.hull(.viper)), (.station, nil, Mesh.hull(.station)),
    (.asteroid, nil, Mesh.hull(.asteroid)), (.cargo, nil, Mesh.hull(.cargo)),
    (.missile, nil, Mesh.hull(.missile)),
  ]
}

func currentRendererSourceGame() throws -> Game {
  var game = Game(executive: false)
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.launch()
  try #require(!game.docked)
  game.screen = .front
  return game
}

func currentRendererSourceBody(
  _ source: RendererMeshSource, game: inout Game, minimumDistance: Double, rotation: Double
) throws -> SpaceBody {
  let radius = try #require(source.mesh.vertices.map(\.length).max())
  try #require(radius.isFinite && radius > 0)
  let id = game.nextBodyID
  game.nextBodyID += 1
  var body = SpaceBody(
    id: id, hull: source.hull, position: .init(0, 0, max(minimumDistance, radius * 4)))
  body.rotation = rotation
  if let catalogue = source.catalogueShipID {
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    body.physical = .init(identity: actor, population: .civilian, catalogueShipID: catalogue)
    let resolved = game.gameplayMesh(for: body)
    #expect(resolved.vertices == source.mesh.vertices && resolved.faces == source.mesh.faces)
    #expect(resolved.materials == source.mesh.materials && resolved.faceTextures == source.mesh.faceTextures)
  }
  return body
}
