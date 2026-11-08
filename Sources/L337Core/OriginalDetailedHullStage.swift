import CryptoKit
import Foundation

/// A detailed original asset is not a native actor, fitting or acquisition authority.
enum OriginalDetailedHullStage {
  enum Failure: Error, Equatable, Sendable {
    case invalidDetailedResource(String)
    case nativeLODUnqualified(id: String, actualSourceFaces: Int, maximum: Int)
    case nativeEvidencePending(id: String, sourceFaces: Int)
    case engineeringRoleUnissued(String)
    case physicalBudgetUnissued(String)
    case nativeSourceUnissued(String)
  }

  struct Registration: Sendable {
    let id: String
    let name: String
    let family: String
    let sourceSHA256: String
    let r3SHA256: String
    let resourceSHA256: String
    let metresPerSourceUnit: String
    let detailedVertices: Int
    let detailedFaces: Int
    let sourceNativeFaces: Int
    var nativeSourceSHA256: String? = nil
    var physicalRecordSHA256: String? = nil
    var displayResourceSHA256: String? = nil
    var physicalStatus: String? = nil
  }

  static func registration(for id: String) -> Registration? {
    switch id {
    case "SH008":
      return .init(
        id: id, name: "Goshawk Explorer", family: "goshawk",
        sourceSHA256: "9a6b3e1403a5cbb45691592f2db2e1dac79bfc7c0d328a4b86a234487943e127",
        r3SHA256: "6815e92d5480692d18576ab5ed5e98cd1f99b1bff622c3c7eb346ed59bcf8d42",
        resourceSHA256: "aafcb5dfec2cb5d141316756daae267888bf3541383f4f155c2561a4d7dd0bb7",
        metresPerSourceUnit: "10000000/1028273", detailedVertices: 2072,
        detailedFaces: 3484, sourceNativeFaces: 964)
    case "SH009":
      return .init(
        id: id, name: "Goshawk Mk II", family: "goshawk",
        sourceSHA256: "41cda75d40e41e4de1a745de9f5c8770618fe5de2f0df0568a49a8c72ba92722",
        r3SHA256: "8487d3b24cff75389b9451eb6a3e9f041c907df16caf696a67cd31f46feec670",
        resourceSHA256: "4fc835b6f40c1b7751ff8c03940c0501ce7c445b1bd0be95f15651a174c67552",
        metresPerSourceUnit: "30000000/3186991", detailedVertices: 2104,
        detailedFaces: 3532, sourceNativeFaces: 1012)
    case "SH040":
      return .init(
        id: "SH040", name: "Newt Escape Pod", family: "newt-escape-pod",
        sourceSHA256: "5b52208ecf64228a843dc792ff4614af3ff9109034de4bedb6ddb0b7918072d9",
        r3SHA256: "6dd8182abf9a00406132db7926c962d470ea7f6c112bb29fad8646aef9aec0ed",
        resourceSHA256: "510a2059ce49a7d902c11ca65303264afa8ee103cd1a9e9ad823dbe05fee816c",
        metresPerSourceUnit: "60/19", detailedVertices: 256,
        detailedFaces: 415, sourceNativeFaces: 92,
        nativeSourceSHA256: "5b52208ecf64228a843dc792ff4614af3ff9109034de4bedb6ddb0b7918072d9",
        physicalRecordSHA256: "0d7cd491b77b6e14016daa8a3c5e622416963870f669f80d63ad3b4d74aaee17")
    case "SH156":
      return .init(
        id: "SH156", name: "Lion Bastion", family: "lion-bastion",
        sourceSHA256: "9a1147d23fa4a9e514afad7f5d9264746ff135f12729de23878750f4d7f1870d",
        r3SHA256: "9f023a5547867793485716c3a19a2ee73edc08988d6666ec6dadbdb8568b1bfc",
        resourceSHA256: "e464bb2d70ac42037fcc898cd2f59cf1243b1e4f7d9517df2da71b2fd5fe8505",
        metresPerSourceUnit: "90000/1699", detailedVertices: 2496,
        detailedFaces: 4072, sourceNativeFaces: 904,
        nativeSourceSHA256: "9a1147d23fa4a9e514afad7f5d9264746ff135f12729de23878750f4d7f1870d",
        physicalRecordSHA256: "b07c553bb8b41ca866bfc4da2ea41928faedde61e1c589cd8e6432e2b6120273")
    case "SH161":
      return .init(
        id: "SH161", name: "Wolf Citadel", family: "wolf",
        sourceSHA256: "0335361ca8aac1cc868e380b3312e2ffb222318803329f5a10c70a21cdf89621",
        r3SHA256: "354edb2f79b3b82e39dda176b9b68a6407172467547381e0a873665cb9d5e53b",
        resourceSHA256: "7bf1de5fb1589f47a9ef65433f854e0645c97433f0e7cbe025d96851db813821",
        metresPerSourceUnit: "1000000/22443", detailedVertices: 1216,
        detailedFaces: 2052, sourceNativeFaces: 788,
        nativeSourceSHA256: "0335361ca8aac1cc868e380b3312e2ffb222318803329f5a10c70a21cdf89621",
        physicalRecordSHA256: "0fb430800bed13bcbefe00e37ea0d1b4d94b5178bb8a6749d0f226ffca61a870")
    case "SH162":
      return .init(
        id: "SH162", name: "Larvaal Probe", family: "larvaal-probe",
        sourceSHA256: "14d4e261029ca1fcf61a2688c43c192e17c7e523a268ffb9c9b726b087b14151",
        r3SHA256: "243c15f460f4c990a2e4d9573ab6ea4ae24168477c68d7345139e1fe6dc28e59",
        resourceSHA256: "7f154b524fe32215311e1dc75a5ccb9deed133ed78f0dad8073becd0c8890ad6",
        metresPerSourceUnit: "12000000/2058667", detailedVertices: 768,
        detailedFaces: 1524, sourceNativeFaces: 596,
        nativeSourceSHA256: "14d4e261029ca1fcf61a2688c43c192e17c7e523a268ffb9c9b726b087b14151",
        physicalRecordSHA256: "74c75edfec6fb3243bd2a6d4497ffebfe6f8d5353d1dd7e388d8eee7b7df8d67")
    case "SH164":
      return .init(
        id: "SH164", name: "Toad Drug Factory", family: "toad-drug-factory",
        sourceSHA256: "b1563bbc135d0c6ec1ea44ccceabf8f3677363030bbf5af816a7a78d0c51c4e4",
        r3SHA256: "29b8cae2acf68eee7f05547c5c0487dceb866c4ba6d3280da5d20b68e55fa4cf",
        resourceSHA256: "5f80b4cff859e78e72b8619d6cfb5cf894796600688dd4afa09b61704cc7610a",
        metresPerSourceUnit: "60000000/887723", detailedVertices: 2520,
        detailedFaces: 4108, sourceNativeFaces: 940,
        nativeSourceSHA256: "b1563bbc135d0c6ec1ea44ccceabf8f3677363030bbf5af816a7a78d0c51c4e4",
        physicalRecordSHA256: "1af229dd864b6d385ca2098448a0d9dd8139bbd2c1e29424fe93ec9e6faac8dc")
    default:
      return OriginalFleetPendingSourceRegistrations.records[id]
        ?? OriginalFleetRelativePendingSourceRegistrations.records[id]
        ?? OriginalFleetLarvaalPendingSourceRegistrations.records[id]
    }
  }

  static func blocksRuntime(_ id: String) -> Bool { registration(for: id) != nil }

  static func requireRuntime(_ id: String) throws {
    guard let entry = registration(for: id) else { return }
    if entry.displayResourceSHA256 != nil { throw Failure.nativeSourceUnissued(id) }
    if entry.nativeSourceSHA256 != nil && entry.physicalRecordSHA256 == nil {
      if entry.physicalStatus == "UNISSUED_SOURCE_MOMENT_CONSISTENCY_STOP" {
        throw Failure.physicalBudgetUnissued(id)
      }
      throw Failure.engineeringRoleUnissued(id)
    }
    if entry.nativeSourceSHA256 != nil && entry.sourceNativeFaces <= 512 {
      throw Failure.nativeEvidencePending(id: id, sourceFaces: entry.sourceNativeFaces)
    }
    throw Failure.nativeLODUnqualified(
      id: id, actualSourceFaces: entry.sourceNativeFaces, maximum: 512)
  }

  static func requireRuntime(modelReference: String) throws {
    guard modelReference.hasPrefix("catalogue:") else { return }
    if modelReference == OriginalCryostasisCapsule.reference, OriginalCryostasisCapsule.source != nil {
      return
    }
    try requireRuntime(String(modelReference.dropFirst(10)))
  }

  static func blocksRuntime(_ body: SpaceBody) -> Bool {
    if let id = body.physical?.catalogueShipID, blocksRuntime(id) { return true }
    guard let fit = body.scriptNPC?.fit else { return false }
    return ([fit.definition.model] + (fit.definition.components ?? []).map(\.model)).contains {
      if $0 == OriginalCryostasisCapsule.reference, let source = OriginalCryostasisCapsule.source {
        return fit.models[$0] != source.collisionSHA256
      }
      if let scoped = OriginalScopedScriptedHull(reference: $0) { return !scoped.permits(fit) }
      return $0.hasPrefix("catalogue:") && blocksRuntime(String($0.dropFirst(10)))
    }
  }

  static func authenticate(_ ship: CatalogueShip, bytes: Data) throws {
    guard let entry = registration(for: ship.id) else { return }
    let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    guard digest == entry.resourceSHA256, validPendingRecord(ship, entry: entry) else {
      throw Failure.invalidDetailedResource(ship.id)
    }
  }

  static func resolvePending(_ ship: CatalogueShip) throws -> CatalogueShip {
    guard let entry = registration(for: ship.id), validPendingRecord(ship, entry: entry) else {
      throw Failure.invalidDetailedResource(ship.id)
    }
    return ship
  }

  /// Only the authenticated pending Newt resource may declare zero-drive capsule statistics.
  /// This never admits it as an ordinary ship, installed fitting, live capsule or person.
  static func hasPendingCapsuleStatistics(_ ship: CatalogueShip) -> Bool {
    guard ship.id == "SH040", let entry = registration(for: ship.id) else { return false }
    return validPendingRecord(ship, entry: entry)
  }

  private static func validPendingCapsuleFitting(
    _ ship: CatalogueShip, source: OriginalFleetR3Contract
  ) -> Bool {
    guard ship.id == "SH040", source.id == ship.id, source.objectKind == .capsule,
      ship.catalogue.objectKind == .capsule, source.origin == .human,
      ship.catalogue.origin == source.origin.catalogueOrigin,
      let crew = source.accommodation, let fitting = source.fitting,
      !crew.nativeAutonomous, crew.nativeCrew == 1, crew.operatingCrew == 1,
      crew.intrinsicCrewPlaces == 1, crew.initialPurchasedCabins == 0,
      crew.maximumCabins == 0, !fitting.roleKitIncluded,
      fitting.equipmentUnits == 0, fitting.utilityMounts == 0,
      fitting.compatibleUtilities.isEmpty, !fitting.externalMissilePylons,
      let performance = source.performance, performance.fuel == 0,
      performance.jump == 0, performance.spool == 0, performance.missiles == 0,
      performance.facings == 0, performance.cargo == 0, performance.cargoExpansion == 0
    else { return false }
    let profiles = ship.profiles.filter { $0.group == "project-refit-v1" }
    guard profiles.count == 1, let profile = profiles.first else { return false }
    func count(_ key: String, equals value: Int) -> Bool {
      let fields = profile.fields.filter { $0.key == key }
      return fields.count == 1 && fields[0].number == Double(value)
    }
    return count("required_crew_including_commander", equals: 1)
      && count("reserved_crew_accommodation", equals: 1)
      && count("equipment_capacity_units", equals: 0)
      && count("initial_charter_passenger_berths", equals: 0)
  }

  private static func validPendingSourceDomain(
    _ ship: CatalogueShip, source: OriginalFleetR3Contract
  ) -> Bool {
    switch source.objectKind {
    case .ship: return OriginalFleetR3Fitting.contract(for: ship) != nil
    case .capsule: return validPendingCapsuleFitting(ship, source: source)
    case .station, .platform, .other: return validPendingEnvironment(ship, source: source)
    }
  }

  private static func validPendingEnvironment(
    _ ship: CatalogueShip, source: OriginalFleetR3Contract
  ) -> Bool {
    guard ["SH156", "SH161", "SH162", "SH164"].contains(ship.id), source.id == ship.id,
      ship.catalogue.objectKind == source.objectKind,
      ship.catalogue.origin == source.origin.catalogueOrigin,
      source.performance == nil, ship.game == nil, source.accommodation == nil,
      source.fitting == nil, source.acquisition == nil, !source.playerFlyable,
      source.purchasePolicy == .never, let environment = source.environment,
      !environment.playerCrewRequired, environment.purchasePolicy == .never,
      ship.nativeDocking == nil, ship.profiles.count == 1,
      let profile = ship.profiles.first, profile.group == "original-r3-source-stage",
      ship.catalogue.damagePolicy == .destructible
    else { return false }
    let purposes = profile.fields.filter { $0.key == "original.environment.physicalService" }
    guard purposes.count == 1, purposes[0].text == environment.physicalService.rawValue else {
      return false
    }
    switch ship.id {
    case "SH156":
      return source.objectKind == .platform && environment.physicalService == .weaponsPlatform
        && ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .platform
        && ship.catalogue.collectionMilestone == .none && !ship.catalogue.discoveryEligible
    case "SH161", "SH164":
      return source.objectKind == .station && environment.physicalService == .stationServices
        && ship.catalogue.isCapital && ship.catalogue.capitalSubtype == .station
        && ship.catalogue.collectionMilestone == .docking && ship.catalogue.discoveryEligible
    case "SH162":
      return source.objectKind == .other && environment.physicalService == .missionProbe
        && !ship.catalogue.isCapital && ship.catalogue.capitalSubtype == nil
        && ship.catalogue.collectionMilestone == .none && !ship.catalogue.discoveryEligible
    default: return false
    }
  }

  private static func validPendingRecord(_ ship: CatalogueShip, entry: Registration) -> Bool {
    func text(_ key: String) -> String? {
      let fields = ship.profiles.flatMap(\.fields).filter { $0.key == key }
      return fields.count == 1 ? fields.first?.text : nil
    }
    let sourceValid: Bool
    let policy: ShipCataloguePurchasePolicy
    if entry.nativeSourceSHA256 != nil || entry.displayResourceSHA256 != nil {
      guard let current = OriginalFleetR3Data.contract(for: ship.id),
        current.sourceSHA256 == entry.r3SHA256,
        current.name == ship.name, current.family == ship.catalogue.family,
        ship.game == current.performance,
        ship.catalogue.minimumBuildTechLevel == nil, ship.catalogue.rarity == .pending,
        validPendingSourceDomain(ship, source: current)
      else { return false }
      if let nativeSHA = entry.nativeSourceSHA256 {
        guard let native = ship.nativeDesign, native.faces.count == entry.sourceNativeFaces,
          native.faces.allSatisfy({ $0.count == 3 }),
          text("original.native_geometry_sha256") == nativeSHA
        else { return false }
      } else {
        guard let displaySHA = entry.displayResourceSHA256, ship.nativeDesign == nil,
          entry.sourceNativeFaces == 0, entry.metresPerSourceUnit == "unissued",
          text("original.display_resource_sha256") == displaySHA
        else { return false }
      }
      if let physicalSHA = entry.physicalRecordSHA256 {
        guard let engineering = OriginalFleetPhysicalData.registrations[ship.id],
          engineering.sha256 == physicalSHA, engineering.detailedSHA256 == entry.sourceSHA256,
          engineering.nativeSourceSHA256 == entry.nativeSourceSHA256,
          engineering.calibration.exactScale == entry.metresPerSourceUnit,
          text("physical.record_sha256") == physicalSHA
        else { return false }
      } else {
        guard OriginalFleetPhysicalData.registrations[ship.id] == nil,
          entry.physicalStatus != nil, text("physical.record_sha256") == nil
        else { return false }
      }
      if let status = entry.physicalStatus, text("physical.status") != status { return false }
      policy = current.purchasePolicy == .blueprintFabrication ? .pendingFabrication : .never
      sourceValid = true
    } else {
      policy = .pendingFabrication
      sourceValid = ship.nativeDesign == nil
    }
    return sourceValid && ship.name == entry.name && ship.catalogue.family == entry.family
      && ship.design.vertices.count == entry.detailedVertices
      && ship.design.faces.count == entry.detailedFaces
      && ship.nativeHull == nil && ship.nativeCombat == nil
      && ship.catalogue.mechanicsStatus == .pending && ship.catalogue.placementStatus == .pending
      && ship.catalogue.purchasePolicy == policy
      && !ship.catalogue.playerFlyable && !ship.catalogue.normalPurchaseEligible
      && ship.catalogue.roleWeights.isEmpty && ship.catalogue.galaxies.isEmpty
      && ship.catalogue.regions.isEmpty && (ship.catalogue.aliases ?? []).isEmpty
      && text("original.geometry_sha256") == entry.sourceSHA256
      && text("r3.sha256") == entry.r3SHA256
      && text("physical.unit_scale_exact") == entry.metresPerSourceUnit
  }
}

extension Game {
  /// Check every claim before broadphase exclusions, physics or flight clocks.
  @inline(never)
  func requireQualifiedOriginalHullClaims() throws {
    try OriginalDetailedHullStage.requireRuntime(nativeQueryStoredShipID())
    try bodies.withUnsafeBufferPointer { stored in
      for index in stored.indices {
        try requireQualifiedOriginalHullClaim(stored.baseAddress!.advanced(by: index).pointee)
      }
    }
  }

  @inline(never)
  private func requireQualifiedOriginalHullClaim(_ body: borrowing SpaceBody) throws {
    if let id = body.nativeGeometryCatalogueID(),
      !currentOccupiedNewtPodHasCurrentCustody(body)
    {
      try OriginalDetailedHullStage.requireRuntime(id)
    }
    if let fit = body.scriptNPC?.fit {
      let definition = fit.definition
      let scoped = OriginalScopedScriptedHull.referenced(by: definition)
      if let scoped, !scoped.permits(fit) {
        try OriginalDetailedHullStage.requireRuntime(scoped.rawValue)
      }
      for reference in [definition.model] + (definition.components ?? []).map(\.model)
      where reference != scoped?.reference {
        try OriginalDetailedHullStage.requireRuntime(modelReference: reference)
      }
    }
  }
}
