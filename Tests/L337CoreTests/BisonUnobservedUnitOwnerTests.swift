import Foundation
import Testing

@testable import L337Core

struct BisonUnobservedUnitOwnerTests {
  @Test
  func actualAllocatorBoundUnobservedIdentitiesRetainWithoutStockOrRepeatedAllocation() throws {
    let (initialGame, request, owner, context, _) = try provisionalConstructor()
    var game = initialGame
    let actor = owner.birthActor
    let before = game
    #expect(owner.units.count == 13 && Set(owner.units.map(\.id)).count == 13)
    #expect(owner.birthActor == actor && owner.birthSpawn == request.identity)
    #expect(owner.units.filter { $0.carrierOrdinal != nil }.count == 12)
    #expect(owner.units[7].physicalRoster == .unobserved && owner.units[12].physicalRoster == .unobserved)
    #expect(owner.units.allSatisfy {
      $0.electrical == .unobserved && $0.gas == .unobserved && $0.thermal == .unobserved
        && $0.mechanical == .unobserved && $0.operative == .unobserved
    })
    let retained = try game.reserveBisonUnobservedUnits(request: request, context: context)
    #expect(retained == owner)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(!game.bodies.contains { $0.physical?.identity == actor })
    #expect(CurrentNewtKitSource.bison?.sourceQualifiedForBirth == false)
  }

  @Test
  func actualClockRetentionIsMonotoneWhileStartupServiceAndCommissioningRefuseAtomically() throws {
    let (initialGame, _, initialOwner, _, _) = try provisionalConstructor()
    var game = initialGame
    var owner = initialOwner
    let allocation = owner
    // Existing real tick owner supplies the clock. The provisional unit identities
    // are not a born/admitted Bison or a reason to create another physics loop.
    game.tick(delta: 0.1)
    try #require(game.commander.flightSimulation.physicalTime > allocation.retainedAt)
    try game.retainBisonUnobservedUnits(&owner)
    #expect(owner.retainedAt == game.commander.flightSimulation.physicalTime)
    #expect(owner.units == allocation.units && owner.allocatedAt == allocation.allocatedAt)
    let journal = try #require(game.commander.savedBisonUnitAllocations)
    #expect(try journal.owner(for: owner.birthRequest, in: game) == owner)
    #expect(throws: BisonUnitRetentionError.foreignAllocation) {
      try game.encodeBisonUnobservedUnits(allocation)
    }
    let before = owner
    let beforeGame = game
    #expect(throws: BisonUnitRetentionError.unobservedElectricalStore) { try game.startBisonUnitService(&owner) }
    #expect(throws: BisonUnitRetentionError.unboundCompleteIssueClock) { try game.advanceBisonUnitService(&owner) }
    #expect(throws: BisonUnitRetentionError.missingPhysicalCommissioningInputs) { try game.requireBisonUnitCommissioning(owner) }
    #expect(owner == before && game.commander == beforeGame.commander && game.bodies == beforeGame.bodies)
    let restored = try game.restoreBisonUnobservedUnits(game.encodeBisonUnobservedUnits(owner), matching: owner)
    #expect(restored == owner && restored.units == allocation.units)
  }

  @Test(arguments: ["duplicate-id", "alias-id", "known-operative", "invented-pressure", "invented-charge", "invented-service-origin", "future-clock", "old-source", "missing-unit", "old-version"])
  func currentColdCannotMintObservationsReplaceIdentityOrRepairMissingState(fault: String) throws {
    let (game, _, owner, _, _) = try provisionalConstructor()
    let actor = owner.birthActor
    let wire = try game.encodeBisonUnobservedUnits(owner)
    let decodedObject = try JSONSerialization.jsonObject(with: wire)
    var object = try #require(decodedObject as? [String: Any])
    var units = try #require(object["units"] as? [[String: Any]])
    switch fault {
    case "duplicate-id": units[1]["id"] = units[0]["id"]
    case "alias-id": units[0]["id"] = UUID().uuidString
    case "known-operative": units[0]["operative"] = "operative"
    case "invented-pressure": units[0]["pressurePascals"] = 101213.92398751198
    case "invented-charge": units[0]["electricalJoules"] = 1380000
    case "invented-service-origin": object["serviceOrigin"] = owner.allocatedAt
    case "future-clock": object["retainedAt"] = game.commander.flightSimulation.physicalTime + 1
    case "old-source": object["sourceSHA256"] = "1430e8d1a3fdbcf0c933e94e7b406be021ee6cff8a54cffaebe652280184b631"
    case "missing-unit": units.removeLast()
    case "old-version": object["version"] = 1
    default: Issue.record("Unknown cold negative control"); return
    }
    object["units"] = units
    let altered = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: (any Error).self) { try game.restoreBisonUnobservedUnits(altered, matching: owner) }
    #expect(try game.restoreBisonUnobservedUnits(wire, matching: owner) == owner)
    #expect(!game.bodies.contains { $0.physical?.identity == actor })
  }

  @Test
  func foreignSourceAndStaleColdCannotSpendOrReplaceTheRetainedOwner() throws {
    let (initialGame, request, original, _, _) = try provisionalConstructor()
    var game = initialGame
    let oldWire = try game.encodeBisonUnobservedUnits(original)
    var retained = original
    game.tick(delta: 0.1)
    try game.retainBisonUnobservedUnits(&retained)
    let before = retained
    #expect(throws: BisonUnitRetentionError.invalidCurrentWire) {
      try game.restoreBisonUnobservedUnits(oldWire, matching: retained)
    }
    var foreign = request
    foreign.currentNewtKitConfiguration = CurrentNewtKitPhysicalSource.configurationID
    let currentContext = try #require(game.gameplayContext())
    #expect(throws: (any Error).self) {
      try game.reserveBisonUnobservedUnits(request: foreign, context: currentContext)
    }
    #expect(retained == before && retained.units == original.units)
    #expect(CurrentNewtKitSource.bison?.sourceQualifiedForBirth == false)
  }

  @Test
  func journalReentryAfterOtherAllocationsUsesOriginalActorAndIds() throws {
    let (initialGame, request, owner, _, _) = try provisionalConstructor()
    var game = initialGame
    let earlier = try game.encodeBisonUnitJournal(try #require(game.commander.savedBisonUnitAllocations))
    let allocatedActor = game.commander.flightSimulation.allocateActor()
    _ = try #require(allocatedActor)
    game.tick(delta: 0.1)
    let before = game
    let retained = try game.reserveBisonUnobservedUnits(request: request,
      context: try #require(game.gameplayContext()))
    #expect(retained.id == owner.id && retained.units == owner.units && retained.birthActor == owner.birthActor)
    #expect(retained.retainedAt == game.commander.flightSimulation.physicalTime)
    #expect(game.commander.flightSimulation == before.commander.flightSimulation && game.bodies == before.bodies)
    var expectedCommander = before.commander
    expectedCommander.savedBisonUnitAllocations = game.commander.savedBisonUnitAllocations
    #expect(game.commander == expectedCommander)
    let actual = try #require(game.commander.savedBisonUnitAllocations)
    #expect(try actual.owner(for: request, in: game) == retained)
    #expect(throws: BisonUnitJournalError.invalidJournal) {
      try game.restoreBisonUnitJournal(earlier, matching: actual)
    }
    #expect(try game.restoreBisonUnitJournal(try game.encodeBisonUnitJournal(actual), matching: actual) == actual)
  }

  @Test
  func twoActualReservationsHaveDisjointIdsAndReenterIndependently() throws {
    let (initialGame, original, first, context, _) = try provisionalConstructor()
    var game = initialGame
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    var request = SpawnRequest(identity: .init(system: original.identity.system, visit: original.identity.visit,
      sequence: sequence, member: 0, producer: .ambient), population: original.population, hull: original.hull,
      position: original.position, orientation: original.orientation, velocity: original.velocity,
      npc: original.npc, rock: nil, payload: nil, priority: original.priority, catalogueShipID: original.catalogueShipID)
    request.currentNewtKitConfiguration = original.currentNewtKitConfiguration
    let beforeCursor = game.commander.flightSimulation.nextActor
    let second = try game.reserveBisonUnobservedUnits(request: request, context: context)
    #expect(game.commander.flightSimulation.nextActor == beforeCursor + 1)
    #expect(first.id != second.id && first.birthActor != second.birthActor)
    #expect(Set(first.units.map(\.id)).isDisjoint(with: Set(second.units.map(\.id))))
    let before = game
    let retainedFirst = try game.reserveBisonUnobservedUnits(request: original, context: context)
    #expect(retainedFirst == first)
    let retainedSecond = try game.reserveBisonUnobservedUnits(request: request, context: context)
    #expect(retainedSecond == second)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
  }

  @Test
  func journalConflictingReentryAndStaleContextRollBackAllocatorAndOwner() throws {
    let (initialGame, request, owner, context, initialJournal) = try provisionalConstructor()
    var game = initialGame
    var conflict = request
    conflict.angularVelocity = .init(1, 0, 0)
    let before = game
    #expect(throws: BisonUnitJournalError.conflictingReentry) {
      try game.reserveBisonUnobservedUnits(request: conflict, context: context)
    }
    #expect(game.commander.savedBisonUnitAllocations == initialJournal && game.commander == before.commander && game.bodies == before.bodies)
    game.tick(delta: 0.1)
    let later = game
    #expect(throws: BisonUnitJournalError.staleContext) {
      try game.reserveBisonUnobservedUnits(request: request, context: context)
    }
    #expect(game.commander.savedBisonUnitAllocations == initialJournal && game.commander == later.commander && game.bodies == later.bodies)
    #expect(try initialJournal.owner(for: request, in: game)?.units == owner.units)
  }

  @Test(arguments: ["foreign-commander", "changed-journal", "duplicate-allocation", "counter-ahead", "future-clock", "operative", "missing-allocation", "invented-root", "old-version"])
  func currentJournalCannotReplaceAllocationOrClaimRootAuthority(fault: String) throws {
    let (game, _, _, _, journal) = try provisionalConstructor()
    let wire = try game.encodeBisonUnitJournal(journal)
    let decodedObject = try JSONSerialization.jsonObject(with: wire)
    var object = try #require(decodedObject as? [String: Any])
    var entries = try #require(object["allocations"] as? [[String: Any]])
    switch fault {
    case "foreign-commander": object["commanderID"] = UUID().uuidString
    case "changed-journal": object["id"] = UUID().uuidString
    case "duplicate-allocation": entries.append(entries[0])
    case "counter-ahead": object["actorCeiling"] = game.commander.flightSimulation.nextActor + 1
    case "future-clock": object["retainedAt"] = game.commander.flightSimulation.physicalTime + 1
    case "operative":
      var value = try #require(entries[0]["wire"] as? [String: Any])
      var units = try #require(value["units"] as? [[String: Any]])
      units[0]["operative"] = "operative"
      value["units"] = units
      entries[0]["wire"] = value
    case "missing-allocation": entries.removeAll()
    case "invented-root": object["qualifiedBirth"] = true
    case "old-version": object["version"] = 1
    default: Issue.record("Unknown journal negative control"); return
    }
    object["allocations"] = entries
    #expect(throws: (any Error).self) {
      try game.restoreBisonUnitJournal(JSONSerialization.data(withJSONObject: object), matching: journal)
    }
    #expect(try game.restoreBisonUnitJournal(wire, matching: journal) == journal)
  }

  @Test
  func actualPhysicalRefusalRetainsReservationWithoutBodyOrServiceEffects() throws {
    let (initialGame, request, owner, context, initialJournal) = try provisionalConstructor()
    var game = initialGame
    let before = game
    #expect(throws: BisonUnitRetentionError.missingPhysicalCommissioningInputs) {
      try game.requireBisonUnitCommissioning(owner)
    }
    let again = try game.reserveBisonUnobservedUnits(request: request, context: context)
    #expect(again == owner && game.commander.savedBisonUnitAllocations == initialJournal)
    #expect(game.commander == before.commander && game.bodies == before.bodies)
    #expect(!game.bodies.contains { $0.physical?.identity == owner.birthActor })
    #expect(CurrentNewtKitSource.bison?.sourceQualifiedForBirth == false)
  }

  @Test(arguments: ["nil", "replaced", "foreign", "removed-entry", "copied-old-entry", "request-rewrite", "advanced-checkpoint"])
  func heldLegitimateOwnerCannotEscapeCanonicalJournalBinding(fault: String) throws {
    let (initialGame, request, originalOwner, context, _) = try provisionalConstructor()
    var game = initialGame
    let originalWire = try game.encodeBisonUnobservedUnits(originalOwner)
    switch fault {
    case "nil": game.commander.savedBisonUnitAllocations = nil
    case "replaced":
      // Replace with a second genuinely allocated journal in the same actual
      // root, preserving the held first owner for the negative operation.
      game.commander.savedBisonUnitAllocations = nil
      _ = try game.reserveBisonUnobservedUnits(request: request, context: context)
      #expect(game.commander.savedBisonUnitAllocations?.valid(in: game) == true)
    case "foreign":
      let (_, _, _, _, foreign) = try provisionalConstructor()
      game.commander.savedBisonUnitAllocations = foreign
    case "removed-entry":
      let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
      let sequence = try #require(allocatedSequence)
      var second = SpawnRequest(identity: .init(system: request.identity.system, visit: request.identity.visit,
        sequence: sequence, member: 0, producer: .ambient), population: request.population, hull: request.hull,
        position: request.position, orientation: request.orientation, velocity: request.velocity,
        npc: request.npc, rock: nil, payload: nil, priority: request.priority, catalogueShipID: request.catalogueShipID)
      second.currentNewtKitConfiguration = request.currentNewtKitConfiguration
      _ = try game.reserveBisonUnobservedUnits(request: second, context: context)
      let actual = try #require(game.commander.savedBisonUnitAllocations)
      let encodedJournal = try game.encodeBisonUnitJournal(actual)
      let decodedObject = try JSONSerialization.jsonObject(with: encodedJournal)
      var object = try #require(decodedObject as? [String: Any])
      var entries = try #require(object["allocations"] as? [[String: Any]])
      entries.removeFirst()
      object["allocations"] = entries
      game.commander.savedBisonUnitAllocations = try JSONDecoder().decode(BisonUnitAllocationJournal.self,
        from: JSONSerialization.data(withJSONObject: object))
      #expect(game.commander.savedBisonUnitAllocations?.valid(in: game) == true)
    case "copied-old-entry", "request-rewrite":
      let actual = try #require(game.commander.savedBisonUnitAllocations)
      let encodedJournal = try game.encodeBisonUnitJournal(actual)
      let decodedObject = try JSONSerialization.jsonObject(with: encodedJournal)
      var object = try #require(decodedObject as? [String: Any])
      var entries = try #require(object["allocations"] as? [[String: Any]])
      var wire = try #require(entries[0]["wire"] as? [String: Any])
      if fault == "copied-old-entry" {
        let replacementID = UUID().uuidString
        object["id"] = replacementID
        wire["allocationJournalID"] = replacementID
      } else {
        var rewritten = request
        rewritten.angularVelocity = .init(1, 0, 0)
        let record = try JSONSerialization.jsonObject(with: JSONEncoder().encode(rewritten))
        entries[0]["request"] = record
        wire["birthRequest"] = record
      }
      entries[0]["wire"] = wire
      object["allocations"] = entries
      game.commander.savedBisonUnitAllocations = try JSONDecoder().decode(BisonUnitAllocationJournal.self,
        from: JSONSerialization.data(withJSONObject: object))
      // These controls are internally coherent current journals. The held
      // owner's exact original journal/request still must fail the actual join.
      #expect(game.commander.savedBisonUnitAllocations?.valid(in: game) == true)
    case "advanced-checkpoint":
      game.tick(delta: 0.1)
      _ = try game.reserveBisonUnobservedUnits(request: request,
        context: try #require(game.gameplayContext()))
    default: Issue.record("Unknown held legitimate owner control"); return
    }
    let before = game
    var held = originalOwner
    #expect(throws: BisonUnitRetentionError.foreignAllocation) { try game.retainBisonUnobservedUnits(&held) }
    #expect(held == originalOwner && game.commander == before.commander && game.bodies == before.bodies)
    #expect(throws: BisonUnitRetentionError.foreignAllocation) { try game.startBisonUnitService(&held) }
    #expect(held == originalOwner && game.commander == before.commander && game.bodies == before.bodies)
    #expect(throws: BisonUnitRetentionError.foreignAllocation) { try game.advanceBisonUnitService(&held) }
    #expect(held == originalOwner && game.commander == before.commander && game.bodies == before.bodies)
    #expect(throws: BisonUnitRetentionError.foreignAllocation) { try game.requireBisonUnitCommissioning(held) }
    #expect(held == originalOwner && game.commander == before.commander && game.bodies == before.bodies)
    #expect(throws: BisonUnitRetentionError.foreignAllocation) { try game.encodeBisonUnobservedUnits(held) }
    #expect(held == originalOwner && game.commander == before.commander && game.bodies == before.bodies)
    #expect(throws: BisonUnitRetentionError.foreignAllocation) {
      try game.restoreBisonUnobservedUnits(originalWire, matching: held)
    }
    #expect(held == originalOwner && game.commander == before.commander && game.bodies == before.bodies)
  }

  /// Controlled unpublished journal fixture using the actual actor/spawn
  /// allocators and source request rules. It asserts no birth/commissioning or
  /// physical observations, creates no kit/people/charge and admits no body.
  func provisionalConstructor() throws -> (Game, SpawnRequest, BisonUnobservedUnitOwner, EncounterContext, BisonUnitAllocationJournal) {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.launch()
    try prepareEMPUnitScene(&game)
    let anchors = try #require(game.commander.flightSimulation.anchors)
    NativePagedSalvageFixture.moveObserver(&game, to: .init(
      position: (anchors.arrival + anchors.station.position) * 0.5,
      orientation: game.commander.flightSimulation.pose.orientation))
    let context = try #require(game.gameplayContext())
    let source = try #require(CurrentNewtKitSource.bison)
    let parent = try #require(OriginalFleetRuntimeHullSource.source(for: "SH005"))
    let allocatedSequence = game.commander.flightSimulation.allocateSpawn()
    let sequence = try #require(allocatedSequence)
    var npc = NPCState(role: .trader, origin: context.system, destination: context.system)
    npc.resources = NPCResources.stock(parent.performance)
    npc.legalProvenance = .generated
    npc.cargoProvenance = .generated
    npc.routeProvenance = .generated
    var request = SpawnRequest(identity: .init(system: context.system, visit: context.visit,
      sequence: sequence, member: 0, producer: .ambient), population: .civilian, hull: .cobra,
      position: anchors.arrival, orientation: .init(), velocity: .init(0, 0, 0), npc: npc,
      rock: nil, payload: nil, priority: .ordinary, catalogueShipID: "SH005")
    request.currentNewtKitConfiguration = source.configuration
    try #require(source.permitsBirthDefinition(request, context: context))
    let owner = try game.reserveBisonUnobservedUnits(request: request, context: context)
    return (game, request, owner, context, try #require(game.commander.savedBisonUnitAllocations))
  }
}
