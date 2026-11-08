import Foundation

public enum StationSecurityPhase: String, Codable, Sendable {
  case calm, investigating, alarm, reinforcing, cooldown
}

public enum PolicePhase: String, Codable, Sendable {
  case patrol, investigate, intercept, engage, search, returning
}

public struct PoliceAssignment: Equatable, Codable, Sendable {
  public let actor: ActorIdentity
  public var target: ActorIdentity?
  public var phase: PolicePhase
  public var lastKnownPosition: Vector3
  public var lastContactAt: Double
}

public struct SecurityPlan: Equatable, Codable, Sendable {
  public let encounters: EncounterPlan
  public let notices: [SecurityNotice]
}

public struct DockingPermission: Equatable, Codable, Sendable {
  public let allowed: Bool
  public let notice: SecurityNotice?
}

private struct SecurityThreat: Equatable, Codable, Sendable {
  var report: VerifiedCrimeReport
  let firstReportedAt: Double
  var lastViolenceAt: Double
  var stationAttacker: Bool
}

/// The same native launch geometry supplies queued requests and conservative envelopes.
struct StationSecurityLaunchDescription {
  static let maximumSlots = 8
  static let hull = Hull.viper
  static let speed = 180.0
  let position: Vector3
  let velocity: Vector3

  static func forwardOffset(slot: Int) -> Double { Double(200 + slot * 220) }
  static func lateralOffset(slot: Int) -> Double { slot % 2 == 0 ? -90 : 90 }

  init(station: StationAnchor, direction: Vector3, slot: Int) {
    position =
      station.exitPosition + direction * Self.forwardOffset(slot: slot)
      + station.orientation.x * Self.lateralOffset(slot: slot)
    velocity = direction * Self.speed
  }
}

/// Runtime-owned value state: reports and plans never mutate bodies or commander data.
public struct StationSecurity: Equatable, Codable, Sendable {
  public private(set) var phase: StationSecurityPhase = .calm
  public private(set) var assignments: [PoliceAssignment] = []
  private var threats: [SecurityThreat] = []
  private var lastReportID: UInt64?
  private var system: SystemIdentity?
  private var visit: UInt64?
  private var nextWaveAt: Double?
  private var firstStationWave = true
  private var ordinaryWaveSent = false
  private var pending: [SpawnBatch] = []
  private var sequence: UInt64 = 0
  private var announcedAlarm = false
  private var announcedInvestigation = false
  private var cooldownAt: Double?
  public init() {}

  /// Covers all native slots at any station angle and actual historical queued positions.
  /// Does not run alarm/AI policy, acknowledge, allocate, or create a request.
  func manualControlPairLaunchEnvelopes(station: StationAnchor, rotation: Double)
    -> [(volume: ManualControlPairEnvelope, speed: Double)]?
  {
    typealias Bound = ManualControlPairEnvelope
    guard station.position.finite, station.exitPosition.finite,
      station.orientation.validRotation, station.exitDirection.finite,
      station.exitDirection.length.isFinite, station.exitDirection.length > 2 * 1e-9,
      rotation.isFinite, rotation >= 0 else { return nil }
    guard pending.count <= StationSecurityLaunchDescription.maximumSlots else { return nil }
    var queued = 0
    let direction = station.exitDirection.unit
    var result: [(volume: Bound, speed: Double)] = []
    for slot in 0..<StationSecurityLaunchDescription.maximumSlots {
      let launch = StationSecurityLaunchDescription(station: station, direction: direction, slot: slot)
      guard launch.position.finite, launch.velocity.finite else { return nil }
      let reach = Bound.sum(
        Bound.l1(station.exitPosition - station.position),
        Bound.product(Bound.l1(direction), abs(StationSecurityLaunchDescription.forwardOffset(slot: slot))),
        Bound.product(Bound.l1(station.orientation.x), abs(StationSecurityLaunchDescription.lateralOffset(slot: slot))))
      // Enclose the rotation of the native lever arms, not the whole station-to-slot ball.
      // Four covers normalized direction and both approximate frame transforms.
      let extent = Bound.product(reach, min(4, Bound.product(4, rotation)))
      let radius = Bound.sum(extent, Bound.roundoff(Bound.sum(Bound.l1(station.position), reach)))
      let volume = Bound(position: launch.position, radius: radius)
      guard volume.valid else { return nil }
      result.append((volume: volume, speed: Bound.product(2, StationSecurityLaunchDescription.speed)))
    }
    for batch in pending {
      guard !batch.requests.isEmpty,
        batch.requests.count <= StationSecurityLaunchDescription.maximumSlots - queued
      else { return nil }
      queued += batch.requests.count
      for request in batch.requests {
        guard request.hull == StationSecurityLaunchDescription.hull,
          request.population == .police, request.position.finite, request.velocity.finite,
          request.velocity.length.isFinite,
          request.orientation.validRotation, request.identity.producer == .security,
          request.priority == .police, request.energy == nil, request.salvage == nil,
          request.angularVelocity == .init(0, 0, 0), request.npc?.resources == nil,
          request.npc?.intention == nil,
          request.npc?.role == .police, request.npc?.ordinaryCargo.isEmpty == true,
          request.rock == nil, request.payload == nil, request.catalogueShipID == nil
        else { return nil }
        let volume = Bound(position: request.position, radius: Bound.roundoff(Bound.l1(request.position)))
        guard volume.valid else { return nil }
        result.append((volume: volume, speed: Bound.l1(request.velocity)))
      }
    }
    return result
  }

  public mutating func receive(_ report: VerifiedCrimeReport) {
    guard report.physicalTime.isFinite, report.physicalTime >= 0, report.position.finite,
      lastReportID.map({ report.incidentID > $0 }) ?? true
    else { return }
    lastReportID = report.incidentID
    if let index = threats.firstIndex(where: { $0.report.offender == report.offender }) {
      threats[index].report = report
      threats[index].lastViolenceAt = report.physicalTime
      threats[index].stationAttacker =
        threats[index].stationAttacker || report.kind == .stationAttack
    } else {
      threats.append(
        .init(
          report: report, firstReportedAt: report.physicalTime,
          lastViolenceAt: report.physicalTime, stationAttacker: report.kind == .stationAttack))
    }
    if report.kind == .stationAttack {
      if nextWaveAt == nil { nextWaveAt = report.physicalTime + 4 }
      if phase != .reinforcing { phase = .alarm }
    } else if phase == .calm || phase == .cooldown {
      phase = .investigating
      ordinaryWaveSent = false
    }
    cooldownAt = nil
  }

  /// Exact current wave ownership is checked again before the atomic admission transaction.
  func ownsPendingLaunch(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard system == context.system, visit == context.visit,
      request.identity.system == context.system, request.identity.visit == context.visit,
      request.identity.producer == .security, request.identity.sequence < sequence
    else { return false }
    return pending.contains { batch in
      batch.atomic && !batch.requests.isEmpty && batch.requests.count <= 8
        && batch.requests.contains(request)
        && Set(batch.requests.map(\.identity)).count == batch.requests.count
        && batch.requests.allSatisfy { member in
          member.identity.sequence == request.identity.sequence
            && member.identity.member < 8
            && StationPoliceSource.matchesFresh(member, context: context)
        }
    }
  }

  /// Admission refusal leaves a queued launch intact; no launch is assumed successful.
  public mutating func acknowledge(receipts: [SpawnReceipt]) {
    let admitted = Set(receipts.filter { $0.actor != nil && $0.refusal == nil }.map(\.request))
    pending = pending.compactMap { batch in
      let requests = batch.requests.filter { !admitted.contains($0.identity) }
      return requests.isEmpty ? nil : .init(requests: requests, atomic: batch.atomic)
    }
  }

  /// Saved alarms against the player survive a new physical visit identity.
  public mutating func rebindPlayer(from old: ActorIdentity, to new: ActorIdentity) {
    guard old.system == new.system else { return }
    for index in threats.indices where threats[index].report.offender == old {
      let report = threats[index].report
      threats[index].report = .init(
        incidentID: report.incidentID, offender: new, victim: report.victim,
        kind: report.kind, physicalTime: report.physicalTime, position: report.position)
    }
    assignments = []
    pending = []
    system = new.system
    visit = new.visit
  }

  public mutating func advance(context: EncounterContext) -> SecurityPlan {
    guard context.physicalTime.isFinite, context.physicalTime >= 0 else {
      return plan(context: context, intents: [], notices: [])
    }
    synchronize(context: context)
    let police = context.actors.filter {
      $0.npc?.role == .police && $0.energy > 0 && $0.identity.visit == context.visit
        && !context.protection.protectedActors.contains($0.identity)
    }.sorted { $0.identity.entity < $1.identity.entity }
    var notices: [SecurityNotice] = []
    let activeStation = threats.contains {
      $0.stationAttacker
        && (!Self.offenderGone($0, context: context)
          || context.physicalTime - $0.lastViolenceAt < 30)
    }
    advanceAlarm(active: activeStation, police: police.count, context: context, notices: &notices)
    if !activeStation {
      advanceInvestigation(police: police.count, context: context, notices: &notices)
    }
    let intents = updateAssignments(police: police, context: context)
    threats.removeAll {
      context.physicalTime - $0.lastViolenceAt >= 30 && Self.offenderGone($0, context: context)
    }
    if threats.isEmpty && !activeStation {
      advanceCalm(police: police.count, context: context)
    }
    return plan(context: context, intents: intents, notices: notices)
  }

  private static func offenderGone(_ threat: SecurityThreat, context: EncounterContext) -> Bool {
    guard let offender = Self.actor(threat.report.offender, context: context) else { return true }
    return offender.energy <= 0
      || (offender.position - context.anchors.station.position).length > 10000
  }

  private mutating func advanceAlarm(
    active: Bool, police: Int, context: EncounterContext, notices: inout [SecurityNotice]
  ) {
    guard active else {
      guard nextWaveAt != nil else { return }
      nextWaveAt = nil
      firstStationWave = true
      announcedAlarm = false
      pending = []
      phase = .cooldown
      cooldownAt = context.physicalTime
      notices.append(.securityCooldown)
      return
    }
    if !announcedAlarm {
      notices.append(.stationAlarm)
      announcedAlarm = true
    }
    while let due = nextWaveAt, due <= context.physicalTime {
      if !firstStationWave && !violenceContinues(at: due, context: context) {
        skipOverdueWaves(after: due, now: context.physicalTime)
        break
      }
      if police + pending.reduce(0, { $0 + $1.requests.count }) >= StationSecurityLaunchDescription.maximumSlots {
        skipOverdueWaves(after: due, now: context.physicalTime)
        firstStationWave = false
        phase = .reinforcing
        break
      }
      guard queueLaunch(count: firstStationWave ? 3 : 2, context: context, activePolice: police)
      else { break }
      firstStationWave = false
      nextWaveAt = due + 10
      phase = .reinforcing
    }
  }

  private func violenceContinues(at due: Double, context: EncounterContext) -> Bool {
    threats.contains {
      $0.stationAttacker && due - $0.lastViolenceAt <= 10
        && !Self.offenderGone($0, context: context)
    }
  }

  private mutating func skipOverdueWaves(after due: Double, now: Double) {
    nextWaveAt = due + (floor((now - due) / 10) + 1) * 10
  }

  private mutating func advanceInvestigation(
    police: Int, context: EncounterContext, notices: inout [SecurityNotice]
  ) {
    let ordinary = threats.filter { !$0.stationAttacker }
    let defendingVisitor = ordinary.contains { protectsCurrentCleanPlayer($0, context: context) }
    guard !ordinary.isEmpty, context.government > 0 || defendingVisitor else { return }
    if !announcedInvestigation {
      notices.append(.distressReceived)
      announcedInvestigation = true
    }
    let first = ordinary.map(\.firstReportedAt).min() ?? context.physicalTime
    let delay = 8 - Double(max(0, min(7, context.government))) * 4 / 7
    if !ordinaryWaveSent && (defendingVisitor || context.physicalTime >= first + delay) {
      ordinaryWaveSent = queueLaunch(
        count: max(0, 2 - police), context: context, activePolice: police)
    }
  }

  /// A witnessed assault inside station protection is local defence, even in anarchy.
  /// Routine/deep-space patrol policy and ordinary delayed investigations are unchanged.
  private func protectsCurrentCleanPlayer(_ threat: SecurityThreat, context: EncounterContext)
    -> Bool
  {
    let report = threat.report
    let player = context.player
    guard player.identity.system == context.system, player.identity.visit == context.visit,
      player.energy.isFinite, player.energy > 0, player.legal.value == 0,
      report.victim == player.identity, report.offender != player.identity,
      report.offender.system == context.system, report.offender.visit == context.visit,
      report.physicalTime <= context.physicalTime,
      context.physicalTime - report.physicalTime < 30,
      report.position.finite, player.position.finite,
      (report.position - context.anchors.station.position).length <= 1200,
      (player.position - context.anchors.station.position).length <= 1200,
      !context.protection.protectedActors.contains(report.offender)
    else { return false }
    let current = context.actors.filter { $0.identity == report.offender }
    return current.count == 1 && current[0].energy.isFinite && current[0].energy > 0
      && current[0].hull.isTargetShip && current[0].npc != nil
  }

  private mutating func updateAssignments(police: [ActorSnapshot], context: EncounterContext)
    -> [NPCIntent]
  {
    let intents = police.map { officer -> NPCIntent in
      let index: Int
      if let found = assignments.firstIndex(where: { $0.actor == officer.identity }) {
        index = found
      } else {
        assignments.append(
          .init(
            actor: officer.identity, target: nil, phase: .patrol,
            lastKnownPosition: officer.position, lastContactAt: context.physicalTime))
        index = assignments.count - 1
      }
      var assignment = assignments[index]
      let intent = policeIntent(officer, assignment: &assignment, context: context)
      assignments[index] = assignment
      return intent
    }
    let livePolice = Set(police.map(\.identity))
    assignments.removeAll { !livePolice.contains($0.actor) }
    return intents
  }

  private mutating func advanceCalm(police: Int, context: EncounterContext) {
    announcedInvestigation = false
    ordinaryWaveSent = false
    if phase == .investigating {
      phase = .cooldown
      cooldownAt = context.physicalTime
    }
    if let cooldownAt, context.physicalTime - cooldownAt >= 10 {
      phase = .calm
      self.cooldownAt = nil
    }
    if phase == .calm && context.government > 0 {
      let desired = context.government >= 5 ? 2 : 1
      _ = queueLaunch(count: max(0, desired - police), context: context, activePolice: police)
    }
  }

  public func dockingPermission(for identity: ActorIdentity, context: EncounterContext)
    -> DockingPermission
  {
    guard let ship = Self.actor(identity, context: context) else {
      return .init(allowed: false, notice: .dockingDenied)
    }
    let alarm = threats.contains {
      $0.report.offender == identity && context.physicalTime - $0.lastViolenceAt < 30
    }
    let pursued = assignments.contains {
      $0.target == identity && [.investigate, .intercept, .engage, .search].contains($0.phase)
    }
    if ship.legal.value >= 50 || alarm || pursued {
      return .init(allowed: false, notice: .dockingDenied)
    }
    return .init(allowed: true, notice: ship.legal.wanted ? .offenderDockingWarning : nil)
  }

  private mutating func synchronize(context: EncounterContext) {
    if system != context.system || (visit != nil && visit != context.visit) {
      threats.removeAll {
        $0.report.offender.system != context.system || $0.report.offender.visit != context.visit
      }
      assignments = []
      pending = []
      if threats.isEmpty {
        phase = .calm
        nextWaveAt = nil
        firstStationWave = true
        ordinaryWaveSent = false
        announcedAlarm = false
        announcedInvestigation = false
      }
    }
    system = context.system
    visit = context.visit
  }

  private mutating func queueLaunch(count: Int, context: EncounterContext, activePolice: Int) -> Bool {
    let queued = pending.reduce(0) { $0 + $1.requests.count }
    let count = min(
      count, max(0, StationSecurityLaunchDescription.maximumSlots - activePolice - queued))
    guard count > 0 else { return true }
    guard let deployment = StationPoliceSource.current() else { return false }
    let station = context.anchors.station
    let direction = station.exitDirection.unit
    let requests = (0..<count).map { member -> SpawnRequest in
      let slot = activePolice + queued + member
      let launch = StationSecurityLaunchDescription(
        station: station, direction: direction, slot: slot)
      return .init(
        identity: .init(
          system: context.system, visit: context.visit, sequence: sequence,
          member: UInt16(member), producer: .security),
        population: .police, hull: StationSecurityLaunchDescription.hull,
        position: launch.position, orientation: station.orientation,
        velocity: launch.velocity,
        npc: .init(
          role: .police, origin: context.system, destination: context.system,
          legalProvenance: .generated, cargoProvenance: .generated,
          routeProvenance: .generated, resources: deployment.stock),
        rock: nil, payload: nil, priority: .police, catalogueShipID: deployment.source.ship.id)
    }
    sequence &+= 1
    pending.append(.init(requests: requests, atomic: true))
    return true
  }

  private func policeIntent(
    _ officer: ActorSnapshot, assignment: inout PoliceAssignment, context: EncounterContext
  ) -> NPCIntent {
    let station = context.anchors.station
    if assignment.phase == .returning {
      return .init(actor: officer.identity, action: .dock(station.identity))
    }
    if (officer.position - station.position).length > 20000 {
      assignment.phase = .returning
      assignment.target = nil
      return .init(actor: officer.identity, action: .dock(station.identity))
    }
    if let target = policeTarget(officer: officer, context: context) {
      let isContact = contact(target, officer: officer, context: context)
      if assignment.target != target.identity {
        assignment.target = target.identity
        assignment.lastContactAt = context.physicalTime
        assignment.lastKnownPosition =
          threats.first { $0.report.offender == target.identity }?.report.position
          ?? target.position
        assignment.phase = .investigate
      }
      if isContact {
        assignment.lastKnownPosition = target.position
        assignment.lastContactAt = context.physicalTime
        assignment.phase =
          (target.position - officer.position).length <= 1500 ? .engage : .intercept
        return .init(actor: officer.identity, action: .engage(target.identity))
      }
    }
    if assignment.target != nil {
      return searchIntent(officer, assignment: &assignment, context: context)
    }
    assignment.phase = .patrol
    let patrol =
      station.exitPosition + station.exitDirection.unit * 1000
      + station.orientation.x * (officer.identity.entity % 2 == 0 ? 500 : -500)
    return .init(
      actor: officer.identity,
      action: .navigate(
        position: patrol, speedUnitsPerSecond: min(240, officer.maximumSpeedUnitsPerSecond)))
  }

  private func policeTarget(officer: ActorSnapshot, context: EncounterContext) -> ActorSnapshot? {
    ([context.player] + context.actors).filter { candidate in
      candidate.energy > 0 && candidate.identity != officer.identity && candidate.hull.isTargetShip
        && candidate.identity.system == context.system && candidate.identity.visit == context.visit
        && !context.protection.protectedActors.contains(candidate.identity)
        && (candidate.legal.wanted || threats.contains { $0.report.offender == candidate.identity })
        && targetKnown(candidate, officer: officer, context: context)
    }.min { a, b in
      let aa = priority(a, context: context)
      let bb = priority(b, context: context)
      return aa == bb ? a.identity.entity < b.identity.entity : aa < bb
    }
  }

  private func targetKnown(
    _ target: ActorSnapshot, officer: ActorSnapshot, context: EncounterContext
  ) -> Bool {
    let station = context.anchors.station.position
    if contact(target, officer: officer, context: context) {
      return (target.position - station).length <= 20000
    }
    let lastKnown = threats.first { $0.report.offender == target.identity }?.report.position
    return lastKnown.map { ($0 - station).length <= 20000 } == true
  }

  private func searchIntent(
    _ officer: ActorSnapshot, assignment: inout PoliceAssignment, context: EncounterContext
  ) -> NPCIntent {
    if context.physicalTime - assignment.lastContactAt >= 60 {
      assignment.phase = .returning
      assignment.target = nil
      return .init(actor: officer.identity, action: .dock(context.anchors.station.identity))
    }
    if assignment.phase != .investigate { assignment.phase = .search }
    return .init(
      actor: officer.identity,
      action: .navigate(
        position: assignment.lastKnownPosition,
        speedUnitsPerSecond: min(240, officer.maximumSpeedUnitsPerSecond)))
  }

  private func contact(_ target: ActorSnapshot, officer: ActorSnapshot, context: EncounterContext)
    -> Bool
  {
    (target.position - context.anchors.station.position).length <= 6000
      || (target.position - officer.position).length <= 2500
  }

  private func priority(_ target: ActorSnapshot, context: EncounterContext) -> Int {
    if let threat = threats.first(where: { $0.report.offender == target.identity }),
      context.physicalTime - threat.lastViolenceAt < 30
    {
      return threat.stationAttacker ? 0 : 1
    }
    return target.legal.value >= 50 ? 2 : 3
  }

  private static func actor(_ identity: ActorIdentity, context: EncounterContext) -> ActorSnapshot?
  {
    identity == context.player.identity
      ? context.player : context.actors.first { $0.identity == identity }
  }

  private func plan(context: EncounterContext, intents: [NPCIntent], notices: [SecurityNotice])
    -> SecurityPlan
  {
    .init(
      encounters: .init(
        system: context.system, visit: context.visit, revision: context.revision,
        batches: pending, intents: intents), notices: notices)
  }
}
