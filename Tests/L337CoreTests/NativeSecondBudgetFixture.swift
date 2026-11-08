import Foundation
import Testing

@testable import L337Core
@testable import L337TestSupport

/// A controlled at-birth manifest passes through the current Bison production
/// allocator/admission. This fixture establishes no natural-spawn or legacy import claim.
enum NativeSecondBudgetFixture {
  static let shipID = "SH005"
  static let manifest: [CommodityAmount] = [.init(commodity: .food, quantity: 120)]

  // Keep full value snapshots on the heap rather than reserving many Game
  // temporaries in one async AppKit regression frame.
  final class Snapshot: Sendable {
    let game: Game
    @inline(never) init(_ value: borrowing Game) { game = value }
  }

  struct Source: Sendable {
    let actor: ActorIdentity
    let parent: ActorIdentity
    let wreck: WreckIdentity
    let sequence: UInt64
    let section: SalvageSectionProfile
    var identity: WreckSectionIdentity { .init(wreck: wreck, section: section.index) }
  }

  static func runtime(file: URL) async throws -> (GameRuntime, Source) {
    // Reuse the existing Bison acquisition fixture's controlled initial source
    // and real paid purchase sequence, before inventory/history or owned identity.
    let runtime = GameRuntime(game: try paidStarterGame(recovery: true), saveURL: file)
    try await runtime.save(to: file)
    await runtime.key("3")
    for axis in EMPModuleAxis.allCases {
      for grade in 1...3 {
        let before = await runtime.snapshot()
        let module = try #require(before.currentEMPPlayerModule())
        let context = try before.empModulePurchaseContext(module: module.id, axis: axis)
        let receipt = try await runtime.purchaseEMPModuleUpgrade(context)
        let after = await runtime.snapshot()
        try #require(receipt.after.value(for: axis) == grade && receipt.paidPrice > 0)
        try #require(after.commander.credits == before.commander.credits - receipt.paidPrice)
        try #require(after.currentEMPPlayerModule()?.empBank?.remaining == 0)
      }
    }
    await runtime.key("0")
    try await runtime.secondBudgetEarnBank()
    try await runtime.secondBudgetDepartToAllowedRegion()
    await runtime.enableStationDefenceDiagnostics()
    let actor = try await runtime.secondBudgetAdmitControlledHostile(shipID)
    try await runtime.secondBudgetSelect(actor)
    try await runtime.secondBudgetSelectTool(.empPirateBlaster)
    try await runtime.secondBudgetDisableWithActualEMP(shipID, actor: actor)
    let empty = try await runtime.secondBudgetWaitForEmptyHull(actor)
    let source = try await runtime.secondBudgetRetainSource(actor: actor, parent: empty)
    try await runtime.secondBudgetAimCargo(source)
    return (runtime, source)
  }

  static func hasInspection(_ game: borrowing Game, source: Source) -> Bool {
    game.commander.alienStorageState?.current.salvage.native.inspections[source.identity] != nil
  }

  static func requirePhysicalCustody(_ game: borrowing Game, source: Source) throws {
    let pending = game.commander.alienStorageState?.current.salvage.pending.values.filter {
      $0.lot.identity.section == source.identity
    } ?? []
    var bound = 0
    for value in pending {
      if let binding = value.binding {
        let candidate = game.bodies.first { $0.physical?.identity == binding }
        let body = try #require(candidate)
        try #require(body.physical?.payload == .salvage(value.lot.identity))
        let actual = game.currentSalvageLot(for: body)
        try #require(actual?.identity == value.lot.identity)
        bound += 1
      } else {
        let present = game.bodies.contains { $0.physical?.payload == .salvage(value.lot.identity) }
        try #require(!present)
      }
    }
    try #require(!pending.isEmpty && bound > 0)
  }

  static func observation(_ game: borrowing Game, source: Source) throws
    -> (inspection: NativeSalvageInspection, cycle: NativeSalvageWorkCycle)
  {
    let nativeCandidate = game.commander.alienStorageState?.current.salvage.native
    let native = try #require(nativeCandidate)
    let inspection = try #require(native.inspections[source.identity])
    let cycle: NativeSalvageWorkCycle
    if let hot = game.nativeSalvageWork {
      try #require(hot.plan == inspection.plan && hot.section == source.section)
      try #require(hot.actor == source.parent && hot.cycle.inspection.id == inspection.id)
      cycle = hot.cycle
    } else {
      cycle = try #require(native.works[inspection.id])
    }
    try #require(cycle.inspection == .fresh(inspection.id))
    try #require(inspection.preinspection == nil && inspection.plan.originalManifest == manifest)
    try #require(inspection.plan.source.manifestSection == source.section.index)
    let owner = game.commander.equipmentOwnerID
    try #require(cycle.owner == owner)
    return (inspection, cycle)
  }

  static func pending(_ game: borrowing Game, source: Source) throws -> Set<SalvageLotIdentity> {
    let salvageCandidate = game.commander.alienStorageState?.current.salvage
    let salvage = try #require(salvageCandidate)
    return Set(salvage.pending.keys.filter { $0.section == source.identity })
  }

  private static func paidStarterGame(recovery: Bool) throws -> Game {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH029"))
    try OriginalDetailedHullStage.requireRuntime(source.ship.id)
    let current = try #require(OriginalFleetR3Data.contract(for: source.ship.id))
    let fitting = try #require(current.fitting)
    try #require(source.ship.id == "SH029" && source.ship.name == "Okapi")
    try #require(source.performance == current.performance && source.ship.game == current.performance)
    try #require(source.performance.workTools?.contains(.salvageCutter) == true)
    try #require(fitting.compatibleUtilities.contains("salvageCutter")
      && fitting.compatibleUtilities.contains("cargoScoop") && !fitting.roleKitIncluded)
    try #require(fitting.equipmentUnits == 20 && fitting.utilityMounts == 3)
    try #require(current.accommodation?.operatingCrew == 1
      && current.accommodation?.intrinsicCrewPlaces == 1)
    // Root-authorised controlled initial hull, before any inventory/history. No earned
    // acquisition, live transfer, included role kit or G1 Okapi helper is substituted.
    var initial = Game(executive: false)
    try #require(initial.commander.equipmentInventory == nil
      && initial.commander.equipmentPurchaseHistory == nil
      && initial.commander.equipmentOwnerID == nil && initial.commander.hullInstanceID == nil)
    initial.commander.shipID = source.ship.id
    initial.commander.fuel = source.performance.fuel
    initial.energy = source.performance.energy
    initial.frontShield = source.performance.shield
    initial.rearShield = source.performance.shield
    initial.screen = .status
    initial.commander.galaxy = 0
    initial.commander.system = 69
    initial.selectedSystem = 69
    initial.market = MarketItem.at(initial.currentSystem)
    initial.commander.credits = 20_000_000
    try #require(initial.commander.shipID == "SH029" && initial.currentSystem.name == "Verasel")
    try #require(initial.currentSystem.technology == 16 && initial.currentSystem.government == 4)
    try #require(!initial.commander.unlimitedCash && !initial.commander.unlimitedFuel)
    try initial.commander.prepareEquipment(legacy: false)
    try #require(initial.commander.nativeCrewMissing == 0)
    try #require(initial.commander.fleetBlueprintAcquisition(for: "SH029") == nil)
    try initial.prepareG03FlightEquipment()
    // Pulse came from paid G03 preparation; the remaining ancestors must also be paid.
    for name in [
      "Military Laser", ShieldBooster.mining.equipmentName, ShieldBooster.beam.equipmentName,
      ShieldBooster.military.equipmentName,
    ] {
      let item = try #require(Equipment.all.first { $0.name == name })
      let before = initial.commander
      let history = try #require(before.equipmentPurchaseHistory)
      let quote = try initial.quoteEquipmentPurchase(item)
      try #require(quote.purchase.requiredDebit > 0)
      let equipmentPurchased = try initial.applyEquipmentPurchase(quote)
      try #require(equipmentPurchased)
      let paid = try #require(initial.commander.equipmentPurchaseHistory)
      try #require(initial.commander.credits == before.credits - quote.purchase.requiredDebit)
      try #require(paid.paid.count == history.paid.count + 1)
      try #require(paid.paid.last?.binding.request == quote.request)
    }
    try #require(initial.commander.laser(on: .front) == .military)
    try #require(initial.commander.shieldBooster == .military)
    if recovery {
      for name in [Equipment.empPirateBlaster, "Salvage Cutter", "Fuel Scoops", "Targeting: Salvage Module"] {
        let item = try #require(Equipment.all.first { $0.name == name })
        let before = initial.commander
        let quote = try initial.quoteEquipmentPurchase(item)
        try #require(quote.purchase.requiredDebit > 0)
        let equipmentPurchased = try initial.applyEquipmentPurchase(quote)
        try #require(equipmentPurchased)
        #expect(initial.commander.credits == before.credits - quote.purchase.requiredDebit)
        #expect(initial.commander.equipmentPurchaseHistory?.paid.last?.binding.request == quote.request)
      }
    }
    try #require(initial.commander.commonEquipmentUnits <= fitting.equipmentUnits)
    try #require(initial.commander.passengerFit?.allowed == true)
    let inventory = try #require(initial.commander.equipmentInventory)
    try inventory.validate(context: EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: initial.commander.nativePerformance))
    try OriginalFleetR3Fitting.validateUtilities(inventory, ship: initial.commander.ship)
    if recovery {
      for utility in [ComponentUtility.empPirateBlaster, .salvageCutter, .fuelScoops] {
        try #require(initial.commander.fittedEquipment(at: .utility(utility)) != nil)
      }
    }
    try #require(initial.energy.isFinite && initial.energy > 0
      && initial.energy <= initial.commander.performance.energy)
    try NativeSaveTestFixture.prepareCurrentPolicy(&initial)
    return initial
  }

}

private enum NativeSecondBudgetFailure: Error {
  case toolSelection, bankBudget, departureBudget, selectionBudget
  case disableBudget, crewDepartureBudget
}

extension GameRuntime {
  func secondBudgetSnapshot() -> NativeSecondBudgetFixture.Snapshot {
    .init(game)
  }

  func secondBudgetAdvance(delta: Double) -> NativeSecondBudgetFixture.Snapshot {
    _ = advance(delta: delta)
    return .init(game)
  }

  func secondBudgetAdvanceHeldWork(delta: Double) throws -> NativeSecondBudgetFixture.Snapshot {
    try #require(!game.paused && !game.docked && game.screen.isFlight && game.energy > 0,
      Comment(rawValue: "Actual second-budget flight: \(game.message) at \(game.commander.flightSimulation.physicalTime)"))
    if game.workGuidance?.holding == true && game.workFireSuspended {
      setControls(Controls())
      key("return")
      setControls(NativePagedSalvageFixture.firingControls)
    }
    let start = game.commander.flightSimulation.physicalTime
    _ = advance(delta: delta)
    try #require(!game.paused && !game.docked && game.screen.isFlight && game.energy > 0,
      Comment(rawValue: "Actual second-budget flight: \(game.message) at \(game.commander.flightSimulation.physicalTime)"))
    try #require(game.commander.flightSimulation.physicalTime > start)
    return .init(game)
  }

  fileprivate func secondBudgetSelectTool(_ tool: FlightWorkTool) throws {
    for _ in 0..<4 {
      if game.selectedFlightTool == tool { return }
      key(FlightControlInput.token(for: .changeWeapon))
    }
    throw NativeSecondBudgetFailure.toolSelection
  }

  fileprivate func secondBudgetLiveFrame() throws -> Game {
    try #require(game.bodies.count <= 256 && game.screen.isFlight && !game.docked)
    try #require(!game.paused && game.energy > 0)
    let start = game.commander.flightSimulation.physicalTime
    let after = advance(delta: 0.1)
    try #require(after.commander.flightSimulation.physicalTime > start)
    try #require(after.bodies.count <= 256 && after.screen.isFlight && after.energy > 0)
    return after
  }

  fileprivate func secondBudgetEarnBank() throws {
    var input = Controls()
    input.throttle = -1
    setControls(input)
    for _ in 0..<256 {
      let bank = try #require(game.currentEMPPlayerModule()?.empBank)
      if bank.remaining == bank.capacity { return }
      _ = try secondBudgetLiveFrame()
    }
    throw NativeSecondBudgetFailure.bankBudget
  }

  fileprivate func secondBudgetDisableWithActualEMP(_ shipID: String, actor: ActorIdentity) throws {
    let epoch = try #require(game.gameplayCombatTrace?.epoch)
    let player = try #require(game.commander.flightSimulation.player)
    var incoming = false
    for _ in 0..<1200 {
      let context = try #require(game.gameplayContext())
      if let disabled = game.commander.savedEMPState?.records[actor] {
        try #require(incoming && disabled.source == actor && disabled.valid)
        try #require(disabled.hull.body.physical?.catalogueShipID == shipID)
        try #require(disabled.weaponOwner == game.commander.equipmentOwnerID)
        try #require(disabled.disableIncident.kind == .emp && disabled.disableIncident.outcome == .hit)
        try #require(disabled.disableIncident.origin.owner == player)
        setControls(Controls())
        return
      }
      if incoming {
        try #require(game.commander.crimeLedger.hasCurrentUnlawfulAttack(
          from: actor, against: player, context: context))
      }
      let start = game.commander.flightSimulation
      let previousDropped = try #require(game.gameplayCombatTrace?.dropped)
      var input = Controls()
      input.throttle = -1
      // A terminal charge or safety stop needs an ordinary release before a fresh press.
      // Keep holding a valid charge; changing saved phase/latch state would bypass input.
      let terminalCharge = game.commander.savedEMPCharge.map { $0.phase != .charging } ?? false
      input.fire = incoming && !terminalCharge && !game.workFireSuspended
      setControls(input)
      let after = try secondBudgetLiveFrame()
      let trace = try #require(after.gameplayCombatTrace)
      try #require(trace.epoch == epoch && trace.incidents.count <= 128)
      if trace.dropped > previousDropped {
        try #require(trace.incidents.first.map { $0.id < start.nextIncident } == true)
      }
      for hit in trace.incidents where hit.id >= start.nextIncident {
        try #require(hit.id < after.commander.flightSimulation.nextIncident)
        if hit.kind == .laser && hit.outcome == .hit,
          hit.origin.owner == actor && hit.victim == player,
          hit.physicalTime > start.physicalTime,
          hit.physicalTime <= after.commander.flightSimulation.physicalTime,
          hit.origin.emissionID >= start.nextEmission,
          hit.origin.emissionID < after.commander.flightSimulation.nextEmission,
          hit.origin.emittedAt > start.physicalTime,
          hit.origin.emittedAt <= after.commander.flightSimulation.physicalTime
        {
          let current = try #require(after.gameplayContext())
          try #require(after.commander.crimeLedger.hasCurrentUnlawfulAttack(
            from: actor, against: player, context: current))
          incoming = true
        }
      }
    }
    setControls(Controls())
    throw NativeSecondBudgetFailure.disableBudget
  }

  fileprivate func secondBudgetWaitForEmptyHull(_ source: ActorIdentity) throws -> ActorIdentity {
    setControls(Controls())
    let occupied = try #require(game.commander.savedEMPState?.records[source]?.hull.binding)
    key(FlightControlInput.token(for: .releaseHold))
    try secondBudgetSelect(occupied)
    try secondBudgetSelectTool(.salvageCutter)
    for _ in 0..<600 {
      let record = try #require(game.commander.savedEMPState?.records[source])
      try #require(record.valid && record.lostCrewCount == 0)
      if record.crewAboard == 0 {
        try #require(record.pods.count + record.capturedCrewCount == record.crewTotal)
        let actor = try #require(record.hull.binding)
        let body = try #require(game.bodies.first { $0.physical?.identity == actor })
        try #require(body.physical?.npc == nil && body.physical?.empSource == source)
        setControls(Controls())
        return actor
      }
      var input = Controls()
      input.fire = game.workGuidance?.holding == true
      setControls(input)
      _ = try secondBudgetLiveFrame()
    }
    setControls(Controls())
    throw NativeSecondBudgetFailure.crewDepartureBudget
  }

  fileprivate func secondBudgetDepartToAllowedRegion() throws {
    var input = Controls()
    input.throttle = 1
    setControls(input)
    for _ in 0..<300 {
      try #require(!game.docked && game.screen.isFlight && game.energy > 0 && !game.paused)
      let context = try #require(game.gameplayContext())
      let region = EncounterGeography.region(at: context.player.position, anchors: context.anchors)
      if region == .tradeLane || region == .deepSpace {
        input.throttle = -1
        setControls(input)
        return
      }
      _ = advance(delta: 0.1)
    }
    throw NativeSecondBudgetFailure.departureBudget
  }

  fileprivate func secondBudgetAdmitControlledHostile(_ shipID: String) throws -> ActorIdentity {
    let source = try #require(OriginalBisonActivation.source(for: shipID))
    let allocatedSpawn = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSpawn)
    let context = try #require(game.gameplayContext())
    try #require(context.system.galaxy == 0 && context.system.system == 69 && context.government == 4)
    let position = context.anchors.arrival * 0.6 + context.anchors.station.position * 0.4
    try #require(source.ship.catalogue.regions.contains(
      EncounterGeography.region(at: context.player.position, anchors: context.anchors)))
    try #require(source.ship.catalogue.regions.contains(
      EncounterGeography.region(at: position, anchors: context.anchors)))
    let stock = try #require(NPCResources.stock(source.game))
    var npc = NPCState(role: .trader, origin: context.system, destination: context.system,
      resources: stock)
    // Controlled input exists before production admission, not a live cargo edit.
    let manifest = NativeSecondBudgetFixture.manifest
    try #require(source.game.cargo >= 120 && manifest.allSatisfy(\.valid))
    npc.ordinaryCargo = manifest
    npc.intention = .engage(context.player.identity)
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    let request = SpawnRequest(
      identity: .init(system: context.system, visit: context.visit, sequence: sequence,
        member: 0, producer: .ambient),
      population: .civilian, hull: .cobra, position: position, orientation: .init(),
      velocity: .init(0, 0, 0), npc: npc, rock: nil, payload: nil, priority: .ordinary,
      catalogueShipID: shipID)
    try #require(!game.bodies.contains { $0.physical?.spawnIdentity == request.identity })
    try #require(OriginalBisonActivation.matchesRequest(request, context: context))
    let receipts = game.admitEncounterPlan(.init(
      system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: true)], intents: []))
    let receipt = try #require(receipts.first)
    try #require(receipts.count == 1 && receipt.refusal == nil,
      Comment(rawValue: "Controlled Bison production admission: \(String(describing: receipt.refusal))"))
    let actor = try #require(receipt.actor)
    let body = try #require(game.bodies.first { $0.physical?.identity == actor })
    try #require(body.physical?.catalogueShipID == shipID && body.physical?.npc?.resources == stock)
    try #require(body.energy == source.game.energy)
    try #require(body.physical?.spawnIdentity == request.identity)
    try #require(body.physical?.npc?.ordinaryCargo == manifest)
    try #require(game.commander.savedEMPState?.records[actor] == nil)
    try #require(OriginalBisonActivation.matchesNativeBody(body, context: context, commander: game.commander))
    return actor
  }

  fileprivate func secondBudgetSelect(_ actor: ActorIdentity) throws {
    for _ in 0..<128 {
      if game.autoTargetBody?.physical?.identity == actor { return }
      key("tab")
    }
    throw NativeSecondBudgetFailure.selectionBudget
  }

  fileprivate func secondBudgetRetainSource(actor: ActorIdentity, parent: ActorIdentity) throws
    -> NativeSecondBudgetFixture.Source
  {
    let record = try #require(game.commander.savedEMPState?.records[actor])
    try #require(record.valid && record.crewAboard == 0 && record.lostCrewCount == 0)
    try #require(record.pods.count + record.capturedCrewCount == record.crewTotal)
    try #require(record.cargo == NativeSecondBudgetFixture.manifest)
    let body = try #require(game.bodies.first { $0.physical?.identity == parent })
    let physical = try #require(body.physical)
    try #require(physical.empSource == actor && physical.npc == nil)
    try #require(physical.catalogueShipID == NativeSecondBudgetFixture.shipID)
    try #require(physical.salvage?.wreck == record.wreck && record.hull.binding == parent)
    try #require(physical.velocity.length > 0)
    try #require(game.retainNativeSalvageWreck(body))
    let retained = try #require(
      game.commander.alienStorageState?.current.salvage.native.wrecks[record.wreck])
    try #require(retained.source == .emp(actor: actor, sequence: record.sequence))
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: NativeSecondBudgetFixture.shipID))
    try #require(!profile.sourceRoles.contains(.thargoid))
    let section = try #require(profile.sections.first { $0.index == 1 })
    try #require(section.workSeconds > 0.02 && section.workSeconds <= 50)
    return .init(actor: actor, parent: parent, wreck: record.wreck,
      sequence: record.sequence, section: section)
  }

  func secondBudgetAimCargo(_ source: NativeSecondBudgetFixture.Source) throws {
    setControls(Controls())
    key(FlightControlInput.token(for: .releaseHold))
    let body = try #require(game.bodies.first { $0.physical?.identity == source.parent })
    let model = game.modelPose(of: body)
    let pose = NativePagedSalvageFixture.cargoObserverPose(model, section: source.section)
    // Observer setup preserves the actual parent's world pose, velocity and custody.
    NativePagedSalvageFixture.moveObserver(&game, to: pose)
    let actual = try #require(game.bodies.first { $0.physical?.identity == source.parent })
    try #require(game.modelPose(of: actual) == model && actual.physical == body.physical)
    let hit = try #require(try game.nearestMissionCollision(
      from: .init(0, 0, 0), direction: .init(0, 0, 1), range: 300,
      radius: 0, includePlayer: false))
    try #require(hit.hit.target == .body(actual.id))
    let metadata = try #require(actual.physical?.salvage)
    try #require(game.workSurface(for: actual, metadata: metadata)?.section == source.identity)
    try secondBudgetSelectTool(.salvageCutter)
    game.workTargetFilter = .salvage
    for _ in 0..<128 {
      key("tab")
      if game.autoTargetBody?.physical?.identity == source.parent { break }
    }
    try #require(game.autoTargetBody?.physical?.identity == source.parent)
    try #require(game.workGuidance?.parent == source.parent)
    try #require(game.workGuidance?.mode == .hold(.salvage))
    try #require(game.workGuidance?.surface.section == source.identity)
    setControls(NativePagedSalvageFixture.firingControls)
  }
}
