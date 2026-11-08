/// The same original SH028 record supplies native rendering, collision and its real port.
enum MainStationGeometry {
  private static let original: CatalogueShip = {
    guard let ship = ShipCatalogue.ship("SH028"), ship.name == "Lion Citadel",
      ship.catalogue.family == "lion-citadel", ship.nativeHull == .station,
      let native = ship.nativeDesign, native.valid,
      let port = ship.nativeDocking, port.valid
    else { preconditionFailure("Original SH028 station geometry and docking port are required.") }
    return ship
  }()

  static let docking = original.nativeDocking!
  static let mesh = original.nativeDesign!.rawMesh
}
