import Foundation
import Testing

@testable import L337Core

struct NativeC01CompletionTests {
  @Test func originalQualifiedIdentitiesHaveOneClosedLocalMappingAndTwoExactChoices() {
    #expect(NativeC01Completion.originalReceipts.count == 4)
    for (original, local) in NativeC01Completion.originalReceipts {
      #expect(!PackValidation.localID(original))
      #expect(PackValidation.localID(local))
    }
    #expect(Set(NativeC01EvidenceChoice.allCases.map(\.rawValue)).count == 2)
    #expect(NativeC01EvidenceChoice.publicReport.label == "Publish the full safety report")
    #expect(NativeC01EvidenceChoice.arbitration.label == "Submit the ledger to crew arbitration")
    #expect(NativeC01Completion.payment == 48000)
    #expect(ScriptBaseClueCatalog.bySource[NativeC01Completion.sourceID]?.clueID == "meridian-offset")
  }

  @Test func typedOperationFramesSeparateDomainsTypesAndStringBoundaries() throws {
    let first = try NativeC01Completion.hash("test-c01-frame", [
      "left": .string("a"), "right": .string("bc"),
    ])
    let moved = try NativeC01Completion.hash("test-c01-frame", [
      "left": .string("ab"), "right": .string("c"),
    ])
    #expect(first != moved)
    #expect(first != (try NativeC01Completion.hash("other-c01-frame", [
      "left": .string("a"), "right": .string("bc"),
    ])))
    #expect(try NativeC01Completion.hash("test-c01-frame", ["value": .integer(1)])
      != NativeC01Completion.hash("test-c01-frame", ["value": .string("1")]))
    #expect(try NativeC01Completion.hash("test-c01-frame", ["value": .null])
      != NativeC01Completion.hash("test-c01-frame", ["value": .string("")]))
  }

  @Test func journalSealPreservesOrderAndSupportsTheExistingMaximumWithoutQuotaWidening() throws {
    let entries = Array(repeating: String(repeating: "a", count: 12000), count: 512)
    let fingerprint = try NativeC01Completion.journalHash(entries)
    #expect(ScriptCompletionReceipt.validDigest(fingerprint))
    #expect(try NativeC01Completion.journalHash(["a", "bc"])
      != NativeC01Completion.journalHash(["ab", "c"]))
    #expect(try NativeC01Completion.journalHash(["first", "second"])
      != NativeC01Completion.journalHash(["second", "first"]))
    #expect(throws: (any Error).self) { try NativeC01Completion.journalHash(entries + ["extra"]) }
    #expect(throws: (any Error).self) {
      try NativeC01Completion.journalHash([String(repeating: "x", count: 12001)])
    }
  }

  @Test func currentRawWrappersRejectNullEmptyUnknownPartialAndEmbeddedClaims() throws {
    // These are deliberately invalid descriptive objects, never a mission/arrival issuer.
    let invalid: [Any] = [NSNull(), [:] as [String: Any], ["disposition": NSNull()],
      ["disposition": [:], "unknown": true], ["terminal": [:]]]
    for completion in invalid {
      let root: [String: Any] = ["instances": [UUID().uuidString: [
        "definition": NativeGlassMeridian.stateID, "version": NativeGlassMeridian.version,
        "digest": NativeGlassMeridian.digest, "savedGlassMeridian": ["completion": completion],
      ]]]
      let data = try JSONSerialization.data(withJSONObject: root)
      #expect(throws: (any Error).self) {
        try NativeC01CompletionSave.validateFields(data, part: .missions,
          schema: NativeC01ReservationAuditSave.version)
      }
      #expect(throws: (any Error).self) {
        try NativeC01CompletionSave.validateFields(data, part: .missions, schema: 63)
      }
    }
    let alias = try JSONSerialization.data(withJSONObject: ["nativeC01Completion": [:]])
    #expect(throws: (any Error).self) {
      try NativeC01CompletionSave.validateFields(alias, part: .commander, schema: 137)
    }
  }
}
