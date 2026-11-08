import Foundation

extension ScriptPackLibrary {
  static func readNPCModels(_ manifest: ScriptManifest, directory: URL) throws
    -> (designs: [String: ShipDesign], bytes: [String: Data])
  {
    var designs: [String: ShipDesign] = [:]
    var resources: [String: Data] = [:]
    for declaration in manifest.models ?? [] {
      let bytes = try readFile(declaration.path, in: directory)
      guard hash(bytes) == declaration.sha256 else {
        throw MissionPackError("NPC model content does not match its declared SHA-256.")
      }
      let design = try JSONDecoder().decode(ShipDesign.self, from: bytes)
      guard scriptGeometryValid(design), design.source == declaration.source,
        design.license == declaration.license
      else { throw MissionPackError("Invalid NPC model geometry or provenance.") }
      designs["asset:" + declaration.id] = design
      resources[declaration.path] = bytes
    }
    let references = Set(
      (manifest.npcs ?? []).flatMap {
        [$0.model] + ($0.components ?? []).map(\.model)
      })
    for reference in references where reference.hasPrefix("catalogue:") {
      designs[reference] = try currentCatalogueNPCDesign(String(reference.dropFirst(10)))
    }
    guard references.isSubset(of: Set(designs.keys)) else {
      throw MissionPackError("Declare every NPC component model before using it.")
    }
    return (designs, resources)
  }

  /// The content-addressed mission model retains the same physical native hull as other actors.
  /// Environment objects retain their separate model owners; this grants no mission population.
  static func currentCatalogueNPCDesign(_ id: String) throws -> ShipDesign {
    if id == OriginalCryostasisCapsule.id, let source = OriginalCryostasisCapsule.source {
      return source.collisionDesign
    }
    if let design = OriginalScopedScriptedHull(rawValue: id)?.design {
      return design
    }
    try OriginalDetailedHullStage.requireRuntime(id)
    guard let ship = ShipCatalogue.ship(id) else {
      throw MissionPackError("The NPC catalogue source is unavailable.")
    }
    let design: ShipDesign
    if OriginalFleetR3Data.contract(for: id)?.objectKind == .ship {
      guard let source = OriginalFleetRuntimeHullSource.source(for: id),
        let native = ship.nativeDesign, source.mesh.faces == native.faces,
        source.mesh.details == (native.details ?? []),
        source.mesh.materials == (native.materials ?? []),
        source.mesh.faceMaterials == (native.faceMaterials ?? []),
        source.mesh.faceTextures == native.rawMesh.faceTextures
      else { throw MissionPackError("The current native NPC hull is not qualified.") }
      design = ShipDesign(
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
    } else {
      design = ship.design
    }
    guard scriptGeometryValid(design) else {
      throw MissionPackError("The NPC catalogue geometry is unavailable or too large.")
    }
    return design
  }

  static func scriptGeometryValid(_ design: ShipDesign) -> Bool {
    design.vertices.count <= 4096 && design.faces.count <= 8192
      && design.faces.allSatisfy { $0.count <= 64 }
      && (design.details?.count ?? 0) <= 8192 && (design.materials?.count ?? 0) <= 256
      && design.vertices.allSatisfy { $0.allSatisfy { abs($0) <= 100_000 } }
      && !design.source.isEmpty && !design.license.isEmpty && design.valid
  }
  static func canonicalGeometry(_ design: ShipDesign) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(design)
  }
}

extension Game {
  mutating func makeScriptNPC(_ definition: ScriptNPCDefinition, pack: ScriptPack, identity: UUID)
    throws
    -> ScriptNPCState
  {
    let scoped = OriginalScopedScriptedHull.referenced(by: definition)
    if let scoped {
      let fit = ScriptNPCFit(definition: definition, models: [scoped.reference: scoped.geometrySHA256])
      guard scoped.permits(pack), scoped.permits(fit), pack.manifest.npcs?.contains(definition) == true
      else { throw MissionPackError("The pending hull is restricted to its original mission roles.") }
    }
    for reference in [definition.model] + (definition.components ?? []).map(\.model)
    where reference != scoped?.reference {
      try OriginalDetailedHullStage.requireRuntime(modelReference: reference)
    }
    var hashes: [String: String] = [:]
    for reference in Set([definition.model] + (definition.components ?? []).map(\.model)) {
      guard let design = pack.models[reference] else {
        throw MissionPackError("The exact NPC model is unavailable.")
      }
      let digest = ScriptPackLibrary.hash(try ScriptPackLibrary.canonicalGeometry(design))
      hashes[reference] = digest
      commander.scriptState.geometry[digest] = design
    }
    let components = Dictionary(
      uniqueKeysWithValues: (definition.components ?? []).map {
        (
          $0.id,
          ScriptNPCComponentState(
            identity: ScriptIdentity.uuid("script-component-v2:\(identity):\($0.id)"),
            energy: $0.energy,
            guns: Dictionary(
              uniqueKeysWithValues: ($0.weapons ?? []).map {
                ($0.id, ScriptNPCGunState())
              }))
        )
      })
    return ScriptNPCState(
      fit: .init(definition: definition, models: hashes), fuel: definition.fuel,
      guns: Dictionary(
        uniqueKeysWithValues: (definition.lasers ?? []).map {
          ($0.id, ScriptNPCGunState())
        }), components: components)
  }
  func scriptModel(_ reference: String, fit: ScriptNPCFit) -> Mesh? {
    guard let hash = fit.models[reference], let design = nativeQueryStoredDesign(hash) else {
      return nil
    }
    if reference == OriginalCryostasisCapsule.reference {
      guard let source = OriginalCryostasisCapsule.source, hash == source.collisionSHA256,
        design == source.collisionDesign
      else { return nil }
    }
    if let scoped = OriginalScopedScriptedHull(reference: reference) {
      guard scoped.permits(fit), design == scoped.design
      else { return nil }
    }
    return design.rawMesh
  }
  func scriptModelRadius(_ reference: String, fit: ScriptNPCFit, scale: Double) -> Double {
    (scriptModel(reference, fit: fit)?.vertices.map(\.length).max() ?? 0) * scale
  }
  func scriptNPCRadius(_ body: SpaceBody) -> Double {
    guard let npc = body.scriptNPC else {
      return gameplayMesh(for: body).vertices.map(\.length).max() ?? .infinity
    }
    let definition = npc.fit.definition
    var radius = scriptModelRadius(definition.model, fit: npc.fit, scale: definition.scale)
    for component in definition.components ?? [] where component.solid {
      guard (npc.components[component.id]?.energy ?? 0) > 0 else { continue }
      radius = max(
        radius,
        (component.position.length
          + scriptModelRadius(component.model, fit: npc.fit, scale: component.scale))
          * definition.scale)
    }
    return radius
  }
}
