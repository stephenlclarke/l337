import Foundation

/// Physical engineering for the two original rescue source hulls. This grants no actual
/// hull, source people, fitting, loaded inertia, docking port, service or launch permission.
enum NativeC03EvacuationHull {
  enum Role: CaseIterable, Sendable {
    case carrier, launch
    var fleetRole: NativeHollowManifestFleetSource.Role {
      self == .carrier ? .custodyCarrier : .evacuationLaunch
    }
  }

  struct Hull: Sendable {
    let source: NativeHollowManifestFleetSource.Profile
    let design: ShipDesign
    let geometry: String
  }

  private static let carrier = Result { try prepare(.carrier) }
  private static let launch = Result { try prepare(.launch) }

  static func resolve(_ role: Role) throws -> Hull {
    switch role {
    case .carrier: try carrier.get()
    case .launch: try launch.get()
    }
  }

  private static func prepare(_ role: Role) throws -> Hull {
    let source = try NativeHollowManifestFleetSource.resolve(role.fleetRole)
    // G4 owns this current native consumer. It performs calibration and preserves the full
    // native appearance/provenance; never substitute display geometry or a source-unit mesh.
    let design = try ScriptPackLibrary.currentCatalogueNPCDesign(source.current.id)
    let mesh = design.rawMesh
    let native = source.physical.model.nativeDesign
    guard source.current.objectKind == .ship,
      source.physical.id == role.fleetRole.id,
      source.physical.specificationSHA256 == source.current.sourceSHA256,
      source.physical.model.sourceSHA256 == source.current.referencedGeometrySHA256,
      mesh.vertices == source.physical.physicalMesh.vertices,
      mesh.faces == source.physical.physicalMesh.faces,
      !mesh.faces.isEmpty, mesh.faces.count <= 512,
      design.details == native.details, design.materials == native.materials,
      design.faceMaterials == native.faceMaterials,
      design.appearanceSource == native.appearanceSource,
      design.appearanceLicense == native.appearanceLicense,
      design.appearanceBasis == native.appearanceBasis,
      design.license == native.license,
      ScriptPackLibrary.scriptGeometryValid(design)
    else { throw OriginalHullPhysicalContract.Failure.unsupportedSource }
    return .init(
      source: source, design: design,
      geometry: ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design)))
  }
}
