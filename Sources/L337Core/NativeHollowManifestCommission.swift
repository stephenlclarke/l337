import Foundation

// This contact is the authored freight-auditor station service, not an individual life actor.
enum NativeHollowManifestAction: String, Sendable {
  case accept, progress, laboratory
  var key: String { NativeHollowManifestCommission.stateID + "/" + rawValue }
}

struct NativeHollowManifestReview: Sendable {
  let action: NativeHollowManifestAction
  let arrival: NativeMainStationArrivalContext?
  let owner: UUID?
  let carrier: UUID?
  let inventoryRevision: UInt64?
  let sale: NativeFirstCommoditySale?
  let digest: String?
  let caseRevision: UInt64?
  let sourceSequence: UInt64?
  let epoch: UUID
  let issues: [String]
  let reviewToken = UUID()
  var allowed: Bool { action != .progress && issues.isEmpty }
}

enum NativeHollowManifestCommission {
  static let stateID = "l337.contract/hollow-manifest"
  static let version = "1.0.0"
  static let digest = "89c04f37a735fdcc6ae73a27247ba56c14d55554d37e92ae1f01a69054bcbe1a"
  static let manifestSHA256 = "d8365dfe9171f210859996c2293a6f9cee5b83e0aa8e0e65d955dd20acc4db0a"
  static let moduleSHA256 = "29c808ee6dbf4758e908559ba8e6375bd3cd644b89e13f5dec1f216ce6fb2db8"
  static let receipt = "hollow-manifest-accept"
  static let authoredReceipt = "l337.hollow-manifest/accept"
  static let inspectionReceipt = "hollow-manifest-inspected"
  static let laboratoryReceipt = "hollow-manifest-laboratory"
  static let laboratoryDialogue =
    "IVEN: The master seal was recalled. Someone retained it, stamped new dates and sent an empty carrier along the insured route. Take this scanner kit; it belongs to the laboratory."
  static let inspectionDialogue =
    "Both seals are authentic, but their manufacturing scratches match. These are two impressions of one physical master, not two independent shipments."
  static let authoredEvent = "mission_contact_confirmed"
  static let target = "toren-commission"
  static let nextStage = NativeHollowManifestStage.inspectFreighters
  static let briefing: [String] = [
    "Nia Toren: Two paid manifests name the same crate, and both captains insist it never reached them. Scan the freighters at Garrivek. If we follow the seal rather than the accusation, we can find where the cargo really went.",
    "TOREN: The mutual has paid for the same machinery twice. I want a complete custody record. Keep the captains alive and their original seals intact.",
    "Speak to freight auditor Nia Toren at Narargan in Galaxy 2 after completing one normal commodity sale. No score gate or link to another campaign.",
  ]

  static func mission(owner: UUID) -> UUID {
    ScriptIdentity.uuid("hollow-manifest-commission-v1:\(owner)")
  }
  static func operation(owner: UUID, mission: UUID, dock: NativeMainStationDockReceipt) -> UUID {
    ScriptIdentity.uuid("hollow-manifest-contact-v1:\(owner):\(mission):\(dock.sequence)")
  }
  static func marked(_ instance: borrowing ScriptInstance) -> Bool {
    instance.definition == stateID || instance.digest == digest || instance.savedHollowManifest != nil
      || instance.receipts.contains(receipt)
  }
  static func applies(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == stateID || pack.manifest.hollowManifest != nil
      || pack.digest == digest
  }
  static func matches(_ pack: borrowing ScriptPack) -> Bool {
    pack.manifest.stateID == stateID && pack.manifest.version == version
      && pack.manifest.hollowManifest?.valid == true && pack.digest == digest
      && ScriptPackLibrary.hash(pack.manifestBytes) == manifestSHA256
      && ScriptPackLibrary.hash(pack.source) == moduleSHA256
      && pack.entryBytes == pack.source && pack.models.isEmpty && pack.resourceBytes.isEmpty
  }
  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.stateID == stateID || manifest.hollowManifest != nil else { return }
    guard manifest.stateID == stateID, manifest.version == version,
      manifest.hollowManifest?.valid == true, manifest.module == "scripts/main.lua",
      manifest.handlers.count == 1,
      manifest.handlers.first?.event == "mission.accepted",
      manifest.handlers.first?.function == "accepted",
      manifest.encounters == nil, manifest.npcs == nil, manifest.modules == nil,
      manifest.board == nil, manifest.providerContract == nil, manifest.trial == nil,
      manifest.equipment == nil, manifest.worldJobs == nil
    else { throw MissionPackError("Restore the closed Hollow Manifest native commission.") }
  }

  static func acceptanceReceipt(event: String, target: String, instance: borrowing ScriptInstance)
    -> String?
  {
    guard event == authoredEvent, target == Self.target, prefixValid(instance) else { return nil }
    return authoredReceipt
  }

  /// A local receipt maps to the authored slash-bearing identity only with ALL native joins.
  /// No caller token, serialized name or birth constructor is current contact authority.
  @inline(never)
  static func prefixValid(_ instance: borrowing ScriptInstance) -> Bool {
    guard marked(instance) else { return true }
    guard instance.definition == stateID, instance.version == version, instance.digest == digest,
      let state = instance.savedHollowManifest, state.shapeValid,
      state.birth.input.firstSourceSequence == 1,
      instance.id == mission(owner: state.birth.input.owner),
      state.birth.input.mission == instance.id,
      state.birth.input.commission
        == operation(
          owner: state.birth.input.owner, mission: instance.id, dock: state.birth.input.dock),
      instance.receipts == expectedReceipts(state), instance.milestones == expectedMilestones(state),
      instance.payloads.isEmpty,
      gearClaimsMatch(instance, state: state),
      instance.timers.isEmpty, instance.dialogue == nil, instance.contract == nil,
      NativeC03CaseClosureSave.terminalClaimsMatch(instance, state: state),
      instance.choiceReceipts.isEmpty,
      instance.conversationReceipts.isEmpty,
      instance.data == .object([:]), instance.journal.count <= expectedJournal(state).count,
      instance.journal == Array(expectedJournal(state).prefix(instance.journal.count))
    else { return false }
    if state.phase == .unadmitted {
      return state.nextSourceSequence == 8 && instance.ownedEncounters.isEmpty
    }
    // G3 supplies the pure owned-actor predicate; it is not a life or scene-admission gate.
    // This consumer activates only with the coherent physical, route and native effect/life packet.
    guard instance.journal == expectedJournal(state) else { return false }
    return admittedActorClaimsMatch(instance)
  }
}

extension Game {
  var hollowManifestPack: ScriptPack? {
    scriptPacks.first { NativeHollowManifestCommission.matches($0) }
  }
  var hollowManifestMission: ScriptInstance? {
    withReadOnlyScriptState { $0.instances.values.first(where: NativeHollowManifestCommission.marked) }
  }
  var hollowManifestRows: [ContractBoardRow] {
    guard hollowManifestPack != nil,
      let dock = commander.nativeStations?.currentMainDock,
      nativeMainStationArrivalContext(for: dock.station) != nil,
      commander.scriptState.firstNativeCommoditySale != nil,
      NativeFirstCommoditySaleSave.validateClaims(commander)
    else { return [] }
    let action: NativeHollowManifestAction
    if systemIdentity == NativeHollowManifestDefinition.issuer {
      action = hollowManifestMission == nil ? .accept : .progress
    } else if systemIdentity == NativeHollowManifestDefinition.laboratoryWorld,
      let state = hollowManifestMission?.savedHollowManifest, state.inspections.count == 2 {
      action = state.laboratory == nil ? .laboratory : .progress
    } else {
      return []
    }
    let title =
      action == .accept ? "Nia Toren / review duplicate-manifest audit"
        : action == .laboratory ? "Marek Iven / collect original inspection kit"
        : "The Hollow Manifest / current case"
    return [
      .init(
        board: action.key, offer: nil, title: title,
        reason: hollowManifestReview(action).issues.first, hollowManifest: action)
    ]
  }
  func hollowManifestReview(_ action: NativeHollowManifestAction) -> NativeHollowManifestReview {
    let dock = commander.nativeStations?.currentMainDock
    let arrival = dock.flatMap { nativeMainStationArrivalContext(for: $0.station) }
    let sale = commander.scriptState.firstNativeCommoditySale
    var issues: [String] = []
    if paused { issues.append("Resume before confirming the commission.") }
    if trialTitle != nil || isMissionTrial {
      issues.append("Use the actual commander outside a trial.")
    }
    let contactWorld = action == .laboratory
      ? NativeHollowManifestDefinition.laboratoryWorld : NativeHollowManifestDefinition.issuer
    if action != .progress && (systemIdentity != contactWorld || arrival == nil) {
      issues.append(action == .laboratory
        ? "Speak to Marek Iven at the actual living Torenran main berth."
        : "Speak to Nia Toren at the actual living Narargan main berth in Galaxy 2.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
    if sale == nil || !NativeFirstCommoditySaleSave.validateClaims(commander) {
      issues.append("Complete one normal commodity sale first.")
    }
    if commander.equipmentOwnerID == nil || commander.hullInstanceID == nil
      || commander.equipmentInventory == nil
    {
      issues.append("The actual owned carrier and inventory must be available.")
    }
    if hollowManifestPack == nil { issues.append("Restore the approved Hollow Manifest opening.") }
    if action == .progress || (action == .accept && hollowManifestMission != nil) {
      issues.append("The original case is retained. Follow the current case journal.")
    }
    if action == .laboratory, let issue = hollowManifestLaboratoryIssue(at: arrival) {
      issues.append(issue)
    }
    if commander.scriptState.instances.count >= 128
      || commander.scriptState.pendingEvents.count >= 4096
      || commander.scriptState.nextEvent >= UInt64(Int64.max) - 10
    {
      issues.append("The native commission record capacity is full.")
    }
    if scriptDispatching || scriptEventsDeferred || !commander.scriptState.pendingEvents.isEmpty {
      issues.append("Finish the current native command before confirming.")
    }
    return .init(
      action: action, arrival: arrival, owner: commander.equipmentOwnerID,
      carrier: commander.hullInstanceID, inventoryRevision: commander.equipmentInventory?.revision,
      sale: sale, digest: hollowManifestPack?.digest,
      caseRevision: hollowManifestMission?.revision,
      sourceSequence: hollowManifestMission?.savedHollowManifest?.nextSourceSequence,
      epoch: nativeStationRuntimeEpoch, issues: issues)
  }

  // File-local: only the actor's explicit bound-save confirmation below calls this producer.
  mutating func confirmHollowManifest(_ quote: NativeHollowManifestReview) throws {
    if quote.action == .laboratory {
      try confirmHollowManifestLaboratory(quote)
      return
    }
    let current = hollowManifestReview(.accept)
    guard screen == .contracts, contractBoard.detail, contractBoard.action == .accept,
      contractBoard.selected?.hollowManifest == .accept,
      quote.allowed, current.allowed, quote.action == .accept,
      quote.arrival == current.arrival, quote.epoch == current.epoch,
      quote.owner == current.owner, quote.carrier == current.carrier,
      quote.inventoryRevision == current.inventoryRevision, quote.sale == current.sale,
      quote.digest == current.digest, let owner = current.owner, let carrier = current.carrier,
      let revision = current.inventoryRevision, let arrival = current.arrival,
      acceptsNativeMainStationArrivalContext(arrival), let sale = current.sale,
      let pack = hollowManifestPack
    else {
      throw MissionPackError("The Toren contact, berth, sale or inventory changed; review again.")
    }
    let id = NativeHollowManifestCommission.mission(owner: owner)
    guard commander.scriptState.instances[id] == nil, hollowManifestMission == nil else {
      throw MissionPackError("The original manifest case already exists; it cannot be replaced.")
    }
    let operation = NativeHollowManifestCommission.operation(
      owner: owner, mission: id, dock: arrival.receipt)
    let birth = try NativeHollowManifestSourceBirth.preparing(
      .init(
        mission: id, owner: owner, commission: operation, carrier: carrier,
        inventoryRevision: revision, dock: arrival.receipt, sale: sale,
        physicalTime: commander.flightSimulation.physicalTime, firstSourceSequence: 1))
    var candidate = self
    var instance = ScriptInstance(
      id: id, definition: NativeHollowManifestCommission.stateID,
      version: NativeHollowManifestCommission.version, digest: pack.digest)
    instance.savedHollowManifest = try .unadmitted(birth)
    instance.receipts = [NativeHollowManifestCommission.receipt]
    instance.milestones = [0]
    candidate.commander.scriptState.instances[id] = instance
    candidate.emitScriptEvent("mission.accepted", only: id)
    guard let accepted = candidate.commander.scriptState.instances[id],
      accepted.outcome == .active, accepted.suspension == nil,
      NativeHollowManifestCommission.acceptanceReceipt(
        event: NativeHollowManifestCommission.authoredEvent,
        target: NativeHollowManifestCommission.target, instance: accepted)
        == NativeHollowManifestCommission.authoredReceipt,
      accepted.journal == NativeHollowManifestCommission.briefing,
      !candidate.commander.scriptState.pendingEvents.contains(where: { $0.instance == id }),
      NativeHollowManifestSave.validateClaims(candidate.commander)
    else { throw MissionPackError("The native commission briefing could not commit.") }
    self = candidate
  }

  func hollowManifestDetail() -> [String] {
    let quote = contractBoard.hollowManifestQuote
    if contractBoard.selected?.hollowManifest == .laboratory {
      return [
        "MAREK IVEN / TORENRAN / GALAXY 2",
        "Review both original seal observations with Iven at this laboratory.",
        "Confirm borrows the laboratory's original one-tonne inspection kit.",
        "Keep one real tonne free. The kit remains a loan and must return to Narargan.",
        "The loan costs no credits and grants no payment or clue.",
        "Back or Esc closes the review without taking the kit.",
      ] + hollowManifestSealComparisonLines()
        + (quote?.issues ?? ["Review the actual laboratory contact again."])
    }
    if contractBoard.selected?.hollowManifest == .progress {
      return hollowManifestCurrentCaseLines()
    }
    return [
      "NIA TOREN / NARARGAN / GALAXY 2",
      "The mutual paid twice for machinery that never left its warehouse.",
      "Confirm opens one audit and creates its two original seal/captain assignments.",
      "The originals share one finite seal master. There are no replacements.",
      "Back or Esc closes this review without accepting or transferring anything.",
      "Get each captain's explicit consent, then observe its original cargo seal from 250-1500m.",
      "Take both seal observations to Marek Iven's laboratory at Torenran.",
    ] + (quote?.issues ?? ["Review the actual current contact again."])
  }
}

/// Ephemeral pin to an actually installed owned case. This is NOT scene/life/admission authority.
/// No caller State is accepted and no Codable initializer can recreate an installed pin.
struct NativeHollowManifestInstalledCase: Sendable {
  fileprivate let snapshot: ScriptInstance
  fileprivate let runtimeEpoch: UUID
  fileprivate let nextEvent: UInt64
  fileprivate let pendingEvents: [ScriptEvent]
  let owner: UUID
  let state: NativeHollowManifestState
  var missionID: UUID { snapshot.id }
  var revision: UInt64 { snapshot.revision }
  var digest: String { snapshot.digest }
  fileprivate init(
    snapshot: ScriptInstance, owner: UUID, state: NativeHollowManifestState,
    runtimeEpoch: UUID, nextEvent: UInt64, pendingEvents: [ScriptEvent]
  ) {
    self.snapshot = snapshot
    self.owner = owner
    self.state = state
    self.runtimeEpoch = runtimeEpoch
    self.nextEvent = nextEvent
    self.pendingEvents = pendingEvents
  }
}

extension Game {
  func hollowManifestInstalledCase() throws -> NativeHollowManifestInstalledCase {
    guard !isMissionTrial, trialTitle == nil, let owner = commander.equipmentOwnerID,
      let instance = hollowManifestMission, let state = instance.savedHollowManifest,
      hollowManifestPack?.digest == instance.digest,
      state.birth.input.owner == owner, NativeHollowManifestSave.validateClaims(commander)
    else { throw SaveError.invalidCommander }
    // Source ownership survives inactive work/suspension. Actual work producers enforce their
    // own eligibility; historical issuance needs no current issuer berth, carrier or fitting.
    let freshness = withReadOnlyScriptState { ($0.nextEvent, $0.pendingEvents) }
    return .init(
      snapshot: instance, owner: owner, state: state, runtimeEpoch: nativeStationRuntimeEpoch,
      nextEvent: freshness.0, pendingEvents: freshness.1)

  }
  func acceptsHollowManifestInstalledCase(_ pin: NativeHollowManifestInstalledCase) -> Bool {
    commander.equipmentOwnerID == pin.owner && nativeStationRuntimeEpoch == pin.runtimeEpoch
      && hollowManifestPack?.digest == pin.digest
      && withReadOnlyScriptState({ $0.instances[pin.missionID] }) == pin.snapshot
      && withReadOnlyScriptState({ $0.nextEvent }) == pin.nextEvent
      && withReadOnlyScriptState({ $0.pendingEvents }) == pin.pendingEvents
      && !isMissionTrial && trialTitle == nil
      && NativeHollowManifestSave.validateClaims(commander)
  }
}

extension NativeHollowManifestCommission {
  static let encounter = "c03-original-freighters"
  static let rootModel = "asset:c03-original-hull"
  static let sealModel = "asset:c03-original-seal"

  static func logicalActor(mission: UUID, slot: NativeHollowManifestState.Slot) -> UUID {
    ScriptIdentity.uuid("script-actor-v2:\(mission):\(digest):\(encounter):\(slot.rawValue)")
  }
  static func component(logicalActor: UUID, slot: NativeHollowManifestState.Slot) -> UUID {
    ScriptIdentity.uuid("script-component-v2:\(logicalActor):\(slot.rawValue)")
  }

  /// Pure declarations for G3's ACTUAL native preparation. No pack capability, actor, native ID,
  /// component, source registry or scene is installed here. Geometry and kinematics are the birth's.
  static func admissionDeclarations(
    birth: NativeHollowManifestSourceBirth, anchors: SystemAnchors, sourceFrame: ShipPose,
    encounter: String
  ) throws -> (
    encounter: ScriptEncounterDefinition, profiles: [ScriptNPCDefinition],
    designs: [String: ShipDesign]
  ) {
    guard birth.shapeValid, encounter == Self.encounter else { throw SaveError.invalidCommander }
    let layout = try NativeC03FreighterRoute.candidateLayout(anchors: anchors)
    var basis = Basis3()
    basis.x = layout.u
    basis.y = layout.v
    basis.z = layout.normal
    guard
      sourceFrame
        == ShipPose(position: (layout.firstCentre + layout.secondCentre) * 0.5, orientation: basis)
    else { throw SaveError.invalidCommander }
    let fit = birth.fit
    let profiles = try NativeHollowManifestState.Slot.allCases.map { slot in
      let profileID = "c03-original-" + slot.rawValue
      let profile = ScriptNPCDefinition(
        id: profileID, name: "Original audit freighter",
        source: birth.rootDesign.source,
        basis: "Approved C03 local unarmed/unshielded source fit; native units.",
        model: rootModel, scale: 1, energy: fit.hullEnergy, recharge: fit.recharge,
        speed: fit.maximumSpeed, acceleration: fit.acceleration,
        pitch: fit.pitch, yaw: fit.yaw, roll: fit.roll, missiles: fit.fittedMissiles,
        fuel: 0, drive: nil, ecm: fit.fittedECM, bounty: 0, lasers: [],
        components: [
          .init(
            id: slot.rawValue, model: sealModel, scale: 1,
            position: NativeC03SealGeometry.componentPosition,
            orientation: NativeC03SealGeometry.componentOrientation, energy: fit.sealEnergy,
            solid: true, weapons: [])
        ])
      guard profile.valid else { throw SaveError.invalidCommander }
      return profile
    }
    let definition = ScriptEncounterDefinition(
      id: encounter, galaxy: 1, system: 113, profile: "profiled-local-freeze-v1",
      actors: NativeHollowManifestState.Slot.allCases.map { slot in
        let point = sourceFrame.shipPoint(slot == .first ? layout.firstCentre : layout.secondCentre)
        return .init(
          id: slot.rawValue, hull: nil, npc: "c03-original-" + slot.rawValue,
          x: point.x, y: point.y, z: point.z, hostile: false)
      })
    guard definition.valid else { throw SaveError.invalidCommander }
    return (definition, profiles, [rootModel: birth.rootDesign, sealModel: birth.master.template])
  }
}

/// Actual Game-issued source estimate, not a biological person record or a Codable life grant.
/// The pin does not freeze a physical target: the real effect owner must separately capture and
/// recheck its exact pre-effect body/scene/flight before one physical/source commit.
struct NativeHollowManifestOriginalLife: Sendable {
  enum Mode: Sendable, Equatable { case issuedNotLost, retainedCondition }
  let pin: NativeHollowManifestInstalledCase
  let original: NativeHollowManifestSourceBirth.Original
  let admission: NativeHollowManifestState.Admission?
  let mode: Mode
  fileprivate init(
    pin: NativeHollowManifestInstalledCase, original: NativeHollowManifestSourceBirth.Original,
    admission: NativeHollowManifestState.Admission?, mode: Mode
  ) {
    self.pin = pin
    self.original = original
    self.admission = admission
    self.mode = mode
  }
}

extension Game {
  /// No caller Birth, State, body or energy flag can supply the installed source to this factory.
  func hollowManifestOriginalLife(slot: NativeHollowManifestState.Slot) throws
    -> NativeHollowManifestOriginalLife
  {
    let pin = try hollowManifestInstalledCase()
    guard let source = try? NativeHollowManifestFleetSource.resolve(.inspectionFreighter),
      let original = pin.state.birth.originals.first(where: { $0.slot == slot }),
      original.operatingCrew == source.accommodation.operatingCrew,
      original.intrinsicCrewQuarters == source.accommodation.intrinsicCrewPlaces,
      pin.state.birth.operations.contains(where: {
        $0.id == original.assignment && $0.kind == .hullAndCaptainAssigned
          && $0.parent == pin.state.birth.input.commission && $0.object == original.hull
      }),
      !pin.state.terminals.contains(where: { $0.effect.admission.slot == slot }),
      c03OriginalConditionMatches(pin, slot: slot)
    else { throw SaveError.invalidCommander }
    if pin.state.phase == .unadmitted {
      guard pin.state.admissions.isEmpty, pin.state.firstAdmissions.isEmpty,
        pin.state.latestAdmissions.isEmpty,
        withReadOnlyScriptState({ $0.instances[pin.missionID]?.ownedEncounters.isEmpty }) == true,
        !bodies.contains(where: { $0.missionInstanceID == pin.missionID })
      else { throw SaveError.invalidCommander }
      return .init(pin: pin, original: original, admission: nil, mode: .issuedNotLost)
    }
    guard let latest = pin.state.latestAdmissions.first(where: { $0.slot == slot }),
      let admission = pin.state.admissions.first(where: { $0.reference == latest }),
      admission.original.owner == pin.owner, admission.original.mission == pin.missionID,
      admission.original.source == original.source, admission.original.hull == original.hull,
      admission.original.captain == original.captain,
      admission.original.seal == original.seal, admission.original.imprint == original.imprint,
      admission.original.master == original.master
    else { throw SaveError.invalidCommander }
    return .init(pin: pin, original: original, admission: admission, mode: .retainedCondition)
  }

  func acceptsHollowManifestOriginalLife(_ gate: NativeHollowManifestOriginalLife) -> Bool {
    guard acceptsHollowManifestInstalledCase(gate.pin),
      let current = try? hollowManifestOriginalLife(slot: gate.original.slot)
    else { return false }
    return current.original == gate.original && current.admission == gate.admission
      && current.mode == gate.mode && current.pin.owner == gate.pin.owner
      && current.pin.missionID == gate.pin.missionID && current.pin.digest == gate.pin.digest
      && current.pin.revision == gate.pin.revision
  }
}

/// Current source ownership only. This does not freeze the live target, fit, UI or contact.
struct NativeHollowManifestConsentSource: Sendable {
  let life: NativeHollowManifestOriginalLife
  let owned: ScriptOwnedActor
  let admission: NativeHollowManifestState.Admission
  let player: ActorIdentity
  fileprivate init(
    life: NativeHollowManifestOriginalLife, owned: ScriptOwnedActor,
    admission: NativeHollowManifestState.Admission, player: ActorIdentity
  ) {
    self.life = life
    self.owned = owned
    self.admission = admission
    self.player = player
  }
}

extension Game {
  /// Remains readable on the explicit review screen and for a living causal revocation.
  /// Actual work/contact producers independently enforce their own screen and physical checks.
  func hollowManifestConsentSource(slot: NativeHollowManifestState.Slot) throws
    -> NativeHollowManifestConsentSource
  {
    let life = try hollowManifestOriginalLife(slot: slot)
    guard life.mode == .retainedCondition,
      let current = c03CurrentOriginalBinding(life.pin, slot: slot),
      current.admission == life.admission,
      let player = commander.flightSimulation.player, player.entity == 0,
      player.system == current.admission.original.actor.system,
      player.visit == current.admission.original.actor.visit
    else { throw SaveError.invalidCommander }
    return .init(life: life, owned: current.owned, admission: current.admission, player: player)
  }

  func acceptsHollowManifestConsentSource(_ source: NativeHollowManifestConsentSource) -> Bool {
    guard acceptsHollowManifestOriginalLife(source.life),
      let current = try? hollowManifestConsentSource(slot: source.admission.reference.slot)
    else { return false }
    return current.admission == source.admission && current.owned == source.owned
      && current.player == source.player
  }

  /// Work eligibility alone confers no item, observer, contact or inspection permission.
  func hollowManifestConsentWorkIsEligible(_ source: NativeHollowManifestConsentSource) -> Bool {
    let slot = source.admission.reference.slot
    let state = source.life.pin.state
    guard acceptsHollowManifestConsentSource(source),
      let instance = withReadOnlyScriptState({ $0.instances[source.life.pin.missionID] }),
      instance.outcome == .active, instance.suspension == nil,
      instance.milestones == [0],
      let actual = bodies.first(where: { $0.id == source.owned.body.id }),
      actual.physical?.npc?.resources?.electrical?.disabledAt == nil
    else { return false }
    return !state.terminals.contains(where: { $0.effect.admission.slot == slot })
      && !state.withdrawals.contains(where: { $0.effect.admission.slot == slot })
      && !state.firstCompromises.contains(where: { $0.admission.slot == slot })
  }
}
