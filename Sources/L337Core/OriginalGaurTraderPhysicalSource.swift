import Foundation

/// Original calibrated SH127 finite mass calculator, separate from capped native loading.
/// A successful read grants no physical contract, actor, LOD exception or operating authority.
struct OriginalGaurTraderPhysicalSource: Sendable {
  static let id = "SH127"
  static let fileName = "SH127-finite-dry-source.json"
  static let byteCount = 24471
  static let sha256 = "57208af3343f46c9ff55c3ded06e347ad2ed2be031527cf7323cdb1e180c8e0d"

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
    let nativeFaceLimit: Int
    let nativeAdmissionBlocked: Bool
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
    metresPerSourceUnit = 625.0 / 69.0
    nativeTriangles = 2188
  }

  private static let resources: Bundle = Bundle.main.resourceURL.flatMap {
    Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
  } ?? Bundle.module

  static var folder: URL { resources.resourceURL!.appendingPathComponent("GaurTraderPhysical") }

  static let current: Self? = {
    guard let model = try? OriginalFleetShowroomModels.model(for: id) else { return nil }
    return load(from: folder, model: model)
  }()

  static func load(from directory: URL, model: OriginalFleetShowroomModel) -> Self? {
    let file = directory.appendingPathComponent(fileName)
    guard let facts = try? file.resourceValues(
      forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
      facts.isRegularFile == true, facts.isSymbolicLink != true, facts.fileSize == byteCount,
      let bytes = try? Data(contentsOf: file)
    else { return nil }
    return decode(bytes, model: model)
  }

  static func decode(_ bytes: Data, model: OriginalFleetShowroomModel) -> Self? {
    // This is a source-only calculator. It deliberately cannot construct the capped
    // CurrentHullSource/physical contract, whose 2188/512 refusal stays unchanged.
    guard bytes.count == byteCount, ScriptPackLibrary.hash(bytes) == sha256,
      let definition = OriginalFleetR3Data.contract(for: id),
      definition.name == "Gaur Trader", definition.objectKind == .ship,
      let registration = OriginalFleetPhysicalData.registrations[id],
      let engineering = try? OriginalFleetPhysicalData.record(for: id),
      engineering.validates(source: registration),
      definition.referencedGeometrySHA256 == registration.detailedSHA256,
      registration.calibration.exactScale == "625/69",
      engineering.metresPerSourceUnitExact == "625/69",
      engineering.metresPerSourceUnit == 625.0 / 69.0,
      engineering.targetDetailedLengthMetres == 40,
      let original = try? OriginalFleetShowroomModels.model(for: id),
      model.id == id, model.coordinateUnits == nil,
      model.sourcePath == registration.nativeSourcePath,
      model.sourceSHA256 == registration.nativeSourceSHA256,
      model.nativeDesign == original.nativeDesign,
      model.nativeDesign.vertices.count == 1216, model.nativeDesign.faces.count == 2188,
      model.nativeDesign.valid, model.nativeDesign.faces.allSatisfy({ $0.count == 3 }),
      let pending = OriginalDetailedHullStage.registration(for: id),
      pending.r3SHA256 == definition.sourceSHA256,
      pending.nativeSourceSHA256 == model.sourceSHA256,
      pending.physicalRecordSHA256 == registration.sha256,
      pending.sourceNativeFaces == 2188, pending.metresPerSourceUnit == "625/69",
      let d = try? JSONDecoder().decode(Document.self, from: bytes),
      d.schemaVersion == 1, d.id == id, d.name == "Gaur Trader",
      d.status == "FINITE_INTRINSIC_EMPTY_DRY_SOURCE_NOT_NATIVE_OR_OPERATIONAL_QUALIFICATION",
      d.r3SHA256 == definition.sourceSHA256,
      d.engineeringSHA256 == registration.sha256,
      d.resourceSHA256 == pending.resourceSHA256,
      d.nativeSourceSHA256 == model.sourceSHA256,
      d.coordinateUnits == "metres", d.metresPerSourceUnit == engineering.metresPerSourceUnit,
      d.metresPerSourceUnitExact == "625/69", d.targetDetailedLengthMetres == 40,
      d.nativeFaceLimit == 512, d.nativeAdmissionBlocked,
      d.nativeVertices == 1216, d.nativeTriangles == 2188,
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
      d.emptyDryReference.valid, d.emptyDryReference.massKg == 55112,
      d.emptyDryReference.massKg == Double(engineering.dryMassKilograms)
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
