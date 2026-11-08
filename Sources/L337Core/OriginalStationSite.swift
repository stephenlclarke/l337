import Foundation

/// Explicit new site policy. Geometry and a candidate pose confer no admission or service receipt.
enum OriginalStationSite: String, CaseIterable, Codable, Sendable {
  case salamander = "SH141"
  case frog = "SH034"
  case dhole = "SH102"
  case remoteUtility = "SH102-REMOTE-UTILITY"

  var catalogueID: String { self == .remoteUtility ? "SH102" : rawValue }
  var system: SystemIdentity {
    .init(galaxy: 0, system: self == .remoteUtility ? 237 : 7)
  }
  static let sourceVersion = "original-station-sites-v1"

  var key: String {
    switch self {
    case .salamander: "avenor-sh141-service-site"
    case .frog: "avenor-sh034-service-site"
    case .dhole: "avenor-sh102-service-site"
    case .remoteUtility: "remote-utility-sh102-g0-s237"
    }
  }

  var name: String {
    switch self {
    case .salamander: "Salamander Station"
    case .frog: "Frog Station"
    case .dhole, .remoteUtility: "Dhole Haven"
    }
  }

  private var family: String {
    switch self {
    case .salamander: "salamander-station"
    case .frog: "frog"
    case .dhole, .remoteUtility: "dhole"
    }
  }

  private var offset: Vector3 {
    switch self {
    case .salamander: .init(6000, 0, 0)
    case .frog: .init(-6000, 0, 0)
    case .dhole: .init(0, 6000, 0)
    case .remoteUtility: .init(0, -6000, 0)
    }
  }

  var initialSpinRate: Double { 0 }
  var rechargeRate: Double { 0 }
  var sealedDispatchDefinition: ScriptCourierDefinition? {
    self == .remoteUtility ? nil : OriginalSealedDispatch.definition
  }

  func identity(world: UUID) -> NativeStationIdentity {
    .init(
      world: world, system: system,
      definition: "original-station-" + catalogueID.lowercased(),
      version: Self.sourceVersion, key: key)
  }

  static func site(for identity: NativeStationIdentity, owner: UUID) -> Self? {
    allCases.first { $0.identity(world: owner) == identity }
  }

  /// The ordinary full-scene admission checks must prove this fixed candidate is clear.
  func sourcePose(in anchors: SystemAnchors) -> ShipPose? {
    guard anchors.system == system, anchors.station.position.finite else { return nil }
    let position = anchors.station.position + offset
    guard position.finite, position.length.isFinite else { return nil }
    return .init(position: position, orientation: Basis3())
  }

  /// The packaged per-ID native mesh is already in metres; never use showroom normalisation.
  func nativeGeometry(from ship: borrowing CatalogueShip)
    -> (mesh: Mesh, port: NativeStationGeometry.Port)?
  {
    guard ship.id == catalogueID, ship.name == name, ship.catalogue.family == family,
      ship.catalogue.objectKind == .station, ship.nativeHull == nil,
      let design = ship.nativeDesign, design.valid,
      let port = ship.nativeDocking, port.valid
    else { return nil }
    return (design.rawMesh, port)
  }
}
