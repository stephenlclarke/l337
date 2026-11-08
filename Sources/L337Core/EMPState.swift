import Foundation

/// A person belongs to one original disabled craft, regardless of physical re-admission.
public struct EMPCrewIdentity: Hashable, Codable, Sendable {
  public let source: ActorIdentity
  public let ordinal: Int
}

struct EMPStoredObject: Equatable, Codable, Sendable {
  var body: SpaceBody
  var binding: ActorIdentity?
  var physicalTime: Double

  var valid: Bool {
    guard let physical = body.physical, physical.currentNewtKitReceipt == nil else { return false }
    if let id = physical.catalogueShipID, OriginalDetailedHullStage.blocksRuntime(id) {
      return false
    }
    return physicalObjectIsValid(physical)
  }

  @inline(never)
  private func physicalObjectIsValid(_ physical: borrowing PhysicalActorState) -> Bool {
    guard body.position.finite, body.orientation.validRotation,
      physical.velocity.finite, physical.angularVelocity.finite,
      body.rotation.isFinite, body.rotationRate.isFinite,
      body.energy.isFinite, (0...1e12).contains(body.energy), body.missiles >= 0,
      physicalTime.isFinite, physicalTime >= 0
    else { return false }
    guard resourcesAreValid(physical) else { return false }
    return identityAndBindingAreValid(physical)
  }

  @inline(never)
  private func resourcesAreValid(_ physical: borrowing PhysicalActorState) -> Bool {
    guard let npc = physical.npc else { return true }
    guard npc.resources?.valid == true, let catalogue = physical.catalogueShipID else { return false }
    return NPCPersistenceSnapshot.currentCatalogueSourceIsValid(
      catalogueShipID: catalogue, hull: body.hull, npc: npc, missiles: body.missiles)
  }

  @inline(never)
  private func identityAndBindingAreValid(_ physical: borrowing PhysicalActorState) -> Bool {
    guard
      body.missionActorID == nil && body.missionInstanceID == nil
        && body.scriptNPC == nil && body.scriptShot == nil && !body.navalTarget
        && !body.enemyMissile && body.playerMissileTarget == nil && body.missileSourceID == nil
        && body.nativeStationIdentity == nil
    else { return false }
    guard physical.npc?.role != .mission else { return false }
    guard body.blackjackRole == nil && body.blackjackIdentity == nil else { return false }
    guard physical.ordnance == nil else { return false }
    guard physical.payload == nil else { return false }
    guard physical.rock == nil else { return false }
    if physical.blocksNavalEncounter {
      guard physical.npc?.role == .police else { return false }
    }
    if binding != nil {
      guard binding == physical.identity else { return false }
    }
    return true
  }

  init(body: SpaceBody, pose: ShipPose, time: Double) {
    self.body = body
    self.body.position = pose.systemPoint(body.position)
    self.body.orientation = body.orientation.transformed(by: pose.orientation)
    binding = body.physical?.identity
    physicalTime = time
  }
}

enum EMPCrewCustodyOutcome: String, Sendable {
  case aboard, occupiedPod, captured, deceasedWithHull
}

struct EMPHullRecord: Equatable, Codable, Sendable {
  let source: ActorIdentity
  let sequence: UInt64
  let wreck: WreckIdentity
  let crewTotal: Int
  let originalSpawn: SpawnIdentity?
  let originalBodyID: Int
  let custody: EMPSourceCustody
  let disableIncident: CombatIncident
  let weapon: OwnedEquipmentItem
  let weaponOwner: UUID
  var pods: [EMPStoredObject] = []
  var hull: EMPStoredObject
  let cargo: [CommodityAmount]
  let legal: LegalRecord
  var nextEjectionAt = 0.0
  var terminal = false
  var lostCrewCount = 0
  var savedCrewCaptures: [NativeCrewCaptureReceipt]?
  var savedDisableEpisodes: [EMPCrewDisableEpisode]?
  var savedDeceasedOrdinals: [Int]?
  var savedRecoveredAt: Double?
  var savedOrdinaryTerminal: NPCTerminalReason?
  var savedCurrentTrafficTransfer: NPCPersistenceSnapshot?
  var savedCurrentCargo: [CommodityAmount]?
  var savedCurrentLegal: LegalRecord?
  var salvageCargo: [CommodityAmount] { savedCurrentCargo ?? cargo }
  var salvageLegal: LegalRecord { savedCurrentLegal ?? legal }
  var isRecovered: Bool { savedRecoveredAt != nil }
  var activeTrafficTransfer: NPCPersistenceSnapshot? {
    savedCurrentTrafficTransfer ?? custody.traffic
  }
  var crewCaptures: [NativeCrewCaptureReceipt] {
    get { savedCrewCaptures ?? [] }
    set { savedCrewCaptures = newValue.isEmpty ? nil : newValue }
  }
  var capturedCrewCount: Int {
    guard crewCaptures.count <= EMPState.maximumPeople,
      crewCaptures.allSatisfy({ (1...EMPState.maximumPeople).contains($0.count) })
    else { return EMPState.maximumPeople + 1 }
    return crewCaptures.reduce(0) { $0 + $1.count }
  }
  var crewAboard: Int {
    guard (0...EMPState.maximumPeople).contains(crewTotal),
      (0...crewTotal).contains(lostCrewCount), pods.count <= crewTotal,
      capturedCrewCount <= crewTotal
    else { return -1 }
    return crewTotal - pods.count - lostCrewCount - capturedCrewCount
  }
  var crewDeadline: Double? {
    let deadline = currentCrewDisableIncident.physicalTime + 30
    return deadline.isFinite && deadline >= currentCrewDisableIncident.physicalTime ? deadline : nil
  }
  var deceasedOrdinals: [Int] {
    savedDeceasedOrdinals ?? []
  }

  func crewOutcome(ordinal: Int) -> EMPCrewCustodyOutcome? {
    guard (0..<crewTotal).contains(ordinal) else { return nil }
    if podIndex(for: ordinal) != nil { return .occupiedPod }
    if crewCaptures.contains(where: { $0.contains(ordinal) }) { return .captured }
    return deceasedOrdinals.contains(ordinal) ? .deceasedWithHull : .aboard
  }

  var valid: Bool {
    guard source.visit > 0, source.entity > 1, source.entity < UInt64.max,
      (0..<8).contains(source.system.galaxy), (0...256).contains(source.system.system),
      custody.valid
    else { return false }
    guard sourceAndCrewAreValid(), hull.valid,
      let catalogue = hullCatalogueAndCondition(),
      recoveryOrDisabledHullIsValid(catalogue: catalogue), currentCustodyIsValid()
    else { return false }
    return currentNewtStockIsValid() && podsAreValid()
  }

  // Each phase returns before the next full nested validator reserves its temporaries.
  @inline(never)
  private func sourceAndCrewAreValid() -> Bool {
    guard sourceFactsBeforeCrewCensusAreValid(), crewCensusValid else { return false }
    return crewCaptureReceiptsAreValid()
  }

  // Source/equipment temporaries end before census, and receipt temporaries start afterwards.
  @inline(never)
  private func sourceFactsBeforeCrewCensusAreValid() -> Bool {
    guard custody.logical == source, custody.original.body.id == originalBodyID,
      custody.original.body.physical?.spawnIdentity == originalSpawn,
      custody.original.body.physical?.npc?.ordinaryCargo == cargo,
      custody.original.body.physical?.npc?.legal == legal,
      custody.original.body.hull == hull.body.hull,
      disableIncident.id > 0, disableIncident.kind == .emp, disableIncident.outcome == .hit,
      disableIncident.victim == custody.original.body.physical?.identity,
      disableIncident.victimLegalBeforeAttack == legal,
      disableIncident.victimRole == custody.original.body.physical?.npc?.role,
      !disableIncident.victimIsStation, disableIncident.origin.owner.entity == 0,
      disableIncident.origin.owner.system == source.system,
      disableIncident.origin.owner.visit == custody.original.body.physical?.identity.visit,
      weapon.node == EquipmentRuntimeCatalog.node(for: Equipment.empPirateBlaster),
      weapon.location?.slot == .utility(.empPirateBlaster), weapon.component == nil,
      disableIncident.origin.sourcePart == "emp:" + weapon.id.uuidString,
      disableIncident.origin.emissionID > 0, disableIncident.position.finite,
      disableIncident.physicalTime.isFinite, disableIncident.physicalTime >= 0,
      disableIncident.origin.emittedAt == disableIncident.physicalTime,
      sequence > 0, sequence < 1_000_000_000, originalBodyID >= 0,
      originalSpawn?.system == source.system || originalSpawn == nil, wreck.system == source.system,
      wreck.site == 0x8000_0000 + UInt32(sequence), wreck.lineage == source.visit,
      (0...EMPState.maximumPeople).contains(crewTotal), pods.count <= crewTotal,
      capturedCrewCount <= crewTotal - pods.count, crewAboard >= 0, crewDeadline != nil
    else { return false }
    if crewTotal == 0 {
      guard let reserve = custody.original.body.physical?.npc?.resources?.electrical,
        reserve.remaining == 0, reserve.disabledAt == disableIncident.physicalTime
      else { return false }
    }
    return true
  }

  @inline(never)
  private func crewCaptureReceiptsAreValid() -> Bool {
    guard crewCaptures.count <= EMPState.maximumPeople,
      savedCrewCaptures == nil || !crewCaptures.isEmpty,
      Set(crewCaptures.map(\.operation)).count == crewCaptures.count,
      crewCaptures.allSatisfy({ $0.valid(record: self) }),
      crewCaptures.enumerated().allSatisfy({ index, receipt in
        index == 0 || receipt.physicalTime >= crewCaptures[index - 1].physicalTime
      })
    else { return false }
    return true
  }

  @inline(never)
  private func hullCatalogueAndCondition() -> String? {
    guard hull.body.physical?.empCrewPod == nil,
      [.cobra, .viper, .sidewinder].contains(hull.body.hull),
      let catalogue = hull.body.physical?.catalogueShipID,
      let ship = ShipCatalogue.ship(catalogue),
      EMPState.declaredNativeCrewCount(ship) == crewTotal,
      catalogue == custody.original.body.physical?.catalogueShipID,
      SalvageCatalogue.empProfile(catalogueShipID: catalogue) != nil,
      cargo.allSatisfy(\.valid), Set(cargo.map(\.commodity)).count == cargo.count,
      (0...255).contains(legal.value), legal.bountyTenths >= 0,
      nextEjectionAt.isFinite, nextEjectionAt >= 0,
      terminal == (hull.body.energy <= 0),
      lostCrewCount == (terminal ? crewTotal - pods.count - capturedCrewCount : 0)
    else { return nil }
    return catalogue
  }

  @inline(never)
  private func recoveryOrDisabledHullIsValid(catalogue: String) -> Bool {
    if isRecovered {
      guard crewTotal > 0, let recoveredAt = savedRecoveredAt, let deadline = crewDeadline,
        recoveredAt.isFinite, recoveredAt >= deadline, recoveredAt <= hull.physicalTime,
        hull.body.physical?.empSource == nil, hull.body.physical?.salvage == nil,
        hull.body.physical?.spawnIdentity?.producer != .emp,
        let reserve = hull.body.physical?.npc?.resources?.electrical,
        reserve.disabledAt == nil,
        savedOrdinaryTerminal != .empTransferred,
        (savedOrdinaryTerminal == .destroyed) == terminal,
        savedOrdinaryTerminal == nil || hull.binding == nil
      else { return false }
    } else {
      if let npc = hull.body.physical?.npc {
        guard let reserve = npc.resources?.electrical,
          reserve.remaining == 0,
          reserve.disabledAt == currentCrewDisableIncident.physicalTime
        else { return false }
      }
      guard savedOrdinaryTerminal == nil, hull.body.physical?.empSource == source,
        hull.body.physical?.spawnIdentity?.producer == .emp,
        hull.body.physical?.spawnIdentity?.sequence == sequence,
        hull.body.physical?.spawnIdentity?.member == 0,
        hull.body.physical?.spawnIdentity?.system == source.system,
        let profile = SalvageCatalogue.empProfile(catalogueShipID: catalogue),
        let metadata = hull.body.physical?.salvage, metadata.wreck == wreck,
        metadata.category == .wreck, metadata.claimant == nil, metadata.section == nil,
        metadata.lot == nil, metadata.bounds == profile.bounds,
        metadata.workSurfaces == profile.surfaces(wreck: wreck)
      else { return false }
    }
    return true
  }

  @inline(never)
  private func currentCustodyIsValid() -> Bool {
    guard (savedCurrentCargo != nil) == (disableEpisodes.count > 1),
      (savedCurrentLegal != nil) == (disableEpisodes.count > 1),
      salvageCargo.count <= 17, salvageCargo.allSatisfy(\.valid),
      Set(salvageCargo.map(\.commodity)).count == salvageCargo.count,
      (0...255).contains(salvageLegal.value), salvageLegal.bountyTenths >= 0,
      currentCrewDisableIncident.victimLegalBeforeAttack == salvageLegal
    else { return false }
    if let transfer = savedCurrentTrafficTransfer {
      guard transfer.valid, transfer.actor.system == source.system,
        transfer.actor.visit >= source.visit,
        transfer.physicalTime <= currentCrewDisableIncident.physicalTime,
        transfer.npc.role == custody.original.body.physical?.npc?.role
      else { return false }
    }
    if !terminal && !isRecovered {
      guard hull.body.physical?.salvage?.ownership == (crewAboard > 0 ? .occupied : .abandoned),
        (hull.body.physical?.npc != nil) == (crewAboard > 0),
        hull.body.physical?.population
          == (crewAboard > 0 ? custody.original.body.physical?.population : .wreck),
        crewAboard == 0 || hull.body.physical?.npc?.ordinaryCargo == salvageCargo
      else { return false }
    }
    return true
  }

  @inline(never)
  private func currentNewtStockIsValid() -> Bool {
    let original = custody.original.body.physical?.currentNewtKitStock
    let current = hull.body.physical?.currentNewtKitStock
    guard original != nil || current != nil else { return pods.isEmpty }
    guard let original, let current,
      let catalogue = custody.original.body.physical?.catalogueShipID,
      let parent = ShipCatalogue.ship(catalogue),
      EMPState.declaredNativeCrewCount(parent) == crewTotal,
      original.issue.birthLoad.catalogueShipID == catalogue,
      hull.body.physical?.catalogueShipID == catalogue,
      let r3 = OriginalFleetR3Data.contract(for: catalogue),
      original.issue.birthLoad.r3SHA256 == r3.sourceSHA256,
      original.issue.birthLoad.people.count == crewTotal,
      Set(original.issue.birthLoad.people.map { $0.identity.ordinal }) == Set(0..<crewTotal),
      original.issue.birthLoad.people.allSatisfy({ $0.identity.source == source }),
      custody.original.body.physical?.currentNewtKitReceipt == nil,
      hull.body.physical?.currentNewtKitReceipt == nil,
      original.phase == .stowed, original.issue.birthActor == source,
      original.issue.person.source == source,
      (0..<crewTotal).contains(original.issue.person.ordinal),
      original.issue.issuedAt <= custody.original.physicalTime,
      CurrentNewtKitStock.permitsTransition(from: original, to: current),
      let descriptor = CurrentNewtKitSource.current, descriptor.matches(original.issue),
      descriptor.matches(original, at: custody.original.physicalTime),
      descriptor.matches(current, at: hull.physicalTime),
      current.structurallyValid
    else { return false }
    if custody.original.body.physical?.identity == original.issue.birthActor {
      guard originalSpawn == original.issue.birthSpawn else { return false }
    } else {
      guard custody.traffic?.currentNewtKitStock == original else { return false }
    }
    if let actuation = current.actuation {
      guard actuation.source == source, actuation.sequence == sequence,
        actuation.startedAt <= hull.physicalTime,
        actuation.load.catalogueShipID == catalogue, actuation.load.r3SHA256 == r3.sourceSHA256,
        actuation.load.people.allSatisfy({ original.issue.birthLoad.people.contains($0) }),
        actuation.load.people.contains(where: {
          $0.identity == original.issue.person && $0.profile == original.issue.personProfile
        }),
        disableEpisodes.contains(where: { episode in
          guard let schedule = episode.ejections.first(where: {
            $0.ordinal == original.issue.person.ordinal
          }) else {
            return false
          }
          return episode.actorBindings.contains(actuation.parent)
            && actuation.startedAt == episode.incident.physicalTime + schedule.delay
            && actuation.deadline == episode.deadline
        })
      else { return false }
    }
    if current.phase == .actuating && current.interruptedAt == nil {
      guard let physical = hull.body.physical,
        descriptor.matchesAttachedObservation(stock: current,
          state: .init(pose: Game.modelPose(of: hull.body, player: .init()),
            velocity: physical.velocity, angularVelocity: physical.angularVelocity),
          at: hull.physicalTime)
      else { return false }
    }
    if current.phase == .released {
      guard pods.count == 1, let receipt = current.receipt,
        receipt.issue.person == original.issue.person,
        pods[0].body.physical?.currentNewtKitReceipt == receipt
      else { return false }
    } else if !pods.isEmpty {
      return false
    }
    return true
  }

  @inline(never)
  private func podsAreValid() -> Bool {
    guard !pods.isEmpty else { return true }
    guard let capsule = ShipCatalogue.ship("SH040"), capsule.catalogue.objectKind == .capsule,
      let current = OriginalFleetR3Data.contract(for: capsule.id), current.objectKind == .capsule,
      let performance = current.performance, capsule.game == performance,
      performance.energy.isFinite, performance.energy > 0
    else { return false }
    return pods.allSatisfy { pod in
      guard let person = pod.body.physical?.empCrewPod,
        person.source == source, (0..<crewTotal).contains(person.ordinal)
      else { return false }
      return
        pod.validCurrentOccupiedNewt(in: self)
        && pod.body.energy > 0 && pod.body.energy <= performance.energy
        && pod.body.hull == .cargo
        && pod.body.physical?.empSource == nil && pod.body.physical?.npc == nil
        && pod.body.physical?.spawnIdentity?.producer == .emp
        && pod.body.physical?.spawnIdentity?.sequence == sequence
        && pod.body.physical?.spawnIdentity?.member == UInt16(person.ordinal + 1)
        && pod.body.physical?.spawnIdentity?.system == source.system
        && pod.body.physical?.population == .cargo && !pod.body.hostile
        && pod.body.physical?.catalogueShipID == "SH040"
        && pod.body.physical?.salvage?.category == .occupiedPod
        && pod.body.physical?.salvage?.ownership == .occupied
        && pod.body.physical?.salvage?.claimant == source
        && pod.body.physical?.salvage?.wreck == nil
        && pod.body.physical?.salvage?.section == nil && pod.body.physical?.salvage?.lot == nil
        && pod.body.physical?.salvage?.workSurfaces.isEmpty == true
    }
  }
}

extension EMPHullRecord {
  @inline(never)
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(source, forKey: .source)
    try values.encode(sequence, forKey: .sequence)
    try values.encode(wreck, forKey: .wreck)
    try values.encode(crewTotal, forKey: .crewTotal)
    try values.encodeIfPresent(originalSpawn, forKey: .originalSpawn)
    try values.encode(originalBodyID, forKey: .originalBodyID)
    try values.encode(NativeSaveEncodingValue<EMPSourceCustody>.prepare(custody), forKey: .custody)
    try values.encode(disableIncident, forKey: .disableIncident)
    try values.encode(weapon, forKey: .weapon)
    try values.encode(weaponOwner, forKey: .weaponOwner)
    try values.encode(NativeSaveEncodingArray(pods), forKey: .pods)
    try values.encode(NativeSaveEncodingValue<EMPStoredObject>.prepare(hull), forKey: .hull)
    try values.encode(cargo, forKey: .cargo)
    try values.encode(legal, forKey: .legal)
    try values.encode(nextEjectionAt, forKey: .nextEjectionAt)
    try values.encode(terminal, forKey: .terminal)
    try values.encode(lostCrewCount, forKey: .lostCrewCount)
    try values.encodeIfPresent(savedCrewCaptures, forKey: .savedCrewCaptures)
    try values.encodeIfPresent(savedDisableEpisodes, forKey: .savedDisableEpisodes)
    try values.encodeIfPresent(savedDeceasedOrdinals, forKey: .savedDeceasedOrdinals)
    try values.encodeIfPresent(savedRecoveredAt, forKey: .savedRecoveredAt)
    try values.encodeIfPresent(savedOrdinaryTerminal, forKey: .savedOrdinaryTerminal)
    if let value = NativeSaveEncodingValue<NPCPersistenceSnapshot>.prepareIfPresent(savedCurrentTrafficTransfer) {
      try values.encode(value, forKey: .savedCurrentTrafficTransfer)
    }
    try values.encodeIfPresent(savedCurrentCargo, forKey: .savedCurrentCargo)
    try values.encodeIfPresent(savedCurrentLegal, forKey: .savedCurrentLegal)
  }

  private enum CodingKeys: String, CodingKey {
    case source, sequence, wreck, crewTotal, originalSpawn, originalBodyID, custody, disableIncident
    case weapon, weaponOwner, pods, hull, cargo, legal, nextEjectionAt, terminal, lostCrewCount,
      savedCrewCaptures, savedDisableEpisodes, savedDeceasedOrdinals,
      savedRecoveredAt, savedOrdinaryTerminal, savedCurrentTrafficTransfer,
      savedCurrentCargo, savedCurrentLegal
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let captures = try NativePeopleDecoding.array(
      values, key: .savedCrewCaptures, type: NativeCrewCaptureReceipt.self)
    let episodes = try NativePeopleDecoding.array(
      values, key: .savedDisableEpisodes, type: EMPCrewDisableEpisode.self,
      maximum: Self.maximumDisableEpisodes)
    let deceased = try NativePeopleDecoding.array(
      values, key: .savedDeceasedOrdinals, type: Int.self)
    guard let episodes, !episodes.isEmpty,
      let pods = try NativePeopleDecoding.array(values, key: .pods, type: EMPStoredObject.self)
    else { throw SaveError.invalidCommander }
    self.init(
      source: try values.decode(ActorIdentity.self, forKey: .source),
      sequence: try values.decode(UInt64.self, forKey: .sequence),
      wreck: try values.decode(WreckIdentity.self, forKey: .wreck),
      crewTotal: try values.decode(Int.self, forKey: .crewTotal),
      originalSpawn: try values.decodeIfPresent(SpawnIdentity.self, forKey: .originalSpawn),
      originalBodyID: try values.decode(Int.self, forKey: .originalBodyID),
      custody: try values.decode(EMPSourceCustody.self, forKey: .custody),
      disableIncident: try values.decode(CombatIncident.self, forKey: .disableIncident),
      weapon: try values.decode(OwnedEquipmentItem.self, forKey: .weapon),
      weaponOwner: try values.decode(UUID.self, forKey: .weaponOwner),
      pods: pods,
      hull: try values.decode(EMPStoredObject.self, forKey: .hull),
      cargo: try values.decode([CommodityAmount].self, forKey: .cargo),
      legal: try values.decode(LegalRecord.self, forKey: .legal),
      nextEjectionAt: try values.decode(Double.self, forKey: .nextEjectionAt),
      terminal: try values.decode(Bool.self, forKey: .terminal),
      lostCrewCount: try values.decode(Int.self, forKey: .lostCrewCount),
      savedCrewCaptures: captures, savedDisableEpisodes: episodes, savedDeceasedOrdinals: deceased,
      savedRecoveredAt: try values.decodeIfPresent(Double.self, forKey: .savedRecoveredAt),
      savedOrdinaryTerminal: try values.decodeIfPresent(
        NPCTerminalReason.self, forKey: .savedOrdinaryTerminal),
      savedCurrentTrafficTransfer: try values.decodeIfPresent(
        NPCPersistenceSnapshot.self, forKey: .savedCurrentTrafficTransfer),
      savedCurrentCargo: try values.decodeIfPresent(
        [CommodityAmount].self, forKey: .savedCurrentCargo),
      savedCurrentLegal: try values.decodeIfPresent(LegalRecord.self, forKey: .savedCurrentLegal))
  }
}

/// Bounded lifetime custody; traffic culling and system departure never regenerate these people or hulls.
struct EMPState: Equatable, Codable, Sendable {
  static let maximumHulls = 32
  static let maximumPeople = 256
  var records: [ActorIdentity: EMPHullRecord] = [:]
  var nextSequence: UInt64 = 1
  var sources: [ActorIdentity] {
    records.keys.sorted {
      ($0.system.galaxy, $0.system.system, $0.visit, $0.entity)
        < ($1.system.galaxy, $1.system.system, $1.visit, $1.entity)
    }
  }
  /// Exact native complement, including an explicitly autonomous zero; never conversion places.
  /// This source declaration grants no actor admission, people or EMP permission.
  static func declaredNativeCrewCount(_ ship: CatalogueShip) -> Int? {
    guard let source = OriginalFleetR3Data.contract(for: ship.id),
      source.objectKind == .ship, ship.catalogue.objectKind == .ship,
      source.name == ship.name, source.family == ship.catalogue.family,
      source.origin.catalogueOrigin == ship.catalogue.origin,
      let crew = source.accommodation,
      (0...maximumPeople).contains(crew.nativeCrew),
      crew.nativeAutonomous == (crew.nativeCrew == 0)
    else { return nil }
    return crew.nativeCrew
  }

  /// People-only consumers still require a positive native complement.
  static func hasSupportedCrew(_ ship: CatalogueShip) -> Bool {
    (declaredNativeCrewCount(ship) ?? 0) > 0
  }
  var valid: Bool {
    guard records.count <= Self.maximumHulls, nextSequence > 0, nextSequence < 1_000_000_000,
      records.allSatisfy({
        $0.key == $0.value.source && $0.value.sequence < nextSequence && $0.value.valid
      })
    else { return false }
    // Validate each bounded complement before adding values from an untrusted save.
    return records.values.reduce(0, { $0 + $1.crewTotal }) <= Self.maximumPeople
      && Set(records.values.map(\.sequence)).count == records.count
      && CurrentOccupiedNewtValidation.issuesAreUnique(records.values.compactMap {
        $0.custody.original.body.physical?.currentNewtKitStock?.issue
      })
  }
}

extension Commander {
  var usesEMPSaveVersion: Bool {
    savedEMPState != nil
      || equipmentInventory?.items.contains { $0.node.key == Equipment.empPirateBlaster } == true
  }
}


extension EMPStoredObject {
  @inline(never)
  func validCurrentOccupiedNewt(in record: borrowing EMPHullRecord) -> Bool {
    guard let physical = body.physical,
      physical.catalogueShipID == "SH040", physical.currentNewtKitStock == nil,
      body.hull == .cargo, body.missiles == 0, !body.ecmEnabled, !body.hostile,
      body.rotationRate == 0, physical.canonicalSpin == true, physical.population == .cargo,
      physical.npc == nil, physical.empSource == nil,
      physical.identity.entity > 1, physical.identity.entity < UInt64.max,
      let capsule = ShipCatalogue.ship("SH040"),
      let performance = OriginalFleetR3Data.contract(for: capsule.id)?.performance,
      capsule.game == performance, performance.energy.isFinite, performance.energy > 0,
      body.energy > 0, body.energy <= performance.energy,
      let descriptor = CurrentNewtKitSource.current,
      let geometry = Game.currentNewtPodCollisionMesh(source: descriptor),
      let radius = geometry.vertices.map(\.length).max(),
      radius.isFinite, radius > 0,
      let salvage = physical.salvage, salvage.category == .occupiedPod,
      salvage.ownership == .occupied, salvage.claimant == record.source,
      salvage.wreck == nil, salvage.section == nil, salvage.lot == nil,
      salvage.workSurfaces.isEmpty, salvage.bounds.center == .init(0, 0, 0),
      salvage.bounds.radius == radius,
      let person = physical.empCrewPod,
      let stock = record.hull.body.physical?.currentNewtKitStock,
      person == stock.issue.person, person.source == record.source,
      (0..<record.crewTotal).contains(person.ordinal),
      let receipt = physical.currentNewtKitReceipt,
      CurrentOccupiedNewtValidation.receipt(receipt, matches: stock),
      receipt.issue == record.custody.original.body.physical?.currentNewtKitStock?.issue,
      receipt.issue.person == person, receipt.actuation.source == record.source,
      receipt.actuation.sequence == record.sequence,
      record.podEjectionLowerBound(for: person.ordinal) == receipt.releasedAt,
      receipt.releasedAt <= physicalTime,
      physical.identity.system == receipt.podActor.system,
      physical.identity.visit >= receipt.podActor.visit,
      physical.spawnIdentity?.producer == .emp,
      physical.spawnIdentity?.system == physical.identity.system,
      physical.spawnIdentity?.visit == physical.identity.visit,
      physical.spawnIdentity?.sequence == record.sequence,
      physical.spawnIdentity?.member == UInt16(person.ordinal + 1),
      descriptor.matches(receipt.issue), descriptor.matches(receipt, observedAt: physicalTime),
      physicalObjectIsValid(physical)
    else { return false }
    if let capturedAt = stock.serviceCapturedAt {
      guard binding == nil, physicalTime == capturedAt else { return false }
    }
    guard descriptor.service(receipt, observedAt: physicalTime) != nil else { return false }
    return true
  }
}

extension EMPStoredObject {
  private enum CodingKeys: String, CodingKey {
    case body, binding, physicalTime
  }
  @inline(never)
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(NativeSaveEncodingValue<SpaceBody>.prepare(body), forKey: .body)
    try values.encodeIfPresent(binding, forKey: .binding)
    try values.encode(physicalTime, forKey: .physicalTime)
  }
}

/// ActorIdentity is a structured key: native Dictionary Codable uses alternating
/// key/value entries. Traverse the SAME immutable dictionary storage, unsorted.
private final class EMPRecordEncodingMap: Encodable {
  private let records: [ActorIdentity: EMPHullRecord]
  init(_ records: [ActorIdentity: EMPHullRecord]) { self.records = records }

  @inline(never)
  func encode(to encoder: any Encoder) throws {
    var values = encoder.unkeyedContainer()
    for index in records.indices {
      try values.encode(key(at: index))
      let record = preparedValue(at: index)
      try values.encode(record)
    }
  }

  @inline(never)
  private func key(at index: Dictionary<ActorIdentity, EMPHullRecord>.Index) -> ActorIdentity {
    records[index].key
  }

  @inline(never)
  private func preparedValue(at index: Dictionary<ActorIdentity, EMPHullRecord>.Index)
    -> NativeSaveEncodingValue<EMPHullRecord> {
    NativeSaveEncodingValue<EMPHullRecord>.prepare(records[index].value)
  }
}

extension EMPState {
  private enum CodingKeys: String, CodingKey { case records, nextSequence }

  @inline(never)
  func encode(to encoder: any Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    try values.encode(EMPRecordEncodingMap(records), forKey: .records)
    try values.encode(nextSequence, forKey: .nextSequence)
  }
}
