import Foundation
import Testing

@testable import L337Core

struct NativeC01InquiryOriginalHeaderRevisionTests {
  @Test(arguments: [UInt64(0), UInt64(Int64.max) - 1])
  func zeroAndLastRepresentableRevisionRoundTrip(revision: UInt64) throws {
    let value = header(revision)
    #expect(value.shapeValid)
    let restored = try JSONDecoder().decode(
      NativeC01InquiryOriginalHeaderRef.self, from: JSONEncoder().encode(value))
    #expect(restored == value && restored.revision == revision)
  }

  @Test(arguments: [UInt64(Int64.max), UInt64.max])
  func outOfRangeOriginalRevisionsRefuse(revision: UInt64) throws {
    let value = header(revision)
    #expect(!value.shapeValid)
    #expect(throws: (any Error).self) { try JSONEncoder().encode(value) }
    let object: [String: Any] = [
      "instanceID": value.instanceID.uuidString, "definition": value.definition,
      "version": value.version, "digest": value.digest,
      "revision": NSNumber(value: revision), "outcome": value.outcome.rawValue,
    ]
    let bytes = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeC01InquiryOriginalHeaderRef.self, from: bytes)
    }
  }

  @Test func otherPositiveRevisionsRemainPositive() {
    #expect(!NativeC01InquiryDataShape.revision(0))
    #expect(NativeC01InquiryDataShape.revision(1))
    #expect(!NativeC01InquiryDataShape.revision(UInt64(Int64.max)))
  }

  // Header DATA only. No original mission, permission, approved case or receipt is created.
  private func header(_ revision: UInt64) -> NativeC01InquiryOriginalHeaderRef {
    .init(instanceID: UUID(uuidString: "00000000-0000-4000-8000-000000000031")!,
      definition: "data-only-original", version: "data-v1", digest: String(repeating: "1", count: 64),
      revision: revision, outcome: .active, permissionOperation: nil)
  }
}
