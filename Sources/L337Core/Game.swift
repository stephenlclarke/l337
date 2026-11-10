import Foundation

/// Actual zero-lifetime cohort admitted by this tick's outer owners. Only
/// Game's real before/after census can create it; stock issuance time is not
/// actor admission time when an authenticated carrier or pod is readmitted.
final class CurrentNewtEndBirths: Sendable {
  let actors: Set<ActorIdentity>
  let allActors: Set<ActorIdentity>
  private let bodies: [ActorIdentity: SpaceBody]
  private let flight: FlightSimulationState
  private let epoch: UUID

  fileprivate init(game: Game, previouslyPresent: Set<ActorIdentity>) {
    var selected: [ActorIdentity: SpaceBody] = [:]
    for body in game.bodies {
      guard let physical = body.physical, !previouslyPresent.contains(physical.identity)
      else { continue }
      selected[physical.identity] = body
    }
    bodies = selected
    allActors = Set(selected.keys)
    actors = Set(
      selected.compactMap { actor, body in
        body.physical?.currentNewtKitStock != nil || body.physical?.currentNewtKitReceipt != nil
          ? actor : nil
      })
    flight = game.storedFlightSimulation()
    epoch = game.nativeStationRuntimeEpoch
  }

  func matches(_ game: Game) -> Bool { matches(game, newtOnly: false) }

  func matchesNewtBirths(_ game: Game) -> Bool { matches(game, newtOnly: true) }

  private func matchesClock(_ game: Game) -> Bool {
    let current = game.storedFlightSimulation()
    return current.physicalTime == flight.physicalTime && current.pose == flight.pose
      && current.system == flight.system && current.visit == flight.visit
      && current.player == flight.player && game.nativeStationRuntimeEpoch == epoch
  }

  private func matches(_ game: Game, newtOnly: Bool) -> Bool {
    guard matchesClock(game) else { return false }
    for (actor, original) in bodies where !newtOnly || actors.contains(actor) {
      guard let body = game.bodies.first(where: { $0.physical?.identity == actor }),
        body == original
      else { return false }
    }
    return true
  }
  private init(copy original: CurrentNewtEndBirths, bodies: [ActorIdentity: SpaceBody]) {
    actors = original.actors; allActors = original.allActors
    flight = original.flight; epoch = original.epoch; self.bodies = bodies
  }

  func accepting(_ effect: NativeCombatHitClockEffect, in game: Game) -> CurrentNewtEndBirths? {
    guard matchesClock(game),
      let updated = effect.updatedBirthBodies(matching: bodies, in: game)
    else { return nil }
    return .init(copy: self, bodies: updated)
  }

  func accepting(_ effect: NativeMissionBeamClockEffect, in game: Game) -> CurrentNewtEndBirths? {
    guard matchesClock(game),
      let updated = effect.updatedBirthBodies(matching: bodies, in: game)
    else { return nil }
    return .init(copy: self, bodies: updated)
  }

  func modelPoses(in game: Game) -> [ActorIdentity: ShipPose]? {
    guard matches(game) else { return nil }
    return bodies.mapValues { Game.modelPose(of: $0, player: flight.pose) }
  }

  func components(in game: Game) -> [ActorIdentity: [CurrentNewtKitComponent]]? {
    guard matches(game) else { return nil }
    var result: [ActorIdentity: [CurrentNewtKitComponent]] = [:]
    for actor in actors {
      guard let body = game.bodies.first(where: { $0.physical?.identity == actor }),
        let parts = try? game.currentNewtGeometryComponents(for: body)
      else { return nil }
      result[actor] = parts
    }
    return result
  }

}

/// One real mechanical retention, including its actual release census. The
/// cohort constructor remains in this file; callers cannot mint birth authority.
struct CurrentNewtNativeMechanicalRetention {
  let result: CurrentNewtMechanicalSegmentResult
  let effects: [NativeDebrisImpactClockEffect]
  let births: CurrentNewtEndBirths
}

extension Game {
  mutating func retainCurrentNewtNativeMechanics(
    _ prepared: CurrentNewtPreparedNativeContact
  ) -> CurrentNewtNativeMechanicalRetention? {
    let interval = prepared.motion.opening.interval
    guard storedFlightSimulation().physicalTime == interval.end else { return nil }
    var candidate = self
    let present = Set(candidate.bodies.compactMap { $0.physical?.identity })
    var effects: [NativeDebrisImpactClockEffect] = []
    var moved = false
    let result = candidate.advanceCurrentNewtMechanicalSegment(prepared.motion.mechanics) {
      game, _ in
      let retained = game.retainCurrentNewtNativeSegment(
        prepared.motion, resolution: prepared.resolution, clockEffects: &effects)
      moved = retained.admitted
      return retained
    }
    guard moved, result.acceptedDuration == interval.end - interval.start,
      candidate.storedFlightSimulation().physicalTime == interval.end,
      candidate.nativeStationRuntimeEpoch
        == prepared.motion.opening.before.nativeStationRuntimeEpoch
    else { return nil }
    let births = CurrentNewtEndBirths(game: candidate, previouslyPresent: present)
    self = candidate
    return .init(result: result, effects: effects, births: births)
  }
}

/// Synchronous dock preparation owns its rollback values off the active call stack.
private final class DockPersistenceSnapshot {
  private let commander: Commander
  private let work: NativeSalvageHotWork?
  private let wreckMotion: [WreckIdentity: NativeSalvageWreckObservation]
  private let lotMotion: [SalvageLotIdentity: NativeSalvageMotion]

  @inline(never)
  init(_ game: borrowing Game) {
    commander = game.commander
    work = game.nativeSalvageWork
    wreckMotion = game.nativeSalvageWreckMotion
    lotMotion = game.nativeSalvageMotion
  }

  @inline(never)
  func restore(to game: inout Game) {
    game.commander = commander
    game.nativeSalvageWork = work
    game.nativeSalvageWreckMotion = wreckMotion
    game.nativeSalvageMotion = lotMotion
  }
}

public enum Screen: String, Codable, Sendable, CaseIterable {
  case demo, title, front, rear, left, right, chart, shortChart, system, market, status, inventory,
    equipment, buy, sell, secret, help, mission, handoff, gallery, navigation, showroom, rumour,
    gameOver, contracts, library, journal
  public var isFlight: Bool { [.front, .rear, .left, .right].contains(self) }
}

/// A Commander-owned value: one COW payload, encoded exactly as the original script-state value.
private struct CommanderScriptStateStorage: Sendable, Equatable, Codable {
  private var values: [ScriptEngineState]

  init(_ value: consuming ScriptEngineState) {
    values = [consume value]
  }

  var value: ScriptEngineState {
    _read { yield values[0] }
    _modify { yield &values[0] }
  }

  func withReadOnlyValue<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    try values.withUnsafeBufferPointer { storage in
      try read(storage.baseAddress!.pointee)
    }
  }

  @inline(never)
  func instancesAreEmpty() -> Bool {
    values.withUnsafeBufferPointer { storage in
      guard let instances = storage.baseAddress!.pointer(to: \.instances) else {
        preconditionFailure("Script claim validation requires addressable stored instances.")
      }
      return instances.pointee.isEmpty
    }
  }

  // Station validation projects child fields before leaving this synchronous storage borrow.
  func withNativeStationReadOnlyValue<Result>(
    _ read: (UnsafePointer<ScriptEngineState>) -> Result
  ) -> Result {
    values.withUnsafeBufferPointer { storage in
      read(storage.baseAddress!)
    }
  }

  init(from decoder: Decoder) throws {
    values = [try ScriptEngineState(from: decoder)]
  }

  func encode(to encoder: Encoder) throws {
    try withReadOnlyValue { try $0.encode(to: encoder) }
  }
}

/// Native custody retains value semantics without growing every inline Commander copy.
private struct CommanderNativePeopleCustodyStorage: Sendable, Equatable, Codable {
  private var values: [NativePeopleCustodyState?]

  init(_ value: consuming NativePeopleCustodyState?) {
    values = [consume value]
  }

  var value: NativePeopleCustodyState? {
    _read { yield values[0] }
    _modify { yield &values[0] }
  }

  func withReadOnlyValue<Result>(
    _ read: (borrowing NativePeopleCustodyState?) throws -> Result
  ) rethrows -> Result {
    try values.withUnsafeBufferPointer { storage in
      try read(storage.baseAddress!.pointee)
    }
  }

  init(from decoder: Decoder) throws {
    values = [try NativePeopleCustodyState(from: decoder)]
  }

  func encode(to encoder: Encoder) throws {
    try withReadOnlyValue { try $0.encode(to: encoder) }
  }
}

/// Immutable retained DATA only; decoding creates no quote, arrival or source-stock authority.
private final class CommanderMemoryAtlasSourceStorage: Codable, Equatable, Sendable {
  let value: NativeMemoryAtlasWatcherSourceRecord
  init(_ value: NativeMemoryAtlasWatcherSourceRecord) { self.value = value }
  init(from decoder: Decoder) throws {
    value = try NativeMemoryAtlasWatcherSourceRecord(from: decoder)
  }
  func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }

  static func == (lhs: CommanderMemoryAtlasSourceStorage, rhs: CommanderMemoryAtlasSourceStorage) -> Bool {
    lhs.value == rhs.value
  }
}

public struct Commander: Sendable, Equatable, Codable {
  private var savedMemoryAtlasWatcherSourceStorage: CommanderMemoryAtlasSourceStorage?
  var savedMemoryAtlasWatcherSource: NativeMemoryAtlasWatcherSourceRecord? {
    get { savedMemoryAtlasWatcherSourceStorage?.value }
    set { savedMemoryAtlasWatcherSourceStorage = newValue.map(CommanderMemoryAtlasSourceStorage.init) }
  }
  private var savedContracts: ScriptContractState?
  public var contracts: ScriptContractState {
    get { savedContracts ?? ScriptContractState() }
    set { savedContracts = newValue == ScriptContractState() ? nil : newValue }
  }

  var legacyOwnedEquipment: LegacyOwnedEquipmentInventory?
  private var savedAccommodation: ShipAccommodation?
  public var accommodation: ShipAccommodation {
    get { savedAccommodation ?? ShipAccommodation() }
    set { savedAccommodation = newValue }
  }
  private var savedScriptState: CommanderScriptStateStorage?
  public var scriptState: ScriptEngineState {
    _read {
      if let stored = savedScriptState {
        yield stored.value
      } else {
        let empty = ScriptEngineState()
        yield empty
      }
    }
    set { savedScriptState = newValue == ScriptEngineState() ? nil : .init(newValue) }
    _modify {
      if case .none = savedScriptState { savedScriptState = .init(ScriptEngineState()) }
      defer {
        if savedScriptState?.withReadOnlyValue({ $0.nextEvent }) == 0,
          savedScriptState?.withReadOnlyValue({ $0 == ScriptEngineState() }) == true
        {
          savedScriptState = nil
        }
      }
      yield &savedScriptState!.value
    }
  }

  func withReadOnlyScriptState<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    if let stored = savedScriptState { return try stored.withReadOnlyValue(read) }
    return try Self.withDefaultScriptState(read)
  }

  @inline(never)
  func scriptInstancesAreEmpty() -> Bool {
    guard let stored = savedScriptState else { return true }
    return stored.instancesAreEmpty()
  }

  @inline(never)
  private static func withDefaultScriptState<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    let empty = ScriptEngineState()
    return try read(empty)
  }
  @inline(never)
  fileprivate static func nativeQueryReadShipID(at commander: UnsafePointer<Commander>) -> String {
    commander.pointer(to: \.ownedShipID)!.pointee
  }

  @inline(never)
  fileprivate static func nativeQueryReadMiningLedger(at commander: UnsafePointer<Commander>) -> MiningLedger {
    commander.pointer(to: \.savedMiningLedger)!.pointee ?? MiningLedger()
  }

  @inline(never)
  fileprivate static func nativeQueryReadCrimeLedger(at commander: UnsafePointer<Commander>) -> CrimeLedger {
    commander.pointer(to: \.savedCrimeLedger)!.pointee ?? CrimeLedger()
  }

  @inline(never)
  fileprivate static func nativeQueryReadBlackjack(at commander: UnsafePointer<Commander>) -> BlackjackMission {
    commander.pointer(to: \.blackjackMission)!.pointee ?? BlackjackMission()
  }

  @inline(never)
  fileprivate static func nativeQueryReadMissionStage(at commander: UnsafePointer<Commander>) -> NavalMissionStage {
    commander.pointer(to: \.navalMission)!.pointee ?? .notStarted
  }

  @inline(never)
  fileprivate static func nativeMechanicalReadNPCPersistence(at commander: UnsafePointer<Commander>) -> NPCPersistenceLedger {
    commander.pointer(to: \.savedNPCPersistence)!.pointee ?? NPCPersistenceLedger()
  }

  @inline(never)
  fileprivate static func nativeStartupInventory(at commander: UnsafePointer<Commander>) -> OwnedEquipmentInventory? {
    commander.pointer(to: \.savedEquipmentInventory)!.pointee
  }

  @inline(never)
  fileprivate static func nativeStartupNativePerformance(at commander: UnsafePointer<Commander>) -> ShipPerformance {
    let shipID = nativeQueryReadShipID(at: commander)
    precondition(!OriginalDetailedHullStage.blocksRuntime(shipID), "Pending original hull has no physical performance")
    return ShipCatalogue.ship(shipID)!.game!
  }

  @inline(never)
  private static func nativeStartupAlienSummary(
    _ kind: AlienModuleKind, at commander: UnsafePointer<Commander>
  ) -> AlienAttachmentSummary {
    guard let hull = nativeStartupInventory(at: commander)?.activeHull,
      let current = commander.pointer(to: \.alienStorageState)!.pointee?.current,
      current.owner == nativeStartupInventory(at: commander)?.owner
    else { return .init(count: 0, bonusBasisPoints: 0) }
    return current.summaries(for: hull)[kind] ?? .init(count: 0, bonusBasisPoints: 0)
  }

  @inline(never)
  private static func nativeStartupAlienDrive(at commander: UnsafePointer<Commander>) -> HyperspaceDrivePolicy? {
    guard let hull = nativeStartupInventory(at: commander)?.activeHull,
      let storage = commander.pointer(to: \.alienStorageState)!.pointee?.current,
      storage.owner == nativeStartupInventory(at: commander)?.owner,
      (storage.summaries(for: hull)[.hyperspaceDrive]?.count ?? 0) > 0
    else { return nil }
    return .alienFoundation
  }

  @inline(never)
  private static func nativeStartupDrive(at commander: UnsafePointer<Commander>) -> HyperspaceDrivePolicy? {
    if let alien = nativeStartupAlienDrive(at: commander) { return alien }
    let ratio = fittedComponent(in: nativeStartupInventory(at: commander), at: .navigation)?.statistics[.jumpSpool] ?? 1
    return try? HyperspaceDrivePolicy.normal(
      component: fittedComponent(in: nativeStartupInventory(at: commander), at: .drive),
      navigationSpoolMultiplier: ratio)
  }

  @inline(never)
  fileprivate static func nativeStartupPerformance(at commander: UnsafePointer<Commander>) -> ShipPerformance {
    var result = nativeStartupNativePerformance(at: commander)
    if let ratio = fittedComponent(in: nativeStartupInventory(at: commander), at: .energy)?.statistics[.energyCapacity] {
      result.energy *= ratio
    }
    result.energy *= nativeStartupAlienSummary(.energyCapacity, at: commander).multiplier
    if let policy = nativeStartupDrive(at: commander), case .timed(let seconds) = policy.activation {
      result.spool = seconds
    }
    return result
  }

  @inline(never)
  private static func nativeStartupShieldBooster(at commander: UnsafePointer<Commander>) -> ShieldBooster? {
    if nativeStartupInventory(at: commander) != nil {
      return fittedEquipment(in: nativeStartupInventory(at: commander), at: .shield).flatMap { ShieldBooster.from($0.node.key) }
    }
    return commander.pointer(to: \.equipment)!.pointee.compactMap(ShieldBooster.from).max()
  }

  @inline(never)
  fileprivate static func nativeStartupShield(at commander: UnsafePointer<Commander>, front: Bool) -> Double {
    nativeStartupNativePerformance(at: commander).shield
      * (fittedComponent(in: nativeStartupInventory(at: commander), at: .shield)?.statistics[
        front ? .frontShieldCapacity : .rearShieldCapacity]
        ?? nativeStartupShieldBooster(at: commander)?.multiplier ?? 1)
      * nativeStartupAlienSummary(.shieldCapacity, at: commander).multiplier
  }

  @inline(never)
  fileprivate static func nativeStartupFuel(at commander: UnsafePointer<Commander>) -> Int {
    let performance = nativeStartupPerformance(at: commander)
    let units: Int
    if let inventory = nativeStartupInventory(at: commander) {
      units = inventory.items.filter {
        if case .some(.fuelStorage) = $0.location?.slot { return true }
        return false
      }.count
    } else {
      units = commander.pointer(to: \.storageUnitCount)!.pointee ?? 0
    }
    return performance.fuel + FuelStorage.unitCapacity * units
  }

  @inline(never)
  fileprivate static func nativeDurabilityBison(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.savedBisonUnitAllocations)!.pointee != nil
  }

  @inline(never)
  fileprivate static func nativeDurabilityWatcher(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee != nil
  }

  @inline(never)
  fileprivate static func nativeDurabilityPeople(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.savedNativePeopleCustodyStorage)!.pointee?.withReadOnlyValue {
      $0?.crewService != nil || $0?.clinicSource != nil || $0?.utilityEngineer != nil
    } == true
  }

  @inline(never)
  fileprivate static func nativeDurabilityUtility(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.nativeStations)!.pointee?.ledger.records.first(where: {
      NativeUtilityState.isTarget($0.identity)
    })?.utility?.consignments.isEmpty == false
  }

  @inline(never)
  fileprivate static func nativeDurabilityEMP(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.savedEMPState)!.pointee != nil
      || nativeStartupInventory(at: commander)?.items.contains {
        $0.node.key == Equipment.empPirateBlaster
      } == true
  }

  @inline(never)
  fileprivate static func nativeDurabilityAlien(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.savedAlienStorageReference)!.pointee != nil
      || commander.pointer(to: \.alienStorageState)!.pointee != nil
  }

  @inline(never)
  fileprivate static func nativeDurabilityNewt(at commander: UnsafePointer<Commander>) -> Bool {
    if CurrentNewtKitSave.hasEncounterClaims(commander.pointer(to: \.encounterDirector)!.pointee) {
      return true
    }
    if nativeMechanicalReadNPCPersistence(at: commander).hasCurrentNewtKitClaims { return true }
    return CurrentNewtKitSave.hasEMPClaims(commander.pointer(to: \.savedEMPState)!.pointee)
  }

  @inline(never)
  fileprivate static func nativeDurabilityLegacy(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.legacyOwnedEquipment)!.pointee != nil
  }

  @inline(never)
  fileprivate static func nativeDurabilityCalendar(at commander: UnsafePointer<Commander>) -> Bool {
    nativeStationReadScriptState(at: commander) { state in
      state.pointer(to: \.calendarLedger)!.pointee != nil
    }
  }

  @inline(never)
  fileprivate static func nativeDurabilityInstances(at commander: UnsafePointer<Commander>) -> Bool {
    nativeStationReadScriptState(at: commander) { state in
      !state.pointer(to: \.instances)!.pointee.isEmpty
    }
  }

  @inline(never)
  fileprivate static func nativeDurabilityContracts(at commander: UnsafePointer<Commander>) -> Bool {
    !(commander.pointer(to: \.savedContracts)!.pointee ?? ScriptContractState()).boards.isEmpty
  }

  @inline(never)
  fileprivate static func nativeDurabilityScript(at commander: UnsafePointer<Commander>) -> Bool {
    nativeStationReadScriptState(at: commander) { state in
      state.pointee != ScriptEngineState()
    }
  }

  @inline(never)
  fileprivate static func nativeDurabilityAccommodation(at commander: UnsafePointer<Commander>) -> Bool {
    (commander.pointer(to: \.savedAccommodation)!.pointee ?? ShipAccommodation()) != ShipAccommodation()
  }

  @inline(never)
  fileprivate static func nativeGeometryReadWorldOwnedPod(
    _ person: EMPCrewIdentity, at commander: UnsafePointer<Commander>
  ) -> Bool {
    !(commander.pointer(to: \.savedNativePeopleCustodyStorage)!.pointee?.withReadOnlyValue {
      $0?.admissions.contains { $0.person == .emp(person) } ?? false
    } ?? false)
  }

  @inline(never)
  static func nativeCapturedServiceEMP(at commander: UnsafePointer<Commander>) -> EMPState? {
    commander.pointer(to: \.savedEMPState)!.pointee
  }

  @inline(never)
  static func nativeCapturedServiceAdmissions(
    _ person: EMPCrewIdentity, at commander: UnsafePointer<Commander>
  ) -> [NativePeopleAdmission] {
    commander.pointer(to: \.savedNativePeopleCustodyStorage)!.pointee?.withReadOnlyValue {
      $0?.admissions.filter { $0.person == .emp(person) } ?? []
    } ?? []
  }

  @inline(never)
  static func nativeCapturedServicePhysicalTime(at commander: UnsafePointer<Commander>) -> Double {
    nativeStationReadFlight(at: commander).physicalTime
  }

  @inline(never)
  static func nativeCapturedServiceWorldOwnedPod(
    _ person: EMPCrewIdentity, at commander: UnsafePointer<Commander>
  ) -> Bool {
    nativeGeometryReadWorldOwnedPod(person, at: commander)
  }

  @inline(never)
  fileprivate static func nativeStationAutoReadXYZzyActive(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.xyzzyEnabled)!.pointee ?? false
  }

  @inline(never)
  fileprivate static func nativeStationAutoReadTargetFlag(at commander: UnsafePointer<Commander>) -> Bool {
    commander.pointer(to: \.automaticTargeting)!.pointee ?? false
  }

  @inline(never)
  fileprivate static func nativeStationAutoReadTier(at commander: UnsafePointer<Commander>) -> TargetingTier? {
    fittedEquipment(in: nativeStartupInventory(at: commander), at: .targetingCore)
      .flatMap { TargetingTier.from($0.node.key) }
  }

  @inline(never)
  fileprivate static func nativeStationAutoReadLaserMounts(at commander: UnsafePointer<Commander>) -> LaserMounts {
    guard nativeStartupInventory(at: commander) != nil else {
      if let mounted = commander.pointer(to: \.mountedLasers)!.pointee { return mounted }
      let equipment = commander.pointer(to: \.equipment)!.pointee
      let legacy = [LaserKind.naval, .military, .beam, .mining, .pulse].first {
        equipment.contains($0.equipmentName)
      }
      return LaserMounts(front: legacy)
    }
    var mounts = LaserMounts()
    for mount in LaserMount.allCases {
      mounts[mount] = fittedEquipment(in: nativeStartupInventory(at: commander), at: .laser(mount))
        .flatMap { LaserKind.from($0.node.key) }
    }
    return mounts
  }

  @inline(never)
  fileprivate static func nativeFrameReadEnergyRecharge(at commander: UnsafePointer<Commander>) -> Double {
    if let multiplier = fittedComponent(in: nativeStartupInventory(at: commander), at: .energy)?.statistics[.energyRecharge] {
      return multiplier * nativeStartupAlienSummary(.energyRecharge, at: commander).multiplier
    }
    let equipment = commander.pointer(to: \.equipment)!.pointee
    let ordinary: Double
    if equipment.contains(Equipment.eliteEnergyUnit) { ordinary = 4 }
    else if equipment.contains(Equipment.navalEnergyUnit) { ordinary = 3 }
    else { ordinary = equipment.contains("Extra Energy Unit") ? 2 : 1 }
    return ordinary * nativeStartupAlienSummary(.energyRecharge, at: commander).multiplier
  }

  @inline(never)
  fileprivate static func nativeFrameReadShieldRecharge(
    at commander: UnsafePointer<Commander>, front: Bool
  ) -> Double {
    nativeStartupNativePerformance(at: commander).shieldRecharge
      * (fittedComponent(in: nativeStartupInventory(at: commander), at: .shield)?.statistics[
        front ? .frontShieldRecharge : .rearShieldRecharge] ?? 1)
      * nativeStartupAlienSummary(.shieldRecharge, at: commander).multiplier
  }

  // Read only child storage here: no Commander value crosses the pointer boundary.
  @inline(never)
  fileprivate static func nativeStationReadScriptState<Result>(
    at commander: UnsafePointer<Commander>,
    _ read: (UnsafePointer<ScriptEngineState>) -> Result
  ) -> Result {
    guard let storage = commander.pointer(to: \.savedScriptState) else {
      preconditionFailure("Native station validation requires addressable stored script state.")
    }
    if let stored = storage.pointee {
      return stored.withNativeStationReadOnlyValue(read)
    }
    return Self.nativeStationReadDefaultScriptState(read)
  }

  @inline(never)
  private static func nativeStationReadDefaultScriptState<Result>(
    _ read: (UnsafePointer<ScriptEngineState>) -> Result
  ) -> Result {
    let empty = ScriptEngineState()
    return withUnsafePointer(to: empty) { pointer in read(pointer) }
  }

  @inline(never)
  fileprivate static func nativeStationReadFlight(
    at commander: UnsafePointer<Commander>
  ) -> FlightSimulationState {
    guard let storage = commander.pointer(to: \.savedFlightSimulation) else {
      preconditionFailure("Native station validation requires addressable stored flight state.")
    }
    if let flight = storage.pointee { return flight }
    return FlightSimulationState()
  }

  @inline(never)
  fileprivate static func nativeStationReadSystem(
    at commander: UnsafePointer<Commander>
  ) -> SystemIdentity {
    guard let galaxy = commander.pointer(to: \.galaxy),
      let system = commander.pointer(to: \.system)
    else {
      preconditionFailure(
        "Native station validation requires addressable stored system coordinates.")
    }
    return SystemIdentity(galaxy: galaxy.pointee, system: system.pointee)
  }

  @inline(never)
  fileprivate static func nativeNPCPersistenceCount(at commander: UnsafePointer<Commander>) -> Int {
    guard let storage = commander.pointer(to: \.savedNPCPersistence) else {
      preconditionFailure("Admission requires addressable stored NPC persistence.")
    }
    return storage.pointee?.count ?? 0
  }

  @inline(never)
  static func nativeStationStateIsValid(_ commander: borrowing Commander) -> Bool {
    withUnsafePointer(to: commander) { pointer in
      Self.nativeStationStateIsValid(at: pointer)
    }
  }

  // Capture only this read-only pointer, never the borrowed Commander, in the policy readers.
  fileprivate static func nativeStationStateIsValid(at commander: UnsafePointer<Commander>) -> Bool
  {
    NativeStationStateValidation.check(
      readWorld: {
        guard let world = commander.pointer(to: \.nativeStations) else {
          preconditionFailure("Native station validation requires addressable stored world.")
        }
        return world.pointee
      },
      readResources: {
        Self.nativeStationReadScriptState(at: commander) { state in
          guard let resources = state.pointer(to: \.savedStationResources) else {
            preconditionFailure("Native station validation requires addressable stored resources.")
          }
          return resources.pointee ?? [:]
        }
      },
      readSystem: {
        Self.nativeStationReadSystem(at: commander)
      },
      readOwner: {
        guard let inventory = commander.pointer(to: \.savedEquipmentInventory) else {
          preconditionFailure("Native station validation requires addressable stored equipment.")
        }
        return inventory.pointee?.owner
      },
      readPhysicalTime: { Self.nativeStationReadFlight(at: commander).physicalTime },
      readStationPosition: {
        Self.nativeStationReadFlight(at: commander).anchors?.station.position
      },
      readCalendar: {
        Self.nativeStationReadScriptState(at: commander) { state in
          guard let calendar = state.pointer(to: \.calendarLedger) else {
            preconditionFailure("Native station validation requires addressable stored calendar.")
          }
          return calendar.pointee
        }
      })
  }

  var savedEquipmentInventory: OwnedEquipmentInventory?
  var savedEquipmentPurchaseHistory: EquipmentPurchaseHistory?
  var savedEMPState: EMPState?
  var savedPlayerElectrical: ElectricalReserve?
  var savedEMPCharge: EMPChargeState?
  var savedCrimboState: NativeCrimboRegistry?
  private var savedNativePeopleCustodyStorage: CommanderNativePeopleCustodyStorage?

  @inline(never)
  func nativePeopleCustodyIsPresent() -> Bool {
    guard let stored = savedNativePeopleCustodyStorage else { return false }
    return stored.withReadOnlyValue {
      if case .none = $0 { return false }
      return true
    }
  }

  var savedNativePeopleCustody: NativePeopleCustodyState? {
    _read {
      if let stored = savedNativePeopleCustodyStorage {
        yield stored.value
      } else {
        let absent: NativePeopleCustodyState? = nil
        yield absent
      }
    }
    set {
      if let newValue {
        savedNativePeopleCustodyStorage = .init(newValue)
      } else {
        savedNativePeopleCustodyStorage = nil
      }
    }
    _modify {
      if case .none = savedNativePeopleCustodyStorage {
        savedNativePeopleCustodyStorage = .init(nil)
      }
      defer {
        // A nil inout result must retain the original absent-key encoding and equality.
        if savedNativePeopleCustodyStorage?.withReadOnlyValue({
          if case .none = $0 { return true }
          return false
        }) == true {
          savedNativePeopleCustodyStorage = nil
        }
      }
      yield &savedNativePeopleCustodyStorage!.value
    }
  }
  var savedSalvageLedger: SalvageLedger?
  var savedAlienStorageReference: AlienStorageReference?
  var alienStorageState: AlienCommanderStorage? = nil
  var savedEquipmentVersion: Int?
  var nativeStations: NativeStationWorld?
  // Optional means no Bison reservation has been allocated; reads never create one.
  var savedBisonUnitAllocations: BisonUnitAllocationJournal?
  private var savedFlightSimulation: FlightSimulationState?
  public var flightSimulation: FlightSimulationState {
    _read {
      if case .some = savedFlightSimulation {
        yield savedFlightSimulation!
      } else {
        let empty = FlightSimulationState()
        yield empty
      }
    }
    set { savedFlightSimulation = newValue }
  }
  private var savedCrimeLedger: CrimeLedger?
  public var crimeLedger: CrimeLedger {
    get { savedCrimeLedger ?? CrimeLedger() }
    set { savedCrimeLedger = newValue }
  }
  private var savedStationSecurity: StationSecurity?
  public var stationSecurity: StationSecurity {
    get { savedStationSecurity ?? StationSecurity() }
    set { savedStationSecurity = newValue }
  }
  public var encounterDirector: EncounterDirector?
  private var savedWantedCareers: WantedCareerLedger?
  public var wantedCareers: WantedCareerLedger {
    get { savedWantedCareers ?? WantedCareerLedger() }
    set { savedWantedCareers = newValue }
  }
  /// Optional chaining preserves the absent state when no careers have been recorded.
  mutating func resetWantedCareerBindings(system: SystemIdentity) {
    savedWantedCareers?.resetPhysicalBindings(system: system)
  }
  private var savedNPCPersistence: NPCPersistenceLedger?
  public var npcPersistence: NPCPersistenceLedger {
    get { savedNPCPersistence ?? NPCPersistenceLedger() }
    set { savedNPCPersistence = newValue }
  }
  private var savedCargoDebrisLedger: CargoDebrisLedger?
  public var cargoDebrisLedger: CargoDebrisLedger {
    get { savedCargoDebrisLedger ?? CargoDebrisLedger() }
    set { savedCargoDebrisLedger = newValue }
  }
  private var savedMiningLedger: MiningLedger?
  var usesRingMiningSaveVersion: Bool { savedMiningLedger?.usesRingSaveVersion == true }
  var usesEconomyMiningSaveVersion: Bool {
    savedMiningLedger?.usesEconomyWeightedPresence == true
  }
  func miningLedgerForMigration(legacyMissing: Bool) -> MiningLedger {
    savedMiningLedger ?? (legacyMissing ? .legacyUnworked() : MiningLedger())
  }
  public var miningLedger: MiningLedger {
    get { savedMiningLedger ?? MiningLedger() }
    set { savedMiningLedger = newValue }
  }
  private var savedMissionProgress: [String: MissionProgress]?
  public var missionProgress: [String: MissionProgress] {
    get { savedMissionProgress ?? [:] }
    set { savedMissionProgress = newValue }
  }
  public var missionPayloadTonnes: Int {
    checkedMissionPayloadTonnes ?? Int.max
  }
  private var wantedAmnesty: Bool?
  public var xyzzyWantedAmnesty: Bool {
    get { wantedAmnesty ?? false }
    set { wantedAmnesty = newValue }
  }
  private var ownedShipID: String
  public var shipID: String {
    get { ownedShipID }
    set { ownedShipID = newValue }
  }
  public var originalMarkets = OriginalLiveMarkets()
  public var name = NewCommanderDefaults.name
  public var credits = NewCommanderDefaults.credits
  public var fuel = NewCommanderDefaults.fuel
  public var galaxy = NewCommanderDefaults.galaxy
  public var system = NewCommanderDefaults.system
  public var cargo = Array(repeating: 0, count: 17)
  public var equipment: Set<String> = ["Pulse Laser"]
  public var missiles = 3
  public var kills = 0
  public var legal = 0
  public var unlimitedMissiles = false
  public var unlimitedCargo = false
  public var unlimitedCash = false
  public var unlimitedFuel = false
  public var unlimitedJumps = false
  public var autoTrade = false
  public var speech = false
  public var executive = false
  // Optional storage preserves compatibility with commanders saved before each feature existed.
  private var discoveredSecretPorts: Int?
  public var plughDiscoveryMask: Int {
    get { discoveredSecretPorts ?? 0 }
    set { discoveredSecretPorts = newValue }
  }
  private var blackjackMission: BlackjackMission?
  public var blackjack: BlackjackMission {
    get { blackjackMission ?? BlackjackMission() }
    set { blackjackMission = newValue }
  }
  public var markedFirearms: Int {
    Self.hasMarkedFirearm(blackjackMission) { $0.carriesFirearm } ? 1 : 0
  }

  // Match the optional in place so this cargo read borrows a retained encounter.
  @inline(never)
  private static func hasMarkedFirearm<Stored: ~Copyable>(
    _ mission: borrowing Stored?, _ carriesFirearm: (borrowing Stored) -> Bool
  ) -> Bool {
    switch mission {
    case .some(let retained):
      return carriesFirearm(retained)
    case .none:
      return false
    }
  }

  private var displayStyle: ShipDisplayStyle?
  private var navalMission: NavalMissionStage?
  private var xyzzyEnabled: Bool?
  private var automaticProfitScan: Bool?
  public var profitScanEnabled: Bool {
    get { automaticProfitScan ?? false }
    set { automaticProfitScan = newValue }
  }
  private var automaticECM: Bool?
  private var automaticTargeting: Bool?
  private var returnFireEnabled: Bool?
  private var capitalReward: Bool?
  private var navigationRoute: NavigationPlan?
  private var storageUnitCount: Int?
  private var mountedLasers: LaserMounts?
  public var laserMounts: LaserMounts {
    get {
      guard equipmentInventory != nil else {
        return mountedLasers ?? LaserMounts(front: legacyLaser)
      }
      var mounts = LaserMounts()
      for mount in LaserMount.allCases {
        mounts[mount] = fittedEquipment(at: .laser(mount)).flatMap { LaserKind.from($0.node.key) }
      }
      return mounts
    }
    set { mountedLasers = newValue }
  }
  private var finiteXYZzyCash: Bool?
  public var xyzzyCashGranted: Bool {
    get { finiteXYZzyCash ?? false }
    set { finiteXYZzyCash = newValue }
  }
  public var fuelStorageUnits: Int {
    get {
      guard let inventory = equipmentInventory else { return storageUnitCount ?? 0 }
      return inventory.items.filter {
        if case .some(.fuelStorage) = $0.location?.slot { return true }
        return false
      }.count
    }
    set { storageUnitCount = newValue }
  }
  public var navigationPlan: NavigationPlan? {
    get { navigationRoute }
    set { navigationRoute = newValue }
  }
  public var capitalRewardClaimed: Bool {
    get { capitalReward ?? false }
    set { capitalReward = newValue }
  }
  public var retaliationEnabled: Bool {
    get { returnFireEnabled ?? true }
    set { returnFireEnabled = newValue }
  }
  public var xyzzyActive: Bool {
    get { xyzzyEnabled ?? false }
    set { xyzzyEnabled = newValue }
  }
  public var autoECM: Bool {
    get { automaticECM ?? false }
    set { automaticECM = newValue }
  }
  public var autoTarget: Bool {
    get { automaticTargeting ?? false }
    set { automaticTargeting = newValue }
  }
  public var missionStage: NavalMissionStage {
    get { navalMission ?? .notStarted }
    set { navalMission = newValue }
  }
  public var shipDisplayStyle: ShipDisplayStyle {
    get { displayStyle ?? .shadedPanels }
    set { displayStyle = newValue }
  }
  mutating func migrateLegacyXYZzyMounts() {
    if mountedLasers == nil && xyzzyActive {
      mountedLasers = LaserMounts(front: .naval, left: .naval, right: .naval, rear: .naval)
      equipment.insert(Equipment.navalLaser)
    }
  }
  private enum CodingKeys: String, CodingKey {
    case savedMemoryAtlasWatcherSourceStorage = "savedMemoryAtlasWatcherSource"
    case savedContracts
    case legacyOwnedEquipment = "ownedEquipment"
    case savedAccommodation
    case savedScriptState
    case savedEquipmentInventory
    case savedEquipmentPurchaseHistory
    case savedEMPState
    case savedPlayerElectrical
    case savedEMPCharge
    case savedNativePeopleCustodyStorage = "savedNativePeopleCustody"
    case savedCrimboState
    case savedSalvageLedger
    case savedAlienStorageReference
    case savedEquipmentVersion
    case nativeStations
    case savedFlightSimulation
    case savedBisonUnitAllocations
    case savedCrimeLedger
    case savedStationSecurity
    case encounterDirector
    case savedNPCPersistence
    case savedWantedCareers
    case savedCargoDebrisLedger
    case savedMiningLedger
    case savedMissionProgress
    case wantedAmnesty
    case ownedShipID
    case originalMarkets
    case name
    case credits
    case fuel
    case galaxy
    case system
    case cargo
    case equipment
    case missiles
    case kills
    case legal
    case unlimitedMissiles
    case unlimitedCargo
    case unlimitedCash
    case unlimitedFuel
    case unlimitedJumps
    case autoTrade
    case speech
    case executive
    case discoveredSecretPorts
    case blackjackMission
    case displayStyle
    case navalMission
    case xyzzyEnabled
    case automaticProfitScan
    case automaticECM
    case automaticTargeting
    case returnFireEnabled
    case capitalReward
    case navigationRoute
    case storageUnitCount
    case mountedLasers
    case finiteXYZzyCash
  }

  // Preserve all stored-value comparisons in their original short-circuit order.
  // Borrow the public operands and project each owned child from its actual field;
  // no whole Commander is copied into a field helper or retained by its frame.
  @inline(never)
  public static func == (_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
    guard equalSavedMemoryAtlasWatcherSourceStorage(lhs, rhs) else { return false }
    guard equalSavedContracts(lhs, rhs) else { return false }
    guard equalLegacyOwnedEquipment(lhs, rhs) else { return false }
    guard equalSavedAccommodation(lhs, rhs) else { return false }
    guard equalSavedScriptState(lhs, rhs) else { return false }
    guard equalSavedEquipmentInventory(lhs, rhs) else { return false }
    guard equalSavedEquipmentPurchaseHistory(lhs, rhs) else { return false }
    guard equalSavedEMPState(lhs, rhs) else { return false }
    guard equalSavedPlayerElectrical(lhs, rhs) else { return false }
    guard equalSavedEMPCharge(lhs, rhs) else { return false }
    guard equalSavedCrimboState(lhs, rhs) else { return false }
    guard equalSavedNativePeopleCustodyStorage(lhs, rhs) else { return false }
    guard equalSavedSalvageLedger(lhs, rhs) else { return false }
    guard equalSavedAlienStorageReference(lhs, rhs) else { return false }
    guard equalAlienStorageState(lhs, rhs) else { return false }
    guard equalSavedEquipmentVersion(lhs, rhs) else { return false }
    guard equalNativeStations(lhs, rhs) else { return false }
    guard equalSavedFlightSimulation(lhs, rhs) else { return false }
    guard equalSavedBisonUnitAllocations(lhs, rhs) else { return false }
    guard equalSavedCrimeLedger(lhs, rhs) else { return false }
    guard equalSavedStationSecurity(lhs, rhs) else { return false }
    guard equalEncounterDirector(lhs, rhs) else { return false }
    guard equalSavedWantedCareers(lhs, rhs) else { return false }
    guard equalSavedNPCPersistence(lhs, rhs) else { return false }
    guard equalSavedCargoDebrisLedger(lhs, rhs) else { return false }
    guard equalSavedMiningLedger(lhs, rhs) else { return false }
    guard equalSavedMissionProgress(lhs, rhs) else { return false }
    guard equalWantedAmnesty(lhs, rhs) else { return false }
    guard equalOwnedShipID(lhs, rhs) else { return false }
    guard equalOriginalMarkets(lhs, rhs) else { return false }
    guard equalName(lhs, rhs) else { return false }
    guard equalCredits(lhs, rhs) else { return false }
    guard equalFuel(lhs, rhs) else { return false }
    guard equalGalaxy(lhs, rhs) else { return false }
    guard equalSystem(lhs, rhs) else { return false }
    guard equalCargo(lhs, rhs) else { return false }
    guard equalEquipment(lhs, rhs) else { return false }
    guard equalMissiles(lhs, rhs) else { return false }
    guard equalKills(lhs, rhs) else { return false }
    guard equalLegal(lhs, rhs) else { return false }
    guard equalUnlimitedMissiles(lhs, rhs) else { return false }
    guard equalUnlimitedCargo(lhs, rhs) else { return false }
    guard equalUnlimitedCash(lhs, rhs) else { return false }
    guard equalUnlimitedFuel(lhs, rhs) else { return false }
    guard equalUnlimitedJumps(lhs, rhs) else { return false }
    guard equalAutoTrade(lhs, rhs) else { return false }
    guard equalSpeech(lhs, rhs) else { return false }
    guard equalExecutive(lhs, rhs) else { return false }
    guard equalDiscoveredSecretPorts(lhs, rhs) else { return false }
    guard equalBlackjackMission(lhs, rhs) else { return false }
    guard equalDisplayStyle(lhs, rhs) else { return false }
    guard equalNavalMission(lhs, rhs) else { return false }
    guard equalXyzzyEnabled(lhs, rhs) else { return false }
    guard equalAutomaticProfitScan(lhs, rhs) else { return false }
    guard equalAutomaticECM(lhs, rhs) else { return false }
    guard equalAutomaticTargeting(lhs, rhs) else { return false }
    guard equalReturnFireEnabled(lhs, rhs) else { return false }
    guard equalCapitalReward(lhs, rhs) else { return false }
    guard equalNavigationRoute(lhs, rhs) else { return false }
    guard equalStorageUnitCount(lhs, rhs) else { return false }
    guard equalMountedLasers(lhs, rhs) else { return false }
    guard equalFiniteXYZzyCash(lhs, rhs) else { return false }
    return true
  }

  // Both pointers are synchronous borrows of live storage. Only Bool returns.
  @inline(never)
  fileprivate static func storedValuesEqual(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    guard equalSavedMemoryAtlasWatcherSourceStorage(lhs, rhs) else { return false }
    guard equalSavedContracts(lhs, rhs) else { return false }
    guard equalLegacyOwnedEquipment(lhs, rhs) else { return false }
    guard equalSavedAccommodation(lhs, rhs) else { return false }
    guard equalSavedScriptState(lhs, rhs) else { return false }
    guard equalSavedEquipmentInventory(lhs, rhs) else { return false }
    guard equalSavedEquipmentPurchaseHistory(lhs, rhs) else { return false }
    guard equalSavedEMPState(lhs, rhs) else { return false }
    guard equalSavedPlayerElectrical(lhs, rhs) else { return false }
    guard equalSavedEMPCharge(lhs, rhs) else { return false }
    guard equalSavedCrimboState(lhs, rhs) else { return false }
    guard equalSavedNativePeopleCustodyStorage(lhs, rhs) else { return false }
    guard equalSavedSalvageLedger(lhs, rhs) else { return false }
    guard equalSavedAlienStorageReference(lhs, rhs) else { return false }
    guard equalAlienStorageState(lhs, rhs) else { return false }
    guard equalSavedEquipmentVersion(lhs, rhs) else { return false }
    guard equalNativeStations(lhs, rhs) else { return false }
    guard equalSavedFlightSimulation(lhs, rhs) else { return false }
    guard equalSavedBisonUnitAllocations(lhs, rhs) else { return false }
    guard equalSavedCrimeLedger(lhs, rhs) else { return false }
    guard equalSavedStationSecurity(lhs, rhs) else { return false }
    guard equalEncounterDirector(lhs, rhs) else { return false }
    guard equalSavedWantedCareers(lhs, rhs) else { return false }
    guard equalSavedNPCPersistence(lhs, rhs) else { return false }
    guard equalSavedCargoDebrisLedger(lhs, rhs) else { return false }
    guard equalSavedMiningLedger(lhs, rhs) else { return false }
    guard equalSavedMissionProgress(lhs, rhs) else { return false }
    guard equalWantedAmnesty(lhs, rhs) else { return false }
    guard equalOwnedShipID(lhs, rhs) else { return false }
    guard equalOriginalMarkets(lhs, rhs) else { return false }
    guard equalName(lhs, rhs) else { return false }
    guard equalCredits(lhs, rhs) else { return false }
    guard equalFuel(lhs, rhs) else { return false }
    guard equalGalaxy(lhs, rhs) else { return false }
    guard equalSystem(lhs, rhs) else { return false }
    guard equalCargo(lhs, rhs) else { return false }
    guard equalEquipment(lhs, rhs) else { return false }
    guard equalMissiles(lhs, rhs) else { return false }
    guard equalKills(lhs, rhs) else { return false }
    guard equalLegal(lhs, rhs) else { return false }
    guard equalUnlimitedMissiles(lhs, rhs) else { return false }
    guard equalUnlimitedCargo(lhs, rhs) else { return false }
    guard equalUnlimitedCash(lhs, rhs) else { return false }
    guard equalUnlimitedFuel(lhs, rhs) else { return false }
    guard equalUnlimitedJumps(lhs, rhs) else { return false }
    guard equalAutoTrade(lhs, rhs) else { return false }
    guard equalSpeech(lhs, rhs) else { return false }
    guard equalExecutive(lhs, rhs) else { return false }
    guard equalDiscoveredSecretPorts(lhs, rhs) else { return false }
    guard equalBlackjackMission(lhs, rhs) else { return false }
    guard equalDisplayStyle(lhs, rhs) else { return false }
    guard equalNavalMission(lhs, rhs) else { return false }
    guard equalXyzzyEnabled(lhs, rhs) else { return false }
    guard equalAutomaticProfitScan(lhs, rhs) else { return false }
    guard equalAutomaticECM(lhs, rhs) else { return false }
    guard equalAutomaticTargeting(lhs, rhs) else { return false }
    guard equalReturnFireEnabled(lhs, rhs) else { return false }
    guard equalCapitalReward(lhs, rhs) else { return false }
    guard equalNavigationRoute(lhs, rhs) else { return false }
    guard equalStorageUnitCount(lhs, rhs) else { return false }
    guard equalMountedLasers(lhs, rhs) else { return false }
    guard equalFiniteXYZzyCash(lhs, rhs) else { return false }
    return true
  }

  // Public operands are borrowed values, not buffer pointers. Read one owned
  // field from each operand in separate sibling scopes; neither closure captures
  // the other borrowed Commander. Both pointers die before comparing the exact
  // child values, and each field frame retires before the next ordered guard.
  @inline(never)
  private static func equalSavedMemoryAtlasWatcherSourceStorage(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedContracts(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedContracts)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedContracts)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalLegacyOwnedEquipment(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.legacyOwnedEquipment)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.legacyOwnedEquipment)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedAccommodation(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedAccommodation)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedAccommodation)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedScriptState(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedScriptState)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedScriptState)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedEquipmentInventory(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedEquipmentInventory)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedEquipmentInventory)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedEquipmentPurchaseHistory(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedEquipmentPurchaseHistory)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedEquipmentPurchaseHistory)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedEMPState(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedEMPState)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedEMPState)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedPlayerElectrical(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedPlayerElectrical)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedPlayerElectrical)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedEMPCharge(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedEMPCharge)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedEMPCharge)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedCrimboState(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedCrimboState)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedCrimboState)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedNativePeopleCustodyStorage(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedNativePeopleCustodyStorage)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedNativePeopleCustodyStorage)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedSalvageLedger(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedSalvageLedger)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedSalvageLedger)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedAlienStorageReference(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedAlienStorageReference)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedAlienStorageReference)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalAlienStorageState(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.alienStorageState)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.alienStorageState)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedEquipmentVersion(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedEquipmentVersion)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedEquipmentVersion)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalNativeStations(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.nativeStations)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.nativeStations)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedFlightSimulation(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedFlightSimulation)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedFlightSimulation)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedBisonUnitAllocations(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedBisonUnitAllocations)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedBisonUnitAllocations)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedCrimeLedger(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedCrimeLedger)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedCrimeLedger)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedStationSecurity(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedStationSecurity)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedStationSecurity)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalEncounterDirector(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.encounterDirector)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.encounterDirector)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedWantedCareers(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedWantedCareers)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedWantedCareers)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedNPCPersistence(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedNPCPersistence)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedNPCPersistence)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedCargoDebrisLedger(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedCargoDebrisLedger)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedCargoDebrisLedger)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedMiningLedger(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedMiningLedger)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedMiningLedger)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedMissionProgress(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.savedMissionProgress)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.savedMissionProgress)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalWantedAmnesty(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.wantedAmnesty)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.wantedAmnesty)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalOwnedShipID(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.ownedShipID)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.ownedShipID)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalOriginalMarkets(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.originalMarkets)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.originalMarkets)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalName(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.name)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.name)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalCredits(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.credits)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.credits)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalFuel(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.fuel)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.fuel)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalGalaxy(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.galaxy)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.galaxy)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSystem(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.system)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.system)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalCargo(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.cargo)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.cargo)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalEquipment(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.equipment)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.equipment)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalMissiles(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.missiles)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.missiles)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalKills(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.kills)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.kills)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalLegal(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.legal)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.legal)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalUnlimitedMissiles(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.unlimitedMissiles)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.unlimitedMissiles)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalUnlimitedCargo(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.unlimitedCargo)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.unlimitedCargo)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalUnlimitedCash(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.unlimitedCash)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.unlimitedCash)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalUnlimitedFuel(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.unlimitedFuel)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.unlimitedFuel)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalUnlimitedJumps(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.unlimitedJumps)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.unlimitedJumps)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalAutoTrade(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.autoTrade)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.autoTrade)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSpeech(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.speech)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.speech)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalExecutive(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.executive)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.executive)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalDiscoveredSecretPorts(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.discoveredSecretPorts)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.discoveredSecretPorts)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalBlackjackMission(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.blackjackMission)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.blackjackMission)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalDisplayStyle(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.displayStyle)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.displayStyle)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalNavalMission(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.navalMission)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.navalMission)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalXyzzyEnabled(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.xyzzyEnabled)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.xyzzyEnabled)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalAutomaticProfitScan(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.automaticProfitScan)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.automaticProfitScan)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalAutomaticECM(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.automaticECM)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.automaticECM)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalAutomaticTargeting(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.automaticTargeting)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.automaticTargeting)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalReturnFireEnabled(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.returnFireEnabled)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.returnFireEnabled)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalCapitalReward(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.capitalReward)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.capitalReward)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalNavigationRoute(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.navigationRoute)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.navigationRoute)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalStorageUnitCount(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.storageUnitCount)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.storageUnitCount)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalMountedLasers(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.mountedLasers)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.mountedLasers)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalFiniteXYZzyCash(
    _ lhs: borrowing Self, _ rhs: borrowing Self
  ) -> Bool {
    let left = withUnsafePointer(to: lhs) { pointer in
      pointer.pointer(to: \.finiteXYZzyCash)!.pointee
    }
    let right = withUnsafePointer(to: rhs) { pointer in
      pointer.pointer(to: \.finiteXYZzyCash)!.pointee
    }
    return left == right
  }

  @inline(never)
  private static func equalSavedMemoryAtlasWatcherSourceStorage(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee == rhs.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee
  }

  @inline(never)
  private static func equalSavedContracts(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedContracts)!.pointee == rhs.pointer(to: \.savedContracts)!.pointee
  }

  @inline(never)
  private static func equalLegacyOwnedEquipment(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.legacyOwnedEquipment)!.pointee == rhs.pointer(to: \.legacyOwnedEquipment)!.pointee
  }

  @inline(never)
  private static func equalSavedAccommodation(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedAccommodation)!.pointee == rhs.pointer(to: \.savedAccommodation)!.pointee
  }

  @inline(never)
  private static func equalSavedScriptState(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedScriptState)!.pointee == rhs.pointer(to: \.savedScriptState)!.pointee
  }

  @inline(never)
  private static func equalSavedEquipmentInventory(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedEquipmentInventory)!.pointee == rhs.pointer(to: \.savedEquipmentInventory)!.pointee
  }

  @inline(never)
  private static func equalSavedEquipmentPurchaseHistory(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedEquipmentPurchaseHistory)!.pointee == rhs.pointer(to: \.savedEquipmentPurchaseHistory)!.pointee
  }

  @inline(never)
  private static func equalSavedEMPState(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedEMPState)!.pointee == rhs.pointer(to: \.savedEMPState)!.pointee
  }

  @inline(never)
  private static func equalSavedPlayerElectrical(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedPlayerElectrical)!.pointee == rhs.pointer(to: \.savedPlayerElectrical)!.pointee
  }

  @inline(never)
  private static func equalSavedEMPCharge(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedEMPCharge)!.pointee == rhs.pointer(to: \.savedEMPCharge)!.pointee
  }

  @inline(never)
  private static func equalSavedCrimboState(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedCrimboState)!.pointee == rhs.pointer(to: \.savedCrimboState)!.pointee
  }

  @inline(never)
  private static func equalSavedNativePeopleCustodyStorage(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedNativePeopleCustodyStorage)!.pointee == rhs.pointer(to: \.savedNativePeopleCustodyStorage)!.pointee
  }

  @inline(never)
  private static func equalSavedSalvageLedger(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedSalvageLedger)!.pointee == rhs.pointer(to: \.savedSalvageLedger)!.pointee
  }

  @inline(never)
  private static func equalSavedAlienStorageReference(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedAlienStorageReference)!.pointee == rhs.pointer(to: \.savedAlienStorageReference)!.pointee
  }

  @inline(never)
  private static func equalAlienStorageState(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.alienStorageState)!.pointee == rhs.pointer(to: \.alienStorageState)!.pointee
  }

  @inline(never)
  private static func equalSavedEquipmentVersion(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedEquipmentVersion)!.pointee == rhs.pointer(to: \.savedEquipmentVersion)!.pointee
  }

  @inline(never)
  private static func equalNativeStations(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.nativeStations)!.pointee == rhs.pointer(to: \.nativeStations)!.pointee
  }

  @inline(never)
  private static func equalSavedFlightSimulation(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedFlightSimulation)!.pointee == rhs.pointer(to: \.savedFlightSimulation)!.pointee
  }

  @inline(never)
  private static func equalSavedBisonUnitAllocations(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedBisonUnitAllocations)!.pointee == rhs.pointer(to: \.savedBisonUnitAllocations)!.pointee
  }

  @inline(never)
  private static func equalSavedCrimeLedger(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedCrimeLedger)!.pointee == rhs.pointer(to: \.savedCrimeLedger)!.pointee
  }

  @inline(never)
  private static func equalSavedStationSecurity(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedStationSecurity)!.pointee == rhs.pointer(to: \.savedStationSecurity)!.pointee
  }

  @inline(never)
  private static func equalEncounterDirector(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.encounterDirector)!.pointee == rhs.pointer(to: \.encounterDirector)!.pointee
  }

  @inline(never)
  private static func equalSavedWantedCareers(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedWantedCareers)!.pointee == rhs.pointer(to: \.savedWantedCareers)!.pointee
  }

  @inline(never)
  private static func equalSavedNPCPersistence(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedNPCPersistence)!.pointee == rhs.pointer(to: \.savedNPCPersistence)!.pointee
  }

  @inline(never)
  private static func equalSavedCargoDebrisLedger(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedCargoDebrisLedger)!.pointee == rhs.pointer(to: \.savedCargoDebrisLedger)!.pointee
  }

  @inline(never)
  private static func equalSavedMiningLedger(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedMiningLedger)!.pointee == rhs.pointer(to: \.savedMiningLedger)!.pointee
  }

  @inline(never)
  private static func equalSavedMissionProgress(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.savedMissionProgress)!.pointee == rhs.pointer(to: \.savedMissionProgress)!.pointee
  }

  @inline(never)
  private static func equalWantedAmnesty(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.wantedAmnesty)!.pointee == rhs.pointer(to: \.wantedAmnesty)!.pointee
  }

  @inline(never)
  private static func equalOwnedShipID(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.ownedShipID)!.pointee == rhs.pointer(to: \.ownedShipID)!.pointee
  }

  @inline(never)
  private static func equalOriginalMarkets(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.originalMarkets)!.pointee == rhs.pointer(to: \.originalMarkets)!.pointee
  }

  @inline(never)
  private static func equalName(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.name)!.pointee == rhs.pointer(to: \.name)!.pointee
  }

  @inline(never)
  private static func equalCredits(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.credits)!.pointee == rhs.pointer(to: \.credits)!.pointee
  }

  @inline(never)
  private static func equalFuel(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.fuel)!.pointee == rhs.pointer(to: \.fuel)!.pointee
  }

  @inline(never)
  private static func equalGalaxy(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.galaxy)!.pointee == rhs.pointer(to: \.galaxy)!.pointee
  }

  @inline(never)
  private static func equalSystem(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.system)!.pointee == rhs.pointer(to: \.system)!.pointee
  }

  @inline(never)
  private static func equalCargo(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.cargo)!.pointee == rhs.pointer(to: \.cargo)!.pointee
  }

  @inline(never)
  private static func equalEquipment(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.equipment)!.pointee == rhs.pointer(to: \.equipment)!.pointee
  }

  @inline(never)
  private static func equalMissiles(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.missiles)!.pointee == rhs.pointer(to: \.missiles)!.pointee
  }

  @inline(never)
  private static func equalKills(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.kills)!.pointee == rhs.pointer(to: \.kills)!.pointee
  }

  @inline(never)
  private static func equalLegal(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.legal)!.pointee == rhs.pointer(to: \.legal)!.pointee
  }

  @inline(never)
  private static func equalUnlimitedMissiles(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.unlimitedMissiles)!.pointee == rhs.pointer(to: \.unlimitedMissiles)!.pointee
  }

  @inline(never)
  private static func equalUnlimitedCargo(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.unlimitedCargo)!.pointee == rhs.pointer(to: \.unlimitedCargo)!.pointee
  }

  @inline(never)
  private static func equalUnlimitedCash(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.unlimitedCash)!.pointee == rhs.pointer(to: \.unlimitedCash)!.pointee
  }

  @inline(never)
  private static func equalUnlimitedFuel(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.unlimitedFuel)!.pointee == rhs.pointer(to: \.unlimitedFuel)!.pointee
  }

  @inline(never)
  private static func equalUnlimitedJumps(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.unlimitedJumps)!.pointee == rhs.pointer(to: \.unlimitedJumps)!.pointee
  }

  @inline(never)
  private static func equalAutoTrade(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.autoTrade)!.pointee == rhs.pointer(to: \.autoTrade)!.pointee
  }

  @inline(never)
  private static func equalSpeech(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.speech)!.pointee == rhs.pointer(to: \.speech)!.pointee
  }

  @inline(never)
  private static func equalExecutive(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.executive)!.pointee == rhs.pointer(to: \.executive)!.pointee
  }

  @inline(never)
  private static func equalDiscoveredSecretPorts(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.discoveredSecretPorts)!.pointee == rhs.pointer(to: \.discoveredSecretPorts)!.pointee
  }

  @inline(never)
  private static func equalBlackjackMission(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.blackjackMission)!.pointee == rhs.pointer(to: \.blackjackMission)!.pointee
  }

  @inline(never)
  private static func equalDisplayStyle(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.displayStyle)!.pointee == rhs.pointer(to: \.displayStyle)!.pointee
  }

  @inline(never)
  private static func equalNavalMission(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.navalMission)!.pointee == rhs.pointer(to: \.navalMission)!.pointee
  }

  @inline(never)
  private static func equalXyzzyEnabled(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.xyzzyEnabled)!.pointee == rhs.pointer(to: \.xyzzyEnabled)!.pointee
  }

  @inline(never)
  private static func equalAutomaticProfitScan(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.automaticProfitScan)!.pointee == rhs.pointer(to: \.automaticProfitScan)!.pointee
  }

  @inline(never)
  private static func equalAutomaticECM(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.automaticECM)!.pointee == rhs.pointer(to: \.automaticECM)!.pointee
  }

  @inline(never)
  private static func equalAutomaticTargeting(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.automaticTargeting)!.pointee == rhs.pointer(to: \.automaticTargeting)!.pointee
  }

  @inline(never)
  private static func equalReturnFireEnabled(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.returnFireEnabled)!.pointee == rhs.pointer(to: \.returnFireEnabled)!.pointee
  }

  @inline(never)
  private static func equalCapitalReward(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.capitalReward)!.pointee == rhs.pointer(to: \.capitalReward)!.pointee
  }

  @inline(never)
  private static func equalNavigationRoute(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.navigationRoute)!.pointee == rhs.pointer(to: \.navigationRoute)!.pointee
  }

  @inline(never)
  private static func equalStorageUnitCount(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.storageUnitCount)!.pointee == rhs.pointer(to: \.storageUnitCount)!.pointee
  }

  @inline(never)
  private static func equalMountedLasers(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.mountedLasers)!.pointee == rhs.pointer(to: \.mountedLasers)!.pointee
  }

  @inline(never)
  private static func equalFiniteXYZzyCash(
    _ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>
  ) -> Bool {
    lhs.pointer(to: \.finiteXYZzyCash)!.pointee == rhs.pointer(to: \.finiteXYZzyCash)!.pointee
  }

  public init() {
    ownedShipID = NewCommanderDefaults.shipID
  }
  public var availableCredits: Int { unlimitedCash ? Int.max : credits }
  public var capacity: Int {
    let standard = standardCargoCapacity
    return unlimitedCargo ? Int.max / 17 : standard
  }
  public var cargoTonnes: Int {
    checkedCargoTonnes ?? Int.max
  }
  public var rank: String {
    let thresholds = [8, 16, 32, 64, 128, 512, 2560, Self.eliteThreshold]
    return [
      "Harmless", "Mostly Harmless", "Poor", "Average", "Above Average", "Competent", "Dangerous",
      "Deadly", "ELITE",
    ][thresholds.filter { kills >= $0 }.count]
  }
  public var valid: Bool {
    guard !OriginalDetailedHullStage.blocksRuntime(shipID),
      ShipCatalogue.ship(shipID)?.game != nil else { return false }
    guard equipmentStateValid else { return false }
    return validAfterEquipment()
  }

  @inline(never)
  private func validAfterEquipment() -> Bool {
    guard NativeMemoryAtlasWatcherSourceSave.validateClaims(self),
      NativeInductionCrewLogSave.validateClaims(self),
      NativeInductionArkSave.validateClaims(self),
      NativeWayfarerInductionSave.validateClaims(self),
      NativeFirstCommoditySaleSave.validateClaims(self),
      NativeFirstCommodityTradeSave.validateClaims(self),
      NativeUnderTowSave.validateClaims(self),
      NativePublicRecordSave.validateClaims(self),
      NativeBorrowedVoiceSave.validateClaims(self),
      NativeTitheCommissionSave.validateClaims(self),
      NativeQuietChoirSave.validateClaims(self),
      NativeMemoryAtlasSave.validateClaims(self),
      NativeSignedPassageOpeningSave.validateClaims(self),
      NativeAssemblyOfOrbitsSave.validateClaims(self),
      NativeGlassMeridianSave.validateClaims(self),
      NativeFleetDiscoverySave.validateClaims(self),
      NativeFlightReceptionSave.validateClaims(self),
      WayfarerFieldReliefSave.validateClaims(self)
    else { return false }
    guard NativeMeasuredExtractionSave.validateClaims(self) else { return false }
    guard WayfarerRecordRecoverySave.validateClaims(self) else { return false }
    guard NativeIdentifiedSalvageSave.validateClaims(self) else { return false }
    guard nativeStationStateValid else { return false }
    guard nativeUtilityStateValid else { return false }
    guard empCustodyStateValid else { return false }
    guard electricalStateValid else { return false }
    guard alienStorageStateValid else { return false }
    guard nativeSalvageOriginalSourcesValid else { return false }
    guard freightCargoValid else { return false }
    guard navigationTradeStateValid else { return false }
    guard originalMarkets.valid else { return false }
    guard cargo.count == 17 else { return false }
    guard (cargo.allSatisfy { $0 >= 0 && $0 <= Int.max / 17 }) else { return false }
    guard credits >= 0 else { return false }
    guard credits <= 4_294_967_295 else { return false }
    guard (0...256).contains(system) else { return false }
    guard (0..<8).contains(galaxy) else { return false }
    guard (0...255).contains(plughDiscoveryMask) else { return false }
    guard (system != Plugh.systemID || hasDiscoveredPlugh(in: galaxy)) else { return false }
    guard (!(navigationPlan?.path.contains(Plugh.systemID) ?? false)
        || hasDiscoveredPlugh(in: galaxy)) else { return false }
    guard (0...FuelStorage.maximumCount).contains(fuelStorageUnits) else { return false }
    guard (0...fuelCapacity).contains(fuel) else { return false }
    guard (0...missileCapacity).contains(missiles) else { return false }
    guard (0...65535).contains(kills) else { return false }
    guard legal >= 0 else { return false }
    guard missionProgress.count <= 128 else { return false }
    guard missionProgress.values.allSatisfy(\.valid) else { return false }
    guard scriptState.valid else { return false }
    guard financeStateValid else { return false }
    guard nativeWormholeHistoryValid else { return false }
    guard nativePeopleStateValid else { return false }
    guard accommodationValid else { return false }
    guard contractsValid else { return false }
    guard (legacyOwnedEquipment != nil ? legacyIssueStateValid : issuedEquipmentValid) else { return false }
    guard (checkedCargoTonnes.map { $0 <= capacity } ?? false) else { return false }
    guard (navigationPlan?.valid ?? true) else { return false }
    guard blackjack.valid else { return false }
    guard (savedFlightSimulation?.valid ?? true) else { return false }
    guard (savedBisonUnitAllocations?.valid(in: self) ?? true) else { return false }
    guard (savedCargoDebrisLedger?.valid ?? true) else { return false }
    guard (savedMiningLedger?.valid ?? true) else { return false }
    guard (savedWantedCareers?.valid(in: flightSimulation) ?? true) else { return false }
    guard (savedNPCPersistence?.valid ?? true) else { return false }
    guard (!blackjack.carriesFirearm || cargo[10] >= 1) else { return false }
    guard equipment.isSubset(of: Equipment.validNames) else { return false }
    guard !name.isEmpty else { return false }
    guard name.count <= 16 else { return false }
    return true
  }
}

public struct Equipment: Sendable {
  /// Equipment definitions store zero-based requirements; original worlds expose one-based TL.
  public var requiredTechnologyLevel: Int { technology + 1 }
  public static let legacyDockingComputer = "Docking Computers"
  public static let navalEnergyUnit = "Naval Energy Unit"
  public static let eliteEnergyUnit = "Elite Energy Unit"
  public static let navalLaser = "Naval Laser"
  public static let empPirateBlaster = "EMP Pirate Blaster"
  public static var validNames: Set<String> {
    Set(all.map(\.name)).subtracting(
      [FuelStorage.equipmentName] + PassengerCabinGrade.allCases.map(\.equipmentName)
    )
    .union(Set(HyperspaceDriveTier.allCases.map(\.label)))
    .union([
      navalEnergyUnit, navalLaser, ShieldBooster.capital.equipmentName, legacyDockingComputer,
      "Targeting: Mining Module", "Targeting: Salvage Module", "Salvage Cutter",
      "Elite Shield Module",
    ])
  }
  public static var maximumHardware: Set<String> {
    validNames.subtracting(
      [
        legacyDockingComputer, "Extra Energy Unit", navalEnergyUnit, "Pulse Laser", "Beam Laser",
        HyperspaceDriveTier.basic.label, HyperspaceDriveTier.intermediate.label,
        "Military Laser", AlienMissileDefinition.name,
      ]
        + TargetingTier.allCases.map(\.equipmentName) + NavigationTier.allCases.map(\.equipmentName)
        + ShieldBooster.allCases.map(\.equipmentName)
    )
    .union([
      TargetingTier.military.equipmentName, NavigationTier.military.equipmentName,
      "Elite Shield Module",
    ])
  }
  public let name: String
  public let price: Int
  public let technology: Int
  public static let base: [Equipment] =
    [
      .init(name: "Fuel", price: 2, technology: 0),
      .init(name: "Missile", price: 1800, technology: 1),
      .init(
        name: AlienMissileDefinition.name, price: AlienMissileDefinition.repeatPriceTenths,
        technology: 0),
      .init(name: "Large Cargo Bay", price: 28000, technology: 3),
      .init(name: "E.C.M. System", price: 21000, technology: 4),
      .init(name: "Pulse Laser", price: 14500, technology: 2),
      .init(name: "Beam Laser", price: 47000, technology: 6),
      .init(name: "Fuel Scoops", price: 19000, technology: 3),
      .init(name: "Escape Pod", price: 36000, technology: 5),
      .init(name: "Energy Bomb", price: 128000, technology: 12),
      .init(name: "Extra Energy Unit", price: 72000, technology: 8),
      .init(name: "Galactic Hyperdrive", price: 285000, technology: 14),
      .init(name: "Mining Laser", price: 33000, technology: 5),
      .init(name: "Military Laser", price: 164000, technology: 13),
    ]
  public static let all =
    base
    + TargetingTier.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: $0.technology)
    }
    + NavigationTier.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: $0.technology)
    } + [
      // Initial project balancing in tenths of a credit; these are new independent devices.
      .init(name: "Targeting: Mining Module", price: 20000, technology: 5),
      .init(name: "Targeting: Salvage Module", price: 40000, technology: 7),
      .init(name: empPirateBlaster, price: 30000, technology: 8),
      .init(name: "Salvage Cutter", price: 25000, technology: 6),
      .init(name: FuelStorage.equipmentName, price: FuelStorage.price, technology: 0),
      .init(name: navalLaser, price: 0, technology: 0),
      .init(name: navalEnergyUnit, price: 196000, technology: 16),
      .init(name: eliteEnergyUnit, price: 135000, technology: 13),
    ]
    + ShieldBooster.allCases.compactMap(\.shopItem) + [
      .init(name: ShieldBooster.capital.equipmentName, price: 0, technology: 0),
      .init(name: HyperspaceDriveTier.intermediate.label, price: 50000, technology: 9),
      .init(name: HyperspaceDriveTier.advanced.label, price: 150000, technology: 12),
    ]
    + PassengerCabinGrade.allCases.map {
      .init(name: $0.equipmentName, price: $0.price, technology: 0)
    }
}

public struct Controls: Sendable {
  public var pitch: Double = 0
  public var roll: Double = 0
  public var yaw: Double = 0
  public var throttle: Double = 0
  public var fire = false
  public var spinContacts = 0
  public var spinRecognition = 0.0
  public var spinSlower = false
  public var spinFaster = false
  public init() {}
}

/// Actual clock-owner transport only; no decoder or external initializer.
struct NativeC01InquiryClockWitness: Sendable {
  let opening: NativeC01InquiryClockOpening
  let observedEnd: Double
  let nativeMotion: CurrentNewtNativeClockEvidence?
  fileprivate init(
    opening: NativeC01InquiryClockOpening, observedEnd: Double,
    nativeMotion: CurrentNewtNativeClockEvidence? = nil
  ) {
    self.opening = opening
    self.observedEnd = observedEnd
    self.nativeMotion = nativeMotion
  }
}

/// Actual camera-phase data; construction remains confined to this mutation-site file.
struct NativeC03AppliedCameraStep: Sendable {
  struct Manual: Sendable {
    let pitch: Double
    let roll: Double
    let yaw: Double
    let translation: Vector3
  }
  let before: ShipPose
  let after: ShipPose
  let delta: Double
  let manual: Manual?
  var work: Bool { manual == nil }
  fileprivate init(game: borrowing Game, before: ShipPose, delta: Double, work: Bool) {
    self.before = before
    after = game.commander.flightSimulation.pose
    self.delta = delta
    manual =
      work
      ? nil
      : .init(
        pitch: game.pitch * delta, roll: game.roll * delta,
        yaw: game.yaw * delta,
        translation: game.autoPilot.velocity * delta + Vector3(0, 0, game.speed * delta * 18))
  }
}

public struct Game: Sendable {
  // Runtime snapshots are values. Array CoW copies the existing payload on first mutation;
  // cloning never reinitializes epochs, random state or universe defaults.
  private struct Values: Sendable {
    var commanderStorage = [Commander()]
    var systems = Universe.systemsIncludingPlugh()
    var screen: Screen = .title
    var paused = false
    var isMissionTrial = false
    var contractBoard = ContractBoardUI()
    var scriptPledgeAdmission: ScriptPledgeAdmission?
    var scriptCourierAdmission: ScriptCourierAdmission?
    var trialTitle: String?
    var trialDigest: String?
    var trialSeed: UInt64?
    var docked = true
    var dockedAtMainStation = true
    var scriptReferenceFrame: ScriptReferenceFrame?
    var scriptDispatching = false
    var scriptEventsDeferred = false
    var empPlayerElectricalInterval: EMPPlayerElectricalInterval?
    var c01InquiryStepRuntime = NativeC01InquiryStepRuntimeState()
    var empPulseBeforeResultStorage: EMPPulseBeforeResult?
    var scriptDurabilityAvailable = false
    var pendingNewSaveDestination: URL?
    var newCommanderSaveReceipt: CommanderFileReceipt?
    var nativeStationRuntimeEpoch = UUID()
    var c01InquiryNativeRegistry = NativeC01InquiryNativeRegistry.empty()
    var nativeOriginalStationPopulationPlan: NativeOriginalStationPopulationPlan?
    var nativeOriginalUtilityFatalStart: NativeOriginalUtilityFatalStart?
    var nativeOriginalUtilityFatalTransition: NativeOriginalUtilityFatalTransition?
    var nativeOrbitalOutlookRuntime = NativeOrbitalOutlookRuntime()
    var nativeAssemblyCalibrationDisplay: NativeAssemblySurveyInstrumentControls.Readout?
    var nativeAssemblyCapacityEditorDisplay: NativeAssemblyCapacityEditorDisplay?
    var nativeOriginalSurveyRuntime: NativeOriginalSurveyRuntime?
    var nativeGlassMeridianRuntime: NativeGlassMeridianRuntime?
    var nativeFlightReceptionPending: NativeFlightReceptionPending?
    var nativeMeasuredExtractionPending: NativeMeasuredExtractionPending?
    var nativeRecordRecoveryPending: WayfarerRecordRecoveryPending?
    var nativeCrewLogPickupPending: NativeCrewLogPickupPending?
    var nativeC01SurveyorPending: NativeC01SurveyorPending?
    var nativeC01TimingStandardPending: NativeC01TimingStandardPending?
    var c01LaneRepairWorkRuntime = NativeC01LaneRepairWorkRuntime()
    var c01ClinicEscortRuntime = NativeC01ClinicEscortRuntime()
    var nativeRecordRecoveryIdentificationPending: WayfarerRecordRecoveryIdentificationPending?
    var nativeIdentifiedSalvagePending: NativeIdentifiedSalvagePending?
    var hollowManifestConsentReview: NativeHollowManifestConsentReview?
    var nativeC03MotionPending: NativeC03MotionPending?
    var nativeC03AttainedMotion: NativeC03AttainedMotionResult?
    var nativeC03ClockEvidence: CurrentNewtNativeClockEvidence?
    var c03ArchiveReaderDisplay: NativeC03ArchiveReaderDisplay?
    var c03CrewRuntime = NativeC03CrewRuntime()
    var nativeCrimboMotionSample: NativeCrimboMotionSample?
    var nativeCrimboAttainedMotion: NativeCrimboAttainedMotion?
    var nativeCrimboLifecycleAvailable = false
    var nativeSalvageMotion: [SalvageLotIdentity: NativeSalvageMotion] = [:]
    var nativeSalvageWreckMotion: [WreckIdentity: NativeSalvageWreckObservation] = [:]
    var nativeSalvageWork: NativeSalvageHotWork?
    var nativeSalvageAdmissionDiagnostic: NativeSalvageAdmissionDiagnostic?
    var nativeEncounterBirthDiagnostic: GameplayEncounterBirthDiagnostic?
    var pendingNativeSalvageCollections: [NativeSalvageCollectionObservation] = []
    var pendingNativeStationDock: NativeStationEntryProof?
    var pendingMemoryAtlasMainDock: NativeMemoryAtlasMainEntryProof?
    var inductionArkDockPublicationPending = false
    var inductionRescueDockPublicationPending = false
    var inductionUtilityWorkRuntime = NativeInductionUtilityWorkRuntime()
    var isolationWorkRuntime = NativeIsolationWorkRuntime()
    var nativeStationDockEvidence: NativeStationDockEvidence?
    var nativeMainStationDockEvidence: NativeMainStationDockEvidence?
    var scriptPacks: [ScriptPack] = []
    var scriptAvailablePackDigest: String?
    var scriptOffer: UUID?
    var scriptPresentedDialogue: ScriptDialogue?
    var scriptConfirmSelected = true
    var scriptChoiceSelection = 0
    var missionPacks = MissionPackLibrary.bundled
    var packOffer: PackOffer?
    var packOfferElapsed = 0.0
    var packDialogScroll = 0
    var blackjackOffer: BlackjackOffer?
    var showroom = ShowroomState()
    var galacticBrowse = GalaxyBrowseState()
    var systemInspection: SystemInspection?
    var rumourReturn: Screen = .status
    var wantedSelection: ActorIdentity?
    var wantedPlayerSelected = false
    var wantedDetail = false
    var wantedRumourDetail = false
    var wantedScroll = 0
    var wantedReadContext: WantedReadContext?
    var blackjackReturn: Screen = .status
    var screenHistory: [Screen] = []
    var flightReturn: Screen = .front
    var selectedSystem = 7
    var selection = 0
    var informationScroll = 0
    var chartInformationScroll = 0
    var bodies: [SpaceBody] = []
    var miningFields: [MiningField] = []
    var salvageSites: [SalvageSite] = []
    var gameplayRevision: UInt64 = 0
    var stationImpactRevision: UInt64?
    var consumedMissionLaserEmission: UInt64 = 0
    var salvageAdmissionGeometry: [String: PreparedSalvageAdmissionHull] = [:]
    var starfield = Starfield()
    var speed = 0.0
    var pitch = 0.0
    var roll = 0.0
    var yaw = 0.0
    var spin = SpinControl()
    var autoPilot = AutoTargetControl()
    var stationAutoDefence: StationAutoDefenceState?
    var workTargetFilter: WorkTargetFilter = .ships
    var workGuidance: FlightWorkGuidance?
    var workBraking: FlightWorkBraking?
    var workRecoveryRock: RockIdentity?
    var workRecoveryAdmissionDeadline: Double?
    var approvedWorkMotion: HullSceneMotion?
    var lastAppliedWorkMotion: HullSceneMotion?
    var plannedLegacyWorkMotion: [Int: HullSweepObstacle] = [:]
    var workScenePlanned = false
    var workFireSuspended = false
    var flightTrigger = FlightTriggerState()
    var selectedToolActivity: FlightToolActivity?
    var flightWeaponDisplay = FlightWeaponDisplay(
      weapon: "UNAVAILABLE", status: "SNAPSHOT REQUIRED")
    var manualResidualFlight = false
    var viewportWidth = 768.0
    var viewportHeight = 768.0
    var targetPanelExpanded: Bool?
    var targetPanelScroll = 0
    var weaponsTargetID: Int?
    var secretScroll = 0
    var energy = 256.0
    var frontShield = 255.0
    var rearShield = 255.0
    var laserHeat = 0.0
    var laserFlash = 0.0
    var playerImpactFeedback: PlayerImpactFeedback?
    var dischargeAudio = DischargeAudioState()
    var gameplayCombatTrace: GameplayCombatTrace?
    var altitude = 1.0
    var celestials: [CelestialBody] = []
    var solarScoopState: SolarScoopState = .inactive
    var solarFuelRemainder = 0.0
    var cabinTemperature = 0.0
    var equipmentMount: LaserMount = .front
    var equipmentWorkTool = false
    var equipmentCrewSelected = false
    var selectedFlightTool: FlightWorkTool = .combatLaser
    var inventoryContextEpoch = InventoryContextEpoch()
    var inventoryActionSelection = 0
    var inventoryUpgradeChoice = 0
    var dockingComputer = false
    var missileArmed = false
    var message = ""
    var messageTime = 0.0
    var jumpCountdown: Double? = nil
    var time = 0.0
    var scriptStartupTime: Double?
    var secretBuffer = ""
    var secretReturn: Screen = .status
    var helpReturn: Screen = .title
    var helpPage = 0
    var gallery = MissionGalleryState()
    var library = ScriptLibraryState()
    var c01InquiryJournal = NativeC01InquiryJournalState()
    var mapColour: MapColourMode = .economy
    var mapZoom: MapZoom = .jump
    var mapSearch = PlanetSearchState()
    var navigationOptions: [RouteAlternative] = []
    var navigationSelection = 0
    var navigationScroll = 0
    var navigationReturn: Screen = .chart
    var missionNotice: MissionNotice?
    var missionPage = 0
    var missionClue: String?
    var missionElapsed = 0.0
    var fireCooldown = 0.0
    var missionLoopCounter: UInt8 = 0
    var missionSpawnDelay = 0
    var enemyECMSource: Int?
    var activeECMActivation: ECMActivationIdentity?
    var ecmControl = ECMControl()
    var retaliation = RetaliationControl()
    var missileCooldown = 0.0
    var nextBodyID = 10
    var legacySimulationSpawnClock: Double?
    var randomState: UInt64 = 0x45_4c49_5445

    init() {}
  }
  private var valueStorage = [Values()]

  // Exactly one value lives in checked copy-on-write storage. Game copies retain independent
  // nested commander mutations without reserving the whole commander in every Game temporary.
  private var commanderStorage: [Commander] {
    _read {
      let stored: [Commander] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.commanderStorage)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].commanderStorage }
  }
  public var commander: Commander {
    _read { yield commanderStorage[0] }
    _modify { yield &commanderStorage[0] }
  }
  var commanderGalaxy: Int {
    commanderStorage.withUnsafeBufferPointer { storage in
      storage.baseAddress!.pointee.galaxy
    }
  }
  // Adoption needs only these scalars; passing the whole pointee to a generic read callback
  // can require an owned Commander temporary before the callback projects either field.
  @inline(never)
  mutating func nativePhysicalAdoptionSystemIdentity() -> SystemIdentity {
    commanderStorage.withUnsafeBufferPointer { storage in
      let commander = storage.baseAddress!
      return Commander.nativeStationReadSystem(at: commander)
    }
  }

  @inline(never)
  func storedSystemIdentity() -> SystemIdentity {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadSystem(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeQueryStoredShipID() -> String {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeQueryReadShipID(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeQueryStoredMiningLedger() -> MiningLedger {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeQueryReadMiningLedger(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeQueryStoredCrimeLedger() -> CrimeLedger {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeQueryReadCrimeLedger(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeQueryStoredBlackjack() -> BlackjackMission {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeQueryReadBlackjack(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeQueryStoredMissionStage() -> NavalMissionStage {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeQueryReadMissionStage(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeMechanicalStoredNPCPersistence() -> NPCPersistenceLedger {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeMechanicalReadNPCPersistence(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeMechanicalStoredEMPState() -> EMPState? {
    commanderStorage.withUnsafeBufferPointer { storage in
      storage.baseAddress!.pointer(to: \.savedEMPState)!.pointee
    }
  }

  @inline(never)
  func nativeStationAutoTargetingTier() -> TargetingTier? {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeStationAutoReadTier(at: storage.baseAddress!) }
  }

  @inline(never)
  func nativeStationAutoLaserMounts() -> LaserMounts {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeStationAutoReadLaserMounts(at: storage.baseAddress!) }
  }

  @inline(never)
  func nativeStationAutoHasECM() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.fittedEquipment(in: Commander.nativeStartupInventory(at: storage.baseAddress!), at: .utility(.ecm)) != nil }
  }

  @inline(never)
  func nativeStationAutoMissiles() -> Int {
    commanderStorage.withUnsafeBufferPointer { storage in storage.baseAddress!.pointer(to: \.missiles)!.pointee }
  }

  @inline(never)
  func nativeStationAutoUnlimitedMissiles() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in storage.baseAddress!.pointer(to: \.unlimitedMissiles)!.pointee }
  }

  @inline(never)
  func nativeStationAutoXYZzyActive() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeStationAutoReadXYZzyActive(at: storage.baseAddress!) }
  }

  @inline(never)
  func nativeStationAutoTargetFlag() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeStationAutoReadTargetFlag(at: storage.baseAddress!) }
  }

  @inline(never)
  func nativeStationAutoPurchaseHistory() -> EquipmentPurchaseHistory? {
    commanderStorage.withUnsafeBufferPointer { storage in storage.baseAddress!.pointer(to: \.savedEquipmentPurchaseHistory)!.pointee }
  }

  @inline(never)
  func nativeStationAutoHasDocking() -> Bool {
    nativeStationAutoTargetingTier().map { $0 >= .docking } ?? false
  }

  @inline(never)
  func nativeStationAutoLaser(on mount: LaserMount) -> LaserKind? {
    nativeStationAutoLaserMounts()[mount]
  }

  @inline(never)
  func nativeFramePerformance() -> ShipPerformance {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeStartupPerformance(at: storage.baseAddress!) }
  }

  @inline(never)
  func nativeFrameEnergyRecharge() -> Double {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeFrameReadEnergyRecharge(at: storage.baseAddress!) }
  }

  @inline(never)
  func nativeFrameFrontRecharge() -> Double {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeFrameReadShieldRecharge(at: storage.baseAddress!, front: true) }
  }

  @inline(never)
  func nativeFrameRearRecharge() -> Double {
    commanderStorage.withUnsafeBufferPointer { storage in Commander.nativeFrameReadShieldRecharge(at: storage.baseAddress!, front: false) }
  }

  @inline(never)
  func nativeDurabilityBison() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityBison(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeGeometryWorldOwnedPod(_ person: EMPCrewIdentity) -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeGeometryReadWorldOwnedPod(person, at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityWatcher() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityWatcher(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityPeople() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityPeople(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityUtility() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityUtility(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityEMP() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityEMP(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityAlien() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityAlien(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityNewt() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityNewt(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityLegacy() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityLegacy(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityCalendar() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityCalendar(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityInstances() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityInstances(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityContracts() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityContracts(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityScript() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityScript(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeDurabilityAccommodation() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeDurabilityAccommodation(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeStartupNativePerformance() -> ShipPerformance {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStartupNativePerformance(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func nativeStartupEnergy() -> Double {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStartupPerformance(at: storage.baseAddress!).energy
    }
  }

  @inline(never)
  func nativeStartupFrontShield() -> Double {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStartupShield(at: storage.baseAddress!, front: true)
    }
  }

  @inline(never)
  func nativeStartupRearShield() -> Double {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStartupShield(at: storage.baseAddress!, front: false)
    }
  }

  @inline(never)
  func nativeStartupFuelCapacity() -> Int {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStartupFuel(at: storage.baseAddress!)
    }
  }

  @inline(never)
  private func nativeCurrentSystemIndex() -> Int {
    commanderStorage.withUnsafeBufferPointer { storage in
      storage.baseAddress!.pointer(to: \.system)!.pointee
    }
  }

  @inline(never)
  func storedFlightSimulation() -> FlightSimulationState {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadFlight(at: storage.baseAddress!)
    }
  }

  // Only owned station children leave these synchronous storage reads.
  func storedNativeStationWorld() -> NativeStationWorld? {
    commanderStorage.withUnsafeBufferPointer { storage in
      guard let world = storage.baseAddress!.pointer(to: \.nativeStations) else {
        preconditionFailure("Station world reads require addressable stored world.")
      }
      return world.pointee
    }
  }

  // Transit steering reads only the script child, never an owned Commander temporary.
  // Both buffer borrows are synchronous; only an owned ledger or scalar leaves them.
  @inline(never)
  func nativeTransitStoredLedger() -> NativeWormholeTransitState? {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let ledger = state.pointer(to: \.wormholeTransit) else {
          preconditionFailure("Transit steering requires addressable stored transit state.")
        }
        return ledger.pointee
      }
    }
  }

  @inline(never)
  func nativeTransitStoredCalendarSeconds() -> Double {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let calendar = state.pointer(to: \.calendarSeconds) else {
          preconditionFailure("Transit steering requires addressable stored calendar time.")
        }
        return calendar.pointee
      }
    }
  }

  func storedNativeStationResource(for key: String) -> ScriptStationResource? {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let resources = state.pointer(to: \.savedStationResources) else {
          preconditionFailure("Station resource reads require addressable stored resources.")
        }
        return resources.pointee?[key]
      }
    }
  }

  func storedNativeStationResourcesAreEmpty() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let resources = state.pointer(to: \.savedStationResources) else {
          preconditionFailure("Station resource reads require addressable stored resources.")
        }
        return resources.pointee?.isEmpty ?? true
      }
    }
  }

  // Complete checks run inside the stored borrow; only their Boolean results leave it.
  func storedNativeUtilityStateIsValid() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      storage.baseAddress!.pointee.nativeUtilityStateValid
    }
  }

  func storedNativePeopleStateIsValid() -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      storage.baseAddress!.pointee.nativePeopleStateValid
    }
  }

  @inline(never)
  func storedNPCPersistenceCount() -> Int {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeNPCPersistenceCount(at: storage.baseAddress!)
    }
  }

  @inline(never)
  func storedEquipmentOwnerID() -> UUID? {
    commanderStorage.withUnsafeBufferPointer { storage in
      guard let inventory = storage.baseAddress!.pointer(to: \.savedEquipmentInventory) else {
        preconditionFailure("Reservation requires addressable stored equipment.")
      }
      return inventory.pointee?.owner
    }
  }

  // Guidance leaves only selected owned children/scalars or typed read-only results.
  // The storage borrow is synchronous; no Commander value or pointer escapes it.
  @inline(never)
  func nativeGuidanceStoredMission(definition: String) -> ScriptInstance? {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let instances = state.pointer(to: \.instances) else {
          preconditionFailure("Guidance requires addressable stored mission instances.")
        }
        return instances.pointee.values.first { $0.definition == definition }
      }
    }
  }

  @inline(never)
  func nativeGuidanceStoredMission(id: UUID) -> ScriptInstance? {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let instances = state.pointer(to: \.instances) else {
          preconditionFailure("Guidance requires addressable stored mission instances.")
        }
        return instances.pointee[id]
      }
    }
  }

  @inline(never)
  func c01ClinicStoredHistoryJoins(
    _ state: borrowing NativeC01ClinicEscortState, mission: borrowing ScriptInstance
  ) -> Bool {
    // The closure owns only these child snapshots; the Commander stays borrowed in storage.
    let ownedState = copy state
    let ownedMission = copy mission
    return commanderStorage.withUnsafeBufferPointer { storage in
      NativeC01ClinicEscortSave.historyJoins(
        ownedState, mission: ownedMission, commander: storage.baseAddress!.pointee)
    }
  }

  @inline(never)
  func c01ClinicStoredPilotFacts(ordinal: Int) -> NativeC01ClinicPilotFacts? {
    commanderStorage.withUnsafeBufferPointer { storage in
      storage.baseAddress!.pointee.c01ClinicStockPilotFacts(ordinal: ordinal)
    }
  }

  @inline(never)
  func nativeGuidanceStoredPlayerMesh() -> Mesh {
    Commander.playerMesh(for: nativeQueryStoredShipID())
  }

  @inline(never)
  func nativeGuidanceStoredEquipmentInventory() -> OwnedEquipmentInventory? {
    commanderStorage.withUnsafeBufferPointer { storage in
      guard let inventory = storage.baseAddress!.pointer(to: \.savedEquipmentInventory) else {
        preconditionFailure("Guidance requires addressable stored equipment inventory.")
      }
      return inventory.pointee
    }
  }

  // Complete Commander equality retires before nested native scene preparation.
  // Only current storage pointers enter the operator; neither pointer escapes this call.
  @inline(never)
  func currentNewtNativeCommanderMatches(_ expected: Game) -> Bool {
    commanderStorage.withUnsafeBufferPointer { live in
      expected.commanderStorage.withUnsafeBufferPointer { saved in
        Commander.storedValuesEqual(live.baseAddress!, saved.baseAddress!)
      }
    }
  }

  // Apply exactly the original clock mutation to an existing CoW Game copy.
  // The expected Commander remains in its heap buffer, never a returned value
  // held by the deep native retention/mechanical callback stack.
  @inline(never)
  func currentNewtNativeCommanderMatches(_ expected: Game, advancingClockBy delta: Double) -> Bool {
    var advanced = expected
    advanced.commander.flightSimulation.advancePhysicalTime(delta)
    return currentNewtNativeCommanderMatches(advanced)
  }

  @inline(never)
  func nativeQueryStoredDesign(_ hash: String) -> ShipDesign? {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let geometry = state.pointer(to: \.savedGeometry) else {
          preconditionFailure("Native queries require addressable stored source geometry.")
        }
        return geometry.pointee?[hash]
      }
    }
  }

  // Keep the original full policy and lazy read order without passing a whole Commander value
  // through the generic read callback. Only owned system/anchor values leave this buffer scope.
  @inline(never)
  mutating func nativeStationPopulationHeader() throws -> (
    system: SystemIdentity, anchors: SystemAnchors
  ) {
    try commanderStorage.withUnsafeBufferPointer { storage in
      let commander = storage.baseAddress!
      let system = Commander.nativeStationReadSystem(at: commander)
      guard
        Commander.nativeStationStateIsValid(at: commander),
        let anchors = Commander.nativeStationReadFlight(at: commander).anchors,
        anchors.system == Commander.nativeStationReadSystem(at: commander)
      else { throw NativeStationRuntimeError.invalidState }
      return (system, anchors)
    }
  }
  /// A synchronous read of current inout storage, without an owned Game receiver temporary.
  /// The pointer and borrowed receiver never escape this call; the callback cannot mutate them.
  @inline(never)
  mutating func withReadOnlyStoredGame<Result>(
    _ read: (borrowing Game) throws -> Result
  ) rethrows -> Result {
    try withUnsafePointer(to: &self) { pointer in try read(pointer.pointee) }
  }

  @inline(never)
  mutating func withReadOnlyStoredScriptState<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    try withReadOnlyStoredGame { game in try game.withReadOnlyScriptState(read) }
  }

  /// Read only the retained marker's script child; no Commander value leaves its storage.
  @inline(never)
  func inductionCrewLogStoredMarkerIsPresent(job: UUID) -> Bool {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        NativeInductionCrewLogPack.marker(job: job, state: state.pointee)
      }
    }
  }

  /// The native lookup returns only its selected owned values, never enclosing state.
  func storedActiveDefensiveFlight() -> (
    instance: ScriptInstance, state: NativeDefensiveFlightState
  )? {
    commanderStorage.withUnsafeBufferPointer { storage in
      Commander.nativeStationReadScriptState(at: storage.baseAddress!) { state in
        guard let instances = state.pointer(to: \.instances) else {
          preconditionFailure("Defensive flight requires addressable stored instances.")
        }
        for instance in instances.pointee.values
        where instance.definition == NativeDefensiveFlight.stateID && instance.outcome == .active {
          if let state = instance.savedDefensiveFlight { return (instance, state) }
        }
        return nil
      }
    }
  }

  /// Synchronous read-only access; the storage borrow and pointer never escape this call.
  func withReadOnlyCommander<Result>(
    _ read: (borrowing Commander) throws -> Result
  ) rethrows -> Result {
    try commanderStorage.withUnsafeBufferPointer { storage in
      try Self.withBorrowedPointee(storage.baseAddress!, read)
    }
  }

  // A potentially noncopyable pointee keeps the address projection borrowed.
  @inline(never)
  static func withBorrowedPointee<Value: ~Copyable, Result>(
    _ pointer: UnsafePointer<Value>, _ read: (borrowing Value) throws -> Result
  ) rethrows -> Result {
    try read(pointer.pointee)
  }

  /// Native station reads borrow current storage without an owned Game receiver temporary.
  /// The synchronous buffer borrow and pointer cannot escape this call.
  @inline(never)
  mutating func withNativeStationReadOnlyCommander<Result>(
    _ read: (borrowing Commander) throws -> Result
  ) rethrows -> Result {
    try commanderStorage.withUnsafeBufferPointer { storage in
      try read(storage.baseAddress!.pointee)
    }
  }

  func withReadOnlyScriptState<Result>(
    _ read: (borrowing ScriptEngineState) throws -> Result
  ) rethrows -> Result {
    try withReadOnlyCommander { try $0.withReadOnlyScriptState(read) }
  }

  @inline(never)
  func nativeStationStoredBodyIsCurrent(_ body: borrowing SpaceBody) -> Bool {
    let identity = body.nativeStationIdentity
    let physicalIdentity = identity == nil ? nil : body.nativeStationPhysicalIdentity
    let energy = body.energy
    let bodyID = body.id
    return commanderStorage.withUnsafeBufferPointer { storage in
      Self.nativeStationBodyIsCurrent(
        identity: identity, physicalIdentity: physicalIdentity, energy: energy, bodyID: bodyID,
        at: storage.baseAddress!)
    }
  }

  @inline(never)
  mutating func nativeStationApproachStoredBodyIsCurrent(_ body: borrowing SpaceBody) -> Bool {
    let identity = body.nativeStationIdentity
    let physicalIdentity = identity == nil ? nil : body.nativeStationPhysicalIdentity
    let energy = body.energy
    let bodyID = body.id
    return commanderStorage.withUnsafeBufferPointer { storage in
      Self.nativeStationBodyIsCurrent(
        identity: identity, physicalIdentity: physicalIdentity, energy: energy, bodyID: bodyID,
        at: storage.baseAddress!)
    }
  }

  @inline(never)
  private static func nativeStationBodyIsCurrent(
    identity: NativeStationIdentity?, physicalIdentity: ActorIdentity?, energy: Double, bodyID: Int,
    at commander: UnsafePointer<Commander>
  ) -> Bool {
    guard let identity, let physicalIdentity,
      let worldStorage = commander.pointer(to: \.nativeStations)
    else { return false }
    guard let world = worldStorage.pointee, Commander.nativeStationStateIsValid(at: commander)
    else { return false }
    return nativeStationBindingIsCurrent(
      energy: energy, bodyID: bodyID, identity: identity, physicalIdentity: physicalIdentity,
      world: world, at: commander)
  }

  @inline(never)
  private static func nativeStationBindingIsCurrent(
    energy: Double, bodyID: Int, identity: NativeStationIdentity, physicalIdentity: ActorIdentity,
    world: borrowing NativeStationWorld, at commander: UnsafePointer<Commander>
  ) -> Bool {
    guard let record = world.ledger.records.first(where: { $0.identity == identity })
    else { return false }
    let currentSystem = Commander.nativeStationReadSystem(at: commander)
    guard identity.system == currentSystem, record.tombstone == nil, energy > 0,
      physicalIdentity.system == currentSystem,
      physicalIdentity.visit == Commander.nativeStationReadFlight(at: commander).visit,
      record.binding == .init(actor: physicalIdentity, bodyID: bodyID)
    else { return false }
    return true
  }

  var missionActorAdmissionSystemIdentity: SystemIdentity {
    withReadOnlyCommander { .init(galaxy: $0.galaxy, system: $0.system) }
  }

  /// Snapshot installed instances through the same synchronous Commander borrow as native policy.
  var retainedMissionActorInstances: [UUID: ScriptInstance] {
    withReadOnlyScriptState { $0.instances }
  }

  func retainedMissionActorAdmissionSourceValues() -> (
    instances: [UUID: ScriptInstance], geometry: [String: ShipDesign], galaxy: Int, system: Int
  ) {
    withReadOnlyCommander { commander in
      let state = commander.withReadOnlyScriptState { ($0.instances, $0.geometry) }
      return (state.0, state.1, commander.galaxy, commander.system)
    }
  }

  func retainedMissionActorAdmissionWorldJob(_ id: UUID) -> ScriptWorldJob? {
    withReadOnlyScriptState { $0.worldJobs[id] }
  }

  @inline(never)
  var contractStation: ContractStationIdentity {
    let galaxyField: KeyPath<Commander, Int> = \.galaxy
    let systemField: KeyPath<Commander, Int> = \.system
    guard let galaxyOffset = MemoryLayout<Commander>.offset(of: galaxyField),
      let systemOffset = MemoryLayout<Commander>.offset(of: systemField)
    else { preconditionFailure("Contract stations require addressable stored coordinates.") }
    let galaxyEnd = galaxyOffset.addingReportingOverflow(MemoryLayout<Int>.size)
    let systemEnd = systemOffset.addingReportingOverflow(MemoryLayout<Int>.size)
    precondition(
      galaxyOffset >= 0 && !galaxyEnd.overflow
        && galaxyEnd.partialValue <= MemoryLayout<Commander>.size)
    precondition(
      systemOffset >= 0 && !systemEnd.overflow
        && systemEnd.partialValue <= MemoryLayout<Commander>.size)
    return commanderStorage.withUnsafeBufferPointer { buffer in
      precondition(buffer.count == 1)
      let base = UnsafeRawPointer(buffer.baseAddress!)
      let galaxyAddress = base.advanced(by: galaxyOffset)
      let systemAddress = base.advanced(by: systemOffset)
      precondition(Int(bitPattern: galaxyAddress) % MemoryLayout<Int>.alignment == 0)
      precondition(Int(bitPattern: systemAddress) % MemoryLayout<Int>.alignment == 0)
      // Both addresses refer to initialized Int subobjects in this same live Commander.
      let galaxy = galaxyAddress.assumingMemoryBound(to: Int.self).pointee
      let system = systemAddress.assumingMemoryBound(to: Int.self).pointee
      return .init(galaxy: galaxy, system: system, stationClass: "main-orbital")
    }
  }

  @inline(never)
  var retainedNativeMainStationDockReceipt: NativeMainStationDockReceipt? {
    let field: KeyPath<Commander, NativeStationWorld?> = \.nativeStations
    guard let offset = MemoryLayout<Commander>.offset(of: field) else {
      preconditionFailure("Dock receipts require addressable stored station state.")
    }
    let end = offset.addingReportingOverflow(MemoryLayout<NativeStationWorld?>.size)
    precondition(
      offset >= 0 && !end.overflow && end.partialValue <= MemoryLayout<Commander>.size)
    return commanderStorage.withUnsafeBufferPointer { buffer in
      precondition(buffer.count == 1)
      let address = UnsafeRawPointer(buffer.baseAddress!).advanced(by: offset)
      precondition(Int(bitPattern: address) % MemoryLayout<NativeStationWorld?>.alignment == 0)
      // This initialized optional station subobject belongs to the same live Commander.
      return address.assumingMemoryBound(to: NativeStationWorld?.self).pointee?.currentMainDock
    }
  }

  var retainedMissionProjectiles: [UUID: ScriptProjectileRecord] {
    withReadOnlyScriptState { $0.projectiles }
  }

  func retainedMissionProjectileRestorationCandidates() throws -> [UUID] {
    try withReadOnlyCommander { commander in
      let galaxy = commander.galaxy
      let system = commander.system
      return try commander.withReadOnlyScriptState { state in
        try Self.retainedMissionProjectileRestorationCandidates(
          from: state, galaxy: galaxy, system: system)
      }
    }
  }

  private static func retainedMissionProjectileRestorationCandidates(
    from state: borrowing ScriptEngineState, galaxy: Int, system: Int
  ) throws -> [UUID] {
    var eligible: [UUID] = []
    for (id, record) in state.projectiles {
      guard record.galaxy == galaxy, record.system == system else { continue }
      guard id == record.body.scriptShot?.identity, record.valid,
        state.projectileArchiveValid(record)
      else { throw NativeMissionProjectileAdmissionError.invalidRecord }
      eligible.append(id)
    }
    return eligible
  }
  public var systems: [StarSystem] {
    _read {
      let stored: [StarSystem] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.systems)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].systems }
  }
  public var screen: Screen {
    _read {
      let stored: Screen = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.screen)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].screen }
  }
  public var paused: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.paused)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].paused }
  }
  public var isMissionTrial: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.isMissionTrial)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].isMissionTrial }
  }
  public var contractBoard: ContractBoardUI {
    _read {
      let stored: ContractBoardUI = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.contractBoard)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].contractBoard }
  }
  var scriptPledgeAdmission: ScriptPledgeAdmission? {
    _read {
      let stored: ScriptPledgeAdmission? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptPledgeAdmission)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptPledgeAdmission }
  }
  var scriptCourierAdmission: ScriptCourierAdmission? {
    _read {
      let stored: ScriptCourierAdmission? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptCourierAdmission)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptCourierAdmission }
  }
  public var trialTitle: String? {
    _read {
      let stored: String? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.trialTitle)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].trialTitle }
  }
  var trialDigest: String? {
    _read {
      let stored: String? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.trialDigest)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].trialDigest }
  }
  var trialSeed: UInt64? {
    _read {
      let stored: UInt64? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.trialSeed)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].trialSeed }
  }
  public var docked: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.docked)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].docked }
  }
  public var dockedAtMainStation: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.dockedAtMainStation)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].dockedAtMainStation }
  }
  var scriptReferenceFrame: ScriptReferenceFrame? {
    _read {
      let stored: ScriptReferenceFrame? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptReferenceFrame)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptReferenceFrame }
  }
  var scriptDispatching: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptDispatching)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptDispatching }
  }
  var scriptEventsDeferred: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptEventsDeferred)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptEventsDeferred }
  }
  var scriptDurabilityAvailable: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptDurabilityAvailable)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptDurabilityAvailable }
  }
  var empPlayerElectricalInterval: EMPPlayerElectricalInterval? {
    _read {
      let stored: EMPPlayerElectricalInterval? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.empPlayerElectricalInterval)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].empPlayerElectricalInterval }
  }
  var c01InquiryStepRuntime: NativeC01InquiryStepRuntimeState {
    _read {
      let stored: NativeC01InquiryStepRuntimeState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.c01InquiryStepRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].c01InquiryStepRuntime }
  }
  var empPulseBeforeResultStorage: EMPPulseBeforeResult? {
    _read {
      let stored: EMPPulseBeforeResult? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.empPulseBeforeResultStorage)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].empPulseBeforeResultStorage }
  }
  // Runtime-only destination ownership and acknowledgment; never encoded in Commander saves.
  var pendingNewSaveDestination: URL? {
    _read {
      let stored: URL? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.pendingNewSaveDestination)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].pendingNewSaveDestination }
  }
  var newCommanderSaveReceipt: CommanderFileReceipt? {
    _read {
      let stored: CommanderFileReceipt? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.newCommanderSaveReceipt)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].newCommanderSaveReceipt }
  }
  var nativeOriginalUtilityFatalStart: NativeOriginalUtilityFatalStart? {
    _read {
      let stored: NativeOriginalUtilityFatalStart? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeOriginalUtilityFatalStart)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeOriginalUtilityFatalStart }
  }
  var nativeOriginalUtilityFatalTransition: NativeOriginalUtilityFatalTransition? {
    _read {
      let stored: NativeOriginalUtilityFatalTransition? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeOriginalUtilityFatalTransition)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeOriginalUtilityFatalTransition }
  }
  var nativeOriginalStationPopulationPlan: NativeOriginalStationPopulationPlan? {
    _read {
      let stored: NativeOriginalStationPopulationPlan? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeOriginalStationPopulationPlan)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeOriginalStationPopulationPlan }
  }
  var c01InquiryNativeRegistry: NativeC01InquiryNativeRegistry {
    _read {
      let stored: NativeC01InquiryNativeRegistry = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.c01InquiryNativeRegistry)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].c01InquiryNativeRegistry }
  }
  var nativeStationRuntimeEpoch: UUID {
    _read {
      let stored: UUID = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeStationRuntimeEpoch)!.pointee
      }
      yield stored
    }
    set {
      valueStorage[0].nativeStationRuntimeEpoch = newValue
      c01InquiryNativeRegistry = .empty()
      c01InquiryStepRuntime.invalidateScene()
      nativeOrbitalOutlookRuntime = .init()
      nativeOriginalSurveyRuntime = nil
      nativeGlassMeridianRuntime = nil
      nativeFlightReceptionPending = nil
      nativeMeasuredExtractionPending = nil
      nativeRecordRecoveryPending = nil
      nativeCrewLogPickupPending = nil
      nativeC01SurveyorPending = nil
      nativeC01TimingStandardPending = nil
      c01LaneRepairWorkRuntime = NativeC01LaneRepairWorkRuntime()
      c01ClinicEscortRuntime = NativeC01ClinicEscortRuntime()
      nativeRecordRecoveryIdentificationPending = nil
      nativeIdentifiedSalvagePending = nil
      hollowManifestConsentReview = nil
      nativeC03MotionPending = nil
      nativeC03AttainedMotion = nil
      nativeC03ClockEvidence = nil
      c03ArchiveReaderDisplay = nil
      c03CrewRuntime = NativeC03CrewRuntime()
    }
    _modify {
      var epoch = valueStorage[0].nativeStationRuntimeEpoch
      defer { nativeStationRuntimeEpoch = epoch }
      yield &epoch
    }
  }
  var nativeOrbitalOutlookRuntime: NativeOrbitalOutlookRuntime {
    _read {
      let stored: NativeOrbitalOutlookRuntime = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeOrbitalOutlookRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeOrbitalOutlookRuntime }
  }
  var nativeAssemblyCalibrationDisplay: NativeAssemblySurveyInstrumentControls.Readout? {
    _read {
      let stored: NativeAssemblySurveyInstrumentControls.Readout? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeAssemblyCalibrationDisplay)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeAssemblyCalibrationDisplay }
  }
  var nativeAssemblyCapacityEditorDisplay: NativeAssemblyCapacityEditorDisplay? {
    _read {
      let stored: NativeAssemblyCapacityEditorDisplay? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeAssemblyCapacityEditorDisplay)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeAssemblyCapacityEditorDisplay }
  }
  var nativeOriginalSurveyRuntime: NativeOriginalSurveyRuntime? {
    _read {
      let stored: NativeOriginalSurveyRuntime? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeOriginalSurveyRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeOriginalSurveyRuntime }
  }
  var nativeGlassMeridianRuntime: NativeGlassMeridianRuntime? {
    _read {
      let stored: NativeGlassMeridianRuntime? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeGlassMeridianRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeGlassMeridianRuntime }
  }
  var nativeFlightReceptionPending: NativeFlightReceptionPending? {
    _read {
      let stored: NativeFlightReceptionPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeFlightReceptionPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeFlightReceptionPending }
  }
  var nativeMeasuredExtractionPending: NativeMeasuredExtractionPending? {
    _read {
      let stored: NativeMeasuredExtractionPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeMeasuredExtractionPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeMeasuredExtractionPending }
  }
  var nativeRecordRecoveryPending: WayfarerRecordRecoveryPending? {
    _read {
      let stored: WayfarerRecordRecoveryPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeRecordRecoveryPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeRecordRecoveryPending }
  }
  var nativeCrewLogPickupPending: NativeCrewLogPickupPending? {
    _read {
      let stored: NativeCrewLogPickupPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeCrewLogPickupPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeCrewLogPickupPending }
  }
  var nativeC01SurveyorPending: NativeC01SurveyorPending? {
    _read {
      let stored: NativeC01SurveyorPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeC01SurveyorPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeC01SurveyorPending }
  }
  var nativeC01TimingStandardPending: NativeC01TimingStandardPending? {
    _read {
      let stored: NativeC01TimingStandardPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeC01TimingStandardPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeC01TimingStandardPending }
  }
  var c01LaneRepairWorkRuntime: NativeC01LaneRepairWorkRuntime {
    _read {
      let stored: NativeC01LaneRepairWorkRuntime = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.c01LaneRepairWorkRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].c01LaneRepairWorkRuntime }
  }
  var c01ClinicEscortRuntime: NativeC01ClinicEscortRuntime {
    _read {
      let stored: NativeC01ClinicEscortRuntime = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.c01ClinicEscortRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].c01ClinicEscortRuntime }
  }
  var nativeRecordRecoveryIdentificationPending: WayfarerRecordRecoveryIdentificationPending? {
    _read {
      let stored: WayfarerRecordRecoveryIdentificationPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeRecordRecoveryIdentificationPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeRecordRecoveryIdentificationPending }
  }
  var nativeIdentifiedSalvagePending: NativeIdentifiedSalvagePending? {
    _read {
      let stored: NativeIdentifiedSalvagePending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeIdentifiedSalvagePending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeIdentifiedSalvagePending }
  }
  var hollowManifestConsentReview: NativeHollowManifestConsentReview? {
    _read {
      let stored: NativeHollowManifestConsentReview? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.hollowManifestConsentReview)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].hollowManifestConsentReview }
  }
  var nativeC03MotionPending: NativeC03MotionPending? {
    _read {
      let stored: NativeC03MotionPending? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeC03MotionPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeC03MotionPending }
  }
  var nativeC03AttainedMotion: NativeC03AttainedMotionResult? {
    _read {
      let stored: NativeC03AttainedMotionResult? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeC03AttainedMotion)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeC03AttainedMotion }
  }
  var nativeC03ClockEvidence: CurrentNewtNativeClockEvidence? {
    _read {
      let stored: CurrentNewtNativeClockEvidence? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeC03ClockEvidence)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeC03ClockEvidence }
  }
  var c03CrewRuntime: NativeC03CrewRuntime {
    _read {
      let stored: NativeC03CrewRuntime = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.c03CrewRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].c03CrewRuntime }
  }
  var c03ArchiveReaderDisplay: NativeC03ArchiveReaderDisplay? {
    _read {
      let stored: NativeC03ArchiveReaderDisplay? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.c03ArchiveReaderDisplay)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].c03ArchiveReaderDisplay }
  }
  var nativeCrimboMotionSample: NativeCrimboMotionSample? {
    _read {
      let stored: NativeCrimboMotionSample? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeCrimboMotionSample)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeCrimboMotionSample }
  }
  var nativeCrimboAttainedMotion: NativeCrimboAttainedMotion? {
    _read {
      let stored: NativeCrimboAttainedMotion? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeCrimboAttainedMotion)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeCrimboAttainedMotion }
  }
  // Enabled only by G1 after supported native save/world/durability validation. Never saved.
  var nativeCrimboLifecycleAvailable: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeCrimboLifecycleAvailable)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeCrimboLifecycleAvailable }
  }
  var nativeSalvageMotion: [SalvageLotIdentity: NativeSalvageMotion] {
    _read {
      let stored: [SalvageLotIdentity: NativeSalvageMotion] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeSalvageMotion)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeSalvageMotion }
  }
  var nativeSalvageWreckMotion: [WreckIdentity: NativeSalvageWreckObservation] {
    _read {
      let stored: [WreckIdentity: NativeSalvageWreckObservation] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeSalvageWreckMotion)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeSalvageWreckMotion }
  }
  var nativeSalvageWork: NativeSalvageHotWork? {
    _read {
      let stored: NativeSalvageHotWork? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeSalvageWork)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeSalvageWork }
  }
  var nativeSalvageAdmissionDiagnostic: NativeSalvageAdmissionDiagnostic? {
    _read {
      let stored: NativeSalvageAdmissionDiagnostic? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeSalvageAdmissionDiagnostic)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeSalvageAdmissionDiagnostic }
  }
  var nativeEncounterBirthDiagnostic: GameplayEncounterBirthDiagnostic? {
    _read {
      let stored: GameplayEncounterBirthDiagnostic? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeEncounterBirthDiagnostic)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeEncounterBirthDiagnostic }
  }
  var pendingNativeSalvageCollections: [NativeSalvageCollectionObservation] {
    _read {
      let stored: [NativeSalvageCollectionObservation] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.pendingNativeSalvageCollections)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].pendingNativeSalvageCollections }
  }
  var pendingMemoryAtlasMainDock: NativeMemoryAtlasMainEntryProof? {
    _read {
      let stored: NativeMemoryAtlasMainEntryProof? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.pendingMemoryAtlasMainDock)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].pendingMemoryAtlasMainDock }
  }

  var pendingNativeStationDock: NativeStationEntryProof? {
    _read {
      let stored: NativeStationEntryProof? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.pendingNativeStationDock)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].pendingNativeStationDock }
  }
  var inductionArkDockPublicationPending: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.inductionArkDockPublicationPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].inductionArkDockPublicationPending }
  }
  var inductionRescueDockPublicationPending: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.inductionRescueDockPublicationPending)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].inductionRescueDockPublicationPending }
  }
  var inductionUtilityWorkRuntime: NativeInductionUtilityWorkRuntime {
    _read {
      let stored: NativeInductionUtilityWorkRuntime = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.inductionUtilityWorkRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].inductionUtilityWorkRuntime }
  }
  var isolationWorkRuntime: NativeIsolationWorkRuntime {
    _read {
      let stored: NativeIsolationWorkRuntime = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.isolationWorkRuntime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].isolationWorkRuntime }
  }
  var nativeStationDockEvidence: NativeStationDockEvidence? {
    _read {
      let stored: NativeStationDockEvidence? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeStationDockEvidence)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeStationDockEvidence }
  }
  var nativeMainStationDockEvidence: NativeMainStationDockEvidence? {
    _read {
      let stored: NativeMainStationDockEvidence? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nativeMainStationDockEvidence)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nativeMainStationDockEvidence }
  }
  public var scriptPacks: [ScriptPack] {
    _read {
      let stored: [ScriptPack] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptPacks)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptPacks }
  }
  public var scriptAvailablePackDigest: String? {
    _read {
      let stored: String? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptAvailablePackDigest)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptAvailablePackDigest }
  }
  public var scriptOffer: UUID? {
    _read {
      let stored: UUID? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptOffer)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptOffer }
  }
  public var scriptPresentedDialogue: ScriptDialogue? {
    _read {
      let stored: ScriptDialogue? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptPresentedDialogue)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptPresentedDialogue }
  }
  public var scriptConfirmSelected: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptConfirmSelected)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptConfirmSelected }
  }
  public var scriptChoiceSelection: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptChoiceSelection)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptChoiceSelection }
  }
  public var missionPacks: MissionPackLibrary {
    _read {
      let stored: MissionPackLibrary = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missionPacks)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missionPacks }
  }
  public var packOffer: PackOffer? {
    _read {
      let stored: PackOffer? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.packOffer)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].packOffer }
  }
  public var packOfferElapsed: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.packOfferElapsed)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].packOfferElapsed }
  }
  public var packDialogScroll: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.packDialogScroll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].packDialogScroll }
  }
  public var blackjackOffer: BlackjackOffer? {
    _read {
      let stored: BlackjackOffer? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.blackjackOffer)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].blackjackOffer }
  }
  public var showroom: ShowroomState {
    _read {
      let stored: ShowroomState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.showroom)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].showroom }
  }
  public var galacticBrowse: GalaxyBrowseState {
    _read {
      let stored: GalaxyBrowseState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.galacticBrowse)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].galacticBrowse }
  }
  public var systemInspection: SystemInspection? {
    _read {
      let stored: SystemInspection? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.systemInspection)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].systemInspection }
  }
  public var rumourReturn: Screen {
    _read {
      let stored: Screen = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.rumourReturn)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].rumourReturn }
  }
  var wantedSelection: ActorIdentity? {
    _read {
      let stored: ActorIdentity? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.wantedSelection)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].wantedSelection }
  }
  var wantedPlayerSelected: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.wantedPlayerSelected)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].wantedPlayerSelected }
  }
  var wantedDetail: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.wantedDetail)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].wantedDetail }
  }
  var wantedRumourDetail: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.wantedRumourDetail)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].wantedRumourDetail }
  }
  var wantedScroll: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.wantedScroll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].wantedScroll }
  }
  var wantedReadContext: WantedReadContext? {
    _read {
      let stored: WantedReadContext? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.wantedReadContext)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].wantedReadContext }
  }
  public var blackjackReturn: Screen {
    _read {
      let stored: Screen = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.blackjackReturn)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].blackjackReturn }
  }
  var screenHistory: [Screen] {
    _read {
      let stored: [Screen] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.screenHistory)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].screenHistory }
  }
  var flightReturn: Screen {
    _read {
      let stored: Screen = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.flightReturn)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].flightReturn }
  }
  public var selectedSystem: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.selectedSystem)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].selectedSystem }
  }
  public var selection: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.selection)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].selection }
  }
  public var informationScroll: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.informationScroll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].informationScroll }
  }
  public var chartInformationScroll: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.chartInformationScroll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].chartInformationScroll }
  }
  /// Mutable station stock is commander-owned and survives departure, save and reload.
  public var market: [MarketItem] {
    get { commander.originalMarkets.items(galaxy: commander.galaxy, system: currentSystem) }
    set { commander.originalMarkets.set(newValue, galaxy: commander.galaxy, system: currentSystem) }
  }
  public var bodies: [SpaceBody] {
    _read {
      let stored: [SpaceBody] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.bodies)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].bodies }
  }
  public var miningFields: [MiningField] {
    _read {
      let stored: [MiningField] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.miningFields)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].miningFields }
  }
  public var salvageSites: [SalvageSite] {
    _read {
      let stored: [SalvageSite] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.salvageSites)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].salvageSites }
  }
  var gameplayRevision: UInt64 {
    _read {
      let stored: UInt64 = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.gameplayRevision)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].gameplayRevision }
  }
  /// Actual contact disqualifies this physical frame from attained-motion credit.
  var stationImpactRevision: UInt64? {
    _read {
      let stored: UInt64? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.stationImpactRevision)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].stationImpactRevision }
  }
  // A laser capability is consumed synchronously in the same actor turn that emitted it.
  // Bounded and ephemeral: capabilities are never restored from a commander save.
  var consumedMissionLaserEmission: UInt64 {
    _read {
      let stored: UInt64 = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.consumedMissionLaserEmission)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].consumedMissionLaserEmission }
  }
  var salvageAdmissionGeometry: [String: PreparedSalvageAdmissionHull] {
    _read {
      let stored: [String: PreparedSalvageAdmissionHull] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.salvageAdmissionGeometry)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].salvageAdmissionGeometry }
  }
  public var starfield: Starfield {
    _read {
      let stored: Starfield = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.starfield)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].starfield }
  }
  public var speed: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.speed)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].speed }
  }
  public var pitch: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.pitch)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].pitch }
  }
  public var roll: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.roll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].roll }
  }
  public var yaw: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.yaw)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].yaw }
  }
  public var spin: SpinControl {
    _read {
      let stored: SpinControl = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.spin)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].spin }
  }
  public var autoPilot: AutoTargetControl {
    _read {
      let stored: AutoTargetControl = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.autoPilot)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].autoPilot }
  }
  var stationAutoDefence: StationAutoDefenceState? {
    _read {
      let stored: StationAutoDefenceState? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.stationAutoDefence)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].stationAutoDefence }
  }
  public var workTargetFilter: WorkTargetFilter {
    _read {
      let stored: WorkTargetFilter = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.workTargetFilter)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].workTargetFilter }
  }
  var workGuidance: FlightWorkGuidance? {
    _read {
      let stored: FlightWorkGuidance? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.workGuidance)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].workGuidance }
  }
  var workBraking: FlightWorkBraking? {
    _read {
      let stored: FlightWorkBraking? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.workBraking)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].workBraking }
  }
  var workRecoveryRock: RockIdentity? {
    _read {
      let stored: RockIdentity? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.workRecoveryRock)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].workRecoveryRock }
  }
  var workRecoveryAdmissionDeadline: Double? {
    _read {
      let stored: Double? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.workRecoveryAdmissionDeadline)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].workRecoveryAdmissionDeadline }
  }
  var approvedWorkMotion: HullSceneMotion? {
    _read {
      let stored: HullSceneMotion? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.approvedWorkMotion)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].approvedWorkMotion }
  }
  var lastAppliedWorkMotion: HullSceneMotion? {
    _read {
      let stored: HullSceneMotion? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.lastAppliedWorkMotion)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].lastAppliedWorkMotion }
  }
  var plannedLegacyWorkMotion: [Int: HullSweepObstacle] {
    _read {
      let stored: [Int: HullSweepObstacle] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.plannedLegacyWorkMotion)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].plannedLegacyWorkMotion }
  }
  var workScenePlanned: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.workScenePlanned)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].workScenePlanned }
  }
  var workFireSuspended: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.workFireSuspended)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].workFireSuspended }
  }
  var flightTrigger: FlightTriggerState {
    _read {
      let stored: FlightTriggerState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.flightTrigger)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].flightTrigger }
  }
  var selectedToolActivity: FlightToolActivity? {
    _read {
      let stored: FlightToolActivity? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.selectedToolActivity)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].selectedToolActivity }
  }
  /// Immutable presentation for the delivered runtime snapshot, prepared off the paint path.
  public internal(set) var flightWeaponDisplay: FlightWeaponDisplay {
    _read {
      let stored: FlightWeaponDisplay = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.flightWeaponDisplay)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].flightWeaponDisplay }
  }
  var manualResidualFlight: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.manualResidualFlight)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].manualResidualFlight }
  }
  public var viewportWidth: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.viewportWidth)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].viewportWidth }
  }
  public var viewportHeight: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.viewportHeight)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].viewportHeight }
  }
  public var targetPanelExpanded: Bool? {
    _read {
      let stored: Bool? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.targetPanelExpanded)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].targetPanelExpanded }
  }
  public var targetPanelScroll: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.targetPanelScroll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].targetPanelScroll }
  }
  public var weaponsTargetID: Int? {
    _read {
      let stored: Int? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.weaponsTargetID)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].weaponsTargetID }
  }
  public var secretScroll: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.secretScroll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].secretScroll }
  }
  public var energy: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.energy)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].energy }
  }
  public var frontShield: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.frontShield)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].frontShield }
  }
  public var rearShield: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.rearShield)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].rearShield }
  }
  public var laserHeat: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.laserHeat)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].laserHeat }
  }
  public var laserFlash: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.laserFlash)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].laserFlash }
  }
  var playerImpactFeedback: PlayerImpactFeedback? {
    _read {
      let stored: PlayerImpactFeedback? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.playerImpactFeedback)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].playerImpactFeedback }
  }
  public var dischargeAudio: DischargeAudioState {
    _read {
      let stored: DischargeAudioState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.dischargeAudio)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].dischargeAudio }
  }
  var gameplayCombatTrace: GameplayCombatTrace? {
    _read {
      let stored: GameplayCombatTrace? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.gameplayCombatTrace)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].gameplayCombatTrace }
  }
  public var altitude: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.altitude)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].altitude }
  }
  public var celestials: [CelestialBody] {
    _read {
      let stored: [CelestialBody] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.celestials)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].celestials }
  }
  public var solarScoopState: SolarScoopState {
    _read {
      let stored: SolarScoopState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.solarScoopState)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].solarScoopState }
  }
  var solarFuelRemainder: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.solarFuelRemainder)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].solarFuelRemainder }
  }
  public var cabinTemperature: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.cabinTemperature)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].cabinTemperature }
  }
  public var equipmentMount: LaserMount {
    _read {
      let stored: LaserMount = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.equipmentMount)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].equipmentMount }
  }
  public var equipmentWorkTool: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.equipmentWorkTool)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].equipmentWorkTool }
  }
  public var equipmentCrewSelected: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.equipmentCrewSelected)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].equipmentCrewSelected }
  }
  public var selectedFlightTool: FlightWorkTool {
    _read {
      let stored: FlightWorkTool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.selectedFlightTool)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].selectedFlightTool }
  }
  public internal(set) var inventoryContextEpoch: InventoryContextEpoch {
    _read {
      let stored: InventoryContextEpoch = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.inventoryContextEpoch)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].inventoryContextEpoch }
  }
  public var inventoryActionSelection: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.inventoryActionSelection)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].inventoryActionSelection }
  }
  public var inventoryUpgradeChoice: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.inventoryUpgradeChoice)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].inventoryUpgradeChoice }
  }
  public var dockingComputer: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.dockingComputer)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].dockingComputer }
  }
  public var missileArmed: Bool {
    _read {
      let stored: Bool = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missileArmed)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missileArmed }
  }
  public var message: String {
    _read {
      let stored: String = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.message)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].message }
  }
  public var messageTime: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.messageTime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].messageTime }
  }
  public var jumpCountdown: Double? {
    _read {
      let stored: Double? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.jumpCountdown)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].jumpCountdown }
  }
  public var time: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.time)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].time }
  }
  var scriptStartupTime: Double? {
    _read {
      let stored: Double? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.scriptStartupTime)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].scriptStartupTime }
  }
  public var secretBuffer: String {
    _read {
      let stored: String = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.secretBuffer)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].secretBuffer }
  }
  public var secretReturn: Screen {
    _read {
      let stored: Screen = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.secretReturn)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].secretReturn }
  }
  public var helpReturn: Screen {
    _read {
      let stored: Screen = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.helpReturn)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].helpReturn }
  }
  public var helpPage: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.helpPage)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].helpPage }
  }
  public var gallery: MissionGalleryState {
    _read {
      let stored: MissionGalleryState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.gallery)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].gallery }
  }
  var c01InquiryJournal: NativeC01InquiryJournalState {
    _read {
      let stored: NativeC01InquiryJournalState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.c01InquiryJournal)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].c01InquiryJournal }
  }
  public var library: ScriptLibraryState {
    _read {
      let stored: ScriptLibraryState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.library)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].library }
  }
  public var mapColour: MapColourMode {
    _read {
      let stored: MapColourMode = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.mapColour)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].mapColour }
  }
  public var mapZoom: MapZoom {
    _read {
      let stored: MapZoom = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.mapZoom)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].mapZoom }
  }
  public var mapSearch: PlanetSearchState {
    _read {
      let stored: PlanetSearchState = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.mapSearch)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].mapSearch }
  }
  public var navigationOptions: [RouteAlternative] {
    _read {
      let stored: [RouteAlternative] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.navigationOptions)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].navigationOptions }
  }
  public var navigationSelection: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.navigationSelection)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].navigationSelection }
  }
  public var navigationScroll: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.navigationScroll)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].navigationScroll }
  }
  public var navigationReturn: Screen {
    _read {
      let stored: Screen = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.navigationReturn)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].navigationReturn }
  }
  public var missionNotice: MissionNotice? {
    _read {
      let stored: MissionNotice? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missionNotice)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missionNotice }
  }
  public var missionPage: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missionPage)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missionPage }
  }
  public var missionClue: String? {
    _read {
      let stored: String? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missionClue)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missionClue }
  }
  public var missionElapsed: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missionElapsed)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missionElapsed }
  }
  var fireCooldown: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.fireCooldown)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].fireCooldown }
  }
  var missionLoopCounter: UInt8 {
    _read {
      let stored: UInt8 = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missionLoopCounter)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missionLoopCounter }
  }
  var missionSpawnDelay: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missionSpawnDelay)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missionSpawnDelay }
  }
  // Legacy callers share ECMControl's physical-time clock; there is no second countdown.
  var ecmFrames: Int {
    get { ecmControl.legacyFrames }
    set { ecmControl.setLegacyFrames(newValue) }
  }
  var enemyECMSource: Int? {
    _read {
      let stored: Int? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.enemyECMSource)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].enemyECMSource }
  }
  var activeECMActivation: ECMActivationIdentity? {
    _read {
      let stored: ECMActivationIdentity? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.activeECMActivation)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].activeECMActivation }
  }
  public var ecmControl: ECMControl {
    _read {
      let stored: ECMControl = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.ecmControl)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].ecmControl }
  }
  public var retaliation: RetaliationControl {
    _read {
      let stored: RetaliationControl = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.retaliation)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].retaliation }
  }
  var missileCooldown: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.missileCooldown)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].missileCooldown }
  }
  var nextBodyID: Int {
    _read {
      let stored: Int = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nextBodyID)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nextBodyID }
  }
  private var legacySimulationSpawnClock: Double? {
    _read {
      let stored: Double? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.legacySimulationSpawnClock)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].legacySimulationSpawnClock }
  }
  private var randomState: UInt64 {
    _read {
      let stored: UInt64 = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.randomState)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].randomState }
  }
  public init(executive: Bool = true) {
    energy = nativeStartupEnergy()
    frontShield = nativeStartupFrontShield()
    rearShield = nativeStartupRearShield()
    if executive {
      commander.executive = true
      screen = .demo
    }
  }
  /// Creates the isolated fixture used by the native planet frame profiler.
  package static func planetFrameProfileFixture(system: Int) throws -> Game {
    var game = Game(executive: false)
    guard game.systems.indices.contains(system) else { throw NativeStationRuntimeError.invalidState }
    game.commander.system = system
    game.selectedSystem = system
    game.commander.shipDisplayStyle = .shadedPanels
    game.screen = .status
    try game.commander.prepareEquipment(legacy: false)
    game.commander.mirrorFittedEquipment()
    return game
  }

  public var currentSystem: StarSystem { systems[nativeCurrentSystemIndex()] }
  public var targetSystem: StarSystem { systems[selectedSystem] }

  public mutating func notify(_ text: String, voiced: Bool = true) {
    if voiced { ecmControl.emit(.gameplay(text)) }
    message = text
    messageTime = 4
  }
  public mutating func load(_ value: Commander) -> Bool {
    var candidate = self
    candidate.stationAutoDefence = nil
    candidate.gameplayCombatTrace = nil
    guard candidate.loadCommander(value) else { return false }
    candidate.c01InquiryStepRuntime = .init()
    self = candidate
    return true
  }
  private mutating func loadCommander(_ value: Commander) -> Bool {
    guard value.valid, !value.usesAlienStorageSaveVersion,
      !CurrentNewtKitSave.hasClaims(value), value.savedBisonUnitAllocations == nil,
      !value.usesEMPSaveVersion, !value.usesModularDriveSaveVersion,
      !value.usesEconomyMiningSaveVersion,
      !value.usesFreightNativeSaveVersion, !value.usesProviderContractSaveVersion,
      value.scriptState.savedFleetDiscovery == nil,
      value.scriptState.firstNativeCommoditySale == nil,
      !NativePracticeSave.hasClaims(value), !NativeSafeGunnerySave.hasClaims(value),
      !NativeDefensiveFlightSave.hasClaims(value),
      !NativeInductionCrewLogSave.hasClaims(value),
      !NativeInductionArkSave.hasClaims(value),
      !NativeWayfarerInductionSave.hasClaims(value),
      value.scriptState.financeLedger == nil, value.scriptState.savedClueJournal == nil,
      value.scriptState.savedC01Inquiry == nil,
      !value.scriptState.instances.values.contains(where: { $0.savedNavigationTrade != nil })
    else {
      return false
    }
    // The loaded commander owns a different native allocation timeline. Invalidate old
    // capabilities and allow that timeline's first genuine emission to be consumed once.
    gameplayRevision &+= 1
    consumedMissionLaserEmission = 0
    legacySimulationSpawnClock = nil
    nativeSalvageMotion.removeAll(keepingCapacity: true)
    nativeSalvageWreckMotion.removeAll(keepingCapacity: true)
    nativeSalvageWork = nil
    pendingNativeSalvageCollections.removeAll(keepingCapacity: true)
    bodies = []
    scriptReferenceFrame = nil
    scriptStartupTime = nil
    commander = value
    invalidateNativeStationAuthority()
    if commander.npcPersistence.count > 0 {
      commander.npcPersistence.resetPhysicalBindings(
        system: .init(galaxy: value.galaxy, system: value.system))
    }
    commander.resetWantedCareerBindings(system: .init(galaxy: value.galaxy, system: value.system))
    clearCelestialFlight()
    blackjackOffer = nil
    packOffer = nil
    scriptOffer = nil
    scriptPresentedDialogue = nil
    scriptAvailablePackDigest = nil
    scriptChoiceSelection = 0
    migrateMissionProgress()
    gallery = MissionGalleryState()
    library = ScriptLibraryState()
    c01InquiryJournal = NativeC01InquiryJournalState()
    showroom = ShowroomState()
    galacticBrowse = GalaxyBrowseState()
    systemInspection = nil
    dockedAtMainStation = commander.nativeStations?.ledger.currentDock == nil
    enforceBlackjackWanted()
    commander.migrateXYZzyPolicy()
    commander.migrateLegacyXYZzyMounts()
    mapSearch = PlanetSearchState()
    do { try commander.prepareEquipment() } catch { return false }
    commander.mirrorFittedEquipment()
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.rearShieldCapacity
    targetPanelExpanded = nil
    targetPanelScroll = 0
    systems = Universe.systemsIncludingPlugh(number: value.galaxy)
    do { try migrateMiningPresence(legacyMissing: true) } catch { return false }
    selectedSystem = value.system
    docked = true
    bodies = []
    missionNotice = nil
    missionPage = 0
    missionClue = nil
    missionElapsed = 0
    missionLoopCounter = 0
    missionSpawnDelay = 0
    ecmFrames = 0
    ecmControl = ECMControl()
    dischargeAudio = DischargeAudioState()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    paused = false
    spin.stop(immediate: true)
    cancelAutoTarget()
    autoPilot = AutoTargetControl()
    clearManualResidualFlight()
    screen = .status
    screenHistory.removeAll()
    speed = 0
    reconcileEliteReward()
    navigationDocked()
    inventoryContextEpoch = .init()
    inventoryActionSelection = 0
    inventoryUpgradeChoice = 0
    equipmentMount = .front
    equipmentWorkTool = false
    equipmentCrewSelected = false
    return true
  }
  public mutating func key(_ raw: String) {
    let key = raw.lowercased()
    if prepareFlightControlKey(key) { return }
    guard flushNativeSalvageWork() else {
      notify("SALVAGE STATE UNAVAILABLE")
      return
    }
    let priorScreen = screen
    let priorPause = paused
    defer { if screen != priorScreen || paused != priorPause { interruptFlightTool() } }
    if handleC01ClinicEscortKey(key) { return }
    if handleC01LaneRepairWorkKey(key) { return }
    if handleInductionUtilityWorkKey(key) { return }
    if handleIsolationWorkKey(key) { return }
    if interfaceKey(key) { return }
    keyAfterInterface(key)
  }
  private mutating func keyAfterInterface(_ key: String) {
    if !docked && screen.isFlight {
      if sharedFlightKey(key) { return }
      switch key {
      case "pageup", "pagedown":
        pageTargetDetails(key == "pageup" ? -1 : 1)
        return
      case "i":
        targetPanelExpanded = !(targetPanelExpanded ?? (viewportWidth >= 1100))
        return
      case "v":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.toggleMode()
        return
      case "b":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.stop()
        return
      case "]", "spin:cw":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.begin(.clockwise)
        return
      case "[", "spin:ccw":
        if autoTargetBody?.hull == .station || workGuidance != nil || workBraking != nil {
          cancelAutoTarget()
        }
        spin.begin(.anticlockwise)
        return
      default: break
      }
    }
    if screen == .demo { return }
    if screen == .title || screen == .gameOver {
      if key == " " || key == "return" {
        if screen == .title, let restoredTime = scriptStartupTime {
          time = restoredTime
          scriptStartupTime = nil
        }
        if screen == .gameOver {
          do { try restartBornBerthedCommander() } catch {
            notify("NEW COMMANDER STATE UNAVAILABLE - RESTART REFUSED", voiced: false)
            return
          }
        }
        screen = .status
      }
      return
    }
    if key.count == 1, let number = Int(key), (0...9).contains(number) {
      functionKey(number)
      return
    }
    switch key {
    case "up":
      if screen == .equipment {
        moveEquipmentSelection(-1)
      } else if [.buy, .sell, .market].contains(screen) {
        selection = MarketDisplayOrder.moved(selection: selection, direction: -1)
      } else {
        selection = max(0, selection - 1)
      }
    case "down":
      if screen == .equipment {
        moveEquipmentSelection(1)
      } else if [.buy, .sell, .market].contains(screen) {
        selection = MarketDisplayOrder.moved(selection: selection, direction: 1)
      } else {
        selection = min(Commodity.all.count - 1, selection + 1)
      }
    case "left", "right":
      if screen == .equipment || screen == .inventory {
        cycleEquipmentFitting(key == "right" ? 1 : -1)
        if screen == .inventory {
          inventoryUpgradeChoice &+= key == "right" ? 1 : -1
        }
      } else if screen == .chart || screen == .shortChart {
        selectChartNeighbour(key == "left" ? -1 : 1)
      } else if screen == .buy || screen == .sell {
        trade(buy: key == "right")
      }
    case "tab":
      if screen == .inventory { inventoryActionSelection &+= 1 }
    case "return":
      if screen == .buy || screen == .sell { trade(buy: screen == .buy) }
      if screen == .equipment { purchase() }
    case "z": if screen == .shortChart { mapZoom = mapZoom.next }
    case "o":
      if screen == .chart {
        returnChartToCurrentLocation()
      } else if screen == .shortChart {
        manuallySelectSystem(commander.system)
      }
    case "d":
      if screen == .chart || screen == .shortChart {
        notify(
          mapIsCurrentGalaxy
            ? String(
              format: "DISTANCE %.1f LIGHT YEARS", currentSystem.distance(to: mapTargetSystem))
            : "DISTANCE UNAVAILABLE ACROSS GALAXIES")
      }
    case "b": if docked { offerBlackjackHandoff() }
    case "h": beginHyperspace()
    case "g": galacticJump()
    case "j": inSystemJump()
    case "t": missileArmed = !docked && (commander.missiles > 0 || commander.unlimitedMissiles)
    case "u":
      missileArmed = false
      retaliation.clear()
      weaponsTargetID = nil
    case "m": fireMissile()
    case "e": ecm()
    case "p": cancelAutoTarget()
    case "energy-bomb": energyBomb()
    case "escape-pod": escapePod()
    default: break
    }
  }
  mutating func secretKey(_ key: String) {
    if ["up", "down", "pageup", "pagedown"].contains(key) {
      secretScroll = secretWindow.moved(key == "up" || key == "pageup" ? -1 : 1)
      return
    }
    switch key {
    case "0":
      commander.shipDisplayStyle = commander.shipDisplayStyle.next
      notify(commander.shipDisplayStyle.label)
    case "1":
      if commander.targetingTier.map({ $0 >= .docking }) != true {
        do {
          try commander.grantEquipment(
            TargetingTier.docking.equipmentName, at: .targetingCore, provenance: .xyzzy)
        } catch {
          notify("DOCKING COMPUTER REFIT REFUSED")
          return
        }
      }
      notify("DOCKING TARGETING COMPUTER FITTED")
    case "2":
      fitMaximumHardware()
    case "c": restoreXYZzyStarter()
    case "3":
      commander.unlimitedMissiles.toggle()
      notify("MISSILE SUPPLY UPDATED")
    case "4":
      commander.unlimitedFuel.toggle()
      if commander.unlimitedFuel { commander.fuel = commander.fuelCapacity }
      notify("FUEL SUPPLY UPDATED")
    case "5":
      notify(
        String(format: "JUMP LIMIT %.1f LY - FUEL AND NAV COMPUTER", commander.maximumJumpDistance))
    case "6":
      commander.autoTrade.toggle()
      if commander.autoTrade { autoTrade() }
      notify("AUTO TRADE UPDATED")
    case "7":
      commander.speech.toggle()
      notify("SPEECH UPDATED")
    case "8":
      if commander.unlimitedCargo
        && commander.cargoTonnes > commander.standardCargoCapacity
      {
        notify("SELL EXCESS CARGO FIRST")
      } else {
        commander.unlimitedCargo.toggle()
        notify("CARGO CAPACITY UPDATED")
      }
    case "9":
      notify(String(format: "CASH %.1f CR", Double(commander.credits) / 10))
    case "b":
      commander.retaliationEnabled.toggle()
      if !commander.retaliationEnabled { retaliation.clear() }
      notify("MILITARY RETURN FIRE UPDATED")
    case "f":
      do {
        try commander.grantEquipment("Fuel Scoops", at: .utility(.fuelScoops), provenance: .xyzzy)
      } catch {
        notify("FUEL SCOOP REFIT REFUSED")
        return
      }
      notify("FUEL SCOOPS FITTED")
    case "e":
      commander.autoECM.toggle()
      notify("AUTOMATIC ECM UPDATED")
    case "l":
      commander.legal = 0
      commander.xyzzyWantedAmnesty = commander.blackjack.stage.wanted
      notify("LEGAL STATUS RESET TO CLEAN")
    case "a":
      commander.autoTarget.toggle()
      if !commander.autoTarget { cancelAutoTarget() }
      notify("AUTO TARGET UPDATED")
    case "escape", "return": screen = secretReturn
    default: break
    }
  }
  mutating func enableXYZzy() {
    var candidate = self
    candidate.commander.xyzzyActive = true
    candidate.commander.name = "CLARKE"
    candidate.commander.profitScanEnabled = true
    candidate.commander.shipDisplayStyle = .shadedPanels
    candidate.commander.retaliationEnabled = true
    candidate.commander.unlimitedMissiles = true
    candidate.commander.unlimitedFuel = true
    candidate.commander.unlimitedJumps = false
    candidate.commander.unlimitedCargo = true
    candidate.commander.startXYZzyCash()
    candidate.commander.autoTrade = true
    candidate.commander.speech = true
    candidate.commander.autoECM = true
    candidate.commander.autoTarget = true
    do { try candidate.refitXYZzyStarter() } catch {
      notify("MAXIMUM REFIT REFUSED")
      return
    }
    if candidate.docked { candidate.autoTrade() }
    self = candidate
  }
  mutating func restoreXYZzyStarter(renamingCommander: Bool = false) {
    var candidate = self
    if renamingCommander { candidate.commander.name = "CLARKE" }
    do { try candidate.refitXYZzyStarter() } catch {
      notify("MAXIMUM REFIT REFUSED")
      return
    }
    self = candidate
  }
  private mutating func refitXYZzyStarter() throws {
    try commander.prepareEquipment()
    if commander.shipID != NewCommanderDefaults.shipID {
      // Hull exchange preserves every portable item and refuses incompatible fittings.
      // The explicit maximum-hardware grant fills only vacant compatible pylons.
      commander.fuel = 0
      commander.unlimitedCargo = true
      try commander.transferEquipment(to: NewCommanderDefaults.shipID, hullID: UUID())
    }
    try commander.grantMaximumHardware()
    refillMaximumHardware()
    if commander.cargoTonnes > commander.standardCargoCapacity { commander.unlimitedCargo = true }
    speed = min(speed, commander.performance.speed)
    showroom.selection = commander.shipID
    showroom.baseline = commander.shipID
    showroom.baselineUsesCurrent = true
    clearShowroomSearch()
    notify("STARTER HULL REFITTED - MAXIMUM HARDWARE")
  }
  mutating func fitMaximumHardware() {
    var candidate = self
    do { try candidate.commander.grantMaximumHardware() } catch {
      notify("MAXIMUM REFIT REFUSED")
      return
    }
    candidate.refillMaximumHardware()
    self = candidate
    notify("MAXIMUM HARDWARE FITTED")
  }
  private mutating func refillMaximumHardware() {
    commander.fuel = commander.fuelCapacity
    energy = commander.performance.energy
    frontShield = commander.shieldCapacity
    rearShield = commander.rearShieldCapacity
  }
  mutating func functionKey(_ number: Int) {
    if number == 6 && docked {
      openShowroom()
      return
    }
    if number == 0 && docked {
      launch()
      return
    }
    selectNumberedDestination(number)
  }
  private mutating func selectNumberedDestination(_ number: Int) {
    guard let destination = Self.numberedScreen(number, docked: docked) else { return }
    if destination == .system {
      systemInspection =
        screen == .chart ? .init(galaxy: viewedGalaxy, system: viewedSystemID) : nil
      let variation = commander.missionStage.rawValue & 1 == 1 ? randomByte() % 5 : 0
      missionClue =
        inspectedGalaxy == commander.galaxy
        ? MissionRules.clue(
          stage: commander.missionStage, galaxy: inspectedGalaxy,
          system: inspectedSystem.id, variation: variation) : nil
    }
    if docked && [.buy, .sell].contains(screen) && [.buy, .sell].contains(destination) {
      screen = destination
    } else {
      navigatePrimary(to: destination)
    }
  }
  public mutating func selectNeighbour(direction: Int) {
    let known = knownSystems
    let current = known.firstIndex { $0.id == selectedSystem } ?? 0
    manuallySelectSystem(known[(current + direction + known.count) % known.count].id)
  }
  public mutating func selectSystem(x: Double, y: Double) {
    let selected =
      knownSystems.min { left, right in
        let ld = pow(Double(left.x - x), 2) + pow(Double(left.y - y), 2)
        let rd = pow(Double(right.x - x), 2) + pow(Double(right.y - y), 2)
        return ld < rd
      }?.id ?? selectedSystem
    manuallySelectSystem(selected)
  }
  public mutating func trade(buy: Bool) {
    var candidate = self
    do {
      try candidate.performMarketTrade(buy: buy, before: self)
      self = candidate
    } catch {
      notify(String(error.localizedDescription.prefix(512)))
    }
  }
  private mutating func performMarketTrade(buy: Bool, before: borrowing Game) throws {
    guard stationAllowsMarketServices, market.indices.contains(selection) else {
      if docked { notify("MARKET UNAVAILABLE AT THIS STATION") }
      return
    }
    let index = selection
    let item = market[index]
    let practice = try navigationTradeMarketAdmission(buying: buy, index: index)
    if buy {
      guard item.quantity > 0, commander.availableCredits >= item.price,
        commander.cargo[index] < Int.max / 17,
        Commodity.all[index].unit != "t" || commander.cargoTonnes < commander.tradeCargoCapacity
          || (practice != nil && commander.cargoTonnes == commander.tradeCargoCapacity)
      else {
        notify("CANNOT BUY")
        return
      }
      if !commander.unlimitedCash { commander.credits -= item.price }
      commander.cargo[index] += 1
      market[index].quantity -= 1
    } else {
      if index == 3, commander.sellableCargo(3) == 0, commander.nativeCaptiveCount > 0 {
        _ = reviewNativeCaptiveSale()
        return
      }
      guard commander.sellableCargo(index) > 0 || practice != nil,
        market[index].quantity < Int.max / 17
      else {
        notify(
          index == 10 && commander.markedFirearms > 0 ? "MISSION FIREARM RESERVED" : "NO CARGO")
        return
      }
      commander.credits = min(4_294_967_295, commander.credits + item.bidPrice)
      commander.cargo[index] -= 1
      market[index].quantity += 1
    }
    recordFirstNativeCommodityTrade(
      buying: buy, index: index,
      before: .init(stock: item.quantity, cargo: before.commander.cargo[index],
        credits: before.commander.credits), unitPrice: buy ? item.price : item.bidPrice)
    if let practice {
      try recordNavigationTradeMarket(instance: practice, buying: buy, before: before, index: index)
    }
    if !buy {
      recordFirstNativeCommoditySale(
        index: index,
        before: .init(
          stock: item.quantity, cargo: before.commander.cargo[index],
          credits: before.commander.credits),
        unitPrice: item.bidPrice, operation: UUID())
    }
  }
  public mutating func purchase() {
    if screen == .equipment, equipmentCrewSelected {
      openNativeCrewBoard()
      return
    }
    guard docked, Equipment.all.indices.contains(selection) else { return }
    _ = purchaseImmediately()
  }
  /// Sells the hold, then buys the most profitable exports for a destination.
  /// Government changes route risk, while commodity prices follow Elite's economy rules.
  public mutating func autoTrade() {
    guard !commander.hasActiveNavigationTrade else {
      notify("TRADE PRACTICE - USE SINGLE-TONNE MARKET CONTROLS")
      return
    }
    guard stationAllowsMarketServices else {
      if docked { notify("AUTO TRADE UNAVAILABLE AT THIS STATION") }
      return
    }
    let oldSelection = selection
    for index in commander.cargo.indices where commander.sellableCargo(index) > 0 {
      let beforeSale = NativeSaleBalance(
        stock: market[index].quantity, cargo: commander.cargo[index], credits: commander.credits)
      let beforeTrade = NativeCommodityTradeBalance(
        stock: market[index].quantity, cargo: commander.cargo[index], credits: commander.credits)
      let saleQuantity = min(commander.sellableCargo(index), Int.max / 17 - market[index].quantity)
      let (revenue, overflow) = saleQuantity.multipliedReportingOverflow(
        by: market[index].bidPrice)
      commander.credits =
        overflow
        ? 4_294_967_295 : min(4_294_967_295, commander.credits + min(revenue, 4_294_967_295))
      market[index].quantity += saleQuantity
      commander.cargo[index] -= saleQuantity
      recordFirstNativeCommoditySale(
        index: index, before: beforeSale, unitPrice: market[index].bidPrice, operation: UUID())
      recordFirstNativeCommodityTrade(
        buying: false, index: index, before: beforeTrade, unitPrice: market[index].bidPrice)
    }
    let refuelCost = refillCost
    if commander.unlimitedFuel {
      commander.fuel = commander.fuelCapacity
    } else if commander.availableCredits >= refuelCost {
      if !commander.unlimitedCash { commander.credits -= refuelCost }
      commander.fuel = commander.fuelCapacity
    } else {
      notify("INSUFFICIENT FUNDS FOR FULL FUEL")
      return
    }
    let routeDestination = commander.navigationPlan?.nextSystem
    if routeDestination == nil && selectedSystem == commander.system {
      let candidates = knownSystems.filter {
        $0.id != commander.system
          && currentSystem.distance(to: $0) <= commander.maximumJumpDistance
      }
      selectedSystem = candidates.max { routeScore($0) < routeScore($1) }?.id ?? commander.system
    }
    guard (routeDestination ?? selectedSystem) != commander.system else {
      notify("NO TRADE ROUTE")
      return
    }
    let destination = routeDestination.map { systems[$0] } ?? targetSystem
    let exports = profitableExports(to: destination)
    for item in exports {
      selection = item.index
      let unit = Commodity.all[item.index].unit
      let room = unit == "t" ? commander.tradeCargoCapacity - commander.cargoTonnes : 63
      let affordable =
        market[item.index].price > 0 ? commander.availableCredits / market[item.index].price : 63
      let count = max(0, min(room, min(affordable, market[item.index].quantity)))
      let beforeTrade = NativeCommodityTradeBalance(stock: market[item.index].quantity,
        cargo: commander.cargo[item.index], credits: commander.credits)
      if !commander.unlimitedCash { commander.credits -= count * market[item.index].price }
      commander.cargo[item.index] += count
      market[item.index].quantity -= count
      recordFirstNativeCommodityTrade(
        buying: true, index: item.index, before: beforeTrade, unitPrice: market[item.index].price)
    }
    selection = oldSelection
    notify("AUTO TRADE TO " + destination.name)
  }
  public func profitableExports(to destination: StarSystem) -> [(index: Int, profit: Int)] {
    Commodity.all.indices.compactMap { index in
      let lowestSale = MarketItem.minimumPrices(at: destination)[index]
      let profit = lowestSale - market[index].price
      return profit > 0 && market[index].quantity > 0 ? (index, profit) : nil
    }.sorted { $0.profit == $1.profit ? $0.index < $1.index : $0.profit > $1.profit }
  }
  private func routeScore(_ destination: StarSystem) -> Double {
    let exports = profitableExports(to: destination)
    let gross = exports.reduce(0.0) {
      $0 + Double($1.profit) * Double(min(commander.tradeCargoCapacity, market[$1.index].quantity))
    }
    let risk = destination.hostileFraction
    return gross / (1 + risk + currentSystem.distance(to: destination) * 0.05)
  }
  @inline(never)
  public mutating func launch() {
    guard nativeLaunchCrewIsReady(), nativeLaunchDockIsCurrent() else { return }
    var candidate = self
    do {
      try candidate.activateNativeStationWorld()
      try candidate.persistNativeStationConditions()
    } catch {
      notify("ORIGINAL STATION STATE UNAVAILABLE - LAUNCH REFUSED")
      return
    }
    if candidate.requiresScriptDurability, !candidate.recordCalendarLaunch(wasDocked: docked) {
      notify("CALENDAR LIMIT - LAUNCH NOT COMMITTED")
      return
    }
    do {
      try candidate.preflightActiveMissionProjectiles()
      try candidate.persistScriptActorsChecked(unloading: true)
      try candidate.performNativeLaunch()
    } catch is NativeStationRuntimeError {
      notify("STATION EXIT UNAVAILABLE - LAUNCH REFUSED")
      return
    } catch {
      paused = true
      notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
      return
    }
    guard candidate.nativeLaunchCommanderIsValid() else {
      notify("LAUNCH REFUSED")
      return
    }
    self = candidate
  }

  @inline(never)
  private mutating func nativeLaunchCrewIsReady() -> Bool {
    if docked, NativeCrewService.launchHullIDs.contains(commander.shipID) {
      guard commander.nativePeopleStateValid, let missing = commander.nativeCrewMissing else {
        notify("CREW LAYOUT OR CUSTODY UNAVAILABLE - LAUNCH REFUSED")
        return false
      }
      guard missing == 0 else {
        notify("CREW MISSING \(missing) - EQUIP SHIP > CREW")
        return false
      }
    }
    return true
  }

  @inline(never)
  private mutating func nativeLaunchDockIsCurrent() -> Bool {
    guard
      commander.nativeStations?.ledger.currentDock == nil
        || nativeStationDockEvidenceIsCurrent
    else {
      notify("STATION DOCKING CUSTODY UNAVAILABLE - LAUNCH REFUSED")
      return false
    }
    return true
  }

  @inline(never)
  private func nativeLaunchCommanderIsValid() -> Bool {
    commander.valid
  }

  @inline(never)
  private mutating func performNativeLaunch() throws {
    let stationReceipt = storedNativeStationWorld()?.ledger.currentDock
    let freshLaunchTrafficID = prepareNativeLaunchBodies()
    guard beginGameplayVisit(arriving: false, freshLaunchTrafficID: freshLaunchTrafficID) else {
      throw SaveError.invalidCommander
    }
    notifyNativeLaunch()
    preloadNavigation()
    retainPendingBlackjackEncounter()
    applyScriptStationResources()
    try registerOriginalNativeMainStation()
    if stationReceipt == nil { try offsetMovingMainStationDeparture() }
    try restoreScriptActors()
    if let stationReceipt { try launchFromNativeStation(stationReceipt) }
    commander.nativeStations?.currentMainDock = nil
  }

  @inline(never)
  private mutating func prepareNativeLaunchBodies() -> Int? {
    persistBlackjackTargets()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    cancelAutoTarget()
    clearManualResidualFlight()
    docked = false
    screen = .front
    screenHistory.removeAll()
    flightReturn = .front
    speed = 8
    dockingComputer = false
    bodies = [
      SpaceBody(id: 0, hull: .station, position: .init(0, 0, -500)),
      SpaceBody(id: 2, hull: .asteroid, position: .init(-280, 100, 2200)),
    ]
    // The new-visit traffic marker is resolved or removed before persistence.
    var freshLaunchTrafficID: Int?
    if commander.npcPersistence.count == 0,
      commander.savedEMPState?.records.values.contains(where: {
        $0.source.system == systemIdentity && $0.originalSpawn == nil && $0.originalBodyID == 1
      }) != true
    {
      bodies.insert(.init(id: 1, hull: .sidewinder, position: .init(90, 20, 1400)), at: 1)
      freshLaunchTrafficID = 1
    }
    commander.legal |= commander.cargo[3] + 2 * commander.cargo[6] + commander.cargo[10]
    resetCelestialFlight()
    return freshLaunchTrafficID
  }

  /// Retire the system-name snapshot before entering retained-actor restoration.
  @inline(never)
  private mutating func notifyNativeLaunch() {
    notify("LAUNCHING FROM " + currentSystem.name)
  }

  public mutating func dock(atMainStation: Bool = true) {
    dock(atMainStation: atMainStation, deferringNativeOffers: false)
  }

  /// Deferral changes event ordering only. Neither Boolean supplies native arrival authority.
  @inline(never)
  mutating func dock(atMainStation: Bool, deferringNativeOffers: Bool) {
    stationAutoDefence = nil
    do { try persistNativeStationConditions() } catch {
      notify("DOCKING DEFERRED: ORIGINAL STATION STATE UNAVAILABLE")
      return
    }
    resolveDestroyed()
    if atMainStation,
      commander.scriptState.stationResources[contractStation.key]?.destroyed == true
    {
      notify("MAIN STATION DESTROYED - DOCKING UNAVAILABLE")
      return
    }
    guard !hasUnsettledWreckDeaths else {
      notify("DOCKING DEFERRED: WRECK SETTLEMENT PENDING")
      return
    }
    guard !hasUnsettledCargoDeaths else {
      notify("DOCKING DEFERRED: CARGO SETTLEMENT PENDING")
      return
    }
    do { try prepareMeasuredDock() } catch {
      notify("DOCKING DEFERRED: EXTRACTION CUSTODY UNAVAILABLE")
      return
    }
    guard prepareDockPersistence() else { return }
    completeNativeDock(atMainStation: atMainStation, deferringNativeOffers: deferringNativeOffers)
  }

  @inline(never)
  private mutating func completeNativeDock(atMainStation: Bool, deferringNativeOffers: Bool) {
    do { try persistScriptActorsChecked(unloading: true) } catch {
      notify("ORIGINAL FREIGHTER STATE UNAVAILABLE - DOCKING DEFERRED", voiced: false)
      return
    }
    persistBlackjackTargets()
    if commander.npcPersistence.count > 0 {
      commander.npcPersistence.resetPhysicalBindings(system: systemIdentity)
    }
    commander.resetWantedCareerBindings(system: systemIdentity)
    commander.nativeStations?.currentMainDock = nil
    commander.nativeStations?.ledger.depart()
    dockedAtMainStation = atMainStation
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    cancelAutoTarget()
    clearManualResidualFlight()
    docked = true
    commander.savedEMPCharge = nil
    empPlayerElectricalInterval = nil
    screen = .status
    screenHistory.removeAll()
    speed = 0
    dockingComputer = false
    bodies = []
    energy = nativeStartupEnergy()
    frontShield = nativeStartupFrontShield()
    rearShield = nativeStartupRearShield()
    laserHeat = 0
    jumpCountdown = nil
    if requiresScriptDurability { cancelCalendarJourney() }
    missileArmed = false
    clearCelestialFlight()
    if !deferringNativeOffers { finishNativeDockOffers() }
  }

  mutating func finishNativeDockOffers() {
    notify("DOCKED")
    navigationDocked()
    if commander.autoTrade { autoTrade() }
    progressNavalMissions()
    reconcileEliteReward()
    if screen != .mission { _ = dispatchMission(.dock) }
    offerBlackjackHandoff()
  }
  /// Scene snapshots commit together; settled physical deaths precede this boundary.
  @inline(never)
  private mutating func prepareDockPersistence() -> Bool {
    if bodies.contains(where: { $0.physical?.currentNewtKitStock != nil }) {
      guard prepareCurrentNewtForActorRemoval(Set(bodies.compactMap { $0.physical?.identity }))
      else {
        notify("DOCKING DEFERRED: MECHANISM STATE UNAVAILABLE", voiced: false)
        return false
      }
    }
    // The real brake precedes the persistence snapshot. A failed writer retains
    // attained work and the stopped mechanism rather than restarting its rod.
    let snapshot = DockPersistenceSnapshot(self)
    var committed = false
    defer {
      if !committed { snapshot.restore(to: &self) }
    }
    guard persistNPCStates().isEmpty else {
      notify("DOCKING DEFERRED: NPC STATE UNAVAILABLE")
      return false
    }
    persistCargoPoses()
    persistOrePoses()
    guard persistSalvagePoses() else {
      notify("DOCKING DEFERRED: SALVAGE STATE UNAVAILABLE")
      return false
    }
    guard flushNativeSalvageMotion(parkingSystem: systemIdentity) else {
      notify("SALVAGE STATE UNAVAILABLE")
      return false
    }
    committed = true
    return true
  }
  public mutating func beginHyperspace() {
    if screen == .chart && !mapIsCurrentGalaxy {
      _ = prepareChartTravel()
      return
    }
    guard !docked, !playerEMPDisabled, jumpCountdown == nil else { return }
    guard prepareChartTravel(), selectedSystem != commander.system,
      knownSystems.contains(where: { $0.id == selectedSystem })
    else {
      return
    }
    let distance = currentSystem.distance(to: targetSystem)
    guard
      distance <= commander.maximumJumpDistance
    else {
      notify("FUEL TOO LOW")
      return
    }
    guard let drive = commander.hyperspaceDrivePolicy,
      commander.fittedComponent(at: .drive) != nil
    else {
      notify("FIT A HYPERSPACE DRIVE")
      return
    }
    guard !hyperspaceMassLocked else {
      notify("MASS LOCKED")
      return
    }
    var candidate = self
    if requiresScriptDurability {
      let debit = commander.jumpFuelCost(distance: distance)
      guard candidate.admitCalendarJourney(destination: targetSystem, nativeFuelDebit: debit),
        candidate.commander.valid
      else {
        notify("CALENDAR LIMIT - JUMP NOT ADMITTED")
        return
      }
    }
    switch drive.activation {
    case .timed(let seconds): candidate.jumpCountdown = seconds
    case .immediate:
      // The fitted recovered alien device uses the same fuel and arrival transaction.
      candidate.arrive()
      guard candidate.commander.system == selectedSystem, candidate.commander.valid else { return }
    }
    candidate.notify("HYPERSPACE")
    self = candidate
  }
  public var massLocked: Bool {
    bodies.contains { $0.hull != .cargo && $0.position.length < 600 }
      || celestials.contains { $0.position.length < $0.radius * 4 }
  }
  public mutating func arrive() {
    var candidate = self
    do {
      try candidate.preflightActiveMissionProjectiles()
      guard try candidate.performNativeArrival() else {
        jumpCountdown = candidate.jumpCountdown
        notify(candidate.message)
        return
      }
      guard candidate.commander.valid else { throw SaveError.invalidCommander }
    } catch {
      paused = true
      notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
      return
    }
    self = candidate
  }
  mutating func arriveThroughNativeWormhole(_ passage: NativeCommanderWormholePassage) throws
    -> Bool
  {
    guard passage.matches(self) else { throw NativeWormholeRefusal.stale }
    try preflightActiveMissionProjectiles()
    return try performNativeArrival(wormhole: passage)
  }
  private mutating func performNativeArrival(wormhole: NativeCommanderWormholePassage? = nil) throws
    -> Bool
  {
    try activateNativeStationWorld()
    try persistNativeStationConditions()
    resolveDestroyed()
    guard !hasUnsettledWreckDeaths else {
      jumpCountdown = nil
      notify("JUMP DEFERRED: WRECK SETTLEMENT PENDING")
      return false
    }
    guard persistSalvagePoses() else {
      jumpCountdown = nil
      notify("JUMP DEFERRED: SALVAGE STATE UNAVAILABLE")
      return false
    }
    persistOrePoses()
    let journey: ScriptCalendarJourney?
    if let wormhole {
      guard let admitted = completeWormholeCalendarJourney(wormhole) else { return false }
      journey = admitted
    } else {
      journey = requiresScriptDurability ? completeCalendarJourney() : nil
    }
    let destination = journey?.destination ?? selectedSystem
    guard flushNativeSalvageMotion(parkingSystem: systemIdentity) else { return false }
    try persistScriptActorsChecked(unloading: true)
    if destination != commander.system { try departOrdinarySimulation() }
    persistBlackjackTargets()
    retaliation.clear()
    weaponsTargetID = nil
    missileCooldown = 0
    spin.stop(immediate: true)
    let arrivalSpeed = min(commander.performance.speed, flightWorldVelocity.length / 18)
    cancelAutoTarget()
    clearManualResidualFlight()
    speed = arrivalSpeed
    let fuelBeforeArrival = commander.fuel
    let cost =
      journey?.nativeFuelDebit
      ?? commander.jumpFuelCost(distance: currentSystem.distance(to: targetSystem))
    if !commander.unlimitedFuel {
      commander.fuel = max(0, commander.fuel - cost)
    }
    commander.system = destination
    if wormhole != nil { selectedSystem = destination }
    if let plan = commander.navigationPlan, plan.nextSystem != commander.system {
      commander.navigationPlan = nil
      notify("ROUTE CANCELLED - OFF ROUTE")
    }
    jumpCountdown = nil
    screen = .front
    screenHistory.removeAll()
    flightReturn = .front
    dockingComputer = false
    bodies = [
      SpaceBody(id: 0, hull: .station, position: .init(0, 0, 16000)),
      SpaceBody(
        id: 1, hull: .sidewinder, position: .init(80, 0, 2600),
        hostile: currentSystem.government < 4),
    ]
    resetCelestialFlight()
    guard beginGameplayVisit(arriving: true, freshLaunchTrafficID: 1) else {
      throw SaveError.invalidCommander
    }
    if let wormhole, let journey, let player = commander.flightSimulation.player {
      // The adapter must have registered this actual native exit, never a guessed GPS pose.
      guard commander.flightSimulation.pose == wormhole.opening.route.exit else {
        throw NativeWormholeRefusal.worldUnavailable
      }
      let fuelAfter = commander.fuel
      commander.scriptState.wormholeTransit?.commanderPassages[wormhole.opening.id] = .init(
        opening: wormhole.opening.id, source: wormhole.player, arrival: player,
        calendarOperation: journey.operation, seconds: journey.seconds,
        fuelBefore: wormhole.fuelBefore, fuelAfter: fuelAfter, fuelDebit: wormhole.fuelDebit)
    }
    altitude = 1
    notify(currentSystem.name)
    retainPendingBlackjackEncounter()
    applyScriptStationResources()
    try registerOriginalNativeMainStation()
    try restoreScriptActors()
    try recordNavigationTradeJourney(journey, fuelBefore: fuelBeforeArrival)
    return true
  }
  public mutating func galacticJump() {
    guard !docked, !playerEMPDisabled, commander.equipment.contains("Galactic Hyperdrive") else {
      return
    }
    var candidate = self
    do {
      guard try candidate.performGalacticJump(), candidate.commander.valid else {
        notify(candidate.message)
        return
      }
      self = candidate
    } catch { notify("GALACTIC JUMP REFUSED") }
  }
  private mutating func performGalacticJump() throws -> Bool {
    resolveDestroyed()
    guard !hasUnsettledWreckDeaths else {
      notify("JUMP DEFERRED: WRECK SETTLEMENT PENDING")
      return false
    }
    guard persistSalvagePoses() else {
      notify("JUMP DEFERRED: SALVAGE STATE UNAVAILABLE")
      return false
    }
    guard try consumeNativeEquipment("Galactic Hyperdrive") else { return false }
    guard flushNativeSalvageMotion(parkingSystem: systemIdentity) else { return false }
    try persistScriptActorsChecked(unloading: true)
    mapSearch = PlanetSearchState()
    commander.navigationPlan = nil
    persistBlackjackTargets()
    try departOrdinarySimulation()
    bodies = []
    commander.galaxy = (commander.galaxy + 1) & 7
    if commander.system == Plugh.systemID { commander.system = Plugh.rumourStation }
    galacticBrowse = GalaxyBrowseState()
    systemInspection = nil
    systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
    selectedSystem = commander.system
    try preflightActiveMissionProjectiles()
    guard try performNativeArrival() else { return false }
    commander.fuel = commander.fuelCapacity
    return true
  }
  public mutating func inSystemJump() {
    guard !docked, !playerEMPDisabled, !massLocked else {
      notify("MASS LOCKED")
      return
    }
    let before = commander.flightSimulation.pose
    for index in bodies.indices { bodies[index].position.z -= 3000 }
    for index in celestials.indices { celestials[index].position.z -= 3000 }
    commander.flightSimulation.pose.advanceView(
      pitch: 0, roll: 0, yaw: 0, translation: .init(0, 0, 3000))
    advanceNativeMissionFrame(from: before, to: commander.flightSimulation.pose, delta: 0)
  }
  @discardableResult public mutating func fireMissile(retaliating: Bool = false) -> Bool {
    guard !docked, !playerEMPDisabled, missileArmed, missileCooldown == 0,
      commander.missiles > 0 || commander.unlimitedMissiles,
      let target = bodies.firstIndex(where: { body in
        (body.hull != .station || nativeStationBodyIsCurrent(body))
          && body.energy > 0 && body.position.z > 0
          && (weaponsTargetID == nil || body.id == weaponsTargetID)
      })
    else { return false }
    guard launchGameplayMissile(targetBodyID: bodies[target].id) else { return false }
    missileCooldown = 1
    notify("MISSILE AWAY", voiced: !retaliating)
    missileArmed = false
    return true
  }
  public mutating func ecm() {
    guard !docked, !playerEMPDisabled, commander.equipment.contains("E.C.M. System"),
      energy > ECMControl.activationEnergyCost,
      ecmFrames == 0
    else {
      return
    }
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player, activateOrdnanceECM(emitter: player)
    else { return }
    _ = ecmControl.detect(bodies)
    detectRetaliationSources()
    ecmControl.activate(destroyed: 0)
    for missile in bodies
    where missile.hull == .missile && missile.energy > 0 && missile.physical?.ordnance == nil
      && missile.scriptShot == nil
    {
      ecmControl.recordDestruction()
      confirmRetaliation(missile)
    }
    bodies.removeAll {
      $0.hull == .missile && $0.physical?.ordnance == nil && $0.scriptShot == nil
    }
    ecmFrames = 32
    enemyECMSource = nil
    energy -= ECMControl.activationEnergyCost
    advanceGameplayOrdnance(allowEnemyECM: false)
    notify("E.C.M.", voiced: false)
  }
  public mutating func energyBomb() {
    // Keep the existing weapon convention: a discharge must leave positive hull energy.
    // Physical bomb use remains available while the separate electrical reserve is disabled.
    let energyCost = 180.0
    guard !docked, energy.isFinite, energy > energyCost else { return }
    var candidate = self
    do {
      guard try candidate.consumeNativeEquipment("Energy Bomb") else { return }
      candidate.energy -= energyCost
      guard candidate.applyAttributedEnergyBomb(), candidate.commander.valid else { return }
      candidate.observeSafeGunneryDischarge()
      candidate.observeDefensiveFlightDischarge()
      candidate.notify("ENERGY BOMB")
      self = candidate
    } catch { notify("ENERGY BOMB REFUSED") }
  }
  public mutating func escapePod() {
    guard !docked, commander.equipment.contains("Escape Pod") else { return }
    guard !commander.accommodation.fittedBerths.contains(where: { $0.use.used }) else {
      notify("PASSENGERS CANNOT FIT THIS ESCAPE POD")
      return
    }
    var candidate = self
    let isolationPod = candidate.isolationProgrammerEscapePod()
    let measuredPod = candidate.measuredEscapePod()
    let recorderPod = candidate.recordRecoveryEscapePod()
    let originalPod = candidate.identifiedSalvageEscapePod()
    let surveyorPod = candidate.commander.fittedEquipment(at: .utility(.escapePod)).flatMap {
      fitted in
      try? candidate.commander.purchaseSnapshot().items.first(where: { $0.id == fitted.id })
    }
    do {
      guard try candidate.consumeNativeEquipment("Escape Pod") else { return }
      try candidate.loseIsolationProgrammerOnEscape(pod: isolationPod)
    } catch {
      notify("ESCAPE POD REFUSED")
      return
    }
    guard candidate.loseCourierPackagesOnEscape() else {
      notify("COURIER LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    guard candidate.loseFreightOnEscape() else {
      notify("FREIGHT LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    do {
      try candidate.closeUncollectedInductionClinicOnExit(.escapePod)
      try candidate.loseHeldInductionClinicOnExit(.escapePod)
      try candidate.loseInductionWorkshopOnExit(.escapePod)
      try candidate.closeUncollectedInductionSeedOnExit(.escapePod)
      try candidate.loseHeldInductionSeedOnExit(.escapePod)
      try candidate.loseC01SurveyorOnEscape(surveyorPod)
      try candidate.loseC01TimingStandardOnEscape(surveyorPod)
    } catch {
      notify("CLINIC RESERVATION LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    guard candidate.loseWayfarerColdChainOnEscape() else {
      notify("SAMPLE LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    do { _ = try candidate.loseWayfarerInductionCrate(.escapePod) } catch {
      notify("INDUCTION CRATE LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseNativeUtilityOnEscape() } catch {
      notify("UTILITY MATERIAL LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    guard candidate.loseWayfarerRepairLoopOnEscape() else {
      notify("REPAIR UNIT LOSS COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseMeasuredOnEscape(pod: measuredPod) } catch {
      notify("EXTRACTION LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseRecordRecoveryOnEscape(pod: recorderPod) } catch {
      notify("SENN RECORDER LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    do { try candidate.loseIdentifiedSalvageOnEscape(pod: originalPod) } catch {
      notify("PELL PROPERTY LOSS NOT SAVED - ESCAPE NOT COMMITTED")
      return
    }
    let leftPeople = !(candidate.commander.nativePeople?.held.isEmpty ?? true)
      || !candidate.commander.assignedNativeCrew.isEmpty
    do {
      try candidate.abandonNativePeopleOnEscape()
    } catch {
      notify("PEOPLE ABANDONMENT COULD NOT BE RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    // The existing successful escape transaction replaces the abandoned craft;
    // a pending charge and its disabled electrical reserve cannot follow it.
    candidate.commander.savedEMPCharge = nil
    candidate.commander.savedPlayerElectrical = nil
    candidate.loseNavigationTradeOnEscape()
    candidate.commander.cargo = Array(repeating: 0, count: 17)
    candidate.commander.cargo[10] = candidate.commander.markedFirearms
    candidate.commander.legal = 0
    candidate.commander.fuel = candidate.commander.fuelCapacity
    do {
      if candidate.activeFlightReception != nil { try candidate.finishFlightReception(.failed) }
    } catch {
      notify("PRACTICE LOSS NOT RECORDED - ESCAPE NOT COMMITTED")
      return
    }
    candidate.dock()
    guard candidate.docked, candidate.commander.valid else {
      notify(candidate.message)
      return
    }
    self = candidate
    if leftPeople { notify("ESCAPED - PEOPLE LEFT WITH ABANDONED SHIP") }
  }
  mutating func randomByte() -> Int {
    randomState = randomState &* 6_364_136_223_846_793_005 &+ 1
    return Int((randomState >> 32) & 255)
  }
  public mutating func tick(delta: Double, controls: Controls = Controls()) {
    tick(delta: delta, controls: controls, nativeSalvagePublish: nil)
  }

  var hasCurrentNewtNativeScene: Bool {
    bodies.contains {
      $0.physical?.currentNewtKitStock != nil || $0.physical?.currentNewtKitReceipt != nil
    }
  }

  @inline(never)
  mutating func tick(
    delta: Double, controls: Controls, nativeSalvagePublish: ScriptPublisher?,
    nativeClockProjection: CurrentNewtScriptClockProjection? = nil
  ) {
    // A failed Reris arrival publication retries its actual attained witness before more motion.
    guard pendingMemoryAtlasMainDock == nil else { return }
    guard admitC01InquiryGeometryAdvance() else { return }
    guard admitFlightWorkAdvance(controls: controls) else { return }
    pendingNativeSalvageCollections.removeAll(keepingCapacity: true)
    guard delta.isFinite, delta > 0 else { return }
    let dt = min(delta, 0.1)
    defer { closeDefensiveFlightIfNeeded() }
    if screen == .showroom {
      showroom.advance(delta: dt)
      return
    }
    if screen == .handoff {
      if !paused { packOfferElapsed += dt }
      return
    }
    if paused || screen == .help || screen == .gallery || screen == .library || screen == .journal
      || screen == .navigation
      || screen == .handoff || screen == .rumour
    {
      return
    }
    let nativeIntervals =
      !docked && screen != .mission
      && ![Screen.gameOver, .secret, .help, .title, .demo].contains(screen)
      && hasCurrentNewtNativeScene
    if !nativeIntervals { time += dt }
    if screen == .mission {
      missionElapsed += dt
      return
    }
    if screen == .demo && time >= 12 {
      screen = .title
      time = 0
    }
    if commander.unlimitedFuel { commander.fuel = commander.fuelCapacity }
    if !nativeIntervals {
      messageTime = max(0, messageTime - dt)
      laserFlash = max(0, laserFlash - dt)
    }
    guard !docked, ![Screen.gameOver, .secret, .help, .title, .demo].contains(screen) else {
      return
    }
    beginC03CrewFatalObservation()
    defer { endC03CrewFatalObservation() }
    approvedWorkMotion = nil
    lastAppliedWorkMotion = nil
    plannedLegacyWorkMotion.removeAll(keepingCapacity: true)
    workScenePlanned = false
    let defensiveFlightBefore = defensiveFlightObservation()
    let fireRequested = controls.fire
    let wasElectricalDisabled = playerEMPDisabled
    let c01MotionStartTime = commander.flightSimulation.physicalTime
    if nativeIntervals { ensurePhysicalActors() }
    beginEMPPlayerElectricalInterval(delta: dt)
    beginNativeOriginalUtilityFatalInterval(delta: dt)
    let c01InquiryOpening = prepareC01InquiryClockOpening(usedD: dt)
    if !nativeIntervals {
      commander.flightSimulation.advancePhysicalTime(dt)
      if let c01InquiryOpening {
        acceptC01InquiryClockWitness(
          .init(
            opening: c01InquiryOpening,
            observedEnd: commander.flightSimulation.physicalTime))
      }
    }
    let safeGunneryAudioBefore = (dischargeAudio.epoch, dischargeAudio.events.last?.id)
    var fireAdmitted = false
    if !nativeIntervals {
      advancePlayerElectrical()
      if wasElectricalDisabled != playerEMPDisabled { interruptFlightTool() }
      fireAdmitted = admitFlightFire(held: fireRequested)
    }
    let controls = playerEMPDisabled ? Controls() : controls
    gameplayRevision &+= 1
    ensurePhysicalActors()
    beginSafeGunneryIfNeeded()
    beginDefensiveFlightIfNeeded()
    defer { closeFailedSafeGunneryIfNeeded() }
    applyFlightFrameControls(delta: dt, controls: controls)
    if !nativeIntervals {
      advanceFlightFrameActions(
        delta: dt, fireAdmitted: fireAdmitted,
        nativeSalvagePublish: nativeSalvagePublish)
    }
    var newtBirths: CurrentNewtEndBirths?
    if !nativeIntervals {
      let present = Set(bodies.compactMap { $0.physical?.identity })
      advanceGameplayEncounters(delta: dt)
      newtBirths = .init(game: self, previouslyPresent: present)
    }
    if !nativeIntervals { planWorkScene(delta: dt) }
    advanceWorkGuidance(delta: dt, deferThrustDebit: nativeIntervals, bornAtEnd: newtBirths)
    let workCameraStart = commander.flightSimulation.pose
    let usedWorkCamera = workGuidance != nil || workBraking != nil
    if nativeIntervals {
      guard advanceNativeTickBodyMotion(delta: dt, c01MotionStartTime: c01MotionStartTime,
        workCameraStart: workCameraStart, c01InquiryOpening: c01InquiryOpening,
        wasElectricalDisabled: wasElectricalDisabled, fireRequested: fireRequested,
        fireAdmitted: &fireAdmitted, nativeSalvagePublish: nativeSalvagePublish,
        nativeClockProjection: nativeClockProjection) else { return }
    } else {
      moveBodies(
        dt: dt, c01MotionStartTime: c01MotionStartTime,
        newtBirthActors: newtBirths?.actors ?? [], newtBirths: newtBirths)
    }
    finishMovedFlightTick(
      dt: dt, nativeIntervals: nativeIntervals, usedWorkCamera: usedWorkCamera,
      workCameraStart: workCameraStart, fireAdmitted: fireAdmitted,
      nativeSalvagePublish: nativeSalvagePublish, safeGunneryAudioBefore: safeGunneryAudioBefore,
      defensiveFlightBefore: defensiveFlightBefore)
  }

  @inline(never)
  private mutating func advanceNativeTickBodyMotion(
    delta dt: Double, c01MotionStartTime: Double, workCameraStart: ShipPose,
    c01InquiryOpening: NativeC01InquiryClockOpening?, wasElectricalDisabled: Bool,
    fireRequested: Bool, fireAdmitted: inout Bool, nativeSalvagePublish: ScriptPublisher?,
    nativeClockProjection: CurrentNewtScriptClockProjection?
  ) -> Bool {
    nativeC01TimingStandardPending = nil
    guard let path = prepareCurrentNewtOuterMotion(delta: dt) else {
      paused = true
      notify("NATIVE MOTION UNAVAILABLE - PAUSED", voiced: false)
      return false
    }
    // Install actual original-source routing once, before the native path reads its opening.
    _ = prepareC03FreighterRoutePass(delta: dt)
    guard let npcFrame = prepareCurrentNewtNPCFrame(path) else {
      paused = true
      notify("FLIGHT PAUSED - NPC MOTION UNAVAILABLE", voiced: false)
      return false
    }
    let timingFrame = glassMeridianMission?.savedGlassMeridian?.timingStandard.flatMap {
      beginC01TimingStandardObservation(
        state: $0, delta: dt,
        startTime: c01MotionStartTime, nativePath: path)
    }
    let interval = advanceCurrentNewtNativeInterval(path, npcFrame: npcFrame)
    let attained = commander.flightSimulation.physicalTime - c01MotionStartTime
    _ = nativeClockProjection?.apply(attained: attained, to: &self)
    time += attained
    messageTime = max(0, messageTime - attained)
    laserFlash = max(0, laserFlash - attained)
    finishCurrentNewtOuterMotion(path, attained: interval.fullMotionAttained)
    guard let evidence = interval.evidence else {
      if screen == .gameOver { return false }
      starfield.advance(from: workCameraStart, to: commander.flightSimulation.pose)
      paused = true
      notify("NATIVE CONTACT UNPROVEN - PAUSED", voiced: false)
      return false
    }
    if let c01InquiryOpening {
      acceptCurrentNewtC01Clock(opening: c01InquiryOpening, evidence: evidence)
    }
    if screen == .gameOver { return false }
    guard evidence.completedOuterInterval else {
      starfield.advance(from: workCameraStart, to: commander.flightSimulation.pose)
      paused = true
      notify("NATIVE CONTACT UNPROVEN - PAUSED AT ATTAINED PREFIX", voiced: false)
      return false
    }
    if let timingFrame, let state = glassMeridianMission?.savedGlassMeridian?.timingStandard {
      nativeC01TimingStandardPending = sealC01TimingStandardCapture(
        timingFrame, state: state, nativeEvidence: evidence)
    }
    let retainedActors = Set(bodies.compactMap { $0.physical?.identity })
    advancePlayerElectrical()
    if wasElectricalDisabled != playerEMPDisabled { interruptFlightTool() }
    fireAdmitted = admitFlightFire(held: fireRequested)
    guard screen != .gameOver else { return false }
    advanceFlightFrameActions(
      delta: dt, fireAdmitted: fireAdmitted,
      nativeSalvagePublish: nativeSalvagePublish)
    guard nativeStationRuntimeEpoch == path.epoch, !docked else { return false }
    advanceGameplayEncounters(delta: dt)
    let births = CurrentNewtEndBirths(game: self, previouslyPresent: retainedActors)
    moveBodies(
      dt: dt, c01MotionStartTime: c01MotionStartTime,
      nativeMotion: evidence, nativeStart: path.motion.start,
      newtBirthActors: births.actors, newtBirths: births, npcFrame: evidence.npcFrame)
    nativeC03ClockEvidence = evidence
    return true
  }

  @inline(never)
  private mutating func applyFlightFrameControls(delta dt: Double, controls: Controls) {
    let craft = nativeFramePerformance()
    if !manualResidualFlight && workGuidance == nil && workBraking == nil {
      speed = ManualFlightThrottleKernel.cruise(
        speed: speed, throttle: controls.throttle, delta: dt,
        acceleration: craft.acceleration, maximum: craft.speed)
    }
    pitch = controls.pitch * craft.pitch
    yaw = controls.yaw * craft.yaw
    let previousSpinRate = spin.actualRate
    if !playerEMPDisabled { spin.advance(delta: dt, controls: controls) }
    roll =
      spin.mode || spin.actualRate != 0 || previousSpinRate != 0
      ? (previousSpinRate + spin.actualRate) * .pi / 360 : controls.roll * craft.roll
    if !playerEMPDisabled { applyAutoTarget(delta: dt, controls: controls) }
    applyManualResidualThrottle(delta: dt, throttle: controls.throttle)
  }

  @inline(never)
  private mutating func finishMovedFlightTick(
    dt: Double, nativeIntervals: Bool, usedWorkCamera: Bool, workCameraStart: ShipPose,
    fireAdmitted: Bool, nativeSalvagePublish: ScriptPublisher?,
    safeGunneryAudioBefore: (UUID, UInt64?),
    defensiveFlightBefore: NativeDefensiveFlightObservation?
  ) {
    if paused || pendingMemoryAtlasMainDock != nil { return }
    if docked {
      stationAutoDefence = nil
      reconcileEliteReward()
      return
    }
    advanceSolarFlight(delta: dt)
    guard screen != .gameOver else { return }
    scoopCargo()
    if !workScenePlanned && missionLoopCounter & 7 == 0 { navalTactics() }
    detectIncomingMissiles()
    advanceNavalMissiles(delta: nativeIntervals ? 0 : dt)
    ecmControl.advance(delta: dt)
    if ecmFrames == 0 {
      enemyECMSource = nil
      activeECMActivation = nil
    }
    advanceRetaliation()
    if usedWorkCamera || nativeIntervals {
      starfield.advance(from: workCameraStart, to: commander.flightSimulation.pose)
    } else {
      starfield.advance(
        delta: dt, speed: speed, pitch: pitch, roll: roll, yaw: yaw, translation: autoPilot.velocity
      )
    }
    let beforeEMPEvent = dischargeAudio.events.last?.id
    advanceEMPCharge(
      triggerHeld: fireAdmitted && !workFireSuspended && selectedFlightTool == .empPirateBlaster,
      publish: nativeSalvagePublish)
    if selectedFlightTool == .empPirateBlaster,
      dischargeAudio.events.last?.id != beforeEMPEvent,
      dischargeAudio.events.last?.tool == .empPirateBlaster
    {
      selectedToolActivity = .init(
        tool: .empPirateBlaster, physicalTime: commander.flightSimulation.physicalTime)
    }
    resolveDestroyed()
    persistBlackjackTargets()
    advanceSafeGunnery(
      delta: dt,
      discharged: safeGunneryAudioBefore.0 != dischargeAudio.epoch
        || safeGunneryAudioBefore.1 != dischargeAudio.events.last?.id)
    if let id = weaponsTargetID, !bodies.contains(where: { $0.id == id && $0.energy > 0 }) {
      weaponsTargetID = nil
      notify("WEAPON LOCK LOST")
    }
    reconcileEliteReward()
    missionLoopCounter &-= 1
    if missionLoopCounter == 0 { spawnNavalEncounter() }
    if energy <= 0 {
      spin.stop(immediate: true)
      screen = .gameOver
      notify("GAME OVER")
    } else if energy < commander.performance.energy / 4 && messageTime <= 0 {
      notify("ENERGY LOW,SIR")
    }
    if screen != .gameOver { advanceMissionClock(dt) }
    if safeGunneryAudioBefore.0 != dischargeAudio.epoch
      || safeGunneryAudioBefore.1 != dischargeAudio.events.last?.id
    {
      observeDefensiveFlightDischarge()
    }
    advanceDefensiveFlight(before: defensiveFlightBefore, delta: dt)
  }
  @inline(never)
  private mutating func advanceFlightFrameActions(
    delta dt: Double, fireAdmitted: Bool, nativeSalvagePublish: ScriptPublisher?
  ) {
    rechargeFlightFrameResources(delta: dt)
    if fireAdmitted && screen.isFlight {
      fireSelectedFlightTool(delta: dt, nativeSalvagePublish: nativeSalvagePublish)
    } else {
      fireStationAutoLaser()
    }
    if let remaining = jumpCountdown {
      jumpCountdown = remaining - dt
      if remaining <= dt { arrive() }
    }
  }

  @inline(never)
  private mutating func rechargeFlightFrameResources(delta dt: Double) {
    let craft = nativeFramePerformance()
    laserHeat = max(0, laserHeat - dt * 12)
    fireCooldown = max(0, fireCooldown - dt)
    missileCooldown = max(0, missileCooldown - dt)
    energy = min(craft.energy, energy + dt * craft.recharge * nativeFrameEnergyRecharge())
    frontShield = min(nativeStartupFrontShield(), frontShield + dt * nativeFrameFrontRecharge())
    rearShield = min(nativeStartupRearShield(), rearShield + dt * nativeFrameRearRecharge())
  }

  mutating func acceptCurrentNewtC01Clock(
    opening: NativeC01InquiryClockOpening, evidence: CurrentNewtNativeClockEvidence
  ) {
    guard let opening = attainedC01InquiryClockOpening(opening, usedD: evidence.attainedDuration)
    else { return }
    acceptC01InquiryClockWitness(
      .init(
        opening: opening,
        observedEnd: commander.flightSimulation.physicalTime, nativeMotion: evidence))
  }

  public func viewPosition(_ p: Vector3) -> Vector3 {
    Self.viewPosition(p, screen: screen)
  }
  static func viewPosition(_ p: Vector3, screen: Screen) -> Vector3 {
    switch screen {
    case .rear: return .init(-p.x, p.y, -p.z)
    case .left: return .init(p.z, p.y, -p.x)
    case .right: return .init(-p.z, p.y, p.x)
    default: return p
    }
  }
  @inline(never)
  private mutating func moveBodies(
    dt: Double, c01MotionStartTime: Double,
    nativeMotion: CurrentNewtNativeClockEvidence? = nil, nativeStart: ShipPose? = nil,
    newtBirthActors: Set<ActorIdentity> = [], newtBirths: CurrentNewtEndBirths? = nil,
    npcFrame: CurrentNewtNPCFrame? = nil
  ) {
    guard admitMovedNewtEndpoint(dt: dt, nativeMotion: nativeMotion, newtBirths: newtBirths) else { return }
    let asteroidContactFrame =
      nativeMotion == nil
      ? beginAsteroidContactStep(delta: dt, excluding: newtBirthActors) : nil
    if nativeMotion == nil { nativeC01TimingStandardPending = nil }
    let timingStandardFrame = beginMovedBodyTimingObservation(
      dt: dt, c01MotionStartTime: c01MotionStartTime, nativeMotion: nativeMotion, newtBirths: newtBirths)
    let before = nativeStart ?? commander.flightSimulation.pose
    if nativeMotion == nil {
      let c03UsedWorkFrame = moveWorkFrame(delta: dt, bornAtEnd: newtBirthActors)
      if !c03UsedWorkFrame {
        moveManualCameraBodies(dt: dt, before: before, newtBirthActors: newtBirthActors)
      }
      if nativeC03MotionPending != nil {
        captureC03CameraStep(.init(game: self, before: before, delta: dt, work: c03UsedWorkFrame))
      }
    }
    // Native paths require their own applied-phase representation; missing captures refuse.
    finishMovedBodyContacts(dt: dt, before: before, asteroidContactFrame: asteroidContactFrame,
      timingStandardFrame: timingStandardFrame, nativeMotion: nativeMotion, npcFrame: npcFrame,
      newtBirths: newtBirths, newtBirthActors: newtBirthActors)
  }

  @inline(never)
  private mutating func finishMovedBodyContacts(
    dt: Double, before: ShipPose, asteroidContactFrame: AsteroidContactFrame?,
    timingStandardFrame: NativeC01TimingStandardFrame?, nativeMotion: CurrentNewtNativeClockEvidence?,
    npcFrame: CurrentNewtNPCFrame?, newtBirths: CurrentNewtEndBirths?, newtBirthActors: Set<ActorIdentity>
  ) {
    guard
      nativeMotion != nil || completeAsteroidContactStep(asteroidContactFrame, delta: dt).admitted
    else { return }
    advanceNativeStationRecharge(delta: dt)
    detectNativeStationEntry(from: before, delta: dt)
    if pendingNativeStationDock != nil {
      advanceNativeMissionFrame(from: before, to: commander.flightSimulation.pose, delta: dt)
      return
    }
    collideWithNativeStationStructures(from: before, delta: dt)
    if let station = bodies.first(where: { $0.id == 0 && $0.hull == .station }),
      station.containsPlayer
    {
      if station.canEnter(roll: roll, speed: nativeStationRelativeEntrySpeed(station)),
        nativeMainStationHullCourseIsClear(
          station, from: before, to: commander.flightSimulation.pose, delta: dt)
      {
        dockAtOriginalNativeMainStation(station, from: before, delta: dt)
        return
      }
      stopAtStationImpact(at: before)
      applyDamage(dt * 100, front: true)
      if message != "DOCKING COLLISION" || messageTime <= 0 { notify("DOCKING COLLISION") }
    }
    finishMovedBodies(
      dt: dt, before: before, timingStandardFrame: timingStandardFrame,
      nativeMotion: nativeMotion, npcFrame: npcFrame,
      newtBirths: newtBirths, newtBirthActors: newtBirthActors)
  }

  @inline(never)
  private mutating func moveManualCameraBodies(dt: Double, before: ShipPose, newtBirthActors: Set<ActorIdentity>) {
    autoPilot.rotateVelocity(pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
    commander.flightSimulation.pose.advanceView(
      pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt,
      translation: autoPilot.velocity * dt + Vector3(0, 0, speed * dt * 18))
    rotateScriptNPCVelocities(from: before, to: commander.flightSimulation.pose)
    moveCelestials(delta: dt)
    for index in bodies.indices {
      bodies[index].position = bodies[index].position.rotated(
        pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
      bodies[index].orientation.rotate(pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
      bodies[index].position = bodies[index].position - autoPilot.velocity * dt
      bodies[index].position.z -= speed * dt * 18
      if let actor = bodies[index].physical?.identity, newtBirthActors.contains(actor) {
        // Its genuine admission occurred at T1. Only the camera changes;
        // there is no preceding self-motion or model spin to consume.
        continue
      }
      advanceBodyModelRotation(at: index, delta: dt)
      advanceCanonicalModelSpin(at: index, delta: dt)
      advanceSpawnedBodyVelocity(index: index, dt: dt)
      if bodies[index].hostile && bodies[index].energy > 0,
        bodies[index].physical?.spawnIdentity == nil, !workScenePlanned,
        bodies[index].missionInstanceID == nil
      {
        enemyAction(index: index, dt: dt)
      }
    }
  }

  @inline(never)
  private mutating func advanceSpawnedBodyVelocity(index: Int, dt: Double) {
    if let physical = bodies[index].physical, physical.spawnIdentity != nil,
      physical.ordnance == nil, bodies[index].scriptShot == nil,
      bodies[index].scriptNPC == nil || c01SurveyorActor(bodies[index]) != nil
        || c01TimingStandardPart(bodies[index]) != nil
        || c01LaneRepairTarget(bodies[index]) != nil
        || c01ClinicCradleDeclared(bodies[index])
    {
      bodies[index].position =
        bodies[index].position
        + commander.flightSimulation.pose.shipVector(physical.velocity) * dt
    }
  }

  @inline(never)
  private mutating func beginMovedBodyTimingObservation(
    dt: Double, c01MotionStartTime: Double, nativeMotion: CurrentNewtNativeClockEvidence?,
    newtBirths: CurrentNewtEndBirths?
  ) -> NativeC01TimingStandardFrame? {
    let timingStandardState = glassMeridianMission?.savedGlassMeridian?.timingStandard
    let timingStandardFrame =
      nativeMotion == nil
      ? timingStandardState.flatMap {
        beginC01TimingStandardObservation(
          state: $0, delta: dt, startTime: c01MotionStartTime,
          bornAtEnd: newtBirths)
      } : nil
    return timingStandardFrame
  }

  @inline(never)
  private mutating func admitMovedNewtEndpoint(
    dt: Double, nativeMotion: CurrentNewtNativeClockEvidence?, newtBirths: CurrentNewtEndBirths?
  ) -> Bool {
    if nativeMotion == nil, let newtBirths, !newtBirths.actors.isEmpty,
      workGuidance == nil, workBraking == nil
    {
      // A real T1 admission has no preceding trajectory. Manual flight must
      // still prove clearance at its endpoint with the same component query
      // and shared budget as work and the timing-standard observer.
      var pilot = autoPilot
      pilot.rotateVelocity(pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt)
      let start = commander.flightSimulation.pose
      var end = start
      end.advanceView(
        pitch: pitch * dt, roll: roll * dt, yaw: yaw * dt,
        translation: pilot.velocity * dt + Vector3(0, 0, speed * dt * 18))
      guard let radius = commander.playerMesh.vertices.map(\.length).max() else {
        nativeEncounterBirthDiagnostic?.recordEndpointRefusal(
          "stage=player-radius radius=nil duration=\(dt) start=\(start) end=\(end)"
            + " actorsTotal=\(newtBirths.actors.count)"
            + " actorsRetained=\(Array(newtBirths.actors.prefix(32)))")
        paused = true
        notify("NEW CONTACT AT FLIGHT ENDPOINT - PAUSED", voiced: false)
        return false
      }
      guard let motion = debrisRigidMotion(from: start, to: end, duration: dt, radius: radius)
      else {
        nativeEncounterBirthDiagnostic?.recordEndpointRefusal(
          "stage=rigid-motion radius=\(radius) duration=\(dt) start=\(start) end=\(end)"
            + " actorsTotal=\(newtBirths.actors.count)"
            + " actorsRetained=\(Array(newtBirths.actors.prefix(32)))")
        paused = true
        notify("NEW CONTACT AT FLIGHT ENDPOINT - PAUSED", voiced: false)
        return false
      }
      guard workBirthEndpointIsClear(motion, bornAtEnd: newtBirths) else {
        paused = true
        notify("NEW CONTACT AT FLIGHT ENDPOINT - PAUSED", voiced: false)
        return false
      }
    }
    return true
  }

  @inline(never)
  private mutating func finishMovedBodies(
    dt: Double, before: ShipPose, timingStandardFrame: NativeC01TimingStandardFrame?,
    nativeMotion: CurrentNewtNativeClockEvidence?, npcFrame: CurrentNewtNPCFrame?,
    newtBirths: CurrentNewtEndBirths?, newtBirthActors: Set<ActorIdentity>
  ) {
    // Motion observers receive only the endpoint retained by physical collision handling.
    if let timingStandardFrame, let state = glassMeridianMission?.savedGlassMeridian?.timingStandard
    {
      nativeC01TimingStandardPending = sealC01TimingStandardCapture(
        timingStandardFrame, state: state)
    }
    advanceNativeMissionFrame(from: before, to: commander.flightSimulation.pose, delta: dt)
    // An existing ordinary moving actor currently refuses native preflight
    // until its one prepared path is supplied. T1 births receive no earlier
    // movement, recharge, projectile age or weapon cooldown from this tail.
    let lateDelta = nativeMotion == nil ? dt : 0
    if let npcFrame,
      !commitCurrentNewtNPCDecisions(
        npcFrame,
        evidence: nativeMotion, admittedAtEnd: newtBirths)
    {
      paused = true
      notify("FLIGHT PAUSED - NPC STATE CHANGED", voiced: false)
      return
    }
    advanceScriptNPCFlight(
      delta: lateDelta, excluding: Set(npcFrame?.entries.keys.map { $0 } ?? []),
      prepareC03Routes: npcFrame == nil)
    synchronizeScriptNPCPhysicalVelocities()
    let weaponBirths =
      npcFrame.map {
        Set(bodies.compactMap { $0.physical?.identity }).subtracting($0.openingActors)
      } ?? newtBirthActors
    advanceScriptNPCWeapons(delta: dt, bornAtEnd: weaponBirths)
    advanceScriptNPCShots(delta: lateDelta)
    persistBlackjackTargets()
    persistCargoPoses()
    persistOrePoses()
    guard persistSalvagePoses(cold: false) else {
      if message != "SALVAGE STATE UNAVAILABLE" || messageTime <= 0 {
        notify("SALVAGE STATE UNAVAILABLE")
      }
      return
    }
    let refusedC03 = persistScriptActors()
    let retainedNPCs = persistNPCStates()
    guard persistEMPState() else { return }
    let departingActors = Set(
      bodies.filter {
        $0.energy > 0 && $0.leavesLocalBubble && $0.id != 0 && !retainedNPCs.contains($0.id)
        && !refusedC03.contains($0.id)
      }.compactMap { $0.physical?.identity })
    if !departingActors.isEmpty,
      bodies.contains(where: { $0.physical?.currentNewtKitStock != nil })
    {
      guard prepareCurrentNewtForActorRemoval(departingActors), persistEMPState() else {
        notify("MECHANISM STATE UNAVAILABLE - CULL DEFERRED", voiced: false)
        return
      }
    }
    // Recapture bodies after the actual brake; the departing projections and
    // native wreck flush must retain its new velocity and finite spent work.
    let departing = bodies.filter {
      $0.energy > 0 && $0.leavesLocalBubble && $0.id != 0 && !retainedNPCs.contains($0.id)
        && !refusedC03.contains($0.id)
    }
    // Ordinary traffic/projectile culls must not replay native lifetime history.
    let nativePending = commander.alienStorageState?.current.salvage.pending
    let nativeDeparting = Set(
      departing.compactMap { body -> ActorIdentity? in
        guard let physical = body.physical, let payload = physical.payload,
          case .salvage(let identity) = payload,
          nativePending?[identity]?.binding == physical.identity
        else { return nil }
        return physical.identity
      })
    let nativeWreckDeparting = Set(
      departing.compactMap { body -> ActorIdentity? in
        guard let physical = body.physical, physical.payload == nil,
          let wreck = physical.salvage?.wreck,
          commander.alienStorageState?.current.salvage.native.wrecks[wreck]?.binding
            == physical.identity
        else { return nil }
        return physical.identity
      })
    if !nativeWreckDeparting.isEmpty {
      guard flushNativeSalvageWrecks(parking: nativeWreckDeparting) else {
        notify("SALVAGE STATE UNAVAILABLE")
        return
      }
    }
    if !nativeDeparting.isEmpty {
      guard flushNativeSalvageMotion(parking: nativeDeparting) else {
        notify("SALVAGE STATE UNAVAILABLE")
        return
      }
    }
    for body in departing {
      if var ordnance = body.physical?.ordnance {
        endOrdnance(bodyID: body.id, state: &ordnance, reason: .culled)
      }
      if let actor = body.physical?.identity {
        commander.miningLedger.cull(actor: actor)
        commander.cargoDebrisLedger.cull(actor: actor)
        commander.salvageLedger.cull(actor: actor)
        commander.npcPersistence.cull(actor: actor)
      }
      clearRemovedTarget(body)
      missionTargetRemoved(body)
      blackjackTargetDestroyed(body)
      recordScriptActorRemoval(body, destroyed: false)
    }
    bodies.removeAll {
      $0.energy > 0 && $0.leavesLocalBubble && $0.id != 0 && !retainedNPCs.contains($0.id)
        && !refusedC03.contains($0.id)
    }
  }
  @inline(never)
  mutating func enemyAction(index: Int, dt: Double) {
    guard !isEMPDisabled(bodies[index]), bodies[index].physical?.empCrewPod == nil else { return }
    let priorPosition = storedFlightSimulation().pose.systemPoint(bodies[index].position)
    if bodies[index].blackjackRole != nil {
      advanceBlackjackNPC(index: index, delta: dt)
      return
    }
    // The legacy hostile projection alone cannot authorize pursuit of the current player.
    guard legacyNPCPlayerEffectSourceIsCurrent(index: index) else { return }
    moveEligibleLegacyEnemy(index: index, dt: dt, priorPosition: priorPosition)
    applyLegacyNPCFlightEffects(index: index, delta: dt)
  }

  @inline(never)
  private mutating func moveEligibleLegacyEnemy(index: Int, dt: Double, priorPosition: Vector3) {
    if let maximumSpeed = bodies[index].nativeNavalCombat?.speed {
      let distance = bodies[index].position.length
      if distance > 0 {
        bodies[index].position =
          bodies[index].position * max(0, 1 - maximumSpeed * 18 * dt / distance)
      }
    } else {
      bodies[index].position.x *= 1 - dt * 0.25
      bodies[index].position.y *= 1 - dt * 0.25
      if bodies[index].position.z > 300 { bodies[index].position.z -= dt * 60 }
    }
    if dt > 0 {
      let worldVelocity =
        (storedFlightSimulation().pose.systemPoint(bodies[index].position) - priorPosition)
        * (1 / dt)
      bodies[index].physical?.velocity = worldVelocity
    }
  }
  mutating func resolveDestroyed() {
    do { try persistNativeStationConditions() } catch {
      notify("ORIGINAL STATION LIFECYCLE UNAVAILABLE - SETTLEMENT DEFERRED", voiced: false)
      return
    }
    let refusedC03 = persistC03ActorsPreservingRefusals()
    var initial = bodies.filter { $0.energy <= 0 && !refusedC03.contains($0.id) }
    if !initial.isEmpty { ensurePhysicalActors() }
    if !initial.isEmpty,
      bodies.contains(where: { $0.physical?.currentNewtKitStock != nil })
    {
      guard prepareCurrentNewtForActorRemoval(Set(initial.compactMap { $0.physical?.identity }))
      else {
        notify("MECHANISM STATE UNAVAILABLE - DESTRUCTION SETTLEMENT DEFERRED", voiced: false)
        return
      }
      initial = bodies.filter { $0.energy <= 0 && !refusedC03.contains($0.id) }
    }
    for body in initial { settleLegacyCombatDeath(body) }
    var deferred = registerDestroyedCargo()
    deferred.formUnion(refusedC03)
    deferred.formUnion(registerDestroyedWrecks())
    deferred.formUnion(registerDestroyedNativeSalvage())
    guard registerEMPHullDeaths() else {
      notify("EMP CUSTODY SETTLEMENT DEFERRED")
      return
    }
    deferred.formUnion(prepareC01InquiryDestroyedRemoval())
    let destroyed = bodies.filter { $0.energy <= 0 && !deferred.contains($0.id) }
    for body in destroyed {
      observeMeasuredOreDeath(body)
      if let payload = body.physical?.payload {
        _ = commander.miningLedger.destroy(payload: payload)
        _ = commander.cargoDebrisLedger.destroy(
          payload: payload, protection: gameplayContext()?.protection)
        if case .salvage(let lot) = payload, let context = gameplayContext(),
          commander.alienStorageState?.current.salvage.sections.contains(lot.section) != true
        {
          _ = commander.salvageLedger.destroy(lot: lot, protection: context.protection)
        }
      }
      if let actor = body.physical?.identity {
        guard retireRecoveredEMPActor(actor, reason: .destroyed) else { continue }
        _ = commander.npcPersistence.terminal(actor: actor, reason: .destroyed)
      }
      missionTargetRemoved(body)
      clearRemovedTarget(body)
      blackjackTargetDestroyed(body)
      recordScriptActorRemoval(body, destroyed: true)
    }
    bodies.removeAll { $0.energy <= 0 && !deferred.contains($0.id) }
    if !bodies.contains(where: { $0.hull == .thargoid }) {
      for index in bodies.indices where bodies[index].hull == .thargon {
        bodies[index].hostile = false
        bodies[index].ecmEnabled = false
      }
    }
  }

}

public enum SaveError: Error { case invalidCommander }

/// Owns all mutable simulation state. Rendering consumes value snapshots only.
public actor GameRuntime {
  var game: Game
  var controls = Controls()
  var assemblyCalibrationControls = NativeAssemblySurveyInstrumentControls()
  var assemblyCapacityEditor: NativeAssemblyCapacityEditorSession?
  var c03ArchiveReaderUI: NativeC03ArchiveReaderUI?
  var galleryNamespace: URL?
  var galleryParent: GalleryParentState?
  var scriptSaveURL: URL?
  var nativePeopleFailureGate: NativePeopleFailureGate?
  var scriptRefusalDiagnostic: ScriptRefusalDiagnostic?
  public init(game: Game = Game(), saveURL: URL? = nil) {
    var prepared = game
    prepared.c01InquiryStepRuntime = .init()
    prepared.invalidateNativeStationAuthority()
    prepared.stationAutoDefence = nil
    prepared.gameplayCombatTrace = nil
    prepared.flightTrigger = .init()
    prepared.selectedToolActivity = nil
    prepared.inventoryContextEpoch = .init()
    if (try? prepared.commander.prepareEquipment()) != nil {
      prepared.commander.mirrorFittedEquipment()
      self.game = prepared
    } else {
      self.game = prepared
    }
    if self.game.requiresScriptDurability {
      let missingCalendar = self.game.commander.scriptState.calendarLedger == nil
      self.game.ensureScriptCalendar(
        origin: game.jumpCountdown == nil ? .newCommander : .inactiveLegacyMigration)
      if missingCalendar, game.jumpCountdown != nil {
        self.game.commander.scriptState.calendarLedger?.legacyUntrackedJourney = true
      }
    }
    if game.isMissionTrial {
      let namespace = Self.newGalleryNamespace()
      galleryNamespace = namespace
      scriptSaveURL = namespace.appendingPathComponent("commander.json")
      self.game.scriptDurabilityAvailable = true
    } else {
      self.game.scriptDurabilityAvailable = saveURL != nil
      scriptSaveURL = saveURL
    }
  }
  init(trialGame: Game) throws {
    let namespace = Self.newGalleryNamespace()
    let target = namespace.appendingPathComponent("commander.json")
    var candidate = trialGame
    candidate.c01InquiryStepRuntime = .init()
    candidate.invalidateNativeStationAuthority()
    try candidate.commander.prepareEquipment()
    candidate.inventoryContextEpoch = .init()
    candidate.ensureScriptCalendar(origin: .newCommander)
    candidate.scriptDurabilityAvailable = true
    candidate.isMissionTrial = true
    try Self.writeCommander(&candidate, to: target)
    game = candidate
    galleryNamespace = namespace
    scriptSaveURL = target
  }
  func invalidateInventoryContext() { game.inventoryContextEpoch = .init() }
  public func inventoryCommand(_ command: InventoryCommand) -> Bool {
    equipmentTransaction(.inventory(command)).applied
  }
  public func snapshot() -> Game {
    game.prepareFlightWeaponDisplay()
    refreshAssemblyCalibrationProjection()
    refreshAssemblyCapacityEditorProjection()
    refreshC03ArchiveReaderProjection()
    return game
  }
  public func key(_ key: String) {
    if handleAssemblyCapacityEditorKey(key) { return }
    if rejectUnprovedC03ArchiveReaderKey(key) { return }
    if key == MissionUIAction.originalSealConsent.rawValue {
      openHollowManifestConsentReview()
      return
    }
    if handleHollowManifestConsentKey(key) { return }
    if handleHollowManifestWakeKey(key) { return }
    if handleHollowManifestRegisterKey(key) { return }
    if galleryAction(key) { return }
    keyAfterGallery(key)
  }
  private func keyAfterGallery(_ key: String) {
    // Safety input survives a refused candidate command because it precedes its rollback snapshot.
    game.prepareIsolationWorkSafetyKey(key)
    let stopsTool = game.flightKeyStopsTool(key)
    if game.prepareFlightControlKey(key) {
      controls.fire = false
      return
    }
    if stopsTool { controls.fire = false }
    game.resolveCourierTerminals(publish: scriptPublisher())
    game.resolveFreightTerminals(
      publish: scriptPublisher(diagnosticBoundary: .resolver), diagnostics: scriptRefusalDiagnostic)
    let before = game
    let held = controls
    applyKey(key)
    game.resolveCourierTerminals()
    game.resolveFreightTerminals(diagnostics: scriptRefusalDiagnostic)
    game.scriptDurabilityAvailable = scriptSaveURL != nil
    if before.screen == .gameOver, [" ", "return"].contains(key) {
      game.scriptPacks = before.scriptPacks
      game.missionPacks = before.missionPacks
      game.pendingNewSaveDestination = before.pendingNewSaveDestination
      game.newCommanderSaveReceipt = before.newCommanderSaveReceipt
    }
    do { try commitScriptCommand(from: before) } catch {
      game = before
      controls = held
      game.notify("MISSION SAVE FAILED - ACTION NOT COMMITTED")
    }
  }
  private func applyKey(_ key: String) {
    let prior = keyTransitionState()
    if handleScriptContactKey(key) {
      controls = Controls()
      return
    }
    if !handleEquipmentKey(key) { applyPlainGameKey(key) }
    finishKeyTransition(
      key, old: prior.screen, wasPaused: prior.paused, wasDocked: prior.docked,
      oldLocation: (prior.galaxy, prior.system))
  }
  // Read buffers finish before command phases can enter deeper native transactions.
  private func keyTransitionState() -> (
    screen: Screen, paused: Bool, docked: Bool, galaxy: Int, system: Int
  ) {
    let old = game.screen
    let wasPaused = game.paused
    let wasDocked = game.docked
    let oldLocation = (game.commander.galaxy, game.commander.system)
    return (old, wasPaused, wasDocked, oldLocation.0, oldLocation.1)
  }
  private func handleScriptContactKey(_ key: String) -> Bool {
    if key == "contacts-open" || (key == "b" && !game.acceptsTextInput), game.docked, !game.paused,
      ![
        Screen.help, .gallery, .library, .journal, .handoff, .mission, .showroom, .title, .demo, .gameOver,
        .secret, .navigation, .rumour,
      ].contains(game.screen)
    {
      game.emitScriptEvent("contact.requested")
      if game.showScriptDialogue() || game.offerAvailableScriptMission() {
        return true
      }
    }
    return false
  }
  private func handleEquipmentKey(_ key: String) -> Bool {
    if game.passengerBerthSelected, ["s", "r"].contains(key.lowercased()) {
      guard scriptSaveURL != nil else {
        game.notify("CABIN FITTING REQUIRES A SAVE LOCATION")
        return true
      }
      if let intent = game.equipmentPurchaseContext?.passengerBerthFitting(
        fitted: key.lowercased() == "r")
      {
        _ = game.performEquipmentMutation(.passengerBerth(intent))
      }
      return true
    }
    guard key.lowercased() == "return", let context = game.equipmentPurchaseContext else {
      return false
    }
    if game.passengerBerthSelected {
      guard scriptSaveURL != nil else {
        game.notify("CABIN PURCHASE REQUIRES A SAVE LOCATION")
        return true
      }
    }
    _ = game.performEquipmentMutation(.purchase(context))
    // A refused attempt still consumes Return; the original route never fell through.
    return true
  }
  private func applyPlainGameKey(_ key: String) {
    game.key(key)
  }
  private func finishKeyTransition(
    _ key: String, old: Screen, wasPaused: Bool, wasDocked: Bool, oldLocation: (Int, Int)
  ) {
    if old != game.screen || wasPaused != game.paused { invalidateInventoryContext() }
    if old == .handoff, game.screen == .contracts { game.refreshContractRows() }
    game.observeScriptLocation(wasDocked: wasDocked, galaxy: oldLocation.0, system: oldLocation.1)
    if key.lowercased() == "tab", game.screen.isFlight, game.autoPilot.targetID != nil {
      controls.pitch = 0
      controls.yaw = 0
      controls.roll = 0
      if game.dockingComputer { controls = Controls() }
    }
    if old != game.screen || key == "pause"
      || [.gallery, .library, .journal, .handoff, .showroom].contains(game.screen)
    {
      controls = Controls()
    }
  }
  public func blackjackHandoffClick(x: Double, y: Double) {
    nativeCommand { $0.blackjackHandoffClick(x: x, y: y) }
  }
  public func secretClick(x: Double, y: Double) { nativeCommand { $0.secretClick(x: x, y: y) } }
  public func showroomClick(x: Double, y: Double) { nativeCommand { $0.showroomClick(x: x, y: y) } }
  public func marketClick(x: Double, y: Double) { nativeCommand { $0.marketClick(x: x, y: y) } }
  public func equipmentClick(y: Double, x: Double? = nil) {
    nativeCommand { $0.equipmentClick(y: y, x: x) }
  }
  public func mapClick(x: Double, y: Double) { game.mapClick(x: x, y: y) }
  public func galleryClick(x: Double, y: Double) { campaignGalleryClick(x: x, y: y) }
  public func setControls(_ value: Controls, expectedEpoch: UUID? = nil) {
    controls = expectedEpoch == nil || expectedEpoch == game.ecmControl.epoch ? value : Controls()
    game.observeFlightFire(held: controls.fire)
  }
  public func setViewport(width: Double, height: Double) {
    guard width.isFinite, height.isFinite, width > 0, height > 0 else { return }
    game.viewportWidth = width
    game.viewportHeight = height
  }
  public func selectSystem(x: Double, y: Double) { game.selectSystem(x: x, y: y) }
  @inline(never)
  public func advance(delta: Double) -> Game {
    // Retry the attained entry before preparing clocks or any new physical work.
    if game.pendingMemoryAtlasMainDock != nil {
      _ = commitPendingMemoryAtlasMainStationEntry()
      return snapshot()
    }
    guard game.admitC01InquiryGeometryAdvance() else { return snapshot() }
    guard game.admitFlightWorkAdvance(controls: controls) else { return snapshot() }
    game.pendingNativeSalvageCollections.removeAll(keepingCapacity: true)
    game.nativeCrimboAttainedMotion = nil
    game.nativeCrimboMotionSample = nil
    let utilityWorkStart = game.inductionUtilityEndpoint()
    let isolationWorkStart = game.isolationWorkSample()
    let c01LaneStart = game.c01LaneRepairEndpoint()
    guard let context = prepareAdvance(delta: delta) else {
      game.advanceInductionUtilityWork(from: nil, publish: scriptPublisher())
      game.advanceIsolationWork(from: nil, publish: scriptPublisher())
      game.advanceC01LaneRepairWork(from: nil, publish: scriptPublisher())
      return snapshot()
    }
    return advancePreparedFrame(
      delta: delta, context: context, utilityWorkStart: utilityWorkStart, c01LaneStart: c01LaneStart,
      isolationWorkStart: isolationWorkStart)
  }

  @inline(never)
  private func advancePreparedFrame(
    delta: Double, context: AdvanceContext, utilityWorkStart: NativeInductionUtilityEndpoint?,
    c01LaneStart: NativeC01LaneRepairEndpoint?, isolationWorkStart: NativeIsolationWorkSample?
  ) -> Game {
    if game.pendingMemoryAtlasMainDock != nil {
      _ = commitPendingMemoryAtlasMainStationEntry()
      return snapshot()
    }
    game.c01ClinicEscortRuntime.attainedSample = game.c01ClinicAttainedSample()
    let observations = PreparedFrameObservations(game: game)
    game.nativeC03ClockEvidence = nil
    game.beginC03AttainedMotionStep()
    beginAssemblyCalibrationMotion()
    game.tick(
      delta: delta, controls: controls,
      nativeSalvagePublish: scriptPublisher(requireNativeSalvage: true),
      nativeClockProjection: context.nativeClockProjection)
    return finishPreparedFrame(
      delta: delta, context: context, utilityWorkStart: utilityWorkStart,
      c01LaneStart: c01LaneStart, isolationWorkStart: isolationWorkStart,
      observations: observations)
  }

  // These exact pre-tick samples survive physical motion; commit-only locals do not.
  private final class PreparedFrameObservations {
    let glassMeridianStart: NativeOriginalSurveySample?
    let flightReceptionStart: NativeFlightReceptionSample?
    let outlookStart: NativeOrbitalOutlookSample?
    let surveyStart: NativeOriginalSurveySample?
    let recordStart: WayfarerRecordRecoveryObservation?
    let committedRecordIdentification: UUID?
    let salvageStart: Double
    let salvagePlayer: ActorIdentity?
    let hollowInspectionStart: NativeHollowManifestInspectionSample?

    @inline(never)
    init(game: borrowing Game) {
      glassMeridianStart = game.glassMeridianSample()
      flightReceptionStart = game.flightReceptionSample()
      outlookStart = game.orbitalOutlookSample()
      surveyStart = game.originalSurveySample()
      recordStart = game.recordRecoveryIdentificationSample()
      committedRecordIdentification = game.recordRecoveryState?.identification?.operation
      salvageStart = game.commander.flightSimulation.physicalTime
      salvagePlayer = game.commander.flightSimulation.player
      hollowInspectionStart = game.hollowManifestInspectionSample()
    }
  }

  @inline(never)
  private func finishPreparedFrame(
    delta: Double, context: AdvanceContext, utilityWorkStart: NativeInductionUtilityEndpoint?,
    c01LaneStart: NativeC01LaneRepairEndpoint?, isolationWorkStart: NativeIsolationWorkSample?,
    observations: PreparedFrameObservations
  ) -> Game {
    var context = context
    let glassMeridianStart = observations.glassMeridianStart
    let flightReceptionStart = observations.flightReceptionStart
    let outlookStart = observations.outlookStart
    let surveyStart = observations.surveyStart
    let recordStart = observations.recordStart
    let committedRecordIdentification = observations.committedRecordIdentification
    let salvageStart = observations.salvageStart
    let salvagePlayer = observations.salvagePlayer
    let attained = game.commander.flightSimulation.physicalTime - context.startPhysicalTime
    if context.nativeClockDeferred {
      context.clockAdvanced = context.nativeClockProjection != nil && attained > 0
    }
    game.consumeC01InquiryAttainedClockStep()
    if game.pendingMemoryAtlasMainDock != nil && !commitPendingMemoryAtlasMainStationEntry() {
      return snapshot()
    }
    commitC01InquiryOperatorHostLoss()
    commitIsolationProgrammerFatalLoss()
    commitNativeSalvageCollections()
    commitMeasuredExtraction()
    commitRecordRecoveryLoss()
    commitIdentifiedSalvageLoss()
    commitIdentifiedSalvageCapture(startTime: salvageStart, startPlayer: salvagePlayer)
    commitRecordRecoveryCapture(
      startTime: salvageStart, startPlayer: salvagePlayer,
      committedIdentification: committedRecordIdentification)
    commitInductionCrewLogCapture(startTime: salvageStart, startPlayer: salvagePlayer)
    commitRecordRecoveryIdentification(start: recordStart)
    let stationEntryAttempted = game.pendingNativeStationDock != nil
    commitPendingNativeStationEntry()
    if game.docked { game.stationAutoDefence = nil }
    commitGlassMeridianScan(start: glassMeridianStart)
    commitGlassMeridianBeacons()
    game.observeC01ClinicFatalTransitions(from: game.c01ClinicEscortRuntime.attainedSample)
    commitC01Surveyor(startTime: salvageStart, startPlayer: salvagePlayer)
    commitC01TimingStandard()
    commitC01ClinicEscort()
    commitFlightReception(start: flightReceptionStart)
    commitOrbitalOutlookScan(start: outlookStart)
    commitOriginalSurveyScan(start: surveyStart)
    finishAdvance(
      delta: context.nativeClockDeferred ? attained : delta,
      context: context, stationEntryAttempted: stationEntryAttempted,
      hollowInspectionStart: observations.hollowInspectionStart)
    game.advanceInductionUtilityWork(from: utilityWorkStart, publish: scriptPublisher())
    game.advanceIsolationWork(from: isolationWorkStart, publish: scriptPublisher())
    game.advanceC01LaneRepairWork(from: c01LaneStart, publish: scriptPublisher())
    game.finishEMPPlayerElectricalInterval(publish: scriptPublisher(requireNativeSalvage: true))
    finishC01InquiryAttainedFrame()
    finishAssemblyCalibrationMotion()
    return snapshot()
  }
  private typealias AdvanceContext = (
    wasDocked: Bool, wasLive: Bool, location: (Int, Int), localActive: Bool, flightActive: Bool,
    calendarActive: Bool, clockAdvanced: Bool, startPhysicalTime: Double,
    startPlayer: ActorIdentity?, transitSample: NativeWormholeMotionSample?,
    startTransitSeconds: Double, nativeClockDeferred: Bool,
    nativeClockProjection: CurrentNewtScriptClockProjection?
  )
  // Release preflight/read buffers before entering the deeper physical simulation.
  @inline(never)
  private func prepareAdvance(delta: Double) -> AdvanceContext? {
    let wasDocked = game.docked
    let wasLive = game.screen != .gameOver
    let startPhysicalTime = game.commander.flightSimulation.physicalTime
    let startPlayer = game.commander.flightSimulation.player
    let location = (game.commander.galaxy, game.commander.system)
    let localActive =
      !game.paused
      && ![Screen.demo, .title, .gameOver, .gallery, .library, .journal, .help, .navigation].contains(
        game.screen)
    let flightActive =
      localActive && !game.docked
      && ![Screen.mission, .handoff, .rumour, .showroom, .secret].contains(game.screen)
    if localActive && !game.docked {
      do { try game.preflightActiveMissionProjectiles() } catch {
        controls = Controls()
        game.paused = true
        game.notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
        return nil
      }
    }
    // Projectile restoration must admit the frame before automatic ammunition can publish.
    // Publish before advancing clocks or exposing the candidate projectile to physics.
    advanceStationAutoMissile(delta: delta)
    return completeAdvancePreparation(
      delta: delta, wasDocked: wasDocked, wasLive: wasLive,
      startPhysicalTime: startPhysicalTime, startPlayer: startPlayer, location: location,
      localActive: localActive, flightActive: flightActive)
  }

  @inline(never)
  private func completeAdvancePreparation(
    delta: Double, wasDocked: Bool, wasLive: Bool, startPhysicalTime: Double,
    startPlayer: ActorIdentity?, location: (Int, Int), localActive: Bool, flightActive: Bool
  ) -> AdvanceContext {
    // Physical facts commit first. A failed script save must never undo a real hit/death.
    let calendarActive = game.calendarActive
    let nativeClockDeferred = flightActive && game.hasCurrentNewtNativeScene
    let nativeClockProjection =
      nativeClockDeferred
      ? CurrentNewtScriptClockProjection(
        game: game, flight: flightActive, local: localActive,
        calendar: calendarActive) : nil
    game.scriptEventsDeferred = true
    let clockAdvanced =
      !nativeClockDeferred && game.requiresScriptDurability
      && game.advanceScriptClockValues(
        delta: delta, flight: flightActive, local: localActive, calendar: calendarActive,
        missionCalendar: game.missionCalendarActive)
    return (
      wasDocked, wasLive, location, localActive, flightActive, calendarActive, clockAdvanced,
      startPhysicalTime, startPlayer,
      flightActive
        && (game.hasNativeWormholeMotionObservers || game.hasInductionArkMotionObserver
          || game.hasInductionRescueMotionObserver)
        ? NativeWormholeMotionSample(game) : nil,
      game.commander.scriptState.transitSeconds, nativeClockDeferred, nativeClockProjection
    )
  }
  // Reserve later event/restoration buffers only after the physical tick and native entry.
  private func finishAdvance(
    delta: Double, context: AdvanceContext, stationEntryAttempted: Bool,
    hollowInspectionStart: NativeHollowManifestInspectionSample?
  ) {
    let (
      wasDocked, wasLive, location, localActive, flightActive, calendarActive, clockAdvanced,
      startPhysicalTime, startPlayer, transitSample, startTransitSeconds, _, _
    ) =
      context
    if wasLive && game.screen == .gameOver {
      if game.energy.isFinite && game.energy < 0 { game.energy = 0 }
      game.markCourierFatalLoss()
      game.markFreightFatalLoss()
      commitNativePeopleLoss()
    }
    // Acts only on the measured fatal state; retries its durable proposal after writer refusal.
    commitWayfarerInductionCrateLoss()
    commitWayfarerColdChainFatalLoss()
    commitInductionClinicUncollectedLoss()
    commitInductionClinicHeldFatalLoss()
    commitInductionWorkshopLoss()
    commitInductionSeedUncollectedLoss()
    commitInductionSeedHeldFatalLoss()
    commitWayfarerRepairLoopFatalLoss()
    commitNativeUtilityFatalLoss()
    commitFieldReliefTargetLoss()
    commitMeasuredExtraction()
    commitRecordRecoveryLoss()
    commitIdentifiedSalvageLoss()
    game.observeC01ClinicFatalTransitions(from: game.c01ClinicEscortRuntime.attainedSample)
    commitC01Surveyor(startTime: startPhysicalTime, startPlayer: startPlayer)
    commitC01TimingStandard()
    commitC01ClinicEscort()
    game.observeSelectedFleetDiscovery()
    game.observeNativeCrimboAttainedMotion(
      delta: delta, flightWasActive: wasLive && !wasDocked && localActive && flightActive,
      startTime: startPhysicalTime, startPlayer: startPlayer,
      stationEntryAttempted: stationEntryAttempted)
    if wasLive && localActive && flightActive && !stationEntryAttempted {
      commitNativePeopleCapture(
        startTime: startPhysicalTime, startPlayer: startPlayer, delta: delta)
    }
    game.resolveCourierTerminals(publish: scriptPublisher())
    game.resolveFreightTerminals(
      publish: scriptPublisher(diagnosticBoundary: .resolver), diagnostics: scriptRefusalDiagnostic)
    game.observeScriptLocation(wasDocked: wasDocked, galaxy: location.0, system: location.1)
    game.scriptEventsDeferred = false
    if localActive && !game.docked {
      do {
        try game.persistScriptActorsChecked()
        try game.restoreScriptActors()
      } catch {
        // Earlier physical effects stay committed. The restore operation's own
        // all-record preflight prevents partial actor/projectile publication.
        // Refused persistence cannot leave an attainable C03 frame observation.
        game.nativeC03MotionPending = nil
        game.nativeC03AttainedMotion = nil
        game.nativeC03ClockEvidence = nil
        controls = Controls()
        game.paused = true
        game.notify("MISSION FLIGHT RESTORE REFUSED - PAUSED", voiced: false)
        return
      }
    }
    game.finishC03AttainedMotionStep(native: game.nativeC03ClockEvidence)
    game.nativeC03ClockEvidence = nil
    commitHollowManifestInspection(from: hollowInspectionStart)
    if wasLive && !wasDocked && localActive && flightActive && !stationEntryAttempted {
      receiveHollowManifestConsentAfterPhysics(
        delta: delta, startTime: startPhysicalTime, startPlayer: startPlayer)
    }
    if localActive {
      game.advanceNativeWormholeFrame(from: transitSample, publish: scriptPublisher())
      game.drainScriptEvents(publish: scriptPublisher())
    }
    if clockAdvanced {
      game.fireDueScriptTimers(
        flight: flightActive, local: localActive, calendar: calendarActive,
        transit: game.commander.scriptState.transitSeconds > startTransitSeconds,
        publish: scriptPublisher())
    }
    if localActive {
      game.advanceInductionArk(from: transitSample, publish: scriptPublisher())
      game.advanceInductionCrewLog(publish: scriptPublisher())
      game.advanceInductionUtilitySource(publish: scriptPublisher())
      game.advanceInductionRescueFlight(from: transitSample, publish: scriptPublisher())
    }
    game.advanceScriptWorldJobs(delta: delta, publish: scriptPublisher())
  }
  public func save(to url: URL) throws {
    try requireGalleryFileAccess(url)
    var candidate = game
    candidate.resolveCourierTerminals()
    candidate.resolveFreightTerminals()
    try BisonUnitJournalSave.validatePreservation(from: game, to: candidate)
    try Self.writeCommander(&candidate, to: url)
    game = candidate
    scriptSaveURL = url
    game.stationAutoDefence?.missilePublicationRefused = false
    game.stationAutoDefence?.saveBinding = url
    nativePeopleFailureGate = nil
    game.scriptDurabilityAvailable = true
  }

  /// Immutable per-publication ownership, never serialized or reused as validation authority.
  final class NativeSavePreparation: Sendable {
    private let gameValue: Game
    private let commanderValue: Commander
    var game: Game { _read { yield gameValue } }
    var commander: Commander { _read { yield commanderValue } }
    init(game: consuming Game, commander: consuming Commander) {
      gameValue = consume game
      commanderValue = consume commander
    }
  }

  /// Shared native persistence barrier before either ordinary JSON or Script chunks.
  /// The returned live Game keeps bindings; only the disk Commander clears them.
  static func prepareNativeSaveState(
    _ value: Game, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication
  ) throws -> NativeSavePreparation {
    var candidate = value
    var stage = ScriptRefusalStage.nativePeople
    var operation = 0
    do {
      operation = 1
      try candidate.recordFlightReceptionFailureIfNeeded()
      operation = 2
      _ = try candidate.applyGlassMeridianPending()
      operation = 3
      _ = try candidate.applyFlightReceptionPending()
      operation = 4
      try candidate.recordNativePeopleLossIfNeeded()
      candidate.stageMeasuredHullLoss()
      operation = 5
      try candidate.applyMeasuredPending()
      operation = 6
      _ = try candidate.recordRecoveryLossIfNeeded()
      operation = 7
      _ = try candidate.recordIdentifiedSalvageLossIfNeeded()
      operation = 8
      try candidate.retryRecordRecoveryIdentification()
      operation = 9
      try candidate.retryRecordRecoveryCapture()
      operation = 10
      try candidate.retryInductionCrewLogCapture()
      operation = 11
      try candidate.retryIdentifiedSalvageCapture()
      stage = .nativeDock
      operation = 12
      try validateNativeDockEvidenceForSave(&candidate)
      stage = .nativeStations
      operation = 13
      try candidate.persistNativeStationConditions()
      operation = 14
      try candidate.failFieldReliefAtDestroyedTarget()
      stage = .equipment
      operation = 15
      try candidate.commander.prepareEquipment()
      candidate.commander.mirrorFittedEquipment()
      stage = .nativeDestruction
      candidate.resolveDestroyed()
      operation = 16
      try candidate.recordFlightReceptionFailureIfNeeded()
      candidate.stageMeasuredHullLoss()
      operation = 17
      try candidate.applyMeasuredPending()
      operation = 18
      _ = try candidate.recordRecoveryLossIfNeeded()
      operation = 19
      _ = try candidate.recordIdentifiedSalvageLossIfNeeded()
      operation = 20
      try BisonUnitJournalSave.validatePreservation(from: value, to: candidate)
      operation = 21
      return try finishNativeSaveState(
        &candidate, diagnostics: diagnostics, diagnosticBoundary: diagnosticBoundary)
    } catch {
      diagnostics?.record(
        diagnosticBoundary, .init(stage: stage, error: error, game: candidate, count: operation))
      throw error
    }
  }

  private static func validateNativeDockEvidenceForSave(_ candidate: inout Game) throws {
    guard candidate.pendingMemoryAtlasMainDock == nil,
      candidate.commander.nativeStations?.ledger.currentDock == nil
        || candidate.nativeStationDockEvidenceIsCurrent,
      candidate.commander.nativeStations?.currentMainDock == nil
        || candidate.nativeMainStationDockEvidenceIsCurrent
    else { throw SaveError.invalidCommander }
  }

  /// Comparison projection only. Do not settle unrelated pending effects or
  /// invoke a publisher while validating C01 birth application storage.
  static func validateC01InquiryPrivateBirthCandidate(
    _ value: borrowing Game, navigationBinding: ScriptNavigationTradeBinding? = nil
  ) throws {
    var persisted = value.commander
    clearNativeSaveBindings(&persisted, system: value.systemIdentity)
    try ScriptSaveStore.validateC01InquiryPrivateBirthCandidate(commander: persisted,
      world: value.scriptWorldSave, scope: value.isMissionTrial ? "gallery" : "commander",
      navigationBinding: navigationBinding)
  }

  /// Disk commanders omit only current scene bindings; live load candidates restore them.
  private static func clearNativeSaveBindings(
    _ commander: inout Commander, system: SystemIdentity
  ) {
    if commander.npcPersistence.count > 0 {
      commander.npcPersistence.resetPhysicalBindings(system: system)
    }
    commander.resetWantedCareerBindings(system: system)
  }

  /// Keep the comparison copy out of the live load frame. All semantic facts still compare.
  @inline(never)
  private static func nativeCommanderNeedsRepublishing(
    _ candidate: borrowing Game, persisted: borrowing Commander
  ) -> Bool {
    var projected = candidate.commander
    clearNativeSaveBindings(&projected, system: candidate.systemIdentity)
    return projected != persisted
  }

  private static func finishNativeSaveState(
    _ candidate: inout Game, diagnostics: ScriptRefusalDiagnostic? = nil,
    diagnosticBoundary: ScriptRefusalBoundary = .publication
  ) throws -> NativeSavePreparation {
    candidate.persistCargoPoses()
    candidate.persistOrePoses()
    guard candidate.persistSalvagePoses() else {
      diagnostics?.record(
        diagnosticBoundary,
        .init(stage: .salvagePoses, error: SaveError.invalidCommander, game: candidate))
      throw SaveError.invalidCommander
    }
    candidate.persistBlackjackTargets()
    let refusedNPCs = candidate.persistNPCStates()
    do { try candidate.captureC01InquiryCurrentLife() } catch {
      diagnostics?.record(
        diagnosticBoundary,
        .init(stage: .nativeSaveValidation, error: error, game: candidate, count: -1))
      throw error
    }
    guard refusedNPCs.isEmpty, !candidate.hasUnsettledWreckDeaths, candidate.commander.valid,
      !candidate.bodies.contains(where: {
        $0.energy <= 0 && $0.hull.isTargetShip && $0.physical?.npc != nil
          && $0.physical?.npc?.role != .mission
      })
    else {
      if let diagnostics, !diagnostics.contains(diagnosticBoundary) {
        // Bits 1/2/4/8: no NPC refusals, no unsettled wreck, commander valid, no dead ordinary NPC.
        let npcCheck: UInt16 = refusedNPCs.isEmpty ? 1 : 0
        let wreckCheck: UInt16 = !candidate.hasUnsettledWreckDeaths ? 2 : 0
        let commanderCheck: UInt16 = candidate.commander.valid ? 4 : 0
        let ordinaryNPCCheck: UInt16 =
          !candidate.bodies.contains(where: {
            $0.energy <= 0 && $0.hull.isTargetShip && $0.physical?.npc != nil
              && $0.physical?.npc?.role != .mission
          }) ? 8 : 0
        let checks: UInt16 = npcCheck | wreckCheck | commanderCheck | ordinaryNPCCheck
        diagnostics.record(
          diagnosticBoundary,
          .init(
            stage: .nativeSaveValidation, error: SaveError.invalidCommander, game: candidate,
            checks: checks, count: refusedNPCs.count))
      }
      throw SaveError.invalidCommander
    }
    var persistedCommander = candidate.commander
    clearNativeSaveBindings(&persistedCommander, system: candidate.systemIdentity)
    return NativeSavePreparation(game: copy candidate, commander: consume persistedCommander)
  }

  public func restoreStartup(from url: URL) throws {
    try load(from: url, persistMigrations: false)
    if game.requiresScriptDurability {
      game.scriptStartupTime = game.time
    }
    game.screen = .title
    game.time = 0
  }
  public func load(from url: URL, persistMigrations: Bool = true) throws {
    try loadNativeCommander(from: url, persistMigrations: persistMigrations, navigationBinding: nil)
    resetAssemblyCalibration()
  }
  func loadNativeCommander(
    from url: URL, persistMigrations: Bool, navigationBinding: ScriptNavigationTradeBinding?
  ) throws {
    try requireGalleryFileAccess(url)
    let data = try CommanderSaveInput.read(from: url)
    try ScriptSaveJSONPreflight.validate(data)
    try CurrentNewtKitSave.validateFields(data, location: .commander, schema: nil)
    try BisonUnitJournalSave.validateFields(data, location: .pointer)
    // A malformed pointer must not turn a misplaced native inquiry into a raw-Commander fallback.
    try NativeMemoryAtlasWatcherEnvelope.validateFields(data, location: .commander, schema: nil)
    _ = try NativeC01InquirySave.validateFields(data, location: .commander, schema: nil)
    try NativeIsolationWorkParentSave.validateFields(data, part: .commander)
    try NativeIsolationWorkSave.validateFields(data, part: .commander)
    try NativeBorrowedVoiceSave.validateFields(data, part: .commander)
    try NativeTitheCommissionSave.validateFields(data, part: .commander)
    try NativeQuietChoirSave.validateFields(data, part: .commander)
    try NativeMemoryAtlasSave.validateFields(data, part: .commander)
    try NativeSignedPassageOpeningSave.validateFields(data, part: .commander)
    try NativePublicRecordSave.validateFields(data, part: .commander)
    if let pointer = try? JSONDecoder().decode(ScriptSavePointer.self, from: data) {
      guard (pointer.scope == "gallery") == (galleryNamespace != nil) else {
        throw MissionPackError(
          "Trial saves open only in Gallery trials; commander saves open in the live game.")
      }
      let generation = try ScriptSaveStore.generationDirectory(pointer.generation, from: url)
      try Self.requireGalleryPathAccess(generation, namespace: galleryNamespace)
      let (commander, world) = try ScriptSaveStore.read(
        data, from: url, navigationBinding: navigationBinding)
      // v2 is already migrated/validated; ordinary docking/load callbacks must not replay here.
      var candidate = Game(executive: false)
      candidate.commander = commander
      try candidate.commander.prepareEquipment()
      candidate.isMissionTrial = galleryNamespace != nil
      candidate.trialTitle = game.trialTitle
      candidate.trialDigest = game.trialDigest
      candidate.trialSeed = game.trialSeed
      candidate.missionPacks = game.missionPacks
      candidate.scriptPacks = game.scriptPacks
      candidate.scriptDurabilityAvailable = true
      candidate.viewportWidth = game.viewportWidth
      candidate.viewportHeight = game.viewportHeight
      candidate.systems = Universe.systemsIncludingPlugh(number: commander.galaxy)
      if candidate.requiresScriptDurability {
        migrateScriptCalendar(&candidate, untrackedJump: world.jumpCountdown != nil)
      }
      candidate.restoreScriptWorld(world)
      try candidate.migrateMiningPresence(legacyMissing: pointer.schemaVersion < 26)
      candidate.rebuildMiningFields()
      candidate.rebuildSalvageSites()
      try candidate.restoreSavedNPCSceneBindings()
      try candidate.rebindNativeStationsAfterLoad()
      try candidate.validateInstalledCourierContent()
      candidate.resolveCourierTerminals()
      candidate.resolveFreightTerminals()
      candidate.suspendUnavailableScriptContent(navigationBinding: navigationBinding)
      guard candidate.commander.valid,
        candidate.commander.savedBisonUnitAllocations == commander.savedBisonUnitAllocations,
        BisonUnitJournalSave.sceneIsConsistent(candidate.bodies, commander: candidate.commander) else {
        throw SaveError.invalidCommander
      }
      if persistMigrations && Self.nativeCommanderNeedsRepublishing(candidate, persisted: commander)
      {
        try Self.writeCommander(&candidate, to: url, navigationBinding: navigationBinding)
      }
      game = candidate
      resetC03ArchiveReaderUI()
      controls = Controls()
      scriptSaveURL = url
      game.scriptDurabilityAvailable = true
      return
    }
    guard galleryNamespace == nil else {
      throw MissionPackError("Legacy commander files cannot replace a Gallery trial.")
    }
    throw SaveError.invalidCommander
  }
}

extension Game {
  var scriptSimulationSave: ScriptSimulationSave {
    ScriptSimulationSave(
      randomState: randomState, fireCooldown: fireCooldown, spawnClock: legacySimulationSpawnClock,
      missionLoopCounter: missionLoopCounter, missionSpawnDelay: missionSpawnDelay,
      ecmFrames: ecmFrames, ecmRemainingDuration: ecmControl.remainingDuration,
      enemyECMSource: enemyECMSource, missileCooldown: missileCooldown,
      cabinTemperature: cabinTemperature, altitude: altitude, solar: ScriptSolarSave(game: self))
  }
  mutating func restoreScriptSimulation(_ state: ScriptSimulationSave?) {
    guard let state, state.valid else { return }
    randomState = state.randomState
    fireCooldown = state.fireCooldown
    legacySimulationSpawnClock = state.spawnClock
    missionLoopCounter = state.missionLoopCounter
    missionSpawnDelay = state.missionSpawnDelay
    let duration =
      state.ecmRemainingDuration
      ?? Double(state.ecmFrames) / ECMControl.referenceFramesPerSecond
    _ = ecmControl.restoreRemainingDuration(duration)
    activeECMActivation = nil
    enemyECMSource = state.enemyECMSource
    missileCooldown = state.missileCooldown
    cabinTemperature = state.cabinTemperature
    altitude = state.altitude
    if let solar = state.solar {
      solar.restore(into: &self)
    } else {
      celestials = []
      solarFuelRemainder = 0
      solarScoopState = .inactive
    }
  }
  mutating func seedScriptTrial(_ seed: UInt64) { randomState = seed }
}

extension Game {
  fileprivate func preflightActiveMissionProjectiles() throws {
    try validateRetainedMissionActorRestoration()
    guard !commander.scriptState.projectiles.isEmpty else { return }
    let identities: [UUID] = commander.scriptState.projectiles.compactMap { id, record in
      record.galaxy == commander.galaxy && record.system == commander.system ? id : nil
    }
    try validateRetainedMissionProjectileAdmissions(identities)
  }
}
