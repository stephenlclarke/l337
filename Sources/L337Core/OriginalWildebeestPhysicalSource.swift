import Foundation

/// Finite source through the supported canonical capped/relative loader for SH104.
/// This is a calculator, never a live actor, physical-contract extension or admission credential.
struct OriginalWildebeestPhysicalSource: Sendable {
  static let id = "SH104"
  static let fileName = "SH104-finite-dry-source.json"
  static let byteCount = 18964
  static let sha256 = "2d457629db04ac97a506ca596f086edfb39ca555e21971ca7eb1867d72a75c77"

  typealias Mass = OriginalFiniteDryMass
  typealias ImpulseResponse = OriginalFiniteDryImpulseResponse

  private struct Part: Decodable, Sendable {
    let id: String
    let massKg: Double
    let centreMetres: [Double]
    let dimensionsMetres: [Double]
    let originalHardwareAllocationIndex: Int
  }

  private struct Document: Decodable, Sendable {
    let schemaVersion: Int
    let id: String
    let name: String
    let status: String
    let r3SHA256: String
    let engineeringSHA256: String
    let resourceSHA256: String
    let nativeSourceSHA256: String
    let coordinateUnits: String
    let metresPerSourceUnit: Double
    let metresPerSourceUnitExact: String
    let targetDetailedLengthMetres: Double
    let nativeAdmissionBlocked: Bool
    let nativeRefusalStage: String
    let nativeVertices: Int
    let nativeTriangles: Int
    let finiteIntrinsicHardware: [Part]
    let emptyDryReference: Mass
    let emptyStateOnly: Bool
    let peopleOrFuelCargoEquipmentGranted: Bool
    let actualObservations: [String]
    let nativeEvidenceQualified: Bool
    let materialsOrMechanismFunctionQualified: Bool
    let operatingAuthorityGranted: Bool
  }

  let emptyDry: Mass
  let nativeSourceSHA256: String
  let specificationSHA256: String
  let metresPerSourceUnit: Double
  let nativeTriangles: Int

  private init(emptyDry: Mass, nativeSourceSHA256: String, specificationSHA256: String) {
    self.emptyDry = emptyDry
    self.nativeSourceSHA256 = nativeSourceSHA256
    self.specificationSHA256 = specificationSHA256
    metresPerSourceUnit = 10000.0 / 667.0
    nativeTriangles = 424
  }

  private static let resources: Bundle = Bundle.main.resourceURL.flatMap {
    Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
  } ?? Bundle.module

  static var folder: URL { resources.resourceURL!.appendingPathComponent("WildebeestPhysical") }

  static let current: Self? = {
    guard let source = try? OriginalFleetCurrentHullSource(id: id) else { return nil }
    return load(from: folder, source: source)
  }()

  static func load(from directory: URL, source: OriginalFleetCurrentHullSource) -> Self? {
    let file = directory.appendingPathComponent(fileName)
    guard let facts = try? file.resourceValues(
      forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
      facts.isRegularFile == true, facts.isSymbolicLink != true, facts.fileSize == byteCount,
      let bytes = try? Data(contentsOf: file)
    else { return nil }
    return decode(bytes, source: source)
  }

  static func decode(_ bytes: Data, source: OriginalFleetCurrentHullSource) -> Self? {
    guard bytes.count == byteCount, ScriptPackLibrary.hash(bytes) == sha256,
      source.contract.id == id, source.contract.name == "Wildebeest",
      source.model.coordinateUnits == nil, source.nativeTriangles == 424,
      source.mesh.vertices.count == 244,
      source.engineering.metresPerSourceUnitExact == "10000/667",
      source.engineering.metresPerSourceUnit == 10000.0 / 667.0,
      source.engineering.targetDetailedLengthMetres == 40,
      let registration = OriginalFleetPhysicalData.registrations[id],
      let pending = OriginalDetailedHullStage.registration(for: id),
      let d = try? JSONDecoder().decode(Document.self, from: bytes),
      d.schemaVersion == 1, d.id == id, d.name == "Wildebeest",
      d.status == "FINITE_INTRINSIC_EMPTY_DRY_SOURCE_NOT_NATIVE_OR_OPERATIONAL_QUALIFICATION",
      d.r3SHA256 == source.contract.sourceSHA256,
      d.engineeringSHA256 == registration.sha256,
      d.resourceSHA256 == pending.resourceSHA256,
      d.nativeSourceSHA256 == source.model.sourceSHA256,
      d.coordinateUnits == "metres", d.metresPerSourceUnit == source.engineering.metresPerSourceUnit,
      d.metresPerSourceUnitExact == "10000/667", d.targetDetailedLengthMetres == 40,
      d.nativeAdmissionBlocked, d.nativeRefusalStage == "nativeEvidencePending",
      d.nativeVertices == 244, d.nativeTriangles == 424,
      d.emptyStateOnly, !d.peopleOrFuelCargoEquipmentGranted, d.actualObservations.isEmpty,
      !d.nativeEvidenceQualified, !d.materialsOrMechanismFunctionQualified,
      !d.operatingAuthorityGranted, d.finiteIntrinsicHardware.count == 10,
      Set(d.finiteIntrinsicHardware.map(\.id)).count == 10,
      d.finiteIntrinsicHardware.allSatisfy({
        $0.massKg.isFinite && $0.massKg > 0 && $0.centreMetres.count == 3
          && $0.centreMetres.allSatisfy(\.isFinite) && $0.dimensionsMetres.count == 3
          && $0.dimensionsMetres.allSatisfy { $0.isFinite && $0 > 0 }
          && (0..<8).contains($0.originalHardwareAllocationIndex)
      }),
      d.emptyDryReference.valid, d.emptyDryReference.massKg == 98146,
      d.emptyDryReference.massKg == Double(source.engineering.dryMassKilograms)
    else { return nil }
    return Self(emptyDry: d.emptyDryReference, nativeSourceSHA256: d.nativeSourceSHA256,
      specificationSHA256: d.r3SHA256)
  }

  /// A reference response from rest. This does not assert that an actual body is at rest,
  /// supply impulse energy, alter any body or include people, cargo, fuel or paid equipment.
  func responseFromRest(impulse: Vector3, atLocalPoint point: Vector3) -> ImpulseResponse? {
    emptyDry.responseFromRest(impulse: impulse, atLocalPoint: point)
  }
}
