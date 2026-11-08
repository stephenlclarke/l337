import Foundation

enum NativeCrewAction: Equatable, Sendable {
  case status
  case hire(NativeStationPersonIdentity)
  case disembark(NativeStationPersonIdentity)
  case history(UUID)

  var key: String {
    switch self {
    case .status: "status"
    case .hire(let person): "hire/" + person.key
    case .disembark(let person): "disembark/" + person.key
    case .history(let operation): "history/" + operation.uuidString
    }
  }
  var action: String {
    switch self {
    case .hire: "Hire / assign"
    case .disembark: "Disembark"
    case .status, .history: "Recorded"
    }
  }
  var transactional: Bool {
    switch self {
    case .hire, .disembark: true
    case .status, .history: false
    }
  }
  var person: NativeStationPersonIdentity? {
    switch self {
    case .hire(let person), .disembark(let person): person
    case .status, .history: nil
    }
  }
}

extension Game {
  /// Pure projection of one authored finite source, or its retained exact locations.
  var nativeCrewPeople: [NativeCrewPerson] {
    if let source = commander.nativePeople?.crewService { return source.people }
    guard let owner = commander.equipmentOwnerID else { return [] }
    return NativeCrewService.originalPeople(
      owner: owner, station: NativeCrewService.sourceStation(owner: owner))
  }
  var nativeCrewRows: [ContractBoardRow] {
    var actions: [(NativeCrewAction, String)] = [(.status, commander.nativeCrewSummary)]
    let station = commander.nativeStations?.currentMainDock?.station
    for person in nativeCrewPeople {
      if person.location.place != nil {
        actions.append((.disembark(person.identity), "Crew / " + person.name + " / aboard"))
      } else if person.location.station == station, station != nil {
        let cost = person.contract == nil ? "200 CR" : "paid contract / 0 CR"
        actions.append((.hire(person.identity), "Crew / " + person.name + " / " + cost))
      }
    }
    let recent = Array((commander.nativePeople?.crewService?.receipts ?? []).suffix(16))
    actions += recent.map {
      (NativeCrewAction.history($0.operation), "Crew / " + $0.kind.rawValue + " receipt \($0.revision)")
    }
    let custodyValid = commander.nativePeopleStateValid
    return actions.map { action, title in
      let row = NativePeopleStationRow.crew(action)
      return .init(
        board: row.key, offer: nil, title: title,
        reason: nativeCrewQuote(action, custodyValid: custodyValid).issues.first, people: row)
    }
  }
  mutating func openNativeCrewBoard() {
    guard docked, !paused else { return }
    openContractBoard()
    guard screen == .contracts,
      let index = contractBoard.rows.firstIndex(where: {
        if case .crew = $0.people { return true }
        return false
      })
    else { return }
    contractBoard.selection = index
    contractBoard.detail = false
  }
  private var nativeCrewArrival: NativeMainStationArrivalContext? {
    guard case .living(let destination) = nativeOriginalMainStationDestination else { return nil }
    return nativeMainStationArrivalContext(for: destination.identity)
  }
  /// An epoch is returned only with the existing current sealed main-station arrival authority.
  var nativeCrewExchangeEpoch: UUID? {
    guard let arrival = nativeCrewArrival, docked, !paused,
      acceptsNativeMainStationArrivalContext(arrival),
      arrival.receipt.commanderOwner == commander.equipmentOwnerID,
      arrival.receipt == commander.nativeStations?.currentMainDock
    else { return nil }
    return nativeStationRuntimeEpoch
  }
  private func nativeCrewFreePlace(_ layout: ShipAccommodationProfile) -> Int? {
    let used = Set(commander.assignedNativeCrew.compactMap { $0.location.place })
    return (1..<layout.intrinsicCrewQuarters).first { !used.contains($0) }
  }
  func nativeCrewQuote(_ action: NativeCrewAction) -> NativePeopleStationQuote {
    nativeCrewQuote(action, custodyValid: commander.nativePeopleStateValid)
  }
  private func nativeCrewQuote(_ action: NativeCrewAction, custodyValid: Bool) -> NativePeopleStationQuote {
    var issues: [String] = []
    let context = nativeCrewArrival
    let person = nativeCrewPeople.first { $0.identity == action.person }
    let price: Int
    if case .hire = action { price = person?.contract == nil ? NativeCrewService.firstContractPrice : 0 }
    else { price = 0 }
    if !custodyValid { issues.append("Native crew custody is invalid.") }
    if case .history(let operation) = action,
      commander.nativePeople?.crewService?.receipts.contains(where: { $0.operation == operation }) != true
    { issues.append("This crew receipt is unavailable.") }
    if action.transactional {
      if !docked || paused || context == nil {
        issues.append("Crew service requires a proved living main orbital arrival.")
      }
      if !scriptDurabilityAvailable { issues.append("Choose a writable commander save first.") }
      if let source = commander.nativePeople?.crewService,
        source.receipts.count >= NativeCrewService.maximumReceipts - 2
      { issues.append("Crew contract storage is full; no people or money will move.") }
      guard let person, let context, let owner = commander.equipmentOwnerID,
        let hull = commander.hullInstanceID, let inventory = commander.equipmentInventory,
        inventory.owner == owner, inventory.activeHull == hull,
        let layout = NativeCrewService.accommodation(commander.shipID)
      else {
        issues.append("This exact person, owned hull or intrinsic layout is unavailable.")
        return nativeCrewQuoteResult(action, context: context, person: person, price: price, issues: issues)
      }
      switch action {
      case .hire:
        if NativeCrewService.adoptedAccommodation(commander.shipID) == nil {
          issues.append("This crew source serves the original Bison and Buffalo hulls.")
        }
        let place = nativeCrewFreePlace(layout)
        if place == nil { issues.append("No free intrinsic crew place remains; commander occupies one.") }
        if commander.credits < price { issues.append("Insufficient cash for the exact crew contract.") }
        if person.location != .station(context.receipt.station) {
          issues.append("This person is not available at this station.")
        }
        if commander.nativePeople?.crewService == nil,
          context.receipt.station != NativeCrewService.sourceStation(owner: owner)
        { issues.append("The finite original crew source is at Avenor main orbital.") }
        if let place,
          NativeCrewService.reply(
            person: person, kind: .hire, dock: context.receipt, hull: hull, place: place,
            shipID: commander.shipID, price: price, epoch: nativeStationRuntimeEpoch) == nil
        { issues.append("This person does not consent to these current crew terms.") }
      case .disembark:
        guard let place = person.location.place, person.location.hull == hull,
          NativeCrewService.reply(
            person: person, kind: .disembark, dock: context.receipt, hull: hull, place: place,
            shipID: commander.shipID, price: 0, epoch: nativeStationRuntimeEpoch) != nil
        else {
          issues.append("This person is not voluntarily disembarking from your current hull.")
          break
        }
      case .status, .history: break
      }
    }
    return nativeCrewQuoteResult(action, context: context, person: person, price: price, issues: issues)
  }
  private func nativeCrewQuoteResult(
    _ action: NativeCrewAction, context: NativeMainStationArrivalContext?, person: NativeCrewPerson?,
    price: Int, issues: [String]
  ) -> NativePeopleStationQuote {
    let available = context.map { arrival in
      nativeCrewPeople.filter { $0.location.station == arrival.receipt.station }.count
    } ?? 0
    var members = person.map { [$0.reference] } ?? []
    if case .disembark = action, let person, let context, let hull = commander.hullInstanceID,
      let changes = try? nativeCrewDisembarkChanges(person, dock: context.receipt, hull: hull)
    { members = changes.map { .station($0.person) } }
    return .init(
      row: .crew(action), commander: commander, context: context,
      members: members, price: price, stock: available,
      epoch: nativeStationRuntimeEpoch, issues: issues)
  }
  private func nativeCrewDisembarkChanges(
    _ person: NativeCrewPerson, dock: NativeMainStationDockReceipt, hull: UUID
  ) throws -> [NativeCrewChange] {
    guard let place = person.location.place,
      let reply = NativeCrewService.reply(
        person: person, kind: .disembark, dock: dock, hull: hull, place: place,
        shipID: commander.shipID, price: 0, epoch: nativeStationRuntimeEpoch)
    else { throw SaveError.invalidCommander }
    var changes = [NativeCrewChange(
      person: person.identity, before: person.location, after: .station(dock.station),
      priorContract: person.contract, contract: person.contract, reply: reply)]
    let remaining = commander.assignedNativeCrew.filter { $0.identity != person.identity }
    for (index, member) in remaining.enumerated() {
      let newPlace = index + 1
      let after = NativeCrewLocation.aboard(hull: hull, place: newPlace)
      guard member.location != after else { continue }
      guard let answer = NativeCrewService.reply(
        person: member, kind: .exchange, dock: dock, hull: hull, place: newPlace,
        shipID: commander.shipID, price: 0, epoch: nativeStationRuntimeEpoch)
      else { throw SaveError.invalidCommander }
      changes.append(.init(
        person: member.identity, before: member.location, after: after,
        priorContract: member.contract, contract: member.contract, reply: answer))
    }
    return changes
  }

  mutating func confirmNativeCrew(_ quote: NativePeopleStationQuote, action: NativeCrewAction) throws {
    let current = nativeCrewQuote(action)
    guard screen == .contracts, contractBoard.detail,
      contractBoard.selected?.people == .crew(action),
      quote.row == .crew(action), contractBoard.peopleQuote?.reviewToken == quote.reviewToken,
      quote.allowed, current.allowed, quote.members == current.members,
      quote.price == current.price, quote.stock == current.stock,
      quote.resources == commander.contractQuoteResources, quote.epoch == nativeStationRuntimeEpoch,
      let context = quote.context, current.context == context,
      acceptsNativeMainStationArrivalContext(context), let owner = commander.equipmentOwnerID,
      let hull = commander.hullInstanceID, let player = commander.flightSimulation.player,
      let layout = NativeCrewService.accommodation(commander.shipID)
    else { throw MissionPackError("Crew, cash, hull or station changed. Review the contract again.") }
    var candidate = self
    candidate.ensureScriptCalendar(origin: .newCommander)
    var custody = commander.nativePeople ?? .init(owner: owner)
    var source = custody.crewService ?? .init(owner: owner, registration: context.receipt)
    guard let person = source.people.first(where: { $0.identity == action.person }) else {
      throw SaveError.invalidCommander
    }
    let kind: NativeCrewMutation
    let after: NativeCrewLocation
    let contract: UUID?
    let place: Int
    switch action {
    case .hire:
      guard let free = nativeCrewFreePlace(layout) else { throw SaveError.invalidCommander }
      kind = .hire
      place = free
      after = .aboard(hull: hull, place: free)
      contract = person.contract ?? quote.reviewToken
    case .disembark:
      guard let assigned = person.location.place else { throw SaveError.invalidCommander }
      kind = .disembark
      place = assigned
      after = .station(context.receipt.station)
      contract = person.contract
    case .status, .history: throw SaveError.invalidCommander
    }
    guard let reply = NativeCrewService.reply(
      person: person, kind: kind, dock: context.receipt, hull: hull, place: place,
      shipID: commander.shipID, price: quote.price, epoch: nativeStationRuntimeEpoch)
    else { throw SaveError.invalidCommander }
    var changes = [NativeCrewChange(
      person: person.identity, before: person.location, after: after,
      priorContract: person.contract, contract: contract, reply: reply)]
    if kind == .disembark {
      changes = try nativeCrewDisembarkChanges(person, dock: context.receipt, hull: hull)
    }
    try source.append(.init(
      operation: quote.reviewToken, revision: source.revision + 1, kind: kind,
      dock: context.receipt, player: player, shipID: commander.shipID,
      changes: changes,
      beforeCash: commander.credits, afterCash: commander.credits - quote.price, price: quote.price,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: candidate.commander.scriptState.calendarSeconds, epoch: nativeStationRuntimeEpoch))
    custody.crewService = source
    candidate.commander.savedNativePeopleCustody = custody
    candidate.commander.credits -= quote.price
    guard candidate.commander.valid else { throw SaveError.invalidCommander }
    self = candidate
  }

  var nativeCrewDetailSummary: [String] {
    let layout = NativeCrewService.accommodation(commander.shipID)
    let places = layout?.intrinsicCrewQuarters ?? 0
    return [
      commander.nativeCrewSummary,
      "Intrinsic places: \(places); free: \(max(0, places - 1 - commander.assignedNativeCrew.count)).",
      "Commander counts once. Crew use intrinsic places, not passenger cabins or cargo.",
      "First contract: 200 CR per person once. No wages. No automatic recruitment.",
    ]
  }
  func nativeCrewDetail(_ action: NativeCrewAction) -> [String] {
    var rows = nativeCrewDetailSummary
    if let id = action.person, let person = nativeCrewPeople.first(where: { $0.identity == id }) {
      rows += [person.name + " / " + nativeCrewLocationText(person.location)]
      switch action {
      case .hire:
        let price = nativeCrewQuote(action).price
        rows += [
          String(format: "Confirm: assign this consenting person for exactly %.1f CR.", Double(price) / 10),
          person.contract == nil ? "A new paid crew contract." : "The same paid contract; no second hiring fee.",
        ]
      case .disembark:
        rows += ["Confirm: voluntary disembarkation here. Same person and paid contract retained. No refund."]
        if let dock = nativeCrewArrival?.receipt, let hull = commander.hullInstanceID,
          let changes = try? nativeCrewDisembarkChanges(person, dock: dock, hull: hull)
        {
          rows += changes.dropFirst().map {
            (NativeCrewService.definition($0.person.person)?.name ?? "Crew")
              + " remains aboard / intrinsic place \($0.after.place ?? 0). Same paid contract."
          }
        }
      case .status, .history: break
      }
    } else if case .history(let operation) = action,
      let receipt = commander.nativePeople?.crewService?.receipts.first(where: { $0.operation == operation })
    {
      rows += ["Crew receipt \(receipt.revision): " + receipt.kind.rawValue]
      rows += receipt.changes.map {
        (NativeCrewService.definition($0.person.person)?.name ?? "Unavailable person")
          + " / " + nativeCrewLocationText($0.after)
      }
      rows += [String(format: "Exact contract debit: %.1f CR.", Double(receipt.price) / 10)]
    } else {
      rows += nativeCrewPeople.map { $0.name + " / " + nativeCrewLocationText($0.location) }
    }
    return rows + ["Back changes no people, assignments or cash."] + nativeCrewQuote(action).issues
  }
  private func nativeCrewLocationText(_ location: NativeCrewLocation) -> String {
    switch location {
    case .station(let station):
      let name = Universe.systemsIncludingPlugh(number: station.system.galaxy)[station.system.system].name
      return name + " main orbital"
    case .aboard(_, let place): return "aboard / intrinsic place \(place)"
    case .lost: return "lost with hull / no rescue recorded"
    case .leftOnEscape: return "left with abandoned hull / no rescue recorded"
    }
  }
  var nativeCrewPageFacts: [String] {
    var facts = [String(commander.nativePeople?.crewService?.revision ?? 0), commander.nativeCrewSummary]
    facts += nativeCrewPeople.map {
      $0.identity.key + "/\($0.revision)/" + ($0.contract?.uuidString ?? "unpaid")
        + "/" + nativeCrewLocationText($0.location)
    }
    return facts
  }
  mutating func closeNativeCrew(_ kind: NativeCrewMutation) throws {
    let assigned = commander.assignedNativeCrew
    guard !assigned.isEmpty else { return }
    guard kind.terminal,
      (kind == .loss ? (screen == .gameOver && energy.isFinite && energy <= 0) : !docked),
      let player = commander.flightSimulation.player,
      var custody = commander.nativePeople, var source = custody.crewService
    else { throw SaveError.invalidCommander }
    let changes = try assigned.map { person -> NativeCrewChange in
      guard let hull = person.location.hull else { throw SaveError.invalidCommander }
      return .init(
        person: person.identity, before: person.location,
        after: kind == .loss ? .lost(hull: hull) : .leftOnEscape(hull: hull),
        priorContract: person.contract, contract: person.contract, reply: nil)
    }
    try source.append(.init(
      operation: UUID(), revision: source.revision + 1, kind: kind, dock: nil,
      player: player, shipID: commander.shipID, changes: changes,
      beforeCash: commander.credits, afterCash: commander.credits, price: 0,
      physicalTime: commander.flightSimulation.physicalTime,
      calendarSeconds: commander.scriptState.calendarSeconds, epoch: nativeStationRuntimeEpoch))
    custody.crewService = source
    commander.savedNativePeopleCustody = custody
  }
}

extension Commander {
  mutating func transferNativeCrew(to hull: UUID, shipID: String, epoch: UUID?) throws {
    let assigned = assignedNativeCrew
    guard !assigned.isEmpty else { return }
    guard nativeCrewTransferIssue(to: shipID) == nil else {
      throw EquipmentRuntimeError.incompatibleFit
    }
    // Read-only equipment projections keep the same hull and all receipt history.
    if hull == hullInstanceID { return }
    guard let epoch, let dock = nativeStations?.currentMainDock,
      NativeStationPassengerJourney.historicalDock(dock, commander: self),
      dock.station.system == SystemIdentity(galaxy: galaxy, system: system),
      dock.actor.visit == flightSimulation.visit, let player = flightSimulation.player,
      var custody = nativePeople, var source = custody.crewService
    else { throw EquipmentRuntimeError.incompatibleFit }
    let changes = try assigned.enumerated().map { index, person -> NativeCrewChange in
      let place = index + 1
      guard let answer = NativeCrewService.reply(
        person: person, kind: .exchange, dock: dock, hull: hull, place: place,
        shipID: shipID, price: 0, epoch: epoch)
      else { throw EquipmentRuntimeError.incompatibleFit }
      return .init(
        person: person.identity, before: person.location, after: .aboard(hull: hull, place: place),
        priorContract: person.contract, contract: person.contract, reply: answer)
    }
    try source.append(.init(
      operation: UUID(), revision: source.revision + 1, kind: .exchange, dock: dock,
      player: player, shipID: shipID, changes: changes,
      beforeCash: credits, afterCash: credits, price: 0,
      physicalTime: flightSimulation.physicalTime, calendarSeconds: scriptState.calendarSeconds,
      epoch: epoch))
    custody.crewService = source
    savedNativePeopleCustody = custody
  }
}
