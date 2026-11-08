import Foundation
import Testing

@testable import L337Core

func empUnitFailureContext(_ game: Game, phase: String) -> Comment {
  let diagnostic = ScriptRefusalDiagnostic()
  _ = game.scriptWorldSave.consistent(with: game.commander, diagnostics: diagnostic)
  let missing = game.commander.nativeCrewMissing.map { String($0) } ?? "nil"
  let actualStations = game.bodies.filter { $0.nativeStationIdentity != nil }.count
  let expectedStations = game.commander.nativeStations?.ledger.records.filter {
    $0.identity.system == game.systemIdentity && $0.tombstone == nil
  }.count ?? 0
  return Comment(rawValue: "EMP unit phase=\(phase) docked=\(game.docked) paused=\(game.paused)"
    + " screen=\(game.screen) valid=\(game.commander.valid) crewMissing=\(missing)"
    + " peopleValid=\(game.commander.nativePeopleStateValid)"
    + " stations=\(actualStations)/\(expectedStations) message=\(game.message.prefix(160)) "
    + (diagnostic.detail() ?? "scene=current")
    + " endpointRefusal=\(game.nativeEncounterBirthDiagnostic?.endpointRefusal ?? "not-observed")")
}

/// Prepare one fresh controlled unit scene without discarding current station custody.
func prepareEMPUnitScene(_ game: inout Game) throws {
  try requireLaunchedEMPUnitScene(game)
  try prepareValidatedEMPUnitScene(&game)
}

@inline(never)
private func requireLaunchedEMPUnitScene(_ game: Game) throws {
  let launched = !game.docked && !game.paused && game.screen.isFlight && game.commander.valid
  try #require(launched, launched ? nil : empUnitFailureContext(game, phase: "launch"))
  try #require(game.commander.savedEMPState == nil)
}

@inline(never)
private func prepareValidatedEMPUnitScene(_ game: inout Game) throws {
  let anchors = try #require(game.commander.flightSimulation.anchors)
  let scalar = game.scriptSimulationSave.randomState
  let counter = game.missionLoopCounter
  let time = game.commander.flightSimulation.physicalTime
  let stations = game.bodies.filter { $0.hull == .station || $0.nativeStationIdentity != nil }
  let poses = stations.map { game.modelPose(of: $0) }
  // The existing arrival anchor supplies the observer location. All retained source
  // actors keep their actual world poses, identities, resources and station bindings.
  let observer = ShipPose(
    position: anchors.arrival, orientation: game.commander.flightSimulation.pose.orientation)
  NativePagedSalvageFixture.moveObserver(&game, to: observer)
  game.bodies.removeAll { $0.hull != .station && $0.nativeStationIdentity == nil }
  game.speed = 0
  game.miningFields = []
  game.salvageSites = []
  game.commander.npcPersistence = .init()
  for (old, pose) in zip(stations, poses) {
    let bodyCandidate = game.bodies.first { $0.id == old.id }
    let body = try #require(bodyCandidate)
    let current = game.modelPose(of: body)
    try #require(body.physical == old.physical)
    try #require(body.nativeStationIdentity == old.nativeStationIdentity)
    try #require((current.position - pose.position).length < 1e-7)
    try #require((current.orientation.x - pose.orientation.x).length < 1e-8)
    try #require((current.orientation.y - pose.orientation.y).length < 1e-8)
    try #require((current.orientation.z - pose.orientation.z).length < 1e-8)
  }
  try #require(game.scriptSimulationSave.randomState == scalar)
  try #require(game.missionLoopCounter == counter)
  try #require(game.commander.flightSimulation.physicalTime == time)
  let consistent = game.scriptWorldSave.consistent(with: game.commander)
  try #require(consistent, consistent ? nil : empUnitFailureContext(game, phase: "unit-scene"))
}

func requireEMPUnitBasicElectricalSource(_ game: Game) throws {
  try #require(game.commander.shipID == NewCommanderDefaults.shipID)
  try #require(game.commander.shipID == "SH025")
  let source = try #require(OriginalFleetR3Data.contract(for: game.commander.shipID))
  let native = try #require(source.performance)
  let energy = try #require(game.commander.fittedComponent(at: .energy))
  try #require(energy.grade == EquipmentModuleTemplates.energy.grades[0].identity)
  try #require(energy.statistics[.energyRecharge] == 1)
  try #require(game.commander.energyRechargeMultiplier == 1)
  try #require(native.recharge == 4.2)
  try #require(game.commander.nativePerformance.recharge == native.recharge)
  try #require(game.commander.performance.recharge == native.recharge)
  try #require(
    game.commander.performance.recharge * game.commander.energyRechargeMultiplier
      == native.recharge)
}

/// Unit slices use the real tick/post/writer owners; native acceptance uses GameRuntime below.
struct EMPUnitWriter {
  let folder: URL
  let file: URL
  init() throws {
    folder = try NativeStationTestStorage().root
    file = folder.appendingPathComponent("commander.json")
  }
  var publish: ScriptPublisher {
    let destination = file
    return { candidate in try GameRuntime.writeCommander(&candidate, to: destination) }
  }
  func clean() { try? FileManager.default.removeItem(at: folder) }
}

func withEMPUnitWriter<T>(
  _ game: inout Game, _ action: (inout Game, ScriptPublisher?, URL) throws -> T
) throws -> T {
  let writer = try EMPUnitWriter()
  defer { writer.clean() }
  var phase = "current-policy"
  do {
    try NativeSaveTestFixture.prepareCurrentPolicy(&game)
    phase = "initial-publication"
    try writer.publish(&game)
  } catch {
    Issue.record(empUnitFailureContext(game, phase: phase))
    throw error
  }
  return try action(&game, writer.publish, writer.file)
}

func empUnitAim(_ game: Game, actor: ActorIdentity? = nil, fire: Bool = false) -> Controls {
  var controls = Controls()
  controls.fire = fire
  guard let body = actor.flatMap({ id in game.bodies.first { $0.physical?.identity == id } })
    ?? game.bodies.first else { return controls }
  controls.yaw = max(-1, min(1, atan2(body.position.x, body.position.z)
    / max(0.001, game.commander.performance.yaw * 0.1)))
  controls.pitch = max(-1, min(1, atan2(body.position.y, hypot(body.position.x, body.position.z))
    / max(0.001, game.commander.performance.pitch * 0.1)))
  return controls
}

@discardableResult
@inline(never)
func empUnitFrame(
  _ game: inout Game, delta: Double = 0.1, controls: Controls = Controls(),
  publish: ScriptPublisher?, finish: Bool = true
) throws -> Double {
  let start = game.storedFlightSimulation().physicalTime
  let accepted = min(delta, 0.1)
  game.tick(delta: delta, controls: controls, nativeSalvagePublish: publish)
  try finishAttainedEMPUnitFrame(&game, start: start, accepted: accepted, publish: publish, finish: finish)
  return accepted
}

@inline(never)
private func finishAttainedEMPUnitFrame(
  _ game: inout Game, start: Double, accepted: Double, publish: ScriptPublisher?, finish: Bool
) throws {
  let alive = !game.docked && !game.paused && game.screen != .gameOver
  try #require(alive, alive ? nil : empUnitFailureContext(game, phase: "frame"))
  try #require(game.commander.flightSimulation.physicalTime == start + accepted)
  if let interval = game.empPlayerElectricalInterval { #expect(interval.acceptedDelta == accepted) }
  if finish { game.finishEMPPlayerElectricalInterval(publish: publish) }
}

func openEMPUnitHeader(_ game: inout Game, publish: ScriptPublisher?) throws {
  let publish = try #require(publish)
  if game.postedEMPPlayerElectrical() != nil { return }
  game.finishEMPPlayerElectricalInterval(publish: publish)
  try empUnitFrame(&game, controls: empUnitAim(game), publish: publish, finish: false)
  try #require(game.postedEMPPlayerElectrical() != nil)
}

func earnEMPUnitBank(_ game: inout Game, publish: ScriptPublisher?, file: URL) throws {
  let publish = try #require(publish)
  let item = try #require(game.currentEMPPlayerModule())
  let history = game.commander.equipmentPurchaseHistory
  for _ in 0..<256 {
    if game.currentEMPPlayerModule()?.empBank?.remaining == 8 { break }
    try empUnitFrame(&game, controls: empUnitAim(game), publish: publish)
  }
  let ready = try #require(game.currentEMPPlayerModule())
  try #require(ready.empBank?.remaining == 8 && (game.commander.savedPlayerElectrical?.remaining ?? 0) > 0)
  #expect(ready.id == item.id && ready.empGrades == item.empGrades)
  #expect(game.commander.equipmentPurchaseHistory == history)
  let saved = try NativeSaveTestFixture.readVersionedCommander(from: file)
  #expect(saved.fittedEquipment(at: .utility(.empPirateBlaster)) == ready)
  #expect(saved.savedPlayerElectrical == game.commander.savedPlayerElectrical)
  #expect(saved.equipmentPurchaseHistory == history)
  try openEMPUnitHeader(&game, publish: publish)
}

func insertEMPUnitTarget(
  _ game: inout Game, catalogue: String = EMPUnitTargetCatalogue.ordinary,
  hostile: Bool = false, police: Bool = false, fullStock: Bool = false
) throws {
  // Resolve current source and actual stock before changing this controlled unit scene.
  let source: OriginalFleetRuntimeHullSource.Source
  let stock: NPCResources
  if police {
    let current = try #require(StationPoliceSource.current())
    source = current.source
    stock = current.stock
    try #require(source.ship.id == StationPoliceSource.catalogueID)
    try #require(source.ship.nativeHull == .viper)
  } else {
    source = try #require(OriginalFleetRuntimeHullSource.source(for: catalogue))
    stock = try #require(NPCResources.stock(source.performance))
    try #require(source.ship.id == catalogue)
  }
  let id = source.ship.id
  let ship = source.ship
  let performance = source.performance
  try #require(!fullStock || (!police && !hostile && id == EMPUnitTargetCatalogue.ordinary))
  try #require(source.contract.id == id && ship.game == performance)
  try #require(stock.valid && stock.profile == .nativeHull)
  try #require(EMPState.hasSupportedCrew(ship))
  let accommodation = try ShipAccommodationProfile(ship: ship)
  try #require(accommodation.operatingCrew > 0)
  let salvage = try #require(SalvageCatalogue.empProfile(catalogueShipID: id))
  if !police && id == EMPUnitTargetCatalogue.ordinary {
    // Pin the chosen ordinary default to its existing source, never inferred crew
    // or a catalogue label applied to an unavailable replacement hull.
    try #require(source.contract.origin == .human && source.contract.classification == "trader")
    try #require(accommodation.operatingCrew == 1 && EMPState.declaredNativeCrewCount(ship) == 1)
    try #require(!salvage.sourceRoles.contains(.thargoid))
  }
  if !police && id == EMPUnitTargetCatalogue.twoPerson {
    try #require(source.contract.origin == .human && source.contract.classification == "military")
    try #require(accommodation.operatingCrew == 2 && EMPState.declaredNativeCrewCount(ship) == 2)
    try #require(!salvage.sourceRoles.contains(.thargoid))
  }
  var body = SpaceBody(
    id: 42, hull: police ? .viper : .cobra, position: .init(0, 0, 1000), hostile: hostile)
  body.rotationRate = 0
  body.energy = fullStock ? performance.energy : min(77, performance.energy * 0.6)
  let velocity: Vector3 = fullStock
    ? game.commander.flightSimulation.pose.orientation.apply(.init(15, -2, 5))
    : .init(15, -2, 5)
  let angularVelocity: Vector3 = fullStock ? .init(0, 0, 0) : .init(0, 0.1, 0.2)
  try #require(!game.bodies.contains { $0.id == 42 })
  game.bodies.insert(body, at: 0)
  game.nextBodyID = max(game.nextBodyID, 43)
  game.ensurePhysicalActors()
  game.bodies[0].physical?.catalogueShipID = id
  game.bodies[0].physical?.velocity = velocity
  game.bodies[0].physical?.angularVelocity = angularVelocity
  game.bodies[0].physical?.canonicalSpin = true
  game.bodies[0].physical?.npc?.resources = stock
  game.bodies[0].physical?.npc?.ordinaryCargo = [.init(commodity: .food, quantity: 2)]
  game.bodies[0].physical?.npc?.cargoProvenance = .recorded
  game.bodies[0].physical?.npc?.legalProvenance = .recorded
  let npcFuel = try #require(game.bodies[0].physical?.npc?.resources?.fuel)
  let reachable = game.knownSystems.filter {
    let distance = game.currentSystem.distance(to: $0)
    return $0.id != game.commander.system && $0.id != Plugh.systemID
      && distance > 0 && distance <= performance.jump
      && Int(ceil(distance * 10)) <= npcFuel
  }.sorted {
    let left = game.currentSystem.distance(to: $0)
    let right = game.currentSystem.distance(to: $1)
    return left == right ? $0.id < $1.id : left < right
  }
  let destination = try #require(reachable.first)
  let destinationSystem = SystemIdentity(galaxy: game.commander.galaxy, system: destination.id)
  game.bodies[0].physical?.npc?.destination = destinationSystem
  game.bodies[0].physical?.npc?.routeProvenance = .recorded
  // Join the actual native adoption; this is not an ordinary spawn receipt or earned actor.
  let adopted = game.bodies[0]
  let physical = try #require(adopted.physical)
  let npc = try #require(physical.npc)
  let expectedRole: NPCRole = police ? .police : (hostile ? .pirate : .trader)
  let expectedPopulation: PopulationClass = police ? .police : (hostile ? .pirate : .civilian)
  try #require(adopted.id == 42 && adopted.hull == (police ? .viper : .cobra))
  try #require(adopted.hostile == hostile && adopted.rotationRate == 0)
  try #require(physical.identity.system == game.systemIdentity)
  try #require(physical.identity.visit == game.commander.flightSimulation.visit)
  try #require(physical.identity.entity > 1 && physical.spawnIdentity == nil)
  try #require(physical.population == expectedPopulation && npc.role == expectedRole)
  try #require(physical.blocksNavalEncounter == police)
  try #require(physical.catalogueShipID == id && npc.resources == stock)
  try #require(StationPoliceSource.empCatalogueID(for: adopted) == id)
  try #require(physical.velocity == velocity)
  try #require(physical.angularVelocity == angularVelocity && physical.canonicalSpin == true)
  try #require(npc.origin == game.systemIdentity && npc.destination == destinationSystem)
  try #require(npc.ordinaryCargo == [.init(commodity: .food, quantity: 2)])
  try #require(npc.cargoProvenance == .recorded && npc.legalProvenance == .recorded)
  try #require(npc.routeProvenance == .recorded)
  if fullStock {
    try #require(adopted.energy == performance.energy && npc.resources == stock)
    try #require(stock.frontShield == stock.frontCapacity && stock.rearShield == stock.rearCapacity)
    try #require(stock.electrical == nil)
  }
}

func expectEMPModuleProperty(_ before: OwnedEquipmentItem, _ after: OwnedEquipmentItem) throws {
  func property(_ item: OwnedEquipmentItem) throws -> NSDictionary {
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
    object.removeValue(forKey: "empBank")
    return object as NSDictionary
  }
  #expect(try property(before) == property(after))
}

func expectEMPPrimaryLaw(_ result: EMPPulseBeforeResult, body: SpaceBody) throws {
  let before = result.primary
  let front = before.contactOffset.dot(before.modelForward) >= 0
  let shield = front ? before.frontShield : before.rearShield
  let resources = try #require(body.physical?.npc?.resources)
  var reserve = before.electrical
  let drained = reserve.drain(max(0, before.contactPower - shield), at: before.electrical.physicalTime)
  try #require(drained)
  #expect(resources.electrical == reserve)
  #expect((front ? resources.frontShield : resources.rearShield) == max(0, shield - before.contactPower))
  #expect((front ? resources.rearShield : resources.frontShield) == (front ? before.rearShield : before.frontShield))
  #expect(body.energy == before.hullEnergy && body.physical?.identity == result.charge.target)
}

func expectEMPSelfLaw(_ result: EMPPulseBeforeResult, game: Game) throws {
  let before = try #require(result.player)
  let front = before.contactPoint.z >= 0
  let shield = front ? before.frontShield : before.rearShield
  var reserve = before.electrical
  let drained = reserve.drain(max(0, before.contactPower - shield), at: before.electrical.physicalTime)
  try #require(drained)
  #expect(game.commander.savedPlayerElectrical == reserve && game.energy == before.hullEnergy)
  #expect((front ? game.frontShield : game.rearShield) == max(0, shield - before.contactPower))
  #expect((front ? game.rearShield : game.frontShield) == (front ? before.rearShield : before.frontShield))
}

@discardableResult
func emitEMPUnitPulse(
  _ game: inout Game, publish: ScriptPublisher?,
  beforeRelease: ((inout Game) throws -> Void)? = nil
) throws -> EMPPulseBeforeResult {
  let publish = try #require(publish)
  try openEMPUnitHeader(&game, publish: publish)
  let began = game.fireEMPPirateBlaster()
  try #require(began)
  let charge = try #require(game.commander.savedEMPCharge)
  for _ in 0..<99 {
    try empUnitFrame(&game, controls: empUnitAim(game, actor: charge.target, fire: true), publish: publish)
  }
  try #require(game.commander.savedEMPCharge?.phase == .charging)
  try beforeRelease?(&game)
  let audio = game.dischargeAudio.events.count
  try empUnitFrame(&game, controls: empUnitAim(game, actor: charge.target, fire: true), publish: publish, finish: false)
  let result = try #require(game.currentEMPPulseBeforeResult())
  try #require(result.charge.phase == .released && result.charge.target == charge.target)
  #expect(abs(game.commander.flightSimulation.physicalTime - charge.startedAt - 10) < 1e-8)
  #expect(game.dischargeAudio.events.count == audio + 1)
  try #require(game.postedEMPPlayerElectrical() != nil)
  #expect(game.currentEMPPlayerModule()?.empBank?.remaining == 0)
  #expect(game.currentEMPPlayerModule()?.empBank?.lastDischarge == result.charge)
  game.finishEMPPlayerElectricalInterval(publish: publish)
  return result
}

/// Only the explicit controlled victim injury is arranged; actual physics and admission run normally.
@discardableResult
func releaseDamagedEMPBoundary(
  _ game: inout Game, seed: UInt64? = 0,
  beforeRelease: ((inout Game) throws -> Void)? = nil
) throws -> Bool {
  try withEMPUnitWriter(&game) { scene, publish, file in
    try openEMPUnitHeader(&scene, publish: publish)
    guard scene.fireEMPPirateBlaster() else { return false }
    if let seed { scene.seedScriptTrial(seed) }
    let charge = try #require(scene.commander.savedEMPCharge)
    for _ in 0..<99 {
      try empUnitFrame(&scene, controls: empUnitAim(scene, actor: charge.target, fire: true), publish: publish)
    }
    try #require(scene.commander.savedEMPCharge?.phase == .charging)
    let indexCandidate = scene.bodies.firstIndex { $0.physical?.identity == charge.target }
    let index = try #require(indexCandidate)
    let contact = try scene.nearestMissionCollision(from: .init(0, 0, 0), direction: .init(0, 0, 1),
      range: EMPPulseProfile.resolve(for: scene.commander).range, radius: 0, includePlayer: false)
    let hit = try #require(contact?.hit)
    try #require(hit.target == .body(scene.bodies[index].id))
    var resources = try #require(scene.bodies[index].physical?.npc?.resources)
    let power = try EMPPulseProfile.resolve(for: scene.commander).power
    let remaining = min(resources.energyCapacity, power / 4)
    let front = (hit.point - scene.bodies[index].position).dot(scene.bodies[index].modelVector(.init(0, 0, 1))) >= 0
    if front { resources.frontShield = min(resources.frontCapacity, power / 4) }
    else { resources.rearShield = min(resources.rearCapacity, power / 4) }
    let now = scene.commander.flightSimulation.physicalTime
    var reserve = try #require(ElectricalReserve(capacity: resources.energyCapacity, recharge: resources.electricalRecharge, at: now))
    let drained = reserve.drain(resources.energyCapacity - remaining, at: now)
    try #require(drained)
    try #require(reserve.remaining > 0 && reserve.disabledAt == nil)
    resources.electrical = reserve
    scene.bodies[index].physical?.npc?.resources = resources
    try beforeRelease?(&scene)
    let audio = scene.dischargeAudio.events.count
    try empUnitFrame(&scene, controls: empUnitAim(scene, actor: charge.target, fire: true), publish: publish, finish: false)
    let result = try #require(scene.currentEMPPulseBeforeResult())
    let actualCandidate = scene.bodies.first { $0.physical?.identity == charge.target }
    let actual = try #require(actualCandidate)
    try expectEMPPrimaryLaw(result, body: actual)
    let source = try #require(actual.physical?.empSource)
    let record = try #require(scene.commander.savedEMPState?.records[source])
    let boundary = record.custody.original.body
    let boundaryPose = scene.commander.flightSimulation.pose
    #expect(record.custody.original.physicalTime == scene.commander.flightSimulation.physicalTime)
    #expect(boundaryPose.systemPoint(actual.position) == boundary.position)
    #expect(actual.orientation.transformed(by: boundaryPose.orientation) == boundary.orientation)
    #expect(actual.physical?.velocity == boundary.physical?.velocity && actual.physical?.angularVelocity == boundary.physical?.angularVelocity)
    #expect(actual.physical?.npc?.resources?.fuel == boundary.physical?.npc?.resources?.fuel)
    #expect(actual.physical?.npc?.ordinaryCargo == boundary.physical?.npc?.ordinaryCargo)
    try #require(scene.isEMPDisabled(actual) && actual.physical?.npc?.resources?.electrical?.remaining == 0)
    #expect(scene.dischargeAudio.events.count == audio + 1)
    try #require(scene.postedEMPPlayerElectrical() != nil)
    #expect(scene.currentEMPPlayerModule()?.empBank?.lastDischarge == result.charge)
    scene.finishEMPPlayerElectricalInterval(publish: publish)
    return true
  }
}

func expectEMPInventoryProperty(_ before: OwnedEquipmentInventory, _ after: OwnedEquipmentInventory) throws {
  #expect(before.owner == after.owner && before.activeHull == after.activeHull)
  #expect(before.items.count == after.items.count && after.revision >= before.revision)
  for original in before.items {
    let currentCandidate = after.items.first { $0.id == original.id }
    let current = try #require(currentCandidate)
    if original.node == EMPModuleGradePolicy.node { try expectEMPModuleProperty(original, current) }
    else { #expect(current == original) }
  }
}

/// Current full-stock controlled producer; this grants no ambient or acquisition authority.
func paidCurrentFullStockEMPFixture() async throws
  -> (purchase: EMPModulePurchaseFixture, actor: ActorIdentity)
{
  let fixture = try await EMPModulePurchaseFixture(useOwnedStarter: true)
  do {
    let initial = await fixture.runtime.snapshot()
    let base = try #require(initial.currentEMPPlayerModule())
    try #require(base.empGrades == .base && base.empBank?.remaining == 0)
    let energy = try await fixture.runtime.purchaseFullStockEMPEnergy()
    var receipts: [EMPModulePaidUpgradeReceipt] = []
    for (next, price) in [(1, 30000), (2, 60000), (3, 120000)] {
      let before = await fixture.runtime.snapshot()
      let context = try await fixture.context(.power)
      let receipt = try await fixture.runtime.purchaseEMPModuleUpgrade(context)
      let after = await fixture.runtime.snapshot()
      #expect(receipt.module == base.id && receipt.axis == .power)
      #expect(receipt.before == .init(power: next - 1, capacity: 0, recharge: 0))
      #expect(receipt.after == .init(power: next, capacity: 0, recharge: 0))
      #expect(receipt.paidPrice == price)
      #expect(receipt.resultingRevision == receipt.sourceInventoryRevision + 1)
      #expect(after.commander.credits == before.commander.credits - price)
      #expect(after.commander.equipmentPurchaseHistory == before.commander.equipmentPurchaseHistory)
      receipts.append(receipt)
      let current = try #require(after.currentEMPPlayerModule())
      #expect(current.id == base.id && current.provenance == base.provenance)
      #expect(current.empGrades?.paid == receipts)
      #expect(current.empBank?.remaining == 0 && current.empBank?.lastDischarge == nil)
    }
    let fitted = await fixture.runtime.snapshot()
    let weapon = try #require(fitted.currentEMPPlayerModule())
    try #require(weapon.empGrades?.indices == .init(power: 3, capacity: 0, recharge: 0))
    try #require(weapon.empBank?.capacity == 8 && weapon.empBank?.remaining == 0)
    let profile = try EMPPulseProfile.resolve(for: fitted.commander)
    try #require(profile.energyStage == 1 && profile.power == 384 && profile.warmup == 10)
    let pointer = try Data(contentsOf: fixture.file)
    let cold = GameRuntime()
    try await cold.load(from: fixture.file, persistMigrations: false)
    let restored = await cold.snapshot()
    #expect(restored.currentEMPPlayerModule() == weapon)
    #expect(restored.commander.fittedEquipment(at: .energy) == energy)
    #expect(
      restored.commander.equipmentPurchaseHistory == fitted.commander.equipmentPurchaseHistory)
    #expect(try Data(contentsOf: fixture.file) == pointer)
    await fixture.runtime.key("0")
    let actor = try await fixture.runtime.scriptCommand { game in
      try prepareEMPUnitScene(&game)
      try insertEMPUnitTarget(&game, fullStock: true)
      try #require(game.commander.valid)
      let body = try #require(game.bodies.first)
      try #require(body.physical?.catalogueShipID == EMPUnitTargetCatalogue.ordinary)
      try #require(game.currentEMPPlayerModule()?.empBank?.remaining == 0)
      return try #require(body.physical?.identity)
    }
    return (fixture, actor)
  } catch {
    fixture.clean()
    throw error
  }
}

private extension GameRuntime {
  func purchaseFullStockEMPEnergy() throws -> OwnedEquipmentItem {
    let before = game.commander
    let owner = try #require(before.equipmentOwnerID)
    let history = try #require(before.equipmentPurchaseHistory)
    let weapon = try #require(game.currentEMPPlayerModule())
    try #require(!game.atPlugh && !game.commander.executive)
    let matchingIndex = Equipment.all.firstIndex { $0.name == "Extra Energy Unit" }
    game.selection = try #require(matchingIndex)
    let offer = Equipment.all[game.selection]
    try #require(game.screen == .equipment && game.equipmentAvailable(offer))
    try #require(game.shopPrice(offer) == 72000)
    let context = try #require(game.equipmentPurchaseContext)
    let result = equipmentTransaction(.purchase(context))
    try #require(result.applied)
    let energy = try #require(game.commander.fittedEquipment(at: .energy))
    let paid = try #require(game.commander.equipmentPurchaseHistory)
    let receipt = try #require(paid.paid.last)
    #expect(paid.paid.count == history.paid.count + 1)
    #expect(receipt.owner == owner && receipt.node == energy.node && receipt.price == 72000)
    #expect(receipt.binding.request.newItem == energy.id)
    #expect(receipt.binding.snapshot.funds == before.credits)
    #expect(game.commander.credits == before.credits - 72000)
    #expect(energy.provenance == .paid(owner: owner, transaction: receipt.transaction))
    try #require(energy.component?.grade == EquipmentModuleTemplates.energy.grades[1].identity)
    #expect(game.currentEMPPlayerModule() == weapon)
    #expect(game.commander.cargo == before.cargo && game.commander.kills == before.kills)
    #expect(game.commander.shipID == before.shipID)
    return energy
  }
}

/// Actual paid shop operations precede native launch; none of these operations earns bank energy.
func paidEMPNativeFixture() async throws -> EMPModulePurchaseFixture {
  let fixture = try await EMPModulePurchaseFixture(useOwnedStarter: true)
  do {
    let before = await fixture.runtime.snapshot()
    let base = try #require(before.currentEMPPlayerModule())
    try #require(base.empGrades == .base && base.empBank?.remaining == 0)
    let context = try await fixture.context(.power)
    let receipt = try await fixture.runtime.purchaseEMPModuleUpgrade(context)
    let purchased = await fixture.runtime.snapshot()
    #expect(receipt.paidPrice == 30000 && receipt.module == base.id && receipt.before == .base)
    #expect(receipt.after == .init(power: 1, capacity: 0, recharge: 0))
    #expect(receipt.resultingRevision == receipt.sourceInventoryRevision + 1)
    #expect(purchased.commander.credits == before.commander.credits - 30000)
    try await fixture.runtime.scriptCommand { game in
      let originalModule = try #require(game.currentEMPPlayerModule())
      let grades = try #require(originalModule.empGrades)
      let history = game.commander.equipmentPurchaseHistory
      try game.commander.grantEquipment(Equipment.eliteEnergyUnit, at: .energy, provenance: .xyzzy)
      #expect(game.commander.fittedComponent(at: .energy)?.grade == EquipmentModuleTemplates.energy.grades[3].identity)
      let fittedModule = try #require(game.currentEMPPlayerModule())
      #expect(fittedModule == originalModule && fittedModule.id == originalModule.id)
      #expect(fittedModule.empGrades == grades && fittedModule.empGrades?.paid == grades.paid)
      #expect(game.commander.equipmentPurchaseHistory == history)
      let profile = try EMPPulseProfile.resolve(for: game.commander)
      #expect(profile.energyStage == 3)
      #expect(profile.power == 80 * EMPModuleGradePolicy.powerMultipliers[grades.power])
    }
    let fitted = await fixture.runtime.snapshot()
    let item = try #require(fitted.currentEMPPlayerModule())
    #expect(item.id == base.id && item.empGrades?.power == 1 && item.empGrades?.paid == [receipt])
    #expect(item.empBank?.remaining == 0 && item.empBank?.capacity == 8 && item.empBank?.lastDischarge == nil)
    #expect(try EMPPulseProfile.resolve(for: fitted.commander).power == 160)
    let pointer = try Data(contentsOf: fixture.file)
    let disk = try NativeSaveTestFixture.readVersionedCommander(from: fixture.file)
    #expect(disk.fittedEquipment(at: .utility(.empPirateBlaster)) == item)
    #expect(disk.equipmentPurchaseHistory == fitted.commander.equipmentPurchaseHistory)
    let cold = GameRuntime()
    try await cold.load(from: fixture.file, persistMigrations: false)
    #expect(await cold.snapshot().commander.fittedEquipment(at: .utility(.empPirateBlaster)) == item)
    #expect(try Data(contentsOf: fixture.file) == pointer)
    await fixture.runtime.key("0")
    let launched = await fixture.runtime.snapshot()
    try #require(!launched.docked && launched.commander.valid)
    #expect(launched.currentEMPPlayerModule()?.empBank?.remaining == 0)
    return fixture
  } catch { fixture.clean(); throw error }
}

struct EMPNativePulseRun: Sendable {
  let remainingFrames: Int
  let pulses: [EMPPulseBeforeResult]
}

struct EMPTestAttackLedger: Decodable {
  struct Window: Decodable, Equatable {
    let owner: ActorIdentity
    let victim: ActorIdentity
    let lastAttack: Double
    let unlawful: Bool
    let authorityAction: Bool
  }
  let attacks: [Window]
}

/// These checks apply only after genuine zero; a positive base000 target is checked separately.
func verifyActualEMPZero(
  _ game: inout Game, original: SpaceBody, expectedWindows: Int,
  hardware: OwnedEquipmentInventory, history: EquipmentPurchaseHistory,
  weapon: OwnedEquipmentItem, credits: Int, cargo: [Int], legal: Int, kills: Int
) async throws {
  let actor = try #require(original.physical?.identity)
  let player = try #require(game.commander.flightSimulation.player)
  let bodyCandidate2 = game.bodies.first { $0.physical?.identity == actor }
  let body = try #require(bodyCandidate2)
  let source = try #require(body.physical?.empSource)
  let record = try #require(game.commander.savedEMPState?.records[source])
  let result = try #require(game.currentEMPPulseBeforeResult())
  try expectEMPPrimaryLaw(result, body: body)
  #expect(source == actor && record.originalBodyID == original.id && record.originalSpawn == original.physical?.spawnIdentity)
  #expect(record.custody.kind == .ordinary && record.custody.valid)
  #expect(record.custody.logical == actor && record.custody.original.body.physical?.identity == actor)
  #expect(record.custody.traffic?.actor == actor && record.custody.assignment == nil)
  #expect(record.disableIncident.victim == actor && record.disableIncident.origin.owner == player)
  #expect(record.disableIncident.physicalTime == result.charge.endedAt)
  #expect(record.disableIncident.origin.sourcePart == "emp:" + weapon.id.uuidString)
  try expectEMPModuleProperty(weapon, record.weapon)
  #expect(record.weapon.empBank?.remaining == 8 && record.weaponOwner == hardware.owner)
  #expect(body.hull == original.hull && body.energy == result.primary.hullEnergy)
  let catalogueID = try #require(body.physical?.catalogueShipID)
  #expect(record.hull.body.physical?.catalogueShipID == catalogueID)
  #expect(record.hull.body.energy == body.energy)
  #expect(record.cargo == original.physical?.npc?.ordinaryCargo && record.legal == original.physical?.npc?.legal)
  let catalogue = try #require(ShipCatalogue.ship(catalogueID))
  let crew = try ShipAccommodationProfile(ship: catalogue).operatingCrew
  #expect(record.crewTotal == crew && record.crewAboard == crew)
  #expect(record.pods.isEmpty && record.crewCaptures.isEmpty && record.lostCrewCount == 0)
  expectOriginalEMPCrewConserved(record)
  let zero = try #require(body.physical?.npc?.resources?.electrical)
  try #require(game.isEMPDisabled(body) && zero.remaining == 0 && zero.disabledAt == result.charge.endedAt)
  try expectEMPInventoryProperty(hardware, #require(game.commander.equipmentInventory))
  #expect(game.commander.equipmentPurchaseHistory == history)
  #expect(game.commander.credits == credits && game.commander.cargo == cargo && game.commander.kills == kills)
  #expect(game.commander.legal > legal && game.screen != .gameOver && !game.docked)
  let before = try JSONDecoder().decode(EMPTestAttackLedger.self, from: JSONEncoder().encode(game.commander.crimeLedger))
  let windows = before.attacks.filter { $0.owner == actor }
  try #require(windows.count == expectedWindows)
  let allSatisfied = windows.allSatisfy { $0.victim == player && $0.lastAttack.isFinite && $0.lastAttack <= record.disableIncident.physicalTime }
  #expect(allSatisfied)
  let writer = try EMPUnitWriter()
  defer { writer.clean() }
  let runtime = GameRuntime(game: game, saveURL: writer.file)
  try await runtime.save(to: writer.file)
  try await runtime.scriptCommand { scene in
    let emission = scene.commander.flightSimulation.nextEmission
    let resources = [scene.energy, scene.frontShield, scene.rearShield]
    scene.emitLegacyNPCBeam(bodyID: body.id, damage: 1000)
    let launched = scene.launchGameplayNPCMissile(bodyID: body.id)
    #expect(!launched)
    #expect(scene.commander.flightSimulation.nextEmission == emission)
    #expect([scene.energy, scene.frontShield, scene.rearShield] == resources)
  }
  await runtime.setControls(Controls())
  game = await runtime.advance(delta: 0.1)
  let stillCandidate = game.bodies.first { $0.physical?.identity == actor }
  let still = try #require(stillCandidate)
  let remaining = try #require(still.physical?.npc?.resources?.electrical)
  #expect(game.isEMPDisabled(still) && remaining.remaining == 0 && remaining.disabledAt == zero.disabledAt)
  let after = try JSONDecoder().decode(EMPTestAttackLedger.self, from: JSONEncoder().encode(game.commander.crimeLedger))
  #expect(after.attacks.filter { $0.owner == actor } == windows)
  let retained = try #require(game.commander.savedEMPState?.records[source])
  #expect(retained.disableIncident == record.disableIncident && retained.custody == record.custody)
  #expect(retained.cargo == record.cargo && retained.legal == record.legal)
  expectOriginalEMPCrewConserved(retained)
  try expectEMPInventoryProperty(hardware, #require(game.commander.equipmentInventory))
  #expect(game.commander.equipmentPurchaseHistory == history && game.commander.legal >= legal)
}

/// Drive saved random ejection times through the production admission boundary.
/// Used only by custody/persistence unit scenes; native flight must use actual ticks.
func ejectScheduledEMPCrewBoundary(_ game: inout Game, source: ActorIdentity) throws {
  let record = try #require(game.commander.savedEMPState?.records[source])
  let episode = try #require(record.disableEpisodes.last)
  try #require(!episode.ejections.isEmpty)
  let times = episode.ejections.map { episode.incident.physicalTime + $0.delay }.sorted()
  let allSatisfied2 = times.allSatisfy { $0 < episode.deadline }
  try #require(allSatisfied2)
  var historicalReceipt: CurrentNewtKitReceipt? = nil
  var historicalWork: CurrentNewtKitStock.WorkState? = nil
  for time in times {
    // Real elapsed physics lets an admitted pod clear the next person's unchanged aperture.
    let stock = game.commander.savedEMPState?.records[source]?.hull.body.physical?.currentNewtKitStock
    var actuation = stock?.actuation
    if record.custody.original.body.physical?.currentNewtKitStock != nil {
      try #require(stock != nil)
    }
    let mechanismStart: Double?
    if let stock {
      let ejectionCandidate = episode.ejections.first { $0.ordinal == stock.issue.person.ordinal }
      let ejection = try #require(ejectionCandidate)
      mechanismStart = episode.incident.physicalTime + ejection.delay
      let kitSource = try #require(CurrentNewtKitSource.current)
      try #require(kitSource.matches(stock, at: game.commander.flightSimulation.physicalTime))
    } else {
      mechanismStart = nil
    }
    // A genuine stowed kit has no actuation until its person's actual sampled start.
    // The same loop discovers the issued endpoint before settling paid stroke/coast.
    var target = max(time + 1e-6, actuation?.completeAt ?? time)
    if actuation == nil { try #require(target < episode.deadline) }
    while game.commander.flightSimulation.physicalTime < target {
      let now = game.commander.flightSimulation.physicalTime
      let endpoint: Double
      if actuation == nil, let mechanismStart, now < mechanismStart {
        endpoint = min(target, mechanismStart)
      } else if let actuation, now < actuation.unlockAt {
        endpoint = min(target, actuation.unlockAt)
      } else {
        endpoint = target
      }
      game.tick(delta: min(0.1, endpoint - now))
      try #require(!game.docked && game.screen != .gameOver)
      let advanced = game.commander.flightSimulation.physicalTime
      try #require(advanced > now)
      if let stock {
        let current = try #require(game.commander.savedEMPState?.records[source]?.hull.body.physical?.currentNewtKitStock)
        let kitSource = try #require(CurrentNewtKitSource.current)
        try #require(current.issue == stock.issue && kitSource.matches(current, at: advanced))
        if let actual = current.actuation {
          if let actuation { try #require(actual == actuation) }
          else {
            let mechanismStart = try #require(mechanismStart)
            try #require(actual.startedAt == mechanismStart)
            try #require(actual.source == source && actual.sequence == record.sequence)
            try #require(actual.parent == record.hull.binding && actual.deadline == episode.deadline)
            actuation = actual
            target = max(target, actual.completeAt)
          }
        } else if let mechanismStart, advanced >= mechanismStart {
          try #require(current.actuation != nil)
        }
      }
      if let observed = game.commander.savedEMPState?.records[source]?.hull.body.physical?.currentNewtKitStock,
        let actual = observed.receipt
      {
        if let historicalReceipt { #expect(actual == historicalReceipt) }
        else {
          let actuation = try #require(actuation)
          let kitSource = try #require(CurrentNewtKitSource.current)
          try #require(advanced == actuation.unlockAt && observed.observedAt == advanced)
          try #require(actual.releasedAt == advanced && actual.actuation == actuation)
          try #require(actual.issue == observed.issue && kitSource.validWork(observed.work))
          try #require(kitSource.matches(observed, at: advanced))
          historicalReceipt = actual
          historicalWork = observed.work
        }
      }
    }
    game.advanceEMPActors()
    if let mechanismStart, game.commander.flightSimulation.physicalTime >= mechanismStart {
      try #require(actuation != nil)
    }
    if let actuation {
      let issued = try #require(stock)
      let kitSource = try #require(CurrentNewtKitSource.current)
      try #require(kitSource.matches(actuation, issue: issued.issue))
      let mechanismStart = try #require(mechanismStart)
      try #require(actuation.startedAt == mechanismStart)
      try #require(actuation.source == source && actuation.sequence == record.sequence)
      try #require(actuation.parent == record.hull.binding)
      try #require(actuation.deadline == episode.deadline && actuation.unlockAt < episode.deadline)
      let retained = try #require(game.commander.savedEMPState?.records[source]?.hull.body.physical?.currentNewtKitStock)
      let receipt = try #require(retained.receipt)
      #expect(retained.issue == issued.issue && retained.actuation == actuation)
      #expect(retained.phase == .released && retained.remaining == 0 && retained.interruptedAt == nil)
      #expect(receipt.issue == issued.issue && receipt.actuation == actuation)
      #expect(historicalReceipt == receipt)
      #expect(receipt.releasedAt == actuation.unlockAt && receipt.releasedAt < episode.deadline)
      #expect(retained.observedAt == game.commander.flightSimulation.physicalTime)
      #expect(retained.observedAt >= actuation.completeAt && retained.observedAt >= receipt.releasedAt)
      let unlockWork = try #require(historicalWork)
      #expect(kitSource.validWork(unlockWork))
      #expect(kitSource.matchesCharges(receipt.remainingCharges,
        kitSource.charges(at: receipt.releasedAt, actuation: actuation, work: unlockWork)))
      #expect(kitSource.validWork(retained.work))
      try #require(retained.work.rodMetres == kitSource.stroke && retained.work.rodVelocity == 0)
      #expect(unlockWork.guideWorkJoules >= issued.work.guideWorkJoules)
      #expect(unlockWork.ejectionWorkJoules >= issued.work.ejectionWorkJoules)
      #expect(retained.work.guideWorkJoules >= unlockWork.guideWorkJoules)
      #expect(retained.work.ejectionWorkJoules >= unlockWork.ejectionWorkJoules)
      #expect(retained.work.guideWorkJoules >= issued.work.guideWorkJoules)
      #expect(retained.work.ejectionWorkJoules >= issued.work.ejectionWorkJoules)
      #expect(kitSource.matchesCharges(retained.charges,
        kitSource.charges(at: retained.observedAt, actuation: actuation, work: retained.work)))
      #expect(receipt.remainingCharges.doesNotExceed(issued.charges))
      #expect(retained.charges.doesNotExceed(receipt.remainingCharges))
      #expect(kitSource.matches(retained, at: game.commander.flightSimulation.physicalTime))
    }
  }
  let after = try #require(game.commander.savedEMPState?.records[source])
  try #require(after.crewAboard == 0 && after.pods.count == record.crewTotal)
  #expect(Set(after.pods.compactMap { $0.body.physical?.empCrewPod }).count == record.crewTotal)
}

/// Fit a real top normal energy component without enabling other secret-mode policies.
func fitEliteEMPTestEnergy(_ game: inout Game) throws {
  try game.commander.grantEquipment(Equipment.eliteEnergyUnit, at: .energy, provenance: .xyzzy)
  #expect(
    game.commander.fittedComponent(at: .energy)?.grade
      == EquipmentModuleTemplates.energy.grades[3].identity)
  #expect(try EMPPulseProfile.resolve(for: game.commander).power == 80)
}

/// Every native aiming, earning, charge and cooldown frame uses the same original800 budget.
@discardableResult
func disableNativeEMPActor(
  _ actor: ActorIdentity, game: inout Game, stopAfterFirstEmission: Bool = false,
  stopAfterEmissions: Int? = nil,
  afterFirstEmission: (@Sendable (inout Game) throws -> Void)? = nil
) async throws -> EMPNativePulseRun {
  let writer = try EMPUnitWriter()
  defer { writer.clean() }
  game.selectFlightTool(.empPirateBlaster)
  let runtime = GameRuntime(game: game, saveURL: writer.file)
  try await runtime.save(to: writer.file)
  game = await runtime.snapshot()
  let desired: Int? = stopAfterFirstEmission ? 1 : stopAfterEmissions
  var pulses: [EMPPulseBeforeResult] = []
  var previousEmission: UInt64?
  var handledFirst = false
  for frame in 0..<800 {
    let bodyCandidate3 = game.bodies.first { $0.physical?.identity == actor }
    let body = try #require(bodyCandidate3)
    if game.isEMPDisabled(body) {
      return .init(remainingFrames: 800 - frame, pulses: pulses)
    }
    let profile = try EMPPulseProfile.resolve(for: game.commander)
    let contact = try game.nearestMissionCollision(from: .init(0, 0, 0), direction: .init(0, 0, 1),
      range: profile.range, radius: 0, includePlayer: false)
    let ready = game.commander.savedEMPCharge == nil && game.fireCooldown <= 0
      && (game.currentEMPPlayerModule()?.empBank?.remaining ?? 0) >= profile.energyCost
    let fire = game.commander.savedEMPCharge?.phase == .charging
      || (ready && contact?.hit.target == .body(body.id))
    let controls = empUnitAim(game, actor: actor, fire: fire)
    await runtime.setControls(controls)
    let start = game.commander.flightSimulation.physicalTime
    game = await runtime.advance(delta: 0.1)
    try #require(game.commander.flightSimulation.physicalTime == start + 0.1,
      "Native EMP frame did not advance its actual owner clock")
    try #require(!game.docked && !game.paused && game.screen != .gameOver,
      Comment(rawValue: "EMP native stopped frame=\(frame) message=\(game.message)"))
    if let result = game.currentEMPPulseBeforeResult(), result.emissionID != previousEmission {
      try #require(result.charge.target == actor && result.charge.phase == .released)
      previousEmission = result.emissionID
      let actualCandidate2 = game.bodies.first { $0.physical?.identity == actor }
      let actual = try #require(actualCandidate2)
      try expectEMPPrimaryLaw(result, body: actual)
      pulses.append(result)
      let saved = try NativeSaveTestFixture.readVersionedCommander(from: writer.file)
      #expect(saved.savedPlayerElectrical == game.commander.savedPlayerElectrical)
      #expect(saved.fittedEquipment(at: .utility(.empPirateBlaster)) == game.currentEMPPlayerModule())
      #expect(saved.equipmentPurchaseHistory == game.commander.equipmentPurchaseHistory)
      if !handledFirst, let afterFirstEmission {
        handledFirst = true
        try await runtime.scriptCommand { scene in try afterFirstEmission(&scene) }
        game = await runtime.snapshot()
      }
      if let desired, pulses.count == desired {
        let pointer = try Data(contentsOf: writer.file)
        let cold = GameRuntime()
        try await cold.load(from: writer.file, persistMigrations: false)
        let restored = await cold.snapshot()
        #expect(restored.currentEMPPlayerModule() == game.currentEMPPlayerModule())
        #expect(restored.commander.savedPlayerElectrical == game.commander.savedPlayerElectrical)
        #expect(try Data(contentsOf: writer.file) == pointer)
        return .init(remainingFrames: 800 - frame - 1, pulses: pulses)
      }
      if game.isEMPDisabled(actual) {
        let pointer = try Data(contentsOf: writer.file)
        let cold = GameRuntime()
        try await cold.load(from: writer.file, persistMigrations: false)
        #expect(await cold.snapshot().commander.savedEMPState == game.commander.savedEMPState)
        #expect(try Data(contentsOf: writer.file) == pointer)
        return .init(remainingFrames: 800 - frame - 1, pulses: pulses)
      }
    }
  }
  throw EMPTestBudgetExhausted.native800
}

enum EMPTestBudgetExhausted: Error { case native800 }

func nativeEMPHulls(_ game: Game, source: ActorIdentity) -> [SpaceBody] {
  let binding = game.commander.savedEMPState?.records[source]?.hull.binding
  return game.bodies.filter { body in
    guard let physical = body.physical, physical.empCrewPod == nil else { return false }
    return physical.empSource == source || physical.identity == binding
      || game.commander.npcPersistence.logicalIdentity(for: physical.identity) == source
  }
}

func expectOriginalEMPCrewConserved(_ record: EMPHullRecord) {
  let escaped = record.pods.compactMap { $0.body.physical?.empCrewPod?.ordinal }
  let held = record.crewCaptures.flatMap(\.ordinals)
  let dead = record.deceasedOrdinals
  let all = record.aboardOrdinals + escaped + held + dead
  #expect(all.count == record.crewTotal && Set(all) == Set(0..<record.crewTotal))
  #expect(
    record.crewAboard + record.pods.count + record.capturedCrewCount + record.lostCrewCount
      == record.crewTotal)
  #expect(record.valid)
}
