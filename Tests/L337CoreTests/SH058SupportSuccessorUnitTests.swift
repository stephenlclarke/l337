import Foundation
import TOMLDecoder
import Testing

@testable import L337Core

/// Copied into the actual test target by the G1-executed successor binding step.
struct SH058SupportSuccessorUnitTests {
  @Test func sourceSuccessorAuthenticatesAndCannotReuseOldPhysicalAuthority() throws {
    let id = "SH058"
    let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
    let ship = try TOMLDecoder().decode(CatalogueShip.self, from: bytes)
    let entry = try #require(OriginalDetailedHullStage.registration(for: id))
    let selected = try OriginalFleetShowroomModels.model(for: id)
    let current = try #require(OriginalFleetR3Data.contract(for: id))
    try OriginalDetailedHullStage.authenticate(ship, bytes: bytes)
    #expect(try OriginalDetailedHullStage.resolvePending(ship) == ship)
    #expect(try OriginalPlayerHullActivation.resolve(ship) == ship)
    #expect(ship.nativeDesign == selected.nativeDesign && selected.nativeDesign.valid)
    #expect(selected.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH058-design.toml")
    #expect(selected.sourceSHA256 == entry.nativeSourceSHA256)
    #expect(selected.sourceSHA256 == current.referencedGeometrySHA256)
    #expect(current.sourceSHA256 == "fd5f2d8a64762ab74e1849985e6cf3bf25184968e5cf6f7d6d15213eadd3b11c")
    #expect(current.referencedGeometrySHA256 == "13ef038a1ab17ffb777bd43f6a63b0a973bbea8bfd6076248cc14f8f1d49b2b8")
    #expect(selected.coordinateUnits == "metres")
    #expect(selected.nativeDesign.faces.count == entry.sourceNativeFaces)
    #expect(selected.nativeDesign.faces.count == 244)
    #expect(selected.nativeDesign.faces.count <= 512)
    #expect(ship.game == current.performance)
    #expect(ship.catalogue.family == "muskox" && ship.name == "Muskox")
    #expect(!ship.catalogue.playerFlyable && !ship.catalogue.normalPurchaseEligible)
    #expect(ship.catalogue.purchasePolicy == .pendingFabrication)
    let registration = try #require(OriginalFleetPhysicalData.registrations[id])
    let record = try OriginalFleetPhysicalData.record(for: id)
    let physical = try OriginalFleetCurrentHullSource(id: id)
    #expect(entry.physicalRecordSHA256 == "b05c4d29534783889ee898d28057f23fa64d8c385c78754aa8abf603e76f03a8")
    #expect(registration.sha256 == entry.physicalRecordSHA256)
    #expect(registration.nativeSourceSHA256 == selected.sourceSHA256)
    #expect(record.validates(source: registration))
    #expect(record.dryMassKilograms == 113117 && record.metresPerSourceUnit == 1)
    #expect(record.centreOfMassMetres.count == 3 && record.inertiaAboutCentreOfMassKgM2.count == 9)
    #expect(physical.model.nativeDesign == selected.nativeDesign && physical.nativeTriangles == 244)
    #expect(physical.mesh.vertices == selected.nativeDesign.rawMesh.vertices)
    #expect(ship.physicalSourceContract?.engineering?.dryMassKilograms == record.dryMassKilograms)
    #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(id: id, sourceFaces: 244)) {
      try OriginalDetailedHullStage.requireRuntime(id)
    }
    #expect(OriginalFleetRuntimeHullSource.source(for: id) == nil)
    #expect(ShipCatalogue.rawMesh(id) == nil)
    #expect(!ScriptNPCModel.referenceValid("catalogue:" + id))
    #expect(SalvageCatalogue.empProfile(catalogueShipID: id) == nil)
    var game = Game(executive: false)
    let before = game.commander
    #expect(game.shipTradeQuote(for: ship) == nil)
    #expect(throws: (any Error).self) {
      try game.commander.transferEquipment(to: id, hullID: UUID())
    }
    #expect(game.commander == before)
    #expect(throws: OriginalDetailedHullStage.Failure.invalidDetailedResource(id)) {
      try OriginalDetailedHullStage.authenticate(ship, bytes: bytes + Data("\n".utf8))
    }
  }

  @Test func defaultLoaderAdmitsOnlyTheThreeGenuineOriginalMuskoxPackages() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let runtime = GameRuntime(game: Game(executive: false))
    await runtime.loadMissionPacks(directory: root.appendingPathComponent("mission-packs"))
    let errors = await runtime.loadDefaultScriptPacks(directory: root.appendingPathComponent("script-packs"))
    #expect(!errors.contains { error in
      ["Bundled identified salvage pack:", "Bundled crew record recovery pack:",
       "Bundled Cevilis custody source:"].contains { error.hasPrefix($0) }
    })
    var game = await runtime.snapshot()
    let expected = [
      (ScriptPackLibrary.bundledIdentifiedSalvageDirectory, NativeIdentifiedSalvage.digest, "pell-return-package"),
      (ScriptPackLibrary.bundledRecordRecoveryDirectory, WayfarerRecordRecovery.digest, "w05-flight-recorder"),
      (ScriptPackLibrary.bundledInductionCrewLogDirectory, NativeInductionCrewLogPack.digest, "induction-crew-custody-recorder"),
    ]
    let authentic = try #require(OriginalScriptedMuskox.design)
    let preview = try #require(ShipCatalogue.ship("SH058")).design
    let reference = OriginalScriptedMuskox.reference
    let hash = OriginalScriptedMuskox.geometrySHA256
    #expect(OriginalDetailedHullStage.blocksRuntime("SH058"))
    #expect(!ScriptNPCModel.referenceValid(reference))
    for (directory, digest, role) in expected {
      let pack = try ScriptPackLibrary.read(directory)
      try #require(pack.digest == digest)
      try #require(game.scriptPacks.contains {
        $0.manifest.stateID == pack.manifest.stateID && $0.digest == digest
      })
      let package = try #require(pack.manifest.npcs?.first { $0.id == role })
      #expect(pack.models[reference] == authentic && package.scale == 0.2)
      let npc = try game.makeScriptNPC(package, pack: pack, identity: UUID())
      #expect(npc.fit.models == [reference: hash])
      var body = SpaceBody(id: -1, hull: .cobra, position: .init(0, 0, 400))
      body.scriptNPC = npc
      #expect(!OriginalDetailedHullStage.blocksRuntime(body))
      let mesh = try #require(game.scriptNPCMesh(body))
      #expect(mesh.faces.count == 244 && mesh.vertices == authentic.rawMesh.vertices.map { $0 * 0.2 })
      #expect(mesh.vertices.allSatisfy { $0.length <= 16 })
      game.bodies = [body]
      game.celestials = []
      let origin = Vector3(0, 0, 0)
      let direction = Vector3(0, 0, 1)
      let scene = GameplayRaycast.prepareOcclusionScene(game)
      let hit = try #require(GameplayRaycast.nearest(
        origin: origin, direction: direction, maxDistance: 500, scene: scene))
      #expect(hit.target == .body(body.id) && abs(hit.distance - 395) <= 1e-8)
      game.commander.shipDisplayStyle = .shadedPanels
      var validFrame = Frame()
      validFrame.rasterizeGraphics = false
      Display.draw(body, game: game, into: &validFrame, screen: .front)
      #expect(!validFrame.shipPanels.isEmpty)
      game.commander.scriptState.geometry[hash] = preview
      #expect(game.scriptNPCMesh(body) == nil && game.scriptNPCDisplayMesh(body) == nil)
      var forgedFrame = Frame()
      forgedFrame.rasterizeGraphics = false
      Display.draw(body, game: game, into: &forgedFrame, screen: .front)
      #expect(forgedFrame.graphics.isEmpty && forgedFrame.worldGraphics.isEmpty)
      let forged = GameplayRaycast.prepareOcclusionScene(game)
      #expect(GameplayRaycast.nearest(
        origin: origin, direction: direction, maxDistance: 500, scene: forged) == nil)
      game.commander.scriptState.geometry[hash] = authentic
    }
    let crewLog = try #require(game.nativeInductionCrewLogPack)
    #expect(crewLog.digest == NativeInductionCrewLogPack.digest)
    let okapi = try NativeInductionCrewLogSource.flightProfile.get()
    #expect(crewLog.manifest.npcs == [okapi, NativeInductionCrewLogSource.recorderProfile()])
    let originalOkapi = try OriginalHullPhysicalContract.okapi.get()
    #expect(crewLog.models[okapi.model] == originalOkapi.model.nativeDesign)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let changed = root.appendingPathComponent("changed-pack")
    try FileManager.default.copyItem(at: ScriptPackLibrary.bundledIdentifiedSalvageDirectory, to: changed)
    let script = changed.appendingPathComponent("scripts/main.lua")
    var bytes = try Data(contentsOf: script)
    bytes.append(Data("\n-- Changed pack identity.\n".utf8))
    try bytes.write(to: script)
    #expect(throws: MissionPackError.self) { try ScriptPackLibrary.read(changed) }
  }
}
