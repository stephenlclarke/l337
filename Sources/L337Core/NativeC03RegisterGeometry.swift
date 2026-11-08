import Foundation

/// Original archive appearance and close-range interaction measurements are project estimates.
/// The optical face is a component target, never a docking/service port or a crew provider.
enum NativeC03RegisterGeometry {
  enum Failure: Error { case invalidAnchors }
  static let rootModel = "asset:c03-register-archive"
  static let faceModel = "asset:c03-register-optical-face"
  static let profileID = "c03-original-register-archive"
  static let component = NativeC03CustodyRegisterContent.target
  static let componentPosition = Vector3(0, 0, 0.76)
  static let surfaceRange = 50.0...150.0
  static let maximumTargetAngle = 2.0 * Double.pi / 180
  static let maximumRelativeSpeed = 1.0
  static let maximumProbeAngle = 0.000004
  static let maximumHeightError = 0.005
  static let plateHeight = 0.02
  static let reliefHeights = [0.015, 0.025, 0.035]
  static let rootDesign = boxes([
    (.init(0, 0, -0.75), .init(2, 1.4, 1.5)),
  ], source: "L337 original C03 register archive; project-estimated geometry; metres")
  static let faceDesign: ShipDesign = {
    var parts: [(Vector3, Vector3)] = [(.init(0, 0, 0), .init(1.2, 0.8, plateHeight))]
    for (index, height) in reliefHeights.enumerated() {
      parts.append((.init(Double(index - 1) * 0.35, 0, plateHeight), .init(0.12, 0.3, height)))
    }
    return boxes(parts, source: "L337 original C03 register optical face; project-estimated geometry; metres")
  }()

  static let profile = ScriptNPCDefinition(
    id: profileID, name: "Original custody-register archive",
    source: NativeHollowManifestDefinition.logicalSourceID,
    basis: "Project-estimated finite passive data archive; no ship/service/crew capability",
    model: rootModel, scale: 1, energy: 16, recharge: 0, speed: 0, acceleration: 0,
    pitch: 0, yaw: 0, roll: 0, missiles: 0, fuel: 0, drive: nil, ecm: false, bounty: 0,
    lasers: [], components: [
      .init(
        id: component, model: faceModel, scale: 1, position: componentPosition,
        orientation: .init(), energy: 1, solid: true, weapons: []),
    ])

  struct Hashes: Sendable {
    let root: String
    let face: String
  }
  static let hashes: Result<Hashes, any Error> = Result {
    .init(
      root: ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(rootDesign)),
      face: ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(faceDesign)))
  }

  /// FIRST source placement in canonical world coordinates, not a docking/launch corridor.
  /// Actual archive motion and this first frame must subsequently survive every unload.
  static func candidateFrame(anchors: SystemAnchors) throws -> ShipPose {
    let world = NativeHollowManifestDefinition.registerWorld
    guard anchors.system == world, anchors.station.identity.system == world,
      anchors.station.identity.entity == 1, anchors.station.identity.visit > 0,
      anchors.station.position.finite, anchors.planet.position.finite,
      anchors.station.position.length.isFinite, anchors.planet.position.length.isFinite,
      anchors.station.orientation.validRotation,
      anchors.station.exitPosition.finite, anchors.station.exitDirection.finite,
      anchors.sun.position.finite, anchors.arrival.finite,
      anchors.planet.radius.isFinite, anchors.planet.radius > 0,
      anchors.sun.radius.isFinite, anchors.sun.radius > 0
    else { throw Failure.invalidAnchors }
    let separation = anchors.station.position - anchors.planet.position
    guard separation.length.isFinite, separation.length > 1e-6 else { throw Failure.invalidAnchors }
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
    let position = anchors.station.position + normal * 6000 + across * 1200
    guard position.finite, position.length.isFinite, basis.validRotation else {
      throw Failure.invalidAnchors
    }
    return .init(position: position, orientation: basis)
  }

  static var probeCentres: [Vector3] {
    [.init(0, 0.3, plateHeight)] + reliefHeights.enumerated().map { index, height in
      .init(Double(index - 1) * 0.35, 0, plateHeight + height)
    }
  }

  private static func boxes(_ parts: [(Vector3, Vector3)], source: String) -> ShipDesign {
    var vertices: [[Double]] = []
    var faces: [[Int]] = []
    let corners: [(Double, Double, Double)] = [
      (0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0),
      (0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1),
    ]
    let quads = [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [3, 7, 6, 2], [0, 4, 7, 3], [1, 2, 6, 5],
    ]
    for (centre, size) in parts {
      let start = vertices.count
      for (x, y, z) in corners {
        vertices.append([
          centre.x + (x - 0.5) * size.x, centre.y + (y - 0.5) * size.y, centre.z + z * size.z,
        ])
      }
      for quad in quads {
        faces.append([quad[0], quad[1], quad[2]].map { start + $0 })
        faces.append([quad[0], quad[2], quad[3]].map { start + $0 })
      }
    }
    return .init(vertices: vertices, faces: faces, license: "MIT", source: source)
  }
}
