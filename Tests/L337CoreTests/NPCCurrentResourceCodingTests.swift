import Foundation
import Testing

@testable import L337Core

struct NPCCurrentResourceCodingTests {
  @Test(arguments: [false, true])
  func currentResourcesRoundTripActualTrackedPools(spent: Bool) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    var resources = try #require(NPCResources.stock(source.performance))
    if spent {
      resources.frontShield = 0
      resources.rearShield = 0
      resources.fuel = 0
      var reserve = try #require(ElectricalReserve(
        capacity: resources.energyCapacity, recharge: resources.energyRecharge, at: 0))
      let drained = reserve.drain(resources.energyCapacity / 2, at: 0)
      try #require(drained)
      resources.electrical = reserve
    }
    let before = resources
    let bytes = try JSONEncoder().encode(resources)
    #expect(try JSONDecoder().decode(NPCResources.self, from: bytes) == before)
    #expect(resources == before && resources.valid)
  }

  @Test(arguments: ["unknown", "null-unknown", "missing-capacity"])
  func currentResourceReaderRejectsUnrecognizedOrMissingRequiredFields(condition: String) throws {
    let source = try #require(OriginalFleetRuntimeHullSource.source(for: "SH025"))
    let stock = try #require(NPCResources.stock(source.performance))
    let bytes = try JSONEncoder().encode(stock)
    var object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    switch condition {
    case "unknown": object["unexpectedResourceSource"] = 2
    case "null-unknown": object["unexpectedResourceSource"] = NSNull()
    case "missing-capacity": object.removeValue(forKey: "energyCapacity")
    default:
      Issue.record("Unknown current resource schema condition")
      return
    }
    let malformed = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) { _ = try JSONDecoder().decode(NPCResources.self, from: malformed) }
    #expect(try JSONDecoder().decode(NPCResources.self, from: bytes) == stock)
  }
}
