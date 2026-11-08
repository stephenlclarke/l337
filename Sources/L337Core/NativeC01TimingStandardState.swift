import Foundation

/// Current mission facts. Decoding these records creates no live pickup authority.
struct NativeC01TimingStandardSource: Codable, Sendable, Equatable {
  let mission: UUID
  let permission: UUID
  let owner: UUID
  let audit: UUID
  let recorder: UUID
  let anchors: SystemAnchors
  let reference: ShipPose
  let visit: UInt64
  let physicalTime: Double

  var position: Vector3 {
    anchors.planet.position + (anchors.sun.position - anchors.planet.position).unit
      * (anchors.planet.radius + 25_000)
  }

  var valid: Bool {
    var native = FlightSimulationState()
    native.enter(NativeC01TimingStandard.location, arriving: true)
    guard let expected = native.anchors else { return false }
    return anchors.system == NativeC01TimingStandard.location
      && anchors.planet == expected.planet && anchors.sun == expected.sun
      && reference.position.finite && reference.orientation.validRotation && position.finite
      && (anchors.sun.position - anchors.planet.position).length > 0
      && visit > 0 && visit < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }
}

struct NativeC01TimingStandardCapture: Codable, Sendable, Equatable {
  let operation: UUID
  let source: NativeC01TimingStandardSource
  let missionRevision: UInt64
  let marker: ScriptOwnedActor
  let collector: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let scoop: EquipmentPurchaseItem
  let point: Vector3
  let relativeSpeed: Double
  let startTime: Double
  let physicalTime: Double
  let epoch: UUID
}

struct NativeC01TimingStandardLoss: Codable, Sendable, Equatable {
  enum Kind: String, Codable, Sendable { case standardDestroyed, carrierDestroyed, escape }
  let kind: Kind
  let actor: ScriptOwnedActor?
  let collector: ActorIdentity
  let carrier: UUID
  let energy: Double
  let escapePod: EquipmentPurchaseItem?
  let physicalTime: Double
}

private struct NativeC01TimingStandardStateValue: Codable, Sendable, Equatable {
  let source: NativeC01TimingStandardSource
  var capture: NativeC01TimingStandardCapture?
  var loss: NativeC01TimingStandardLoss?
  var used: NativeC01TimingStandardUse?
}

/// Keep captured actor records out of each leaf value's inline storage.
struct NativeC01TimingStandardState: Codable, Sendable, Equatable {
  private var storage: [NativeC01TimingStandardStateValue]

  init(
    source: NativeC01TimingStandardSource,
    capture: NativeC01TimingStandardCapture? = nil,
    loss: NativeC01TimingStandardLoss? = nil,
    used: NativeC01TimingStandardUse? = nil
  ) {
    storage = [.init(source: source, capture: capture, loss: loss, used: used)]
  }

  init(from decoder: any Decoder) throws {
    storage = [try NativeC01TimingStandardStateValue(from: decoder)]
  }

  func encode(to encoder: any Encoder) throws {
    try storage[0].encode(to: encoder)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    // Compare the value even when buffers are shared, preserving NaN semantics.
    lhs.storage[0] == rhs.storage[0]
  }

  var source: NativeC01TimingStandardSource {
    _read { yield storage[0].source }
  }

  var capture: NativeC01TimingStandardCapture? {
    _read { yield storage[0].capture }
    _modify { yield &storage[0].capture }
  }

  var loss: NativeC01TimingStandardLoss? {
    _read { yield storage[0].loss }
    _modify { yield &storage[0].loss }
  }

  var used: NativeC01TimingStandardUse? {
    _read { yield storage[0].used }
    _modify { yield &storage[0].used }
  }

  var held: Bool { capture != nil && loss == nil && used == nil }
  var heldMassKg: Double { held ? NativeC01TimingStandard.massKg : 0 }
}

enum NativeC01TimingStandard {
  static let location = SystemIdentity(galaxy: 0, system: 162)
  static let encounter = "meridian-standard-cradle"
  static let target = "timing-standard"
  static let receipt = "c01-recover-standard"
  static let massKg = 1000.0

  enum Part: String, CaseIterable, Hashable, Sendable {
    case standard = "timing-standard"
    case left = "cradle-left"
    case right = "cradle-right"
    case back = "cradle-back"
    case arm = "damaged-support-arm"

    var centre: Vector3 {
      switch self {
      case .standard: .init(0, 0, 0)
      case .left: .init(-6, 0, -6)
      case .right: .init(6, 0, -6)
      case .back: .init(0, 0, -13)
      case .arm: .init(0, 0, 100)
      }
    }
    var dimensions: Vector3 {
      switch self {
      case .standard:
        guard let envelope = try? OriginalHullEnvelope(vertices: design.rawMesh.vertices) else {
          preconditionFailure("Original timing-standard native dimensions are required.")
        }
        return envelope.dimensions
      case .left, .right: return .init(1, 8, 12)
      case .back: return .init(12, 8, 1)
      case .arm: return .init(120, 2, 2)
      }
    }
    var massKg: Double {
      guard self == .standard else { return 10_000 }
      guard let record = try? NativeC01Props.standard.get() else {
        preconditionFailure("The original timing-standard physical record is required.")
      }
      return record.massKilograms
    }
    var model: String { "asset:c01-standard-" + rawValue }

    /// Existing closed box topology with explicit project-owned metre dimensions.
    var design: ShipDesign {
      if self == .standard {
        guard let record = try? NativeC01Props.standard.get() else {
          preconditionFailure("The original timing-standard native geometry is required.")
        }
        return record.nativeDesign
      }
      let original = NativeC01SurveyorGeometry.recorder
      let d = dimensions
      return .init(
        vertices: original.vertices.map {
          [$0[0] / 0.8 * d.x, $0[1] / 0.5 * d.y, $0[2] / 0.3 * d.z]
        },
        faces: original.faces, license: original.license,
        source: "C01 proposed cradle box; explicit metre extents, independent of mass")
    }
    var profile: ScriptNPCDefinition {
      if self == .standard {
        guard let record = try? NativeC01Props.standard.get() else {
          preconditionFailure("The original timing-standard structural policy is required.")
        }
        return .init(
          id: "c01-standard-" + rawValue, name: "Original Meridian timing standard",
          source: record.sourcePath + "; SHA256 " + record.sourceSHA256,
          basis: "Original calibrated native prop; physical1000kg and structural health16; no equipment.",
          model: model, scale: 1, energy: record.structuralPolicy.energy,
          recharge: record.structuralPolicy.recharge,
          speed: 0, acceleration: 0, pitch: 0, yaw: 0, roll: 0,
          missiles: 0, fuel: 0, drive: nil, ecm: false, bounty: 0, lasers: [], components: [])
      }
      return .init(
        id: "c01-standard-" + rawValue, name: rawValue,
        source: "C01.P03.A project implementation policy; native feasibility remains unqualified",
        basis: "Existing closed box topology, explicit metre extents and independent mass",
        model: model, scale: 1, energy: self == .standard ? 16 : 64,
        recharge: 0, speed: 0, acceleration: 0, pitch: 0, yaw: 0, roll: 0,
        missiles: 0, fuel: 0, drive: nil, ecm: false, bounty: 0, lasers: [], components: [])
    }
  }

  static let modelHashes: Result<[Part: String], any Error> = Result {
    try Dictionary(
      uniqueKeysWithValues: Part.allCases.map {
        ($0, ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry($0.design)))
      })
  }
  static let hulls: Result<[Part: PreparedHull], any Error> = Result {
    try Dictionary(
      uniqueKeysWithValues: Part.allCases.map {
        ($0, try PreparedHull(mesh: $0.design.rawMesh))
      })
  }

  static func actor(source: NativeC01TimingStandardSource, part: Part) -> UUID {
    ScriptIdentity.uuid(
      "script-actor-v2:\(source.mission):\(NativeGlassMeridian.digest):\(encounter):\(part.rawValue)")
  }
  static func operation(source: NativeC01TimingStandardSource) -> UUID {
    ScriptIdentity.uuid(
      "c01-standard-custody-v1:\(source.mission):\(source.permission):\(source.audit)")
  }

  /// Same retained-endpoint rigid interpolation used by the native debris contact pass.
  /// The caller must obtain both endpoints from the actual integrator, never from a goal.
  static func rigidMotion(
    from start: ShipPose, to end: ShipPose, duration: Double,
    radius: Double
  ) -> HullSceneMotion? {
    guard start.orientation.validRotation, end.orientation.validRotation,
      start.position.finite, end.position.finite, duration.isFinite,
      duration > 0, duration <= 0.1, radius.isFinite, radius >= 0
    else { return nil }
    let a = start.orientation
    let b = end.orientation
    var relative = Basis3()
    relative.x = b.apply(a.inverse(.init(1, 0, 0)))
    relative.y = b.apply(a.inverse(.init(0, 1, 0)))
    relative.z = b.apply(a.inverse(.init(0, 0, 1)))
    let angle = acos(max(-1, min(1, (relative.x.x + relative.y.y + relative.z.z - 1) * 0.5)))
    guard angle.isFinite, angle < 1 else { return nil }
    let skew = Vector3(
      relative.y.z - relative.z.y, relative.z.x - relative.x.z,
      relative.x.y - relative.y.x)
    let omega =
      angle < 1e-7
      ? skew * (0.5 / duration)
      : skew * (angle / (2 * sin(angle) * duration))
    return .init(
      start: start, end: end,
      initialVelocity: (end.position - start.position) * (1 / duration),
      acceleration: .init(0, 0, 0), worldAngularVelocity: omega,
      duration: duration, playerRadius: radius)
  }

  static func approachSpeed(
    relativeVelocity: Vector3, playerAngularVelocity: Vector3, targetAngularVelocity: Vector3
  ) -> Double? {
    guard relativeVelocity.finite, playerAngularVelocity.finite, targetAngularVelocity.finite
    else { return nil }
    let radius = Part.standard.design.rawMesh.vertices.map(\.length).max()!
    let speed =
      relativeVelocity.length
      + playerAngularVelocity.length * Vector3(0, -45, 55).length
      + targetAngularVelocity.length * radius
    return speed.isFinite ? speed : nil
  }

  /// Add to the existing stored-kg aggregate before its single upward rounding.
  static func cargoTonnes(otherCargo: Int, storedKg: Double, addingStandard: Bool) -> Int? {
    guard otherCargo >= 0, storedKg.isFinite, storedKg >= 0 else { return nil }
    let mass = storedKg + (addingStandard ? massKg : 0)
    let rounded = ceil(mass / 1000)
    guard mass.isFinite, rounded.isFinite, rounded < Double(Int.max) else { return nil }
    let result = otherCargo.addingReportingOverflow(Int(rounded))
    return result.overflow ? nil : result.partialValue
  }

  static func prospectiveCargo(_ commander: borrowing Commander) -> Int? {
    guard let checked = commander.checkedCargoTonnes else { return nil }
    let recorderKg = commander.scriptState.instances.values.reduce(0.0) {
      $0 + ($1.hasHeldGlassMeridianRecorder ? 8 : 0)
    }
    let stored =
      commander.salvageLedger.inventoryMassKg
      + (commander.alienStorageState?.current.storedMassKg ?? 0) + recorderKg
    guard let prior = cargoTonnes(otherCargo: 0, storedKg: stored, addingStandard: false),
      prior <= checked
    else { return nil }
    return cargoTonnes(otherCargo: checked - prior, storedKg: stored, addingStandard: true)
  }
}

extension NativeC01TimingStandard {
  static func consumed(_ id: UUID, commander: borrowing Commander) -> Bool {
    commander.scriptState.instances.values.contains { mission in
      guard let leaf = mission.savedGlassMeridian?.timingStandard,
        leaf.capture != nil || leaf.loss != nil
      else { return false }
      return id == actor(source: leaf.source, part: .standard)
    }
  }
}

/// Descriptive native selection facts; not capture authority.
public struct NativeC01TimingStandardSelectionFacts: Sendable, Equatable {
  let logicalActor: UUID
  let fits: Bool
}
