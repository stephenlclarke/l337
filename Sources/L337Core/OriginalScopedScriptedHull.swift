/// Exact-model exceptions for authored mission packs while ordinary hull admission is pending.
enum OriginalScopedScriptedHull: String, CaseIterable {
  case peregrine = "SH023"
  case muskox = "SH058"

  var reference: String { "catalogue:" + rawValue }

  init?(reference: String) {
    guard reference.hasPrefix("catalogue:") else { return nil }
    self.init(rawValue: String(reference.dropFirst(10)))
  }

  static func referenced(by definition: ScriptNPCDefinition) -> Self? {
    if let root = Self(reference: definition.model) { return root }
    return (definition.components ?? []).lazy.compactMap { Self(reference: $0.model) }.first
  }

  var design: ShipDesign? {
    switch self {
    case .peregrine: OriginalScriptedPeregrine.design
    case .muskox: OriginalScriptedMuskox.design
    }
  }

  var geometrySHA256: String {
    switch self {
    case .peregrine: OriginalScriptedPeregrine.geometrySHA256
    case .muskox: OriginalScriptedMuskox.geometrySHA256
    }
  }

  func declaresRole(_ definition: ScriptNPCDefinition) -> Bool {
    switch self {
    case .peregrine:
      return design != nil
        && (definition == OriginalCorridorDefence.npc || definition == OriginalVerifiedWarrant.npc)
    case .muskox:
      return OriginalScriptedMuskox.declaresPackage(definition)
    }
  }

  func permits(_ fit: ScriptNPCFit) -> Bool {
    switch self {
    case .peregrine:
      return declaresRole(fit.definition) && fit.models == [reference: geometrySHA256]
    case .muskox:
      return OriginalScriptedMuskox.permits(fit)
    }
  }

  func permits(_ pack: ScriptPack) -> Bool {
    switch self {
    case .peregrine:
      guard let design, pack.models[reference] == design else { return false }
      switch pack.manifest.stateID {
      case OriginalCorridorDefence.stateID: return pack.digest == OriginalCorridorDefence.digest
      case OriginalVerifiedWarrant.stateID: return pack.digest == OriginalVerifiedWarrant.digest
      default: return false
      }
    case .muskox:
      return OriginalScriptedMuskox.permits(pack)
    }
  }
}

enum OriginalScriptedPeregrine {
  static let geometrySHA256 = "761e9cc51de6ae313d764d6995bf923f42299eb12d81131ce7df2d7a512d6414"

  static let design: ShipDesign? = {
    let id = OriginalScopedScriptedHull.peregrine.rawValue
    guard let ship = ShipCatalogue.ship(id), let native = ship.nativeDesign,
      let source = try? OriginalFleetCurrentHullSource(id: id),
      source.model.nativeDesign == native, source.nativeTriangles == 512,
      source.engineering.metresPerSourceUnitExact == "250000/19057"
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
}
