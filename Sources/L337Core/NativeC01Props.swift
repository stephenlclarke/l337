import Foundation

/// Two fixed, project-owned C01 props. This does not extend the ship catalogue or script model API.
enum NativeC01Props {
  enum Kind: Sendable, Equatable {
    case relay, standard
    var id: String { self == .relay ? "c01-relay-node" : "c01-timing-standard" }
    var file: String { self == .relay ? "relay-node.json" : "timing-standard.json" }
    var recipe: String { self == .relay ? "relay-node.toml" : "timing-standard.toml" }
    var recipeSHA256: String {
      self == .relay
        ? "d72901d8bf80d85d3e9290e58c510332d0d6f07d558b7566ff80b0cf3a167cc0"
        : "f788022916b0557a1f69eaa6ef68340a8b3d605d7b32ab091fd58aaa68e740b8"
    }
    var sourcePath: String {
      "l337-content-proposal/mission-artwork/props/" + recipe
    }
    var metresPerSourceUnit: Double { self == .relay ? 8 : 1 }
    var energy: Double { self == .relay ? 100 : 16 }
  }

  struct StructuralPolicy: Codable, Sendable, Equatable {
    let energy: Double
    let recharge: Double
    let shields: Double
    let fuel: Double
    let missiles: Int
    let ecm: Bool
    let weapons: Bool
    let drive: Bool
    let crew: Int

    func valid(_ kind: Kind) -> Bool {
      energy.isFinite && energy == kind.energy && recharge == 0 && shields == 0 && fuel == 0
        && missiles == 0 && !ecm && !weapons && !drive && crew == 0
    }
  }

  struct InteractionFace: Codable, Sendable, Equatable {
    let center: Vector3
    let outward: Vector3
    let up: Vector3
    let polygon: [Vector3]
    let nativeFaceIndices: [Int]
    private static let tolerance = 1e-5
    private var right: Vector3 { up.cross(outward) }

    func valid(in design: ShipDesign) -> Bool {
      guard design.valid, center.finite, outward.finite, up.finite,
        abs(outward.length - 1) < 1e-8, abs(up.length - 1) < 1e-8,
        abs(outward.dot(up)) < 1e-8, (3...64).contains(polygon.count),
        polygon.allSatisfy({ $0.finite && $0.z == 0 }),
        !nativeFaceIndices.isEmpty, nativeFaceIndices.count <= 512,
        Set(nativeFaceIndices).count == nativeFaceIndices.count,
        nativeFaceIndices.allSatisfy(design.faces.indices.contains)
      else { return false }
      for index in polygon.indices {
        let a = polygon[index]
        let next = (index + 1) % polygon.count
        let edge = polygon[next] - a
        guard edge.length.isFinite, edge.length > 0 else { return false }
        for other in polygon.indices where other != index && other != next {
          let cross = edge.x * (polygon[other].y - a.y) - edge.y * (polygon[other].x - a.x)
          guard cross.isFinite, cross > 0 else { return false }
        }
      }
      for index in nativeFaceIndices {
        let face = design.faces[index]
        guard face.count == 3 else { return false }
        let points = face.map { vector(design.vertices[$0]) }
        let normal = (points[1] - points[0]).cross(points[2] - points[0])
        guard normal.finite, normal.length > 1e-10,
          normal.unit.dot(outward) > 1 - 1e-7,
          points.allSatisfy({ abs(($0 - center).dot(outward)) <= Self.tolerance })
        else { return false }
      }
      var probes = polygon.map { center + right * $0.x + up * $0.y }
      probes.append(center + right * (polygon.reduce(0) { $0 + $1.x } / Double(polygon.count))
        + up * (polygon.reduce(0) { $0 + $1.y } / Double(polygon.count)))
      return probes.allSatisfy { triangleContains($0, in: design) }
    }

    func contains(_ point: Vector3, in design: ShipDesign) -> Bool {
      // The immutable record validates this face once at load; keep the live point query bounded.
      guard point.finite, center.finite, outward.finite, up.finite,
        (3...64).contains(polygon.count), !nativeFaceIndices.isEmpty,
        nativeFaceIndices.allSatisfy({ index in
          design.faces.indices.contains(index) && design.faces[index].count == 3
            && design.faces[index].allSatisfy { vertex in
              design.vertices.indices.contains(vertex) && design.vertices[vertex].count == 3
                && design.vertices[vertex].allSatisfy(\.isFinite)
            }
        })
      else { return false }
      let offset = point - center
      guard abs(offset.dot(outward)) <= Self.tolerance else { return false }
      let x = offset.dot(right)
      let y = offset.dot(up)
      for index in polygon.indices {
        let a = polygon[index]
        let b = polygon[(index + 1) % polygon.count]
        let cross = (b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x)
        guard cross.isFinite, cross >= -Self.tolerance * (b - a).length else { return false }
      }
      return triangleContains(point, in: design)
    }

    private func triangleContains(_ point: Vector3, in design: ShipDesign) -> Bool {
      nativeFaceIndices.contains { index in
        let face = design.faces[index]
        let vertices = face.map { vector(design.vertices[$0]) }
        guard vertices.count == 3 else { return false }
        let normal = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
        guard normal.finite, normal.length > 1e-10 else { return false }
        let unit = normal.unit
        guard abs((point - vertices[0]).dot(unit)) <= Self.tolerance else { return false }
        return vertices.indices.allSatisfy { i in
          let edge = vertices[(i + 1) % 3] - vertices[i]
          let cross = edge.cross(point - vertices[i]).dot(unit)
          return cross.isFinite && cross >= -Self.tolerance * edge.length
        }
      }
    }

    private func vector(_ values: [Double]) -> Vector3 {
      .init(values[0], values[1], values[2])
    }
  }

  struct Record: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let id: String
    let sourcePath: String
    let sourceSHA256: String
    let metresPerSourceUnit: Double
    let massKilograms: Double
    let design: ShipDesign
    let nativeDesign: ShipDesign
    let interactionFace: InteractionFace
    let structuralPolicy: StructuralPolicy
  }

  private static let relayResourceSHA256 =
    "d85b7772ead49584d20c83ac1510c6fb3b8ea2869213c324134e3b7914086714"
  private static let standardResourceSHA256 =
    "858220b86b7b1b293aaf288803e9b389ef1005c6fa55fb90eeaaef835a468336"
  static let relay: Result<Record, any Error> = Result {
    try load(.relay, expectedSHA256: relayResourceSHA256)
  }
  static let standard: Result<Record, any Error> = Result {
    try load(.standard, expectedSHA256: standardResourceSHA256)
  }

  static let relayModelHash: Result<String, any Error> = Result {
    ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(relay.get().nativeDesign))
  }

  private static func load(_ kind: Kind, expectedSHA256: String) throws -> Record {
    let url = ScriptPackLibrary.bundledGlassMeridianDirectory
      .appendingPathComponent("native-props").appendingPathComponent(kind.file)
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard let size = attributes[.size] as? NSNumber, (1...4_194_304).contains(size.intValue) else {
      throw SaveError.invalidCommander
    }
    let bytes = try Data(contentsOf: url)
    guard bytes.count == size.intValue, ScriptPackLibrary.hash(bytes) == expectedSHA256 else {
      throw SaveError.invalidCommander
    }
    return try decode(bytes, kind: kind)
  }

  static func decode(_ bytes: Data, kind: Kind) throws -> Record {
    guard !bytes.isEmpty, bytes.count <= 4_194_304 else { throw SaveError.invalidCommander }
    try ScriptSaveJSONPreflight.validate(bytes)
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      Set(root.keys) == Set([
        "schemaVersion", "id", "sourcePath", "sourceSHA256", "metresPerSourceUnit", "massKilograms",
        "design", "nativeDesign", "interactionFace", "structuralPolicy",
      ]), let face = root["interactionFace"] as? [String: Any],
      Set(face.keys) == Set(["center", "outward", "up", "polygon", "nativeFaceIndices"]),
      let policy = root["structuralPolicy"] as? [String: Any],
      Set(policy.keys) == Set([
        "energy", "recharge", "shields", "fuel", "missiles", "ecm", "weapons", "drive", "crew",
      ])
    else { throw SaveError.invalidCommander }
    let record = try JSONDecoder().decode(Record.self, from: bytes)
    guard record.schemaVersion == 1, record.id == kind.id,
      record.sourceSHA256 == kind.recipeSHA256,
      record.sourcePath == kind.sourcePath,
      record.metresPerSourceUnit == kind.metresPerSourceUnit,
      record.massKilograms.isFinite, record.massKilograms > 0,
      record.design.license == "MIT", record.nativeDesign.license == "MIT",
      record.design.valid, record.nativeDesign.valid,
      record.nativeDesign.vertices.count <= 4096,
      record.nativeDesign.faces.count <= 512,
      record.nativeDesign.faces.allSatisfy({ $0.count == 3 }),
      record.structuralPolicy.valid(kind),
      record.interactionFace.valid(in: record.nativeDesign),
      try PreparedHull(mesh: record.nativeDesign.rawMesh).isClosed
    else { throw SaveError.invalidCommander }
    if kind == .standard, record.massKilograms != NativeC01TimingStandard.massKg {
      throw SaveError.invalidCommander
    }
    return record
  }
}

extension Game {
  /// Classification is about the exact retained original object, including genuine dead health0.
  /// It changes no damage, legal judgement, loss or mission-progress authority.
  func isC01StructuralProp(_ body: SpaceBody) -> Bool {
    guard let mission = glassMeridianMission, let opening = mission.savedGlassMeridian,
      mission.definition == NativeGlassMeridian.stateID, mission.digest == NativeGlassMeridian.digest,
      opening.permission.mission == mission.id,
      opening.permission.owner == commander.equipmentOwnerID,
      body.missionInstanceID == mission.id, let actorID = body.missionActorID,
      let physical = body.physical, physical.population == .mission, physical.npc?.role == .mission,
      physical.identity.system == systemIdentity,
      physical.identity.visit == commander.flightSimulation.visit,
      let spawn = physical.spawnIdentity, spawn.producer == .mission,
      spawn.system == physical.identity.system, spawn.visit == physical.identity.visit
    else { return false }
    let encounter: String
    if c01ClinicCradleDeclared(body), let leaf = opening.clinicEscort {
      guard NativeC01ClinicEscortSave.historyJoins(leaf, mission: mission, commander: commander),
        physical.identity.visit >= leaf.source.visit,
        NativeC01ClinicEscort.nativeValid(physical, cradle: true)
      else { return false }
      encounter = NativeC01ClinicEscort.sourceEncounter
    } else if let part = c01TimingStandardPart(body), let leaf = opening.timingStandard {
      guard NativeC01TimingStandardSave.historyJoins(leaf, mission: mission, commander: commander),
        NativeC01TimingStandard.nativeValid(physical, source: leaf.source, part: part)
      else { return false }
      encounter = NativeC01TimingStandard.encounter
    } else if let target = c01LaneRepairTarget(body), let leaf = opening.laneRepair {
      guard NativeC01LaneRepairSave.historyJoins(leaf, mission: mission, commander: commander),
        NativeC01LaneRepair.nativeValid(physical, source: leaf.source, target: target)
      else { return false }
      encounter = NativeC01LaneRepair.encounter
    } else {
      return false
    }
    guard let group = mission.ownedEncounters[encounter], group.valid, group.admitted,
      let actor = group.actors.values.first(where: { $0.identity == actorID }),
      actor.presence == .present || actor.presence == .destroyed,
      actor.body.id == body.id, actor.body.physical?.identity == physical.identity,
      actor.body.scriptNPC?.fit == body.scriptNPC?.fit
    else { return false }
    return true
  }
}
