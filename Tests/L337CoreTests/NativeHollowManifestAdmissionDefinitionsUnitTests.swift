import Foundation
import Testing

@testable import L337Core

/// Actual original admission must succeed before these lookups are exercised. Source/geometry
/// matching alone is not native admission, person life, a provider port or mission progress.
struct NativeHollowManifestAdmissionDefinitionsUnitTests {
  @Test func genuineOriginalsResolveThroughTheCurrentNativeBridgeAndCompleteGeometry() async throws {
    let (game, fixture) = try await actualHollowManifestFreighterRootFixture()
    defer { fixture.clean() }
    let instance = try #require(game.hollowManifestMission)
    let pack = try #require(game.hollowManifestPack)
    let definition = try #require(NativeHollowManifestCommission.encounterDefinition(
      pack: pack, state: instance, id: NativeHollowManifestCommission.encounter))
    #expect(definition.galaxy == 1 && definition.system == 113)
    #expect(Set(definition.actors.map(\.id))
      == Set(NativeHollowManifestState.Slot.allCases.map(\.rawValue)))
    let profiles = NativeHollowManifestCommission.profiles(pack: pack, state: instance)
    #expect(profiles.count == 2)
    let designs = NativeHollowManifestCommission.designs(pack: pack, state: instance)
    #expect(designs.count == 2)
    let source = try NativeHollowManifestFleetSource.resolve(.inspectionFreighter)
    #expect(designs[NativeHollowManifestCommission.rootModel] == source.physical.model.nativeDesign)
    let originals = game.c03LiveRouteInputs().originals
    try #require(originals.count == 2)
    for original in originals {
      let body = try #require(game.bodies.first { $0.id == original.owned.body.id })
      let descriptor = try #require(game.currentMissionActorDescriptor(bodyID: body.id))
      #expect(descriptor.instanceID == instance.id && descriptor.packDigest == pack.digest)
      #expect(descriptor.actorID == original.owned.identity)
      #expect(descriptor.body == body)
      let profile = try #require(profiles.first { $0.id == body.scriptNPC?.fit.definition.id })
      #expect(profile.energy == source.performance.energy && profile.recharge == source.performance.recharge)
      #expect(profile.speed == source.performance.speed)
      let mesh = try #require(game.scriptNPCMesh(body))
      #expect(mesh.vertices.count == 140 + 64 && mesh.faces.count == 236 + 96)
    }
  }

  @Test func wrongEncounterOrChangedOwnerDigestCannotResolveAnOriginalFit() async throws {
    let (game, fixture) = try await actualHollowManifestFreighterRootFixture()
    defer { fixture.clean() }
    let instance = try #require(game.hollowManifestMission)
    let pack = try #require(game.hollowManifestPack)
    try #require(NativeHollowManifestCommission.profiles(pack: pack, state: instance).count == 2)
    #expect(NativeHollowManifestCommission.encounterDefinition(
      pack: pack, state: instance, id: "foreign-encounter") == nil)
    var changed = ScriptInstance(
      id: instance.id, definition: instance.definition, version: instance.version,
      digest: String(repeating: "e", count: 64))
    changed.savedHollowManifest = instance.savedHollowManifest
    changed.ownedEncounters = instance.ownedEncounters
    #expect(NativeHollowManifestCommission.encounterDefinition(
      pack: pack, state: changed, id: NativeHollowManifestCommission.encounter) == nil)
    #expect(NativeHollowManifestCommission.profiles(pack: pack, state: changed).isEmpty)
    #expect(NativeHollowManifestCommission.designs(pack: pack, state: changed).isEmpty)
  }
}
