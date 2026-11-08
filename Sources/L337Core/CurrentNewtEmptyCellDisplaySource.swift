import Foundation

/// Exact display-only derivative of the authenticated current Newt. Actual
/// custody decides whether its selected person is physically present. This
/// cache creates no person, empty actor, catalogue alias or admission permission.
enum CurrentNewtEmptyCellDisplaySource {
  static let resourceSHA256 = "510a2059ce49a7d902c11ca65303264afa8ee103cd1a9e9ad823dbe05fee816c"
  static let removedFigureVertices = 104..<240
  static let removedFigureFaces = 179..<391

  static let emptyDisplayMesh: Mesh? = {
    let file = OriginalFleetPhysicalData.folder.deletingLastPathComponent()
      .appendingPathComponent("Ships/SH040.toml")
    guard let facts = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
      facts.isRegularFile == true, facts.isSymbolicLink != true, facts.fileSize == 27_799,
      let bytes = try? Data(contentsOf: file), bytes.count == 27_799,
      ScriptPackLibrary.hash(bytes) == resourceSHA256,
      let source = OriginalCryostasisCapsule.source,
      source.collisionSHA256 == "be0d091a6bbf5f1af265eae4b94381fe0f049b8c4593005378b45b791f1b7461"
    else { return nil }
    let display = source.displayMesh
    guard display.vertices.count == 256, display.faces.count == 415,
      display.faceMaterials.count == 415, display.materials.count == 8,
      display.details.isEmpty, let enclosure = display.opticalEnclosure,
      display.faceTextures.isEmpty || display.faceTextures.count == 415
    else { return nil }
    let keptVertices = display.vertices.indices.filter { !removedFigureVertices.contains($0) }
    let keptFaces = display.faces.indices.filter { !removedFigureFaces.contains($0) }
    var remap = Array(repeating: -1, count: display.vertices.count)
    for (new, old) in keptVertices.enumerated() { remap[old] = new }
    guard removedFigureFaces.allSatisfy({ index in
      (4..<8).contains(display.faceMaterials[index])
        && display.faces[index].allSatisfy(removedFigureVertices.contains)
    }), keptFaces.allSatisfy({ index in
      (0..<4).contains(display.faceMaterials[index])
        && display.faces[index].allSatisfy { remap[$0] >= 0 }
    }) else { return nil }
    var mesh = Mesh(vertices: keptVertices.map { display.vertices[$0] },
      faces: keptFaces.map { index in display.faces[index].map { remap[$0] } },
      materials: Array(display.materials.prefix(4)),
      faceMaterials: keptFaces.map { display.faceMaterials[$0] },
      faceTextures: display.faceTextures.isEmpty ? [] : keptFaces.map { display.faceTextures[$0] },
      preserveWinding: true)
    mesh.opticalEnclosure = enclosure
    return mesh
  }()
}
