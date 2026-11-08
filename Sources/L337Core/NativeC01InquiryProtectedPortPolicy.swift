/// Newly authored C01 placement exclusion DATA. This does not establish a
/// live provider, complete registry, route coverage or native clearance.
enum NativeC01InquiryProtectedPortPolicy {
  enum Source: Sendable, Equatable {
    case main
    case original(OriginalStationSite)
  }

  struct Volume: Sendable {
    let catalogueID: String
    let revision: String
    let sourcePort: NativeStationGeometry.Port
    let metresPerNativeUnit: Double
    let minimumPortFrame: Vector3
    let maximumPortFrame: Vector3
    let minimumStationFrame: Vector3
    let maximumStationFrame: Vector3
    let meshInStationFrame: Mesh

    fileprivate init(catalogueID: String, revision: String, sourcePort: NativeStationGeometry.Port,
      metresPerNativeUnit: Double, minimumPortFrame: Vector3, maximumPortFrame: Vector3,
      minimumStationFrame: Vector3, maximumStationFrame: Vector3, meshInStationFrame: Mesh)
    {
      self.catalogueID = catalogueID; self.revision = revision; self.sourcePort = sourcePort
      self.metresPerNativeUnit = metresPerNativeUnit
      self.minimumPortFrame = minimumPortFrame; self.maximumPortFrame = maximumPortFrame
      self.minimumStationFrame = minimumStationFrame; self.maximumStationFrame = maximumStationFrame
      self.meshInStationFrame = meshInStationFrame
    }
  }

  static let revision = "c01-protected-port-authoring-v1"
  private static let paddingMetres = 2000.0
  private static let outwardMetres = 10000.0

  /// These four source adapters already expose native meshes/ports in project
  /// metres. Their original authored asset scale must not be applied a second time.
  static func sourceVolume(for source: Source) -> Volume? {
    let id: String
    let port: NativeStationGeometry.Port
    switch source {
    case .main:
      guard let ship = ShipCatalogue.ship("SH028"), ship.name == "Lion Citadel",
        ship.catalogue.family == "lion-citadel", ship.nativeHull == .station,
        let design = ship.nativeDesign, design.valid,
        let actualPort = ship.nativeDocking, actualPort.valid,
        actualPort == MainStationGeometry.docking
      else { return nil }
      id = ship.id
      port = actualPort
    case .original(let site):
      guard ["SH034", "SH102", "SH141"].contains(site.catalogueID),
        let sources = try? NativeStationSource.requireBindings(),
        let actual = sources.first(where: { $0.site == site }),
        actual.physical.blueprintID == site.catalogueID
      else { return nil }
      id = actual.catalogueShipID
      port = actual.geometry.docking
    }
    // An explicit per-provider convention, not a universal world-unit claim.
    let metresPerNativeUnit = 1.0
    guard port.valid, port.outward == Vector3(0, 0, 1), port.up == Vector3(0, 1, 0),
      let minX = port.aperture.map(\.x).min(), let maxX = port.aperture.map(\.x).max(),
      let minY = port.aperture.map(\.y).min(), let maxY = port.aperture.map(\.y).max()
    else { return nil }
    let padding = paddingMetres / metresPerNativeUnit
    let lower = Vector3((minX - padding).nextDown, (minY - padding).nextDown,
      (-port.tunnelDepth).nextDown)
    let upper = Vector3((maxX + padding).nextUp, (maxY + padding).nextUp,
      (outwardMetres / metresPerNativeUnit).nextUp)
    // Source axes are exact +X/+Y/+Z here. Enclose the represented port-centre
    // additions too; later world transforms belong to the actual native query owner.
    let stationLower = Vector3((port.center.x + lower.x).nextDown,
      (port.center.y + lower.y).nextDown, (port.center.z + lower.z).nextDown)
    let stationUpper = Vector3((port.center.x + upper.x).nextUp,
      (port.center.y + upper.y).nextUp, (port.center.z + upper.z).nextUp)
    guard lower.finite, upper.finite, stationLower.finite, stationUpper.finite,
      stationLower.x < stationUpper.x, stationLower.y < stationUpper.y,
      stationLower.z < stationUpper.z
    else { return nil }
    let a = stationLower, b = stationUpper
    let vertices: [Vector3] = [
      .init(a.x, a.y, a.z), .init(b.x, a.y, a.z), .init(b.x, b.y, a.z), .init(a.x, b.y, a.z),
      .init(a.x, a.y, b.z), .init(b.x, a.y, b.z), .init(b.x, b.y, b.z), .init(a.x, b.y, b.z),
    ]
    let faces = [
      [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
      [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
    ]
    return Volume(catalogueID: id, revision: revision, sourcePort: port,
      metresPerNativeUnit: metresPerNativeUnit, minimumPortFrame: lower, maximumPortFrame: upper,
      minimumStationFrame: stationLower, maximumStationFrame: stationUpper,
      meshInStationFrame: Mesh(vertices: vertices, faces: faces, preserveWinding: true))
  }

  /// Construct DATA from an actual captured provider port. The caller must
  /// separately retain provider/source currentness and pay native hull preparation.
  static func prepareVolume(for source: Source, port: NativeStationGeometry.Port,
    work: inout NativeC01InquiryCurveGeometry.Work
  ) -> NativeC01InquiryPreparationWork.Outcome<Volume> {
    typealias P = NativeC01InquiryPreparationWork
    return P.perform(work: &work) { meter in
      try meter.records(1, .metadata)
      let id: String
      switch source {
      case .main: id = "SH028"
      case .original(let site): id = site.catalogueID
      }
      try validate(port, meter: meter)
      try meter.records(1, .metadata)
      guard port.outward == Vector3(0, 0, 1), port.up == Vector3(0, 1, 0)
      else { throw P.Failure.invalidSource }
      // One pass over actual aperture vertices; no unmetered maps/min scans.
      var minX = Double.infinity, maxX = -Double.infinity
      var minY = Double.infinity, maxY = -Double.infinity
      for index in port.aperture.indices {
        try meter.records(1, .metadata)
        let vertex = port.aperture[index]
        minX = min(minX, vertex.x); maxX = max(maxX, vertex.x)
        minY = min(minY, vertex.y); maxY = max(maxY, vertex.y)
      }
      // Four fixed vector constructions, bounds checks and source metadata.
      try meter.records(5, .metadata)
      let metresPerNativeUnit = 1.0
      let padding = paddingMetres / metresPerNativeUnit
      let lower = Vector3((minX - padding).nextDown, (minY - padding).nextDown,
        (-port.tunnelDepth).nextDown)
      let upper = Vector3((maxX + padding).nextUp, (maxY + padding).nextUp,
        (outwardMetres / metresPerNativeUnit).nextUp)
      let stationLower = Vector3((port.center.x + lower.x).nextDown,
        (port.center.y + lower.y).nextDown, (port.center.z + lower.z).nextDown)
      let stationUpper = Vector3((port.center.x + upper.x).nextUp,
        (port.center.y + upper.y).nextUp, (port.center.z + upper.z).nextUp)
      guard lower.finite, upper.finite, stationLower.finite, stationUpper.finite,
        stationLower.x < stationUpper.x, stationLower.y < stationUpper.y,
        stationLower.z < stationUpper.z else { throw P.Failure.invalidSource }
      // Fixed eight vertices, six faces, twenty-four indices and result record.
      // Mesh's preserveWinding branch stores these arrays without traversal.
      try meter.records(8 + 6 + 24 + 1, .hullInput)
      let a = stationLower, b = stationUpper
      let vertices: [Vector3] = [
        .init(a.x, a.y, a.z), .init(b.x, a.y, a.z), .init(b.x, b.y, a.z), .init(a.x, b.y, a.z),
        .init(a.x, a.y, b.z), .init(b.x, a.y, b.z), .init(b.x, b.y, b.z), .init(a.x, b.y, b.z),
      ]
      let faces = [
        [0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
        [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7],
      ]
      return Volume(catalogueID: id, revision: revision, sourcePort: port,
        metresPerNativeUnit: metresPerNativeUnit, minimumPortFrame: lower, maximumPortFrame: upper,
        minimumStationFrame: stationLower, maximumStationFrame: stationUpper,
        meshInStationFrame: Mesh(vertices: vertices, faces: faces, preserveWinding: true))
    }
  }

  /// Same predicates/order as Port.valid, with each variable visit prepaid.
  private static func validate(_ port: NativeStationGeometry.Port,
    meter: NativeC01InquiryPreparationWork.Meter) throws
  {
    typealias P = NativeC01InquiryPreparationWork
    try validateStationVector(port.center, meter: meter)
    try validateStationVector(port.outward, meter: meter)
    try validateStationVector(port.up, meter: meter)
    try meter.records(1, .metadata)
    guard abs(port.outward.length - 1) < 1e-8, abs(port.up.length - 1) < 1e-8,
      abs(port.outward.dot(port.up)) < 1e-8, port.tunnelDepth.isFinite, port.tunnelDepth > 0,
      (3...64).contains(port.aperture.count) else { throw P.Failure.invalidSource }
    for index in port.aperture.indices {
      try meter.records(1, .metadata)
      let vertex = port.aperture[index]
      try validateStationVector(vertex, meter: meter)
      guard vertex.z == 0 else { throw P.Failure.invalidSource }
    }
    for index in port.aperture.indices {
      try meter.records(1, .metadata)
      let a = port.aperture[index], next = (index + 1) % port.aperture.count
      let edge = port.aperture[next] - a
      guard edge.length.isFinite, edge.length > 0 else { throw P.Failure.invalidSource }
      for other in port.aperture.indices {
        try meter.records(1, .metadata)
        if other == index || other == next { continue }
        let cross = edge.x * (port.aperture[other].y - a.y)
          - edge.y * (port.aperture[other].x - a.x)
        guard cross.isFinite, cross > 0 else { throw P.Failure.invalidSource }
      }
    }
  }

  private static func validateStationVector(_ vector: Vector3,
    meter: NativeC01InquiryPreparationWork.Meter) throws
  {
    // Prepay scalar checks and the bounded temporary array before allocation.
    try meter.records(3, .metadata)
    for value in [vector.x, vector.y, vector.z] {
      guard value.isFinite, abs(value) <= 1e12
      else { throw NativeC01InquiryPreparationWork.Failure.invalidSource }
    }
  }
}
