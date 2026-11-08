import Foundation

struct OriginalHullEnvelope: Sendable, Equatable {
  let minimum: Vector3
  let maximum: Vector3
  /// Rotation is about the authored origin, which need not be the AABB centre.
  let clearanceRadius: Double
  var dimensions: Vector3 { maximum - minimum }

  init(vertices: [Vector3]) throws {
    guard vertices.count >= 4, vertices.allSatisfy(\.finite) else {
      throw OriginalHullPhysicalContract.Failure.invalidGeometry
    }
    minimum = .init(
      vertices.map(\.x).min()!, vertices.map(\.y).min()!, vertices.map(\.z).min()!)
    maximum = .init(
      vertices.map(\.x).max()!, vertices.map(\.y).max()!, vertices.map(\.z).max()!)
    clearanceRadius = vertices.map(\.length).max()!
    let size = maximum - minimum
    guard size.finite, size.x > 0, size.y > 0, size.z > 0,
      clearanceRadius.isFinite, clearanceRadius > 0
    else { throw OriginalHullPhysicalContract.Failure.invalidGeometry }
  }
}

/// One deliberate physical-source binding, separate from display normalization and actor admission.
/// This contract alone never replaces a saved ship, enables a fitting or certifies a docking route.
struct OriginalHullPhysicalContract: Sendable {
  enum Failure: Error { case unsupportedSource, invalidGeometry }
  let id: String
  let name: String
  let metresPerSourceUnit: Double
  let unitBasis: String
  let physicalMesh: Mesh
  let specificationSHA256: String
  let model: OriginalFleetShowroomModel
  let envelope: OriginalHullEnvelope
  let nativeTriangles: Int
  /// Empty-hull engineering only. This is not a complete occupied or loaded inertial model.
  let engineering: OriginalFleetPhysicalRecord?

  static let gyrfalconAssault: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH002") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH002"))
  }

  static let gyrfalconCommand: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH003") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH003"))
  }

  static let gyrfalconPatrol: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH004") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH004"))
  }

  static let impalaVoyager: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH007") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH007"))
  }

  static let sableLiner: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH012") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH012"))
  }

  static let onager: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH018") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH018"))
  }

  static let gazelleExplorer: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH019") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH019"))
  }

  static let ibex: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH027") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH027"))
  }

  static let sparrowhawk: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH030") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH030"))
  }

  static let kiteInterceptor: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH031") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH031"))
  }

  static let pantherExplorer: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH032") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH032"))
  }

  static let pantherScout: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH033") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH033"))
  }

  static let stagLiner: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH035") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH035"))
  }

  static let redtailMkIII: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH103") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH103"))
  }

  static let besra: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH108") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH108"))
  }

  static let okapi: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH029") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH029"))
  }

  static let saiga: Result<Self, any Error> = Result {
    guard let definition = OriginalFleetDefinitionData.definition(for: "SH061") else {
      throw Failure.unsupportedSource
    }
    return try Self(
      definition: definition, model: OriginalFleetShowroomModels.model(for: "SH061"))
  }

  @inline(never)
  init(definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel) throws {
    // A bounded source model can be inspected before actor qualification. All live actor,
    // raw-mesh, player, fitting and salvage entry points retain their independent admission gate.
    if OriginalFleetPhysicalData.registrations[definition.id] == nil {
      try OriginalDetailedHullStage.requireRuntime(definition.id)
    }
    guard definition.approvedMeshAvailable, model.id == definition.id, model.nativeDesign.valid
    else {
      throw Failure.unsupportedSource
    }
    let selected = try Self.sourceCalibration(definition: definition, model: model)
    let calibration = try Self.completeEngineering(selected, definition: definition, model: model)
    try self.init(definition: definition, model: model, calibration: calibration)
  }

  private struct SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    let engineering: OriginalFleetPhysicalRecord?
  }

  @inline(never)
  private static func sourceCalibration(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    switch definition.id {
    case "SH002":
      return try calibrationCase1(definition: definition, model: model)
    case "SH003", "SH004":
      return try calibrationCase2(definition: definition, model: model)
    case "SH007":
      return try calibrationCase3(definition: definition, model: model)
    case "SH012":
      return try calibrationCase4(definition: definition, model: model)
    case "SH018":
      return try calibrationCase5(definition: definition, model: model)
    case "SH019":
      return try calibrationCase6(definition: definition, model: model)
    case "SH027":
      return try calibrationCase7(definition: definition, model: model)
    case "SH030":
      return try calibrationCase8(definition: definition, model: model)
    case "SH031":
      return try calibrationCase9(definition: definition, model: model)
    case "SH032", "SH033":
      return try calibrationCase10(definition: definition, model: model)
    case "SH035":
      return try calibrationCase11(definition: definition, model: model)
    case "SH103":
      return try calibrationCase12(definition: definition, model: model)
    case "SH108":
      return try calibrationCase13(definition: definition, model: model)
    case "SH029":
      return try calibrationCase14(definition: definition, model: model)
    case "SH061":
      return try calibrationCase15(definition: definition, model: model)
    case "SH040":
      return try calibrationCase16(definition: definition, model: model)
    default:
      return try calibrationCase17(definition: definition, model: model)
    }
  }

  @inline(never)
  private static func calibrationCase1(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Gyrfalcon Assault",
        definition.sourceSHA256
          == "c2319489558505ed3d4eb6a437e8870e4f6f20055912e337792e324200d0230f",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-01-native-lod/SH002-design.toml",
        model.sourceSHA256 == "5e665c3443a3f1fb2341d418dc9d5cbde7bc1f11d2761c67289defeb26e3c51a"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase2(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard let approved = OriginalGyrfalconFamilyActivation.registration(for: definition.id),
        definition.name == approved.name,
        definition.sourceSHA256 == approved.specificationSHA256,
        model.coordinateUnits == "metres", model.sourcePath == approved.modelPath,
        model.sourceSHA256 == approved.modelSHA256
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase3(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Impala Voyager",
        definition.sourceSHA256
          == "362f40c5d357d80c6559090d528a09f71858e09155b162996902c10aa4c7ff63",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-01-native-lod/SH007-design.toml",
        model.sourceSHA256 == "911be33ac10be443afd3d33c6d20f65079bb9a5c20b58752597c52d50d12aad3"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase4(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Sable Liner",
        definition.sourceSHA256
          == "a59ed199acd7c681bc4e590076b0853d19db9724c777c0aee483878d30fcb0df",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH012-design.toml",
        model.sourceSHA256 == "980854a3c77366b6c0e1d8f559ffcbdad7bbf2fe510988fdd86a380477f6e297"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase5(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Onager",
        definition.sourceSHA256
          == "93ec89428324d31d6639ad069107c767d7c0129d1683d26f27475fc89a56cc38",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH018-design.toml",
        model.sourceSHA256 == "40e2a5fdd0f7945141cb55701deab76a64f974a38133f86333bb4fd8d199fbf6"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase6(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Gazelle Explorer",
        definition.sourceSHA256
          == "9eb70cd7503964f5613f86cd6ceec2cf34f64598e8018779380fc6eca5b08a04",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-01-native-lod/SH019-design.toml",
        model.sourceSHA256 == "56172839f14cc1aca09814de34d181b98832e87e071130d0c4c930a760d66944"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase7(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Ibex",
        definition.sourceSHA256
          == "7b038e5e6675b715d56d0ffbecf5ebaed4dd0216109c63aaf5c7dd990efa1aa8",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH027-design.toml",
        model.sourceSHA256 == "db3494ecc09b427242eed021bae074124aad87c38fe03b654161d49269952484"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase8(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Sparrowhawk",
        definition.sourceSHA256
          == "774d49d514d03dba198d09762d04d30e74d3ea07dad7f1c34167f0978defb36d",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH030-design.toml",
        model.sourceSHA256 == "92a8ba49e684eca12580df930e999bd6f21186821b92b87f8c381b0a3e017e66"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase9(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Kite Interceptor",
        definition.sourceSHA256
          == "cedbde09b76675e9fb3f6022d9c78330524be816ec3d3878f600c0b5244fc8b0",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH031-design.toml",
        model.sourceSHA256 == "099246e4cea539c64042a0749ba1873e3fdbe2dfba92c53bc7370c03719dea56"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase10(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard let approved = OriginalPantherFamilyActivation.registration(for: definition.id),
        definition.name == approved.name, definition.role == approved.role.rawValue,
        definition.sourceSHA256 == approved.specificationSHA256,
        model.coordinateUnits == "metres", model.sourcePath == approved.modelPath,
        model.sourceSHA256 == approved.modelSHA256
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase11(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Stag Liner",
        definition.sourceSHA256
          == "dff26cfb4027b272cb7e82c1fd967ec5aa8e27e4a74d2cdfd28a5a01a5836dae",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH035-design.toml",
        model.sourceSHA256 == "78f0f2a3940b7c50c9dafc17323320da23173b25af19c16a0be427167949334a"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase12(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Redtail Mk III",
        definition.sourceSHA256
          == "a867f71cdc9693f245c54a8c63d15a657a00c6ba7db782cfa384b6f6ee41ccdf",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-04/SH103-design.toml",
        model.sourceSHA256 == "39ec7a78c9da5b4ff652255b4d278d1169821bb27941e1d34ccc2f97ce61eb90"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase13(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Besra",
        definition.sourceSHA256
          == "e6dd044e8985abfeb14b7a23296389c5acbb210e901bebe64aa4cbbdc49c4de8",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-04/SH108-design.toml",
        model.sourceSHA256 == "ef7d78789eed53b721c6f9417abe5f79a0394613540ff901d8af1fd9c76e13f1"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase14(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Okapi",
        definition.sourceSHA256
          == "229d27ea2c5213bd0993c99b9545997e065673e578b7120829e5c6bd06dafc59",
        model.coordinateUnits == "metres",
        model.sourcePath == "fleet-completion-20261019/batch-02-native-lod/SH029-design.toml",
        model.sourceSHA256 == "585cb9a7f47fb13f6249c09f2ccc262eb852c98ad10721a95730b68fc4eb7b5c"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 1
      unitBasis = "Approved native LOD in authored metres."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase15(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard definition.name == "Saiga",
        definition.sourceSHA256
          == "a5b9e65f897bebac9f94ab7ba88c5f38908bf13da7c85c5c3eff5b74ed96a4a4",
        model.coordinateUnits == nil,
        model.sourcePath == "replacement-hulls/SH061-design.toml",
        model.sourceSHA256 == "fad88f0e9cfc1f9a3748ab995b9fca058f675a0c8a6fc89bc72ccefd8399e26b"
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = 20
      unitBasis =
        "Explicit project calibration approved 21 October 2026: 20 metres per SH061 source unit. Source coordinates did not declare SI units."
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase16(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      guard let registration = OriginalFleetPhysicalData.registrations[definition.id],
        model.sourcePath == registration.nativeSourcePath,
        model.sourceSHA256 == registration.nativeSourceSHA256,
        model.coordinateUnits == nil, model.nativeDesign.faces.count == 92,
        model.nativeDesign.faces.allSatisfy({ $0.count == 3 })
      else { throw Failure.unsupportedSource }
      let record = try OriginalFleetPhysicalData.record(for: definition.id)
      guard record.contractSHA256 == definition.sourceSHA256 else { throw Failure.unsupportedSource }
      metresPerSourceUnit = record.metresPerSourceUnit
      unitBasis = "Authored cryostasis shell in its original frame at the retained 60/19 calibration."
      sourceEngineering = record
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func calibrationCase17(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    let metresPerSourceUnit: Double
    let unitBasis: String
    var sourceEngineering: OriginalFleetPhysicalRecord?
      let source = try OriginalFleetCurrentHullSource(id: definition.id, model: model)
      guard source.contract.name == definition.name,
        source.contract.sourceSHA256 == definition.sourceSHA256,
        source.model.sourcePath == model.sourcePath,
        source.model.sourceSHA256 == model.sourceSHA256,
        source.model.nativeDesign == model.nativeDesign
      else { throw Failure.unsupportedSource }
      metresPerSourceUnit = source.engineering.metresPerSourceUnit
      unitBasis =
        "Exact current original source; explicit uniform engineering calibration at its original origin."
      sourceEngineering = source.engineering
    return .init(
      metresPerSourceUnit: metresPerSourceUnit, unitBasis: unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private static func completeEngineering(
    _ calibration: SourceCalibration, definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel
  ) throws -> SourceCalibration {
    var sourceEngineering = calibration.engineering
    let metresPerSourceUnit = calibration.metresPerSourceUnit
    // Baseline calibrations retain their exact sources and units. An added source budget
    // binds here without turning empty engineering into loaded mass or native qualification.
    if sourceEngineering == nil, let binding = OriginalFleetPhysicalData.registrations[definition.id] {
      let record = try OriginalFleetPhysicalData.record(for: definition.id)
      guard record.contractSHA256 == definition.sourceSHA256,
        binding.nativeSourcePath == model.sourcePath,
        binding.nativeSourceSHA256 == model.sourceSHA256,
        record.metresPerSourceUnit == metresPerSourceUnit
      else { throw Failure.unsupportedSource }
      sourceEngineering = record
    }
    return .init(metresPerSourceUnit: metresPerSourceUnit,
      unitBasis: calibration.unitBasis, engineering: sourceEngineering)
  }

  @inline(never)
  private init(
    definition: OriginalFleetDefinition, model: OriginalFleetShowroomModel, calibration: SourceCalibration
  ) throws {
    metresPerSourceUnit = calibration.metresPerSourceUnit
    unitBasis = calibration.unitBasis
    let mesh = model.displayMesh
    id = definition.id
    name = definition.name
    specificationSHA256 = definition.sourceSHA256
    self.model = model
    engineering = calibration.engineering
    let scale = metresPerSourceUnit
    physicalMesh = .init(
      vertices: mesh.vertices.map { $0 * scale }, faces: mesh.faces,
      details: mesh.details, materials: mesh.materials, faceMaterials: mesh.faceMaterials,
      faceTextures: mesh.faceTextures, preserveWinding: true)
    envelope = try OriginalHullEnvelope(vertices: physicalMesh.vertices)
    nativeTriangles = mesh.faces.reduce(0) { $0 + max(0, $1.count - 2) }
  }

  var sourceFields: [ShipSpec] {
    let size = envelope.dimensions
    let basis =
      unitBasis
      + " Independent of display normalization; derived bounds do not certify a docking route or activate a hull."
    func field(_ key: String, _ label: String, _ value: Double, unit: String) -> ShipSpec {
      .init(
        key: "original.physical." + key, label: label,
        text: String(format: "%.2f", value) + " " + unit, number: value,
        unit: unit, status: metresPerSourceUnit == 1 ? "source" : "calibration", basis: basis)
    }
    return [
      field("width", "Native LOD width X", size.x, unit: "m"),
      field("height", "Native LOD height Y", size.y, unit: "m"),
      field("length", "Native LOD length Z", size.z, unit: "m"),
      field(
        "clearanceRadius", "Native origin clearance radius", envelope.clearanceRadius, unit: "m"),
      .init(
        key: "original.physical.source", label: "Physical source",
        text: model.sourcePath + " / " + model.sourceSHA256,
        number: nil, unit: "authored", status: "source", basis: basis),
    ]
  }
}

extension CatalogueShip {
  /// Keep the complete original-source profile intact; physical evidence has its own units/group.
  var physicalSourceContract: OriginalHullPhysicalContract? {
    let result: Result<OriginalHullPhysicalContract, any Error>
    switch id {
    case "SH002": result = OriginalHullPhysicalContract.gyrfalconAssault
    case "SH003": result = OriginalHullPhysicalContract.gyrfalconCommand
    case "SH004": result = OriginalHullPhysicalContract.gyrfalconPatrol
    case "SH007": result = OriginalHullPhysicalContract.impalaVoyager
    case "SH012": result = OriginalHullPhysicalContract.sableLiner
    case "SH018": result = OriginalHullPhysicalContract.onager
    case "SH019": result = OriginalHullPhysicalContract.gazelleExplorer
    case "SH027": result = OriginalHullPhysicalContract.ibex
    case "SH030": result = OriginalHullPhysicalContract.sparrowhawk
    case "SH031": result = OriginalHullPhysicalContract.kiteInterceptor
    case "SH032": result = OriginalHullPhysicalContract.pantherExplorer
    case "SH033": result = OriginalHullPhysicalContract.pantherScout
    case "SH035": result = OriginalHullPhysicalContract.stagLiner
    case "SH103": result = OriginalHullPhysicalContract.redtailMkIII
    case "SH108": result = OriginalHullPhysicalContract.besra
    case "SH029": result = OriginalHullPhysicalContract.okapi
    case "SH061": result = OriginalHullPhysicalContract.saiga
    default:
      guard let cached = OriginalFleetPhysicalContractCache.result(for: id) else { return nil }
      result = cached
    }
    return try? result.get()
  }

  var physicalSourcePreview: Mesh? {
    physicalSourceContract?.model.displayMesh.showroomNormalised
  }

  var sourceProfilesIncludingPhysical: [ShipProfile] {
    let retained = sourceProfilesIncludingOriginal
    guard let contract = physicalSourceContract else { return retained }
    return retained + [
      .init(
        id: id + "/original-physical", title: "Physical source: " + contract.name,
        group: "original-physical-metres",
        context:
          contract.unitBasis + " Active fitting and docking remain separate.",
        fields: contract.sourceFields)
    ]
  }
}
