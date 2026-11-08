import Foundation
import Testing

@testable import L337Core

struct OriginalStationFatalIntervalCodecTests {
  // Constructed historical facts exercise the codec only, never a live fatal capability.
  @Test(arguments: [0.0, 68_719_476_736.0, 1e12 - 0.25])
  func acceptedActualUsedDurationSurvivesSupportedClockRounding(start: Double) throws {
    let state = history(start: start, usedDuration: 0.1)
    #expect(NativeUtilityEngineerSave.shapeValid(state))
    let restored = try NativeUtilityEngineerSave.decodeClosed(JSONEncoder().encode(state))
    #expect(restored == state)
    let casualty = try #require(restored.casualty)
    #expect(casualty.usedDuration == 0.1)
    #expect(casualty.physicalTime == start + casualty.usedDuration)
    #expect(casualty.physicalTime > start)
    if start == 68_719_476_736.0 {
      #expect(casualty.physicalTime - start > 0.100001)
    }
  }

  @Test(arguments: ["missing", "null", "zero", "negative", "overBound", "wrongEnd", "nonadvance"])
  func missingNullOrInconsistentUsedDurationIsRejected(form: String) throws {
    let state = history(start: 68_719_476_736, usedDuration: 0.1)
    var root = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
    var casualty = try #require(root["casualty"] as? [String: Any])
    switch form {
    case "missing": casualty.removeValue(forKey: "usedDuration")
    case "null": casualty["usedDuration"] = NSNull()
    case "zero": casualty["usedDuration"] = 0
    case "negative": casualty["usedDuration"] = -0.1
    case "overBound": casualty["usedDuration"] = 0.100001
    case "wrongEnd": casualty["physicalTime"] = 68_719_476_736.0 + 0.2
    default:
      casualty["usedDuration"] = Double.leastNonzeroMagnitude
      casualty["physicalTime"] = 68_719_476_736.0
    }
    root["casualty"] = casualty
    #expect(throws: (any Error).self) {
      try NativeUtilityEngineerSave.decodeClosed(JSONSerialization.data(withJSONObject: root))
    }
  }

  private func history(start: Double, usedDuration: Double) -> NativeUtilityEngineerState {
    let owner = UUID()
    let identity = NativeUtilityEngineerIdentity(owner: owner)
    let binding = NativeStationBinding(
      actor: .init(system: identity.station.system, visit: 1, entity: 2), bodyID: 1)
    let epoch = UUID()
    let birth = NativeUtilityEngineerRegistration(
      operation: NativeUtilityEngineer.birthOperation(owner: owner), identity: identity,
      station: identity.station, sourceVersion: OriginalStationSite.sourceVersion,
      binding: binding,
      spawn: .init(system: identity.station.system, visit: 1, sequence: 1, member: 0, producer: .mission),
      physicalTime: 0, epoch: epoch)
    return .init(registration: birth, casualty: .init(
      operation: NativeUtilityEngineer.casualtyOperation(owner: owner, binding: binding, incident: 1),
      binding: binding, priorLifecycleRevision: 1,
      tombstone: .init(revision: 2, destroyedBinding: binding), incident: 1, origin: nil,
      startTime: start, usedDuration: usedDuration, physicalTime: start + usedDuration,
      preNextIncident: 1, postNextIncident: 2, epoch: epoch))
  }
}
