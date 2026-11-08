import Foundation

extension NativeCrewService {
  static func valid(
    _ state: NativeCrewServiceState?, custody: NativePeopleCustodyState,
    commander: borrowing Commander
  ) -> Bool {
    guard let state else { return true }
    guard state.owner == custody.owner, state.owner == commander.equipmentOwnerID,
      state.sourceDigest == digest, state.registration.station == sourceStation(owner: state.owner),
      NativeStationPassengerJourney.historicalDock(state.registration, commander: commander),
      state.people.count == definitions.count, !state.receipts.isEmpty,
      state.receipts.count <= maximumReceipts,
      state.receipts.first?.kind == .hire, state.receipts.first?.dock == state.registration
    else { return false }
    let identities = Set(state.people.map(\.identity))
    let ids = Set(state.people.map { $0.identity.id })
    guard identities.count == definitions.count, ids.count == definitions.count,
      !ids.contains(state.owner),
      custody.admissions.allSatisfy({ admission in
        if let id = admission.person.nativeID, ids.contains(id) { return false }
        guard let station = admission.person.station else { return true }
        return !identities.contains(station)
      }),
      commander.accommodation.ownedBerths.allSatisfy({
        $0.use.personID.map { !ids.contains($0) } ?? true
      })
    else { return false }
    var replay = NativeCrewServiceState(owner: state.owner, registration: state.registration)
    var operations: Set<UUID> = []
    var physicalTime: Double = 0
    var calendar = state.registration.calendarSeconds
    for receipt in state.receipts {
      guard operations.insert(receipt.operation).inserted,
        receipt.revision == replay.revision + 1,
        receipt.physicalTime.isFinite, receipt.physicalTime >= physicalTime,
        receipt.physicalTime <= commander.flightSimulation.physicalTime,
        receipt.calendarSeconds.isFinite, receipt.calendarSeconds >= calendar,
        receipt.calendarSeconds <= commander.scriptState.calendarSeconds,
        receipt.player.entity == 0, receipt.player.visit > 0,
        receipt.player.visit <= commander.flightSimulation.visit,
        (0...4_294_967_295).contains(receipt.beforeCash),
        (0...4_294_967_295).contains(receipt.afterCash),
        (0...firstContractPrice).contains(receipt.price),
        receipt.beforeCash >= receipt.price,
        receipt.afterCash == receipt.beforeCash - receipt.price,
        validReceipt(receipt, before: replay, commander: commander)
      else { return false }
      guard receipt.kind.terminal || replay.receipts.count < maximumReceipts - 2 else { return false }
      // Operation uniqueness was checked above with a Set, not a quadratic history rescan.
      for change in receipt.changes {
        guard let index = replay.people.firstIndex(where: { $0.identity == change.person }) else {
          return false
        }
        replay.people[index].location = change.after
        replay.people[index].contract = change.contract
        replay.people[index].revision = receipt.revision
      }
      replay.receipts.append(receipt)
      guard placesUnique(replay.people) else { return false }
      physicalTime = receipt.physicalTime
      calendar = receipt.calendarSeconds
    }
    guard replay.people == state.people else { return false }
    for person in state.people {
      guard person.identity.owner == state.owner, person.identity.batch == batch,
        definition(person.identity.person) != nil
      else { return false }
      if let station = person.location.station {
        guard station.valid, station.world == state.owner,
          commander.nativeStations?.mainStations.contains(station) == true
        else { return false }
      }
      if let place = person.location.place {
        guard person.contract != nil, person.location.hull == commander.hullInstanceID,
          let layout = accommodation(commander.shipID),
          (1..<layout.intrinsicCrewQuarters).contains(place)
        else { return false }
      }
    }
    return true
  }

  private static func placesUnique(_ people: [NativeCrewPerson]) -> Bool {
    let aboard = people.filter { $0.location.place != nil }
    return Set(aboard.compactMap { $0.location.hull }).count <= 1
      && Set(aboard.compactMap { $0.location.place })
        == Set((0..<aboard.count).map { $0 + 1 })
  }

  private static func validReceipt(
    _ receipt: NativeCrewReceipt, before: borrowing NativeCrewServiceState, commander: borrowing Commander
  ) -> Bool {
    guard !receipt.changes.isEmpty, receipt.changes.count <= definitions.count,
      Set(receipt.changes.map(\.person)).count == receipt.changes.count,
      let layout = accommodation(receipt.shipID)
    else { return false }
    if receipt.kind.terminal {
      guard receipt.dock == nil, receipt.price == 0 else { return false }
    } else {
      guard let dock = receipt.dock,
        NativeStationPassengerJourney.historicalDock(dock, commander: commander),
        dock.calendarSeconds <= receipt.calendarSeconds,
        dock.actor.system == receipt.player.system, dock.actor.visit == receipt.player.visit,
        dock.commanderOwner == before.owner
      else { return false }
    }
    let aboard = before.people.filter { $0.location.place != nil }
    if receipt.kind == .exchange || receipt.kind.terminal {
      guard !aboard.isEmpty,
        Set(aboard.map(\.identity)) == Set(receipt.changes.map(\.person))
      else { return false }
    } else if receipt.kind == .hire, receipt.changes.count != 1 { return false }
    if receipt.kind == .disembark {
      guard receipt.changes.filter({ $0.after.station != nil }).count == 1 else { return false }
    }
    for change in receipt.changes {
      guard let person = before.people.first(where: { $0.identity == change.person }),
        change.before == person.location, change.priorContract == person.contract
      else { return false }
      switch receipt.kind {
      case .hire:
        guard let dock = receipt.dock, let answer = change.reply,
          answer.epoch == receipt.epoch, answer.shipID == receipt.shipID,
          answer.price == receipt.price,
          answer == reply(
            person: person, kind: .hire, dock: dock, hull: answer.hull, place: answer.place,
            shipID: receipt.shipID, price: receipt.price, epoch: receipt.epoch),
          change.after == .aboard(hull: answer.hull, place: answer.place),
          change.contract == (person.contract ?? receipt.operation)
        else { return false }
      case .disembark:
        guard let dock = receipt.dock, let answer = change.reply,
          let hull = person.location.hull, let oldPlace = person.location.place,
          receipt.price == 0, change.contract == person.contract
        else { return false }
        if change.after == .station(dock.station) {
          guard answer == reply(
            person: person, kind: .disembark, dock: dock, hull: hull, place: oldPlace,
            shipID: receipt.shipID, price: 0, epoch: receipt.epoch)
          else { return false }
        } else {
          guard change.after.hull == hull, let place = change.after.place,
            answer == reply(
              person: person, kind: .exchange, dock: dock, hull: hull, place: place,
              shipID: receipt.shipID, price: 0, epoch: receipt.epoch)
          else { return false }
        }
      case .exchange:
        guard let dock = receipt.dock, let answer = change.reply,
          let target = change.after.hull, let place = change.after.place,
          target != person.location.hull,
          answer == reply(
            person: person, kind: .exchange, dock: dock, hull: target, place: place,
            shipID: receipt.shipID, price: 0, epoch: receipt.epoch),
          receipt.price == 0, change.contract == person.contract,
          (1..<layout.intrinsicCrewQuarters).contains(place)
        else { return false }
      case .loss, .escape:
        guard let hull = person.location.hull, person.location.place != nil,
          person.contract != nil, change.contract == person.contract, change.reply == nil,
          change.after == (receipt.kind == .loss ? .lost(hull: hull) : .leftOnEscape(hull: hull))
        else { return false }
      }
    }
    return true
  }

  /// Current container validation only; no compatibility format or new save version.
  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      root["crewService"] == nil
    else { throw SaveError.invalidCommander }
    guard part == .commander else {
      guard root["savedNativePeopleCustody"] == nil else { throw SaveError.invalidCommander }
      return
    }
    let custody = root["savedNativePeopleCustody"] as? [String: Any] ?? [:]
    for key in ["savedAccommodation", "savedEquipmentInventory", "savedScriptState", "savedContracts"] {
      let container = root[key] as? [String: Any] ?? [:]
      guard container["crewService"] == nil else { throw SaveError.invalidCommander }
    }
    let accommodation = root["savedAccommodation"] as? [String: Any] ?? [:]
    let nativeRecords = (custody["admissions"] as? [[String: Any]] ?? [])
      + (custody["transfers"] as? [[String: Any]] ?? [])
      + (accommodation["ownedBerths"] as? [[String: Any]] ?? [])
    guard nativeRecords.allSatisfy({ $0["crewService"] == nil }) else {
      throw SaveError.invalidCommander
    }
    guard let value = custody["crewService"] else { return }
    guard let raw = value as? [String: Any],
      let people = raw["people"] as? [Any], people.count == definitions.count,
      let receipts = raw["receipts"] as? [[String: Any]], receipts.count <= maximumReceipts,
      receipts.allSatisfy({
        guard let changes = $0["changes"] as? [Any] else { return false }
        return (1...definitions.count).contains(changes.count)
      })
    else { throw SaveError.invalidCommander }
    let data = try JSONSerialization.data(withJSONObject: raw)
    let state = try JSONDecoder().decode(NativeCrewServiceState.self, from: data)
    let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    guard (raw as NSDictionary).isEqual(canonical) else { throw SaveError.invalidCommander }
  }
}
