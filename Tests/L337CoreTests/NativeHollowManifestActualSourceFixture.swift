import Foundation
import Testing

@testable import L337Core

/// Controlled location/cargo setup is NOT a flown route. Bootstrap, native launch/entry, ordinary
/// sale, explicit confirmation and writer calls below use the real runtime. All remain UNRUN.
final class HollowManifestCommissionFixture {
  let files: ScriptFreightFixture
  let runtime: GameRuntime

  init(sale: Bool = true) async throws {
    let storage = try ScriptFreightFixture()
    files = storage
    var ready = false
    defer { if !ready { storage.clean() } }
    try FileManager.default.createDirectory(
      at: files.save.deletingLastPathComponent(), withIntermediateDirectories: true)
    let boot = GameRuntime(game: Game(executive: false))
    try await boot.startNewCommander()
    _ = try await boot.registerNewCommanderDestination(at: files.save)
    let born = await boot.snapshot()
    try #require(born.nativeMainStationDockEvidenceIsCurrent)
    await boot.nativeCommand { $0.screen = .status }
    await boot.key("0")
    var game = await boot.snapshot()
    try #require(!game.docked, Comment(rawValue: game.message))
    try #require(game.commander.nativeStations?.currentMainDock == nil)
    try game.departOrdinarySimulation()
    // Set a controlled remote scene, then obtain a NEW receipt through actual swept entry.
    // Neither these coordinates nor the old born berth supplies Narargan contact authority.
    game.commander.galaxy = 1
    game.commander.system = 120
    game.selectedSystem = 120
    game.systems = Universe.systemsIncludingPlugh(number: 1)
    game.commander.cargo[13] = 1
    game.scriptPacks = [
      try ScriptPackLibrary.read(ScriptPackLibrary.bundledHollowManifestDirectory)
    ]
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    let station = try #require(game.bodies.first { $0.id == 0 })
    let previous = game.commander.flightSimulation.pose
    var pose = ShipPose()
    pose.position = previous.systemPoint(station.entrancePosition + station.entranceNormal * 2)
    pose.orientation.y = previous.orientation.apply(station.entranceUp)
    pose.orientation.z = previous.orientation.apply(station.entranceNormal) * -1
    pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
    NativeStationTestFixture.reframe(&game, to: pose)
    game.speed = 3
    runtime = GameRuntime(game: game, saveURL: files.save)
    for _ in 0..<100 {
      if await runtime.snapshot().docked { break }
      _ = await runtime.advance(delta: 0.05)
    }
    let arrived = await runtime.snapshot()
    try #require(arrived.docked && arrived.nativeMainStationDockEvidenceIsCurrent)
    try #require(arrived.systemIdentity == NativeHollowManifestDefinition.issuer)
    if sale {
      await runtime.nativeCommand { candidate in
        candidate.screen = .sell
        candidate.selection = 13
      }
      await runtime.key("left")
      let traded = await runtime.snapshot()
      try #require(traded.commander.scriptState.firstNativeCommoditySale != nil)
      try #require(NativeFirstCommoditySaleSave.validateClaims(traded.commander))
    }
    try await runtime.save(to: files.save)
    ready = true
  }
  func clean() { files.clean() }
  func review() async throws -> Game {
    await runtime.nativeCommand { game in
      game.openContractBoard()
      if let index = game.contractBoard.rows.firstIndex(where: { $0.hollowManifest == .accept }) {
        game.contractBoard.selection = index
      }
    }
    let board = await runtime.snapshot()
    try #require(board.contractBoard.selected?.hollowManifest == .accept)
    await runtime.key("return")
    let detail = await runtime.snapshot()
    try #require(detail.contractBoard.detail && detail.contractBoard.action == .back)
    try #require(detail.contractBoard.hollowManifestQuote?.allowed == true)
    return detail
  }
  func selectConfirm() async { await runtime.key("right") }
}

/// Shared ACTUAL commission/admission setup. The remote location is controlled test data,
/// not a flown journey; no Birth/State, installed pin, life gate or receipt is injected.
func actualHollowManifestFreighterRootFixture(targeting: TargetingTier? = nil) async throws -> (
  game: Game, commission: HollowManifestCommissionFixture
) {
  let commission = try await HollowManifestCommissionFixture()
  do {
    if let targeting {
      try #require(targeting == .basic)  // This bounded fixture buys one existing Basic item only.
      let station = await commission.runtime.snapshot()
      let index = try #require(Equipment.all.firstIndex { $0.name == targeting.equipmentName })
      let item = Equipment.all[index]
      try #require(station.nativeMainStationDockEvidenceIsCurrent)
      try #require(station.systemIdentity == NativeHollowManifestDefinition.issuer)
      try #require(station.stationAllowsEquipmentServices && station.equipmentAvailable(item))
      try #require(station.commander.fittedEquipment(at: .targetingCore) == nil)
      let price = station.shopPrice(item)
      let count = try #require(station.commander.equipmentPurchaseHistory?.paid.count)
      try #require(price > 0)
      try await commission.runtime.scriptCommand { candidate in
        try #require(candidate.commander == station.commander)
        // Labelled test budget, not earned progress or a fresh-commander playability claim.
        candidate.commander.credits += price
        candidate.screen = .equipment
        candidate.selection = index
      }
      let funded = await commission.runtime.snapshot()
      let context = try #require(funded.equipmentPurchaseContext)
      let result = await commission.runtime.equipmentTransaction(.purchase(context))
      try #require(result.applied)
      let bought = await commission.runtime.snapshot()
      let fitted = try #require(bought.commander.fittedEquipment(at: .targetingCore))
      let history = try #require(bought.commander.equipmentPurchaseHistory)
      let paid = try #require(history.paid.last)
      try #require(bought.commander.credits == funded.commander.credits - price)
      try #require(history.paid.count == count + 1 && paid.price == price)
      try #require(fitted.node.key == targeting.equipmentName)
      try #require(fitted.location?.hullInstanceID == bought.commander.hullInstanceID)
      try #require(paid.binding.request.newItem == fitted.id && paid.node == fitted.node)
      try #require(fitted.provenance == .paid(owner: history.owner, transaction: paid.transaction))
    }
    _ = try await commission.review()
    await commission.selectConfirm()
    await commission.runtime.key("return")
    var game = await commission.runtime.snapshot()
    let issued = try #require(game.hollowManifestMission?.savedHollowManifest)
    try #require(issued.phase == .unadmitted && issued.birth.originals.count == 2)
    game.launch()
    try #require(!game.docked, Comment(rawValue: game.message))
    try game.departOrdinarySimulation()
    let world = NativeHollowManifestDefinition.freighterWorld
    game.commander.galaxy = world.galaxy
    game.commander.system = world.system
    game.selectedSystem = world.system
    game.systems = Universe.systemsIncludingPlugh(number: world.galaxy)
    game.speed = 0
    game.bodies = [.init(id: 0, hull: .station, position: .init(0, 0, 16000))]
    game.commander.nativeStations?.currentMainDock = nil
    game.nativeMainStationDockEvidence = nil
    game.resetCelestialFlight()
    let beganVisit = game.beginGameplayVisit(arriving: true)
    try #require(beganVisit)
    game.applyScriptStationResources()
    try game.registerOriginalNativeMainStation()
    try game.restoreScriptActors()
    let pin = try game.hollowManifestInstalledCase()
    try #require(pin.state.phase == .admitted && pin.state.latestAdmissions.count == 2)
    try #require(pin.state.birth == issued.birth && pin.state.terminals.isEmpty)
    for slot in NativeHollowManifestState.Slot.allCases {
      let life = try game.hollowManifestOriginalLife(slot: slot)
      let bound = try #require(game.c03CurrentOriginalBinding(pin, slot: slot))
      let actual = try #require(game.bodies.first { $0.id == bound.owned.body.id })
      try #require(life.mode == .retainedCondition && life.admission == bound.admission)
      try #require(actual.missionActorID == bound.owned.identity)
      try #require(actual.physical?.identity == bound.admission.original.actor)
      try #require(actual.physical?.spawnIdentity == bound.admission.spawn)
      try #require(game.acceptsHollowManifestOriginalLife(life))
    }
    return (game, commission)
  } catch {
    commission.clean()
    throw error
  }
}

/// Controlled camera only. Actual current life, native body and complete nearest mesh contact
/// remain mandatory; this shared test helper mints no origin, proof, source or life authority.
func aimAtActualHollowManifestSeal(_ game: inout Game, slot: NativeHollowManifestState.Slot) throws
  -> Int
{
  let life = try game.hollowManifestOriginalLife(slot: slot)
  let admission = try #require(life.admission)
  let body = try #require(game.bodies.first { $0.missionActorID == admission.logicalActor })
  try #require(game.acceptsHollowManifestOriginalLife(life))
  let previous = game.commander.flightSimulation.pose
  let centre = body.position + body.modelVector(
    NativeC03SealGeometry.componentPosition
      + NativeC03SealGeometry.componentOrientation.apply(.init(0, 0, 0.03)))
  let normal = body.modelVector(NativeC03SealGeometry.componentOrientation.z)
  var pose = ShipPose(position: previous.systemPoint(centre + normal * 300))
  pose.orientation.z = previous.orientation.apply(normal * -1)
  pose.orientation.y = previous.orientation.apply(
    body.modelVector(NativeC03SealGeometry.componentOrientation.y))
  pose.orientation.x = pose.orientation.y.cross(pose.orientation.z)
  NativeStationTestFixture.reframe(&game, to: pose)
  game.rotateScriptNPCVelocities(from: previous, to: pose)
  game.screen = .front
  let contact = try #require(
    try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000,
      radius: 0, includePlayer: false))
  try #require(contact.hit.target == .body(body.id))
  try #require(contact.victimPart == slot.rawValue)
  try #require(contact.componentUUID == admission.original.component)
  return body.id
}
