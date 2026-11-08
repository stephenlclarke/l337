import Foundation

struct NativeC01LaneRepairSource: Codable, Sendable, Equatable {
  let mission: UUID
  let permission: UUID
  let owner: UUID
  let audit: UUID
  let recorder: UUID
  let standard: UUID
  let anchors: SystemAnchors
  let reference: ShipPose
  let visit: UInt64
  let physicalTime: Double

  var valid: Bool {
    var flight = FlightSimulationState()
    flight.enter(NativeC01LaneRepair.location, arriving: true)
    guard let expected = flight.anchors else { return false }
    return anchors.system == NativeC01LaneRepair.location
      && anchors.planet == expected.planet && anchors.sun == expected.sun
      && anchors.station.position == expected.station.position
      && reference.position.finite && reference.orientation.validRotation
      && visit > 0 && visit < UInt64(Int64.max)
      && physicalTime.isFinite && (0...1e12).contains(physicalTime)
  }

  func position(_ target: NativeC01LaneRepair.Target) -> Vector3 {
    anchors.station.position + target.offset
  }
}

/// A current explicitly armed action; loading this fact never creates a live work token.
struct NativeC01LaneRepairArm: Codable, Sendable, Equatable {
  let operation: UUID
  let mission: UUID
  let permission: UUID
  let standard: UUID
  let target: NativeC01LaneRepair.Target
  let actor: ActorIdentity
  let player: ActorIdentity
  let owner: UUID
  let carrier: UUID
  let inventoryRevision: UInt64
  let epoch: UUID
  let physicalTime: Double
}

struct NativeC01LaneRepairSegment: Codable, Sendable, Equatable {
  let arm: NativeC01LaneRepairArm
  var first: Double?
  var last: Double?
  var seconds: Double = 0
  var intervals: UInt64 = 0
  var lastRange: Double?
  var lastSpeed: Double?
  var lastAim: Double?
}

struct NativeC01LaneRepairProgress: Codable, Sendable, Equatable {
  let target: NativeC01LaneRepair.Target
  var segments: [NativeC01LaneRepairSegment] = []
  // Explicit current rearming after fully measured work; this is never a live capability.
  var completionArm: NativeC01LaneRepairArm?
  var seconds: Double { segments.reduce(0) { $0 + $1.seconds } }
}

/// Historical facts from a fresh attained qualified interval, separate from credited work.
struct NativeC01LaneRepairConfirmation: Codable, Sendable, Equatable {
  let arm: NativeC01LaneRepairArm
  let start: Double
  let end: Double
  let startRange: Double
  let endRange: Double
  let startSpeed: Double
  let endSpeed: Double
  let startAim: Double
  let endAim: Double
}

private struct NativeC01LaneRepairEvidence: Codable {
  let segments: [NativeC01LaneRepairSegment]
  let confirmation: NativeC01LaneRepairConfirmation
}

struct NativeC01LaneRepairReceipt: Codable, Sendable, Equatable {
  let operation: UUID
  let target: NativeC01LaneRepair.Target
  let actor: ActorIdentity
  let history: String
  let confirmation: NativeC01LaneRepairConfirmation
  let sequence: UInt64
  let physicalTime: Double
}

/// Installation consumes the captured physical standard; it is distinct from genuine loss.
struct NativeC01TimingStandardUse: Codable, Sendable, Equatable {
  let operation: UUID
  let mission: UUID
  let permission: UUID
  let owner: UUID
  let standard: UUID
  let recorder: UUID
  let calibrations: [UUID]
  let sequence: UInt64
  let physicalTime: Double
}

struct NativeC01LaneRepairState: Codable, Sendable, Equatable {
  let source: NativeC01LaneRepairSource
  var progress: [NativeC01LaneRepairProgress] = []
  var receipts: [NativeC01LaneRepairReceipt] = []
  var installation: NativeC01TimingStandardUse?
}

enum NativeC01LaneRepair {
  static let location = SystemIdentity(galaxy: 0, system: 91)
  static let encounter = "meridian-lane-relays"
  static let receipt = "c01-rebuild-lane"
  static let qualifiedSeconds = 20.0
  // Existing native positive physical-step ceiling; also bounds fresh confirmation evidence.
  static let maximumPhysicalInterval = 0.100001
  static let maximumSegments = 64

  enum Target: String, Codable, Sendable, CaseIterable, Hashable {
    case inner = "relay-inner"
    case middle = "relay-middle"
    case outer = "relay-outer"

    /// New C01 authoring layout, reusing the existing original native survey arrangement.
    /// These are system-world offsets from SystemAnchors.station.position, not view coordinates.
    var offset: Vector3 {
      switch self {
      case .inner: .init(-5000, 0, 20000)
      case .middle: .init(0, 4000, 24000)
      case .outer: .init(5000, 0, 28000)
      }
    }
  }

  static func actor(source: NativeC01LaneRepairSource, target: Target) -> UUID {
    ScriptIdentity.uuid(
      "script-actor-v2:\(source.mission):\(NativeGlassMeridian.digest):\(encounter):\(target.rawValue)")
  }

  static func qualifies(range: Double, speed: Double, aim: Double) -> Bool {
    range.isFinite && (50...150).contains(range)
      && speed.isFinite && (0...1).contains(speed)
      && aim.isFinite && (0...(2 * Double.pi / 180)).contains(aim)
  }

  /// Only actual attained endpoints may reach this helper through the private live observer.
  static func credit(before: Double, start: Double, end: Double) -> Double? {
    guard before.isFinite, (0...(qualifiedSeconds + 1e-8)).contains(before),
      start.isFinite, end.isFinite, start >= 0, end > start,
      end <= 1e12, end - start <= maximumPhysicalInterval
    else { return nil }
    return max(0, min(qualifiedSeconds - before, end - start))
  }

  static func history(
    _ progress: NativeC01LaneRepairProgress, confirmation: NativeC01LaneRepairConfirmation
  ) throws -> String {
    try NativeFlightReception.hash(
      NativeC01LaneRepairEvidence(segments: progress.segments, confirmation: confirmation))
  }

  static func calibrationOperation(
    source: NativeC01LaneRepairSource, target: Target, history: String
  ) -> UUID {
    ScriptIdentity.uuid(
      "c01-lane-calibration-v1:\(source.mission):\(source.permission):\(source.standard):\(target.rawValue):\(history)")
  }

  static func installationOperation(
    source: NativeC01LaneRepairSource, calibrations: [UUID]
  ) -> UUID {
    ScriptIdentity.uuid(
      "c01-lane-standard-use-v1:\(source.mission):\(source.permission):\(source.standard):"
        + calibrations.map(\.uuidString).joined(separator: ":"))
  }
}
