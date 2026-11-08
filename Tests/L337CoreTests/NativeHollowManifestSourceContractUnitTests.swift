import Foundation
import Testing

@testable import L337Core

/// Deliberately unauthenticated component facts; no source, living captain or consent is minted.
struct NativeHollowManifestSourceContractUnitTests {
  private func original(
    slot: NativeHollowManifestOriginalSealBinding.Slot = .first,
    mission: UUID, owner: UUID, master: UUID
  ) -> NativeHollowManifestOriginalSealBinding {
    .init(
      slot: slot, mission: mission, owner: owner, source: UUID(), hull: UUID(), captain: UUID(),
      seal: UUID(), master: master, imprint: UUID(),
      actor: .init(
        system: .init(galaxy: 1, system: 113), visit: 4, entity: slot == .first ? 10 : 11),
      component: UUID(), sourceRevision: 1, issuedSequence: 5, issuedTime: 100)
  }

  private func request(
    _ source: NativeHollowManifestOriginalSealBinding
  ) -> NativeHollowManifestSealConsentRequest {
    .init(
      operation: UUID(), binding: source, purpose: .observeOriginalCargoSeal,
      player: .init(system: source.actor.system, visit: source.actor.visit, entity: 0),
      playerHull: UUID(), targetingEquipment: UUID(), inventoryRevision: 1,
      sequence: 6, physicalTime: 101)
  }

  private func reply(
    _ request: NativeHollowManifestSealConsentRequest,
    decision: NativeHollowManifestSealConsentReply.Decision = .granted
  ) -> NativeHollowManifestSealConsentReply {
    .init(
      operation: UUID(), request: request.operation, originalSource: request.binding.source,
      captain: request.binding.captain, seal: request.binding.seal, decision: decision,
      revision: 1, previousReply: nil, sequence: 7, physicalTime: 102)
  }

  private func changed<T: Codable>(_ value: T, field: String, replacement: Any) throws -> T {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object[field] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }

  @Test func twoDeclaredOriginalsShareOnlyCaseAndMasterAndDoNotBecomeNativeActors() throws {
    let mission = UUID()
    let owner = UUID()
    let master = UUID()
    let first = original(mission: mission, owner: owner, master: master)
    let second = original(slot: .second, mission: mission, owner: owner, master: master)
    #expect(NativeHollowManifestOriginalSealBinding.rosterShapeValid([first, second]))
    #expect(NativeHollowManifestOriginalSealBinding.rosterShapeValid([second, first]))
    for invalid in [[], [first], [first, first], [first, second, second]] {
      #expect(!NativeHollowManifestOriginalSealBinding.rosterShapeValid(invalid))
    }
    let game = Game(executive: false)
    let before = game.commander
    let decoded = try JSONDecoder().decode(
      NativeHollowManifestOriginalSealBinding.self, from: JSONEncoder().encode(first))
    #expect(decoded == first && decoded.shapeValid)
    #expect(game.commander == before && game.commander.scriptState.instances[mission] == nil)
    #expect(!game.bodies.contains { $0.missionActorID == decoded.source })
  }

  @Test func duplicateOriginalAndForeignCaseReferencesRefuseTheTwoFreighterShape() throws {
    let mission = UUID()
    let owner = UUID()
    let master = UUID()
    let first = original(mission: mission, owner: owner, master: master)
    let second = original(slot: .second, mission: mission, owner: owner, master: master)
    for (field, value) in [
      ("source", first.source), ("hull", first.hull), ("captain", first.captain),
      ("seal", first.seal), ("imprint", first.imprint), ("component", first.component),
      ("mission", UUID()), ("owner", UUID()), ("master", UUID()),
    ] {
      let invalid = try changed(second, field: field, replacement: value.uuidString)
      #expect(!NativeHollowManifestOriginalSealBinding.rosterShapeValid([first, invalid]))
    }
    let actor = try JSONSerialization.jsonObject(with: JSONEncoder().encode(first.actor))
    let sameActor = try changed(second, field: "actor", replacement: actor)
    #expect(!NativeHollowManifestOriginalSealBinding.rosterShapeValid([first, sameActor]))
    for field in ["issuedSequence", "sourceRevision"] {
      #expect(!(try changed(first, field: field, replacement: 0)).shapeValid)
    }
    #expect(!(try changed(first, field: "issuedTime", replacement: -1)).shapeValid)
  }

  @Test func requestsBindActualIdentitySlotsAndCannotPrecedeOriginalIssuance() throws {
    let source = original(mission: UUID(), owner: UUID(), master: UUID())
    let requested = request(source)
    #expect(requested.structurallyMatches(source))
    let other = original(
      slot: .second, mission: source.mission, owner: source.owner, master: source.master)
    #expect(!requested.structurallyMatches(other))
    for field in [
      "mission", "owner", "source", "hull", "captain", "seal", "master", "imprint", "component",
    ] {
      let changedSource = try changed(source, field: field, replacement: UUID().uuidString)
      #expect(!requested.structurallyMatches(changedSource))
    }
    #expect(
      !(try changed(requested, field: "sequence", replacement: 5)).structurallyMatches(source))
    #expect(
      !(try changed(requested, field: "physicalTime", replacement: 99)).structurallyMatches(source))
    var player = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(requested.player)) as? [String: Any])
    for (field, value) in [("visit", 3), ("entity", 1)] {
      var changedPlayer = player
      changedPlayer[field] = value
      #expect(
        !(try changed(requested, field: "player", replacement: changedPlayer)).structurallyMatches(
          source))
    }
    player["system"] = ["galaxy": 1, "system": 120]
    #expect(
      !(try changed(requested, field: "player", replacement: player)).structurallyMatches(source))
  }

  @Test func nativeReplyInterfaceRefusesOtherRequestCaptainSourceSealAndBackdatedFacts() throws {
    let source = original(mission: UUID(), owner: UUID(), master: UUID())
    let requested = request(source)
    for decision in [NativeHollowManifestSealConsentReply.Decision.granted, .declined] {
      let response = reply(requested, decision: decision)
      #expect(response.structurallyMatches(requested, original: source))
      let decoded = try JSONDecoder().decode(
        NativeHollowManifestSealConsentReply.self, from: JSONEncoder().encode(response))
      #expect(decoded == response)
      for field in ["request", "originalSource", "captain", "seal"] {
        #expect(
          !(try changed(response, field: field, replacement: UUID().uuidString))
            .structurallyMatches(requested, original: source))
      }
      #expect(
        !(try changed(response, field: "operation", replacement: requested.operation.uuidString))
          .structurallyMatches(requested, original: source))
      #expect(
        !(try changed(response, field: "sequence", replacement: requested.sequence))
          .structurallyMatches(requested, original: source))
      #expect(
        !(try changed(response, field: "physicalTime", replacement: 100)).structurallyMatches(
          requested, original: source))
      #expect(
        !(try changed(response, field: "revision", replacement: 2)).structurallyMatches(
          requested, original: source))
    }
    #expect(!reply(requested, decision: .revoked).structurallyMatches(requested, original: source))
  }

  @Test func revocationMustFollowThatExactGrantOnceAndCannotReplaceItsReply() throws {
    let source = original(mission: UUID(), owner: UUID(), master: UUID())
    let requested = request(source)
    let grant = reply(requested)
    let revoke = NativeHollowManifestSealConsentReply(
      operation: UUID(), request: requested.operation, originalSource: source.source,
      captain: source.captain, seal: source.seal, decision: .revoked, revision: 2,
      previousReply: grant.operation, sequence: 8, physicalTime: 103)
    #expect(revoke.structurallyMatches(requested, original: source, previous: grant))
    #expect(!revoke.structurallyMatches(requested, original: source))
    #expect(!revoke.structurallyMatches(requested, original: source, previous: reply(requested)))
    #expect(
      !revoke.structurallyMatches(
        requested, original: source, previous: reply(requested, decision: .declined)))
    #expect(!grant.structurallyMatches(requested, original: source, previous: revoke))
    #expect(!revoke.structurallyMatches(requested, original: source, previous: revoke))
    for (field, value) in [("revision", 3), ("sequence", 7), ("physicalTime", 101)] {
      #expect(
        !(try changed(revoke, field: field, replacement: value)).structurallyMatches(
          requested, original: source, previous: grant))
    }
    #expect(
      !(try changed(revoke, field: "decision", replacement: "granted")).structurallyMatches(
        requested, original: source, previous: grant))
  }
}
