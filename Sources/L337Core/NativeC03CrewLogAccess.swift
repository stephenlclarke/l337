import Foundation

/// One data owner. Decoding a holder never grants a physical log, provider or read right.
enum NativeC03CrewLogHolder: Codable, Equatable, Sendable {
  case originalLaunch
  case stationWard(UUID)
  case originalInspectionKit(UUID)
  case institutionalRecipient(UUID)
}

/// Required actual-provider read boundary. There is deliberately NO witness factory while
/// physical ward/log storage is unqualified. The provider owner must implement that factory
/// against the actual adopted installation and live log component before this is usable.
/// Neither saved custody, a main dock nor descriptive document bytes can construct it.
final class NativeC03WardLogReadWitness: Sendable {
  private let snapshot: CommanderSnapshot
  private let bodies: [SpaceBody]
  private let epoch: UUID
  private let station: NativeMainStationIdentity
  private let service: UUID
  private let registration: UUID
  private let document: UUID
  private let documentHash: String

  private init(game: borrowing Game, station: NativeMainStationIdentity, service: UUID,
    registration: UUID, document: UUID, documentHash: String)
  {
    snapshot = CommanderSnapshot(game.commander)
    bodies = game.bodies
    epoch = game.nativeStationRuntimeEpoch
    self.station = station
    self.service = service
    self.registration = registration
    self.document = document
    self.documentHash = documentHash
  }

  fileprivate func binds(game: borrowing Game, source: NativeC03CrewSourceState,
    arrival: NativeMainStationArrivalContext, service: UUID) -> Bool
  {
    guard epoch == game.nativeStationRuntimeEpoch else { return false }
    guard bodies == game.bodies else { return false }
    guard snapshot.value == game.commander else { return false }
    return station == arrival.receipt.station && self.service == service
      && registration == source.registration.operation && document == source.registration.crewLog.serial
      && documentHash == (try? NativeFlightReception.hash(source.registration.crewLog))
  }
}

struct NativeC03CrewLogAccessReceipt: Codable, Equatable, Sendable {
  static let receipt = "hollow-manifest-original-crew-log-received"
  static let dialogue =
    "The original evacuation crew reached station care. With the ward's permission, their unaltered log is now held in the original inspection kit."

  struct Facts: Codable, Equatable, Sendable {
    let registration: UUID
    let document: UUID
    let documentHash: String
    let careTransfer: UUID
    let service: UUID
    let owner: UUID
    let dock: NativeMainStationDockReceipt
    let originalKit: UUID
    let issueCommand: UUID
    let carrier: UUID
    let inventoryRevision: UInt64
    let beforeCaseRevision: UInt64
    let afterCaseRevision: UInt64
    let physicalTime: Double
    let calendarSeconds: Double
    let epoch: UUID
  }

  let operation: UUID
  let facts: Facts

  fileprivate init(facts: Facts) throws {
    self.facts = facts
    operation = try Self.identity(facts)
  }

  static func identity(_ facts: Facts) throws -> UUID {
    guard facts.documentHash.utf8.count == 64, ScriptCompletionReceipt.validDigest(facts.documentHash)
    else { throw SaveError.invalidCommander }
    return ScriptIdentity.uuid("c03-original-crew-log-access-v1:\(try NativeFlightReception.hash(facts))")
  }

  /// Pure cross-stage history. Saved document bytes are not provider permission.
  func valid(in state: borrowing NativeHollowManifestState) -> Bool {
    let f = facts
    guard let crew = state.crewSource, let lab = state.laboratory,
      operation == (try? Self.identity(f)), f.registration == crew.registration,
      f.owner == state.birth.input.owner, f.originalKit == lab.facts.originalKit,
      f.issueCommand == lab.facts.issueCommand,
      f.inventoryRevision >= lab.facts.afterInventoryRevision,
      f.inventoryRevision < UInt64(Int64.max),
      f.dock.valid, f.dock.commanderOwner == f.owner,
      f.dock.station.system == NativeHollowManifestDefinition.carrierWorld,
      f.service == (try? NativeC03CareWardAccommodation.candidate(station: f.dock.station).service),
      f.physicalTime.isFinite, f.physicalTime >= lab.facts.physicalTime,
      f.physicalTime <= 1e12, f.calendarSeconds.isFinite,
      f.calendarSeconds >= f.dock.calendarSeconds, f.calendarSeconds <= 1e12,
      f.beforeCaseRevision > 0, f.beforeCaseRevision < UInt64(Int64.max) - 1,
      f.afterCaseRevision == f.beforeCaseRevision + 1
    else { return false }
    return true
  }

  /// Historical data-transfer joins only. The full source validator must independently
  /// authenticate original care and the physical ward/log custody graph. No recursive call.
  func valid(source: borrowing NativeC03CrewSourceState, commander: borrowing Commander) -> Bool {
    let f = facts
    let references = source.references
    let transfers = commander.nativePeople?.transfers ?? []
    let matching = transfers.filter { $0.operation == f.careTransfer }
    let firstCare = transfers.filter { $0.kind == .care && $0.members == references }
      .min(by: { $0.revision < $1.revision })
    // Current data access remains kit-only. Historical access can survive a genuine later
    // recipient return; these are acyclic receipt joins, never a new receiving permission.
    switch source.crewLogHolder {
    case .originalInspectionKit(let kit):
      guard kit == f.originalKit else { return false }
    case .institutionalRecipient(let recipient):
      guard let returned = commander.scriptState.instances[source.mission]?
        .savedHollowManifest?.caseFile?.evidenceReturn,
        returned.facts.recipient == recipient, returned.facts.crewLogTransfer == operation,
        returned.facts.crewLog == f.document, returned.facts.originalKit == f.originalKit
      else { return false }
    case .originalLaunch, .stationWard: return false
    }
    guard operation == (try? Self.identity(f)), f.registration == source.registration.operation,
      f.document == source.registration.crewLog.serial,
      f.documentHash == (try? NativeFlightReception.hash(source.registration.crewLog)),
      f.owner == source.owner, source.loss == nil,
      f.originalKit == source.registration.originalKit,
      let instance = commander.scriptState.instances[source.mission],
      let state = instance.savedHollowManifest, state.crewLogAccess == self,
      valid(in: state), let laboratory = state.laboratory,
      f.issueCommand == laboratory.facts.issueCommand,
      f.originalKit == laboratory.facts.originalKit,
      matching.count == 1, let care = matching.first,
      firstCare?.operation == f.careTransfer,
      care.kind == .care, care.members == references, care.owner == f.owner,
      f.physicalTime.isFinite, f.physicalTime >= care.physicalTime,
      f.physicalTime <= commander.flightSimulation.physicalTime,
      f.calendarSeconds.isFinite, f.calendarSeconds >= care.calendarSeconds,
      NativeC03CrewSourceSave.calendarInCurrentBounds(transfer: f.calendarSeconds,
        current: commander.scriptState.calendarSeconds),
      f.dock.valid, f.dock.commanderOwner == f.owner,
      f.dock.station.system == NativeHollowManifestDefinition.carrierWorld,
      f.service == (try? NativeC03CareWardAccommodation.candidate(station: f.dock.station).service),
      f.dock.calendarSeconds <= f.calendarSeconds,
      f.beforeCaseRevision < UInt64(Int64.max) - 1,
      f.afterCaseRevision == f.beforeCaseRevision + 1,
      f.afterCaseRevision <= instance.revision,
      f.inventoryRevision >= laboratory.facts.afterInventoryRevision
    else { return false }
    return true
  }
}

/// Fresh actual held-loan view, not another saved document or access capability.
struct NativeC03HeldCrewLog: Sendable {
  let kit: NativeHollowManifestKitBinding
  let transfer: UUID
  let contents: NativeC03OriginalCrewLogContent
  fileprivate init(kit: NativeHollowManifestKitBinding, transfer: UUID,
    contents: NativeC03OriginalCrewLogContent)
  {
    self.kit = kit
    self.transfer = transfer
    self.contents = contents
  }
}

/// Game-created review only. Current full physical provider/log ownership remains required;
/// a historical care receipt by itself cannot make this constructible.
final class NativeC03CrewLogReceivingReview: Sendable {
  let logSource: NativeC03WardLogReadWitness
  let pin: NativeHollowManifestInstalledCase
  let arrival: NativeMainStationArrivalContext
  let custody: NativePeopleCustodyState
  let source: NativeC03CrewSourceState
  let kit: NativeHollowManifestKitBinding
  let care: NativePeopleTransferReceipt
  let service: UUID
  let flight: FlightSimulationState
  let calendar: Double
  let epoch: UUID
  fileprivate init(logSource: NativeC03WardLogReadWitness,
    pin: NativeHollowManifestInstalledCase, arrival: NativeMainStationArrivalContext,
    custody: NativePeopleCustodyState, source: NativeC03CrewSourceState,
    kit: NativeHollowManifestKitBinding, care: NativePeopleTransferReceipt, service: UUID,
    flight: FlightSimulationState, calendar: Double, epoch: UUID)
  {
    self.logSource = logSource
    self.pin = pin
    self.arrival = arrival
    self.custody = custody
    self.source = source
    self.kit = kit
    self.care = care
    self.service = service
    self.flight = flight
    self.calendar = calendar
    self.epoch = epoch
  }
}

extension Game {
  /// The actual receiver must still own the document in its live physical custody graph.
  /// Current code rejects all care, so this cannot activate until that real graph exists.
  func hollowManifestCrewLogReceivingReview(_ logSource: NativeC03WardLogReadWitness) throws
    -> NativeC03CrewLogReceivingReview
  {
    guard !isMissionTrial, trialTitle == nil, screen == .contracts,
      systemIdentity == NativeHollowManifestDefinition.carrierWorld,
      let instance = hollowManifestMission, instance.outcome == .active,
      instance.suspension == nil, instance.milestones == Set(0...4),
      instance.savedHollowManifest?.crewLogAccess == nil,
      let custody = commander.nativePeople,
      let source = custody.hollowManifestCrew, source.loss == nil, source.crewLogAccess == nil,
      case .stationWard(let service) = source.crewLogHolder,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
      case .living(let destination) = nativeOriginalMainStationDestination,
      let arrival = nativeMainStationArrivalContext(for: destination.identity),
      let care = custody.transfers.filter({ $0.kind == .care && $0.members == source.references })
        .min(by: { $0.revision < $1.revision }),
      commander.flightSimulation.physicalTime >= care.physicalTime,
      commander.scriptState.calendarSeconds.isFinite,
      commander.scriptState.calendarSeconds >= care.calendarSeconds
    else { throw SaveError.invalidCommander }
    let pin = try hollowManifestInstalledCase()
    let data = try hollowManifestHeldRegisterData()
    guard data.kit.serial == source.registration.originalKit,
      acceptsHollowManifestInstalledCase(pin), acceptsNativeMainStationArrivalContext(arrival),
      logSource.binds(game: self, source: source, arrival: arrival, service: service)
    else { throw EquipmentIssueError.staleObligation }
    return .init(logSource: logSource, pin: pin, arrival: arrival, custody: custody, source: source,
      kit: data.kit, care: care, service: service, flight: commander.flightSimulation,
      calendar: commander.scriptState.calendarSeconds, epoch: nativeStationRuntimeEpoch)
  }

  /// Command-staged data handoff only, called through an actual future explicit UI Confirm
  /// and existing writer. The same atomic commit retains stage 5; it moves no people or hardware.
  @inline(never)
  mutating func receiveHollowManifestCrewLog(_ review: NativeC03CrewLogReceivingReview) throws {
    let current = try hollowManifestCrewLogReceivingReview(review.logSource)
    guard acceptsHollowManifestInstalledCase(review.pin), review.arrival == current.arrival,
      review.custody == current.custody, review.source == current.source,
      review.kit == current.kit, review.care == current.care, review.service == current.service,
      review.flight == current.flight, review.calendar == current.calendar,
      review.epoch == current.epoch, let instance = hollowManifestMission,
      instance.revision < UInt64(Int64.max) - 1
    else { throw SaveError.invalidCommander }
    let facts = NativeC03CrewLogAccessReceipt.Facts(registration: review.source.registration.operation,
      document: review.source.registration.crewLog.serial,
      documentHash: try NativeFlightReception.hash(review.source.registration.crewLog),
      careTransfer: review.care.operation, service: review.service, owner: review.source.owner,
      dock: review.arrival.receipt, originalKit: review.kit.serial,
      issueCommand: review.kit.issueCommand, carrier: review.kit.carrier,
      inventoryRevision: review.kit.inventoryRevision, beforeCaseRevision: instance.revision,
      afterCaseRevision: instance.revision + 1, physicalTime: review.flight.physicalTime,
      calendarSeconds: review.calendar, epoch: review.epoch)
    var custody = review.custody
    var source = review.source
    let access = try NativeC03CrewLogAccessReceipt(facts: facts)
    source.crewLogAccess = access
    source.crewLogHolder = .originalInspectionKit(review.kit.serial)
    custody.hollowManifestCrew = source
    var selected = instance
    selected.savedHollowManifest = try review.pin.state.retainingCrewLogAccess(access)
    selected.receipts.insert(NativeC03CrewLogAccessReceipt.receipt)
    selected.milestones.insert(5)
    selected.journal.append(NativeC03CrewLogAccessReceipt.dialogue)
    selected.revision = facts.afterCaseRevision
    var candidate = commander
    candidate.savedNativePeopleCustody = custody
    candidate.scriptState.instances[instance.id] = selected
    guard source.crewLogAccess?.valid(source: source, commander: candidate) == true,
      NativeHollowManifestSave.validateClaims(candidate), custody.valid(commander: candidate),
      candidate.equipmentInventory == commander.equipmentInventory,
      candidate.credits == commander.credits, candidate.cargo == commander.cargo,
      acceptsHollowManifestInstalledCase(review.pin)
    else { throw SaveError.invalidCommander }
    commander = candidate
  }

  /// Historical transfer alone is insufficient. Resolve the same original physical loan
  /// in the current active hull every time; a lost/returned/replaced kit cannot expose data.
  func hollowManifestHeldCrewLog() throws -> NativeC03HeldCrewLog {
    let pin = try hollowManifestInstalledCase()
    guard let instance = hollowManifestMission, let custody = commander.nativePeople,
      let source = custody.hollowManifestCrew, let access = source.crewLogAccess,
      NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
      access.valid(source: source, commander: commander)
    else { throw SaveError.invalidCommander }
    let kit = try NativeHollowManifestKitCustody.resolve(instance: instance, commander: commander)
    guard source.crewLogHolder == .originalInspectionKit(kit.serial),
      kit.serial == access.facts.originalKit, kit.issueCommand == access.facts.issueCommand,
      acceptsHollowManifestInstalledCase(pin)
    else { throw EquipmentIssueError.staleObligation }
    return .init(kit: kit, transfer: access.operation, contents: source.registration.crewLog)
  }
}


extension NativeHollowManifestState {
  /// Retain an actual handoff's history. This function grants no ward or read capability;
  /// full save validation still requires the reciprocal physical provider/custody owner.
  func retainingCrewLogAccess(_ access: NativeC03CrewLogAccessReceipt) throws -> Self {
    guard shapeValid, phase == .admitted, crewSource != nil, crewLogAccess == nil,
      caseFile == nil else { throw Failure.invalidState }
    let candidate = Self(birth: birth, phase: phase, nextSourceSequence: nextSourceSequence,
      admissions: admissions, firstAdmissions: firstAdmissions, latestAdmissions: latestAdmissions,
      terminals: terminals, consents: consents, firstCompromises: firstCompromises,
      latestSealDamage: latestSealDamage, damageRevision: damageRevision, withdrawals: withdrawals,
      routeAnchors: routeAnchors, sourceFrame: sourceFrame, ownedEncounterID: ownedEncounterID,
      routes: routes, inspections: inspections, laboratory: laboratory,
      wakeTrail: wakeTrail, custodyRegister: custodyRegister, crewSource: crewSource,
      crewLogAccess: access, caseFile: nil)
    guard candidate.shapeValid, candidate.preservesHistory(of: self) else { throw Failure.invalidState }
    return candidate
  }
}
