import Foundation

/// Live authority is never encoded. Saved action facts only describe the dock that issued them.
final class NativeOriginalSealedDispatchOrigin: Sendable {
  let station: ContractStationIdentity
  let facts: NativeStationEventFacts
  let packDigest: String
  private let context: NativeStationBoardContext

  private init(
    station: ContractStationIdentity, facts: NativeStationEventFacts,
    packDigest: String, context: NativeStationBoardContext
  ) {
    self.station = station
    self.facts = facts
    self.packDigest = packDigest
    self.context = context
  }

  /// Closed data projection. This does not resolve packs or create live service authority.
  static func station(for site: OriginalStationSite) -> ContractStationIdentity? {
    guard site.sealedDispatchDefinition == OriginalSealedDispatch.definition else { return nil }
    return .init(galaxy: site.system.galaxy, system: site.system.system,
      stationClass: "original-station-" + site.catalogueID.lowercased())
  }

  static func site(for station: ContractStationIdentity) -> OriginalStationSite? {
    OriginalStationSite.allCases.first { Self.station(for: $0) == station }
  }

  static func matches(_ facts: NativeStationEventFacts, station: ContractStationIdentity) -> Bool {
    guard let site = site(for: station), facts.valid,
      site.identity(world: facts.receipt.commanderOwner) == facts.receipt.station
    else { return false }
    return facts.descriptor.boardOrigin == .authored
      && facts.descriptor.capabilities == [.sealedDispatchBoard]
  }

  static func allows(_ board: ScriptContractBoard) -> Bool {
    if board.station.stationClass == "main-orbital" { return true }
    return site(for: board.station) != nil && board.provider == OriginalSealedDispatch.provider
      && board.id == OriginalSealedDispatch.boardID && board.clock == .missionCalendar
      && board.freightGeneration == nil && board.courierGeneration?.origin == board.station
      && OriginalSealedDispatch.validBoard(board)
      && board.offers.allSatisfy { $0.courier?.declaration == OriginalSealedDispatch.definition }
  }

  static func allows(_ job: ScriptContractJob) -> Bool {
    if job.station.stationClass == "main-orbital" { return true }
    return site(for: job.station) != nil && job.provider == OriginalSealedDispatch.provider
      && job.clock == .missionCalendar && job.offer.freightPlan == nil
      && job.offer.courier?.declaration == OriginalSealedDispatch.definition
      && job.offer.courier?.generation.origin == job.station && OriginalSealedDispatch.validJob(job)
  }

  private static let bundledDigest: String? = {
    guard let pack = try? ScriptPackLibrary.read(ScriptPackLibrary.bundledSealedDispatchDirectory),
      OriginalSealedDispatch.validManifest(pack.manifest),
      pack.manifest.id == OriginalSealedDispatch.provider
    else { return nil }
    return pack.digest
  }()

  private static func trusted(_ pack: ScriptPack) -> Bool {
    OriginalSealedDispatch.validManifest(pack.manifest)
      && pack.manifest.id == OriginalSealedDispatch.provider && pack.digest == bundledDigest
      && pack.manifest.pledge == nil && pack.manifest.procurement == nil
      && pack.manifest.freight == nil
  }

  static func current(in game: borrowing Game, pack: ScriptPack) -> Self? {
    guard trusted(pack), let context = game.nativeStationBoardContext,
      game.acceptsNativeStationBoardContext(context),
      let owner = game.commander.equipmentOwnerID,
      let site = OriginalStationSite.site(for: context.station, owner: owner),
      let station = station(for: site),
      let facts = game.nativeStationEventFacts, facts.receipt == context.service.receipt,
      matches(facts, station: station),
      context.service.capability == .sealedDispatchBoard,
      let world = game.commander.nativeStations,
      let record = world.ledger.records.first(where: { $0.identity == context.station }),
      record.tombstone == nil, record.binding == facts.receipt.dockingBinding,
      let pose = world.pose(for: record.identity), pose.energy > 0
    else { return nil }
    let bodies = game.bodies.filter {
      $0.nativeStationIdentity == record.identity || $0.id == facts.receipt.dockingBinding.bodyID
    }
    // A normal dock unloads the flight bodies. Any retained body must be the one live current source.
    guard bodies.isEmpty || bodies.count == 1
      && world.bodyRigidPoseIsConsistent(bodies[0], flight: game.commander.flightSimulation)
    else { return nil }
    return .init(station: station, facts: facts, packDigest: pack.digest, context: context)
  }

  func isCurrent(in game: borrowing Game, pack: ScriptPack) -> Bool {
    guard let actual = Self.current(in: game, pack: pack) else { return false }
    return actual.station == station && actual.facts == facts && actual.packDigest == packDigest
      && actual.context == context
  }
}

extension Commander {
  func originalSealedOriginRecord(for station: ContractStationIdentity) -> Bool {
    if station.stationClass == "main-orbital" { return true }
    guard let site = NativeOriginalSealedDispatchOrigin.site(for: station),
      let owner = equipmentOwnerID, let world = nativeStations, world.ledger.world == owner,
      let record = world.ledger.records.first(where: { $0.identity == site.identity(world: owner) })
    else { return false }
    return NativeStationSource.authentic(record, owner: owner)
  }

  private func originalSealedOriginFactValid(
    _ facts: NativeStationEventFacts, station: ContractStationIdentity
  ) -> Bool {
    guard originalSealedOriginRecord(for: station),
      NativeOriginalSealedDispatchOrigin.matches(facts, station: station),
      let owner = equipmentOwnerID, facts.receipt.commanderOwner == owner,
      let world = nativeStations, facts.receipt.station.world == world.ledger.world,
      let record = world.ledger.records.first(where: { $0.identity == facts.receipt.station }),
      record.descriptor == facts.descriptor, record.revision >= facts.receipt.lifecycleRevision,
      facts.receipt.sequence < world.ledger.nextDockSequence,
      facts.receipt.dockingBinding.actor.visit <= flightSimulation.visit,
      facts.receipt.dockingBinding.actor.entity < flightSimulation.nextActor
    else { return false }
    // Later rebinds or destruction do not rewrite the historical issue/abandon receipt.
    return true
  }

  private func originalSealedDeliveryHistoryValid(_ state: ScriptInstance, job: ScriptContractJob)
    -> Bool
  {
    guard let owner = equipmentOwnerID, let world = nativeStations, world.ledger.world == owner,
      let completion = state.completionReceipt, let cause = completion.cause,
      let receipt = cause.nativeMainDock, receipt.valid,
      completion.committed.nativeMainDock == receipt,
      receipt.commanderOwner == owner, receipt.station.world == owner,
      receipt.station.system == SystemIdentity(
        galaxy: job.offer.destinationGalaxy, system: job.offer.destinationSystem),
      cause.galaxy == receipt.station.system.galaxy, cause.system == receipt.station.system.system,
      world.mainStations.contains(receipt.station),
      let resource = scriptState.stationResources[receipt.station.key],
      resource.valid, resource.identity == receipt.station.resource,
      receipt.sequence < world.nextMainDockSequence,
      receipt.actor.visit <= flightSimulation.visit, receipt.actor.entity < flightSimulation.nextActor,
      receipt.calendarSeconds <= cause.calendarSeconds,
      cause.calendarSeconds <= scriptState.calendarSeconds
    else { return false }
    if let custody = state.courier, let issue = custody.issue.originalOrigin?.receipt {
      guard receipt.actor.visit > issue.dockingBinding.actor.visit,
        job.clock == .missionCalendar, let delivery = custody.terminal,
        delivery.cause == .delivered, delivery.proof.clock >= custody.issue.clock
      else { return false }
    }
    // Historical receiving survives later rebinds or source destruction. It grants no live arrival.
    return true
  }

  func originalSealedOriginHistoryValid(_ state: ScriptInstance) -> Bool {
    guard let job = state.contract, let terms = job.offer.courier else { return true }
    guard OriginalSealedDispatch.matches(terms.declaration) else {
      return job.station.stationClass == "main-orbital"
    }
    guard NativeOriginalSealedDispatchOrigin.allows(job),
      state.definition == OriginalSealedDispatch.stateID, let custody = state.courier,
      custody.item == ScriptCourierCustody.itemIdentity(state.id)
    else { return false }
    if job.station.stationClass != "main-orbital" {
      guard let issue = custody.issue.originalOrigin,
        originalSealedOriginFactValid(issue, station: job.station)
      else { return false }
      if let terminal = custody.terminal, terminal.cause == .abandoned {
        guard let facts = terminal.proof.originalOrigin,
          originalSealedOriginFactValid(facts, station: job.station)
        else { return false }
      }
    }
    if custody.terminal?.cause == .delivered {
      return originalSealedDeliveryHistoryValid(state, job: job)
    }
    return true
  }
}

extension Game {
  func nativeOriginalSealedDispatchOrigin(for pack: ScriptPack) -> NativeOriginalSealedDispatchOrigin? {
    NativeOriginalSealedDispatchOrigin.current(in: self, pack: pack)
  }

  func contractBoardStation(for pack: ScriptPack) -> ContractStationIdentity? {
    guard docked else { return nil }
    if dockedAtMainStation { return contractStation }
    return nativeOriginalSealedDispatchOrigin(for: pack)?.station
  }

  func courierOriginIsCurrent(
    _ station: ContractStationIdentity, declaration: ScriptCourierDefinition
  ) -> Bool {
    if station.stationClass == "main-orbital" {
      return docked && dockedAtMainStation && station == contractStation
    }
    guard declaration == OriginalSealedDispatch.definition,
      let pack = scriptPacks.first(where: { OriginalSealedDispatch.validManifest($0.manifest) })
    else { return false }
    return nativeOriginalSealedDispatchOrigin(for: pack)?.station == station
  }

  func courierAdmissionOriginIsCurrent(_ admission: ScriptCourierAdmission, pack: ScriptPack) -> Bool {
    if admission.proof.station.stationClass == "main-orbital" {
      guard dockedAtMainStation, contractStation == admission.proof.station,
        admission.originalOrigin == nil, admission.proof.originalOrigin == nil
      else { return false }
      if admission.kind == .deliver, let terms = admission.job.offer.courier,
        OriginalSealedDispatch.matches(terms.declaration)
      {
        guard let receiver = admission.originalReceiver else { return false }
        return acceptsNativeMainStationArrivalContext(receiver)
          && originalSealedDispatchReceiver(for: admission.job) == receiver
      }
      return admission.originalReceiver == nil
    }
    guard admission.kind != .deliver, let origin = admission.originalOrigin,
      origin.station == admission.proof.station, origin.station == admission.job.station,
      origin.facts == admission.proof.originalOrigin
    else { return false }
    return origin.isCurrent(in: self, pack: pack)
  }

  func scriptDialogueStationIsCurrent(pack: ScriptPack, state: ScriptInstance, contact: String) -> Bool {
    if dockedAtMainStation { return true }
    guard state.definition == OriginalSealedDispatch.stateID,
      state.digest == pack.digest, state.version == pack.manifest.version,
      let job = state.contract, job.offer.courier?.declaration == OriginalSealedDispatch.definition,
      contact == OriginalSealedDispatch.definition.abandonContact,
      state.courier?.terminal == nil, state.courier?.pendingLoss == nil,
      let origin = nativeOriginalSealedDispatchOrigin(for: pack)
    else { return false }
    return origin.station == job.station
  }

  func courierOrMainDialogueStationIsCurrent(_ state: ScriptInstance, contact: String) -> Bool {
    guard let pack = scriptPack(for: state) else { return false }
    return scriptDialogueStationIsCurrent(pack: pack, state: state, contact: contact)
  }

  func originalSealedDispatchReceiver(for job: ScriptContractJob) -> NativeMainStationArrivalContext? {
    guard let terms = job.offer.courier, OriginalSealedDispatch.matches(terms.declaration),
      let owner = commander.equipmentOwnerID, let world = commander.nativeStations,
      world.ledger.world == owner,
      let destination = world.mainStations.first(where: {
        $0.world == owner && $0.system == SystemIdentity(
          galaxy: job.offer.destinationGalaxy, system: job.offer.destinationSystem)
      }),
      let receiver = nativeMainStationArrivalContext(for: destination),
      receiver.receipt.commanderOwner == owner,
      receiver.receipt.sequence < world.nextMainDockSequence
    else { return nil }
    return receiver
  }

  func courierDialogueStationIsCurrent(_ state: ScriptInstance, contact: String) -> Bool {
    guard let job = state.contract, let terms = job.offer.courier,
      let pack = scriptPack(for: state), pack.manifest.courier == terms.declaration
    else { return false }
    if contact == terms.declaration.deliveryContact {
      if OriginalSealedDispatch.matches(terms.declaration) {
        return originalSealedDispatchReceiver(for: job) != nil
      }
      return docked && dockedAtMainStation && commander.galaxy == job.offer.destinationGalaxy
        && commander.system == job.offer.destinationSystem
    }
    return contact == terms.declaration.abandonContact
      && courierOriginIsCurrent(job.station, declaration: terms.declaration)
      && scriptDialogueStationIsCurrent(pack: pack, state: state, contact: contact)
  }
}
