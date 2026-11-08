import Foundation

/// Standalone immutable birth leaf only. No save namespace, current-context permission or
/// manufacture/person-life authority is registered by this codec.
enum NativeHollowManifestBirthCodec {
  enum Failure: Error, Equatable {
    case resourceLimit, invalidLeaf, noncanonical, wrongOwner, wrongMission, changedBirth
  }
  static let maximumBytes = 262_144
  static let maximumStringBytes = 4096

  static func encode(_ birth: NativeHollowManifestSourceBirth) throws -> Data {
    guard birth.shapeValid else { throw Failure.invalidLeaf }
    let bytes = try canonical(birth)
    try preflight(bytes)
    return bytes
  }

  static func decode(
    _ bytes: Data, owner: UUID, mission: UUID,
    existingBirth: NativeHollowManifestSourceBirth? = nil
  ) throws -> NativeHollowManifestSourceBirth {
    try preflight(bytes)
    guard let raw = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      let originals = raw["originals"] as? [Any], originals.count == 2,
      let operations = raw["operations"] as? [Any], operations.count == 7,
      geometryShape(raw["rootDesign"], vertices: 140, faces: 236),
      let master = raw["master"] as? [String: Any],
      geometryShape(master["template"], vertices: 64, faces: 96)
    else { throw Failure.invalidLeaf }
    let birth = try JSONDecoder().decode(NativeHollowManifestSourceBirth.self, from: bytes)
    guard birth.shapeValid else { throw Failure.invalidLeaf }
    // Same convention as AlienStoragePageCodec: exact canonical bytes reject duplicate keys,
    // unknown/null fields and alternate representations. Equality is not source authority.
    guard try canonical(birth) == bytes else { throw Failure.noncanonical }
    guard birth.input.owner == owner else { throw Failure.wrongOwner }
    guard birth.input.mission == mission else { throw Failure.wrongMission }
    if let existingBirth, existingBirth != birth { throw Failure.changedBirth }
    return birth
  }

  /// Historical owner/sale/dock joins only. An old carrier or fitting need not be the current
  /// player hull. Actual Nia, original life, pack and private source authentication stay pending.
  static func historicalOwnerMatches(
    _ birth: NativeHollowManifestSourceBirth, commander: borrowing Commander, mission: UUID
  ) -> Bool {
    guard birth.shapeValid, birth.input.mission == mission,
      birth.input.owner == commander.equipmentOwnerID,
      commander.scriptState.firstNativeCommoditySale == birth.input.sale,
      NativeFirstCommoditySaleSave.validateClaims(commander),
      let world = commander.nativeStations,
      world.ledger.world == birth.input.owner,
      world.mainStations.contains(birth.input.dock.station),
      birth.input.dock.sequence < world.nextMainDockSequence,
      birth.input.dock.actor.visit <= commander.flightSimulation.visit,
      birth.input.dock.calendarSeconds <= commander.scriptState.calendarSeconds,
      birth.input.physicalTime <= commander.flightSimulation.physicalTime
    else { return false }
    return true
  }

  private static func canonical(_ birth: NativeHollowManifestSourceBirth) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(birth)
  }

  private static func geometryShape(_ raw: Any?, vertices: Int, faces: Int) -> Bool {
    guard let geometry = raw as? [String: Any],
      let points = geometry["vertices"] as? [[Any]], points.count == vertices,
      let triangles = geometry["faces"] as? [[Any]], triangles.count == faces
    else { return false }
    return points.allSatisfy { $0.count == 3 } && triangles.allSatisfy { $0.count == 3 }
  }

  /// Resource scan before Foundation allocates JSON arrays, strings or nested ShipDesigns.
  /// Foundation checks full JSON grammar afterwards; this is not a second JSON decoder.
  static func preflight(_ data: Data) throws {
    guard data.count <= maximumBytes else { throw Failure.resourceLimit }
    struct Frame {
      let closing: UInt8
      let name: String?
      let maximumItems: Int
      var commas = 0
      var expectsKey = true
      var key: String?
    }
    let bytes = [UInt8](data)
    var stack: [Frame] = []
    var quoted = false
    var escaped = false
    var escapedKey = false
    var keyString = false
    var start = 0
    var containers = 0
    var totalCommas = 0
    var scalarBytes = 0
    for (index, byte) in bytes.enumerated() {
      if quoted {
        guard index - start <= maximumStringBytes else { throw Failure.resourceLimit }
        if escaped {
          escaped = false
        } else if byte == 92 {
          escaped = true
          escapedKey = escapedKey || keyString
        } else if byte == 34 {
          quoted = false
          if keyString {
            guard !escapedKey else { throw Failure.noncanonical }
            stack[stack.count - 1].key = String(decoding: bytes[start..<index], as: UTF8.self)
            stack[stack.count - 1].expectsKey = false
          }
        }
        continue
      }
      switch byte {
      case 34:
        quoted = true
        keyString = stack.last?.closing == 125 && stack.last?.expectsKey == true
        escapedKey = false
        start = index + 1
        scalarBytes = 0
      case 91, 123:
        containers += 1
        guard stack.count < 16, containers <= 4096 else { throw Failure.resourceLimit }
        let name = stack.last?.key
        let maximum: Int
        if byte == 123 {
          maximum = 64
        } else if stack.last?.closing == 93,
          stack.last?.name == "vertices" || stack.last?.name == "faces"
        {
          maximum = 3
        } else {
          let template = stack.contains { $0.name == "template" }
          switch name {
          case "originals": maximum = 2
          case "operations": maximum = 7
          case "vertices": maximum = template ? 64 : 140
          case "faces": maximum = template ? 96 : 236
          default: maximum = 256
          }
        }
        stack.append(.init(closing: byte == 91 ? 93 : 125, name: name, maximumItems: maximum))
        scalarBytes = 0
      case 93, 125:
        guard stack.last?.closing == byte else { throw Failure.invalidLeaf }
        stack.removeLast()
        scalarBytes = 0
      case 44:
        guard !stack.isEmpty else { throw Failure.invalidLeaf }
        totalCommas += 1
        stack[stack.count - 1].commas += 1
        guard totalCommas <= 8192,
          stack[stack.count - 1].commas < stack[stack.count - 1].maximumItems
        else { throw Failure.resourceLimit }
        if stack.last?.closing == 125 { stack[stack.count - 1].expectsKey = true }
        scalarBytes = 0
      case 9, 10, 13, 32, 58: scalarBytes = 0
      default:
        scalarBytes += 1
        guard scalarBytes <= 64 else { throw Failure.resourceLimit }
      }
    }
    guard !quoted, !escaped, stack.isEmpty else { throw Failure.invalidLeaf }
  }
}
