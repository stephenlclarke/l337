extension ShipCatalogue {
  // Physical geometry stays in authored units; showroom meshes are normalized separately.
  private static let rawMeshesByID: [String: Mesh] = Dictionary(
    uniqueKeysWithValues: all.compactMap { ship -> (String, Mesh)? in
      guard !OriginalDetailedHullStage.blocksRuntime(ship.id) else { return nil }
      if ship.id == "SH005" || ship.id == "SH006" || ship.id == "SH007"
        || ship.id == "SH013" || ship.id == "SH014" || ship.id == "SH025" || ship.id == "SH026"
      {
        guard let native = ship.nativeDesign else {
          preconditionFailure("Original hull requires its authored native design")
        }
        return (ship.id, native.rawMesh)
      }
      if OriginalPlayerHullActivation.resourceSHA256[ship.id] != nil {
        guard let physical = ship.physicalSourceContract else {
          preconditionFailure("Current original baseline requires its pinned physical source")
        }
        return (ship.id, physical.physicalMesh)
      }
      if OriginalFleetPhysicalData.registrations[ship.id] != nil {
        guard let physical = ship.physicalSourceContract else {
          preconditionFailure("Current original hull requires its exact calibrated physical source")
        }
        return (ship.id, physical.physicalMesh)
      }
      // Reuse the authored geometry already retained by ordinary salvage profiles.
      if let profile = SalvageCatalogue.profile(catalogueShipID: ship.id) {
        return (ship.id, profile.mesh)
      }
      return (ship.id, ship.design.rawMesh)
    })

  static func rawMesh(_ id: String) -> Mesh? { rawMeshesByID[id] }
}
