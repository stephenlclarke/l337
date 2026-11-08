import Foundation

/// Exact inventory distributions from the authenticated Bison configuration.
/// Cells are finite source positions; kg/g are not converted to cargo tonnes.
struct CurrentNewtBisonInventory: Sendable {
  typealias Mass = CurrentNewtKitReceipt.MassProperties
  typealias Allocation = CurrentNewtKitLoadModel.Allocation
  let cargoCentres: [Vector3]
  let cargoMeshes: [Mesh]
  let unitGrams: [Int]
  let maximumCargoGrams: Int
  let maximumCellGrams: Int
  let cargoDensity: Double
  let fuelCentre: Vector3
  let fuelDimensions: Vector3
  let fuelMesh: Mesh
  let fuelKilogramsPerTenthLY: Double
  let maximumFuelDensity: Double
  let missileDimensions: Vector3
  let missileMass: Double
  let missileCentres: [Vector3]
  let missileMesh: Mesh

  static func decode(_ value: Any?) -> Self? {
    guard let root = value as? [String: Any], root["catalogueShipID"] as? String == "SH005",
      root["r3SHA256"] as? String == CurrentBisonWideShoePhysicalSource.r3SHA256,
      let cargo = root["cargo"] as? [String: Any],
      let centres = vectors(cargo["cellCentresMetres"]), centres.count == 1152,
      let nativeUnits = cargo["nativeUnitByCommodityIndex"] as? [String],
      nativeUnits == CommodityIdentity.allCases.map(\.unit),
      let kilograms = cargo["unitKilograms"] as? [String: Double],
      kilograms == ["t": 1000, "kg": 1, "g": 0.001],
      let maximumCargo = cargo["maximumTotalKilograms"] as? Double,
      maximumCargo == 1_108_000,
      let maximumCell = cargo["maximumCellKg"] as? Double, maximumCell == 1000,
      let density = cargo["cubeDensityKgM3"] as? Double, density == 1000,
      let fuel = root["fuel"] as? [String: Any],
      fuel["includesActualScoopRemainder"] as? Bool == true,
      fuel["capacityTenthsLY"] as? Int == 130,
      let fuelCentre = vector(fuel["centreMetres"]),
      let fuelDimensions = vector(fuel["distributionDimensionsMetres"]), positive(fuelDimensions),
      let fuelKg = fuel["kilogramsPerTenthLY"] as? Double, fuelKg == 10,
      let fuelDensity = fuel["maximumBulkDensityKgM3"] as? Double, fuelDensity == 1000,
      let fuelMesh = mesh(centre: fuelCentre, dimensions: fuelDimensions),
      let missiles = root["missiles"] as? [String: Any], missiles["maximum"] as? Int == 7,
      let missileCentres = vectors(missiles["centresMetres"]), missileCentres.count == 7,
      let missileDimensions = vector(missiles["dimensionsMetres"]), positive(missileDimensions),
      let missileMass = missiles["kilogramsEach"] as? Double, missileMass == 100,
      let missileMesh = mesh(centre: .init(0, 0, 0), dimensions: missileDimensions),
      let equipment = root["equipment"] as? [String: Any],
      equipment["actualFuelScoopsMustBeFalse"] as? Bool == true,
      equipment["actualECMEnabledMustBeSealed"] as? Bool == true,
      equipment["coreECMIncludedInNewBareKg"] as? Double == 35,
      equipment["kitCount"] as? Int == 1,
      equipment["additionalModules"] as? String == "REFUSE_UNMODELED_ACTUAL_MODULES"
    else { return nil }
    let fullDimensions = Vector3(1, 1, 1)
    let meshes = centres.compactMap { mesh(centre: $0, dimensions: fullDimensions) }
    guard meshes.count == centres.count else { return nil }
    let unitGrams = nativeUnits.compactMap { kilograms[$0].map { Int($0 * 1000) } }
    guard unitGrams.count == nativeUnits.count else { return nil }
    return .init(cargoCentres: centres, cargoMeshes: meshes,
      unitGrams: unitGrams,
      maximumCargoGrams: Int(maximumCargo * 1000), maximumCellGrams: Int(maximumCell * 1000),
      cargoDensity: density, fuelCentre: fuelCentre, fuelDimensions: fuelDimensions,
      fuelMesh: fuelMesh, fuelKilogramsPerTenthLY: fuelKg, maximumFuelDensity: fuelDensity,
      missileDimensions: missileDimensions, missileMass: missileMass,
      missileCentres: missileCentres, missileMesh: missileMesh)
  }

  func allocations(_ load: CurrentNewtKitLoad) -> [Allocation]? {
    guard load.structurallyValid, load.hasFuelScoops == false, let fuel = load.resources.fuel,
      fuel >= 0, Double(fuel) + load.resources.scoopRemainder <= 130,
      load.missiles >= 0, load.missiles <= missileCentres.count else { return nil }
    var result: [Allocation] = []
    var cursor = 0
    var total = 0
    for amount in load.cargo.sorted(by: { $0.commodity.rawValue < $1.commodity.rawValue }) {
      let unit = unitGrams[amount.commodity.rawValue]
      guard amount.valid, amount.quantity <= (maximumCargoGrams - total) / unit else { return nil }
      let grams = amount.quantity * unit
      total += grams
      let full = grams / maximumCellGrams
      let remainder = grams % maximumCellGrams
      let required = full + (remainder > 0 ? 1 : 0)
      guard required <= cargoCentres.count - cursor else { return nil }
      for index in 0..<required {
        let cell = cursor + index
        let cellGrams = index < full ? maximumCellGrams : remainder
        let mass = Double(cellGrams) / 1000
        let edge = pow(mass / cargoDensity, 1.0 / 3.0)
        let dimensions = Vector3(edge, edge, edge)
        let geometry: Mesh
        if cellGrams == maximumCellGrams { geometry = cargoMeshes[cell] }
        else {
          guard let partial = Self.mesh(centre: cargoCentres[cell], dimensions: dimensions) else { return nil }
          geometry = partial
        }
        result.append(.init(id: "actual-cargo-(\(amount.commodity.rawValue), \(cell))",
          mass: Self.boxMass(mass, centre: cargoCentres[cell], dimensions: dimensions), mesh: geometry))
      }
      cursor += required
    }
    let fuelMass = (Double(fuel) + load.resources.scoopRemainder) * fuelKilogramsPerTenthLY
    let volume = fuelDimensions.x * fuelDimensions.y * fuelDimensions.z
    guard fuelMass.isFinite, fuelMass >= 0, fuelMass <= maximumFuelDensity * volume else { return nil }
    if fuelMass > 0 {
      result.append(.init(id: "actual-fuel-including-scoop-remainder",
        mass: Self.boxMass(fuelMass, centre: fuelCentre, dimensions: fuelDimensions), mesh: fuelMesh))
    }
    for index in 0..<load.missiles {
      result.append(.init(id: "actual-missile-\(index)",
        mass: Self.boxMass(missileMass, centre: missileCentres[index], dimensions: missileDimensions),
        mesh: missileMesh, offset: missileCentres[index]))
    }
    return result.allSatisfy { CurrentNewtKitMass.componentIsValid($0.mass) } ? result : nil
  }

  private static func boxMass(_ mass: Double, centre: Vector3, dimensions d: Vector3) -> Mass {
    .init(massKilograms: mass, centreOfMassMetres: centre,
      inertiaKgM2: [mass * (d.y * d.y + d.z * d.z) / 12, 0, 0,
        0, mass * (d.x * d.x + d.z * d.z) / 12, 0,
        0, 0, mass * (d.x * d.x + d.y * d.y) / 12])
  }

  private static func mesh(centre: Vector3, dimensions: Vector3) -> Mesh? {
    CurrentNewtKitGeometry.mesh(part: ["shape": "effectiveUniformBoxMassModel",
      "centreMetres": [centre.x, centre.y, centre.z],
      "dimensionsMetres": [dimensions.x, dimensions.y, dimensions.z]])
  }

  private static func vector(_ value: Any?) -> Vector3? {
    guard let values = value as? [Double], values.count == 3, values.allSatisfy(\.isFinite) else { return nil }
    return .init(values[0], values[1], values[2])
  }

  private static func vectors(_ value: Any?) -> [Vector3]? {
    guard let values = value as? [[Double]] else { return nil }
    let result = values.compactMap(vector)
    return result.count == values.count ? result : nil
  }

  private static func positive(_ v: Vector3) -> Bool {
    v.finite && v.x > 0 && v.y > 0 && v.z > 0
  }
}

extension CurrentNewtKitLoadModel {
  static func decodeBison(_ value: Any?, people: [Int: CurrentNewtKitIssue.PersonProfile]) -> Self? {
    guard let inventory = CurrentNewtBisonInventory.decode(value), people.count == 12,
      let contract = OriginalFleetR3Data.contract(for: "SH005"),
      contract.sourceSHA256 == CurrentBisonWideShoePhysicalSource.r3SHA256,
      contract.performance?.cargo == 1108, contract.performance?.fuel == 130,
      contract.performance?.missiles == 7 else { return nil }
    return .init(catalogueShipID: "SH005", r3SHA256: contract.sourceSHA256,
      rules: [], fixed: [], fixedAllocations: [], expectedPeople: people, bisonInventory: inventory,
      maximumCargoMassKilograms: 1_108_000, maximumFuelTenthsLY: 130, maximumMissiles: 7)
  }
}
