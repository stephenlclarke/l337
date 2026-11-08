import AppKit
import Foundation
import Testing

@testable import L337Core
@testable import L337Mac

@MainActor
private func nativeEMPFrameImage(_ frame: Frame) throws -> CGImage {
  let context = try #require(
    CGContext(
      data: nil, width: 768, height: 768, bitsPerComponent: 8, bytesPerRow: 768 * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  )
  context.setFillColor(CGColor(gray: 0, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: 768, height: 768))
  context.translateBy(x: 0, y: 768)
  context.scaleBy(x: 1, y: -1)
  drawFrame(frame, context: context, rect: CGRect(x: 0, y: 0, width: 768, height: 768))
  return try #require(context.makeImage())
}

private func nativeEMPBytes(_ image: CGImage) throws -> Data {
  let data = try #require(image.dataProvider?.data)
  return data as Data
}

@MainActor
private func captureNativeEMPView(_ view: GameView) throws -> (image: CGImage, seconds: Double) {
  try #require(
    view.bounds.width == 768 && view.bounds.height == 768,
    "EMP content bounds=\(view.bounds) windowContent=\(String(describing: view.window?.contentLayoutRect)) screen=\(String(describing: view.window?.screen?.visibleFrame))"
  )
  let context = try #require(
    CGContext(
      data: nil, width: 768, height: 768, bitsPerComponent: 8, bytesPerRow: 768 * 4,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
  )
  context.translateBy(x: 0, y: 768)
  context.scaleBy(x: 1, y: -1)
  NSGraphicsContext.saveGraphicsState()
  defer { NSGraphicsContext.restoreGraphicsState() }
  NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
  let started = ProcessInfo.processInfo.systemUptime
  view.draw(view.bounds)
  let seconds = ProcessInfo.processInfo.systemUptime - started
  return (try #require(context.makeImage()), seconds)
}

@MainActor
private func verifyNativeEMPPixels(_ view: GameView, bodyID: Int, ink: Ink, stage: String) throws {
  let original = view.game
  defer { view.game = original }
  for style in ShipDisplayStyle.allCases {
    var game = original
    game.commander.shipDisplayStyle = style
    let started = ProcessInfo.processInfo.systemUptime
    let frame = Display.presentation(game, width: 768, height: 768)
    view.game = game
    let captured = try captureNativeEMPView(view)
    let image = captured.image
    let oracleStarted = ProcessInfo.processInfo.systemUptime
    let oracle = try #require(imageForGame(game, width: 768, height: 768))
    let oracleSeconds = ProcessInfo.processInfo.systemUptime - oracleStarted
    #expect(try nativeEMPBytes(image) == nativeEMPBytes(oracle))
    try #require(captured.seconds > 0 && oracleSeconds > 0)
    let pixels = try nativeEMPBytes(image)
    #expect(try pixels == nativeEMPBytes(nativeEMPFrameImage(frame)))
    var withoutCue = frame
    func stripped(_ graphics: [Graphic]) -> [Graphic] {
      graphics.filter { if case .glow = $0 { false } else { true } }
    }
    withoutCue.worldGraphics = stripped(frame.worldGraphics)
    withoutCue.graphics = stripped(frame.graphics)
    let baseline = try nativeEMPBytes(nativeEMPFrameImage(withoutCue))
    var colouredDifference = 0
    var white = 0
    for y in 0..<768 {
      for x in 0..<768 {
        // The established native bitmap convention addresses logical y directly after the y-flip.
        let offset = y * image.bytesPerRow + x * 4
        let r = Int(pixels[offset])
        let g = Int(pixels[offset + 1])
        let b = Int(pixels[offset + 2])
        let inside = frame.flightClip.contains(.init(Double(x), Double(y)))
        if inside, r > 230, g > 230, b > 230 { white += 1 }
        if pixels[offset..<offset + 4] != baseline[offset..<offset + 4] {
          #expect(inside)
          if ink == .red, r > g + 20, r > b + 20 { colouredDifference += 1 }
          if ink == .orange, r > g, g > b + 10 { colouredDifference += 1 }
        }
      }
    }
    #expect(colouredDifference > 0)
    if style == .whiteWireframe {
      #expect(!frame.shipLines.isEmpty && frame.shipLines.allSatisfy { $0.ink == .white })
      #expect(white > 0)
    }
    let index = try #require(game.bodies.firstIndex { $0.id == bodyID })
    for hidden in [false, true] {
      var occluded = game
      if hidden {
        occluded.bodies[index].position = .init(10000, 0, 1000)
      } else {
        occluded.bodies.append(.init(id: 999, hull: .station, position: .init(0, 0, 350)))
      }
      let clipped = Display.presentation(occluded, width: 768, height: 768)
      #expect(!clipped.worldGraphics.contains { if case .glow = $0 { true } else { false } })
      var strippedFrame = clipped
      strippedFrame.worldGraphics = stripped(clipped.worldGraphics)
      strippedFrame.graphics = stripped(clipped.graphics)
      view.game = occluded
      let actual = try captureNativeEMPView(view).image
      let clippedOracle = try #require(imageForGame(occluded, width: 768, height: 768))
      #expect(try nativeEMPBytes(actual) == nativeEMPBytes(clippedOracle))
      #expect(try nativeEMPBytes(actual) == nativeEMPBytes(nativeEMPFrameImage(strippedFrame)))
    }
    if let path = ProcessInfo.processInfo.environment["ELITE_UI_EVIDENCE_DIRECTORY"] {
      let directory = URL(fileURLWithPath: path, isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let name = "emp-\(stage)-\(style.rawValue)"
      let png = try #require(
        NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try png.write(to: directory.appendingPathComponent(name + ".png"))
      let evidence: [String: Any] = [
        "source": ProcessInfo.processInfo.environment["ELITE_VALIDATION_SOURCE_SHA"] ?? "local",
        "colouredCuePixels": colouredDifference, "whiteWorldPixels": white,
        "actualDrawSeconds": captured.seconds, "oracleDrawSeconds": oracleSeconds,
        "actualToOracleRatio": captured.seconds / oracleSeconds,
        "verificationSeconds": ProcessInfo.processInfo.systemUptime - started,
        "foregroundAndOffscreenCuePixels": 0,
      ]
      try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys])
        .write(to: directory.appendingPathComponent(name + ".json"))
    }
  }
}

extension NativeViewTests {
  @MainActor @Test func nativeEMPKeysDisableEjectAndPublishTheSameSourceAndPeople() async throws {
    _ = NSApplication.shared
    let previousMenu = NSApp.mainMenu
    let identifier = "elite-native-emp-" + UUID().uuidString
    let preferences = try #require(UserDefaults(suiteName: identifier))
    let storage = try NativeStationTestStorage()
    defer {
      preferences.removePersistentDomain(forName: identifier)
      storage.clean()
    }
    let file = storage.url
    var baseline = try await NativeEMPPaidUIFixture.game(file: file)
    baseline.selectFlightTool(.combatLaser)
    let profile = try #require(
      SalvageCatalogue.empProfile(catalogueShipID: NativeEMPPaidUIFixture.catalogueID))
    let cargoSection = try #require(profile.sections.first { $0.kind == .cargo })
    let forward = cargoSection.normal.unit * -1
    let cardinal = abs(forward.y) < 0.8 ? Vector3(0, 1, 0) : .init(1, 0, 0)
    var basis = Basis3()
    basis.z = forward
    basis.x = cardinal.cross(forward).unit
    basis.y = forward.cross(basis.x).unit
    baseline.bodies[0].orientation = basis.transposed
    baseline.bodies[0].position = .init(0, 0, 1000)
    baseline.bodies[0].physical?.velocity = .init(0, 0, 0)
    baseline.bodies[0].physical?.angularVelocity = .init(0, 0, 0)
    // This controlled UI scene begins with an ordinary, already depleted craft, still powered.
    var resources = try #require(baseline.bodies[0].physical?.npc?.resources)
    let frontOverflow = resources.absorb(resources.frontShield, front: true)
    let rearOverflow = resources.absorb(resources.rearShield, front: false)
    try #require(frontOverflow == 0 && rearOverflow == 0)
    let initialTime = baseline.commander.flightSimulation.physicalTime
    var reserve = try #require(
      ElectricalReserve(
        capacity: resources.energyCapacity, recharge: resources.electricalRecharge, at: initialTime)
    )
    let drained = reserve.drain(resources.energyCapacity - 1, at: initialTime)
    try #require(drained && reserve.remaining == 1 && reserve.disabledAt == nil)
    resources.electrical = reserve
    baseline.bodies[0].physical?.npc?.resources = resources
    let pulse = try EMPPulseProfile.resolve(for: baseline.commander)
    try #require(pulse.power == 64 && pulse.warmup == 10 && pulse.energyCost == 8)
    try #require(
      1 + (resources.electricalRecharge + resources.shieldRecharge) * (pulse.warmup + 0.1)
        < pulse.power)
    let accommodation = try ShipAccommodationProfile(ship: baseline.commander.ship)
    try #require(accommodation.operatingCrew == 1)
    try #require(
      baseline.commander.savedEMPState == nil && baseline.commander.savedEMPCharge == nil)
    try #require(baseline.bodies[0].physical?.empSource == nil && baseline.bodies[0].energy == 77)
    // Paid arrival, launch and bank earning have already advanced this scene.
    // Preserve the entire attained simulation input; never reseed it for the UI.
    let attainedSimulation = baseline.scriptSimulationSave
    let attainedPhysicalTime = baseline.commander.flightSimulation.physicalTime
    try #require(attainedSimulation.valid && attainedPhysicalTime > 0)
    // The shared fixture fixes its initial input before the paid journey. No
    // scalar draw is expected until this scene's one original crew sample.
    // Preserve the attained clock/counter and expose any unexpected earlier draw.
    try #require(attainedSimulation.randomState == 0,
      Comment(rawValue: "Initial paid UI stream consumed before EMP: RNG=\(attainedSimulation.randomState) "
        + "missionCounter=\(attainedSimulation.missionLoopCounter) physicalTime=\(attainedPhysicalTime)"))
    try #require(baseline.commander.missionStage == .notStarted)
    try #require(!baseline.bodies[0].ecmEnabled && baseline.bodies[0].missiles == 0)
    try #require(baseline.bodies[0].hull.navalEnergy == nil)
    let original = baseline.bodies[0]
    let writer = GameRuntime(game: baseline)
    try await writer.save(to: file)
    let delegate = AppDelegate(
      restoreOnLaunch: false,
      saves: CommanderSaveSession(preferences: preferences, defaultURL: file))
    delegate.applicationDidFinishLaunching(
      Notification(name: NSApplication.didFinishLaunchingNotification))
    let window = try #require(delegate.window)
    defer {
      delegate.windowWillClose(Notification(name: NSWindow.willCloseNotification))
      window.orderOut(nil)
      window.delegate = nil
      NSApp.mainMenu = previousMenu
    }
    let view = try #require(window.contentView as? GameView)
    let loop = try #require(delegate.loop)
    loop.cancel()
    await loop.value
    try await delegate.runtime.load(from: file, persistMigrations: false)
    view.game = await delegate.runtime.snapshot()
    try #require(
      view.game.scriptSimulationSave == attainedSimulation
        && view.game.commander.flightSimulation.physicalTime == attainedPhysicalTime)
    try #require(
      view.game.commander.savedEMPState == nil && view.game.commander.savedEMPCharge == nil)
    let loadedTarget = try #require(view.game.bodies.first { $0.id == original.id })
    try #require(loadedTarget.physical?.identity == original.physical?.identity)
    try #require(loadedTarget.physical?.npc?.resources?.electrical?.remaining == 1)
    try #require(loadedTarget.physical?.npc?.resources?.electrical?.disabledAt == nil)
    view.pending.removeAll()
    let stationWeapons = Dictionary(
      uniqueKeysWithValues: view.game.bodies.compactMap { body in
        body.nativeStationIdentity.map { ($0, (body.missiles, body.ecmEnabled)) }
      })
    func event(_ code: UInt16, _ text: String, down: Bool) throws -> NSEvent {
      try #require(
        NSEvent.keyEvent(
          with: down ? .keyDown : .keyUp, location: .zero, modifierFlags: [],
          timestamp: 0, windowNumber: window.windowNumber, context: nil,
          characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }
    for _ in 0..<FlightWorkTool.allCases.count
    where view.game.selectedFlightTool != .empPirateBlaster {
      view.keyDown(with: try event(13, "w", down: true))
      view.keyUp(with: try event(13, "w", down: false))
      await delegate.processPendingCommands(in: view)
    }
    try #require(view.game.selectedFlightTool == .empPirateBlaster)
    try verifyNativeEMPPixels(view, bodyID: original.id, ink: .red, stage: "armed")
    let audioBefore = view.game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count
    var expectedEnergy = original.energy
    let chargeStartSimulation = view.game.scriptSimulationSave
    view.keyDown(with: try event(36, "\r", down: true))
    await delegate.processFrame(in: view, delta: { 0.1 })
    if resources.profile == .nativeHull {
      expectedEnergy = min(
        resources.energyCapacity, expectedEnergy + 0.1 * resources.energyRecharge)
    }
    let charge = try #require(view.game.commander.savedEMPCharge)
    try #require(charge.phase == .charging && charge.target == original.physical?.identity)
    #expect(view.game.commander.savedEMPState == nil)
    #expect(
      view.game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == audioBefore)
    var heldFrames = 0
    for _ in 0..<120 where view.game.commander.savedEMPCharge?.phase == .charging {
      try #require(view.game.scriptSimulationSave.randomState == attainedSimulation.randomState)
      try #require(view.game.ecmFrames == 0 && view.game.screen != .gameOver && !view.game.docked)
      try #require(
        view.game.bodies.allSatisfy { body in
          let weaponsUnchanged: Bool
          if let station = body.nativeStationIdentity, let expected = stationWeapons[station] {
            weaponsUnchanged = body.missiles == expected.0 && body.ecmEnabled == expected.1
          } else {
            weaponsUnchanged = body.missiles == 0 && !body.ecmEnabled
          }
          return weaponsUnchanged && !body.enemyMissile && body.playerMissileTarget == nil
            && body.physical?.ordnance == nil && body.blackjackRole == nil
        })
      await delegate.processFrame(in: view, delta: { 0.1 })
      heldFrames += 1
      if resources.profile == .nativeHull {
        expectedEnergy = min(
          resources.energyCapacity, expectedEnergy + 0.1 * resources.energyRecharge)
      }
      if view.game.commander.flightSimulation.physicalTime + 1e-9 < charge.startedAt + pulse.warmup
      {
        #expect(view.game.commander.savedEMPState == nil)
        #expect(
          view.game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count
            == audioBefore)
      }
    }
    view.keyUp(with: try event(36, "\r", down: false))
    let released = try #require(view.game.commander.savedEMPCharge)
    let endedAt = try #require(released.endedAt)
    try #require(released.phase == .released && heldFrames == 100)
    #expect(abs(endedAt - charge.startedAt - pulse.warmup) < 1e-8)
    #expect(
      view.game.dischargeAudio.events.filter { $0.tool == .empPirateBlaster }.count == audioBefore
        + 1)
    let source = try #require(view.game.bodies.first { $0.id == original.id }?.physical?.empSource)
    let disabled = try #require(view.game.bodies.first { $0.physical?.empSource == source })
    #expect(disabled.id == original.id)
    #expect(disabled.energy == expectedEnergy)
    #expect(view.game.targetColourCue(for: disabled) == .recoverable)
    #expect(view.game.empTargetStatus(disabled)?.contains("CREW ABOARD") == true)
    try verifyNativeEMPPixels(view, bodyID: disabled.id, ink: .orange, stage: "disabled-occupied")
    let occupied = try #require(view.game.commander.savedEMPState?.records[source])
    let episode = try #require(occupied.disableEpisodes.last)
    try #require(occupied.crewTotal == 1 && occupied.crewAboard == 1)
    // One original crew member consumes exactly one source RNG draw. Its delay
    // follows the attained stream, rather than the obsolete reseeded 0.5 seconds.
    let sampledState = attainedSimulation.randomState &* 6_364_136_223_846_793_005 &+ 1
    let sampledByte = Int((sampledState >> 32) & 255)
    let sampledDelay = 0.5 + Double(sampledByte) / 255 * 44.5
    try #require(episode.ejections == [.init(ordinal: 0, delay: sampledDelay)])
    #expect(view.game.scriptSimulationSave.randomState == sampledState)
    #expect(view.game.missionLoopCounter
      == chargeStartSimulation.missionLoopCounter &- UInt8(heldFrames + 1))
    try #require(episode.incident.physicalTime + sampledDelay < episode.deadline,
      Comment(rawValue: "Current UI ejection premise: attainedRNG=\(attainedSimulation.randomState) "
        + "attainedCounter=\(attainedSimulation.missionLoopCounter) sampledDelay=\(sampledDelay) "
        + "deadline=\(episode.deadline) disableTime=\(episode.incident.physicalTime)"))
    for _ in 0..<300 where view.game.commander.savedEMPState?.records[source]?.crewAboard != 0 {
      try #require(
        view.game.commander.flightSimulation.physicalTime < episode.deadline
          && view.game.screen != .gameOver && !view.game.docked)
      await delegate.processFrame(in: view, delta: { 0.1 })
    }
    try #require(view.game.commander.flightSimulation.physicalTime < episode.deadline)
    let record = try #require(view.game.commander.savedEMPState?.records[source])
    try #require(record.crewAboard == 0 && record.pods.count == record.crewTotal)
    let salvage = try #require(view.game.bodies.first { $0.physical?.empSource == source })
    #expect(salvage.id == original.id && view.game.targetColourCue(for: salvage) == .recoverable)
    let metadata = try #require(salvage.physical?.salvage)
    let context = try #require(view.game.gameplayContext())
    #expect(view.game.salvageCuttingIsAllowed(salvage, metadata: metadata, context: context))
    let people = Set(view.game.bodies.compactMap { $0.physical?.empCrewPod })
    #expect(people.count == record.crewTotal)
    try verifyNativeEMPPixels(view, bodyID: salvage.id, ink: .orange, stage: "disabled-empty")
    // Use the player's real filter/Tab target commands and controller to reach a cutter hold.
    for (code, text) in [(UInt16(3), "f"), (3, "f"), (48, "\t")] {
      view.keyDown(with: try event(code, text, down: true))
      view.keyUp(with: try event(code, text, down: false))
      await delegate.processPendingCommands(in: view)
    }
    for _ in 0..<2400 where view.game.workGuidance?.holding != true {
      await delegate.processFrame(in: view, delta: { 0.1 })
    }
    try #require(view.game.workGuidance?.holding == true)
    try #require(view.game.selectedFlightTool == .salvageCutter)
    let section = WreckSectionIdentity(wreck: record.wreck, section: cargoSection.index)
    try #require(view.game.workGuidance?.surface.section == section)
    view.keyDown(with: try event(36, "\r", down: true))
    var cutting = true
    for _ in 0..<1200 {
      if view.game.salvageSectionIsDepleted(section) {
        if cutting {
          view.keyUp(with: try event(36, "\r", down: false))
          cutting = false
        }
        let received = view.game.commander.cargo[CommodityIdentity.food.rawValue]
          - baseline.commander.cargo[CommodityIdentity.food.rawValue]
        if received == 2 { break }
        let food = view.game.commander.alienStorageState?.current.salvage.pending.values.first {
          guard $0.lot.identity.section == section, $0.binding != nil,
            case .commodity(let amount) = $0.lot.content
          else { return false }
          return amount.commodity == .food
        }
        if let target = food?.binding, view.game.autoPilot.targetActor != target {
          // Tab selects the actual released body; the ordinary scoop controller
          // must move the owned craft through its real aperture and custody guard.
          for _ in 0..<view.game.bodies.count {
            view.keyDown(with: try event(48, "\t", down: true))
            view.keyUp(with: try event(48, "\t", down: false))
            await delegate.processPendingCommands(in: view)
            if view.game.autoPilot.targetActor == target { break }
          }
          try #require(view.game.autoPilot.targetActor == target)
        }
      }
      await delegate.processFrame(in: view, delta: { 0.1 })
    }
    if cutting { view.keyUp(with: try event(36, "\r", down: false)) }
    try #require(view.game.salvageSectionIsDepleted(section))
    let native = try #require(view.game.commander.alienStorageState?.current.salvage.native)
    let inspection = try #require(native.inspections[section])
    let cycle = try #require(native.works[inspection.id])
    #expect(cycle.inspection == .fresh(inspection.id) && cycle.releases > 0)
    #expect(cycle.currentWorkSeconds == 0 && cycle.depleted)
    #expect(inspection.preinspection == nil && inspection.plan.source.manifest == record.salvageCargo)
    let parent = try #require(native.wrecks[record.wreck])
    #expect(parent.source == .emp(actor: source, sequence: record.sequence))
    let food = view.game.commander.alienStorageState?.current.salvage.pending.values.reduce(0) {
      total, pending in
      guard pending.lot.identity.section.wreck == record.wreck,
        case .commodity(let amount) = pending.lot.content, amount.commodity == .food
      else { return total }
      return total + amount.quantity
    } ?? 0
    #expect(food + view.game.commander.cargo[CommodityIdentity.food.rawValue]
      - baseline.commander.cargo[CommodityIdentity.food.rawValue] == 2)
    #expect(view.game.commander.cargo[CommodityIdentity.food.rawValue]
      - baseline.commander.cargo[CommodityIdentity.food.rawValue] == 2)
    let receivedFood = view.game.commander.alienStorageState?.current.snapshot.world.reduce(0) {
      total, value in
      guard case .companion(let item) = value, item.plan == inspection.id,
        case .collected(let receipt) = item.state,
        case .cargo(let amount, let before, let after) = receipt.effect,
        amount.commodity == .food, after - before == amount.quantity
      else { return total }
      return total + amount.quantity
    } ?? 0
    #expect(receivedFood == 2)
    #expect(view.game.commander.savedEMPState?.records[source]?.pods.count == people.count)
    delegate.queueCommanderFile(.saveActive)
    await delegate.processPendingCommands(in: view)
    let bytes = try Data(contentsOf: file)
    let pointer = try JSONDecoder().decode(ScriptSavePointer.self, from: bytes)
    let (saved, _) = try ScriptSaveStore.read(bytes, from: file)
    let discovery = try #require(saved.scriptState.savedFleetDiscovery)
    #expect(discovery.valid && discovery.owner == saved.equipmentOwnerID)
    #expect(discovery.entries[NativeEMPPaidUIFixture.catalogueID] != nil)
    #expect(pointer.schemaVersion == NativeFleetDiscoverySave.alienVersion)
    #expect(saved.usesAlienStorageSaveVersion && saved.alienStorageStateValid)
    #expect(saved.alienStorageState?.current.salvage.native.works[inspection.id] == cycle)
    #expect(saved.alienStorageState?.current.salvage.native.inspections[section] == inspection)
    #expect(saved.savedEMPState?.records[source]?.pods.count == people.count)
    #expect(saved.savedEMPState?.records[source]?.hull.body.id == original.id)
    try await delegate.runtime.load(from: file, persistMigrations: false)
    view.game = await delegate.runtime.snapshot()
    #expect(view.game.commander.cargo == saved.cargo)
    #expect(view.game.commander.alienStorageState?.current.snapshot
      == saved.alienStorageState?.current.snapshot)
    #expect(view.game.commander.savedEMPState?.records[source]?.disableEpisodes
      == saved.savedEMPState?.records[source]?.disableEpisodes)
    #expect(Set(view.game.bodies.compactMap { $0.physical?.empCrewPod }) == people)
    #expect(nativeEMPHulls(view.game, source: source).count == 1)
    #expect(try Data(contentsOf: file) == bytes)
  }
}
