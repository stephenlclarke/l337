import Foundation

/// Finite intrinsic dry source for SH093. It is a calculator, never a live actor or admission credential.
struct OriginalGiraffeLinerPhysicalSource: Sendable {
  static let id = "SH093"
  static let fileName = "SH093-finite-dry-source.json"
  static let byteCount = 15004
  static let sha256 = "682b4ffd3f5212f65b9fc6fb2d793f5f0638cb7be70bdb21ef60deb6fc8b6d48"

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

  private init(emptyDry: Mass, nativeSourceSHA256: String, specificationSHA256: String) {
    self.emptyDry = emptyDry
    self.nativeSourceSHA256 = nativeSourceSHA256
    self.specificationSHA256 = specificationSHA256
  }

  private static let resources: Bundle = Bundle.main.resourceURL.flatMap {
    Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
  } ?? Bundle.module

  static var folder: URL { resources.resourceURL!.appendingPathComponent("GiraffeLinerPhysical") }

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
      source.contract.id == id, source.contract.name == "Giraffe Liner",
      source.model.coordinateUnits == "metres", source.nativeTriangles == 216,
      source.mesh.vertices.count == 130,
      let registration = OriginalFleetPhysicalData.registrations[id],
      let pending = OriginalDetailedHullStage.registration(for: id),
      let d = try? JSONDecoder().decode(Document.self, from: bytes),
      d.schemaVersion == 1, d.id == id, d.name == "Giraffe Liner",
      d.status == "FINITE_INTRINSIC_EMPTY_DRY_SOURCE_NOT_NATIVE_OR_OPERATIONAL_QUALIFICATION",
      d.r3SHA256 == source.contract.sourceSHA256,
      d.engineeringSHA256 == registration.sha256,
      d.resourceSHA256 == pending.resourceSHA256,
      d.nativeSourceSHA256 == source.model.sourceSHA256,
      d.coordinateUnits == "metres", d.metresPerSourceUnit == 1,
      d.nativeVertices == 130, d.nativeTriangles == 216,
      d.emptyStateOnly, !d.peopleOrFuelCargoEquipmentGranted, d.actualObservations.isEmpty,
      !d.nativeEvidenceQualified, !d.materialsOrMechanismFunctionQualified,
      !d.operatingAuthorityGranted, d.finiteIntrinsicHardware.count == 12,
      Set(d.finiteIntrinsicHardware.map(\.id)).count == 12,
      d.finiteIntrinsicHardware.allSatisfy({
        $0.massKg.isFinite && $0.massKg > 0 && $0.centreMetres.count == 3
          && $0.centreMetres.allSatisfy(\.isFinite) && $0.dimensionsMetres.count == 3
          && $0.dimensionsMetres.allSatisfy { $0.isFinite && $0 > 0 }
          && (0..<8).contains($0.originalHardwareAllocationIndex)
      }),
      d.emptyDryReference.valid, d.emptyDryReference.massKg == 72102,
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

extension OriginalHullPhysicalContract {
  /// Separate finite-mechanism reference. The original engineering budget remains intact;
  /// neither value is a loaded actor or substitutes for pending native qualification.
  var finiteGiraffeLinerDrySource: OriginalGiraffeLinerPhysicalSource? {
    guard id == OriginalGiraffeLinerPhysicalSource.id, metresPerSourceUnit == 1,
      let finite = OriginalGiraffeLinerPhysicalSource.current,
      finite.specificationSHA256 == specificationSHA256,
      finite.nativeSourceSHA256 == model.sourceSHA256
    else { return nil }
    return finite
  }
}
