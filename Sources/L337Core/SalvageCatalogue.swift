import Foundation

public enum SalvageHullRole: String, Codable, Sendable {
  case capitalWarship, carrier, alienCapital, deepSpaceCruiser, bulkFreighter
  case largeLiner, largeExplorer, largeCombatShip, largeTransport, largeEncounterShip,
    abandonedInfrastructure, disabledOrdinaryShip
}

public enum SalvageSectionKind: String, Codable, Sendable, CaseIterable {
  case hull, cargo, computer, drive, weapons, shields, missiles, hardpoints, escapePods
}

public enum SalvageEligibility: String, Codable, Sendable {
  case allowed, unsupportedHull, claimed, occupied, activeStation, missionProtected
}

public struct SalvageSectionProfile: Equatable, Codable, Sendable {
  public let index: UInt16
  public let kind: SalvageSectionKind
  public let localPosition: Vector3
  public let normal: Vector3
  public let radius: Double
  public let workSeconds: Double
  public let structural: Bool
  public let technologyDefinitionIDs: [String]
  /// Index into the actual catalogue mesh, not a surrogate box or native Hull mesh.
  public let sourceFaceIndex: Int
}

public struct SalvageProfile: Sendable {
  public let catalogueShipID: String
  public let name: String
  public let role: SalvageHullRole
  public let basis: String
  public let sourceRoles: Set<SalvageSourceRole>
  /// Project native-unit scale; source geometry does not establish metres or mass.
  public let physicalScale: Double
  public let bounds: SalvageBounds
  public let minimum: Vector3
  public let maximum: Vector3
  public let sections: [SalvageSectionProfile]
  public let mesh: Mesh

  public func surfaces(wreck: WreckIdentity) -> [SalvageWorkSurface] {
    sections.map {
      .init(
        section: .init(wreck: wreck, section: $0.index), position: $0.localPosition,
        normal: $0.normal, radius: $0.radius)
    }
  }
}

/// Explicit project classifications, reviewed against catalogue roles and source/refit records.
/// These profiles describe abandoned variants, never permission to cut an active counterpart.
public enum SalvageCatalogue {
  private struct Entry: Sendable {
    let id: String
    let role: SalvageHullRole
    let basis: String
  }
  private static let entries: [Entry] = [
    .init(
      id: "SH005", role: .bulkFreighter,
      basis: "Bison: original container-hauler hull; abandoned bulk-freighter variant."),
    .init(
      id: "SH006", role: .bulkFreighter,
      basis:
        "Bison Mk II: original heavy container-hauler hull; abandoned bulk-freighter variant."
    ),
    .init(
      id: "SH012", role: .largeLiner,
      basis: "Sable Liner: current original liner geometry; existing separately abandoned variant only."),
    .init(id: "SH013", role: .bulkFreighter, basis: "Buffalo: original cargo-drum freighter; abandoned bulk-freighter variant."),
    .init(
      id: "SH014", role: .bulkFreighter,
      basis: "Buffalo Mk II: original enlarged cargo-drum freighter; abandoned bulk-freighter variant."),
    .init(
      id: "SH019", role: .largeExplorer,
      basis: "Gazelle Explorer: current original explorer geometry; existing separately abandoned variant only."),
    .init(
      id: "SH028", role: .abandonedInfrastructure,
      basis: "Lion Citadel: existing separately abandoned site variant only; active main station excluded."),
    .init(
      id: "SH034", role: .abandonedInfrastructure,
      basis: "Frog Station: existing separately abandoned site variant only; active main station excluded."),
    .init(
      id: "SH102", role: .abandonedInfrastructure,
      basis: "Dhole Haven: existing separately abandoned rock-hermit installation only; occupied station excluded."),
    .init(
      id: "SH141", role: .abandonedInfrastructure,
      basis:
        "Salamander Station: current original geometry; existing separately abandoned site variant only; active station excluded."
    ),
  ]

  public static let all: [SalvageProfile] = entries.compactMap(makeProfile)

  private static let disabledProfiles: [String: SalvageProfile] = Dictionary(
    uniqueKeysWithValues: ShipCatalogue.all.compactMap { ship in
      guard !OriginalDetailedHullStage.blocksRuntime(ship.id), ship.game != nil,
        !all.contains(where: { $0.catalogueShipID == ship.id }),
        let profile = makeProfile(
          .init(
            id: ship.id, role: .disabledOrdinaryShip,
            basis:
              "Project EMP unoccupied hull: actual catalogue mesh; no occupied cutting permission.")
        )
      else { return nil }
      return (ship.id, profile)
    })
  public static func profile(catalogueShipID: String) -> SalvageProfile? {
    all.first { $0.catalogueShipID == catalogueShipID }
  }
  static func empProfile(catalogueShipID: String) -> SalvageProfile? {
    guard !OriginalDetailedHullStage.blocksRuntime(catalogueShipID) else { return nil }
    return profile(catalogueShipID: catalogueShipID) ?? disabledProfiles[catalogueShipID]
  }

  public static func eligibility(
    catalogueShipID: String, ownership: SalvageOwnership,
    activeStation: Bool = false, missionProtected: Bool = false
  ) -> SalvageEligibility {
    if missionProtected || ownership == .missionProtected { return .missionProtected }
    if activeStation { return .activeStation }
    guard profile(catalogueShipID: catalogueShipID) != nil else { return .unsupportedHull }
    switch ownership {
    case .abandoned: return .allowed
    case .claimed: return .claimed
    case .occupied: return .occupied
    case .missionProtected: return .missionProtected
    }
  }

  private struct Face {
    let index: Int
    let center: Vector3
    let normal: Vector3
    let radius: Double
  }

  private static func makeProfile(_ entry: Entry) -> SalvageProfile? {
    guard !OriginalDetailedHullStage.blocksRuntime(entry.id),
      let ship = ShipCatalogue.all.first(where: { $0.id == entry.id }) else { return nil }
    // previewMesh is showroom-normalised; native wreck geometry must use authoritative raw vertices.
    let mesh: Mesh
    if OriginalPlayerHullActivation.resourceSHA256[entry.id] != nil
      || OriginalFleetPhysicalData.registrations[entry.id] != nil
    {
      guard let physical = ship.physicalSourceContract else { return nil }
      mesh = physical.physicalMesh
    } else if entry.id == "SH005" || entry.id == "SH006"
      || entry.id == "SH013" || entry.id == "SH014" || entry.id == "SH026"
    {
      // Read the owned design directly: the raw cache also consumes salvage profiles.
      guard let native = ship.nativeDesign else { return nil }
      mesh = native.rawMesh
    } else if entry.role == .disabledOrdinaryShip, entry.id != "SH061",
      let retained = ShipCatalogue.rawMesh(entry.id)
    {
      mesh = retained
    } else {
      mesh = ship.design.rawMesh
    }
    guard !mesh.vertices.isEmpty else { return nil }
    let minimum = Vector3(
      mesh.vertices.map(\.x).min()!, mesh.vertices.map(\.y).min()!, mesh.vertices.map(\.z).min()!)
    let maximum = Vector3(
      mesh.vertices.map(\.x).max()!, mesh.vertices.map(\.y).max()!, mesh.vertices.map(\.z).max()!)
    let center = (minimum + maximum) * 0.5
    let radius = mesh.vertices.map { ($0 - center).length }.max()!
    let faces = mesh.faces.enumerated().compactMap { index, indices -> Face? in
      guard indices.count >= 3, indices.allSatisfy({ mesh.vertices.indices.contains($0) }) else {
        return nil
      }
      let first = mesh.vertices[indices[0]]
      let cross = (mesh.vertices[indices[1]] - first).cross(mesh.vertices[indices[2]] - first)
      guard cross.length > 1e-8 else { return nil }
      let midpoint =
        indices.reduce(Vector3(0, 0, 0)) { $0 + mesh.vertices[$1] } * (1 / Double(indices.count))
      return .init(
        index: index, center: midpoint, normal: cross * (1 / cross.length),
        radius: indices.map { (mesh.vertices[$0] - midpoint).length }.max()!)
    }
    let directions: [Vector3] = [
      .init(0, 1, 0), .init(0, -1, 0), .init(0, 0, 1),
      .init(0, 0, -1), .init(1, 0, 0), .init(-1, 0, 0), .init(1, 1, 0), .init(-1, 1, 0),
      .init(0, 1, 1),
    ]
    var used: Set<Int> = []
    var sections: [SalvageSectionProfile] = []
    for (index, kind) in SalvageSectionKind.allCases.enumerated() {
      let direction = directions[index].unit
      let available = faces.filter { !used.contains($0.index) }
      let facing = available.filter { $0.normal.dot(direction) > 0.2 }
      guard
        let face = (facing.isEmpty ? available : facing).max(by: {
          let a = ($0.center - center).dot(direction)
          let b = ($1.center - center).dot(direction)
          return a == b ? $0.index > $1.index : a < b
        })
      else { continue }
      used.insert(face.index)
      sections.append(
        .init(
          index: UInt16(index), kind: kind, localPosition: face.center,
          normal: face.normal, radius: face.radius, workSeconds: workSeconds(kind),
          structural: kind == .hull || kind == .cargo,
          technologyDefinitionIDs: technology(kind, alien: entry.role == .alienCapital),
          sourceFaceIndex: face.index))
    }
    guard radius.isFinite, radius > 0, !sections.isEmpty else { return nil }
    return .init(
      catalogueShipID: ship.id, name: ship.name, role: entry.role, basis: entry.basis,
      sourceRoles: sourceRoles(entry),
      physicalScale: 1, bounds: .init(center: center, radius: radius), minimum: minimum,
      maximum: maximum, sections: sections, mesh: mesh)
  }

  private static func sourceRoles(_ entry: Entry) -> Set<SalvageSourceRole> {
    // This existing rock-hermit site retains its separately owned source role.
    // New environment resources need their own actual salvage producer/ownership;
    // their catalogue IDs cannot inherit a predecessor's installation role.
    if entry.id == "SH102" { return [.rockHermit, .station] }
    switch entry.role {
    case .capitalWarship: return [.militaryCapital]
    case .alienCapital: return [.thargoid]
    case .carrier: return [.commercialCarrier]
    case .bulkFreighter, .largeLiner, .largeTransport: return [.commercialTrader]
    case .abandonedInfrastructure: return [.station]
    case .deepSpaceCruiser, .largeExplorer, .largeCombatShip, .largeEncounterShip,
      .disabledOrdinaryShip:
      // Initial project tuning: generic cargo/5% ship item, not a historical trader claim.
      return [.generalShip]
    }
  }

  private static func workSeconds(_ kind: SalvageSectionKind) -> Double {
    switch kind {
    case .hull: 12
    case .cargo: 16
    case .computer, .shields, .hardpoints: 24
    case .drive: 30
    case .weapons: 26
    case .missiles: 18
    case .escapePods: 16
    }
  }

  private static func technology(_ kind: SalvageSectionKind, alien: Bool) -> [String] {
    if alien { return kind == .hull ? [] : ["alien-artefact"] }
    switch kind {
    case .hull, .cargo: return []
    case .computer: return ["computer-core"]
    case .drive: return ["drive-technology"]
    case .weapons: return ["laser-technology"]
    case .shields: return ["shield-technology"]
    case .missiles:
      return ["missile-standard", "missile-guided", "missile-heavy", "missile-ecm-resistant"]
    case .hardpoints: return ["laser-hardpoint", "missile-pylon"]
    case .escapePods: return ["spare-escape-pod"]
    }
  }
}
