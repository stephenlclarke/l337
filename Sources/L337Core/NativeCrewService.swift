import Foundation

/// Original finite Avenor volunteers. A definition is a person, never a fitted cabin or cargo unit.
struct NativeCrewDefinition: Sendable {
  let id: String
  let name: String
}

enum NativeCrewLocation: Equatable, Codable, Sendable {
  case station(NativeMainStationIdentity)
  case aboard(hull: UUID, place: Int)
  case lost(hull: UUID)
  case leftOnEscape(hull: UUID)

  var station: NativeMainStationIdentity? {
    if case .station(let station) = self { return station }
    return nil
  }
  var hull: UUID? {
    switch self {
    case .aboard(let hull, _), .lost(let hull), .leftOnEscape(let hull): hull
    case .station: nil
    }
  }
  var place: Int? {
    if case .aboard(_, let place) = self { return place }
    return nil
  }
}

struct NativeCrewPerson: Equatable, Codable, Sendable {
  let identity: NativeStationPersonIdentity
  var location: NativeCrewLocation
  var contract: UUID?
  var revision: UInt64
  var reference: NativePersonReference { .station(identity) }
  var name: String { NativeCrewService.definition(identity.person)?.name ?? "Unavailable person" }
}

enum NativeCrewMutation: String, Equatable, Codable, Sendable {
  case hire, disembark, exchange, loss, escape
  var terminal: Bool { self == .loss || self == .escape }
}

/// The person's native reply to these exact terms, not a player-set consent switch.
struct NativeCrewReply: Equatable, Codable, Sendable {
  let personRevision: UInt64
  let contract: UUID?
  let dock: NativeMainStationDockReceipt
  let hull: UUID
  let place: Int
  let shipID: String
  let price: Int
  let epoch: UUID
}

struct NativeCrewChange: Equatable, Codable, Sendable {
  let person: NativeStationPersonIdentity
  let before: NativeCrewLocation
  let after: NativeCrewLocation
  let priorContract: UUID?
  let contract: UUID?
  let reply: NativeCrewReply?
}

struct NativeCrewReceipt: Equatable, Codable, Sendable {
  let operation: UUID
  let revision: UInt64
  let kind: NativeCrewMutation
  let dock: NativeMainStationDockReceipt?
  let player: ActorIdentity
  let shipID: String
  let changes: [NativeCrewChange]
  let beforeCash: Int
  let afterCash: Int
  let price: Int
  let physicalTime: Double
  let calendarSeconds: Double
  let epoch: UUID

  private enum CodingKeys: String, CodingKey {
    case operation, revision, kind, dock, player, shipID, changes, beforeCash, afterCash, price,
      physicalTime, calendarSeconds, epoch
  }

  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let list = try values.nestedUnkeyedContainer(forKey: .changes)
    guard let count = list.count, (1...NativeCrewService.definitions.count).contains(count) else {
      throw SaveError.invalidCommander
    }
    operation = try values.decode(UUID.self, forKey: .operation)
    revision = try values.decode(UInt64.self, forKey: .revision)
    kind = try values.decode(NativeCrewMutation.self, forKey: .kind)
    dock = try values.decodeIfPresent(NativeMainStationDockReceipt.self, forKey: .dock)
    player = try values.decode(ActorIdentity.self, forKey: .player)
    shipID = try values.decode(String.self, forKey: .shipID)
    changes = try values.decode([NativeCrewChange].self, forKey: .changes)
    beforeCash = try values.decode(Int.self, forKey: .beforeCash)
    afterCash = try values.decode(Int.self, forKey: .afterCash)
    price = try values.decode(Int.self, forKey: .price)
    physicalTime = try values.decode(Double.self, forKey: .physicalTime)
    calendarSeconds = try values.decode(Double.self, forKey: .calendarSeconds)
    epoch = try values.decode(UUID.self, forKey: .epoch)
  }

  init(
    operation: UUID, revision: UInt64, kind: NativeCrewMutation,
    dock: NativeMainStationDockReceipt?, player: ActorIdentity, shipID: String,
    changes: [NativeCrewChange], beforeCash: Int, afterCash: Int, price: Int,
    physicalTime: Double, calendarSeconds: Double, epoch: UUID
  ) {
    self.operation = operation
    self.revision = revision
    self.kind = kind
    self.dock = dock
    self.player = player
    self.shipID = shipID
    self.changes = changes
    self.beforeCash = beforeCash
    self.afterCash = afterCash
    self.price = price
    self.physicalTime = physicalTime
    self.calendarSeconds = calendarSeconds
    self.epoch = epoch
  }
}

struct NativeCrewServiceState: Equatable, Codable, Sendable {
  let owner: UUID
  let sourceDigest: String
  let registration: NativeMainStationDockReceipt
  var people: [NativeCrewPerson]
  var receipts: [NativeCrewReceipt]
  var revision: UInt64 { UInt64(receipts.count) }

  init(owner: UUID, registration: NativeMainStationDockReceipt) {
    self.owner = owner
    sourceDigest = NativeCrewService.digest
    self.registration = registration
    people = NativeCrewService.originalPeople(owner: owner, station: registration.station)
    receipts = []
  }

  private enum CodingKeys: String, CodingKey {
    case owner, sourceDigest, registration, people, receipts
  }
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let peopleList = try values.nestedUnkeyedContainer(forKey: .people)
    let receiptList = try values.nestedUnkeyedContainer(forKey: .receipts)
    guard peopleList.count == NativeCrewService.definitions.count,
      let count = receiptList.count, count <= NativeCrewService.maximumReceipts
    else { throw SaveError.invalidCommander }
    owner = try values.decode(UUID.self, forKey: .owner)
    sourceDigest = try values.decode(String.self, forKey: .sourceDigest)
    registration = try values.decode(NativeMainStationDockReceipt.self, forKey: .registration)
    people = try values.decode([NativeCrewPerson].self, forKey: .people)
    receipts = try values.decode([NativeCrewReceipt].self, forKey: .receipts)
  }

  /// Callers stage this value inside the existing Game transaction and publisher.
  mutating func append(_ receipt: NativeCrewReceipt) throws {
    guard receipts.count < NativeCrewService.maximumReceipts,
      receipt.kind.terminal || receipts.count < NativeCrewService.maximumReceipts - 2,
      receipt.revision == revision + 1,
      !receipts.contains(where: { $0.operation == receipt.operation }),
      !receipt.changes.isEmpty,
      receipt.changes.count <= NativeCrewService.definitions.count,
      Set(receipt.changes.map(\.person)).count == receipt.changes.count
    else { throw SaveError.invalidCommander }
    let indices = try receipt.changes.map { change -> Int in
      guard let index = people.firstIndex(where: { $0.identity == change.person }),
        people[index].location == change.before, people[index].contract == change.priorContract
      else { throw SaveError.invalidCommander }
      return index
    }
    // Every throwing check precedes mutation; a unique replay buffer stays linear in receipts.
    for (index, change) in zip(indices, receipt.changes) {
      people[index].location = change.after
      people[index].contract = change.contract
      people[index].revision = receipt.revision
    }
    receipts.append(receipt)
  }
}

enum NativeCrewService {
  static let batch = "avenor-original-crew-01"
  // New bounded storage estimate, with two slots reserved for actual terminal events.
  static let maximumReceipts = 1024
  static let firstContractPrice = 2000
  static let definitions: [NativeCrewDefinition] = [
    .init(id: "sela-anwick", name: "Sela Anwick"),
    .init(id: "rian-corven", name: "Rian Corven"),
    .init(id: "talia-drex", name: "Talia Drex"),
    .init(id: "ivo-farren", name: "Ivo Farren"),
    .init(id: "mara-keld", name: "Mara Keld"),
    .init(id: "noel-lest", name: "Noel Lest"),
    .init(id: "eira-madd", name: "Eira Madd"),
    .init(id: "kian-orrick", name: "Kian Orrick"),
    .init(id: "vera-pellin", name: "Vera Pellin"),
    .init(id: "arun-rell", name: "Arun Rell"),
    .init(id: "nira-savin", name: "Nira Savin"),
    .init(id: "cal-torren", name: "Cal Torren"),
    .init(id: "disa-vann", name: "Disa Vann"),
  ]
  static let digest = ScriptPackLibrary.hash(
    Data((batch + "\n" + definitions.map { $0.id + ":" + $0.name }.joined(separator: "\n")
      + "\nadult-volunteers;first-contract=2000;no-wages;no-replenishment").utf8))
  static let launchHullIDs: Set<String> = Set(["SH005", "SH006", "SH007", "SH013", "SH014", "SH025", "SH026"])
    .union(OriginalPlayerHullActivation.resourceSHA256.keys)

  static func definition(_ id: String) -> NativeCrewDefinition? {
    definitions.first { $0.id == id }
  }
  static func sourceStation(owner: UUID) -> NativeMainStationIdentity {
    let key = "main-orbital:0:7"
    return .init(
      world: owner, system: .init(galaxy: 0, system: 7),
      resource: Game.worldResourceIdentity("main-station-v1:" + key))
  }
  static func originalPeople(owner: UUID, station: NativeMainStationIdentity) -> [NativeCrewPerson] {
    definitions.map {
      .init(
        identity: .init(owner: owner, batch: batch, person: $0.id),
        location: .station(station), contract: nil, revision: 0)
    }
  }
  static func accommodation(_ shipID: String) -> ShipAccommodationProfile? {
    guard let ship = ShipCatalogue.ship(shipID) else { return nil }
    return try? ShipAccommodationProfile(ship: ship)
  }
  /// Closed current routes; requirements do not hire people or grant a paid contract.
  static func adoptedAccommodation(_ shipID: String) -> ShipAccommodationProfile? {
    guard launchHullIDs.contains(shipID), let ship = ShipCatalogue.ship(shipID) else { return nil }
    if let current = OriginalFleetR3Fitting.contract(for: ship) {
      guard !OriginalDetailedHullStage.blocksRuntime(shipID), ship.catalogue.playerFlyable,
        let profile = accommodation(shipID), profile.crewStatus == "original-r3-current-fit",
        profile.operatingCrew == current.accommodation?.operatingCrew,
        profile.intrinsicCrewQuarters == current.accommodation?.intrinsicCrewPlaces,
        profile.equipmentUnits == OriginalFleetR3Fitting.nativeEquipmentUnits(for: ship, contract: current)
      else { return nil }
      return profile
    }
    if shipID == "SH007" {
      guard ship.profiles.count == 1, let selected = ship.profiles.first,
        selected.id == "ORIGINAL-IMPALA-R3-SH007", selected.group == "original-r3-source-stage",
        let profile = accommodation(shipID), profile.crewStatus == "authored-r3-native-adapter",
        profile.operatingCrew == 2, profile.intrinsicCrewQuarters == 2,
        profile.equipmentUnits == 26, profile.initialCharterBerths == 0,
        profile.maximumPhysicalCabinModules == 12
      else { return nil }
      return profile
    }
    return nil
  }

  /// These thirteen authored adults volunteer under these explicit standing terms.
  /// The current location, valid paid contract and intrinsic place still determine each reply.
  static func reply(
    person: NativeCrewPerson, kind: NativeCrewMutation, dock: NativeMainStationDockReceipt,
    hull: UUID, place: Int, shipID: String, price: Int, epoch: UUID
  ) -> NativeCrewReply? {
    guard person.identity.batch == batch, definition(person.identity.person) != nil,
      person.identity.owner == dock.commanderOwner, person.identity.id != dock.commanderOwner,
      let layout = accommodation(shipID), (1..<layout.intrinsicCrewQuarters).contains(place)
    else { return nil }
    switch kind {
    case .hire:
      guard adoptedAccommodation(shipID) != nil, person.location == .station(dock.station),
        price == (person.contract == nil ? firstContractPrice : 0)
      else { return nil }
    case .disembark, .exchange:
      guard person.location.place != nil, person.contract != nil, price == 0 else { return nil }
    case .loss, .escape: return nil
    }
    return .init(
      personRevision: person.revision, contract: person.contract, dock: dock,
      hull: hull, place: place, shipID: shipID, price: price, epoch: epoch)
  }
}

extension Commander {
  var assignedNativeCrew: [NativeCrewPerson] {
    guard let hull = hullInstanceID else { return [] }
    return nativePeople?.crewService?.people.filter {
      $0.location.place != nil && $0.location.hull == hull
    } ?? []
  }
  var nativeCrewMissing: Int? {
    guard NativeCrewService.launchHullIDs.contains(shipID) else { return 0 }
    guard let layout = NativeCrewService.adoptedAccommodation(shipID) else { return nil }
    return max(0, layout.operatingCrew - 1 - assignedNativeCrew.count)
  }
  var nativeCrewSummary: String {
    if !NativeCrewService.launchHullIDs.contains(shipID), shipID != "SH025" {
      return "Assigned crew \(assignedNativeCrew.count + 1) incl commander; readiness not active for this hull."
    }
    if let missing = nativeCrewMissing {
      let required = NativeCrewService.adoptedAccommodation(shipID)?.operatingCrew ?? 1
      return "Crew \(assignedNativeCrew.count + 1)/\(required) incl commander"
        + (missing > 0 ? " / missing \(missing)" : "")
    }
    return "Crew layout unavailable"
  }
  func nativeCrewTransferIssue(to shipID: String) -> String? {
    guard !assignedNativeCrew.isEmpty else { return nil }
    guard let layout = NativeCrewService.accommodation(shipID),
      assignedNativeCrew.count < layout.intrinsicCrewQuarters
    else { return "Disembark crew at this station before exchanging into fewer intrinsic places." }
    return nil
  }
}
