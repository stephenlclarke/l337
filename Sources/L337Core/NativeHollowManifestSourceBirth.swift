import Foundation

/// Untrusted preparation only. Construction/decoding does not establish an actual commission,
/// manufacture, attachment, living person, native actor, consent or mission progress.
struct NativeHollowManifestSourceBirth: Codable, Sendable, Equatable {
  enum Failure: Error { case invalidInput, changedBirth }

  struct Input: Codable, Sendable, Equatable {
    let mission: UUID
    let owner: UUID
    let commission: UUID
    let carrier: UUID
    let inventoryRevision: UInt64
    let dock: NativeMainStationDockReceipt
    let sale: NativeFirstCommoditySale
    let physicalTime: Double
    let firstSourceSequence: UInt64

    var shapeValid: Bool {
      dock.valid && dock.commanderOwner == owner
        && dock.station.system == NativeHollowManifestDefinition.issuer
        && sale.valid && sale.owner == owner && sale.dock.station.world == owner
        && sale.dock.sequence <= dock.sequence && sale.dock.actor.visit <= dock.actor.visit
        && sale.dock.calendarSeconds <= dock.calendarSeconds
        && physicalTime.isFinite && (0...1e12).contains(physicalTime)
        && sale.physicalTime <= physicalTime && inventoryRevision < UInt64(Int64.max)
        && firstSourceSequence > 0 && firstSourceSequence < UInt64(Int64.max) - 7
    }
  }

  enum Kind: String, Codable, Sendable {
    case masterCreated, hullAndCaptainAssigned, sealManufactured, sealAttached
  }

  /// A proposed ordered source operation, never a native-event or Script nextEvent receipt.
  struct Operation: Codable, Sendable, Equatable {
    let id: UUID
    let kind: Kind
    let sequence: UInt64
    let parent: UUID
    let object: UUID
  }

  struct Master: Codable, Sendable, Equatable {
    let id: UUID
    let operation: UUID
    /// Finite positive master-pattern template, not a discovered/admitted master actor.
    let template: ShipDesign
  }

  struct Original: Codable, Sendable, Equatable {
    let slot: NativeHollowManifestOriginalSealBinding.Slot
    let source: UUID
    let hull: UUID
    let captain: UUID
    let seal: UUID
    let imprint: UUID
    let master: UUID
    let assignment: UUID
    let manufacture: UUID
    let attachment: UUID
    /// Current authored operating complement; not a person-life or accommodation grant.
    let operatingCrew: Int
    let intrinsicCrewQuarters: Int
  }

  /// New local inspection fit. Capabilities do not install player minimum equipment.
  struct InspectionFit: Codable, Sendable, Equatable {
    let hullEnergy: Double
    let recharge: Double
    let maximumSpeed: Double
    let acceleration: Double
    let pitch: Double
    let yaw: Double
    let roll: Double
    let sealEnergy: Double
    let fittedMissiles: Int
    let fittedGuns: Int
    let fittedShields: Int
    let fittedEscapeEquipment: Int
    let fittedECM: Bool
    let ordinaryCargoTonnes: Int
  }

  let input: Input
  let rootDesign: ShipDesign
  let master: Master
  let originals: [Original]
  let operations: [Operation]
  let fit: InspectionFit
  let nextSourceSequence: UInt64

  /// No pose or velocity default: physical motion and contact/probe policy remain unresolved.
  enum UnresolvedDependency: String, CaseIterable {
    case actualCommissionAndPublication, originalPersonLifeBinding, nativeActorAdmission
    case physicalMotionPolicy, physicalSceneClearance, contactInstrumentAndProbe
  }

  var shapeValid: Bool {
    guard let expected = try? Self.preparing(input) else { return false }
    return self == expected
  }

  /// Pure deterministic proposal. The future private real command must authenticate its inputs
  /// and publish the complete candidate atomically. No allocator or external state is touched.
  static func preparing(_ input: Input, existing: Self? = nil) throws -> Self {
    guard input.shapeValid else { throw Failure.invalidInput }
    let geometry = try NativeC03SealGeometry.onager.get()
    let source = try NativeHollowManifestFleetSource.resolve(.inspectionFreighter)
    let expected = make(input, geometry: geometry, source: source)
    if let existing {
      guard existing == expected else { throw Failure.changedBirth }
      return existing
    }
    return expected
  }

  private static func make(
    _ input: Input, geometry: NativeC03SealGeometry.Geometry,
    source: NativeHollowManifestFleetSource.Profile
  ) -> Self {
    // Deterministic addresses support retry; they do not prove that any operation happened.
    func id(_ key: String) -> UUID {
      ScriptIdentity.uuid(
        "c03-source-birth-v1:\(input.owner):\(input.mission):\(input.commission):\(key)")
    }
    let master = Master(
      id: id("master"), operation: id("master-created"), template: geometry.sealDesign)
    var operations: [Operation] = [
      .init(
        id: master.operation, kind: .masterCreated, sequence: input.firstSourceSequence,
        parent: input.commission, object: master.id)
    ]
    var originals: [Original] = []
    for (index, slot) in NativeHollowManifestOriginalSealBinding.Slot.allCases.enumerated() {
      let prefix = slot.rawValue
      let original = Original(
        slot: slot, source: id(prefix + ":source"), hull: id(prefix + ":hull"),
        captain: id(prefix + ":captain"), seal: id(prefix + ":seal"),
        imprint: id(prefix + ":imprint"), master: master.id,
        assignment: id(prefix + ":assigned"), manufacture: id(prefix + ":manufactured"),
        attachment: id(prefix + ":attached"), operatingCrew: source.accommodation.operatingCrew,
        intrinsicCrewQuarters: source.accommodation.intrinsicCrewPlaces)
      let sequence = input.firstSourceSequence + UInt64(1 + index * 3)
      operations += [
        .init(
          id: original.assignment, kind: .hullAndCaptainAssigned, sequence: sequence,
          parent: input.commission, object: original.hull),
        .init(
          id: original.manufacture, kind: .sealManufactured, sequence: sequence + 1,
          parent: master.operation, object: original.seal),
        .init(
          id: original.attachment, kind: .sealAttached, sequence: sequence + 2,
          parent: original.manufacture, object: original.hull),
      ]
      originals.append(original)
    }
    return .init(
      input: input, rootDesign: geometry.rootDesign, master: master, originals: originals,
      operations: operations,
      fit: .init(
        hullEnergy: Double(source.performance.energy), recharge: source.performance.recharge,
        maximumSpeed: source.performance.speed, acceleration: source.performance.acceleration,
        pitch: source.performance.pitch, yaw: source.performance.yaw,
        roll: source.performance.roll, sealEnergy: 16,
        fittedMissiles: 0, fittedGuns: 0, fittedShields: 0, fittedEscapeEquipment: 0,
        fittedECM: false, ordinaryCargoTonnes: 0),
      nextSourceSequence: input.firstSourceSequence + 7)
  }
}
