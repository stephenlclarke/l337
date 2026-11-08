import Foundation
import Testing

@testable import L337Core

private var npcExample: URL {
  URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().appendingPathComponent("docs/mission-packs/profiled-skirmish")
}
private struct NPCFixture {
  let root: URL
  var directory: URL { root.appendingPathComponent("pack") }
  var save: URL { root.appendingPathComponent("save/commander.json") }
  init(edits: [(String, String)] = [], source: String? = nil) throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent("npc-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: npcExample, to: directory)
    let manifest = directory.appendingPathComponent("manifest.toml")
    var text = try String(contentsOf: manifest, encoding: .utf8)
    for (a, b) in edits { text = text.replacingOccurrences(of: a, with: b) }
    try text.write(to: manifest, atomically: true, encoding: .utf8)
    if let source {
      try source.write(
        to: directory.appendingPathComponent("scripts/main.lua"), atomically: true,
        encoding: .utf8)
    }
  }
  func clean() { try? FileManager.default.removeItem(at: root) }
  func game(launch: Bool = true) throws -> (Game, UUID) {
    let pack = try ScriptPackLibrary.read(directory)
    var game = Game(executive: false)
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.scriptPacks = [pack]
    let id = try game.acceptScriptMission(pack)
    if launch {
      game.launch()
      game.emitScriptEvent("station.undocked")
      game.drainScriptEvents()
    }
    return (game, id)
  }
}
private func npcIndex(_ game: Game, _ id: UUID, _ alias: String = "lead") throws -> Int {
  let identity = try #require(
    game.commander.scriptState.instances[id]?
      .ownedEncounters["opponents"]?.actors[alias]?.identity)
  let matchingIndex = game.bodies.firstIndex { $0.missionActorID == identity }
  return try #require(matchingIndex)
}
private func fillActualNPCSceneBudget(_ game: inout Game) throws -> Set<SpawnIdentity> {
  game.ensurePhysicalActors()
  let allocated = game.commander.flightSimulation.allocateSpawn()
  let sequence = try #require(allocated)
  let ownedPreparationRequired1 = game.gameplayContext()
  let context = try #require(ownedPreparationRequired1)
  let count = context.budget.maximum - context.budget.total
  let requests = (0..<count).map { index in
    SpawnRequest(
      identity: .init(
        system: context.system, visit: context.visit, sequence: sequence,
        member: UInt16(index), producer: .mission),
      population: .mission, hull: .cargo,
      position: context.player.position + .init(10_000, Double(index) * 200, 10_000),
      orientation: Basis3(), velocity: .init(0, 0, 0), npc: nil, rock: nil, payload: nil,
      priority: .mission)
  }
  let receipts = game.admitEncounterPlan(
    .init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: requests, atomic: true)], intents: []))
  let allSatisfied = receipts.count == count && receipts.allSatisfy { $0.actor != nil && $0.refusal == nil }
  try #require(allSatisfied)
  let ownedPreparationRequired2 = game.gameplayContext()
  let full = try #require(ownedPreparationRequired2)
  try #require(full.budget.total == full.budget.maximum)
  return Set(requests.map(\.identity))
}

private func npcIntent(
  _ mode: String, request: String = "test", target: String? = nil,
  offset: Vector3 = .init(0, 0, 0), speed: Double = 1, tolerance: Double = 10
) -> ScriptValue {
  var fields: [String: ScriptValue] = [
    "op": .string("actor.intent"), "id": .string(request),
    "encounter": .string("opponents"), "actor": .string("lead"), "mode": .string(mode),
    "offset": .array([.number(offset.x), .number(offset.y), .number(offset.z)]),
    "speed": .number(speed), "tolerance": .number(tolerance),
  ]
  if let target { fields["target"] = .string(target) }
  return .object(fields)
}
private func setNPCIntent(_ game: inout Game, id: UUID, command: ScriptValue) throws {
  var state = try #require(game.commander.scriptState.instances[id])
  let ownedPreparationRequired3 = game.scriptPack(for: state)
  let pack = try #require(ownedPreparationRequired3)
  _ = try game.applyScriptNPCIntent(command, pack: pack, state: &state)
  game.commander.scriptState.instances[id] = state
}

@Test func profiledShipsAdmitActualModelsComponentsAndSourceZerosWithoutPlayerDefaults() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  let (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  let npc = try #require(game.bodies[index].scriptNPC)
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.admitted == true)
  #expect(game.bodies[index].missiles == 0 && !game.bodies[index].ecmEnabled && npc.fuel == 0)
  #expect(npc.fit.definition.energy == 120 && npc.components["turret"]?.energy == 40)
  #expect(game.commander.scriptState.geometry.count == 2)
  #expect(game.bodies.filter { $0.scriptNPC != nil }.count == 2)
  #expect(game.bodies.filter { $0.scriptNPC != nil }.map(\.scriptNativeUnits) == [2, 2])
  let mesh = try #require(game.scriptNPCMesh(game.bodies[index]))
  #expect(mesh.vertices.count == 16 && mesh.faces.count == 12)
  #expect(
    mesh.materials.count == 2
      && mesh.faceMaterials == Array(repeating: 0, count: 6) + Array(repeating: 1, count: 6))
  #expect(mesh.vertices[0] == .init(-40, -20, -60))
  #expect(mesh.vertices[8] == .init(-6, 22, -9))
  #expect(game.commander.valid)
  // Identification consumes an actual owned module and the admitted actor's
  // authored fit name; the generic native hull label is not its identity.
  var basic = game
  try basic.commander.grantEquipment(
    TargetingTier.basic.equipmentName, at: .targetingCore,
    provenance: .grant("Target identity regression"))
  let hidden = try #require(basic.information(for: basic.bodies[index]))
  #expect(hidden.model == nil && hidden.identifier == "Target #\(basic.bodies[index].id)")
  var identified = game
  try identified.commander.grantEquipment(
    TargetingTier.identification.equipmentName, at: .targetingCore,
    provenance: .grant("Target identity regression"))
  let information = try #require(identified.information(for: identified.bodies[index]))
  #expect(information.model == npc.fit.definition.name)
  #expect(information.identifier == npc.fit.definition.name + " #\(identified.bodies[index].id)")
  var unavailable = identified
  let hash = try #require(npc.fit.models[npc.fit.definition.model])
  try #require(unavailable.commander.scriptState.geometry.removeValue(forKey: hash) != nil)
  let missingModel = try #require(unavailable.information(for: unavailable.bodies[index]))
  #expect(missingModel.model == "Unidentified craft")
  #expect(missingModel.model != npc.fit.definition.name)
}

@Test func licensedModelBytesInstallImmutablyAndTamperingLinksOrMissingGeometryAreDenied() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  let pack = try ScriptPackLibrary.read(fixture.directory)
  let installed = try ScriptPackLibrary.install(
    pack, directory: fixture.root.appendingPathComponent("library"))
  #expect(try ScriptPackLibrary.read(installed).digest == pack.digest)
  #expect(
    try ScriptPackLibrary.install(pack, directory: fixture.root.appendingPathComponent("library"))
      == installed)
  let model = fixture.directory.appendingPathComponent("models/hull.json")
  let original = try Data(contentsOf: model)
  try Data("{}".utf8).write(to: model)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
  try FileManager.default.removeItem(at: model)
  let elsewhere = fixture.root.appendingPathComponent("elsewhere.json")
  try original.write(to: elsewhere)
  try FileManager.default.createSymbolicLink(at: model, withDestinationURL: elsewhere)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
  try FileManager.default.removeItem(at: model)
  #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
}

@Test func npcManifestRejectsUnknownKeysUnboundedFitsAndUndeclaredCapability() throws {
  for edits in [
    [("\"profiled-encounters-v2\", ", "")],
    [("energy = 120.0", "energy = -1.0")],
    [("missiles = 0", "missiles = 33")],
    [("scale = 1.0", "scale = 1000000.0")],
    [("trackingRate = 2.0", "trackingRate = -1.0")],
    [("speed = 100.0", "teleport = true\nspeed = 100.0")],
    [("npc=\"training-craft\"", "npc=\"missing\"")],
    [("collisionDelay = 0.05", "collisionDelay = 3.0")],
    [("muzzle = {x=0.0,y=0.0,z=61.0}", "muzzle = {x=0.0,y=0.0,z=61.0,q=4}")],
  ] {
    let fixture = try NPCFixture(edits: edits)
    defer { fixture.clean() }
    #expect(throws: (any Error).self) { try ScriptPackLibrary.read(fixture.directory) }
  }
}

@Test func originalNativeDefinitionCodecRejectsMalformedFitsAndRequiresTheDeclaredDriveComponent()
  throws
{
  let original = try NativeInductionArkSource.profile()
  let physical = try OriginalHullPhysicalContract.saiga.get()
  let geometry = try ScriptPackLibrary.canonicalGeometry(physical.model.nativeDesign)
  let models = [original.model: ScriptPackLibrary.hash(geometry)]
  let originalFit = ScriptNPCFit(definition: original, models: models)
  let originalValid = original.valid
  let originalFitValid = originalFit.valid
  try #require(originalValid && originalFitValid)
  let encoder = JSONEncoder()
  encoder.outputFormatting = .sortedKeys
  let originalBytes = try encoder.encode(original)
  let rawOriginal = try JSONSerialization.jsonObject(with: originalBytes)
  let object = try #require(rawOriginal as? [String: Any])
  let decoder = JSONDecoder()
  decoder.nonConformingFloatDecodingStrategy = .convertFromString(
    positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")

  func check(_ label: String, _ input: [String: Any], expected: Bool) throws
    -> ScriptNPCDefinition
  {
    let bytes = try JSONSerialization.data(withJSONObject: input)
    let decoded = try decoder.decode(ScriptNPCDefinition.self, from: bytes)
    let definitionValid = decoded.valid
    let fit = ScriptNPCFit(definition: decoded, models: models)
    let fitValid = fit.valid
    #expect(definitionValid == expected, Comment(rawValue: label))
    #expect(fitValid == expected, Comment(rawValue: label))
    return decoded
  }

  let roundTrip = try check("authenticated original round trip", object, expected: true)
  #expect(roundTrip == original)
  let textCases: [(String, Any, Bool)] = [
    ("id", "1-invalid", false),
    ("name", String(repeating: "\u{1F680}", count: 20), true),
    ("name", String(repeating: "\u{1F680}", count: 21), false),
    ("source", "", false), ("source", String(repeating: "s", count: 4096), true),
    ("source", String(repeating: "s", count: 4097), false),
    ("basis", "", false), ("basis", String(repeating: "b", count: 4096), true),
    ("basis", String(repeating: "b", count: 4097), false),
    ("model", "catalogue:SH00x", false), ("model", "catalogue:SH999", false),
  ]
  for (index, entry) in textCases.enumerated() {
    let (field, value, expected) = entry
    var changed = object
    changed[field] = value
    _ = try check("text/model \(field) case \(index)", changed, expected: expected)
  }
  _ = try check("original after text/model inputs", object, expected: true)

  let physicalCases: [(String, Any, Bool)] = [
    ("scale", 0.0, false), ("scale", 0.001, true), ("scale", 1000.0, true),
    ("scale", 1000.001, false), ("energy", 0.0, false), ("energy", 0.001, true),
    ("energy", 1_000_000.0, true), ("energy", 1_000_000.001, false),
    ("speed", -1.0, false), ("fuel", 100_000.01, false),
    ("missiles", 32, true), ("missiles", 33, false),
    ("bounty", -1, false), ("bounty", 1_000_000, true), ("bounty", 1_000_001, false),
  ]
  for (field, value, expected) in physicalCases {
    var changed = object
    changed[field] = value
    _ = try check("physical \(field): \(value)", changed, expected: expected)
  }
  var infiniteScale = object
  infiniteScale["scale"] = "Infinity"
  let decodedInfinity = try check("decoded infinite scale", infiniteScale, expected: false)
  #expect(decodedInfinity.scale == Double.infinity)
  var nanEnergy = object
  nanEnergy["energy"] = "NaN"
  let decodedNaNEnergy = try check("decoded NaN energy", nanEnergy, expected: false)
  #expect(decodedNaNEnergy.energy.isNaN)
  let scalarFields = ["recharge", "speed", "acceleration", "pitch", "yaw", "roll", "fuel"]
  for (index, field) in scalarFields.enumerated() {
    var changed = object
    changed[field] = "NaN"
    let decoded = try check("decoded NaN \(field)", changed, expected: false)
    let values = [
      decoded.recharge, decoded.speed, decoded.acceleration, decoded.pitch,
      decoded.yaw, decoded.roll, decoded.fuel,
    ]
    #expect(values[index].isNaN)
  }
  for bound in [0.0, 100_000.0] {
    var changed = object
    for field in scalarFields { changed[field] = bound }
    _ = try check("all seven finite scalar boundary \(bound)", changed, expected: true)
  }
  _ = try check("original after physical inputs", object, expected: true)

  // Reuse a real declared gun, without constructing a Game or requesting a capture.
  let directory = npcExample.deletingLastPathComponent().appendingPathComponent("readme-capture")
  let pack = try ScriptPackLibrary.read(directory)
  let definitions = try #require(pack.manifest.npcs)
  let captureDefinitionCandidate = definitions.first { $0.id == "lead" }
  let captureDefinition = try #require(captureDefinitionCandidate)
  let declaredLasers = try #require(captureDefinition.lasers)
  let laserCandidate = declaredLasers.first { $0.id == "forward" }
  let laser = try #require(laserCandidate)
  let laserValid = laser.valid
  try #require(laserValid)
  let laserBytes = try encoder.encode(laser)
  let rawLaser = try JSONSerialization.jsonObject(with: laserBytes)
  let laserObject = try #require(rawLaser as? [String: Any])
  let components = try #require(object["components"] as? [[String: Any]])
  let driveComponentCandidate = components.first { ($0["id"] as? String) == "drive" }
  let driveComponent = try #require(driveComponentCandidate)
  var uniqueLasers: [[String: Any]] = []
  for index in 0..<17 {
    var weapon = laserObject
    weapon["id"] = "forward-\(index)"
    uniqueLasers.append(weapon)
  }
  for (count, expected) in [(16, true), (17, false)] {
    var changed = object
    changed["lasers"] = Array(uniqueLasers.prefix(count))
    _ = try check("unique declared laser count \(count)", changed, expected: expected)
  }
  var duplicateLasers = object
  duplicateLasers["lasers"] = [laserObject, laserObject]
  _ = try check("duplicate declared laser id", duplicateLasers, expected: false)
  var invalidLaser = laserObject
  invalidLaser["trackingRate"] = -1.0
  var invalidLaserProfile = object
  invalidLaserProfile["lasers"] = [invalidLaser]
  _ = try check("invalid declared laser", invalidLaserProfile, expected: false)
  var uniqueComponents = [driveComponent]
  for index in 1..<33 {
    var component = driveComponent
    component["id"] = "aux-\(index)"
    uniqueComponents.append(component)
  }
  for (count, expected) in [(32, true), (33, false)] {
    var changed = object
    changed["components"] = Array(uniqueComponents.prefix(count))
    _ = try check("unique declared component count \(count)", changed, expected: expected)
  }
  var duplicateComponents = object
  duplicateComponents["components"] = [driveComponent, driveComponent]
  _ = try check("duplicate declared component id", duplicateComponents, expected: false)
  var invalidComponent = driveComponent
  invalidComponent["energy"] = 0.0
  var invalidComponentProfile = object
  invalidComponentProfile["components"] = [invalidComponent]
  _ = try check("invalid declared component", invalidComponentProfile, expected: false)
  _ = try check("original after equipment inputs", object, expected: true)

  let drive = try #require(object["drive"] as? [String: Any])
  var absentDrive = object
  absentDrive.removeValue(forKey: "drive")
  _ = try check("absent optional drive with original component", absentDrive, expected: true)
  absentDrive["components"] = [] as [[String: Any]]
  _ = try check("absent optional drive without components", absentDrive, expected: true)
  for (field, value) in [("fuelUnit", "tonnes" as Any), ("rangeLightYears", 0.0 as Any)] {
    var invalidDrive = drive
    invalidDrive[field] = value
    var changed = object
    changed["drive"] = invalidDrive
    _ = try check("invalid drive \(field)", changed, expected: false)
  }
  var unmatchedDrive = drive
  unmatchedDrive["component"] = "missing"
  var unmatchedProfile = object
  unmatchedProfile["drive"] = unmatchedDrive
  _ = try check("valid drive terms without matching component", unmatchedProfile, expected: false)
  var missingComponent = object
  missingComponent["components"] = [] as [[String: Any]]
  _ = try check("removed required drive component", missingComponent, expected: false)
  _ = try check("original after drive inputs", object, expected: true)
  let finalBytes = try encoder.encode(original)
  #expect(finalBytes == originalBytes)
  let finalFitValid = originalFit.valid
  #expect(finalFitValid)
}

@Test func nativeFlightRequestsPreserveIdentityAndReachActualCoordinatesWithBoundedAcceleration()
  throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  let original = game.bodies[index]
  let goal = Vector3(0, 0, 3500)
  try setNPCIntent(&game, id: id, command: npcIntent("approach", offset: goal))
  let pack = try #require(game.scriptPacks.first)
  var state = try #require(game.commander.scriptState.instances[id])
  #expect(
    try game.applyScriptNPCIntent(npcIntent("flee", target: "player"), pack: pack, state: &state)
      == nil)
  #expect(game.bodies[index].scriptNPC?.intent?.mode == .approach)
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect(abs((game.bodies[index].scriptNPC?.velocity.length ?? 0) - 5) < 1e-8)
  #expect((game.bodies[index].position - original.position).length <= 0.5 + 1e-8)
  for _ in 0..<200 { game.advanceScriptNPCFlight(delta: 0.1) }
  let stationCandidate = game.bodies.first { $0.id == 0 }
  let station = try #require(stationCandidate)
  let actual = station.orientation.inverse(game.bodies[index].position - station.position)
  #expect((actual - goal).length <= 10.1)
  #expect(game.bodies[index].missionActorID == original.missionActorID)
  #expect(game.bodies[index].scriptNPC?.intent?.status == .reached)
  #expect(game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.arrived" }.count == 1)
  game.persistScriptActors()
  #expect(game.commander.valid)
}

@Test func followingAndFleeingUseTheSameOwnedTargetAndForeignOrMalformedIntentsCannotMoveShips()
  throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  try setNPCIntent(
    &game, id: id, command: npcIntent("follow", target: "wing", offset: .init(100, 0, 0)))
  for _ in 0..<30 { game.advanceScriptNPCFlight(delta: 0.1) }
  #expect(game.bodies[index].scriptNPC?.velocity.length ?? 0 > 0)
  #expect(game.bodies[index].orientation.validRotation)
  try setNPCIntent(&game, id: id, command: npcIntent("flee", request: "flee", target: "player"))
  for _ in 0..<40 { game.advanceScriptNPCFlight(delta: 0.1) }
  #expect(game.bodies[index].scriptNPC?.intent?.mode == .flee)
  let before = game.bodies
  #expect(throws: (any Error).self) {
    try setNPCIntent(&game, id: id, command: npcIntent("follow", request: "bad", target: "foreign"))
  }
  #expect(throws: (any Error).self) {
    try setNPCIntent(&game, id: id, command: npcIntent("approach", request: "bad", speed: 2))
  }
  #expect(game.bodies == before)
  let wing = try npcIndex(game, id, "wing")
  try setNPCIntent(&game, id: id, command: npcIntent("attack", request: "lost", target: "wing"))
  game.bodies[wing].energy = 0
  game.advanceScriptNPCFlight(delta: 0.1)
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect(game.bodies[index].scriptNPC?.intent?.status == .lost)
  #expect(
    game.commander.scriptState.pendingEvents.filter { $0.kind == "actor.target.lost" }.count == 1)
}

// This measures only the selected target's geometry; it does not prove full-scene occlusion.
private func measuredNPCContact(_ game: Game, targetID: Int, from: Vector3) throws
  -> MissionCollisionContact?
{
  let excluded = Set(game.bodies.filter { $0.id != targetID }.map(\.id))
  return try game.nearestMissionCollision(
    from: from, direction: .init(0, 0, 1), range: 3000, radius: 0,
    excludingBodyIDs: excluded, includePlayer: false)
}

private func applyActualNPCLaser(
  _ game: inout Game, sourceID: Int, targetID: Int, targetPart: String? = nil
) throws {
  let proof = try makeActualNPCLaserProof(
    &game, sourceID: sourceID, targetID: targetID, targetPart: targetPart)
  let receipt = try game.applyMissionImpact(proof)
  game.projectScriptMissionImpact(receipt)
}

private func makeActualNPCLaserProof(
  _ game: inout Game, sourceID: Int, targetID: Int, targetPart: String?
) throws -> MissionNativeLaserProof {
  let sourceCandidate = game.bodies.first { $0.id == sourceID }
  let source = try #require(sourceCandidate)
  let targetCandidate = game.bodies.first { $0.id == targetID }
  let target = try #require(targetCandidate)
  let npc = try #require(source.scriptNPC)
  let weapon = try #require(npc.fit.definition.lasers?.first)
  let muzzle = source.position + source.orientation.apply(weapon.muzzle * npc.fit.definition.scale)
  var aim = target.position
  if let targetPart {
    let fit = try #require(target.scriptNPC?.fit.definition)
    let partCandidate = fit.components?.first { $0.id == targetPart }
    let part = try #require(partCandidate)
    aim = aim + target.orientation.apply(part.position * fit.scale)
  }
  let proof = try game.makeMissionNativeLaserProof(
    sourceBodyID: sourceID, weapon: weapon, component: nil,
    muzzle: muzzle, direction: (aim - muzzle).unit)
  try #require(proof.hit?.target == .body(targetID) && proof.victimPart == targetPart)
  return proof
}

@Test func componentRayHitsUseMeasuredGeometryAndCannotBecomeHullDeathOrPlayerBounty() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  try verifyComponentRayContactsAndBounty(&game, id: id)
}

private func verifyComponentRayContactsAndBounty(_ game: inout Game, id: UUID) throws {
  let (targetID, kills) = try verifyMeasuredComponentRayContacts(&game, id: id)
  try applyAllyHullLaserImpacts(&game, id: id, targetID: targetID)
  verifyAllyHullDestructionWithoutPlayerBounty(&game, id: id, kills: kills)
}

private func verifyMeasuredComponentRayContacts(_ game: inout Game, id: UUID) throws
  -> (Int, Int)
{
  let index = try npcIndex(game, id)
  let targetID = game.bodies[index].id
  game.bodies[index].position = .init(0, 0, 2000)
  game.bodies[index].orientation = Basis3()
  game.celestials = []
  game.scriptEventsDeferred = true
  game.ensurePhysicalActors()
  let kills = game.commander.kills
  let measured = try measuredNPCContact(game, targetID: targetID, from: .init(0, 25, 0))
  let hit = try #require(measured)
  #expect(hit.hit.target == .body(targetID) && hit.victimPart == "turret")
  #expect(abs(hit.hit.distance - 1991) < 1e-8)
  let component = try #require(game.bodies[index].scriptNPC?.components["turret"]?.identity)
  let player = try #require(game.commander.flightSimulation.player)
  let laser = try #require(game.commander.laser(on: .front))
  let damage = game.commander.laserDamage(against: game.bodies[index].hull, mount: .front)
  try #require(damage > 0)
  // Use actual fitted player damage and a fresh sealed contact/origin for every impact.
  for _ in 0..<Int(ceil(40 / damage)) {
    let queried = try measuredNPCContact(game, targetID: targetID, from: .init(0, 25, 0))
    let current = try #require(queried)
    let allocated = game.makeAttackOrigin(owner: player)
    let origin = try #require(allocated)
    let receipt = try game.applyNativeMissionContact(
      current, origin: origin, damage: damage, laser: laser, mount: .front,
      emissionPosition: game.commander.flightSimulation.pose.position)
    game.projectScriptMissionImpact(receipt)
  }
  #expect(game.bodies[index].energy == 120)
  #expect(game.bodies[index].scriptNPC?.components["turret"]?.energy == 0)
  #expect(game.scriptNPCMesh(game.bodies[index])?.faces.count == 6)
  #expect(
    game.commander.scriptState.pendingEvents.filter { $0.kind == "component.destroyed" }.count == 1)
  #expect(
    game.commander.scriptState.pendingEvents.last?.values["component_id"]
      == .string(component.uuidString))
  let destroyedPart = try measuredNPCContact(game, targetID: targetID, from: .init(0, 25, 0))
  #expect(destroyedPart == nil)
  // A ray through the bounding sphere but outside the measured hull must miss.
  let missedHull = try measuredNPCContact(game, targetID: targetID, from: .init(50, 0, 0))
  #expect(missedHull == nil)
  let measuredHull = try measuredNPCContact(game, targetID: targetID, from: .init(0, 0, 0))
  let hull = try #require(measuredHull)
  #expect(hull.victimPart == nil && abs(hull.hit.distance - 1940) < 1e-8)
  return (targetID, kills)
}

private func applyAllyHullLaserImpacts(_ game: inout Game, id: UUID, targetID: Int) throws {
  let ally = try npcIndex(game, id, "wing")
  let allyID = game.bodies[ally].id
  game.bodies[ally].position = .init(0, 0, 1000)
  game.bodies[ally].orientation = Basis3()
  let actualWeapon = try #require(game.bodies[ally].scriptNPC?.fit.definition.lasers?.first)
  for _ in 0..<Int(ceil(120 / actualWeapon.damage)) {
    try applyActualNPCLaser(&game, sourceID: allyID, targetID: targetID)
  }
}

private func verifyAllyHullDestructionWithoutPlayerBounty(_ game: inout Game, id: UUID, kills: Int)
{
  game.resolveDestroyed()
  #expect(game.commander.kills == kills)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors["lead"]?.presence
      == .destroyed)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.destroyed == false)
}

private func aimNPCAtPlayer(_ game: inout Game, id: UUID) throws -> Int {
  let index = try npcIndex(game, id)
  game.bodies[index].position = .init(0, 0, 1000)
  var facing = Basis3()
  facing.rotate(pitch: 0, roll: 0, yaw: .pi)
  game.bodies[index].orientation = facing
  try setNPCIntent(
    &game, id: id,
    command: npcIntent("attack", request: "fire-test", target: "player", speed: 0))
  return index
}

// Use the admitted current starting hull for the example's real gun-interception units.
private func declaredNPCGunGame(_ fixture: NPCFixture) throws -> (Game, UUID) {
  let pack = try ScriptPackLibrary.read(fixture.directory)
  var game = Game(executive: false)
  try OriginalDetailedHullStage.requireRuntime(game.commander.shipID)
  game.commander.fuel = 70
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  return (game, id)
}

@Test func npcLasersAndPlasmaSpendActualEnergyHeatAndCooldownAndDamageRealColliders() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try declaredNPCGunGame(fixture)
  let index = try aimNPCAtPlayer(&game, id: id)
  let shield = game.frontShield
  game.advanceScriptNPCWeapons(delta: 0.1)
  #expect(game.frontShield == shield - 6)
  #expect(game.bodies[index].energy == 119.5)
  #expect(game.bodies[index].scriptNPC?.guns["forward"]?.heat == 3.2)
  #expect(game.bodies[index].scriptNPC?.shots == 2)
  #expect(game.bodies.filter { $0.scriptShot != nil }.count == 1)
  let projectileCandidate = game.bodies.first { $0.scriptShot != nil }
  let projectile = try #require(projectileCandidate)
  #expect(abs((projectile.scriptShot?.velocity.length ?? 0) - 2000) < 1e-8)
  #expect(projectile.scriptShot?.damage == 15 && projectile.scriptShot?.lifetime == 3)
  let shotMesh = try #require(game.scriptNPCMesh(projectile))
  #expect(shotMesh.vertices.count == 6 && shotMesh.faces.count == 8)
  let allSatisfied2 = shotMesh.vertices.allSatisfy { abs($0.length - 2) < 1e-8 }
  #expect(allSatisfied2)
  #expect(shotMesh.materials.first?.emissive == true)
  #expect(shotMesh.materials.first?.colour == Ink.redOrange.rawValue)
  for _ in 0..<5 { game.advanceScriptNPCShots(delta: 0.1) }
  #expect(game.frontShield == shield - 21)
  game.resolveDestroyed()
  #expect(!game.bodies.contains { $0.scriptShot != nil })
  game.bodies[index].energy = 0.4
  let shots = game.bodies[index].scriptNPC?.shots
  game.advanceScriptNPCWeapons(delta: 0.1)
  // Zero-cost turret can fire, but the energy-costing forward laser cannot.
  #expect(game.bodies[index].scriptNPC?.guns["forward"]?.cooldown == 0)
  #expect(game.bodies[index].energy == 0.4)
  #expect(game.bodies[index].scriptNPC?.shots == shots)
}

@Test func plasmaHitsTheActualInterveningShipAndECMCannotDestroyOrClaimPlasma() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try declaredNPCGunGame(fixture)
  _ = try aimNPCAtPlayer(&game, id: id)
  let wing = try npcIndex(game, id, "wing")
  game.bodies[wing].position = .init(0, 25, 700)
  game.bodies[wing].orientation = Basis3()
  let shield = game.frontShield
  game.advanceScriptNPCWeapons(delta: 0.1)
  try game.commander.grantEquipment(
    "E.C.M. System", at: .utility(.ecm), provenance: .grant("npc-ecm-fixture"))
  game.ecm()
  let containsMatch = game.bodies.contains { $0.scriptShot != nil }
  #expect(containsMatch)
  for _ in 0..<3 { game.advanceScriptNPCShots(delta: 0.1) }
  #expect(game.bodies[wing].energy == 105)
  #expect(game.frontShield == shield - 6)
  for _ in 0..<32 { game.ecmControl.advance() }
  #expect(
    !game.ecmControl.events.contains {
      if case .missilesDestroyed = $0.announcement { true } else { false }
    })
}

@Test func profiledConditionAndLiveProjectilesSurviveCameraSaveAndDockWithoutConstructorRefill()
  async throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try aimNPCAtPlayer(&game, id: id)
  game.advanceScriptNPCWeapons(delta: 0.1)
  game.advanceScriptNPCShots(delta: 0.1)
  game.bodies[index].scriptNPC?.components["turret"]?.energy = 17
  game.bodies[index].scriptNPC?.velocity = .init(5, 0, 0)
  game.bodies[index].energy = 97
  let identity = game.bodies[index].missionActorID
  let shot = try #require(game.bodies.first { $0.scriptShot != nil }?.scriptShot)
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let saved = await runtime.snapshot()
  #expect(saved.commander.valid && saved.scriptWorldSave.consistent(with: saved.commander))
  // Predict only the native station's fresh scene addresses before reading the save.
  var expectedBodies = saved.bodies
  var expectedFlight = saved.commander.flightSimulation
  var expectedStations = try #require(saved.commander.nativeStations)
  let stationIndices = saved.bodies.indices.filter {
    saved.bodies[$0].nativeStationIdentity != nil
  }
  try #require(!stationIndices.isEmpty)
  let allocatedSpawn = expectedFlight.allocateSpawn()
  let spawn = try #require(allocatedSpawn)
  for (member, index) in stationIndices.enumerated() {
    let original = saved.bodies[index]
    let station = try #require(original.nativeStationIdentity)
    let physical = try #require(original.physical)
    let allocatedActor = expectedFlight.allocateActor()
    let actor = try #require(allocatedActor)
    var expected = original
    expected.id = saved.nextBodyID + member
    expected.physical = .init(
      identity: actor, population: physical.population, npc: physical.npc,
      velocity: physical.velocity, laserCooldown: physical.laserCooldown,
      rock: physical.rock, payload: physical.payload, attackOrigin: physical.attackOrigin,
      emissionPosition: physical.emissionPosition, deathOrigin: physical.deathOrigin,
      deathIncidentID: physical.deathIncidentID, ordnance: physical.ordnance,
      spawnIdentity: .init(
        system: saved.systemIdentity, visit: expectedFlight.visit, sequence: spawn,
        member: UInt16(member), producer: .mission),
      blocksNavalEncounter: physical.blocksNavalEncounter,
      catalogueShipID: physical.catalogueShipID, angularVelocity: physical.angularVelocity,
      canonicalSpin: physical.canonicalSpin, salvage: physical.salvage,
      empSource: physical.empSource, empCrewPod: physical.empCrewPod,
      suspendedNPCIntention: physical.suspendedNPCIntention)
    expectedBodies[index] = expected
    try expectedStations.ledger.rebind(station, to: .init(actor: actor, bodyID: expected.id))
  }
  let restored = GameRuntime(game: game)
  try await restored.load(from: fixture.save)
  let loaded = await restored.snapshot()
  #expect(loaded.bodies == expectedBodies)
  #expect(loaded.commander.flightSimulation == expectedFlight)
  #expect(loaded.commander.nativeStations == expectedStations)
  #expect(loaded.nextBodyID == saved.nextBodyID + stationIndices.count)
  for station in loaded.bodies where station.nativeStationIdentity != nil {
    #expect(loaded.nativeStationBodyIsCurrent(station))
  }
  #expect(loaded.commander.scriptState == saved.commander.scriptState)
  var docked = loaded
  docked.dock()
  #expect(docked.commander.scriptState.projectiles[shot.identity]?.presence == .unloaded)
  let before = docked.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[
    "lead"]?.body
  docked.launch()
  let resumed = try npcIndex(docked, id)
  #expect(docked.bodies[resumed].missionActorID == identity)
  #expect(docked.bodies[resumed].energy == 97)
  #expect(docked.bodies[resumed].scriptNPC?.components["turret"]?.energy == 17)
  #expect(docked.bodies[resumed].scriptNPC?.shots == before?.scriptNPC?.shots)
  #expect(docked.bodies.first { $0.scriptShot?.identity == shot.identity }?.scriptShot?.age == 0.1)
  #expect(docked.commander.valid)
}

@Test func wholeProfiledCohortCountsSolidComponentsAndRetainsThePreparedPlanWhileBlocked() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game(launch: false)
  game.launch()
  let stationCandidate2 = game.bodies.first { $0.id == 0 }
  let station = try #require(stationCandidate2)
  _ = try admitMissionTestObstruction(
    &game, hull: .asteroid,
    position: station.position + station.orientation.apply(.init(0, 0, 3000)))
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let prepared = try #require(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"])
  #expect(!prepared.admitted && prepared.actors.values.allSatisfy { $0.presence == .prepared })
  #expect(!game.bodies.contains { $0.scriptNPC != nil })
  let identities = prepared.actors.mapValues(\.identity)
  let components = prepared.actors.mapValues { $0.body.scriptNPC?.components["turret"]?.identity }
  game.bodies = [station]
  _ = try fillActualNPCSceneBudget(&game)
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  #expect(!game.bodies.contains { $0.scriptNPC != nil })
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors.mapValues(
      \.identity) == identities)
  game.bodies = [station]
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.admitted == true)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors.mapValues(
      \.identity) == identities)
  #expect(
    game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors.mapValues {
      $0.body.scriptNPC?.components["turret"]?.identity
    } == components)
}

@Test func rejectedLaterCommandCannotLeakProfileModelsBodiesIntentsOrMoney() throws {
  let fixture = try NPCFixture(
    source: """
      local M={}
      function M.accepted(e,w,d) return {data=d,commands={}} end
      function M.undocked(e,w,d) return {data=d,commands={{op='encounter.ensure',id='opponents'},
        {op='actor.intent',id='move',encounter='opponents',actor='lead',mode='attack',target='player',offset={0,0,0},speed=1,tolerance=100},
        {op='credits',id='overspend',amount=-100000}}} end
      function M.admitted(e,w,d) return {data=d,commands={}} end
      function M.destroyed(e,w,d) return {data=d,commands={}} end
      function M.contact(e,w,d) return {data=d,commands={}} end
      function M.confirm(e,w,d) return {data=d,commands={}} end
      return M
      """
  )
  defer { fixture.clean() }
  var (game, id) = try fixture.game(launch: false)
  game.launch()
  let bodies = game.bodies
  let credits = game.commander.credits
  game.emitScriptEvent("station.undocked")
  #expect(game.bodies == bodies && game.commander.credits == credits)
  #expect(game.commander.scriptState.geometry.isEmpty)
  #expect(game.commander.scriptState.instances[id]?.ownedEncounters.isEmpty == true)
  #expect(game.commander.scriptState.instances[id]?.suspension != nil)
  #expect(!game.commander.scriptState.pendingEvents.contains { $0.kind == "encounter.admitted" })
}

@Test func changingIntentInARotatedFrameCannotRotateOrResetTheActualVelocity() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try npcIndex(game, id)
  let stationCandidate3 = game.bodies.firstIndex { $0.id == 0 }
  let station = try #require(stationCandidate3)
  game.bodies[station].orientation.rotate(pitch: 0.3, roll: 0.4, yaw: 0.5)
  game.bodies[index].scriptNPC?.velocity = .init(10, 4, 2)
  game.persistScriptActors()
  let canonical = game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[
    "lead"]?.body.scriptNPC?.velocity
  #expect(canonical != game.bodies[index].scriptNPC?.velocity)
  try setNPCIntent(&game, id: id, command: npcIntent("hold", request: "brake"))
  #expect(game.bodies[index].scriptNPC?.velocity == .init(10, 4, 2))
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect((game.bodies[index].scriptNPC?.velocity.length ?? 0) < Vector3(10, 4, 2).length)
  let snapshot = game.scriptNPCSnapshot(game.bodies[index].scriptNPC)
  #expect(snapshot["name"]?.string == "Profiled training opponent")
  #expect(snapshot["components"]?["turret"]?["identity"]?.string != nil)
}

@Test func profileSceneSaveRejectsAlteredModelHashForeignShotOwnerAndDuplicateComponentIdentity()
  throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  try verifyProfileSceneSaveRejections(&game, id: id)
}

private func verifyProfileSceneSaveRejections(_ game: inout Game, id: UUID) throws {
  let index = try aimNPCAtPlayer(&game, id: id)
  game.advanceScriptNPCWeapons(delta: 0.1)
  game.persistScriptActors()
  #expect(game.commander.valid)
  var changed = game
  let hash = try #require(changed.commander.scriptState.geometry.keys.first)
  changed.commander.scriptState.geometry.removeValue(forKey: hash)
  #expect(!changed.commander.valid)
  changed = game
  let wing = try npcIndex(changed, id, "wing")
  let component = try #require(changed.bodies[index].scriptNPC?.components["turret"])
  changed.bodies[wing].scriptNPC?.components["turret"] = component
  changed.persistScriptActors()
  #expect(!changed.commander.valid)
  let encodedState = try JSONEncoder().encode(game.commander.scriptState)
  let rawState = try JSONSerialization.jsonObject(with: encodedState)
  var json = try #require(rawState as? [String: Any])
  // UUID dictionaries are encoded as alternating key/value arrays by Foundation.
  var projectiles = try #require(json["savedProjectiles"] as? [Any])
  var record = try #require(projectiles[1] as? [String: Any])
  var body = try #require(record["body"] as? [String: Any])
  var shot = try #require(body["scriptShot"] as? [String: Any])
  shot["owner"] = UUID().uuidString
  body["scriptShot"] = shot
  record["body"] = body
  projectiles[1] = record
  json["savedProjectiles"] = projectiles
  #expect(throws: MissionNativeBridgeError.invalidArchive) {
    try JSONDecoder().decode(
      ScriptEngineState.self, from: JSONSerialization.data(withJSONObject: json))
  }
}

@Test func sweptSphereContactIncludesFacesEdgesCornersAndNonunitLocalDirections() {
  let a = Vector3(-10, -10, 100)
  let b = Vector3(10, -10, 100)
  let c = Vector3(0, 10, 100)
  func hit(_ origin: Vector3, range: Double = 200) -> Double? {
    ScriptSweptCollision.triangle(
      origin: origin, direction: .init(0, 0, 1), range: range,
      radius: 2, a: a, b: b, c: c)
  }
  #expect(abs((hit(.init(0, 0, 0)) ?? 0) - 98) < 1e-8)
  #expect(abs((hit(.init(0, -11, 0)) ?? 0) - (100 - sqrt(3))) < 1e-8)
  #expect(abs((hit(.init(11, -11, 0)) ?? 0) - (100 - sqrt(2))) < 1e-8)
  #expect(hit(.init(12, -12, 0)) == nil)
  #expect(hit(.init(0, 0, 0), range: 97) == nil)
  #expect(hit(.init(0, 0, 101)) == 0)
  #expect(
    ScriptSweptCollision.triangle(
      origin: .init(0, -11, 99), direction: .init(1, 0, 0),
      range: 10, radius: 2, a: a, b: b, c: c) == 0)
  #expect(
    ScriptSweptCollision.sphere(origin: .init(3, 0, 0), direction: .init(-2, 0, 0), radius: 1) == 1)
  #expect(
    ScriptSweptCollision.sphere(origin: .init(0, 0, 0), direction: .init(0, 0, 0), radius: 1) == 0)
  #expect(
    ScriptSweptCollision.sphere(origin: .init(3, 0, 0), direction: .init(0, 0, 0), radius: 1) == nil
  )
}

@Test func aClassicConeNearMissCannotInterceptAnActualProfiledHullHit() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  game.speed = 0
  try game.commander.grantEquipment(
    LaserKind.naval.equipmentName, at: .laser(.front), provenance: .grant("npc-naval-fixture"))
  let ordinaryCandidate = game.bodies.firstIndex { $0.id == 1 }
  let ordinary = try #require(ordinaryCandidate)
  game.bodies[ordinary].position = .init(80, 0, 1400)
  let oldEnergy = game.bodies[ordinary].energy
  let index = try npcIndex(game, id)
  game.bodies[index].position = .init(0, 0, 2500)
  var controls = Controls()
  controls.fire = true
  game.tick(delta: 0.1, controls: controls)
  #expect(game.bodies[ordinary].energy == oldEnergy)
  #expect(!game.bodies[ordinary].hostile)
  #expect(game.bodies[index].energy < 120)
}

@Test func catalogueNpcGeometryUsesMeasuredRawVerticesAndNeverChangesThePlayerFit() throws {
  let fixture = try NPCFixture(edits: [
    ("model = \"asset:hull\"", "model = \"catalogue:SH128\""),
    ("scale = 1.0", "scale = 1.6"),
  ])
  defer { fixture.clean() }
  let pack = try ScriptPackLibrary.read(fixture.directory)
  var game = Game(executive: false)
  try OriginalDetailedHullStage.requireRuntime(game.commander.shipID)
  game.commander.fuel = game.commander.fuelCapacity
  game.energy = game.commander.performance.energy
  game.frontShield = game.commander.shieldCapacity
  game.rearShield = game.commander.rearShieldCapacity
  game.screen = .status
  try game.commander.prepareEquipment(legacy: false)
  game.scriptPacks = [pack]
  let id = try game.acceptScriptMission(pack)
  game.launch()
  game.emitScriptEvent("station.undocked")
  game.drainScriptEvents()
  let body = game.bodies[try npcIndex(game, id)]
  let before = game.commander
  let playerMesh = game.commander.playerMesh
  let mesh = try #require(game.scriptNPCMesh(body))
  let raw = try #require(ShipCatalogue.ship("SH128")?.design.rawMesh)
  #expect(mesh.vertices.count > raw.vertices.count)
  #expect(Array(mesh.vertices.prefix(raw.vertices.count)) == raw.vertices.map { $0 * 1.6 })
  #expect(body.scriptNPC?.fit.models["catalogue:SH128"] != nil)
  #expect(game.commander.shipID == before.shipID)
  let transporter = try #require(ShipCatalogue.ship("SH128"))
  #expect(transporter.game?.cargo == 150)
  let historicalNPCCandidate = transporter.profiles.first { $0.id == "O08-oolite_template_transporter" }
  let historicalNPC = try #require(historicalNPCCandidate)
  #expect(historicalNPC.fields.first { $0.key == "max_cargo" }?.number == 12)
  #expect(game.commander == before)
  #expect(game.commander.playerMesh.vertices == playerMesh.vertices)
  #expect(game.commander.playerMesh.faces == playerMesh.faces)
  #expect(game.commander.playerMesh.details == playerMesh.details)
  #expect(game.commander.playerMesh.materials == playerMesh.materials)
  #expect(game.commander.playerMesh.faceMaterials == playerMesh.faceMaterials)
  #expect(game.commander.valid)
}

@Test func projectilesRespectLifetimeAndWeaponsWaitForRealWorldCapacityWithoutSpending() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let index = try aimNPCAtPlayer(&game, id: id)
  game.bodies[index].scriptNPC?.guns["forward"]?.heat = 256
  let originalEnergy = game.bodies[index].energy
  let fillers = try fillActualNPCSceneBudget(&game)
  game.advanceScriptNPCWeapons(delta: 0.01)
  #expect(!game.bodies.contains { $0.scriptShot != nil })
  #expect(game.bodies[index].scriptNPC?.shots == 0 && game.bodies[index].energy == originalEnergy)
  game.bodies.removeAll { body in
    body.physical?.spawnIdentity.map { fillers.contains($0) } ?? false
  }
  game.advanceScriptNPCWeapons(delta: 0.01)
  let projectileIndexCandidate = game.bodies.firstIndex { $0.scriptShot != nil }
  let projectileIndex = try #require(projectileIndexCandidate)
  let shotIdentity = try #require(game.bodies[projectileIndex].scriptShot?.identity)
  game.bodies[projectileIndex].position = .init(5000, 5000, 5000)
  game.persistScriptActors()
  #expect(game.commander.scriptState.projectiles[shotIdentity] != nil)
  for _ in 0..<31 { game.advanceScriptNPCShots(delta: 0.1) }
  game.resolveDestroyed()
  #expect(!game.bodies.contains { $0.scriptShot?.identity == shotIdentity })
  #expect(game.commander.scriptState.projectiles[shotIdentity] == nil)
}

@Test func actualNpcCrossfireRendersLiveRootAndComponentLaserColoursAndDisablesDestroyedTurrets()
  throws
{
  let edits = [
    ("kind = \"plasma\"", "kind = \"laser\""),
    ("projectileSpeed = 2000.0\n", ""), ("lifetime = 3.0\n", ""),
    ("collisionRadius = 2.0\n", ""), ("collisionDelay = 0.05\n", ""),
    ("maximumHeat = 256.0", "maximumHeat = 256.0\ncolour = 4281597951"),
  ]
  let fixture = try NPCFixture(edits: edits)
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  let (shooter, target) = try arrangeActualNPCCrossfire(&game, id: id)
  // Keep future rendering copies and verification temporaries out of the deep emission call.
  game.advanceScriptNPCWeapons(delta: 0.1)
  verifyActualNPCCrossfireFirstEmission(&game, shooter: shooter, target: target)
  let intactHull = verifyActualNPCCrossfireBeams(&game, shooter: shooter, expected: 2)
  try destroyActualNPCCrossfireTurret(&game, shooter: shooter, target: target)
  let damagedHull = verifyActualNPCCrossfireBeams(&game, shooter: shooter, expected: 1)
  // The implicit draw path must also remove the actual destroyed component's hull panels.
  #expect(intactHull != damagedHull)
}

private func arrangeActualNPCCrossfire(_ game: inout Game, id: UUID) throws -> (Int, Int) {
  let shooter = try npcIndex(game, id)
  let target = try npcIndex(game, id, "wing")
  game.bodies[shooter].position = .init(200, 0, 1000)
  game.bodies[target].position = .init(-200, 0, 1500)
  var pose = Basis3()
  pose.z = Vector3(-400, 0, 500).unit
  pose.x = pose.y.cross(pose.z)
  game.bodies[shooter].orientation = pose
  try setNPCIntent(
    &game, id: id, command: npcIntent("attack", request: "crossfire", target: "wing", speed: 0))
  return (shooter, target)
}

private func verifyActualNPCCrossfireFirstEmission(_ game: inout Game, shooter: Int, target: Int) {
  #expect(game.bodies[shooter].scriptNPC?.shots == 2)
  #expect(game.bodies[target].energy == 99)
  game.commander.shipDisplayStyle = .shadedPanels
}

private func verifyActualNPCCrossfireBeams(_ game: inout Game, shooter: Int, expected: Int)
  -> [Graphic]
{
  func colouredBeams(_ frame: Frame) -> Int {
    frame.graphics.filter {
      if case .panel(let panel) = $0 { return panel.colour == 4_281_597_951 }
      return false
    }.count
  }
  var frame = Frame()
  Display.draw(game.bodies[shooter], game: game, into: &frame)
  #expect(colouredBeams(frame) == expected)
  return frame.graphics.filter {
    if case .panel(let panel) = $0 { return panel.colour != 4_281_597_951 }
    return true
  }
}

private func destroyActualNPCCrossfireTurret(_ game: inout Game, shooter: Int, target: Int) throws {
  let actualWeapon = try #require(game.bodies[target].scriptNPC?.fit.definition.lasers?.first)
  for _ in 0..<Int(ceil(40 / actualWeapon.damage)) {
    try applyActualNPCLaser(
      &game, sourceID: game.bodies[target].id, targetID: game.bodies[shooter].id,
      targetPart: "turret")
  }
}

private func profiledPatrolHasLawfulHullContact(_ game: Game, mission: UUID, actor: UUID) throws
  -> Bool
{
  guard game.screen == .front, try campaignPatrolOutsideStationZone(game),
    let context = game.gameplayContext(),
    let contact = try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 6000, radius: 0,
      excludingBodyIDs: [], includePlayer: false),
    contact.victimPart == nil, contact.componentUUID == nil,
    case .body(let bodyID) = contact.hit.target,
    let body = game.bodies.first(where: { $0.id == bodyID }),
    body.missionInstanceID == mission, body.missionActorID == actor, body.scriptNPC != nil,
    game.commander.scriptState.instances[mission]?.ownedEncounters["opponents"]?.actors.values
      .contains(where: {
        $0.identity == actor && $0.body.id == bodyID && $0.presence == .present
      }) == true
  else { return false }
  let actualEntitlement = game.combatMissionEntitlement(
    contact.hit.target, owner: context.player.identity, context: context)
  let entitlement = try #require(actualEntitlement)
  try #require(
    entitlement.owner == context.player.identity && entitlement.victim == body.physical?.identity)
  try #require(entitlement.authorizesAttack && entitlement.amountTenths == 50)
  return true
}

@Test func nativeProfiledPatrolUsesActualPlayerLasersAutomaticDockingAndStationConfirmation()
  async throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  try game.commander.grantEquipment(
    TargetingTier.military.equipmentName, at: .targetingCore,
    provenance: .grant("npc-targeting-fixture"))
  try game.commander.grantEquipment(
    LaserKind.naval.equipmentName, at: .laser(.front), provenance: .grant("npc-naval-fixture"))
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let legalBefore = game.commander.legal
  try #require(legalBefore == 0)
  for alias in ["lead", "wing"] {
    let identity = try #require(
      game.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[alias]?
        .identity)
    for _ in 0..<12 {
      await runtime.key("tab")
      if await runtime.snapshot().autoTargetBody?.missionActorID == identity { break }
    }
    #expect(await runtime.snapshot().autoTargetBody?.missionActorID == identity)
    for _ in 0..<200 {
      let frame = await runtime.advance(delta: 0.02)
      if frame.autoPilot.status == "TRACKING TARGET" { break }
    }
    var controls = Controls()
    for _ in 0..<300 {
      // Fly the real outbound path before requesting an actual assigned-hull shot.
      let aiming = await runtime.snapshot()
      controls.fire = try profiledPatrolHasLawfulHullContact(aiming, mission: id, actor: identity)
      await runtime.setControls(controls)
      let frame = await runtime.advance(delta: 0.05)
      if frame.commander.scriptState.instances[id]?.ownedEncounters["opponents"]?.actors[alias]?
        .presence == .destroyed
      {
        break
      }
    }
    await runtime.setControls(Controls())
    #expect(
      await runtime.snapshot().commander.scriptState.instances[id]?.ownedEncounters["opponents"]?
        .actors[alias]?.presence == .destroyed)
  }
  let won = await runtime.snapshot()
  #expect(won.commander.legal == legalBefore)
  #expect(won.commander.kills == 2)
  #expect(won.commander.scriptState.instances[id]?.data["phase"] == .string("report"))
  #expect(won.commander.scriptState.instances[id]?.suspension == nil)
  let beforeStationSelection = actualStationGuidanceDiagnostic(won)
  var stationCycle: [String] = []
  for attempt in 0...won.bodies.count {
    await runtime.key("tab")
    let selected = await runtime.snapshot()
    if stationCycle.count < 16 {
      stationCycle.append(
        "\(attempt):target=\(String(describing: selected.autoPilot.targetID)),actor=\(String(describing: selected.autoPilot.targetActor)),docking=\(selected.dockingComputer)"
      )
    }
    if selected.autoTargetBody?.id == 0 { break }
  }
  var returned = await runtime.snapshot()
  try #require(
    returned.autoTargetBody?.id == 0 && returned.autoTargetBody?.hull == .station
      && returned.dockingComputer,
    Comment(
      rawValue:
        "Original station selection: target=\(String(describing: returned.autoPilot.targetID))"
        + ",dockingComputer=\(returned.dockingComputer),screen=\(returned.screen)"
        + ",legal=\(returned.commander.legal),energy=\(returned.energy),bodies=\(returned.bodies.count)"
        + "; beforeSelection=" + beforeStationSelection
        + "; cycle=[" + stationCycle.joined(separator: " | ") + "]"
        + "; afterSelection=" + actualStationGuidanceDiagnostic(returned)
    ))
  let beforeDock = actualStationGuidanceDiagnostic(returned)
  var healthLoss: [String] = []
  for _ in 0..<5000 where !returned.docked {
    let previousEnergy = returned.energy
    let previousFront = returned.frontShield
    let previousRear = returned.rearShield
    returned = await runtime.advance(delta: 0.02)
    if healthLoss.count < 8,
      returned.energy < previousEnergy || returned.frontShield < previousFront
        || returned.rearShield < previousRear
    {
      let station = returned.bodies.first { $0.id == 0 && $0.hull == .station }
      healthLoss.append(
        "physicalTime=\(returned.commander.flightSimulation.physicalTime),energy=\(returned.energy),shields=\(returned.frontShield)/\(returned.rearShield),legal=\(returned.commander.legal),message=\(returned.message),stationDistance=\(String(describing: station?.position.length)),inside=\(String(describing: station?.containsPlayer)),incidentCursor=\(returned.commander.flightSimulation.nextIncident)"
      )
    }
  }
  #expect(
    returned.docked && returned.dockedAtMainStation,
    Comment(
      rawValue: "beforeDockFlight=" + beforeDock + "; afterDockFlight="
        + actualStationGuidanceDiagnostic(returned)
        + "; actualHealthLoss=[" + healthLoss.joined(separator: " | ") + "]"))
  #expect(returned.commander.legal == legalBefore)
  await runtime.key("contacts-open")
  #expect(await runtime.snapshot().scriptOffer == id)
  await runtime.key("return")
  #expect(await runtime.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
  #expect(await runtime.snapshot().commander.credits == won.commander.credits + 1000)
  let loaded = GameRuntime(game: game)
  try await loaded.load(from: fixture.save)
  #expect(await loaded.snapshot().commander.scriptState.instances[id]?.outcome == .complete)
}

// Keep the large Commander proof on the heap while real native station validation runs.
private final class NPCReplayNamespaceProof {
  var commander: Commander
  var bodies: [SpaceBody]
  let nextBodyID: Int
  let revision: UInt64
  let epoch: UUID
  init(_ game: borrowing Game) {
    commander = game.commander
    bodies = game.bodies
    nextBodyID = game.nextBodyID
    revision = game.gameplayRevision
    epoch = game.nativeStationRuntimeEpoch
  }
}

private func npcReplayExpectedReboundBody(
  _ original: SpaceBody, id: Int, actor: ActorIdentity, spawn: SpawnIdentity
) throws -> SpaceBody {
  // Preserve every encoded field; only the three explicitly allocated addresses change.
  let encoded = try JSONEncoder().encode(original)
  let measuredObject = try JSONSerialization.jsonObject(with: encoded)
  var object = try #require(measuredObject as? [String: Any])
  var physical = try #require(object["physical"] as? [String: Any])
  object["id"] = id
  physical["identity"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(actor))
  physical["spawnIdentity"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(spawn))
  object["physical"] = physical
  return try JSONDecoder().decode(
    SpaceBody.self, from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]))
}

@inline(never)
private func alignNPCReplayNativeStationNamespace(_ game: inout Game) throws {
  let proof = NPCReplayNamespaceProof(game)
  let indices = proof.bodies.indices.filter { proof.bodies[$0].nativeStationIdentity != nil }
  try #require(!indices.isEmpty)
  for index in indices {
    let body = proof.bodies[index]
    let identity = try #require(body.nativeStationIdentity)
    let current =
      game.nativeStationBodyIsCurrent(body)
      && NativeStationSource.binding(for: identity) != nil
    try #require(current)
  }
  // Public load performs this mandatory fresh-binding transition on the restored branch.
  // Apply that same real authority transition to the unserialized continuation, not a
  // post-replay normalization of shots, resources or mission state.
  try game.rebindNativeStationsAfterLoad()
  let freshEpoch = game.nativeStationRuntimeEpoch != proof.epoch
  let sameBodyCount = game.bodies.count == proof.bodies.count
  try #require(freshEpoch && sameBodyCount)
  let scriptStateUnchanged = game.commander.scriptState == proof.commander.scriptState
  let nonStationsUnchanged =
    game.bodies.filter { $0.nativeStationIdentity == nil }
    == proof.bodies.filter { $0.nativeStationIdentity == nil }
  try #require(scriptStateUnchanged && nonStationsUnchanged)
  let allocatedSequence = proof.commander.flightSimulation.allocateSpawn()
  let sequence = try #require(allocatedSequence)
  var world = try #require(proof.commander.nativeStations)
  for (member, index) in indices.enumerated() {
    let original = proof.bodies[index]
    let identity = try #require(original.nativeStationIdentity)
    let allocatedActor = proof.commander.flightSimulation.allocateActor()
    let actor = try #require(allocatedActor)
    let spawn = SpawnIdentity(
      system: identity.system, visit: actor.visit, sequence: sequence,
      member: UInt16(member), producer: .mission)
    let id = proof.nextBodyID + member
    proof.bodies[index] = try npcReplayExpectedReboundBody(
      original, id: id, actor: actor, spawn: spawn)
    try world.ledger.rebind(identity, to: .init(actor: actor, bodyID: id))
    let current = game.nativeStationBodyIsCurrent(game.bodies[index])
    try #require(current)
  }
  proof.commander.nativeStations = world
  // Full comparisons prove all non-address fields, sources, conditions, stocks,
  // script state and all other flight fields survive the boundary unchanged.
  let bodiesMatch = game.bodies == proof.bodies
  let commanderMatches = game.commander == proof.commander
  let countersMatch =
    game.nextBodyID == proof.nextBodyID + indices.count
    && game.gameplayRevision == proof.revision + 1
  try #require(bodiesMatch && commanderMatches && countersMatch)
}

@Test func physicalNpcReplayAfterSavePreservesShotIdentitiesStocksAndWeaponResults() async throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  _ = try aimNPCAtPlayer(&game, id: id)
  game.speed = 0
  var runtime = GameRuntime(game: game)
  _ = await runtime.advance(delta: 0.1)
  try await runtime.save(to: fixture.save)
  game = await runtime.snapshot()
  try alignNPCReplayNativeStationNamespace(&game)
  runtime = GameRuntime(game: game, saveURL: fixture.save)
  let resumed = GameRuntime(game: game)
  try await resumed.load(from: fixture.save)
  for _ in 0..<12 {
    _ = await runtime.advance(delta: 0.1)
    _ = await resumed.advance(delta: 0.1)
  }
  let uninterrupted = await runtime.snapshot()
  let restored = await resumed.snapshot()
  #expect(uninterrupted.bodies == restored.bodies)
  #expect(
    uninterrupted.frontShield == restored.frontShield && uninterrupted.energy == restored.energy)
  #expect(uninterrupted.commander.scriptState == restored.commander.scriptState)
}

@Test func profiledGalleryStartsRealModelsAndWeaponsInAnIsolatedSavedWorld() async throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var game = Game(executive: false)
  game.screen = .status
  let pack = try ScriptPackLibrary.read(fixture.directory)
  game.scriptPacks = [pack]
  game.commander.credits = 123456
  try game.commander.prepareEquipment(legacy: false)
  game.openGallery()
  let runtime = GameRuntime(game: game)
  try await runtime.save(to: fixture.save)
  let before = await runtime.snapshot()
  let bytes = try Data(contentsOf: fixture.save)
  try await runtime.startScriptGalleryTrial(packDigest: pack.digest, seed: 7823)
  let galleryDirectory = await runtime.gallerySaveDirectory()
  let directory = try #require(galleryDirectory)
  defer { try? FileManager.default.removeItem(at: directory) }
  #expect(await runtime.snapshot().isMissionTrial)
  #expect(await runtime.snapshot().bodies.filter { $0.scriptNPC != nil }.count == 2)
  #expect(await runtime.snapshot().commander.scriptState.geometry.count == 2)
  for _ in 0..<30 { _ = await runtime.advance(delta: 0.1) }
  let containsMatch2 = await runtime.snapshot().bodies.contains { ($0.scriptNPC?.shots ?? 0) > 0 }
  #expect(containsMatch2)
  _ = try await runtime.saveForInterface()
  try await runtime.restartScriptGalleryTrial()
  let allSatisfied3 = await runtime.snapshot().bodies.filter { $0.scriptNPC != nil }.allSatisfy {
    $0.energy == 120 && $0.scriptNPC?.shots == 0
  }
  #expect(allSatisfied3)
  try await runtime.returnFromScriptGalleryTrial()
  #expect(await runtime.snapshot().commander == before.commander)
  #expect(try Data(contentsOf: fixture.save) == bytes)
}

@Test(arguments: [false, true])
func pureNPCDecisionProposesArrivalOrLossWithoutEmittingBeforeActualOwner(_ lost: Bool) throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  if lost {
    try setNPCIntent(
      &game, id: id, command: npcIntent("attack", request: "outer-decision", target: "wing"))
    let wing = try npcIndex(game, id, "wing")
    game.bodies[wing].energy = 0
  } else {
    try setNPCIntent(&game, id: id, command: npcIntent("hold", request: "outer-decision"))
  }
  let index = try npcIndex(game, id)
  let body = game.bodies[index]
  let snapshot = game.bodies
  let owned = Dictionary(
    snapshot.compactMap { value in
      value.missionActorID.map { ($0, value) }
    }, uniquingKeysWith: { first, _ in first })
  let station = snapshot.first { $0.id == 0 && $0.hull == .station }
  let before = (commander: game.commander, bodies: game.bodies, world: game.scriptWorldSave)
  let ownedPreparationRequired4 = game.prepareScriptNPCFlightDecision(
      body,
      owned: owned, station: station, delta: 0.1)
  let proposal = try #require(ownedPreparationRequired4)
  let notice = try #require(proposal.pending)
  #expect(notice.kind == (lost ? .targetLost : .arrived))
  #expect(proposal.intent?.status == (lost ? .lost : .reached))
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  #expect(game.scriptWorldSave == before.world && body.scriptNPC?.intent?.status == .requested)
  let count = before.commander.scriptState.pendingEvents.filter {
    $0.kind == notice.kind.rawValue && $0.values["request"] == .string("outer-decision")
  }.count
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect(game.bodies[index].orientation == proposal.orientation)
  #expect(game.bodies[index].position == proposal.translation.end)
  #expect(game.bodies[index].scriptNPC?.velocity == proposal.translation.velocity)
  #expect(game.bodies[index].scriptNPC?.intent == proposal.intent)
  #expect(
    game.commander.scriptState.pendingEvents.filter {
      $0.kind == notice.kind.rawValue && $0.values["request"] == .string("outer-decision")
    }.count == count + 1)
  game.advanceScriptNPCFlight(delta: 0.1)
  #expect(
    game.commander.scriptState.pendingEvents.filter {
      $0.kind == notice.kind.rawValue && $0.values["request"] == .string("outer-decision")
    }.count == count + 1)
}

@Test func pureNPCFollowDecisionUsesFrozenOwnedSnapshotAcrossBodyOrder() throws {
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  var (game, id) = try fixture.game()
  try setNPCIntent(
    &game, id: id,
    command: npcIntent("follow", request: "outer-follow", target: "wing", offset: .init(100, 0, 0)))
  let body = game.bodies[try npcIndex(game, id)]
  let owned = Dictionary(
    game.bodies.compactMap { value in
      value.missionActorID.map { ($0, value) }
    }, uniquingKeysWith: { first, _ in first })
  let station = game.bodies.first { $0.id == 0 && $0.hull == .station }
  let before = (commander: game.commander, bodies: game.bodies)
  let ownedPreparationRequired5 = game.prepareScriptNPCFlightDecision(
      body,
      owned: owned, station: station, delta: 0.1)
  let first = try #require(ownedPreparationRequired5)
  var reversed = game
  reversed.bodies.reverse()
  let ownedPreparationRequired6 = reversed.prepareScriptNPCFlightDecision(
      body,
      owned: owned, station: station, delta: 0.1)
  let second = try #require(ownedPreparationRequired6)
  #expect(
    second.orientation == first.orientation && second.translation.end == first.translation.end)
  #expect(
    second.translation.velocity == first.translation.velocity && second.intent == first.intent)
  #expect(first.pending == nil && second.pending == nil)
  #expect(game.commander == before.commander && game.bodies == before.bodies)
  #expect(
    reversed.commander == before.commander && Array(reversed.bodies.reversed()) == before.bodies)
}

// Retain the real opening through Game's existing CoW storage. Complete Commander
// reads/equality retire in these frames before the original physical tick begins.
@inline(never)
private func expectNativeNPCOpeningUnchanged(_ game: Game, opening: Game, bodies: [SpaceBody]) {
  let unchanged = game.currentNewtNativeCommanderMatches(opening) && game.bodies == bodies
  #expect(unchanged)
}

@inline(never)
private func nativeNPCOpeningHasNoTransit(_ game: Game) -> Bool {
  game.withReadOnlyScriptState { $0.wormholeTransit == nil }
}

@inline(never)
private func nativeNPCOriginalArrivalCount(_ game: Game) -> Int {
  game.commander.scriptState.pendingEvents.filter {
    $0.kind == "actor.arrived" && $0.values["request"] == .string("native-outer-once")
  }.count
}

// Exercise the real scene owner inside the existing full owning comparison. Its
// immutable opening/proposed cohorts must cover every actual body without a write.
@inline(never)
private func expectNativeNPCQuerySceneReadOnly(
  _ game: Game, path: CurrentNewtOuterMotion, frame: CurrentNewtNPCFrame
) throws {
  let prepared = try prepareNativeNPCQueryScene(game, path: path, frame: frame)
  try verifyNativeNPCQueryScene(game, path: path, prepared: prepared)
}

private struct PreparedNativeNPCQueryScene {
  let bodies: [SpaceBody]
  let celestials: [CelestialBody]
  let epoch: UUID
  let interval: CurrentNewtMechanicalInterval
  let opening: CurrentNewtNativeSegmentOpening
  let scene: CurrentNewtNativeQueryScene
}

@inline(never)
private func prepareNativeNPCQueryScene(
  _ game: Game, path: CurrentNewtOuterMotion, frame: CurrentNewtNPCFrame
) throws -> PreparedNativeNPCQueryScene {
  let bodies = game.bodies
  let celestials = game.celestials
  let epoch = game.nativeStationRuntimeEpoch
  let interval = CurrentNewtMechanicalInterval(start: path.startTime, end: path.endTime)
  let end = try #require(path.state(at: path.endTime))
  let openingCandidate = game.beginCurrentNewtNativeSegment(
    interval, playerMotion: path.motion, playerEnd: end, npcFrame: frame)
  let opening = try #require(openingCandidate)
  let ownedPreparationRequired7 = game.currentNewtMechanicalPlan(interval)
  let mechanics = try #require(ownedPreparationRequired7)
  var sceneRefusal: CurrentNewtPreparationRefusal? = nil
  let sceneCandidate = game.prepareCurrentNewtNativeQueryScene(
    opening: opening, mechanics: mechanics, report: {
      if sceneRefusal == nil { sceneRefusal = $0 }
    })
  let sceneReason = sceneRefusal?.summary ?? "Native scene refusal checkpoint missing (instrumentation incomplete)"
  let scene = try #require(sceneCandidate, Comment(rawValue: sceneReason))
  return .init(bodies: bodies, celestials: celestials, epoch: epoch,
    interval: interval, opening: opening, scene: scene)
}

@inline(never)
private func verifyNativeNPCQueryScene(
  _ game: Game, path: CurrentNewtOuterMotion, prepared: PreparedNativeNPCQueryScene
) throws {
  let bodies = prepared.bodies
  let celestials = prepared.celestials
  let epoch = prepared.epoch
  let interval = prepared.interval
  let opening = prepared.opening
  let scene = prepared.scene
  // Real launch traffic remains in the full scene. Its original per-body phase
  // must be covered by both collider cohorts, without adding an AI decision.
  for body in bodies where !body.hostile && body.physical?.npc != nil
    && body.scriptNPC == nil && body.physical?.spawnIdentity == nil
  {
    let actor = try #require(body.physical?.identity)
    let projectedCandidate = scene.motion.proposed.bodies.first {
      $0.physical?.identity == actor
    }
    let projected = try #require(projectedCandidate)
    let expectedCandidate = game.currentNewtPostCameraBodies(path).first {
      $0.physical?.identity == actor
    }
    let expected = try #require(expectedCandidate)
    let actualPose = scene.motion.proposed.modelPose(of: projected)
    let expectedPose = Game.modelPose(of: expected, player: path.motion.end)
    #expect(actualPose == expectedPose)
    let ordinary = try #require(scene.colliders.first { $0.actor == actor })
    let endpoint = try #require(ordinary.poseAt(path.motion.duration))
    #expect(endpoint == expectedPose)
    let solidCovered = scene.solidColliders.contains { $0.actor == actor }
    #expect(solidCovered)
  }
  let ownedSceneExpected1 = scene.motion.opening === opening
  #expect(ownedSceneExpected1)
  expectNativeNPCOpeningUnchanged(game, opening: opening.before, bodies: bodies)
  let ownedSceneExpected2 = game.celestials == celestials && game.nativeStationRuntimeEpoch == epoch
  #expect(ownedSceneExpected2)
  let ownedSceneExpected3 = game.storedFlightSimulation().physicalTime == interval.start
  #expect(ownedSceneExpected3)
  let ownedSceneExpected4 = scene.motion.proposed.storedFlightSimulation().physicalTime == interval.end
  #expect(ownedSceneExpected4)
  let originalActors = Set(bodies.compactMap { $0.physical?.identity })
  let proposedActors = Set(scene.motion.proposed.bodies.compactMap { $0.physical?.identity })
  #expect(proposedActors == originalActors)
  for body in bodies where body.energy > 0 {
    let physical = try #require(body.physical)
    let covered = scene.colliders.contains { $0.actor == physical.identity }
    let solidCovered = scene.solidColliders.contains { $0.actor == physical.identity }
    #expect(covered && solidCovered)
  }
}

@Test(arguments: [false, true])
func nativeNPCPathsMatchOneOriginalStepAndCommitEffectsWithoutASecondMove(_ canonicalSpin: Bool)
  throws
{
  let fixture = try NPCFixture()
  defer { fixture.clean() }
  let prepared = try prepareNativeNPCComparison(fixture, canonicalSpin: canonicalSpin)
  try expectNativeNPCQuerySceneReadOnly(prepared.game, path: prepared.path, frame: prepared.frame)
  try expectColdPhysicalSourceIdentityAndRefusal()
  try verifyNativeNPCComparison(prepared)
}

private struct PreparedNativeNPCComparison {
  let game: Game
  let id: UUID
  let lead: Int
  let opening: FlightSimulationState
  let bodies: [SpaceBody]
  let openingGame: Game
  let path: CurrentNewtOuterMotion
  let frame: CurrentNewtNPCFrame
}

@inline(never)
private func prepareNativeNPCComparison(_ fixture: NPCFixture, canonicalSpin: Bool) throws -> PreparedNativeNPCComparison {
  var (game, id) = try fixture.game()
  try setNPCIntent(&game, id: id, command: npcIntent("hold", request: "native-outer-once"))
  let lead = try npcIndex(game, id)
  game.bodies[lead].energy = 100
  game.speed = 0
  game.ensurePhysicalActors()
  if canonicalSpin {
    // Exercise the existing canonical-spin input; neither this fixture nor the
    // path descriptor grants source qualification or contact authority.
    try #require(game.bodies[lead].physical != nil)
    game.bodies[lead].physical?.canonicalSpin = true
    game.bodies[lead].physical?.angularVelocity = .init(0.03, -0.02, 0.04)
  }
  let opening = game.storedFlightSimulation()
  let bodies = game.bodies
  let openingGame = game
  // Ordinary mission actors have no transit ledger. Querying the real steering
  // path must remain inert before both the reference tick and native preparation.
  let hasNoTransit = nativeNPCOpeningHasNoTransit(openingGame)
  try #require(hasNoTransit)
  for body in bodies where body.scriptNPC != nil {
    let steeringGoal = game.nativeTransitSteeringGoal(body)
    let clearanceGoal = game.nativeTransitExitClearanceGoal(body)
    #expect(steeringGoal == nil && clearanceGoal == nil)
    if let intent = body.scriptNPC?.intent {
      let retainedIntent = game.nativeTransitSteeringIntent(body, intent: intent)
      #expect(retainedIntent == intent)
    }
  }
  expectNativeNPCOpeningUnchanged(game, opening: openingGame, bodies: bodies)
  // The real profiled cohort has no clinic, Ark or rescue source. Every optional
  // guidance query must preserve its native owner before the unchanged reference tick.
  let clinicControls = game.c01ClinicEscortRuntime.controls.count
  let clinicReason = game.c01ClinicEscortRuntime.reason
  for body in bodies {
    guard let profile = body.scriptNPC?.fit.definition else { continue }
    let course = game.c01ClinicCourse(body, profile: profile, delta: 0.1)
    let applied = game.c01ClinicGuidance(body, profile: profile, delta: 0.1)
    let ark = game.inductionArkDockGuidance(body, profile: profile, delta: 0.1)
    let rescue = game.inductionRescueDockGuidance(body, profile: profile, delta: 0.1)
    #expect(course == nil && applied == nil && ark == nil && rescue == nil)
  }
  expectNativeNPCOpeningUnchanged(game, opening: openingGame, bodies: bodies)
  #expect(game.c01ClinicEscortRuntime.controls.count == clinicControls)
  #expect(game.c01ClinicEscortRuntime.reason == clinicReason)
  let pathCandidate = game.prepareCurrentNewtOuterMotion(delta: 0.1)
  let path = try #require(pathCandidate)
  var frameRefusal: CurrentNewtPreparationRefusal? = nil
  let frameCandidate = game.prepareCurrentNewtNPCFrame(path, report: {
    if frameRefusal == nil { frameRefusal = $0 }
  })
  let frameReason = frameRefusal?.summary ?? "NPC frame refusal checkpoint missing (instrumentation incomplete)"
  let frame = try #require(frameCandidate, Comment(rawValue: frameReason))
  try #require(frame.entries.count == 2)
  expectNativeNPCOpeningUnchanged(game, opening: openingGame, bodies: bodies)
  return .init(game: game, id: id, lead: lead, opening: opening, bodies: bodies,
    openingGame: openingGame, path: path, frame: frame)
}

@inline(never)
private func verifyNativeNPCComparison(_ prepared: PreparedNativeNPCComparison) throws {
  var game = prepared.game
  let id = prepared.id
  let lead = prepared.lead
  let opening = prepared.opening
  let bodies = prepared.bodies
  let openingGame = prepared.openingGame
  let path = prepared.path
  let frame = prepared.frame
  var original = game
  original.tick(delta: 0.1)
  for entry in frame.entries.values {
    let bodyCandidate = original.bodies.first { $0.physical?.identity == entry.actor }
    let body = try #require(bodyCandidate)
    let expected = original.modelPose(of: body)
    let displacement = expected.position - entry.before.pose.position
    let quarter = try #require(entry.state(at: path.startTime + 0.025))
    let threeQuarters = try #require(entry.state(at: path.startTime + 0.075))
    let end = try #require(entry.state(at: path.endTime))
    #expect(
      (quarter.pose.position - (entry.before.pose.position + displacement * 0.25)).length < 1e-7)
    #expect(
      (threeQuarters.pose.position - (entry.before.pose.position + displacement * 0.75)).length
        < 1e-7)
    #expect((end.pose.position - expected.position).length < 1e-7)
    #expect((end.pose.orientation.x - expected.orientation.x).length < 1e-7)
    #expect((end.pose.orientation.y - expected.orientation.y).length < 1e-7)
    #expect((end.pose.orientation.z - expected.orientation.z).length < 1e-7)
  }
  let interval = game.advanceCurrentNewtNativeInterval(path, npcFrame: frame)
  let evidence = try #require(interval.evidence)
  #expect(
    evidence.verifiedFinalFlight(
      from: opening, usedD: 0.1,
      epoch: game.nativeStationRuntimeEpoch) == game.storedFlightSimulation())
  let positions = Dictionary(
    uniqueKeysWithValues: game.bodies.compactMap { body in
      body.physical.map { ($0.identity, game.modelPose(of: body)) }
    })
  let decisionsCommitted = game.commitCurrentNewtNPCDecisions(frame)
  try #require(decisionsCommitted)
  game.advanceScriptNPCFlight(delta: 0, excluding: Set(frame.entries.keys))
  let after = try npcIndex(game, id)
  let definition = try #require(game.bodies[after].scriptNPC?.fit.definition)
  #expect(game.bodies[after].energy == min(definition.energy, 100 + definition.recharge * 0.1))
  #expect(nativeNPCOriginalArrivalCount(game) == 1)
  for body in game.bodies {
    guard let actor = body.physical?.identity else { continue }
    #expect(game.modelPose(of: body) == positions[actor])
  }
}


@inline(never)
private func expectColdPhysicalSourceIdentityAndRefusal() throws {
  let shipCandidate = ShipCatalogue.ship("SH040")
  let ship = try #require(shipCandidate)
  let physicalCandidate = ship.physicalSourceContract
  let physical = try #require(physicalCandidate)
  let capsuleCandidate = OriginalCryostasisCapsule.source
  let capsule = try #require(capsuleCandidate)
  let kitCandidate = CurrentNewtKitSource.current
  let kit = try #require(kitCandidate)
  #expect(physical.id == "SH040" && physical.nativeTriangles == 92)
  #expect(physical.metresPerSourceUnit == 60.0 / 19.0)
  #expect(abs(physical.envelope.dimensions.z - 2.4) < 1e-12)
  #expect(physical.engineering?.dryMassKilograms == 248)
  #expect(capsule.collisionDesign.vertices.count == physical.physicalMesh.vertices.count)
  #expect(kit.configuration == CurrentNewtKitPhysicalSource.configurationID
    && kit.sourceSHA256 == CurrentNewtKitPhysicalSource.sourceSHA256)
  let definitionCandidate = OriginalFleetDefinitionData.definition(for: "SH040")
  let definition = try #require(definitionCandidate)
  let model = physical.model
  let wrongID = OriginalFleetShowroomModel(id: "SH999", sourcePath: model.sourcePath,
    sourceSHA256: model.sourceSHA256, coordinateUnits: model.coordinateUnits, nativeDesign: model.nativeDesign)
  #expect(throws: OriginalHullPhysicalContract.Failure.self) {
    _ = try OriginalHullPhysicalContract(definition: definition, model: wrongID)
  }
  let wrongPin = OriginalFleetShowroomModel(id: model.id, sourcePath: model.sourcePath,
    sourceSHA256: String(repeating: "0", count: 64), coordinateUnits: model.coordinateUnits,
    nativeDesign: model.nativeDesign)
  #expect(throws: OriginalHullPhysicalContract.Failure.self) {
    _ = try OriginalHullPhysicalContract(definition: definition, model: wrongPin)
  }
}
