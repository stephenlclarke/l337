import Foundation

/// Original C03 content declares three cargo-handler wake marks, not their physical recipe.
/// These passive fragments and dimensions are project-authored estimates, not historical data.
enum NativeC03WakeGeometry {
  enum Mark: String, CaseIterable, Codable, Sendable {
    case first = "wake-one"
    case second = "wake-two"
    case third = "wake-three"

    var index: Int {
      switch self {
      case .first: 0
      case .second: 1
      case .third: 2
      }
    }
    var model: String { "asset:c03-" + rawValue }
    var profile: String { "c03-" + rawValue }
  }

  enum Failure: Error { case invalidAnchors }
  static let world = NativeHollowManifestDefinition.carrierWorld
  static let surfaceRange = 250.0...1500.0
  static let maximumProbeAngle = 0.000004
  static let maximumHeightError = 0.005
  static let maximumTargetAngle = 2.0 * Double.pi / 180
  static let plateHeight = 0.25

  /// A geometric reading is not a source, actor admission, kit-custody or mission receipt.
  static func reliefHeights(_ mark: Mark) -> [Double] {
    let values = [0.08, 0.12, 0.16]
    return (0..<3).map { values[($0 + mark.index) % values.count] }
  }

  static func probeCentres(_ mark: Mark) -> [Vector3] {
    [.init(0, 1.5, plateHeight)] + reliefHeights(mark).enumerated().map { index, height in
      .init(Double(index - 1) * 3, 0, plateHeight + height)
    }
  }

  private static let designs = Mark.allCases.map(makeDesign)
  private static let profiles = Mark.allCases.map(makeProfile)
  private static let geometryHashes: Result<[String], any Error> = Result {
    try designs.map { ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry($0)) }
  }

  static func design(_ mark: Mark) -> ShipDesign { designs[mark.index] }
  static func profile(_ mark: Mark) -> ScriptNPCDefinition { profiles[mark.index] }
  static func geometryHash(_ mark: Mark) throws -> String { try geometryHashes.get()[mark.index] }

  private static func makeDesign(_ mark: Mark) -> ShipDesign {
    var vertices: [[Double]] = []
    var faces: [[Int]] = []
    let corners: [(Double, Double, Double)] = [
      (0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0),
      (0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1),
    ]
    let quads = [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ]
    func append(centre: Vector3, size: Vector3) {
      let start = vertices.count
      for (x, y, z) in corners {
        vertices.append([
          centre.x + (x - 0.5) * size.x, centre.y + (y - 0.5) * size.y,
          centre.z + z * size.z,
        ])
      }
      for quad in quads {
        faces.append([quad[0], quad[1], quad[2]].map { start + $0 })
        faces.append([quad[0], quad[2], quad[3]].map { start + $0 })
      }
    }
    append(centre: .init(0, 0, 0), size: .init(10, 4, plateHeight))
    for (index, height) in reliefHeights(mark).enumerated() {
      append(
        centre: .init(Double(index - 1) * 3, 0, plateHeight), size: .init(0.8, 2, height))
    }
    return .init(
      vertices: vertices, faces: faces, license: "MIT",
      source: "L337 original C03 \(mark.rawValue); project-estimated passive residue geometry; metres")
  }

  /// Bridge fit for a passive solid, not a spacecraft: no drive, crew, cargo, weapons or power.
  private static func makeProfile(_ mark: Mark) -> ScriptNPCDefinition {
    .init(
      id: mark.profile, name: "Cargo-handler wake mark \(mark.index + 1)",
      source: NativeHollowManifestDefinition.logicalSourceID,
      basis: "Project-estimated inert wake fragment; no docking or ship capability",
      model: mark.model, scale: 1, energy: 1, recharge: 0, speed: 0, acceleration: 0,
      pitch: 0, yaw: 0, roll: 0, missiles: 0, fuel: 0, drive: nil, ecm: false,
      bounty: 0, lasers: [], components: [])
  }

  struct Layout: Sendable {
    let reference: ShipPose
    let positions: [Vector3]
  }

  static func declaration(anchors: SystemAnchors) throws -> ScriptEncounterDefinition {
    let layout = try candidateLayout(anchors: anchors)
    return .init(
      id: NativeC03WakeTrail.encounter, galaxy: world.galaxy, system: world.system,
      profile: "profiled-local-freeze-v1",
      actors: Mark.allCases.map { mark in
        let point = layout.reference.shipPoint(layout.positions[mark.index])
        return .init(
          id: mark.rawValue, hull: nil, npc: mark.profile,
          x: point.x, y: point.y, z: point.z, hostile: false)
      })
  }

  /// Candidate FIRST-source layout only. Saved or live objects must retain their actual poses.
  /// The last mark supplies a search bearing; it creates no cradle, service or docking port.
  static func candidateLayout(anchors: SystemAnchors) throws -> Layout {
    guard anchors.system == world, anchors.station.identity.system == world,
      anchors.station.identity.entity == 1, anchors.station.identity.visit > 0,
      anchors.station.position.finite, anchors.planet.position.finite,
      anchors.station.position.length.isFinite, anchors.planet.position.length.isFinite,
      anchors.station.orientation.validRotation,
      anchors.station.exitPosition.finite, anchors.station.exitDirection.finite,
      anchors.arrival.finite, anchors.sun.position.finite,
      anchors.planet.radius.isFinite, anchors.planet.radius > 0,
      anchors.sun.radius.isFinite, anchors.sun.radius > 0
    else { throw Failure.invalidAnchors }
    let separation = anchors.station.position - anchors.planet.position
    guard separation.length.isFinite, separation.length > 1e-6 else {
      throw Failure.invalidAnchors
    }
    let normal = separation.unit
    var axis = Vector3(1, 0, 0)
    for candidate in [Vector3(0, 1, 0), Vector3(0, 0, 1)] {
      if abs(candidate.dot(normal)) < abs(axis.dot(normal)) { axis = candidate }
    }
    let across = axis.cross(normal).unit
    var basis = Basis3()
    basis.x = across
    basis.y = normal.cross(across) * -1
    basis.z = normal * -1
    let positions = Mark.allCases.map { mark in
      anchors.station.position + normal * (12_000 + Double(mark.index) * 6000)
        + across * [0.0, 1800.0, -1200.0][mark.index]
    }
    guard basis.validRotation, positions.allSatisfy({ $0.finite && $0.length.isFinite }) else {
      throw Failure.invalidAnchors
    }
    return .init(reference: .init(position: positions[0], orientation: basis), positions: positions)
  }
}
