import Foundation
import Testing

@testable import L337Core

struct NativeHollowManifestMarkerReadTests {
  @Test(arguments: ["definition", "digest", "receipt", "foreign"])
  func eachIndependentMarkFlagsTheClaimWithoutValidatingOrMutatingIt(mark: String) throws {
    var instance = ScriptInstance(
      id: UUID(),
      definition: mark == "definition" ? NativeHollowManifestCommission.stateID : "foreign-definition",
      version: "unvalidated-marker-input",
      digest: mark == "digest" ? NativeHollowManifestCommission.digest : "foreign-digest")
    if mark == "receipt" { instance.receipts.insert(NativeHollowManifestCommission.receipt) }
    let untouched = instance
    let before = try encoded(instance)
    #expect(instance.savedHollowManifest == nil)
    for _ in 0..<3 {
      #expect(NativeHollowManifestCommission.marked(instance) == (mark != "foreign"))
    }
    if mark != "foreign" {
      // Recognition must keep invalid claims in the closed validation path.
      #expect(!NativeHollowManifestCommission.prefixValid(instance))
    }
    #expect(instance == untouched && instance.id == untouched.id)
    #expect(try encoded(instance) == before)
    #expect(instance.definition == untouched.definition && instance.digest == untouched.digest)
    #expect(instance.receipts == untouched.receipts && instance.savedHollowManifest == nil)
    var detached = instance
    detached.receipts = []
    #expect(NativeHollowManifestCommission.marked(detached)
      == (mark == "definition" || mark == "digest"))
    #expect(NativeHollowManifestCommission.marked(instance) == (mark != "foreign"))
    #expect(try encoded(instance) == before)
  }

  @Test func genuineCurrentOptionalPresenceRemainsVisibleAcrossCOWDetachAndColdDecode()
    async throws
  {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let accepted = await fixture.runtime.snapshot()
    let actual = try #require(accepted.hollowManifestMission)
    let actualState = try #require(actual.savedHollowManifest)
    try #require(NativeHollowManifestSave.validateClaims(accepted.commander))
    try #require(NativeHollowManifestCommission.prefixValid(actual))
    let disk = try Data(contentsOf: fixture.files.save)
    let actualBytes = try encoded(actual)
    #expect(NativeHollowManifestCommission.marked(actual))

    // Deliberately foreign metadata isolates the nonnil-presence recognition arm.
    // This copy is an invalid claim, never a source/mission admission or saved root.
    var presenceOnly = ScriptInstance(id: UUID(), definition: "foreign-definition",
      version: "presence-negative-input", digest: "foreign-digest")
    presenceOnly.savedHollowManifest = actualState
    try #require(presenceOnly.receipts.isEmpty)
    let retained = presenceOnly
    let retainedBytes = try encoded(retained)
    #expect(NativeHollowManifestCommission.marked(presenceOnly))
    #expect(!NativeHollowManifestCommission.prefixValid(presenceOnly))
    #expect(presenceOnly.savedHollowManifest == actualState)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: retainedBytes)
    #expect(NativeHollowManifestCommission.marked(decoded))
    #expect(decoded == retained)
    #expect(try encoded(decoded) == retainedBytes)
    presenceOnly.savedHollowManifest = nil
    #expect(!NativeHollowManifestCommission.marked(presenceOnly))
    #expect(NativeHollowManifestCommission.marked(retained))
    #expect(retained.savedHollowManifest == actualState)
    #expect(try encoded(retained) == retainedBytes)
    #expect(try encoded(actual) == actualBytes)
    #expect(try Data(contentsOf: fixture.files.save) == disk)
    let after = await fixture.runtime.snapshot()
    #expect(after.commander == accepted.commander && after.bodies == accepted.bodies)
  }

  private func encoded(_ instance: ScriptInstance) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(instance)
  }
}
