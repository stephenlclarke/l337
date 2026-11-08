import Foundation

/// Newly authored C01 apparatus geometry. These descriptors admit no body or
/// fixture. Actual scene compatibility, designed joints and publication are
/// separate native-owner checks.
enum NativeC01InquiryFixtureGeometry {
  static let revision = "c01-inquiry-apparatus-geometry-v1"
  static let metricRevision = "c01-inquiry-project-metres-v1"
  // A source-local project convention, not a universal or historical SI scale.
  static let metresPerWorldUnit = 1.0

  enum Part: String, Codable, Sendable, CaseIterable {
    case support, head0, head1, head2
  }

  struct Descriptor: Sendable {
    let part: Part
    let centreNative: Vector3
    /// The same immutable mesh must serve rendering and physical queries.
    let mesh: Mesh
  }

  struct ReceiverFace: Sendable {
    let centreNative: Vector3
    let outward: Vector3
    let polygonNative: [Vector3]
    let nativeFaceIndex: Int
  }

  struct DesignedJoint: Sendable {
    let head: Part
    let headBackFaceIndex: Int
    let supportFrontFaceIndex: Int
    let areaSquareMetres: Double
  }

  static let receiver = ReceiverFace(
    centreNative: native(.init(0, 0, -1)), outward: .init(0, 0, -1),
    polygonNative: [
      native(.init(-1, -1, -1)), native(.init(-1, 1, -1)),
      native(.init(1, 1, -1)), native(.init(1, -1, -1)),
    ], nativeFaceIndex: 0)

  static let support = descriptor(.support, centre: .init(0, 50, 2), halfSize: .init(301, 51, 1))
  static let head0 = descriptor(.head0, centre: .init(-300, 0, 0), halfSize: .init(1, 1, 1))
  static let head1 = descriptor(.head1, centre: .init(0, 100, 0), halfSize: .init(1, 1, 1))
  static let head2 = descriptor(.head2, centre: .init(300, 0, 0), halfSize: .init(1, 1, 1))

  // Exact source joints only. This list never excludes another solid from a
  // native query or turns an unverified actor into an admitted assembly part.
  static let designedJoints: [DesignedJoint] = [Part.head0, .head1, .head2].map {
    .init(head: $0, headBackFaceIndex: 1, supportFrontFaceIndex: 0, areaSquareMetres: 4)
  }

  static func descriptor(for part: Part) -> Descriptor {
    switch part {
    case .support: support
    case .head0: head0
    case .head1: head1
    case .head2: head2
    }
  }

  /// Explicit new source-owned authoring budgets. Surface material and itemized
  /// intrinsic allowances are estimates, not measured mass, a mass/health law,
  /// a paid fitting or a kit granted to the commander.
  struct PhysicalBudget: Sendable {
    let massKilograms: Double
    let energy: Double
    var recharge: Double { 0 }
    var shields: Double { 0 }
    var fuel: Double { 0 }
    var missiles: Int { 0 }
    var crew: Int { 0 }
    var ecm: Bool { false }
    var weapons: Bool { false }
    var drive: Bool { false }
  }

  // Exposed support area125612m² *14kg/m² +300kg intrinsic.
  // Each head area(24-4)m² *14kg/m² +100kg intrinsic.
  // Internal contact patches are excluded from the mass budget on both sides,
  // while all original closed faces remain in the actual collision geometry.
  static let supportBudget = PhysicalBudget(massKilograms: 1_758_868, energy: 100)
  static let headBudget = PhysicalBudget(massKilograms: 380, energy: 16)

  static func physicalBudget(for part: Part) -> PhysicalBudget {
    switch part {
    case .support: supportBudget
    case .head0, .head1, .head2: headBudget
    }
  }

  /// Only C01-authored metre coordinates cross this conversion. Raw ray ranges
  /// stay in native coordinates, and existing actor/component transforms stay
  /// with their existing source owners.
  private static func native(_ metres: Vector3) -> Vector3 {
    metres * (1 / metresPerWorldUnit)
  }

  private static func descriptor(_ part: Part, centre: Vector3, halfSize: Vector3) -> Descriptor {
    let x = halfSize.x
    let y = halfSize.y
    let z = halfSize.z
    let vertices: [Vector3] = [
      .init(-x, -y, -z), .init(x, -y, -z), .init(x, y, -z), .init(-x, y, -z),
      .init(-x, -y, z), .init(x, -y, z), .init(x, y, z), .init(-x, y, z),
    ]
    return .init(
      part: part, centreNative: native(centre),
      mesh: .init(
        vertices: vertices.map(native),
        faces: [
          [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
          [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
        ], preserveWinding: true))
  }
}

extension NativeC01InquiryFixtureGeometry {
  private static let supportDigest: Result<String, any Error> = Result { try digest(.support) }
  private static let head0Digest: Result<String, any Error> = Result { try digest(.head0) }
  private static let head1Digest: Result<String, any Error> = Result { try digest(.head1) }
  private static let head2Digest: Result<String, any Error> = Result { try digest(.head2) }

  /// Fixed geometry descriptors, not source approval or an admitted mesh claim.
  /// This belongs in the full source join, never the shallow validation DAG.
  static func expectedGeometryPins() throws -> NativeC01InquiryFixtureGeometryPins {
    try .init(
      support: supportDigest.get(), head0: head0Digest.get(),
      head1: head1Digest.get(), head2: head2Digest.get())
  }

  private static func digest(_ part: Part) throws -> String {
    let mesh = descriptor(for: part).mesh
    let design = ShipDesign(
      vertices: mesh.vertices.map { [$0.x, $0.y, $0.z] }, faces: mesh.faces,
      license: "MIT", source: "C01 authored apparatus;\(revision);\(metricRevision);\(part.rawValue)")
    return ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
  }
}

struct NativeC01InquiryFixtureGeometryPins: Codable, Sendable, Equatable {
  let support: String
  let head0: String
  let head1: String
  let head2: String

  var shapeValid: Bool {
    [support, head0, head1, head2].allSatisfy(ScriptCompletionReceipt.validDigest)
  }
}

/// Retained binding facts only. Birth and subsequent actual bindings remain
/// distinguishable; allocating or decoding these IDs creates no physical part.
struct NativeC01InquiryFixtureBinding: Codable, Sendable, Equatable {
  let actor: ActorIdentity
  let spawn: SpawnIdentity
  let bodyID: Int
  let revision: UInt64
  let operation: UUID

  var shapeValid: Bool {
    actor.visit > 0 && actor.visit < UInt64.max && actor.entity >= 2 && actor.entity < UInt64.max
      && spawn.system == actor.system && spawn.visit == actor.visit
      && spawn.sequence > 0 && spawn.sequence < UInt64.max && spawn.member < 4
      // Proposed G1-owned raw producer case. No missing enum API is called:
      // current producers cannot satisfy this source-specific data predicate.
      && spawn.producer.rawValue == "c01Inquiry"
      && bodyID > 0 && revision > 0 && revision < UInt64(Int64.max)
  }
}

struct NativeC01InquiryFixtureTransition: Codable, Sendable, Equatable {
  let operation: UUID
  let binding: NativeC01InquiryFixtureBinding
  let physicalTime: Double
  let historicalEpoch: UUID

  var shapeValid: Bool {
    binding.shapeValid && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }
}

enum NativeC01InquiryFixturePresence: Codable, Sendable, Equatable {
  case present
  case destroyed(CombatIncident)
  case parked(NativeC01InquiryFixtureTransition)
  case removed(NativeC01InquiryFixtureTransition)
}

struct NativeC01InquiryFixturePartState: Codable, Sendable, Equatable {
  let part: NativeC01InquiryFixtureGeometry.Part
  let birthBinding: NativeC01InquiryFixtureBinding
  let binding: NativeC01InquiryFixtureBinding
  let birthPose: ShipPose
  let pose: ShipPose
  let velocity: Vector3
  let angularVelocity: Vector3
  let energy: Double
  let physicalTime: Double
  let presence: NativeC01InquiryFixturePresence

  var shapeValid: Bool {
    let member: UInt16
    switch part {
    case .support: member = 0
    case .head0: member = 1
    case .head1: member = 2
    case .head2: member = 3
    }
    guard birthBinding.shapeValid, binding.shapeValid,
      birthBinding.spawn.member == member, binding.spawn.member == member,
      binding.revision >= birthBinding.revision,
      birthBinding.actor.system == binding.actor.system,
      birthPose.position.finite, birthPose.orientation.validRotation,
      pose.position.finite, pose.orientation.validRotation,
      velocity.finite, angularVelocity.finite,
      energy.isFinite, energy >= 0,
      energy <= NativeC01InquiryFixtureGeometry.physicalBudget(for: part).energy,
      physicalTime.isFinite, (0...1e12).contains(physicalTime)
    else { return false }
    switch presence {
    case .present:
      return energy > 0
    case .destroyed(let incident):
      return energy == 0 && incident.id > 0 && incident.id < UInt64.max
        && incident.victim == binding.actor && incident.outcome == .destruction
        && incident.position.finite && incident.physicalTime.isFinite
        && incident.physicalTime >= 0 && incident.physicalTime <= physicalTime
    case .parked(let transition):
      return energy > 0 && transition.shapeValid && transition.binding == binding
        && transition.physicalTime <= physicalTime
    case .removed(let transition):
      return transition.shapeValid && transition.binding == binding
        && transition.physicalTime <= physicalTime
    }
  }
}

enum NativeC01InquiryFixtureRetirementCause: Codable, Sendable, Equatable {
  case partDestroyed(part: NativeC01InquiryFixtureGeometry.Part, incidentID: UInt64)
  case sourceUnavailable(operation: UUID)
  case supersededByAdmission(operation: UUID)
  case caseClosed(operation: UUID)
}

struct NativeC01InquiryFixtureRetirement: Codable, Sendable, Equatable {
  let operation: UUID
  let revision: UInt64
  let physicalTime: Double
  let cause: NativeC01InquiryFixtureRetirementCause
}

private struct NativeC01InquiryFixtureBodyAddress: Hashable {
  let system: SystemIdentity
  let visit: UInt64
  let bodyID: Int

  init(_ binding: NativeC01InquiryFixtureBinding) {
    system = binding.actor.system
    visit = binding.actor.visit
    bodyID = binding.bodyID
  }
}

/// Exactly four historical part records. A retired generation can retain
/// genuinely present survivors as solids without granting instrument authority.
/// All source/world/cold/admission/currentness checks remain external to shape.
struct NativeC01InquiryFixtureGeneration: Codable, Sendable, Equatable {
  let owner: UUID
  let caseID: UUID
  let caseOrdinal: UInt64
  let sourceBirth: UUID
  let sourceRevision: UInt64
  let fixtureID: UUID
  let generation: UInt64
  let revision: UInt64
  let admissionOperation: UUID
  let admissionArrival: NativeMainStationDockReceipt
  let admissionPhysicalTime: Double
  let inertialFrame: ShipPose
  let placementCandidate: UInt64
  let geometryRevision: String
  let geometryPins: NativeC01InquiryFixtureGeometryPins
  let metricRevision: String
  let metresPerWorldUnit: Double
  let lawRevision: String
  let support: NativeC01InquiryFixturePartState
  let head0: NativeC01InquiryFixturePartState
  let head1: NativeC01InquiryFixturePartState
  let head2: NativeC01InquiryFixturePartState
  let retirement: NativeC01InquiryFixtureRetirement?
  let modelSnapshot: NativeC01InquiryModelSnapshot

  var parts: [NativeC01InquiryFixturePartState] { [support, head0, head1, head2] }

  var shapeValid: Bool {
    guard modelSnapshot.shapeValid, caseOrdinal < UInt64.max, sourceRevision > 0, sourceRevision < UInt64(Int64.max),
      generation > 0, generation < UInt64.max, revision > 0, revision < UInt64(Int64.max),
      admissionArrival.valid, admissionArrival.commanderOwner == owner,
      admissionArrival.station.world == owner,
      admissionPhysicalTime.isFinite, (0...1e12).contains(admissionPhysicalTime),
      inertialFrame.position.finite, inertialFrame.orientation.validRotation,
      placementCandidate < UInt64.max,
      geometryRevision == NativeC01InquiryFixtureGeometry.revision, geometryPins.shapeValid,
      metricRevision == NativeC01InquiryFixtureGeometry.metricRevision,
      metresPerWorldUnit == NativeC01InquiryFixtureGeometry.metresPerWorldUnit,
      lawRevision == NativeC01InquiryHeadModelData.lawRevision,
      support.part == .support, head0.part == .head0, head1.part == .head1, head2.part == .head2
    else { return false }
    let records = parts
    guard records.allSatisfy({
      $0.shapeValid && $0.binding.actor.system == admissionArrival.station.system
        && $0.birthBinding.actor.visit == admissionArrival.actor.visit
        && $0.birthBinding.operation == admissionOperation
        && $0.physicalTime >= admissionPhysicalTime
    }), Set(records.map { $0.birthBinding.actor }).count == 4,
      Set(records.map { $0.birthBinding.spawn }).count == 4,
      Set(records.map { $0.birthBinding.bodyID }).count == 4,
      Set(records.map { $0.binding.actor }).count == 4,
      Set(records.map { $0.binding.spawn }).count == 4,
      Set(records.map { NativeC01InquiryFixtureBodyAddress($0.binding) }).count == 4
    else { return false }
    guard let retirement else {
      return records.allSatisfy {
        if case .present = $0.presence { return true }
        return false
      }
    }
    guard retirement.shapeValid, retirement.revision > 0, retirement.revision <= revision,
      retirement.physicalTime.isFinite, retirement.physicalTime >= admissionPhysicalTime,
      retirement.physicalTime <= 1e12
    else { return false }
    switch retirement.cause {
    case .partDestroyed(let part, let incidentID):
      guard let record = records.first(where: { $0.part == part }),
        case .destroyed(let incident) = record.presence
      else { return false }
      return incident.id == incidentID && incident.physicalTime <= retirement.physicalTime
    case .sourceUnavailable, .supersededByAdmission, .caseClosed:
      // The outer owner must join the exact actual source/admission operation.
      return true
    }
  }
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryPartDestroyedCause: Codable, Sendable, Equatable {
  let part: NativeC01InquiryFixtureGeometry.Part
  let incidentID: UInt64
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryOperationCause: Codable, Sendable, Equatable {
  let operation: UUID
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryModelSnapshot: Codable, Sendable, Equatable {
  let physicalTime: Double
  let lastStep: NativeC01InquiryStepData?
  let head0: NativeC01InquiryHeadModelData
  let head1: NativeC01InquiryHeadModelData
  let head2: NativeC01InquiryHeadModelData
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryFixtureLife: Codable, Sendable, Equatable {
  let caseID: UUID
  let fixture: NativeC01InquiryFixtureRef
  let revision: UInt64
  let support: NativeC01InquiryPartLife
  let head0: NativeC01InquiryPartLife
  let head1: NativeC01InquiryPartLife
  let head2: NativeC01InquiryPartLife
  let modelSnapshot: NativeC01InquiryModelSnapshot
  let retirement: NativeC01InquiryFixtureRetirement?
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryPartLife: Codable, Sendable, Equatable {
  let binding: NativeC01InquiryFixtureBinding
  let pose: ShipPose
  let velocity: Vector3
  let angularVelocity: Vector3
  let energy: Double
  let physicalTime: Double
  let presence: NativeC01InquiryFixturePresence
  let bindingHistory: [NativeC01InquiryRebinding]
}

/// Retained DATA; decoding and shallow validation issue no live capability.
struct NativeC01InquiryRebinding: Codable, Sendable, Equatable {
  let operation: UUID
  let departure: NativeC01InquiryFixtureTransition
  let binding: NativeC01InquiryFixtureBinding
  let physicalTime: Double
  let historicalEpoch: UUID
}

extension NativeC01InquiryFixtureRetirement {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.revision(revision),
      NativeC01InquiryDataShape.time(physicalTime),
      cause.shapeValid
    else { return false }
    return true
  }
}

extension NativeC01InquiryPartDestroyedCause {
  var shapeValid: Bool {
    guard incidentID < UInt64.max
    else { return false }
    return true
  }
}

extension NativeC01InquiryOperationCause {
  var shapeValid: Bool {
    return true
  }
}

extension NativeC01InquiryModelSnapshot {
  var shapeValid: Bool {
    guard NativeC01InquiryDataShape.time(physicalTime),
      (lastStep.map { $0.shapeValid } ?? true),
      head0.shapeValid,
      head1.shapeValid,
      head2.shapeValid
    else { return false }
    return lastStep.map { $0.clockEnd == physicalTime } ?? true
  }
}

extension NativeC01InquiryFixtureLife {
  var shapeValid: Bool {
    guard fixture.shapeValid,
      NativeC01InquiryDataShape.revision(revision),
      support.shapeValid,
      head0.shapeValid,
      head1.shapeValid,
      head2.shapeValid,
      modelSnapshot.shapeValid,
      (retirement.map { $0.shapeValid } ?? true)
    else { return false }
    return fixture.generation > 0
      && [support, head0, head1, head2].enumerated().allSatisfy { index, part in
        part.binding.spawn.member == UInt16(index)
      }
  }
}

extension NativeC01InquiryPartLife {
  var shapeValid: Bool {
    guard binding.shapeValid,
      NativeC01InquiryDataShape.pose(pose),
      velocity.finite,
      angularVelocity.finite,
      energy.isFinite && energy >= 0 && energy.sign != .minus,
      NativeC01InquiryDataShape.time(physicalTime),
      presence.shapeValid,
      bindingHistory.count <= 16384,
      bindingHistory.allSatisfy({ $0.shapeValid })
    else { return false }
    switch presence {
    case .present: return energy > 0
    case .destroyed(let incident):
      return energy == 0 && incident.victim == binding.actor && incident.outcome == .destruction
        && incident.physicalTime <= physicalTime
    case .parked(let transition): return energy > 0 && transition.binding == binding && transition.physicalTime <= physicalTime
    case .removed(let transition): return transition.binding == binding && transition.physicalTime <= physicalTime
    }
  }
}

extension NativeC01InquiryRebinding {
  var shapeValid: Bool {
    guard departure.shapeValid,
      binding.shapeValid,
      NativeC01InquiryDataShape.time(physicalTime)
    else { return false }
    return binding.actor.system == departure.binding.actor.system
      && binding.actor != departure.binding.actor && binding.spawn != departure.binding.spawn
      && binding.spawn.member == departure.binding.spawn.member
      && NativeC01InquiryDataShape.adjacent(departure.binding.revision, binding.revision)
      && binding.operation == operation && physicalTime >= departure.physicalTime
  }
}

extension NativeC01InquiryFixturePresence {
  var shapeValid: Bool {
    switch self {
    case .present: return true
    case .destroyed(let value): return NativeC01InquiryDataShape.incident(value)
    case .parked(let value): return value.shapeValid
    case .removed(let value): return value.shapeValid
    }
  }
  init(from decoder: any Decoder) throws {
    let header = try decoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    let kind = try header.decode(String.self, forKey: .init("kind"))
    switch kind {
    case "present":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind"])
      _ = c
      self = .present
    case "destroyed":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(CombatIncident.self, forKey: .init("payload"))
      self = .destroyed(value)
    case "parked":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryFixtureTransition.self, forKey: .init("payload"))
      self = .parked(value)
    case "removed":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryFixtureTransition.self, forKey: .init("payload"))
      self = .removed(value)
    default:
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Unknown inquiry variant"))
    }
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    switch self {
    case .present:
      try c.encode("present", forKey: .init("kind"))
    case .destroyed(let value):
      try c.encode("destroyed", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .parked(let value):
      try c.encode("parked", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    case .removed(let value):
      try c.encode("removed", forKey: .init("kind"))
      try c.encode(value, forKey: .init("payload"))
    }
  }
}

extension NativeC01InquiryFixtureRetirementCause {
  var shapeValid: Bool {
    switch self {
    case .partDestroyed(_, let incidentID): return incidentID > 0 && incidentID < UInt64.max
    case .sourceUnavailable: return true
    case .supersededByAdmission: return true
    case .caseClosed: return true
    }
  }
  init(from decoder: any Decoder) throws {
    let header = try decoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    let kind = try header.decode(String.self, forKey: .init("kind"))
    switch kind {
    case "partDestroyed":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryPartDestroyedCause.self, forKey: .init("payload"))
      self = .partDestroyed(part: value.part, incidentID: value.incidentID)
    case "sourceUnavailable":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryOperationCause.self, forKey: .init("payload"))
      self = .sourceUnavailable(operation: value.operation)
    case "supersededByAdmission":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryOperationCause.self, forKey: .init("payload"))
      self = .supersededByAdmission(operation: value.operation)
    case "caseClosed":
      let c = try NativeC01InquiryDataCodec.object(decoder, required: ["kind", "payload"])
      let value = try c.decode(NativeC01InquiryOperationCause.self, forKey: .init("payload"))
      self = .caseClosed(operation: value.operation)
    default:
      throw DecodingError.dataCorrupted(.init(
        codingPath: decoder.codingPath, debugDescription: "Unknown inquiry variant"))
    }
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    switch self {
    case .partDestroyed(let part, let incidentID):
      try c.encode("partDestroyed", forKey: .init("kind"))
      try c.encode(NativeC01InquiryPartDestroyedCause(part: part, incidentID: incidentID), forKey: .init("payload"))
    case .sourceUnavailable(let operation):
      try c.encode("sourceUnavailable", forKey: .init("kind"))
      try c.encode(NativeC01InquiryOperationCause(operation: operation), forKey: .init("payload"))
    case .supersededByAdmission(let operation):
      try c.encode("supersededByAdmission", forKey: .init("kind"))
      try c.encode(NativeC01InquiryOperationCause(operation: operation), forKey: .init("payload"))
    case .caseClosed(let operation):
      try c.encode("caseClosed", forKey: .init("kind"))
      try c.encode(NativeC01InquiryOperationCause(operation: operation), forKey: .init("payload"))
    }
  }
}

extension NativeC01InquiryFixtureGeometryPins {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["support", "head0", "head1", "head2"])
    self.init(
      support: try c.decode(String.self, forKey: .init("support")),
      head0: try c.decode(String.self, forKey: .init("head0")),
      head1: try c.decode(String.self, forKey: .init("head1")),
      head2: try c.decode(String.self, forKey: .init("head2")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(support, forKey: .init("support"))
    try c.encode(head0, forKey: .init("head0"))
    try c.encode(head1, forKey: .init("head1"))
    try c.encode(head2, forKey: .init("head2"))
  }
}

extension NativeC01InquiryFixtureBinding {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["actor", "spawn", "bodyID", "revision", "operation"])
    self.init(
      actor: try c.decode(ActorIdentity.self, forKey: .init("actor")),
      spawn: try c.decode(SpawnIdentity.self, forKey: .init("spawn")),
      bodyID: try c.decode(Int.self, forKey: .init("bodyID")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      operation: try c.decode(UUID.self, forKey: .init("operation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(actor, forKey: .init("actor"))
    try c.encode(spawn, forKey: .init("spawn"))
    try c.encode(bodyID, forKey: .init("bodyID"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(operation, forKey: .init("operation"))
  }
}

extension NativeC01InquiryFixtureTransition {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "binding", "physicalTime", "historicalEpoch"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      binding: try c.decode(NativeC01InquiryFixtureBinding.self, forKey: .init("binding")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(binding, forKey: .init("binding"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
  }
}

extension NativeC01InquiryFixturePartState {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["part", "birthBinding", "binding", "birthPose", "pose", "velocity", "angularVelocity", "energy", "physicalTime", "presence"])
    self.init(
      part: try c.decode(NativeC01InquiryFixtureGeometry.Part.self, forKey: .init("part")),
      birthBinding: try c.decode(NativeC01InquiryFixtureBinding.self, forKey: .init("birthBinding")),
      binding: try c.decode(NativeC01InquiryFixtureBinding.self, forKey: .init("binding")),
      birthPose: try c.decode(ShipPose.self, forKey: .init("birthPose")),
      pose: try c.decode(ShipPose.self, forKey: .init("pose")),
      velocity: try c.decode(Vector3.self, forKey: .init("velocity")),
      angularVelocity: try c.decode(Vector3.self, forKey: .init("angularVelocity")),
      energy: try c.decode(Double.self, forKey: .init("energy")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      presence: try c.decode(NativeC01InquiryFixturePresence.self, forKey: .init("presence")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(part, forKey: .init("part"))
    try c.encode(birthBinding, forKey: .init("birthBinding"))
    try c.encode(binding, forKey: .init("binding"))
    try c.encode(birthPose, forKey: .init("birthPose"))
    try c.encode(pose, forKey: .init("pose"))
    try c.encode(velocity, forKey: .init("velocity"))
    try c.encode(angularVelocity, forKey: .init("angularVelocity"))
    try c.encode(energy, forKey: .init("energy"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(presence, forKey: .init("presence"))
  }
}

extension NativeC01InquiryFixtureRetirement {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "revision", "physicalTime", "cause"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      cause: try c.decode(NativeC01InquiryFixtureRetirementCause.self, forKey: .init("cause")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(cause, forKey: .init("cause"))
  }
}

extension NativeC01InquiryFixtureGeneration {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["owner", "caseID", "caseOrdinal", "sourceBirth", "sourceRevision", "fixtureID", "generation", "revision", "admissionOperation", "admissionArrival", "admissionPhysicalTime", "inertialFrame", "placementCandidate", "geometryRevision", "geometryPins", "metricRevision", "metresPerWorldUnit", "lawRevision", "support", "head0", "head1", "head2", "modelSnapshot"],
      optional: ["retirement"])
    self.init(
      owner: try c.decode(UUID.self, forKey: .init("owner")),
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      caseOrdinal: try c.decode(UInt64.self, forKey: .init("caseOrdinal")),
      sourceBirth: try c.decode(UUID.self, forKey: .init("sourceBirth")),
      sourceRevision: try c.decode(UInt64.self, forKey: .init("sourceRevision")),
      fixtureID: try c.decode(UUID.self, forKey: .init("fixtureID")),
      generation: try c.decode(UInt64.self, forKey: .init("generation")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      admissionOperation: try c.decode(UUID.self, forKey: .init("admissionOperation")),
      admissionArrival: try c.decode(NativeMainStationDockReceipt.self, forKey: .init("admissionArrival")),
      admissionPhysicalTime: try c.decode(Double.self, forKey: .init("admissionPhysicalTime")),
      inertialFrame: try c.decode(ShipPose.self, forKey: .init("inertialFrame")),
      placementCandidate: try c.decode(UInt64.self, forKey: .init("placementCandidate")),
      geometryRevision: try c.decode(String.self, forKey: .init("geometryRevision")),
      geometryPins: try c.decode(NativeC01InquiryFixtureGeometryPins.self, forKey: .init("geometryPins")),
      metricRevision: try c.decode(String.self, forKey: .init("metricRevision")),
      metresPerWorldUnit: try c.decode(Double.self, forKey: .init("metresPerWorldUnit")),
      lawRevision: try c.decode(String.self, forKey: .init("lawRevision")),
      support: try c.decode(NativeC01InquiryFixturePartState.self, forKey: .init("support")),
      head0: try c.decode(NativeC01InquiryFixturePartState.self, forKey: .init("head0")),
      head1: try c.decode(NativeC01InquiryFixturePartState.self, forKey: .init("head1")),
      head2: try c.decode(NativeC01InquiryFixturePartState.self, forKey: .init("head2")),
      retirement: try c.decodeIfPresent(NativeC01InquiryFixtureRetirement.self, forKey: .init("retirement")),
      modelSnapshot: try c.decode(NativeC01InquiryModelSnapshot.self, forKey: .init("modelSnapshot")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(owner, forKey: .init("owner"))
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(caseOrdinal, forKey: .init("caseOrdinal"))
    try c.encode(sourceBirth, forKey: .init("sourceBirth"))
    try c.encode(sourceRevision, forKey: .init("sourceRevision"))
    try c.encode(fixtureID, forKey: .init("fixtureID"))
    try c.encode(generation, forKey: .init("generation"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(admissionOperation, forKey: .init("admissionOperation"))
    try c.encode(admissionArrival, forKey: .init("admissionArrival"))
    try c.encode(admissionPhysicalTime, forKey: .init("admissionPhysicalTime"))
    try c.encode(inertialFrame, forKey: .init("inertialFrame"))
    try c.encode(placementCandidate, forKey: .init("placementCandidate"))
    try c.encode(geometryRevision, forKey: .init("geometryRevision"))
    try c.encode(geometryPins, forKey: .init("geometryPins"))
    try c.encode(metricRevision, forKey: .init("metricRevision"))
    try c.encode(metresPerWorldUnit, forKey: .init("metresPerWorldUnit"))
    try c.encode(lawRevision, forKey: .init("lawRevision"))
    try c.encode(support, forKey: .init("support"))
    try c.encode(head0, forKey: .init("head0"))
    try c.encode(head1, forKey: .init("head1"))
    try c.encode(head2, forKey: .init("head2"))
    try c.encodeIfPresent(retirement, forKey: .init("retirement"))
    try c.encode(modelSnapshot, forKey: .init("modelSnapshot"))
  }
}

extension NativeC01InquiryPartDestroyedCause {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["part", "incidentID"])
    self.init(
      part: try c.decode(NativeC01InquiryFixtureGeometry.Part.self, forKey: .init("part")),
      incidentID: try c.decode(UInt64.self, forKey: .init("incidentID")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(part, forKey: .init("part"))
    try c.encode(incidentID, forKey: .init("incidentID"))
  }
}

extension NativeC01InquiryOperationCause {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
  }
}

extension NativeC01InquiryModelSnapshot {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["physicalTime", "head0", "head1", "head2"],
      optional: ["lastStep"])
    self.init(
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      lastStep: try c.decodeIfPresent(NativeC01InquiryStepData.self, forKey: .init("lastStep")),
      head0: try c.decode(NativeC01InquiryHeadModelData.self, forKey: .init("head0")),
      head1: try c.decode(NativeC01InquiryHeadModelData.self, forKey: .init("head1")),
      head2: try c.decode(NativeC01InquiryHeadModelData.self, forKey: .init("head2")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encodeIfPresent(lastStep, forKey: .init("lastStep"))
    try c.encode(head0, forKey: .init("head0"))
    try c.encode(head1, forKey: .init("head1"))
    try c.encode(head2, forKey: .init("head2"))
  }
}

extension NativeC01InquiryFixtureLife {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["caseID", "fixture", "revision", "support", "head0", "head1", "head2", "modelSnapshot"],
      optional: ["retirement"])
    self.init(
      caseID: try c.decode(UUID.self, forKey: .init("caseID")),
      fixture: try c.decode(NativeC01InquiryFixtureRef.self, forKey: .init("fixture")),
      revision: try c.decode(UInt64.self, forKey: .init("revision")),
      support: try c.decode(NativeC01InquiryPartLife.self, forKey: .init("support")),
      head0: try c.decode(NativeC01InquiryPartLife.self, forKey: .init("head0")),
      head1: try c.decode(NativeC01InquiryPartLife.self, forKey: .init("head1")),
      head2: try c.decode(NativeC01InquiryPartLife.self, forKey: .init("head2")),
      modelSnapshot: try c.decode(NativeC01InquiryModelSnapshot.self, forKey: .init("modelSnapshot")),
      retirement: try c.decodeIfPresent(NativeC01InquiryFixtureRetirement.self, forKey: .init("retirement")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(caseID, forKey: .init("caseID"))
    try c.encode(fixture, forKey: .init("fixture"))
    try c.encode(revision, forKey: .init("revision"))
    try c.encode(support, forKey: .init("support"))
    try c.encode(head0, forKey: .init("head0"))
    try c.encode(head1, forKey: .init("head1"))
    try c.encode(head2, forKey: .init("head2"))
    try c.encode(modelSnapshot, forKey: .init("modelSnapshot"))
    try c.encodeIfPresent(retirement, forKey: .init("retirement"))
  }
}

extension NativeC01InquiryPartLife {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["binding", "pose", "velocity", "angularVelocity", "energy", "physicalTime", "presence", "bindingHistory"])
    self.init(
      binding: try c.decode(NativeC01InquiryFixtureBinding.self, forKey: .init("binding")),
      pose: try c.decode(ShipPose.self, forKey: .init("pose")),
      velocity: try c.decode(Vector3.self, forKey: .init("velocity")),
      angularVelocity: try c.decode(Vector3.self, forKey: .init("angularVelocity")),
      energy: try c.decode(Double.self, forKey: .init("energy")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      presence: try c.decode(NativeC01InquiryFixturePresence.self, forKey: .init("presence")),
      bindingHistory: try c.decode([NativeC01InquiryRebinding].self, forKey: .init("bindingHistory")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(binding, forKey: .init("binding"))
    try c.encode(pose, forKey: .init("pose"))
    try c.encode(velocity, forKey: .init("velocity"))
    try c.encode(angularVelocity, forKey: .init("angularVelocity"))
    try c.encode(energy, forKey: .init("energy"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(presence, forKey: .init("presence"))
    try c.encode(bindingHistory, forKey: .init("bindingHistory"))
  }
}

extension NativeC01InquiryRebinding {
  init(from decoder: any Decoder) throws {
    let c = try NativeC01InquiryDataCodec.object(
      decoder, required: ["operation", "departure", "binding", "physicalTime", "historicalEpoch"])
    self.init(
      operation: try c.decode(UUID.self, forKey: .init("operation")),
      departure: try c.decode(NativeC01InquiryFixtureTransition.self, forKey: .init("departure")),
      binding: try c.decode(NativeC01InquiryFixtureBinding.self, forKey: .init("binding")),
      physicalTime: try c.decode(Double.self, forKey: .init("physicalTime")),
      historicalEpoch: try c.decode(UUID.self, forKey: .init("historicalEpoch")))
    try NativeC01InquiryDataCodec.requireShape(shapeValid, decoder: decoder)
  }
  func encode(to encoder: any Encoder) throws {
    try NativeC01InquiryDataCodec.requireShape(self, valid: shapeValid, encoder: encoder)
    var c = encoder.container(keyedBy: NativeC01InquiryDataCodec.Key.self)
    try c.encode(operation, forKey: .init("operation"))
    try c.encode(departure, forKey: .init("departure"))
    try c.encode(binding, forKey: .init("binding"))
    try c.encode(physicalTime, forKey: .init("physicalTime"))
    try c.encode(historicalEpoch, forKey: .init("historicalEpoch"))
  }
}

extension NativeC01InquiryFixtureLife {
  // Compare chain membership, never a closed case's old pose/energy to today's body.
  func matchesBirthChains(_ generation: NativeC01InquiryFixtureGeneration) -> Bool {
    let current = [support, head0, head1, head2]
    for (index, historical) in generation.parts.enumerated() {
      let part = current[index]
      var previous = historical.birthBinding
      var historicalBindingSeen = previous == historical.binding
      var previousTime = generation.admissionPhysicalTime
      var operations = Set<UUID>()
      for rebind in part.bindingHistory {
        guard rebind.departure.binding == previous,
          rebind.departure.physicalTime >= previousTime,
          operations.insert(rebind.operation).inserted
        else { return false }
        previous = rebind.binding
        previousTime = rebind.physicalTime
        historicalBindingSeen = historicalBindingSeen || previous == historical.binding
      }
      guard part.binding == previous, part.physicalTime >= previousTime, historicalBindingSeen,
        part.energy <= NativeC01InquiryFixtureGeometry.physicalBudget(for: historical.part).energy
      else { return false }
    }
    return true
  }
}
