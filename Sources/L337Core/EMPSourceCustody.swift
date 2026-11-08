import Foundation

struct EMPSourceCustody: Equatable, Codable, Sendable {
  enum Kind: String, Codable, Sendable { case ordinary, police }
  let kind: Kind
  let logical: ActorIdentity
  let original: EMPStoredObject
  let traffic: NPCPersistenceSnapshot?
  let assignment: PoliceAssignment?

  var valid: Bool {
    guard original.valid else { return false }
    return sourceDetailsAreValid()
  }

  // The original object's full validation precedes physical/NPC/traffic temporaries.
  @inline(never)
  private func sourceDetailsAreValid() -> Bool {
    guard original.body.energy > 0,
      let physical = original.body.physical, let npc = physical.npc,
      physical.empSource == nil, physical.empCrewPod == nil, physical.salvage == nil,
      physical.identity.system == logical.system, physical.identity.visit >= logical.visit,
      logical.entity > 1, logical.visit > 0, npc.role != .mission
    else { return false }
    if kind == .police {
      guard npc.role == .police, physical.population == .police,
        assignment == nil || assignment?.actor == physical.identity
      else { return false }
    } else {
      guard npc.role != .police, !physical.blocksNavalEncounter, traffic != nil, assignment == nil
      else { return false }
    }
    if let traffic {
      guard traffic.valid, traffic.actor == physical.identity, traffic.npc == npc,
        traffic.hull == original.body.hull, traffic.position == original.body.position,
        traffic.energy == original.body.energy, traffic.velocity == physical.velocity,
        traffic.angularVelocity == physical.angularVelocity
      else { return false }
    }
    return true
  }
}

extension Commander {
  var empCustodyStateValid: Bool {
    guard let state = savedEMPState else { return npcPersistence.empTransfers.isEmpty }
    guard state.valid,
      npcPersistence.empTransfers.allSatisfy({ source, snapshot in
        state.records[source]?.isRecovered == false
          && state.records[source]?.activeTrafficTransfer == snapshot
      })
    else { return false }
    for record in state.records.values {
      guard empCustodyRecordLinksAreValid(record) else { return false }
    }
    return true
  }

  /// Read one actual stored record and its existing owner links. Collection-wide
  /// validity remains with the full current publication/load predicate above.
  func nativeEMPCustodyRecord(for source: ActorIdentity) -> EMPHullRecord? {
    guard let state = savedEMPState, let record = state.records[source],
      record.source == source, record.sequence < state.nextSequence, record.valid,
      empCustodyRecordLinksAreValid(record)
    else { return nil }
    return record
  }

  private func empCustodyRecordLinksAreValid(_ record: borrowing EMPHullRecord) -> Bool {
    let sourceSystem = record.source.system
    let nextActor = flightSimulation.nextActor
    let visit = flightSimulation.visit
    let nextIncident = flightSimulation.nextIncident
    let nextEmission = flightSimulation.nextEmission
    let physicalTime = flightSimulation.physicalTime
    let incident = record.disableIncident
    guard record.weaponOwner == equipmentOwnerID,
      record.crewEpisodeTimelineValid(flight: flightSimulation),
      salvageLedger.empSourceIsConsistent(record),
      nativeEMPSourceIsConsistent(record),
      record.source.entity < nextActor,
      record.source.visit <= visit,
      incident.id < nextIncident,
      incident.origin.emissionID < nextEmission,
      incident.physicalTime <= physicalTime,
      ([record.hull] + record.pods).allSatisfy({ object in
        guard let actor = object.body.physical?.identity else { return false }
        return actor.system == sourceSystem && actor.visit > 0
          && actor.visit <= visit && actor.entity > 1
          && actor.entity < nextActor
          && object.physicalTime <= physicalTime
      })
    else { return false }
    if record.isRecovered {
      guard record.savedRecoveredAt.map({ $0 <= physicalTime }) == true,
        npcPersistence.terminalReason(for: record.source) != .empTransferred
      else { return false }
    } else if let traffic = record.activeTrafficTransfer,
      let retained = npcPersistence.snapshot(for: record.source)
    {
      guard retained == traffic else { return false }
      return npcPersistence.terminalReason(for: record.source) == .empTransferred
    }
    return true
  }
}

extension Commander {
  private func nativeEMPSourceIsConsistent(_ record: EMPHullRecord) -> Bool {
    guard let plans = alienStorageState?.current.salvage.native.plansByWreck[record.wreck] else {
      return true
    }
    guard record.pods.count + record.capturedCrewCount == record.crewTotal,
      record.lostCrewCount == 0,
      let catalogue = record.hull.body.physical?.catalogueShipID,
      let profile = SalvageCatalogue.empProfile(catalogueShipID: catalogue)
    else { return false }
    return plans.allSatisfy { value in
      let source = value.plan.source
      return profile.sections.contains { $0.index == value.plan.section.section }
        && source.roles == profile.sourceRoles && source.manifest == record.salvageCargo
        && source.legalValue == record.salvageLegal.value && source.ownership == .abandoned
        && source.stolenProvenance == (record.salvageLegal.value == 0)
        && source.manifestSection == 1 && !source.manifestAlreadySettled
    }
  }
}

extension EMPSourceCustody {
  private enum CodingKeys: String, CodingKey {
    case kind, logical, original, traffic, assignment
  }
  @inline(never)
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(kind, forKey: .kind)
    try values.encode(logical, forKey: .logical)
    try values.encode(NativeSaveEncodingValue<EMPStoredObject>.prepare(original), forKey: .original)
    if let value = NativeSaveEncodingValue<NPCPersistenceSnapshot>.prepareIfPresent(traffic) {
      try values.encode(value, forKey: .traffic)
    }
    try values.encodeIfPresent(assignment, forKey: .assignment)
  }
}
