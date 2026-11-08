import Foundation
import TOMLDecoder

public struct ShipSpec: Codable, Sendable, Equatable {
  public let key: String
  public let label: String
  public let text: String
  public let number: Double?
  public let unit: String
  public let status: String
  public let basis: String
}
public struct ShipProfile: Codable, Sendable, Equatable {
  public let id: String
  public let title: String
  public let group: String
  public let context: String
  public let fields: [ShipSpec]
}
public struct CatalogueShip: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String
  public let shipClass: String
  public let appearances: String
  public let evidence: String
  public let refit: Bool
  public let model: String?
  public let modelSource: String?
  public let dimensions: [Double]?
  public let geometryContext: String
  public let profiles: [ShipProfile]
  public let game: ShipPerformance?
  public let catalogue: ShipCatalogueMetadata
  public let design: ShipDesign
  public let nativeHull: Hull?
  public let nativeDesign: ShipDesign?
  public let nativeCombat: NativeCombat?
  var nativeDocking: NativeStationGeometry.Port? = nil
  public var originalDefinition: OriginalFleetDefinition? {
    ShipCatalogue.originalDefinition(for: id)
  }
  var sourceProfilesIncludingOriginal: [ShipProfile] {
    guard let original = ShipCatalogue.originalSourceProfile(for: id) else { return profiles }
    return profiles + [original]
  }
  public var searchText: String {
    var terms = [id, name, shipClass, appearances, evidence] + (catalogue.aliases ?? [])
    if let original = originalDefinition {
      terms += [original.name, original.family, original.role, original.purchasePolicy]
    }
    return terms.joined(separator: " ")
  }
  public var previewMesh: Mesh? { ShipCatalogue.meshes[id] }
  public var availability: String {
    if OriginalDetailedHullStage.blocksRuntime(id) {
      return "Original hull pending; unavailable for flight or purchase"
    }
    return game == nil ? "Display object; not a flyable ship" : "Available for exchange at a main station"
  }
}
public struct ShipDesign: Codable, Sendable, Equatable {
  public let vertices: [[Double]]
  public let faces: [[Int]]
  public let license: String
  public let source: String
  public let details: [MeshDetail]?
  public let materials: [ShipMaterial]?
  public let faceMaterials: [Int]?
  public let paletteName: String?
  public let appearanceSource: String?
  public let appearanceLicense: String?
  public let appearanceBasis: String?
  public let sourceFaceColours: [[Double]]?
  public let sourceTextures: [ShipSourceTexture]?
  public let sourceFaceTextures: [ShipSourceFaceTexture]?
  public let resolvedTextures: [ShipResolvedTexture]?
  public let textures: [OriginalShipTextureReference]?
  public let faceTextures: [ShipSourceFaceTexture]?

  public init(
    vertices: [[Double]], faces: [[Int]], license: String, source: String,
    details: [MeshDetail]? = nil, materials: [ShipMaterial]? = nil, faceMaterials: [Int]? = nil,
    paletteName: String? = nil, appearanceSource: String? = nil, appearanceLicense: String? = nil,
    appearanceBasis: String? = nil, sourceFaceColours: [[Double]]? = nil,
    sourceTextures: [ShipSourceTexture]? = nil, sourceFaceTextures: [ShipSourceFaceTexture]? = nil,
    resolvedTextures: [ShipResolvedTexture]? = nil,
    textures: [OriginalShipTextureReference]? = nil, faceTextures: [ShipSourceFaceTexture]? = nil
  ) {
    self.vertices = vertices
    self.faces = faces
    self.license = license
    self.source = source
    self.details = details
    self.materials = materials
    self.faceMaterials = faceMaterials
    self.paletteName = paletteName
    self.appearanceSource = appearanceSource
    self.appearanceLicense = appearanceLicense
    self.appearanceBasis = appearanceBasis
    self.sourceFaceColours = sourceFaceColours
    self.sourceTextures = sourceTextures
    self.sourceFaceTextures = sourceFaceTextures
    self.resolvedTextures = resolvedTextures
    self.textures = textures
    self.faceTextures = faceTextures
  }
  var valid: Bool {
    guard vertices.count >= 4, faces.count >= 4,
      vertices.allSatisfy({ $0.count == 3 && $0.allSatisfy(\.isFinite) }),
      vertices.contains(where: { $0.contains(where: { $0 != 0 }) })
    else { return false }
    let indicesValid = faces.allSatisfy {
      $0.count >= 3 && $0.allSatisfy { vertices.indices.contains($0) }
    }
    let palette = materials ?? []
    let assignments = faceMaterials ?? []
    let materialsValid =
      palette.isEmpty
      ? assignments.isEmpty
      : assignments.count == faces.count
        && assignments.allSatisfy { palette.indices.contains($0) }
        && palette.allSatisfy { material in
          guard !material.name.isEmpty && material.colour & 255 == 255 else { return false }
          guard let opacity = material.opticalOpacity else { return true }
          return opacity > 0 && opacity < 1
        }
    guard indicesValid, materialsValid, sourceAppearanceValid, originalAppearanceValid,
      (details ?? []).allSatisfy({
        vertices.indices.contains($0.start) && vertices.indices.contains($0.end)
          && faces.indices.contains($0.face)
      })
    else { return false }
    if palette.contains(where: { $0.opticalOpacity != nil }) {
      for mappings in [faceTextures, sourceFaceTextures].compactMap({ $0 }) where !mappings.isEmpty {
        for (index, mapping) in mappings.enumerated() where mapping.texture != -1 {
          guard palette[assignments[index]].opticalOpacity == nil else { return false }
        }
      }
    }
    return faces.filter { face in
      let p = face.prefix(3).map { Vector3(vertices[$0][0], vertices[$0][1], vertices[$0][2]) }
      return (p[1] - p[0]).cross(p[2] - p[0]).length > 0.000001
    }.count >= 4
  }

  var rawMesh: Mesh {
    if resolvedTextures?.isEmpty == false { ShipTextureAssets.preload() }
    if textures?.isEmpty == false { OriginalShipTextureAssets.preload() }
    return Mesh(
      vertices: vertices.map { Vector3($0[0], $0[1], $0[2]) }, faces: faces,
      details: details ?? [], materials: materials ?? [], faceMaterials: faceMaterials ?? [],
      faceTextures: resolvedFaceTextures, preserveWinding: true)
  }
  var mesh: Mesh { rawMesh.showroomNormalised }
}
public enum ShipFileError: Error {
  case missingFolder
  case invalid(String)
  case duplicate(String)
}
public enum ShipCatalogue {
  public static let all: [CatalogueShip] = {
    do { return try load(from: folder) } catch {
      preconditionFailure("Invalid packaged ship definitions: \(error)")
    }
  }()
  static let meshes = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0.design.mesh) })
  private static let nativeRecords = Dictionary(
    uniqueKeysWithValues: all.compactMap { ship in ship.nativeHull.map { ($0, ship) } })
  private static let nativeMeshes: [Hull: Mesh] = nativeRecords.mapValues { ship in
    if let design = ship.nativeDesign { return design.rawMesh }
    let mesh = ship.design.mesh
    return Mesh(
      vertices: mesh.vertices.map { $0 * 0.69 }, faces: mesh.faces, details: mesh.details,
      materials: mesh.materials, faceMaterials: mesh.faceMaterials, faceTextures: mesh.faceTextures,
      preserveWinding: true)
  }
  public static func nativeShip(_ hull: Hull) -> CatalogueShip? { nativeRecords[hull] }
  static func nativeMesh(_ hull: Hull) -> Mesh? { nativeMeshes[hull] }
  private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
  public static func ship(_ id: String) -> CatalogueShip? { byID[id] }
  static func containsShip(_ id: String) -> Bool { byID.index(forKey: id) != nil }
  /// The authored source join never falls back to the current native performance table.
  public static func originalDefinition(for id: String) -> OriginalFleetDefinition? {
    OriginalFleetDefinitionData.definition(for: id)
  }
  static func originalSourceProfile(for id: String) -> ShipProfile? {
    OriginalFleetDefinitionData.definition(for: id)?.sourceProfile
  }
  public static var modelCount: Int { all.count }
  private static let resources: Bundle =
    Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
    } ?? Bundle.module
  public static var folder: URL { resources.resourceURL!.appendingPathComponent("Ships") }
  public static func load(from directory: URL) throws -> [CatalogueShip] {
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: nil
    )
    .filter { $0.pathExtension == "toml" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard !files.isEmpty else { throw ShipFileError.missingFolder }
    var ids = Set<String>()
    var nativeKinds = Set<Hull>()
    return try files.map { url in
      let bytes = try Data(contentsOf: url)
      let ship = try TOMLDecoder().decode(CatalogueShip.self, from: bytes)
      // The save discriminator is still used by role-bound actors. It owns no native mesh.
      guard ship.nativeHull != .cobra else {
        throw ShipFileError.invalid("Retired native hull: cobra")
      }
      try OriginalDetailedHullStage.authenticate(ship, bytes: bytes)
      try OriginalPlayerHullActivation.authenticateBaseline(ship, bytes: bytes)
      if ["SH005", "SH006"].contains(ship.id) {
        let expectedName = ship.id == "SH005" ? "Bison" : "Bison Mk II"
        guard ship.name == expectedName, ship.catalogue.family == "bison",
          let native = ship.nativeDesign, native.valid
        else { throw ShipFileError.invalid(url.lastPathComponent) }
      }
      if ["SH013", "SH014"].contains(ship.id) {
        let expectedName = ship.id == "SH013" ? "Buffalo" : "Buffalo Mk II"
        guard ship.name == expectedName, ship.catalogue.family == "buffalo",
          let native = ship.nativeDesign, native.valid
        else { throw ShipFileError.invalid(url.lastPathComponent) }
      }
      if ship.id == "SH025" {
        guard let contract = OriginalFleetR3Data.contract(for: ship.id),
          ship.name == contract.name, ship.catalogue.family == contract.family,
          ship.game == contract.performance,
          let accommodation = try? ShipAccommodationProfile(ship: ship),
          accommodation.equipmentUnits == contract.fitting?.equipmentUnits,
          accommodation.operatingCrew == contract.accommodation?.operatingCrew
        else { throw ShipFileError.invalid(url.lastPathComponent) }
      }
      if ship.id == "SH026" {
        guard ship.name == "Harrier", ship.catalogue.family == "harrier",
          let native = ship.nativeDesign, native.valid
        else { throw ShipFileError.invalid(url.lastPathComponent) }
      }
      if let site = OriginalStationSite.allCases.first(where: { $0.catalogueID == ship.id }) {
        guard site.nativeGeometry(from: ship) != nil,
          let physical = OriginalStationPhysical.read(from: ship), physical.blueprintID == ship.id,
          ship.catalogue.damagePolicy == .destructible
        else { throw ShipFileError.invalid(url.lastPathComponent) }
      }
      if ship.id == "SH028" {
        guard ship.name == "Lion Citadel", ship.catalogue.family == "lion-citadel",
          ship.nativeHull == .station, let native = ship.nativeDesign, native.valid,
          let port = ship.nativeDocking, port.valid
        else { throw ShipFileError.invalid(url.lastPathComponent) }
      }
      guard ship.id == url.deletingPathExtension().lastPathComponent,
        ship.id.range(of: "^SH[0-9]{3}$", options: .regularExpression) != nil,
        !ship.name.isEmpty, ship.design.valid,
        (ship.game?.valid(purchasePolicy: ship.catalogue.purchasePolicy) ?? true)
          || OriginalDetailedHullStage.hasPendingCapsuleStatistics(ship),
        ship.nativeDesign?.valid ?? true, ship.nativeCombat?.valid ?? true,
        ship.catalogue.valid(
          shipID: ship.id, performance: ship.game, nativeCombat: ship.nativeCombat),
        (ship.id == OriginalImpalaVoyagerActivation.id
          ? OriginalImpalaVoyagerActivation.validEffectiveCargo(ship)
          : ship.catalogue.validEffectiveCargo(performance: ship.game, profiles: ship.profiles))
      else { throw ShipFileError.invalid(url.lastPathComponent) }
      let resolved: CatalogueShip
      if OriginalBisonActivation.contains(ship.id) {
        do {
          resolved = try OriginalBisonActivation.resolve(
            ship, resourceSHA256: ScriptPackLibrary.hash(bytes))
        } catch {
          throw ShipFileError.invalid(url.lastPathComponent)
        }
      } else {
        resolved = try OriginalPlayerHullActivation.resolve(ship)
      }
      if let hull = ship.nativeHull, !nativeKinds.insert(hull).inserted {
        throw ShipFileError.invalid("Duplicate native hull: " + hull.rawValue)
      }
      guard ids.insert(ship.id).inserted else { throw ShipFileError.duplicate(ship.id) }
      return resolved
    }
  }
}
public struct ShipComparisonRow: Sendable {
  public let label: String
  public let baseline: String
  public let selected: String
  public let difference: String
  public var rating: ComparisonRating = .unavailable
  public static func difference(_ left: ShipSpec?, _ right: ShipSpec?, comparable: Bool) -> String {
    guard comparable, let left, let right, left.unit == right.unit,
      let a = left.number, let b = right.number
    else { return "" }
    let delta = b - a
    let estimate = [left.status, right.status].contains {
      $0.localizedCaseInsensitiveContains("estimated")
    }
    return String(format: "Diff %+.3g", delta) + (left.unit.isEmpty ? "" : " " + left.unit)
      + (estimate ? " (estimated)" : "")
  }
}
