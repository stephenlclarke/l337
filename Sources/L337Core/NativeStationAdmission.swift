import Foundation
import os

enum NativeStationRuntimeError: Error, Equatable {
  case invalidSource, invalidState, unavailable, unsafePlacement, capacity, unsafeEntry, unsafeExit
}

/// One catalogue value supplies both geometry and the adopted physical profile.
struct NativeStationSourceBinding: Equatable, Sendable {
  let site: OriginalStationSite
  let physical: OriginalStationPhysical
  let geometry: NativeStationGeometry
  var system: SystemIdentity { site.system }
  var key: String { site.key }
  var catalogueShipID: String { site.catalogueID }
  var rotationRate: Double { site.initialSpinRate }
  var maximumEnergy: Double { physical.maximumStructuralEnergy }
  var recharge: Double { physical.rechargeEnergyPerSecond }
  var descriptor: NativeStationDescriptor {
    .init(definition: "original-station-" + site.catalogueID.lowercased(),
      version: OriginalStationSite.sourceVersion, boardOrigin: .authored,
      capabilities: site.sealedDispatchDefinition == nil ? [] : [.sealedDispatchBoard])
  }
  func identity(world: UUID) -> NativeStationIdentity { site.identity(world: world) }
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.site == rhs.site && lhs.physical == rhs.physical
      && lhs.geometry.mesh.vertices == rhs.geometry.mesh.vertices
      && lhs.geometry.mesh.faces == rhs.geometry.mesh.faces
      && lhs.geometry.docking == rhs.geometry.docking
      && lhs.geometry.bounds == rhs.geometry.bounds
  }
  init?(site: OriginalStationSite) {
    guard let ship = ShipCatalogue.ship(site.catalogueID),
      let shape = site.nativeGeometry(from: ship),
      let physical = OriginalStationPhysical.read(from: ship),
      physical.blueprintID == site.catalogueID,
      let geometry = NativeStationGeometry(site: site, mesh: shape.mesh, port: shape.port)
    else { return nil }
    self.site = site
    self.physical = physical
    self.geometry = geometry
  }
}
enum NativeStationSource {
  static let adapterRevision = "original-station-source-v1"
  static let boardRevision = "original-sealed-dispatch-board-v1"
  static let bindings = OriginalStationSite.allCases.compactMap { NativeStationSourceBinding(site: $0) }
  static func requireBindings() throws -> [NativeStationSourceBinding] {
    let values = bindings
    guard values.count == OriginalStationSite.allCases.count,
      Set(values.map(\.site)) == Set(OriginalStationSite.allCases)
    else { throw NativeStationRuntimeError.invalidSource }
    return values
  }
  static func binding(for identity: NativeStationIdentity) -> NativeStationSourceBinding? {
    guard let site = OriginalStationSite.site(for: identity, owner: identity.world) else { return nil }
    return bindings.first { $0.site == site }
  }
  static func position(for source: NativeStationSourceBinding) -> Vector3? {
    source.site.sourcePose(in: canonicalAnchors(system: source.system))?.position
  }
  static func boardHour(calendarSeconds: Double) -> Int64? {
    guard calendarSeconds.isFinite, calendarSeconds >= 0 else { return nil }
    let value = floor(calendarSeconds / 3600)
    return value < Double(Int64.max) ? Int64(value) : nil
  }
  static func authentic(_ record: NativeStationRecord, owner: UUID) -> Bool {
    guard record.valid, record.identity.world == owner,
      let source = binding(for: record.identity)
    else { return false }
    return record.descriptor == source.descriptor
  }
  static func canonicalAnchors(system: SystemIdentity) -> SystemAnchors {
    var flight = FlightSimulationState()
    flight.enter(system, arriving: false)
    return flight.anchors!
  }
  static func initialOrientation(_ identity: NativeStationIdentity) -> Basis3 { Basis3() }
}

struct NativeStationSavedPose: Equatable, Codable, Sendable {
  init(station: NativeStationIdentity, position: Vector3, orientation: Basis3, energy: Double) {
    self.station = station
    self.position = position
    self.orientation = orientation
    self.energy = energy
  }
  private enum CodingKeys: String, CodingKey { case station, position, orientation, energy }
  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["station", "position", "orientation", "energy"])
    let c = try decoder.container(keyedBy: CodingKeys.self)
    station = try c.decode(NativeStationIdentity.self, forKey: .station)
    position = try c.decode(Vector3.self, forKey: .position)
    orientation = try c.decode(Basis3.self, forKey: .orientation)
    energy = try c.decode(Double.self, forKey: .energy)
    guard valid else { throw SaveError.invalidCommander }
  }

  let station: NativeStationIdentity
  let position: Vector3
  let orientation: Basis3
  var energy: Double

  var valid: Bool {
    guard let source = NativeStationSource.binding(for: station),
      position.finite, position.length.isFinite, orientation.validRotation,
      energy.isFinite, (0...source.maximumEnergy).contains(energy),
      position == NativeStationSource.position(for: source)
    else { return false }
    return orientation == NativeStationSource.initialOrientation(station)
  }

  func orientation(at physicalTime: Double) -> Basis3? {
    guard physicalTime.isFinite, physicalTime >= 0,
      let source = NativeStationSource.binding(for: station)
    else { return nil }
    var spin = Basis3()
    spin.rotate(
      pitch: 0, roll: (physicalTime * source.rotationRate).truncatingRemainder(dividingBy: 2 * .pi),
      yaw: 0)
    var result = Basis3()
    result.x = orientation.apply(spin.x)
    result.y = orientation.apply(spin.y)
    result.z = orientation.apply(spin.z)
    return result.validRotation ? result : nil
  }
}

/// Original main stations retain their separate source namespace.
struct NativeMainStationIdentity: Equatable, Hashable, Codable, Sendable {
  /// Original main-station histories span all galaxies, including each galaxy's PLUGH system.
  static let maximumCount = 8 * (Plugh.systemID + 1)
  let world: UUID
  let system: SystemIdentity
  let resource: UUID
  var key: String { "main-orbital:\(system.galaxy):\(system.system)" }
  var valid: Bool {
    (0..<8).contains(system.galaxy) && (0...256).contains(system.system)
      && resource == Game.worldResourceIdentity("main-station-v1:\(key)")
  }
}

struct NativeMainStationDockReceipt: Equatable, Codable, Sendable {
  let station: NativeMainStationIdentity
  let actor: ActorIdentity
  let commanderOwner: UUID
  let sequence: UInt64
  let calendarSeconds: Double
  var valid: Bool {
    station.valid && station.world == commanderOwner && actor.system == station.system
      && actor.entity == 1 && actor.visit > 0 && actor.visit < UInt64(Int64.max)
      && sequence > 0 && sequence < UInt64(Int64.max)
      && calendarSeconds.isFinite && (0...1e12).contains(calendarSeconds)
  }
}

struct NativeMainStationObservation: Equatable, Codable, Sendable {
  let station: NativeMainStationIdentity
  let actor: ActorIdentity
  let calendarSeconds: Double
  var valid: Bool {
    station.valid && actor.system == station.system && actor.entity == 1
      && actor.visit > 0 && actor.visit < UInt64(Int64.max)
      && calendarSeconds.isFinite && (0...1e12).contains(calendarSeconds)
  }
}

/// Persistent source/pose wrapper; G3 owns the unchanged logical lifecycle and receipt ledger.
struct NativeStationWorld: Equatable, Codable, Sendable {
  private let validationMemo = NativeStationValidationMemo()

  // Owned world snapshots share one value until a nested mutation detaches it.
  // Each read projects its stored child before the synchronous buffer borrow ends.
  private struct Values: Sendable {
    let adapterRevision: String
    let geometryRevision: String
    let clockOrigin: Double
    var ledger: NativeStationLedger
    var poses: [NativeStationSavedPose]
    var mainStations: [NativeMainStationIdentity]
    var mainObservations: [NativeMainStationObservation]
    var nextMainDockSequence: UInt64
    var currentMainDock: NativeMainStationDockReceipt?
    var stationInertia: [NativeStationInertia] = []
    var arkFuel: [NativeArkStationFuel]? = nil
  }
  private var valueStorage: [Values]

  var adapterRevision: String {
    _read {
      let stored: String = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.adapterRevision)!.pointee
      }
      yield stored
    }
  }

  var geometryRevision: String {
    _read {
      let stored: String = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.geometryRevision)!.pointee
      }
      yield stored
    }
  }

  var clockOrigin: Double {
    _read {
      let stored: Double = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.clockOrigin)!.pointee
      }
      yield stored
    }
  }

  var ledger: NativeStationLedger {
    _read {
      let stored: NativeStationLedger = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.ledger)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].ledger }
  }

  var poses: [NativeStationSavedPose] {
    _read {
      let stored: [NativeStationSavedPose] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.poses)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].poses }
  }

  var mainStations: [NativeMainStationIdentity] {
    _read {
      let stored: [NativeMainStationIdentity] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.mainStations)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].mainStations }
  }

  var mainObservations: [NativeMainStationObservation] {
    _read {
      let stored: [NativeMainStationObservation] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.mainObservations)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].mainObservations }
  }

  var nextMainDockSequence: UInt64 {
    _read {
      let stored: UInt64 = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.nextMainDockSequence)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].nextMainDockSequence }
  }

  var currentMainDock: NativeMainStationDockReceipt? {
    _read {
      let stored: NativeMainStationDockReceipt? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.currentMainDock)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].currentMainDock }
  }

  var stationInertia: [NativeStationInertia] {
    _read {
      let stored: [NativeStationInertia] = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.stationInertia)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].stationInertia }
  }

  var arkFuel: [NativeArkStationFuel]? {
    _read {
      let stored: [NativeArkStationFuel]? = valueStorage.withUnsafeBufferPointer { storage in
        storage.baseAddress!.pointer(to: \.arkFuel)!.pointee
      }
      yield stored
    }
    _modify { yield &valueStorage[0].arkFuel }
  }

  init(owner: UUID) throws {
    let bindings = try NativeStationSource.requireBindings()
    guard bindings.count <= NativeStationLedger.maximumSourceRecords else {
      throw NativeStationRuntimeError.invalidSource
    }
    let adapterRevision = NativeStationSource.adapterRevision
    let geometryRevision = NativeStationGeometry.adapterRevision
    // Native simulation-calendar origin, not the original engine's absolute ship-clock epoch.
    let clockOrigin: Double = 0
    let mainStations: [NativeMainStationIdentity] = []
    let mainObservations: [NativeMainStationObservation] = []
    let nextMainDockSequence: UInt64 = 1
    let currentMainDock: NativeMainStationDockReceipt? = nil
    let records = bindings.map { binding in
      NativeStationRecord(
        identity: binding.identity(world: owner), descriptor: binding.descriptor,
        revision: 1, binding: nil, tombstone: nil,
        utility: NativeUtilityState.isTarget(binding.identity(world: owner))
          ? NativeUtilityState(owner: owner) : nil)
    }
    let ledger = try NativeStationLedger(world: owner, records: records)
    let poses: [NativeStationSavedPose] = try bindings.map { binding in
      guard let position = NativeStationSource.position(for: binding)
      else { throw NativeStationRuntimeError.unsafePlacement }
      let station = binding.identity(world: owner)
      return .init(
        station: station, position: position,
        orientation: NativeStationSource.initialOrientation(station), energy: binding.maximumEnergy)
    }
    valueStorage = [.init(
      adapterRevision: adapterRevision, geometryRevision: geometryRevision, clockOrigin: clockOrigin,
      ledger: ledger, poses: poses, mainStations: mainStations, mainObservations: mainObservations,
      nextMainDockSequence: nextMainDockSequence, currentMainDock: currentMainDock,
      stationInertia: [], arkFuel: nil)]
    guard valid else { throw NativeStationRuntimeError.invalidState }
  }

  var valid: Bool {
    let content = NativeStationWorldContent(self)
    if validationMemo.contains(content) { return true }
    guard validWithoutMemo else { return false }
    validationMemo.recordValidated(content)
    return true
  }

  /// The original complete source, ownership, pose and receipt predicate.
  /// Decode and every changed semantic world must still pass all of it.
  private var validWithoutMemo: Bool {
    let originals = Set(mainStations)
    guard arkFuelIsValid, inertiaIsValid, adapterRevision == NativeStationSource.adapterRevision,
      geometryRevision == NativeStationGeometry.adapterRevision, clockOrigin == 0,
      mainStations.count <= NativeMainStationIdentity.maximumCount,
      originals.count == mainStations.count,
      Set(mainStations.map(\.key)).count == mainStations.count,
      mainStations.allSatisfy({ $0.valid && $0.world == ledger.world }),
      mainObservations.count <= NativeMainStationIdentity.maximumCount,
      Set(mainObservations.map(\.station)).count == mainObservations.count,
      mainObservations.allSatisfy({ $0.valid && originals.contains($0.station) }),
      nextMainDockSequence > 0, nextMainDockSequence < UInt64(Int64.max),
      ledger.valid, NativeStationSource.bindings.count == OriginalStationSite.allCases.count,
      Set(ledger.records.map(\.identity)) == Set(OriginalStationSite.allCases.map { $0.identity(world: ledger.world) }),
      ledger.records.count == NativeStationLedger.recordLimit,
      poses.count == ledger.records.count, Set(poses.map(\.station)).count == poses.count,
      ledger.records.allSatisfy({ NativeStationSource.authentic($0, owner: ledger.world) }),
      ledger.records.filter({ NativeUtilityState.isTarget($0.identity) }).count == 1,
      ledger.records.first(where: { NativeUtilityState.isTarget($0.identity) })?.utility?.owner
        == ledger.world,
      poses.allSatisfy(\.valid), Set(poses.map(\.station)) == Set(ledger.records.map(\.identity))
    else { return false }
    let conditions = Dictionary(uniqueKeysWithValues: poses.map { ($0.station, $0.energy) })
    guard
      ledger.records.allSatisfy({ record in
        record.tombstone == nil
          ? (conditions[record.identity] ?? 0) > 0 : conditions[record.identity] == 0
      })
    else { return false }
    guard ledger.currentDock.map({ $0.commanderOwner == ledger.world }) ?? true else {
      return false
    }
    if let receipt = currentMainDock {
      return ledger.currentDock == nil && receipt.valid && mainStations.contains(receipt.station)
        && receipt.sequence == nextMainDockSequence - 1 && receipt.commanderOwner == ledger.world
    }
    return true
  }

  static func == (lhs: NativeStationWorld, rhs: NativeStationWorld) -> Bool {
    NativeStationWorldContent(lhs) == NativeStationWorldContent(rhs)
  }

  func pose(for station: NativeStationIdentity) -> NativeStationSavedPose? {
    poses.first { $0.station == station }
  }

  private enum CodingKeys: String, CodingKey {
    case adapterRevision, geometryRevision, clockOrigin, ledger, poses, mainStations,
      mainObservations, nextMainDockSequence, currentMainDock, stationInertia, arkFuel
  }

  init(from decoder: Decoder) throws {
    try NativeUtilityCoding.require(decoder, ["adapterRevision", "geometryRevision", "clockOrigin",
      "ledger", "poses", "mainStations", "mainObservations", "nextMainDockSequence", "stationInertia"],
      optional: ["currentMainDock", "arkFuel"])
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let adapterRevision = try values.decode(String.self, forKey: .adapterRevision)
    let geometryRevision = try values.decode(String.self, forKey: .geometryRevision)
    let clockOrigin = try values.decode(Double.self, forKey: .clockOrigin)
    let ledger = try values.decode(NativeStationLedger.self, forKey: .ledger)
    let nextMainDockSequence =
      try values.decode(UInt64.self, forKey: .nextMainDockSequence)
    let currentMainDock: NativeMainStationDockReceipt? = values.contains(.currentMainDock)
      ? try values.decode(NativeMainStationDockReceipt.self, forKey: .currentMainDock) : nil
    let mainStations: [NativeMainStationIdentity]
    if values.contains(.mainStations) {
      var mainEntries = try values.nestedUnkeyedContainer(forKey: .mainStations)
      guard mainEntries.count.map({ $0 <= NativeMainStationIdentity.maximumCount }) ?? true else {
        throw NativeStationRuntimeError.invalidState
      }
      var originals: [NativeMainStationIdentity] = []
      while !mainEntries.isAtEnd {
        guard originals.count < NativeMainStationIdentity.maximumCount else {
          throw NativeStationRuntimeError.invalidState
        }
        originals.append(try mainEntries.decode(NativeMainStationIdentity.self))
      }
      mainStations = originals
    } else { throw NativeStationRuntimeError.invalidState }
    let mainObservations: [NativeMainStationObservation]
    if values.contains(.mainObservations) {
      var observations = try values.nestedUnkeyedContainer(forKey: .mainObservations)
      guard observations.count.map({ $0 <= NativeMainStationIdentity.maximumCount }) ?? true else {
        throw NativeStationRuntimeError.invalidState
      }
      var originals: [NativeMainStationObservation] = []
      while !observations.isAtEnd {
        guard originals.count < NativeMainStationIdentity.maximumCount else {
          throw NativeStationRuntimeError.invalidState
        }
        originals.append(try observations.decode(NativeMainStationObservation.self))
      }
      mainObservations = originals
    } else { throw NativeStationRuntimeError.invalidState }
    var entries = try values.nestedUnkeyedContainer(forKey: .poses)
    guard entries.count.map({ $0 <= NativeStationLedger.recordLimit }) ?? true else {
      throw NativeStationRuntimeError.invalidState
    }
    var result: [NativeStationSavedPose] = []
    while !entries.isAtEnd {
      guard result.count < NativeStationLedger.recordLimit else {
        throw NativeStationRuntimeError.invalidState
      }
      result.append(try entries.decode(NativeStationSavedPose.self))
    }
    let poses = result
    var stationInertia: [NativeStationInertia] = []
    var inertiaEntries = try values.nestedUnkeyedContainer(forKey: .stationInertia)
    guard inertiaEntries.count.map({ $0 <= Self.maximumInertialStations }) ?? true else {
      throw NativeStationRuntimeError.invalidState
    }
    while !inertiaEntries.isAtEnd {
      guard stationInertia.count < Self.maximumInertialStations else {
        throw NativeStationRuntimeError.invalidState
      }
      stationInertia.append(try inertiaEntries.decode(NativeStationInertia.self))
    }
    var arkFuel: [NativeArkStationFuel]? = nil
    if values.contains(.arkFuel) {
      arkFuel = try NativeUtilityCoding.array(
        NativeArkStationFuel.self, key: .arkFuel, container: values,
        limit: NativeMainStationIdentity.maximumCount)
    }
    valueStorage = [.init(
      adapterRevision: adapterRevision, geometryRevision: geometryRevision, clockOrigin: clockOrigin,
      ledger: ledger, poses: poses, mainStations: mainStations, mainObservations: mainObservations,
      nextMainDockSequence: nextMainDockSequence, currentMainDock: currentMainDock,
      stationInertia: stationInertia, arkFuel: arkFuel)]
    guard valid else { throw NativeStationRuntimeError.invalidState }
  }

  func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(adapterRevision, forKey: .adapterRevision)
    try values.encode(geometryRevision, forKey: .geometryRevision)
    try values.encode(clockOrigin, forKey: .clockOrigin)
    try values.encode(ledger, forKey: .ledger)
    try values.encode(poses, forKey: .poses)
    try values.encode(mainStations, forKey: .mainStations)
    try values.encode(mainObservations, forKey: .mainObservations)
    try values.encode(nextMainDockSequence, forKey: .nextMainDockSequence)
    try values.encodeIfPresent(currentMainDock, forKey: .currentMainDock)
    try values.encode(stationInertia, forKey: .stationInertia)
    try values.encodeIfPresent(arkFuel, forKey: .arkFuel)
  }
}

extension NativeStationWorld {
  var arkFuelIsValid: Bool {
    guard let arkFuel else { return true }
    return !arkFuel.isEmpty && arkFuel.count <= NativeMainStationIdentity.maximumCount
      && Set(arkFuel.map(\.station)).count == arkFuel.count
      && arkFuel.allSatisfy {
        $0.valid && $0.station.world == ledger.world && mainStations.contains($0.station)
      }
  }
}

/// One derived immutable validation witness, shared safely across value snapshots.
/// Only a complete successful source check may replace it. Neither disk nor UI
/// can supply the witness, and a hit requires full semantic equality, not an ID.
private final class NativeStationValidatedContent: Sendable {
  private let content: NativeStationWorldContent

  init(_ content: consuming NativeStationWorldContent) {
    self.content = consume content
  }

  @inline(never)
  func matches(_ candidate: borrowing NativeStationWorldContent) -> Bool {
    content == candidate
  }
}

private final class NativeStationValidationMemo: Sendable {
  private let state = OSAllocatedUnfairLock<NativeStationValidatedContent?>(initialState: nil)

  func contains(_ content: NativeStationWorldContent) -> Bool {
    state.withLock {
      guard let cached = $0 else { return false }
      return cached.matches(content)
    }
  }

  func recordValidated(_ content: NativeStationWorldContent) {
    let validated = NativeStationValidatedContent(content)
    state.withLock { $0 = validated }
  }
}
