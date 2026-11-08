import Foundation

/// The Muskox remains pending as a ship. Its exact original native model is shared
/// by three authored passive mission packages at their existing one-fifth scale.
enum OriginalScriptedMuskox {
  static let id = "SH058"
  static let reference = "catalogue:SH058"
  static let geometrySHA256 = "cbd9b83b002e7318e3edc2210a6c4f7ce868524e9df962f0e61508508e824670"
  static let cradleGeometrySHA256 = "1969007aca56a6def7fe81927191d01b102e722d4be96a6503142d61db96d32d"

  static let design: ShipDesign? = {
    guard let ship = ShipCatalogue.ship(id), let native = ship.nativeDesign,
      let source = try? OriginalFleetCurrentHullSource(id: id),
      source.model.nativeDesign == native, source.nativeTriangles == 244,
      source.engineering.metresPerSourceUnit == 1
    else { return nil }
    let calibrated = ShipDesign(
      vertices: source.mesh.vertices.map { [$0.x, $0.y, $0.z] }, faces: native.faces,
      license: native.license,
      source: "Current calibrated native catalogue " + id + " / R3 "
        + source.contract.sourceSHA256 + ". " + native.source,
      details: native.details, materials: native.materials, faceMaterials: native.faceMaterials,
      paletteName: native.paletteName, appearanceSource: native.appearanceSource,
      appearanceLicense: native.appearanceLicense, appearanceBasis: native.appearanceBasis,
      sourceFaceColours: native.sourceFaceColours, sourceTextures: native.sourceTextures,
      sourceFaceTextures: native.sourceFaceTextures, resolvedTextures: native.resolvedTextures,
      textures: native.textures, faceTextures: native.faceTextures)
    guard ScriptPackLibrary.scriptGeometryValid(calibrated),
      let bytes = try? ScriptPackLibrary.canonicalGeometry(calibrated),
      ScriptPackLibrary.hash(bytes) == geometrySHA256
    else { return nil }
    return calibrated
  }()

  static func declaresPackage(_ definition: ScriptNPCDefinition) -> Bool {
    guard definition.model == reference, design != nil else { return false }
    return ["pell-return-package", "w05-flight-recorder", "induction-crew-custody-recorder"]
      .contains(definition.id)
  }

  static func permits(_ fit: ScriptNPCFit) -> Bool {
    guard design != nil, fit.models == [reference: geometrySHA256] else { return false }
    return NativeIdentifiedSalvage.npcValid(fit.definition, package: true)
      || WayfarerRecordRecovery.npcValid(fit.definition, package: true)
      || fit.definition == NativeInductionCrewLogSource.recorderProfile()
  }

  static func permits(_ pack: ScriptPack) -> Bool {
    guard let design, pack.models[reference] == design else { return false }
    switch pack.manifest.stateID {
    case NativeIdentifiedSalvage.stateID: return pack.digest == NativeIdentifiedSalvage.digest
    case WayfarerRecordRecovery.stateID: return pack.digest == WayfarerRecordRecovery.digest
    case NativeInductionCrewLogPack.stateID: return pack.digest == NativeInductionCrewLogPack.digest
    default: return false
    }
  }
}
