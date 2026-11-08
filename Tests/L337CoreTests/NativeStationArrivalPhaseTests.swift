import Foundation
import Testing

@testable import L337Core

@Test func nativeArrivalTickKeepsRotatingStationsOnPhysicalClockAndPublishes() throws {
  var game = Game(executive: false)
  game.commander.galaxy = 0
  game.systems = Universe.systemsIncludingPlugh(number: game.commander.galaxy)
  let destination = 7  // Avenor has the three adopted original dispatch sites.
  let identity = SystemIdentity(galaxy: game.commander.galaxy, system: destination)
  let sources = NativeStationSource.bindings.filter { $0.system == identity }
  try #require(Set(sources.map(\.site)) == Set([
    OriginalStationSite.salamander, .frog, .dhole,
  ]))
  try game.commander.prepareEquipment(legacy: false)
  let target = game.systems[destination]
  let reach = game.commander.maximumJumpDistance
  let origin = try #require(
    game.systems.first {
      $0.id != destination && $0.government >= 5 && $0.distance(to: target) <= reach
    })
  game.commander.system = origin.id
  game.selectedSystem = origin.id
  game.market = MarketItem.at(game.currentSystem)
  game.screen = .status
  game.launch()
  let launched = !game.docked && !game.paused && game.screen.isFlight && game.commander.valid
  try #require(launched)
  var controls = Controls()
  controls.throttle = 1
  var departure = 0
  while game.hyperspaceMassLocked && departure < 300 {
    game.tick(delta: 0.1, controls: controls)
    departure += 1
  }
  let ready = departure < 300 && !game.hyperspaceMassLocked && game.energy > 0 && !game.paused
  try #require(ready)
  let fuel = game.commander.fuel
  game.selectedSystem = destination
  game.key("h")
  let journey = try #require(game.commander.scriptState.calendarLedger?.pendingJourney)
  try #require(journey.origin == origin.id && journey.destination == destination)
  var steps = 0
  while game.jumpCountdown != nil && steps < 500 {
    game.tick(delta: 0.1, controls: Controls())
    steps += 1
  }
  let arrived =
    steps > 0 && steps < 500 && game.commander.system == destination
    && !game.docked && !game.paused && game.energy > 0
  try #require(arrived)
  // This is the actual post-jump id-1 cohort, bound before station admission.
  try requireNativeLaunchFleetAndStationPopulation(
    game, expectedRole: game.currentSystem.government < 4 ? .pirate : .trader)
  #expect(game.commander.fuel == fuel - journey.nativeFuelDebit)
  let world = try #require(game.commander.nativeStations)
  let owner = try #require(game.commander.equipmentOwnerID)
  var stations: [SpaceBody] = []
  for source in sources {
    let station = try #require(game.bodies.first {
      $0.nativeStationIdentity == source.identity(world: owner)
    })
    #expect(world.bodyRigidPoseIsConsistent(station, flight: game.commander.flightSimulation))
    #expect(station.rotationRate == source.rotationRate && station.rotationRate == 0)
    stations.append(station)
  }
  let main = try #require(game.bodies.first { $0.id == 0 && $0.hull == .station })
  #expect(abs(main.rotation - 0.1 * main.rotationRate) < 1e-12)
  let sceneMatches = game.scriptWorldSave.consistent(with: game.commander)
  #expect(sceneMatches)
  let storage = try NativeStationTestStorage()
  defer { storage.clean() }
  let prepared = try GameRuntime.prepareNativeSaveState(game)
  _ = try ScriptSaveStore.write(
    commander: prepared.commander, world: prepared.game.scriptWorldSave, to: storage.url)
  let bytes = try Data(contentsOf: storage.url)
  let (cold, scene) = try ScriptSaveStore.read(bytes, from: storage.url)
  let retainedSceneMatches = scene.consistent(with: cold)
  #expect(retainedSceneMatches && cold.system == destination)
  // Actual source pose validation still rejects a changed station phase; no tolerance is relaxed.
  var changed = game.scriptWorldSave
  let station = try #require(stations.first)
  let index = try #require(changed.bodies.firstIndex { $0.id == station.id })
  changed.bodies[index].rotation += 0.01
  let changedSceneMatches = changed.consistent(with: game.commander)
  #expect(!changedSceneMatches)
}
