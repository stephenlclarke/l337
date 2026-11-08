import Foundation
import Testing

@testable import L337Core

struct NativeC03SharedStateJoinUnitTests {
  @Test func actualOpeningSurvivesInstanceCopyAndCodecWithoutSharingMutation() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let original = try #require(game.hollowManifestMission)
    let state = try #require(original.savedHollowManifest)
    var detached = original
    detached.savedHollowManifest = nil
    #expect(detached.savedHollowManifest == nil)
    #expect(original.savedHollowManifest == state)
    #expect(detached != original)
    let bytes = try ScriptValueStorage.encoder().encode(original)
    let decoded = try JSONDecoder().decode(ScriptInstance.self, from: bytes)
    #expect(decoded == original)
    #expect(decoded.savedHollowManifest == state)
    #expect(decoded.savedHollowManifest?.crewLogAccess == state.crewLogAccess)
    #expect(decoded.savedHollowManifest?.crewSource == state.crewSource)
    #expect(NativeHollowManifestCommission.prefixValid(decoded))
  }

  @Test func custodyDecoderConsumesTheDeclaredOriginalCrewSourceInsteadOfIgnoringIt() throws {
    let owner = UUID()
    let invalid = Data("""
      {"owner":"\(owner)","revision":0,"admissions":[],"transfers":[],
       "hollowManifestCrew":"a name is not a retained native source"}
      """.utf8)
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativePeopleCustodyState.self, from: invalid)
    }
    let oldSave = Data("""
      {"owner":"\(owner)","revision":0,"admissions":[],"transfers":[]}
      """.utf8)
    let decoded = try JSONDecoder().decode(NativePeopleCustodyState.self, from: oldSave)
    #expect(decoded.owner == owner && decoded.hollowManifestCrew == nil)
    let bytes = try ScriptValueStorage.encoder().encode(decoded)
    #expect(try JSONDecoder().decode(NativePeopleCustodyState.self, from: bytes) == decoded)
  }

  @Test func c03ActionsAndRecoveredPageCannotOpenWithoutTheActualOriginal() {
    let game = Game(executive: false)
    for action in [MissionUIAction.originalSealConsent, .originalWakeScan,
      .originalRegisterRecovery, .reviewRecoveredRegister]
    {
      #expect(action.requiresPageProof)
      #expect(!action.isEnabled(in: game))
    }
    #expect(!ScriptPageIdentity.c03ArchiveReader("an archive label").valid)
    #expect(game.c03ArchiveReaderPageDigest == nil)
  }
}
