import Foundation

/// One original C03 person address. Only the actual native source producer can issue the
/// corresponding person; decoding or constructing an address proves no life or custody.
public struct NativeC03CrewIdentity: Codable, Hashable, Sendable {
  let owner: UUID
  let mission: UUID
  let ordinal: Int

  var source: UUID {
    ScriptIdentity.uuid(Self.sourceKey(owner: owner, mission: mission))
  }
  var key: String { Self.sourceKey(owner: owner, mission: mission) + ":original-crew:\(ordinal)" }
  var id: UUID { ScriptIdentity.uuid(key) }
  var valid: Bool { (0..<NativeC03EvacuationAccommodation.crewCount).contains(ordinal) }

  static func sourceKey(owner: UUID, mission: UUID) -> String {
    "c03-original-carrier-source-v1:\(owner):\(mission)"
  }

  func belongsTo(owner: UUID, mission: UUID, source: UUID) -> Bool {
    valid && self.owner == owner && self.mission == mission && self.source == source
  }
}
