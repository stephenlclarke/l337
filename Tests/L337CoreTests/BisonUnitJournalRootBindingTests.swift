import Foundation
import Testing

@testable import L337Core

/// These tests require the bundled unapplied Game/constructor root patch.
/// No body or physical commissioning is claimed by this UNOBSERVED version.
struct BisonUnitJournalRootBindingTests {
  @Test
  func actualCommanderWireRetainsJournalAndReentryWithoutNewIds() throws {
    let (initialGame, request, owner, _, journal) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var game = initialGame
    let wire = try JSONEncoder().encode(game.commander)
    let restored = try JSONDecoder().decode(Commander.self, from: wire)
    #expect(restored == game.commander && restored.savedBisonUnitAllocations == journal)
    game.commander = restored
    #expect(journal.valid(in: game))
    let before = game
    let same = try game.reserveBisonUnobservedUnits(request: request,
      context: try #require(game.gameplayContext()))
    #expect(same == owner && game.commander == before.commander && game.bodies == before.bodies)

    // Both complete equality paths include the optional journal. Dropping it
    // changes only this field; two absent values still compare exactly equal.
    #expect(game.currentNewtNativeCommanderMatches(before))
    var absent = game
    absent.commander.savedBisonUnitAllocations = nil
    let absentCopy = absent
    #expect(game.commander != absent.commander)
    #expect(!game.currentNewtNativeCommanderMatches(absent))
    #expect(!absent.currentNewtNativeCommanderMatches(game))
    #expect(absent.commander == absentCopy.commander)
    #expect(absent.currentNewtNativeCommanderMatches(absentCopy))

    // Isolate the genuine journal from the launch calendar. A retained journal
    // requires durability even while every other retained feature is absent.
    var journalOnly = absent
    journalOnly.commander.scriptState = ScriptEngineState()
    journalOnly.commander.accommodation = ShipAccommodation()
    try #require(!journalOnly.requiresScriptDurability)
    #expect(!journalOnly.nativeDurabilityBison())
    journalOnly.commander.savedBisonUnitAllocations = journal
    try #require(journal.valid(in: journalOnly))
    let durabilityOpening = journalOnly
    for _ in 0..<3 {
      #expect(journalOnly.nativeDurabilityBison() && journalOnly.requiresScriptDurability)
    }
    #expect(journalOnly.currentNewtNativeCommanderMatches(durabilityOpening))
    #expect(journalOnly.bodies == durabilityOpening.bodies)
    journalOnly.commander.savedBisonUnitAllocations = nil
    #expect(!journalOnly.nativeDurabilityBison() && !journalOnly.requiresScriptDurability)

    // Real clock/retention creates changed journal contents. Align every other
    // field before comparison; both retained snapshots remain valid at this time.
    var advanced = game
    advanced.tick(delta: 0.1)
    var retainedOwner = owner
    try advanced.retainBisonUnobservedUnits(&retainedOwner)
    let changedJournal = try #require(advanced.commander.savedBisonUnitAllocations)
    try #require(changedJournal != journal && changedJournal.valid(in: advanced.commander))
    try #require(journal.valid(in: advanced.commander))
    var originalJournalOnly = advanced
    originalJournalOnly.commander.savedBisonUnitAllocations = journal
    #expect(advanced.commander != originalJournalOnly.commander)
    #expect(!advanced.currentNewtNativeCommanderMatches(originalJournalOnly))
    #expect(!originalJournalOnly.currentNewtNativeCommanderMatches(advanced))
    let advancedCopy = advanced
    #expect(advanced.commander == advancedCopy.commander)
    #expect(advanced.currentNewtNativeCommanderMatches(advancedCopy))
  }

  @Test(arguments: ["foreign-owner", "actor-counter-behind", "source-hash", "invented-pressure"])
  func decodedRootCannotBindForeignAllocatorOrObservedState(fault: String) throws {
    let (game, _, _, _, _) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    let encodedCommander = try JSONEncoder().encode(game.commander)
    let decodedRoot = try JSONSerialization.jsonObject(with: encodedCommander)
    var root = try #require(decodedRoot as? [String: Any])
    var journal = try #require(root["savedBisonUnitAllocations"] as? [String: Any])
    switch fault {
    case "foreign-owner": journal["commanderID"] = UUID().uuidString
    case "actor-counter-behind":
      var flight = try #require(root["savedFlightSimulation"] as? [String: Any])
      flight["nextActor"] = 2
      root["savedFlightSimulation"] = flight
    case "source-hash", "invented-pressure":
      var entries = try #require(journal["allocations"] as? [[String: Any]])
      var value = try #require(entries[0]["wire"] as? [String: Any])
      if fault == "source-hash" { value["sourceSHA256"] = "obsolete-source" }
      else {
        var units = try #require(value["units"] as? [[String: Any]])
        units[0]["pressurePascals"] = 101213.92398751198
        value["units"] = units
      }
      entries[0]["wire"] = value
      journal["allocations"] = entries
    default: Issue.record("Unknown actual root negative control"); return
    }
    root["savedBisonUnitAllocations"] = journal
    let bytes = try JSONSerialization.data(withJSONObject: root)
    do {
      let decoded = try JSONDecoder().decode(Commander.self, from: bytes)
      #expect(decoded.savedBisonUnitAllocations?.valid(in: decoded) == false)
    } catch {
      // Strict source/state structure may refuse during decode itself.
    }
  }

  @Test
  func actualAdmissionKeepsUnqualifiedPreflightAndExistingReservation() throws {
    let (initialGame, request, owner, _, journal) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var game = initialGame
    let context = try #require(game.gameplayContext())
    let before = game
    let plan = EncounterPlan(system: context.system, visit: context.visit, revision: context.revision,
      batches: [.init(requests: [request], atomic: false)], intents: [])
    let receipts = game.admitEncounterPlan(plan)
    #expect(receipts.count == 1 && receipts[0].actor == nil && receipts[0].refusal != nil)
    #expect(game.commander.savedBisonUnitAllocations == journal)
    #expect(game.commander.flightSimulation.nextActor == before.commander.flightSimulation.nextActor)
    #expect(!game.bodies.contains { $0.physical?.identity == owner.birthActor })
    #expect(CurrentNewtKitSource.bison?.sourceQualifiedForBirth == false)
  }

  @Test
  func failedReservationAfterNativeActorAllocationRollsBackCursorAndJournal() throws {
    let (initialGame, original, _, _, journal) = try BisonUnobservedUnitOwnerTests().provisionalConstructor()
    var game = initialGame
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    var request = SpawnRequest(identity: .init(system: original.identity.system, visit: original.identity.visit,
      sequence: sequence, member: 0, producer: .ambient), population: original.population, hull: original.hull,
      position: original.position, orientation: original.orientation, velocity: original.velocity,
      npc: original.npc, rock: nil, payload: nil, priority: original.priority, catalogueShipID: original.catalogueShipID)
    request.currentNewtKitConfiguration = original.currentNewtKitConfiguration
    let index = try #require(game.bodies.firstIndex { $0.physical != nil })
    // A hostile alias already occupies the proposed spawn. The allocator runs
    // only in a copied candidate, then the real pre-snapshot owner rejects it.
    game.bodies[index].physical?.spawnIdentity = request.identity
    let context = try #require(game.gameplayContext())
    let before = game
    #expect(throws: BisonUnitRetentionError.invalidBirthCandidate) {
      try game.reserveBisonUnobservedUnits(request: request, context: context)
    }
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(game.commander.savedBisonUnitAllocations == journal)
  }
}
