import Foundation

/// Read-only inputs to one actual published pulse; never release or resource authority.
struct EMPPulseBeforeResult: Sendable {
  struct Primary: Sendable {
    let hullEnergy: Double
    let frontShield: Double
    let rearShield: Double
    let electrical: ElectricalReserve
    let initializedReserve: Bool
    let contactPower: Double
    let contactOffset: Vector3
    let modelForward: Vector3

    fileprivate init(
      hullEnergy: Double, frontShield: Double, rearShield: Double,
      electrical: ElectricalReserve, initializedReserve: Bool, contactPower: Double,
      contactOffset: Vector3, modelForward: Vector3
    ) {
      self.hullEnergy = hullEnergy
      self.frontShield = frontShield
      self.rearShield = rearShield
      self.electrical = electrical
      self.initializedReserve = initializedReserve
      self.contactPower = contactPower
      self.contactOffset = contactOffset
      self.modelForward = modelForward
    }
  }

  struct Player: Sendable {
    let hullEnergy: Double
    let frontShield: Double
    let rearShield: Double
    let electrical: ElectricalReserve
    let contactPower: Double
    let contactPoint: Vector3

    fileprivate init(
      hullEnergy: Double, frontShield: Double, rearShield: Double,
      electrical: ElectricalReserve, contactPower: Double, contactPoint: Vector3
    ) {
      self.hullEnergy = hullEnergy
      self.frontShield = frontShield
      self.rearShield = rearShield
      self.electrical = electrical
      self.contactPower = contactPower
      self.contactPoint = contactPoint
    }
  }

  let charge: EMPChargeState
  let emissionID: UInt64
  let epoch: UUID
  let primary: Primary
  let player: Player?

  fileprivate init(
    charge: EMPChargeState, emissionID: UInt64, epoch: UUID,
    primary: Primary, player: Player?
  ) {
    self.charge = charge
    self.emissionID = emissionID
    self.epoch = epoch
    self.primary = primary
    self.player = player
  }
}

private struct EMPPulseContact {
  let target: GameplayHitTarget
  let point: Vector3
  let power: Double
}

private final class EMPPulseAttempt {
  var game: Game

  @inline(never)
  init(game: borrowing Game) { self.game = copy game }
}

/// One fully staged pulse. These observations grant no publication or combat authority.
private final class PreparedEMPPulsePublication {
  let candidate: EMPPulseAttempt
  let charge: EMPChargeState
  let epoch: UUID
  let emissionID: UInt64
  let primaryBefore: EMPPulseBeforeResult.Primary?
  let playerBefore: EMPPulseBeforeResult.Player?

  @inline(never)
  init(candidate: EMPPulseAttempt, charge: EMPChargeState, epoch: UUID, emissionID: UInt64,
    primaryBefore: EMPPulseBeforeResult.Primary?, playerBefore: EMPPulseBeforeResult.Player?) {
    self.candidate = candidate
    self.charge = charge
    self.epoch = epoch
    self.emissionID = emissionID
    self.primaryBefore = primaryBefore
    self.playerBefore = playerBefore
  }
}

private struct EMPPulsePreparation {
  let contacts: [EMPPulseContact]
  let profile: EMPPulseProfile
  let tool: OwnedEquipmentItem
  let inventoryRevision: UInt64
  let bank: EMPBankState
  let origin: AttackOrigin
}

private struct EMPPulseBodyPreparation {
  let id: Int
  let remaining: Double
  let before: EMPPulseBeforeResult.Primary?
}

private enum EMPPulseVictimPreparation {
  case refused
  case playerApplied(EMPPulseBeforeResult.Player?)
  case body(EMPPulseBodyPreparation)
}

/// A zero-power transition finishes synchronously after application temporaries unwind.
private enum EMPPulseApplication {
  case refused
  case applied(primary: EMPPulseBeforeResult.Primary?, player: EMPPulseBeforeResult.Player?)
  case pendingDisable(
    id: Int, incident: CombatIncident, context: EncounterContext,
    before: EMPPulseBeforeResult.Primary?)
}

extension Game {
  var playerEMPDisabled: Bool { commander.savedPlayerElectrical?.disabledAt != nil }

  /// Repeated held-fire requests leave the actual ten-second simulation charge intact.
  @discardableResult
  mutating func fireEMPPirateBlaster() -> Bool {
    empPulseBeforeResultStorage = nil
    guard commander.savedEMPCharge == nil, !playerEMPDisabled,
      !docked, screen == .front, commander.valid,
      let tool = commander.fittedEquipment(at: .utility(.empPirateBlaster)),
      let owner = commander.equipmentOwnerID, let hull = commander.hullInstanceID,
      let profile = try? EMPPulseProfile.resolve(for: commander),
      laserHeat.isFinite, laserHeat + profile.heatCost < 240,
      fireCooldown.isFinite, fireCooldown <= 0
    else { return false }
    ensurePhysicalActors()
    guard let player = commander.flightSimulation.player,
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1), range: profile.range,
        radius: 0, includePlayer: false),
      case .body(let id) = contact.hit.target,
      let body = bodies.first(where: { $0.id == id }), empPulseEligible(body),
      let target = body.physical?.identity,
      let reserve = currentPlayerElectrical(), reserve.remaining > 0,
      reserve.disabledAt == nil, currentEMPPlayerModule() == tool,
      let bank = tool.empBank, bank.remaining >= profile.energyCost
    else { return false }
    commander.savedEMPCharge = .init(
      player: player, target: target, owner: owner, hull: hull, weapon: tool.id,
      startedAt: commander.flightSimulation.physicalTime)
    notify("EMP CHARGING - TEN SECONDS")
    return true
  }

  private func currentPlayerElectrical() -> ElectricalReserve? {
    postedEMPPlayerElectrical()
  }

  func empPulseEligible(_ body: SpaceBody) -> Bool {
    guard body.energy > 0, [.cobra, .viper, .sidewinder].contains(body.hull),
      let physical = body.physical, let npc = physical.npc, npc.role != .mission,
      physical.empCrewPod == nil, physical.empSource == nil, physical.salvage == nil,
      !body.navalTarget, body.missionInstanceID == nil, body.blackjackRole == nil,
      let context = gameplayContext(),
      !context.protection.protectedActors.contains(physical.identity),
      let catalogue = physical.catalogueShipID,
      let ship = ShipCatalogue.ship(catalogue), EMPState.declaredNativeCrewCount(ship) != nil,
      SalvageCatalogue.empProfile(catalogueShipID: catalogue) != nil,
      npc.resources?.valid == true,
      NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
        catalogueShipID: catalogue, hull: body.hull, npc: npc, missiles: body.missiles)
    else { return false }
    return true
  }

  /// Called by the real, source-attributed activation producer; field expiry cannot undo it.
  mutating func cancelEMPCharge(for activation: ECMActivationIdentity) {
    guard var charge = commander.savedEMPCharge, charge.phase == .charging,
      charge.player.system == activation.emitter.system,
      charge.player.visit == activation.emitter.visit
    else { return }
    charge.phase = .cancelled
    charge.endedAt = commander.flightSimulation.physicalTime
    charge.cancellingECM = activation
    commander.savedEMPCharge = charge
    notify("EMP CHARGE CANCELLED BY ECM")
  }

  mutating func advancePlayerElectrical() {
    postEMPPlayerElectricalInterval()
  }

  mutating func advanceEMPCharge(triggerHeld: Bool, publish: ScriptPublisher? = nil) {
    empPulseBeforeResultStorage = nil
    guard var charge = commander.savedEMPCharge else { return }
    if charge.phase != .charging {
      if !triggerHeld { commander.savedEMPCharge = nil }
      return
    }
    let now = commander.flightSimulation.physicalTime
    guard triggerHeld else {
      charge.phase = .cancelled
      charge.endedAt = now
      commander.savedEMPCharge = charge
      notify("EMP CHARGE CANCELLED - RETURN RELEASED")
      return
    }
    guard now + 1e-9 >= charge.startedAt + 10 else { return }
    charge.phase = .released
    charge.endedAt = now
    // Consume the request before attempting release; refusal never retries on a later frame.
    commander.savedEMPCharge = charge
    guard emitEMPPulse(charge, publish: publish) else {
      notify("EMP RELEASE REFUSED - TARGET OR EQUIPMENT CHANGED")
      return
    }
  }

  private func pulseContacts(primary: GameplayHit, profile: EMPPulseProfile) -> [EMPPulseContact] {
    guard case .body(let primaryID) = primary.target else { return [] }
    var contacts: [EMPPulseContact] = [
      .init(target: primary.target, point: primary.point, power: profile.power)
    ]
    let origin = primary.point
    for body in bodies.sorted(by: { $0.id < $1.id })
    where body.id != primaryID && empPulseEligible(body) {
      let direction = body.position - origin
      let radius = gameplayMesh(for: body).vertices.map(\.length).max() ?? 0
      guard direction.length > 0, direction.length - radius < profile.splashRadius,
        let hit = try? nearestMissionCollision(
          from: origin, direction: direction.unit,
          range: profile.splashRadius, radius: 0, excludingBodyIDs: [primaryID], includePlayer: true
        ),
        hit.hit.target == .body(body.id)
      else { continue }
      let power = profile.power * max(0, 1 - hit.hit.distance / profile.splashRadius)
      if power > 0 {
        contacts.append(.init(target: .body(body.id), point: hit.hit.point, power: power))
      }
    }
    let towardPlayer = origin * -1
    if towardPlayer.length > 0,
      let hit = try? nearestMissionCollision(
        from: origin, direction: towardPlayer.unit,
        range: profile.splashRadius, radius: 0, excludingBodyIDs: [primaryID], includePlayer: true),
      hit.hit.target == .player
    {
      let power = profile.power * max(0, 1 - hit.hit.distance / profile.splashRadius)
      if power > 0 { contacts.append(.init(target: .player, point: hit.hit.point, power: power)) }
    }
    return contacts
  }

  /// Cost, all actual victims, law and any zero-power custody admission publish together.
  @inline(never)
  private mutating func emitEMPPulse(
    _ charge: EMPChargeState, publish: ScriptPublisher?
  ) -> Bool {
    guard let publish, admitsEMPPulseRelease(),
      let publication = prepareEMPPulsePublication(charge)
    else { return false }
    do { try publish(&publication.candidate.game) } catch { return false }
    return finishEMPPulsePublication(publication)
  }

  @inline(never)
  private func prepareEMPPulsePublication(_ charge: EMPChargeState) -> PreparedEMPPulsePublication? {
    let candidate = EMPPulseAttempt(game: self)
    let epoch = nativeStationRuntimeEpoch
    var primaryBefore: EMPPulseBeforeResult.Primary?
    var playerBefore: EMPPulseBeforeResult.Player?
    guard let preparation = candidate.game.prepareEMPPulseEffects(charge),
      candidate.game.applyEMPPulseEffects(
        preparation, primaryBefore: &primaryBefore, playerBefore: &playerBefore),
      candidate.game.persistEMPState(), candidate.game.persistNPCStates().isEmpty,
      candidate.game.empPulseCommanderIsValid()
    else { return nil }
    candidate.game.notify("EMP PULSE RELEASED")
    return .init(candidate: candidate, charge: charge, epoch: epoch,
      emissionID: preparation.origin.emissionID, primaryBefore: primaryBefore, playerBefore: playerBefore)
  }

  @inline(never)
  private mutating func finishEMPPulsePublication(_ publication: PreparedEMPPulsePublication) -> Bool {
    let candidate = publication.candidate
    if let primaryBefore = publication.primaryBefore {
      candidate.game.empPulseBeforeResultStorage = .init(
        charge: publication.charge, emissionID: publication.emissionID, epoch: publication.epoch,
        primary: primaryBefore, player: publication.playerBefore)
    }
    publishEMPPulse(candidate)
    return true
  }

  @inline(never)
  private func admitsEMPPulseRelease() -> Bool {
    guard !docked, !playerEMPDisabled, screen == .front, commander.valid else { return false }
    return true
  }

  @inline(never)
  private func empPulseCommanderIsValid() -> Bool { commander.valid }

  @inline(never)
  private mutating func publishEMPPulse(_ candidate: EMPPulseAttempt) {
    self = candidate.game
  }

  /// Current actual publication evidence only. A successful zero/custody target stays readable.
  func currentEMPPulseBeforeResult() -> EMPPulseBeforeResult? {
    guard let result = empPulseBeforeResultStorage,
      let charge = commander.savedEMPCharge, charge == result.charge, charge.valid,
      charge.phase == .released, charge.endedAt == commander.flightSimulation.physicalTime,
      commander.flightSimulation.player == charge.player,
      commander.equipmentOwnerID == charge.owner, commander.hullInstanceID == charge.hull,
      result.epoch == nativeStationRuntimeEpoch,
      result.emissionID > 0, result.emissionID < commander.flightSimulation.nextEmission,
      let tool = commander.fittedEquipment(at: .utility(.empPirateBlaster)),
      tool.node == EMPModuleGradePolicy.node, tool.id == charge.weapon,
      tool.empBank?.lastDischarge == charge,
      bodies.contains(where: { $0.physical?.identity == charge.target }),
      result.primary.electrical.valid, result.primary.contactPower.isFinite,
      result.primary.contactOffset.finite, result.primary.modelForward.finite
    else { return nil }
    return result
  }

  /// Complete full-body and equipment queries before victim application enters native combat.
  /// Only the caller's private candidate is changed; refusal discards every staged effect.
  @inline(never)
  private mutating func prepareEMPPulseEffects(_ charge: EMPChargeState) -> EMPPulsePreparation? {
    guard commander.flightSimulation.player == charge.player,
      commander.equipmentOwnerID == charge.owner, commander.hullInstanceID == charge.hull,
      let tool = commander.fittedEquipment(at: .utility(.empPirateBlaster)),
      tool.id == charge.weapon,
      let profile = try? EMPPulseProfile.resolve(for: commander),
      let contact = try? nearestMissionCollision(
        from: .init(0, 0, 0), direction: .init(0, 0, 1),
        range: profile.range, radius: 0, includePlayer: false),
      case .body(let id) = contact.hit.target,
      let primary = bodies.first(where: { $0.id == id }),
      primary.physical?.identity == charge.target,
      empPulseEligible(primary), let reserve = currentPlayerElectrical(),
      reserve.remaining > 0, reserve.disabledAt == nil,
      currentEMPPlayerModule() == tool,
      let inventory = commander.equipmentInventory,
      let bank = tool.empBank,
      let discharge = bank.stagingDischarge(charge, cost: profile.energyCost),
      fireCooldown <= 0,
      laserHeat.isFinite, laserHeat + profile.heatCost < 240
    else { return nil }
    let contacts = pulseContacts(primary: contact.hit, profile: profile)
    guard !contacts.isEmpty else { return nil }
    guard let origin = makeAttackOrigin(
        owner: charge.player, sourcePart: "emp:" + tool.id.uuidString)
    else { return nil }
    return .init(
      contacts: contacts, profile: profile, tool: tool,
      inventoryRevision: inventory.revision, bank: discharge.bank, origin: origin)
  }

  @inline(never)
  private mutating func applyEMPPulseEffects(
    _ preparation: borrowing EMPPulsePreparation,
    primaryBefore: inout EMPPulseBeforeResult.Primary?,
    playerBefore: inout EMPPulseBeforeResult.Player?
  ) -> Bool {
    guard var inventory = commander.equipmentInventory else { return false }
    let context = EquipmentRuntimeCatalog.context(
      owner: inventory.owner, hull: inventory.activeHull, performance: commander.performance)
    do {
      try inventory.replaceEMPBank(
        expected: preparation.tool, with: preparation.bank,
        expectedRevision: preparation.inventoryRevision, context: context)
    } catch { return false }
    commander.savedEquipmentInventory = inventory
    for (index, hit) in preparation.contacts.enumerated() {
      switch applyElectricalPulse(hit, origin: preparation.origin, capturePrimary: index == 0) {
      case .refused:
        return false
      case .applied(let primary, let player):
        if let primary { primaryBefore = primary }
        if let player { playerBefore = player }
      case .pendingDisable(let id, let incident, let context, let before):
        // Finish this victim before any next contact, after the pulse-application frame unwinds.
        guard disableEMPHull(id: id, incident: incident, tool: preparation.tool, context: context),
          empPulseCommanderIsValid()
        else { return false }
        if let before { primaryBefore = before }
      }
    }
    laserHeat += preparation.profile.heatCost
    fireCooldown = preparation.profile.cooldown
    laserFlash = 0.08
    dischargeAudio.record(.empPirateBlaster)
    commander.crimeLedger.finishEmission(preparation.origin.emissionID)
    return true
  }

  private mutating func applyElectricalPulse(
    _ hit: EMPPulseContact, origin: AttackOrigin, capturePrimary: Bool
  ) -> EMPPulseApplication {
    switch prepareElectricalPulseVictim(hit, capturePrimary: capturePrimary) {
    case .refused:
      return .refused
    case .playerApplied(let before):
      return .applied(primary: nil, player: before)
    case .body(let preparation):
      let positions = electricalPulseWorldPositions(hit.point)
      guard
        let incident = recordCombat(
          origin: origin, kind: .emp, outcome: .hit, target: hit.target,
          worldPosition: positions.hit, emissionPosition: positions.emission)
      else { return .refused }
      if preparation.remaining == 0 {
        guard let context = gameplayContext() else { return .refused }
        return .pendingDisable(
          id: preparation.id, incident: incident, context: context, before: preparation.before)
      }
      return .applied(primary: preparation.before, player: nil)
    }
  }

  @inline(never)
  private func electricalPulseWorldPositions(_ point: Vector3) -> (hit: Vector3, emission: Vector3)
  {
    (
      commander.flightSimulation.pose.systemPoint(point),
      commander.flightSimulation.pose.position
    )
  }

  /// Finish the existing drain and its queries before opening combat-recording frames.
  @inline(never)
  private mutating func prepareElectricalPulseVictim(
    _ hit: EMPPulseContact, capturePrimary: Bool
  ) -> EMPPulseVictimPreparation
  {
    let now = commander.flightSimulation.physicalTime
    if hit.target == .player {
      guard var reserve = commander.savedPlayerElectrical else { return .refused }
      let beforeElectrical = reserve
      let before = EMPPulseBeforeResult.Player(
        hullEnergy: energy, frontShield: frontShield, rearShield: rearShield,
        electrical: reserve, contactPower: hit.power, contactPoint: hit.point)
      let front = hit.point.z >= 0
      let shield = front ? frontShield : rearShield
      let absorbed = min(shield, hit.power)
      if front { frontShield -= absorbed } else { rearShield -= absorbed }
      guard reserve.drain(hit.power - absorbed, at: now) else { return .refused }
      commander.savedPlayerElectrical = reserve
      recordEMPPlayerElectricalDebit(before: beforeElectrical, after: reserve)
      if reserve.disabledAt != nil {
        let momentum = flightWorldVelocity
        releaseWorkGuidance()
        autoPilot.disengage()
        dockingComputer = false
        speed = 0
        manualResidualFlight = true
        autoPilot.setApproachVelocity(commander.flightSimulation.pose.shipVector(momentum))
        jumpCountdown = nil
        notify("ELECTRICAL POWER LOST - EMERGENCY BOMB OR ESCAPE POD AVAILABLE")
      }
      return .playerApplied(before)
    }
    guard case .body(let id) = hit.target,
      let index = bodies.firstIndex(where: { $0.id == id }), empPulseEligible(bodies[index]),
      var resources = bodies[index].physical?.npc?.resources
    else { return .refused }
    guard
      var reserve = resources.electrical
        ?? ElectricalReserve(
          capacity: resources.energyCapacity,
          recharge: resources.electricalRecharge, at: now),
      reserve.advance(
        to: now, capacity: resources.energyCapacity, recharge: resources.electricalRecharge)
    else { return .refused }
    let before: EMPPulseBeforeResult.Primary? = capturePrimary
      ? .init(
        hullEnergy: bodies[index].energy,
        frontShield: resources.frontShield, rearShield: resources.rearShield,
        electrical: reserve, initializedReserve: resources.electrical == nil,
        contactPower: hit.power, contactOffset: hit.point - bodies[index].position,
        modelForward: bodies[index].modelVector(.init(0, 0, 1))) : nil
    let facing =
      (hit.point - bodies[index].position).dot(bodies[index].modelVector(.init(0, 0, 1))) >= 0
    let overflow = resources.absorb(hit.power, front: facing)
    guard reserve.drain(overflow, at: now) else { return .refused }
    resources.electrical = reserve
    bodies[index].physical?.npc?.resources = resources
    return .body(
      .init(id: id, remaining: reserve.remaining, before: before))
  }

  /// Only an actual zero electrical reserve can transfer the live hull and people.
  /// Only applyEMPPulseEffects calls this inside emitEMPPulse's atomic candidate.
  /// Any refusal discards that entire candidate, including earlier victims and cost.
  @discardableResult
  private mutating func disableEMPHull(
    id: Int, incident: CombatIncident, tool: OwnedEquipmentItem, context: EncounterContext
  ) -> Bool {
    guard let preparation = prepareEMPDisable(id: id, context: context),
      let custody = claimEMPSource(bodyID: id, context: context, pose: preparation.facts.pose),
      var record = constructDisabledEMPRecord(
        id: id, incident: incident, tool: tool, context: context,
        preparation: preparation, custody: custody)
    else { return false }
    let ejections = sampleEMPCrewEjections(ordinals: record.aboardOrdinals)
    guard
      record.appendCrewDisableEpisode(
        incident: incident, weapon: tool, owner: preparation.facts.owner, ejections: ejections),
      record.valid
    else { return false }
    var state = preparation.facts.state
    state.records[record.source] = record
    if preparation.previousSource == nil { state.nextSequence += 1 }
    commander.savedEMPState = state
    if record.crewTotal == 0 {
      guard let body = bodies.first(where: { $0.id == id }),
        retainNativeSalvageWreck(body)
      else { return false }
      notify("ENGINES AND WEAPONS DISABLED - UNOCCUPIED SALVAGE")
    } else {
      notify("ENGINES AND WEAPONS DISABLED - CREW EJECTION PENDING")
    }
    return true
  }

  // Finish immutable eligibility reads before claiming the complete original source.
  private func prepareEMPDisable(id: Int, context: EncounterContext) -> EMPDisablePreparation? {
    guard let actual = bodies.first(where: { $0.id == id }),
      let actor = actual.physical?.identity, let facts = commander.empDisableFacts(actor: actor),
      actual.physical?.npc?.resources?.electrical?.remaining == 0,
      actual.physical?.npc?.resources?.electrical?.disabledAt
        == facts.time
    else { return nil }
    guard
      let index = bodies.firstIndex(where: { $0.id == id }),
      let physical = bodies[index].physical, let npc = physical.npc,
      bodies[index].energy > 0, [.cobra, .viper, .sidewinder].contains(bodies[index].hull),
      !bodies[index].navalTarget, bodies[index].missionInstanceID == nil,
      bodies[index].blackjackRole == nil, npc.role != .mission, physical.salvage == nil,
      physical.empCrewPod == nil,
      !context.protection.protectedActors.contains(physical.identity),
      let catalogue = StationPoliceSource.empCatalogueID(for: bodies[index]),
      let ship = ShipCatalogue.ship(catalogue),
      let crew = EMPState.declaredNativeCrewCount(ship),
      let profile = SalvageCatalogue.empProfile(catalogueShipID: catalogue)
    else { return nil }
    // A repeated hit has no new disable/ejection/loot transition or additional cost.
    guard physical.empSource == nil else { return nil }
    let state = facts.state
    guard state.valid else { return nil }
    let priorSource =
      facts.logical
      ?? state.records.first(where: {
        $0.value.isRecovered && $0.value.hull.binding == physical.identity
      })?.key
    let previous = priorSource.flatMap { state.records[$0] }
    if let previous {
      guard previous.isRecovered, !previous.terminal, previous.savedOrdinaryTerminal == nil,
        previous.crewAboard > 0,
        previous.disableEpisodes.count < EMPHullRecord.maximumDisableEpisodes
      else { return nil }
    } else {
      guard state.records.count < EMPState.maximumHulls,
        crew <= EMPState.maximumPeople - state.records.values.reduce(0, { $0 + $1.crewTotal }),
        state.nextSequence < 1_000_000_000 - 1
      else { return nil }
    }
    return .init(
      facts: facts, previousSource: previous?.source, catalogue: catalogue, crew: crew,
      profile: profile, originalSpawn: physical.spawnIdentity,
      cargo: npc.ordinaryCargo, legal: npc.legal)
  }

  // Construct the record after custody admission, before sampling or validating its episode.
  private mutating func constructDisabledEMPRecord(
    id: Int, incident: CombatIncident, tool: OwnedEquipmentItem, context: EncounterContext,
    preparation: EMPDisablePreparation, custody: EMPSourceCustody
  ) -> EMPHullRecord? {
    guard let current = bodies.firstIndex(where: { $0.id == id }) else { return nil }
    let previous = preparation.previousSource.flatMap { preparation.facts.state.records[$0] }
    let logical = previous?.source ?? custody.logical
    guard previous == nil || custody.logical == logical else { return nil }
    let sequence = previous?.sequence ?? preparation.facts.state.nextSequence
    let wreck =
      previous?.wreck
      ?? WreckIdentity(
        system: context.system,
        site: 0x8000_0000 + UInt32(sequence), lineage: logical.visit)
    bodies[current].physical?.canonicalSpin = true
    bodies[current].physical?.catalogueShipID = preparation.catalogue
    bodies[current].physical?.spawnIdentity = .init(
      system: context.system, visit: context.visit, sequence: sequence, member: 0, producer: .emp)
    bodies[current].physical?.empSource = logical
    bodies[current].physical?.salvage = .init(
      category: .wreck, ownership: preparation.crew == 0 ? .abandoned : .occupied,
      claimant: nil, wreck: wreck, section: nil, lot: nil,
      bounds: preparation.profile.bounds, workSurfaces: preparation.profile.surfaces(wreck: wreck))
    if preparation.crew == 0 {
      // The original custody snapshot retains the actual depleted NPC resources and cargo.
      // No person or ejection is created for a declared autonomous native craft.
      bodies[current].physical?.npc = nil
      bodies[current].physical?.blocksNavalEncounter = false
      bodies[current].physical?.population = .wreck
      bodies[current].hostile = false
    }
    var record: EMPHullRecord
    if var retained = previous {
      retained.hull = .init(
        body: bodies[current], pose: preparation.facts.pose,
        time: context.physicalTime)
      retained.savedCurrentTrafficTransfer = custody.traffic
      retained.savedCurrentCargo = preparation.cargo
      retained.savedCurrentLegal = preparation.legal
      retained.savedRecoveredAt = nil
      retained.savedOrdinaryTerminal = nil
      record = retained
    } else {
      record = EMPHullRecord(
        source: logical, sequence: sequence, wreck: wreck, crewTotal: preparation.crew,
        originalSpawn: preparation.originalSpawn, originalBodyID: id, custody: custody,
        disableIncident: incident, weapon: tool, weaponOwner: preparation.facts.owner,
        hull: .init(
          body: bodies[current], pose: preparation.facts.pose,
          time: context.physicalTime), cargo: preparation.cargo, legal: preparation.legal,
        nextEjectionAt: context.physicalTime + 1)
    }
    return record
  }
}

extension Game {
  /// Police bookkeeping is not mission immunity. Actual traffic custody is retired only when it exists.
  private mutating func claimEMPSource(
    bodyID: Int, context: EncounterContext, pose: ShipPose
  ) -> EMPSourceCustody? {
    guard let body = bodies.first(where: { $0.id == bodyID }), let physical = body.physical,
      let npc = physical.npc,
      !context.protection.protectedActors.contains(physical.identity)
    else { return nil }
    if !physical.blocksNavalEncounter {
      guard !persistNPCStates(context: context, pose: pose).contains(bodyID) else { return nil }
    } else if npc.role != .police || physical.population != .police {
      return nil
    }
    let facts = commander.empSourceClaimFacts(actor: physical.identity)
    let logical = facts.logical
    let traffic = facts.traffic
    let evidence = EMPSourceCustody(
      kind: npc.role == .police ? .police : .ordinary,
      logical: logical,
      original: .init(
        body: body, pose: pose,
        time: context.physicalTime), traffic: traffic,
      assignment: facts.assignment)
    guard evidence.valid else { return nil }
    if traffic != nil {
      guard commander.npcPersistence.terminal(actor: physical.identity, reason: .empTransferred)
      else {
        return nil
      }
    }
    return evidence
  }
}

private struct EMPDisableFacts {
  let time: Double
  let pose: ShipPose
  let owner: UUID
  let state: EMPState
  let logical: ActorIdentity?
}
private struct EMPDisablePreparation {
  let facts: EMPDisableFacts
  let previousSource: ActorIdentity?
  let catalogue: String
  let crew: Int
  let profile: SalvageProfile
  let originalSpawn: SpawnIdentity?
  let cargo: [CommodityAmount]
  let legal: LegalRecord
}
private struct EMPSourceClaimFacts {
  let logical: ActorIdentity
  let traffic: NPCPersistenceSnapshot?
  let assignment: PoliceAssignment?
}
extension Commander {
  /// Read the large commander value once, retaining only immutable transition facts.
  fileprivate func empDisableFacts(actor: ActorIdentity) -> EMPDisableFacts? {
    guard let owner = equipmentOwnerID else { return nil }
    return .init(
      time: flightSimulation.physicalTime, pose: flightSimulation.pose,
      owner: owner, state: savedEMPState ?? EMPState(),
      logical: npcPersistence.logicalIdentity(for: actor))
  }
  fileprivate func empSourceClaimFacts(actor: ActorIdentity) -> EMPSourceClaimFacts {
    let logical =
      npcPersistence.logicalIdentity(for: actor)
      ?? savedEMPState?.records.first(where: {
        $0.value.isRecovered && $0.value.savedOrdinaryTerminal == nil
          && $0.value.hull.binding == actor
      })?.key ?? actor
    return .init(
      logical: logical, traffic: npcPersistence.snapshot(for: logical),
      assignment: stationSecurity.assignments.first { $0.actor == actor })
  }
}
