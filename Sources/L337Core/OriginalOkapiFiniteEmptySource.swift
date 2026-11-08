import Foundation

/// A separate proposed empty distribution. Reading it never replaces an adopted
/// physical contract, kit/load source, actor state or installed mechanism.
struct OriginalOkapiFiniteEmptySource: Sendable {
  static let id = "SH029"
  static let fileName = "SH029-finite-empty-source.json"
  static let byteCount = 32507
  static let sha256 = "ad07ebd5e5ed80be9f5bc62b2da23c6d46892112bb74f0a7ec407016b93b405f"
  static let engineeringSHA256 = "f64a24c2863cf047f852d99313ca7ee131ebcda40c3e140f43572d6fbf3aa827"

  private struct Part: Decodable, Sendable {
    let massKg: Double
    let centreMetres: [Double]
    let dimensionsMetres: [Double]
    let originalHardwareAllocationIndex: Int
    let detailedComponentIndex: Int
    let nativeComponentIndex: Int
  }

  private struct Document: Decodable, Sendable {
    let schemaVersion: Int
    let id: String
    let name: String
    let status: String
    let planSHA256: String
    let inputManifestSHA256: String
    let r3SHA256: String
    let detailedSourceSHA256: String
    let nativeSourceSHA256: String
    let engineeringSHA256: String
    let resourceSHA256: String
    let coordinateUnits: String
    let metresPerSourceUnit: Double
    let nativeTriangles: Int
    let nativeFaceLimit: Int
    let finiteIntrinsicHardware: [Part]
    let emptyDryReference: OriginalFiniteDryMass
    let adoptedSourceGeometryOrMassEdited: Bool
    let adoptedKitOrLoadSemanticsEdited: Bool
    let installedCabinCrewPowerOrLoadedAuthorityGranted: Bool
    let sourceOnlyReference: Bool
    let actualObservations: [String]
    let actualGameAcceptance: Bool
  }

  let emptyDry: OriginalFiniteDryMass
  let nativeSourceSHA256: String
  let specificationSHA256: String

  private init(document: Document) {
    emptyDry = document.emptyDryReference
    nativeSourceSHA256 = document.nativeSourceSHA256
    specificationSHA256 = document.r3SHA256
  }

  private static let resources: Bundle = Bundle.main.resourceURL.flatMap {
    Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
  } ?? Bundle.module

  static var folder: URL { resources.resourceURL!.appendingPathComponent("OkapiFiniteEmpty") }

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
    guard bytes.count == byteCount, ScriptPackLibrary.hash(bytes) == sha256,
      let definition = OriginalFleetR3Data.contract(for: id),
      definition.name == "Okapi", definition.objectKind == .ship,
      let registration = OriginalFleetPhysicalData.registrations[id],
      registration.sha256 == engineeringSHA256,
      let engineering = try? OriginalFleetPhysicalData.record(for: id),
      engineering.validates(source: registration), engineering.metresPerSourceUnit == 1,
      engineering.dryMassKilograms == 45520,
      let original = try? OriginalFleetShowroomModels.model(for: id),
      model.id == id, model.coordinateUnits == "metres",
      model.sourcePath == registration.nativeSourcePath,
      model.sourceSHA256 == registration.nativeSourceSHA256,
      model.nativeDesign == original.nativeDesign,
      model.nativeDesign.vertices.count == 76, model.nativeDesign.faces.count == 120,
      model.nativeDesign.valid, model.nativeDesign.faces.allSatisfy({ $0.count == 3 }),
      let document = try? JSONDecoder().decode(Document.self, from: bytes),
      document.schemaVersion == 1, document.id == id, document.name == "Okapi",
      document.status == "PROPOSED_FINITE_INTRINSIC_EMPTY_REFERENCE_NOT_ADOPTED_LOAD_OR_INSTALLATION",
      document.planSHA256 == "bc85c90747bb32b8c87bb6724f75fd7daadc16bc0a1c785d932bf5e4a012955c",
      document.inputManifestSHA256 == "59d693224f0a605deffacfbdf3099d3368e1eed3df0120d334334820e3bc94a8",
      document.r3SHA256 == definition.sourceSHA256,
      document.detailedSourceSHA256 == registration.detailedSHA256,
      document.nativeSourceSHA256 == model.sourceSHA256,
      document.engineeringSHA256 == registration.sha256,
      document.resourceSHA256 == "ecf10abbdaed31818297c0658daa7ffa542214411ab285b2c9e429e3b1ea5ade",
      document.coordinateUnits == "metres", document.metresPerSourceUnit == 1,
      document.nativeTriangles == 120, document.nativeFaceLimit == 512,
      !document.adoptedSourceGeometryOrMassEdited, !document.adoptedKitOrLoadSemanticsEdited,
      !document.installedCabinCrewPowerOrLoadedAuthorityGranted,
      document.sourceOnlyReference, document.actualObservations.isEmpty, !document.actualGameAcceptance,
      document.finiteIntrinsicHardware.count == 8,
      document.finiteIntrinsicHardware.enumerated().allSatisfy({ index, part in
        part.originalHardwareAllocationIndex == index
          && part.massKg == [900.0, 900, 750, 180, 120, 90, 140, 160][index]
          && part.detailedComponentIndex == [8, 11, 0, 0, 0, 0, 0, 0][index]
          && part.nativeComponentIndex == [5, 6, 0, 0, 0, 0, 0, 0][index]
          && part.centreMetres.count == 3 && part.centreMetres.allSatisfy(\.isFinite)
          && part.dimensionsMetres.count == 3
          && part.dimensionsMetres.allSatisfy { $0.isFinite && $0 > 0 }
      }),
      document.emptyDryReference.valid, document.emptyDryReference.massKg == 45520
    else { return nil }
    return Self(document: document)
  }

  /// A reference from rest, without supplying work or changing an actual body.
  func responseFromRest(impulse: Vector3, atLocalPoint point: Vector3) -> OriginalFiniteDryImpulseResponse? {
    emptyDry.responseFromRest(impulse: impulse, atLocalPoint: point)
  }
}
