import Foundation
import Testing

@testable import L337Core

struct NativeC03EvacuationDefinitionsUnitTests {
  @Test func bothDeclarationsUseTheActualQualifiedNativeHullAndExactSourceRoles() throws {
    // This positive assertion must remain blocked until actual geometry qualifies. Never
    // replace the Saiga's 1720 faces with a proxy or relax the native 512-face limit here.
    let declared = try NativeC03EvacuationDefinitions.resolve()
    #expect(declared.encounter.id == NativeC03CrewSourceState.encounter)
    #expect(declared.encounter.valid && declared.profiles.count == 2 && declared.designs.count == 2)
    #expect(declared.encounter.galaxy == NativeHollowManifestDefinition.carrierWorld.galaxy)
    #expect(declared.encounter.system == NativeHollowManifestDefinition.carrierWorld.system)
    for role in NativeC03EvacuationHull.Role.allCases {
      let hull = try NativeC03EvacuationHull.resolve(role)
      let profile = try NativeC03EvacuationProfile.definition(role)
      let alias = role == .launch ? NativeC03CrewSourceState.launchTarget : NativeC03CrewSourceState.carrierTarget
      let actor = try #require(declared.encounter.actors.first(where: { $0.id == alias }))
      #expect(actor.hull == nil && actor.npc == profile.id && !actor.hostile)
      #expect(actor.x == (role == .launch ? 1000 : -1000) && actor.y == 0 && actor.z == 0)
      #expect(declared.profiles.first(where: { $0.id == profile.id }) == profile)
      #expect(declared.designs[NativeC03EvacuationProfile.model(role)] == hull.design)
      #expect(hull.design.rawMesh.vertices == hull.source.physical.physicalMesh.vertices)
      #expect(hull.design.rawMesh.faces.count <= 512)
    }
  }

  @Test func anActuallyAcceptedCaseWithoutCrewCannotExposeEvacuationNativeDeclarations() async throws {
    let fixture = try await HollowManifestCommissionFixture()
    defer { fixture.clean() }
    _ = try await fixture.review()
    await fixture.selectConfirm()
    await fixture.runtime.key("return")
    let game = await fixture.runtime.snapshot()
    let instance = try #require(game.hollowManifestMission)
    let pack = try #require(game.hollowManifestPack)
    try #require(NativeHollowManifestCommission.prefixValid(instance))
    #expect(instance.savedHollowManifest?.crewSource == nil)
    #expect(NativeC03EvacuationDefinitions.installed(pack: pack, state: instance) == nil)
    #expect(NativeHollowManifestCommission.encounterDefinition(
      pack: pack, state: instance, id: NativeC03CrewSourceState.encounter) == nil)
    #expect(game.commander.nativePeople?.hollowManifestCrew == nil)
  }
}
