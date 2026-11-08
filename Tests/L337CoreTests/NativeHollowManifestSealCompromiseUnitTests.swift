import Foundation
import Testing

@testable import L337Core

/// Controlled, unauthenticated facts only. No real source, native hit or captain grant is produced.
struct NativeHollowManifestSealCompromiseUnitTests {
  private struct Fixture {
    let contexts: [NativeHollowManifestSealCompromiseContext]
    init() {
      let mission = UUID()
      let owner = UUID()
      let master = UUID()
      contexts = NativeHollowManifestOriginalSealBinding.Slot.allCases.enumerated().map {
        index, slot in
        .init(
          original: .init(
            slot: slot, mission: mission, owner: owner, source: UUID(), hull: UUID(),
            captain: UUID(), seal: UUID(), master: master, imprint: UUID(),
            actor: .init(
              system: .init(galaxy: 1, system: 113), visit: 4, entity: UInt64(10 + index)),
            component: UUID(), sourceRevision: 1, issuedSequence: 900, issuedTime: 100),
          geometry: .init(
            rootGeometryHash: String(repeating: "a", count: 64),
            sealGeometryHash: String(repeating: "b", count: 64), revision: 1,
            componentPose: .init(position: .init(6.52, -1, 0)), rootScale: 1, componentScale: 1),
          originalComponentEnergy: 100)
      }
    }
    func facts(
      slot: Int = 0, incidentID: UInt64 = 1, time: Double = 101,
      before: Double = 100, damage: Double = 5, unattributed: Bool = false
    ) -> NativeHollowManifestSealDamageFacts {
      let context = contexts[slot]
      return .init(
        original: context.original, geometry: context.geometry,
        component: context.original.component,
        cause: .init(
          id: incidentID, physicalTime: time, mission: context.original.mission,
          victim: context.original.actor, victimPart: context.original.slot.rawValue,
          component: context.original.component, kind: unattributed ? .plasma : .laser,
          outcome: before - damage <= 0 ? .componentDestruction : .hit,
          position: .init(1, 2, 3), attribution: unattributed ? .unknown : .currentVisit,
          origin: unattributed
            ? nil
            : .init(
              emissionID: incidentID + 10,
              owner: .init(system: context.original.actor.system, visit: 4, entity: 0),
              emittedAt: 100, ownerLegalAtEmission: .init()),
          terminalShot: unattributed ? UUID() : nil),
        admittedDamage: damage, beforeEnergy: before, afterEnergy: max(0, before - damage))
    }
  }

  private func changed<T: Codable>(_ value: T, field: String, replacement: Any) throws -> T {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object[field] = replacement
    return try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: object))
  }
  private func object<T: Encodable>(_ value: T) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
  }

  @Test func firstPositiveNonlethalEffectPermanentlyRetainsItsOriginalCauseAndSeparateNamespace()
    throws
  {
    let f = Fixture()
    let initial = try NativeHollowManifestSealCompromiseState(contexts: f.contexts)
    let facts = f.facts()
    // Native incident1 is not compared with C03 source sequence900.
    let compromised = try initial.recording(facts)
    #expect(compromised.shapeValid && compromised.damageRevision == 1)
    #expect(compromised.firstCompromises == [facts] && facts.afterEnergy > 0)
    #expect(compromised.latestDamage == facts)
    #expect(initial.firstCompromises.isEmpty && initial.damageRevision == 0)
    #expect(compromised.structuralCandidateStamp(for: .first) == nil)
    #expect(compromised.structuralCandidateStamp(for: .second) != nil)
    #expect(try compromised.recording(facts) == compromised)
    let decoded = try JSONDecoder().decode(
      NativeHollowManifestSealCompromiseState.self, from: JSONEncoder().encode(compromised))
    #expect(decoded == compromised && decoded.shapeValid)
  }

  @Test func everyOriginalComponentGeometryVictimAndEnergyJoinMustMatch() throws {
    let f = Fixture()
    let initial = try NativeHollowManifestSealCompromiseState(contexts: f.contexts)
    let facts = f.facts()
    for field in [
      "mission", "owner", "source", "hull", "captain", "seal", "master", "imprint", "component",
    ] {
      let foreign = try changed(facts.original, field: field, replacement: UUID().uuidString)
      let bad = try changed(facts, field: "original", replacement: object(foreign))
      #expect(throws: (any Error).self) { try initial.recording(bad) }
    }
    for field in ["rootGeometryHash", "sealGeometryHash"] {
      let foreign = try changed(
        facts.geometry, field: field, replacement: String(repeating: "c", count: 64))
      let bad = try changed(facts, field: "geometry", replacement: object(foreign))
      #expect(throws: (any Error).self) { try initial.recording(bad) }
    }
    let revised = try changed(facts.geometry, field: "revision", replacement: 2)
    #expect(throws: (any Error).self) {
      try initial.recording(changed(facts, field: "geometry", replacement: object(revised)))
    }
    let foreignVictim = try changed(
      facts.cause, field: "victim", replacement: object(f.contexts[1].original.actor))
    #expect(throws: (any Error).self) {
      try initial.recording(changed(facts, field: "cause", replacement: object(foreignVictim)))
    }
    for (field, value) in [("admittedDamage", 0), ("beforeEnergy", 99), ("afterEnergy", 96)] {
      #expect(throws: (any Error).self) {
        try initial.recording(changed(facts, field: field, replacement: value))
      }
    }
    #expect(throws: (any Error).self) {
      try initial.recording(changed(facts, field: "component", replacement: UUID().uuidString))
    }
    #expect(initial.firstCompromises.isEmpty)
  }

  @Test func lethalAndNonlethalOutcomesAndMissingOrBackdatedNativeCausesCannotAlias() throws {
    let f = Fixture()
    let initial = try NativeHollowManifestSealCompromiseState(contexts: f.contexts)
    let lethal = f.facts(damage: 100)
    #expect(try initial.recording(lethal).firstCompromises == [lethal])
    let facts = f.facts()
    for (field, value) in [
      ("id", 0 as Any), ("physicalTime", 99 as Any), ("outcome", "componentDestruction" as Any),
      ("victimPart", "freighter-seal-b" as Any), ("victim", NSNull()),
    ] {
      let incident = try changed(facts.cause, field: field, replacement: value)
      #expect(throws: (any Error).self) {
        try initial.recording(changed(facts, field: "cause", replacement: object(incident)))
      }
    }
    var raw = try #require(object(facts) as? [String: Any])
    raw.removeValue(forKey: "cause")
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(
        NativeHollowManifestSealDamageFacts.self, from: JSONSerialization.data(withJSONObject: raw))
    }
  }

  @Test func laterSameTimeDamageInvalidatesCandidatesWithoutOverwritingEitherFirstCompromise()
    throws
  {
    let f = Fixture()
    let initial = try NativeHollowManifestSealCompromiseState(contexts: f.contexts)
    let pending = try #require(initial.structuralCandidateStamp(for: .first))
    let first = f.facts()
    let one = try initial.recording(first)
    #expect(!one.matchesStructuralCandidate(pending))
    let secondPending = try #require(one.structuralCandidateStamp(for: .second))
    let later = f.facts(incidentID: 2, before: 95, damage: 2)
    let again = try one.recording(later)
    #expect(again.damageRevision == 2 && again.firstCompromises == [first])
    #expect(!again.matchesStructuralCandidate(secondPending))
    #expect(
      again.latestDamage == later && later.cause.physicalTime == first.cause.physicalTime)
    let second = f.facts(slot: 1, incidentID: 3)
    let both = try again.recording(second)
    #expect(both.firstCompromises == [first, second] && both.damageRevision == 3)
    #expect(both.structuralCandidateStamp(for: .first) == nil)
    #expect(both.structuralCandidateStamp(for: .second) == nil)
    #expect(try both.recording(first) == both)
    #expect(try both.recording(second) == both)
  }

  @Test func staleOrChangedReplayRefusesAndHistoryStaysBoundedThroughFurtherDamage() throws {
    let f = Fixture()
    let first = f.facts()
    var state = try NativeHollowManifestSealCompromiseState(contexts: f.contexts).recording(first)
    let changedAmount = try changed(first, field: "admittedDamage", replacement: 4)
    let tampered = try changed(changedAmount, field: "afterEnergy", replacement: 96)
    #expect(tampered.structurallyMatches(f.contexts[0]))
    #expect(throws: (any Error).self) { try state.recording(tampered) }
    for id in UInt64(2)...20 {
      state = try state.recording(f.facts(incidentID: id, before: 95, damage: 1))
    }
    #expect(state.firstCompromises == [first] && state.damageRevision == 20)
    #expect(state.latestDamage?.cause.id == 20)
    #expect(state.structuralCandidateStamp(for: .first) == nil)
    #expect(try state.recording(first) == state)
    #expect(try state.recording(f.facts(incidentID: 20, before: 95, damage: 1)) == state)
    #expect(throws: (any Error).self) {
      try state.recording(f.facts(incidentID: 19, before: 95, damage: 1))
    }
    #expect(throws: (any Error).self) {
      try state.recording(f.facts(incidentID: 21, time: 100.5, before: 95, damage: 1))
    }
    // Even controlled restored energy cannot erase the retained first compromise or restore a stamp.
    let healed = try state.recording(f.facts(incidentID: 21, before: 100, damage: 1))
    #expect(
      healed.firstCompromises == [first] && healed.structuralCandidateStamp(for: .first) == nil)
  }

  @Test func foreignCandidateAndMalformedDecodedHistoryAreNeverProgressOrNativeAuthority() throws {
    let f = Fixture()
    let initial = try NativeHollowManifestSealCompromiseState(contexts: f.contexts)
    let stamp = try #require(initial.structuralCandidateStamp(for: .first))
    let other = Fixture()
    let foreign = try NativeHollowManifestSealCompromiseState(contexts: other.contexts)
    #expect(!foreign.matchesStructuralCandidate(stamp))
    let facts = f.facts()
    let state = try initial.recording(facts)
    let removed = try changed(state, field: "firstCompromises", replacement: [])
    #expect(!removed.shapeValid && !removed.matchesStructuralCandidate(stamp))
    #expect(throws: (any Error).self) { try removed.recording(facts) }
    let later = try state.recording(f.facts(incidentID: 2, before: 95, damage: 1))
    #expect(!(try changed(later, field: "damageRevision", replacement: 1)).shapeValid)
    #expect(!(try changed(state, field: "damageRevision", replacement: 0)).shapeValid)
    let duplicate = try changed(
      state, field: "firstCompromises", replacement: [object(facts), object(facts)])
    #expect(!duplicate.shapeValid)
    #expect(throws: (any Error).self) {
      try NativeHollowManifestSealCompromiseState(contexts: [f.contexts[0]])
    }
    #expect(throws: (any Error).self) {
      try NativeHollowManifestSealCompromiseState(contexts: [f.contexts[0], f.contexts[0]])
    }
  }

  @Test(arguments: [5.0, 100.0])
  func unattributedRetainedProjectileCompromisesWithoutInventingOrigin(damage: Double) throws {
    let f = Fixture()
    let initial = try NativeHollowManifestSealCompromiseState(contexts: f.contexts)
    let facts = f.facts(damage: damage, unattributed: true)
    #expect(facts.cause.origin == nil && facts.cause.attribution == .unknown)
    #expect(facts.cause.terminalShot != nil && facts.cause.kind == .plasma)
    #expect(facts.structurallyMatches(f.contexts[0]))
    let next = try initial.recording(facts)
    #expect(next.firstCompromises == [facts] && next.damageRevision == 1)
    #expect(try next.recording(facts) == next)
    let decoded = try JSONDecoder().decode(
      NativeHollowManifestSealCompromiseState.self, from: JSONEncoder().encode(next))
    #expect(decoded == next && decoded.latestDamage?.cause.origin == nil)
    #expect(decoded.latestDamage?.cause.outcome == (damage == 100 ? .componentDestruction : .hit))
  }

  @Test func unknownCauseScopeAndSameTimeReplayCannotInventCurrentOrFrozenAttribution() throws {
    let f = Fixture()
    let initial = try NativeHollowManifestSealCompromiseState(contexts: f.contexts)
    let first = f.facts(unattributed: true)
    let state = try initial.recording(first)
    let stamp = try #require(state.structuralCandidateStamp(for: .second))
    let later = f.facts(incidentID: 2, before: 95, unattributed: true)
    let next = try state.recording(later)
    #expect(next.firstCompromises == [first] && next.damageRevision == 2)
    #expect(!next.matchesStructuralCandidate(stamp))
    #expect(first.cause.physicalTime == later.cause.physicalTime)
    #expect(try next.recording(first) == next && next.recording(later) == next)
    for (field, value) in [
      ("terminalShot", NSNull() as Any), ("kind", "laser" as Any),
      ("attribution", "currentVisit" as Any), ("attribution", "frozenLaunch" as Any),
      ("mission", UUID().uuidString as Any), ("component", UUID().uuidString as Any),
      ("id", 0 as Any), ("physicalTime", 99 as Any),
    ] {
      let badCause = try changed(first.cause, field: field, replacement: value)
      let bad = try changed(first, field: "cause", replacement: object(badCause))
      #expect(throws: (any Error).self) { try initial.recording(bad) }
    }
    // A retained archive can exist while adjudication stays unknown. Keep that distinction.
    let archived = try changed(
      first.cause, field: "origin", replacement: object(f.facts().cause.origin))
    let archivedFacts = try changed(first, field: "cause", replacement: object(archived))
    #expect(archivedFacts.structurallyMatches(f.contexts[0]))
    #expect(archivedFacts.cause.attribution == .unknown && archivedFacts.cause.origin != nil)
    let frozen = try changed(archived, field: "attribution", replacement: "frozenLaunch")
    #expect(frozen.shapeValid)
    let origin = try #require(archived.origin)
    let invalidOrigin = try changed(origin, field: "emissionID", replacement: 0)
    let invalidArchive = try changed(archived, field: "origin", replacement: object(invalidOrigin))
    #expect(throws: (any Error).self) {
      try initial.recording(changed(first, field: "cause", replacement: object(invalidArchive)))
    }
  }

}
