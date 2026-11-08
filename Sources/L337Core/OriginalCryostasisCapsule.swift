import Foundation

/// The calibrated shell is authoritative for scripted geometry. The decorative
/// interior is joined only for display and never enters the saved geometry map.
enum OriginalCryostasisCapsule {
  static let id = "SH040"
  static let reference = "catalogue:SH040"

  static func isReferenced(by fit: ScriptNPCFit) -> Bool {
    fit.definition.model == reference
      || (fit.definition.components ?? []).contains { $0.model == reference }
  }

  struct Source: Sendable {
    let collisionDesign: ShipDesign
    let collisionSHA256: String
    let displayMesh: Mesh
  }

  static let source: Source? = load()

  @inline(never)
  private static func load() -> Source? {
    guard let ship = ShipCatalogue.ship(id), ship.catalogue.objectKind == .capsule,
      let physical = ship.physicalSourceContract else { return nil }
    return validatedSource(ship: ship, physical: physical)
  }

  @inline(never)
  private static func validatedSource(ship: CatalogueShip, physical: OriginalHullPhysicalContract) -> Source? {
    guard let record = physical.engineering,
      let shell = ship.nativeDesign, shell == physical.model.nativeDesign,
      physical.nativeTriangles == 92, physical.metresPerSourceUnit == 60.0 / 19.0,
      abs(physical.envelope.dimensions.z - 2.4) < 1e-12, record.dryMassKilograms == 248,
      record.detailedSourceSHA256 == physical.model.sourceSHA256,
      ship.design.vertices.count == 256, ship.design.faces.count == 415,
      Array(ship.design.vertices.prefix(shell.vertices.count)) == shell.vertices,
      ship.design.faces[38] == [14, 15, 27, 26],
      let materials = ship.design.materials, let assignments = ship.design.faceMaterials,
      materials.indices.contains(3), assignments[38] == 3, materials[3].opticalOpacity == 0.25,
      assignments.indices.filter({ materials[assignments[$0]].opticalOpacity != nil }) == [38],
      ship.design.faces.reduce(0, { $0 + $1.count - 2 }) == 416
    else { return nil }
    let collision = ShipDesign(
      vertices: physical.physicalMesh.vertices.map { [$0.x, $0.y, $0.z] },
      faces: shell.faces, license: shell.license, source: "Calibrated cryostasis shell " + physical.model.sourceSHA256,
      details: shell.details, materials: shell.materials, faceMaterials: shell.faceMaterials,
      paletteName: shell.paletteName, appearanceSource: shell.appearanceSource,
      appearanceLicense: shell.appearanceLicense, appearanceBasis: shell.appearanceBasis)
    guard ScriptPackLibrary.scriptGeometryValid(collision),
      let bytes = try? ScriptPackLibrary.canonicalGeometry(collision)
    else { return nil }
    let visual = ship.design.rawMesh
    var display = Mesh(
      vertices: visual.vertices.map { $0 * physical.metresPerSourceUnit },
      faces: visual.faces, details: visual.details, materials: visual.materials,
      faceMaterials: visual.faceMaterials, faceTextures: visual.faceTextures, preserveWinding: true)
    display.opticalEnclosure = .init(paneFace: 38, firstInteriorFace: 91)
    return .init(collisionDesign: collision, collisionSHA256: ScriptPackLibrary.hash(bytes), displayMesh: display)
  }
}
