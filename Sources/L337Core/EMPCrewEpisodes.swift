import Foundation

struct EMPCrewEjection: Equatable, Codable, Sendable {
  let ordinal: Int
  let delay: Double
  var emittedAt: Double?
}

/// Timing evidence. Electrical recovery and traffic ownership stay with the runtime.
struct EMPCrewDisableEpisode: Equatable, Codable, Sendable {
  let incident: CombatIncident
  let weapon: OwnedEquipmentItem
  let weaponOwner: UUID
  var ejections: [EMPCrewEjection]
  var actorBindings: [ActorIdentity]
  var deadline: Double { incident.physicalTime + 30 }
  func valid(source: ActorIdentity, crewTotal: Int) -> Bool {
    incident.id > 0 && incident.kind == .emp && incident.outcome == .hit
      && incident.origin.emissionID > 0 && incident.position.finite && !incident.victimIsStation
      && weapon.node == EquipmentRuntimeCatalog.node(for: Equipment.empPirateBlaster)
      && weapon.location?.slot == .utility(.empPirateBlaster) && weapon.component == nil
      && incident.origin.sourcePart == "emp:" + weapon.id.uuidString
      && incident.origin.ordnance == nil && incident.origin.playerAmmunition == nil
      && incident.victim?.system == source.system && (incident.victim?.entity ?? 0) > 1
      && incident.origin.owner.entity == 0 && incident.origin.owner.system == source.system
      && incident.origin.owner.visit == incident.victim?.visit
      && incident.physicalTime.isFinite && incident.physicalTime >= 0
      && deadline.isFinite && incident.origin.emittedAt == incident.physicalTime
      && (0...EMPState.maximumPeople).contains(crewTotal)
      && ejections.count >= (crewTotal == 0 ? 0 : 1) && ejections.count <= crewTotal
      && (1...EMPState.maximumPeople).contains(actorBindings.count)
      && Set(actorBindings).count == actorBindings.count
      && actorBindings.first == incident.victim
      && actorBindings.allSatisfy {
        $0.system == source.system && $0.entity > 1
          && $0.visit >= (incident.victim?.visit ?? UInt64.max)
      }
      && Set(ejections.map(\.ordinal)).count == ejections.count
      && ejections.allSatisfy { entry in
        (0..<crewTotal).contains(entry.ordinal) && entry.delay.isFinite
          && (0.5...45).contains(entry.delay)
          && (entry.emittedAt.map {
            $0.isFinite && $0 >= incident.physicalTime + entry.delay && $0 < deadline
          } ?? true)
      }
  }
}

extension EMPCrewDisableEpisode {
  private enum CodingKeys: String, CodingKey {
    case incident, weapon, weaponOwner, ejections, actorBindings
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    guard
      let schedule = try NativePeopleDecoding.array(
        values, key: .ejections, type: EMPCrewEjection.self)
    else { throw SaveError.invalidCommander }
    guard
      let bindings = try NativePeopleDecoding.array(
        values, key: .actorBindings, type: ActorIdentity.self)
    else { throw SaveError.invalidCommander }
    self.init(
      incident: try values.decode(CombatIncident.self, forKey: .incident),
      weapon: try values.decode(OwnedEquipmentItem.self, forKey: .weapon),
      weaponOwner: try values.decode(UUID.self, forKey: .weaponOwner),
      ejections: schedule, actorBindings: bindings)
  }
}

extension EMPHullRecord {
  static let maximumDisableEpisodes = 32
  var disableEpisodes: [EMPCrewDisableEpisode] { savedDisableEpisodes ?? [] }
  var currentCrewDisableIncident: CombatIncident {
    disableEpisodes.last?.incident ?? disableIncident
  }
  var aboardOrdinals: [Int] {
    guard (1...EMPState.maximumPeople).contains(crewTotal) else { return [] }
    return (0..<crewTotal).filter { crewOutcome(ordinal: $0) == .aboard }
  }
  func podIndex(for ordinal: Int) -> Int? {
    pods.firstIndex { $0.body.physical?.empCrewPod == .init(source: source, ordinal: ordinal) }
  }
  func podEjectionLowerBound(for ordinal: Int) -> Double? {
    guard podIndex(for: ordinal) != nil else { return nil }
    for episode in disableEpisodes {
      if let emitted = episode.ejections.first(where: { $0.ordinal == ordinal })?.emittedAt {
        return emitted
      }
    }
    return nil
  }
  func nextDueCrew(at time: Double) -> Int? {
    guard time.isFinite, let episode = disableEpisodes.last, time < episode.deadline else {
      return nil
    }
    return episode.ejections.filter {
      crewOutcome(ordinal: $0.ordinal) == .aboard
        && episode.incident.physicalTime + $0.delay <= time
    }.min {
      ($0.delay, $0.ordinal) < ($1.delay, $1.ordinal)
    }?.ordinal
  }
  /// Called only by the actual-zero producer, once for the original surviving complement.
  mutating func appendCrewDisableEpisode(
    incident: CombatIncident, weapon: OwnedEquipmentItem, owner: UUID,
    ejections: [EMPCrewEjection]
  )
    -> Bool
  {
    guard let victim = incident.victim else { return false }
    let episode = EMPCrewDisableEpisode(
      incident: incident, weapon: weapon, weaponOwner: owner,
      ejections: ejections, actorBindings: [victim])
    guard !terminal, (crewTotal == 0 || crewAboard > 0),
      disableEpisodes.count < Self.maximumDisableEpisodes,
      episode.valid(source: source, crewTotal: crewTotal),
      owner == weaponOwner,
      Set(ejections.map(\.ordinal)) == Set(aboardOrdinals),
      disableEpisodes.isEmpty || incident.victim == hull.body.physical?.identity,
      disableEpisodes.last.map({
        incident.id > $0.incident.id && incident.physicalTime >= $0.deadline
      })
        ?? (incident == disableIncident)
    else { return false }
    savedDisableEpisodes = disableEpisodes + [episode]
    nextEjectionAt = incident.physicalTime + (ejections.map(\.delay).min() ?? 45)
    return true
  }
  var crewCensusValid: Bool {
    guard crewCensusBoundsAreValid(), let discharged = crewCensusDischarges(),
      crewCensusEpisodesAreValid(), crewCensusEpisodeOriginsAreValid(),
      crewCensusEpisodeOrderIsValid(), currentCrewCensusIsValid(), historicalCrewCensusIsValid()
    else { return false }
    return crewCensusEmissionsAreValid(ejected: discharged.ejected, captured: discharged.captured)
  }

  // Preserve the census algorithm while ending each phase's transient values before the next.
  @inline(never)
  private func crewCensusBoundsAreValid() -> Bool {
    guard (0...EMPState.maximumPeople).contains(crewTotal), pods.count <= crewTotal,
      crewCaptures.count <= EMPState.maximumPeople,
      disableEpisodes.count <= Self.maximumDisableEpisodes,
      !disableEpisodes.isEmpty,
      savedDeceasedOrdinals == nil || !deceasedOrdinals.isEmpty,
      (0...crewTotal).contains(lostCrewCount), deceasedOrdinals.count == lostCrewCount
    else { return false }
    return true
  }

  @inline(never)
  private func crewCensusDischarges() -> (ejected: [Int], captured: [Int])? {
    let ejected = pods.compactMap { $0.body.physical?.empCrewPod?.ordinal }
    let captured = crewCaptures.flatMap(\.ordinals)
    let discharged = ejected + captured + deceasedOrdinals
    guard discharged.count <= crewTotal, Set(discharged).count == discharged.count,
      discharged.allSatisfy({ (0..<crewTotal).contains($0) }), ejected.count == pods.count
    else { return nil }
    return (ejected, captured)
  }

  @inline(never)
  private func crewCensusEpisodesAreValid() -> Bool {
    return disableEpisodes.allSatisfy({
      $0.weaponOwner == weaponOwner && $0.valid(source: source, crewTotal: crewTotal)
    })
  }

  @inline(never)
  private func crewCensusEpisodeOriginsAreValid() -> Bool {
    guard disableEpisodes.first.map({ $0.incident == disableIncident }) ?? true,
      disableEpisodes.first.map({ $0.weapon == weapon && $0.weaponOwner == weaponOwner }) ?? true
    else { return false }
    return true
  }

  @inline(never)
  private func crewCensusEpisodeOrderIsValid() -> Bool {
    guard
      disableEpisodes.enumerated().allSatisfy({ index, episode in
        index == 0
          || (episode.incident.id > disableEpisodes[index - 1].incident.id
            && episode.incident.physicalTime >= disableEpisodes[index - 1].deadline)
      })
    else { return false }
    return true
  }

  @inline(never)
  private func currentCrewCensusIsValid() -> Bool {
    guard let current = disableEpisodes.last,
      Set(aboardOrdinals).isSubset(of: Set(current.ejections.map(\.ordinal))),
      Set(deceasedOrdinals).isSubset(of: Set(current.ejections.map(\.ordinal)))
    else { return false }
    return true
  }

  @inline(never)
  private func historicalCrewCensusIsValid() -> Bool {
    // Historical schedules retain discharged IDs, but no later episode can reissue them.
    for (index, episode) in disableEpisodes.enumerated() {
      let members = Set(episode.ejections.map(\.ordinal))
      if index == 0, members != Set(0..<crewTotal) { return false }
      if index > 0,
        !members.isSubset(of: Set(disableEpisodes[index - 1].ejections.map(\.ordinal)))
      {
        return false
      }
      if crewCaptures.contains(where: {
        $0.physicalTime < episode.incident.physicalTime && !members.isDisjoint(with: $0.ordinals)
      }) {
        return false
      }
      if disableEpisodes.prefix(index).contains(where: { prior in
        prior.ejections.contains { $0.emittedAt != nil && members.contains($0.ordinal) }
      }) {
        return false
      }
    }
    return true
  }

  @inline(never)
  private func crewCensusEmissionsAreValid(ejected: [Int], captured: [Int]) -> Bool {
    let emissions = disableEpisodes.flatMap(\.ejections).filter { $0.emittedAt != nil }
    let emittedOrdinals = emissions.map(\.ordinal)
    guard Set(emittedOrdinals).count == emittedOrdinals.count,
      emissions.allSatisfy({ podIndex(for: $0.ordinal) != nil }),
      Set(emittedOrdinals).isDisjoint(with: captured)
    else { return false }
    guard Set(ejected) == Set(emittedOrdinals) else { return false }
    return true
  }

  mutating func recordCrewEjection(ordinal: Int, at time: Double) -> Bool {
    guard var episodes = savedDisableEpisodes, let index = episodes.indices.last else {
      return false
    }
    guard
      let entry = episodes[index].ejections.firstIndex(where: { $0.ordinal == ordinal }),
      episodes[index].ejections[entry].emittedAt == nil,
      time >= episodes[index].incident.physicalTime + episodes[index].ejections[entry].delay,
      time < episodes[index].deadline
    else { return false }
    // Schedule delay and original ID never change after sampling.
    episodes[index].ejections[entry].emittedAt = time
    savedDisableEpisodes = episodes
    return true
  }

  mutating func recordCrewActorBinding(_ actor: ActorIdentity) -> Bool {
    guard var episodes = savedDisableEpisodes, let index = episodes.indices.last else {
      return false
    }
    let old = episodes[index]
    if old.actorBindings.contains(actor) { return true }
    guard old.actorBindings.count < EMPState.maximumPeople else { return false }
    var changed = old
    changed.actorBindings.append(actor)
    guard changed.valid(source: source, crewTotal: crewTotal) else { return false }
    episodes[index] = changed
    savedDisableEpisodes = episodes
    return true
  }
}

extension Game {
  mutating func sampleEMPCrewEjections(ordinals: [Int]) -> [EMPCrewEjection] {
    ordinals.map { ordinal in
      // Native seeded simulation RNG, independent of the classic galaxy generator.
      .init(ordinal: ordinal, delay: 0.5 + Double(randomByte()) / 255 * 44.5)
    }
  }
}

extension EMPHullRecord {
  func crewEpisodeTimelineValid(flight: FlightSimulationState) -> Bool {
    disableEpisodes.allSatisfy { episode in
      let incident = episode.incident
      return incident.id < flight.nextIncident && incident.origin.emissionID < flight.nextEmission
        && incident.physicalTime <= flight.physicalTime
        && (incident.victim?.visit ?? UInt64.max) <= flight.visit
        && (incident.victim?.entity ?? UInt64.max) < flight.nextActor
        && episode.ejections.allSatisfy { ($0.emittedAt ?? 0) <= flight.physicalTime }
        && episode.actorBindings.allSatisfy {
          $0.visit <= flight.visit && $0.entity < flight.nextActor
        }
    }
  }
}
