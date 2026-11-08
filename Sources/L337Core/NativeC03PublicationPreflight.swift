import Foundation

/// A raw current-chunk boundary, not a root-format selector or a source capability.
/// G1 supplies the actual root owner and the trusted current C03 schema selection.
enum NativeC03PublicationPreflight {
  enum Failure: Error, Equatable {
    case invalidJSON, resourceLimit, duplicateField, unknownField
    case misplacedClaim, invalidInstance, wrongSchema, missingOwner
  }

  struct Publication: Sendable {
    let mission: UUID
    let bytes: Data
    let state: NativeHollowManifestState
  }

  /// Call BEFORE Foundation decodes the enclosing chunk. A nil trusted schema or
  /// owner never permits a claim; it is useful when rejecting non-mission chunks.
  /// Never obtain currentSchema by echoing the untrusted pointer's schema.
  static func validate(
    _ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?,
    currentSchema: Int?, owner: UUID?
  ) throws -> [Publication] {
    var scanner = Scanner(data: data)
    let leaves = try scanner.scan()
    guard leaves.isEmpty || part == .missions else { throw Failure.misplacedClaim }
    guard leaves.isEmpty || (schema != nil && schema == currentSchema) else {
      throw Failure.wrongSchema
    }
    guard !leaves.isEmpty else { return [] }
    guard let owner else { throw Failure.missingOwner }
    // Finish the entire raw scan before ANY leaf enters Foundation decoding.
    return try leaves.map { leaf in
      let bytes = Data(data[
        (data.startIndex + leaf.range.lowerBound)..<(data.startIndex + leaf.range.upperBound)])
      let state = try NativeHollowManifestSave.decodePublication(
        bytes, owner: owner, mission: leaf.mission)
      return .init(mission: leaf.mission, bytes: bytes, state: state)
    }
  }

  /// The raw codec authenticates DATA only. The full candidate still needs these
  /// unchanged reciprocal joins, plus G1's ordinary custody/history/root checks.
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard NativeHollowManifestSave.validateClaims(commander) else { return false }
    if let custody = commander.nativePeople {
      return NativeC03CrewSourceSave.validSource(
        custody.hollowManifestCrew, custody: custody, commander: commander)
    }
    return true
  }

  private struct Leaf {
    let mission: UUID
    let range: Range<Int>
  }

  private struct Scanner {
    let data: Data
    var index = 0
    var leaves: [Leaf] = []
    var missions: Set<UUID> = []
    var leafStart: Int?
    var leafDepth = 0
    var leafContainers = 0

    // Same current chunk ceilings as ScriptSaveStore. G1 retains the stricter
    // pointer/header/world limits and all current chunk hash/namespace checks.
    private static let maximumChunkBytes = 134_217_728
    private static let leafFields: Set<String> = [
      "birth", "phase", "nextSourceSequence", "admissions", "firstAdmissions",
      "latestAdmissions", "terminals", "consents", "firstCompromises",
      "latestSealDamage", "damageRevision", "withdrawals", "routeAnchors",
      "sourceFrame", "ownedEncounterID", "routes", "inspections", "laboratory",
      "wakeTrail", "custodyRegister", "crewSource", "crewLogAccess", "caseFile",
    ]
    private static let leafArrays: Set<String> = [
      "admissions", "firstAdmissions", "latestAdmissions", "terminals", "consents",
      "firstCompromises", "withdrawals", "routes", "inspections",
    ]

    mutating func scan() throws -> [Leaf] {
      guard data.count <= Self.maximumChunkBytes else { throw Failure.resourceLimit }
      try whitespace()
      try object(depth: 0) { scanner, key in
        guard key != NativeHollowManifestSave.field else { throw Failure.misplacedClaim }
        guard !key.lowercased().contains("hollowmanifest") else { throw Failure.unknownField }
        if key == "instances" { try scanner.instances(depth: 1) }
        else { try scanner.value(depth: 1) }
      }
      try whitespace()
      guard index == data.count else { throw Failure.invalidJSON }
      return leaves
    }

    private var next: UInt8? {
      index < data.count ? data[data.startIndex + index] : nil
    }

    private mutating func take() throws -> UInt8 {
      guard let byte = next else { throw Failure.invalidJSON }
      if let leafStart, index - leafStart >= NativeHollowManifestSave.maximumBytes {
        throw Failure.resourceLimit
      }
      index += 1
      return byte
    }

    private mutating func expect(_ byte: UInt8) throws {
      guard try take() == byte else { throw Failure.invalidJSON }
    }

    private mutating func whitespace() throws {
      while let byte = next, byte == 9 || byte == 10 || byte == 13 || byte == 32 {
        _ = try take()
      }
    }

    private mutating func container(depth: Int) throws {
      guard depth < 96 else { throw Failure.resourceLimit }
      if leafStart != nil {
        leafContainers += 1
        guard depth - leafDepth < 16, leafContainers <= 4096 else {
          throw Failure.resourceLimit
        }
      }
    }

    private mutating func object(
      depth: Int, field: (inout Scanner, String) throws -> Void
    ) throws {
      try container(depth: depth)
      try expect(123)
      try whitespace()
      if next == 125 { _ = try take(); return }
      var keys: Set<String> = []
      repeat {
        let key = try string(capture: true)
        guard keys.count < (leafStart == nil ? 16384 : 64) else {
          throw Failure.resourceLimit
        }
        guard keys.insert(key).inserted else { throw Failure.duplicateField }
        try whitespace()
        try expect(58)
        try whitespace()
        try field(&self, key)
        try whitespace()
        if next == 125 { _ = try take(); return }
        try expect(44)
        try whitespace()
      } while true
    }

    private mutating func instances(depth: Int) throws {
      if next == 123 {
        try object(depth: depth) { scanner, key in
          guard let mission = UUID(uuidString: key) else { throw Failure.invalidInstance }
          try scanner.instance(mission, depth: depth + 1)
        }
      } else {
        try container(depth: depth)
        try expect(91)
        try whitespace()
        if next == 93 { _ = try take(); return }
        repeat {
          let key = try string(capture: true)
          guard let mission = UUID(uuidString: key) else { throw Failure.invalidInstance }
          try whitespace()
          try expect(44)
          try whitespace()
          try instance(mission, depth: depth + 1)
          try whitespace()
          if next == 93 { _ = try take(); return }
          try expect(44)
          try whitespace()
        } while true
      }
    }

    private mutating func instance(_ mission: UUID, depth: Int) throws {
      guard missions.count < 128, missions.insert(mission).inserted else {
        throw Failure.invalidInstance
      }
      var id: UUID?
      var definition: String?
      var version: String?
      var digest: String?
      var range: Range<Int>?
      try object(depth: depth) { scanner, key in
        switch key {
        case "id": id = UUID(uuidString: try scanner.string(capture: true))
        case "definition": definition = try scanner.string(capture: true)
        case "version": version = try scanner.string(capture: true)
        case "digest": digest = try scanner.string(capture: true)
        case NativeHollowManifestSave.field:
          guard scanner.leaves.isEmpty else { throw Failure.invalidInstance }
          range = try scanner.publication(depth: depth + 1)
        default:
          guard !key.lowercased().contains("hollowmanifest") else { throw Failure.unknownField }
          try scanner.value(depth: depth + 1)
        }
      }
      guard id == mission else { throw Failure.invalidInstance }
      let named = definition == NativeHollowManifestCommission.stateID
      let pinned = digest == NativeHollowManifestCommission.digest
      guard named == pinned, named == (range != nil) else { throw Failure.invalidInstance }
      if let range {
        guard version == NativeHollowManifestCommission.version else { throw Failure.invalidInstance }
        leaves.append(.init(mission: mission, range: range))
      }
    }

    private mutating func publication(depth: Int) throws -> Range<Int> {
      let start = index
      leafStart = start
      leafDepth = depth
      leafContainers = 0
      defer { leafStart = nil }
      var birth = false
      try object(depth: depth) { scanner, key in
        guard Self.leafFields.contains(key) else { throw Failure.unknownField }
        if Self.leafArrays.contains(key) {
          guard scanner.next == 91 else { throw Failure.invalidJSON }
        } else if key == "phase" || key == "ownedEncounterID" {
          guard scanner.next == 34 else { throw Failure.invalidJSON }
        } else if key == "nextSourceSequence" || key == "damageRevision" {
          guard let byte = scanner.next, byte >= 48, byte <= 57 else {
            throw Failure.invalidJSON
          }
        } else {
          guard scanner.next == 123 else { throw Failure.invalidJSON }
        }
        if key == "birth" { birth = true }
        try scanner.value(depth: depth + 1, key: key)
      }
      guard birth else { throw Failure.invalidJSON }
      return start..<index
    }

    private mutating func value(depth: Int, key: String? = nil) throws {
      guard let byte = next else { throw Failure.invalidJSON }
      switch byte {
      case 123:
        try object(depth: depth) { scanner, child in
          guard child != NativeHollowManifestSave.field else { throw Failure.misplacedClaim }
          try scanner.value(depth: depth + 1, key: child)
        }
      case 91:
        try container(depth: depth)
        try expect(91)
        try whitespace()
        if next == 93 { _ = try take(); return }
        let maximum: Int
        if leafStart == nil { maximum = 16384 }
        else if key == "originals" { maximum = 2 }
        else if key == "operations" { maximum = 7 }
        else if key == "admissions" { maximum = 20 }
        else if let key, Self.leafArrays.contains(key) { maximum = 2 }
        else { maximum = 256 }
        var count = 0
        repeat {
          guard count < maximum else { throw Failure.resourceLimit }
          count += 1
          try value(depth: depth + 1)
          try whitespace()
          if next == 93 { _ = try take(); return }
          try expect(44)
          try whitespace()
        } while true
      case 34: _ = try string(capture: false)
      case 116: try literal("true")
      case 102: try literal("false")
      case 110: try literal("null")
      case 45, 48...57: try number()
      default: throw Failure.invalidJSON
      }
    }

    private mutating func literal(_ value: String) throws {
      for byte in value.utf8 { try expect(byte) }
    }

    private mutating func number() throws {
      let start = index
      if next == 45 { _ = try take() }
      if next == 48 { _ = try take() }
      else { try digits() }
      if next == 46 { _ = try take(); try digits() }
      if next == 101 || next == 69 {
        _ = try take()
        if next == 43 || next == 45 { _ = try take() }
        try digits()
      }
      guard index - start <= 64 else { throw Failure.resourceLimit }
    }

    private mutating func digits() throws {
      guard let byte = next, byte >= 48, byte <= 57 else { throw Failure.invalidJSON }
      repeat { _ = try take() } while next.map({ $0 >= 48 && $0 <= 57 }) == true
    }

    /// Validate UTF-8 and JSON escapes without Foundation string/JSON decoding.
    /// Only keys and bounded identity fields need an owned decoded Swift string.
    private mutating func string(capture: Bool) throws -> String {
      try expect(34)
      let start = index
      let maximum = leafStart == nil ? 6 * 262144 : NativeHollowManifestBirthCodec.maximumStringBytes
      var result = String.UnicodeScalarView()
      while true {
        guard index - start <= maximum else { throw Failure.resourceLimit }
        let byte = try take()
        if byte == 34 { return String(result) }
        let value: UInt32
        if byte == 92 {
          switch try take() {
          case 34: value = 34
          case 92: value = 92
          case 47: value = 47
          case 98: value = 8
          case 102: value = 12
          case 110: value = 10
          case 114: value = 13
          case 116: value = 9
          case 117:
            let first = try hex()
            if (0xD800...0xDBFF).contains(first) {
              try expect(92); try expect(117)
              let second = try hex()
              guard (0xDC00...0xDFFF).contains(second) else { throw Failure.invalidJSON }
              value = 0x10000 + (first - 0xD800) * 1024 + second - 0xDC00
            } else {
              guard !(0xDC00...0xDFFF).contains(first) else { throw Failure.invalidJSON }
              value = first
            }
          default: throw Failure.invalidJSON
          }
        } else if byte < 128 {
          guard byte >= 32 else { throw Failure.invalidJSON }
          value = UInt32(byte)
        } else {
          let count: Int
          let minimum: UInt32
          var scalar: UInt32
          switch byte {
          case 0xC2...0xDF: count = 1; minimum = 0x80; scalar = UInt32(byte & 0x1F)
          case 0xE0...0xEF: count = 2; minimum = 0x800; scalar = UInt32(byte & 0x0F)
          case 0xF0...0xF4: count = 3; minimum = 0x10000; scalar = UInt32(byte & 0x07)
          default: throw Failure.invalidJSON
          }
          for _ in 0..<count {
            let continuation = try take()
            guard (0x80...0xBF).contains(continuation) else { throw Failure.invalidJSON }
            scalar = scalar * 64 + UInt32(continuation & 0x3F)
          }
          guard scalar >= minimum else { throw Failure.invalidJSON }
          value = scalar
        }
        guard let scalar = UnicodeScalar(value) else { throw Failure.invalidJSON }
        if capture { result.append(scalar) }
      }
    }

    private mutating func hex() throws -> UInt32 {
      var value: UInt32 = 0
      for _ in 0..<4 {
        let byte = try take()
        let digit: UInt32
        switch byte {
        case 48...57: digit = UInt32(byte - 48)
        case 65...70: digit = UInt32(byte - 55)
        case 97...102: digit = UInt32(byte - 87)
        default: throw Failure.invalidJSON
        }
        value = value * 16 + digit
      }
      return value
    }
  }
}
