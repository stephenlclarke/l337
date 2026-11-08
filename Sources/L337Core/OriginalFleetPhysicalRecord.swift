import Foundation

/// A frozen source engineering budget. Loading this value never admits a native actor.
struct OriginalFleetPhysicalRecord: Decodable, Sendable {
  let schemaVersion: Int
  let id: String
  let status: String
  let contractSHA256: String
  let detailedSourceSHA256: String
  let componentSourceSHA256: String
  let roleMapSHA256: String
  let policyProposalSHA256: String
  let coordinateUnits: String
  let metresPerSourceUnit: Double
  let sourceCoordinateUnits: String?
  let metresPerSourceUnitExact: String?
  let targetDetailedLengthMetres: Double?
  let scaleStatus: String?
  let sourceOriginUnchanged: Bool
  let stockMassKg: Double
  let intrinsicHardwareMassKg: Double
  let unroundedMassKg: Double
  let roundingReserveKg: Double
  let dryMassKilograms: Int
  let centreOfMassMetres: [Double]
  let inertiaAboutCentreOfMassKgM2: [Double]
  let sourceOriginInertiaBeforeReserveKgM2: [Double]
  let reserveLocationMetres: [Double]
  let sourceGeometryNotEdited: Bool

  func validates(source: OriginalFleetPhysicalData.Registration) -> Bool {
    guard schemaVersion == 1, id == source.id,
      status == "NEW_AUTHORED_SOURCE_BUDGET_NOT_NATIVE_QUALIFICATION",
      contractSHA256 == OriginalFleetR3Data.contract(for: id)?.sourceSHA256,
      detailedSourceSHA256 == source.detailedSHA256,
      componentSourceSHA256 == source.componentsSHA256,
      roleMapSHA256 == source.roleMapSHA256,
      policyProposalSHA256 == OriginalFleetPhysicalData.policyProposalSHA256,
      coordinateUnits == "metres", validatesCalibration(source.calibration),
      sourceOriginUnchanged, sourceGeometryNotEdited,
      stockMassKg.isFinite, stockMassKg > 0,
      intrinsicHardwareMassKg.isFinite, intrinsicHardwareMassKg > 0,
      unroundedMassKg.isFinite, unroundedMassKg > 0,
      dryMassKilograms > 0, Double(dryMassKilograms) == ceil(unroundedMassKg),
      roundingReserveKg.isFinite, roundingReserveKg >= 0, roundingReserveKg < 1,
      approximately(stockMassKg + intrinsicHardwareMassKg, unroundedMassKg),
      approximately(unroundedMassKg + roundingReserveKg, Double(dryMassKilograms)),
      centreOfMassMetres.count == 3, centreOfMassMetres.allSatisfy(\.isFinite),
      reserveLocationMetres == centreOfMassMetres,
      inertiaAboutCentreOfMassKgM2.count == 9,
      inertiaAboutCentreOfMassKgM2.allSatisfy(\.isFinite),
      sourceOriginInertiaBeforeReserveKgM2.count == 9,
      sourceOriginInertiaBeforeReserveKgM2.allSatisfy(\.isFinite)
    else { return false }
    let tensor = inertiaAboutCentreOfMassKgM2
    for row in 0..<3 {
      for column in 0..<3 {
        guard approximately(tensor[3 * row + column], tensor[3 * column + row]) else {
          return false
        }
      }
    }
    let minor = tensor[0] * tensor[4] - tensor[1] * tensor[3]
    let determinant =
      tensor[0] * (tensor[4] * tensor[8] - tensor[5] * tensor[7])
      - tensor[1] * (tensor[3] * tensor[8] - tensor[5] * tensor[6])
      + tensor[2] * (tensor[3] * tensor[7] - tensor[4] * tensor[6])
    guard tensor[0] > 0, minor.isFinite, minor > 0,
      determinant.isFinite, determinant > 0
    else { return false }
    let centre = centreOfMassMetres
    let squared = centre.reduce(0) { $0 + $1 * $1 }
    for row in 0..<3 {
      for column in 0..<3 {
        let shift = unroundedMassKg
          * ((row == column ? squared : 0) - centre[row] * centre[column])
        guard approximately(
          tensor[3 * row + column] + shift,
          sourceOriginInertiaBeforeReserveKgM2[3 * row + column])
        else { return false }
      }
    }
    return true
  }

  private func validatesCalibration(_ calibration: OriginalFleetPhysicalData.Calibration) -> Bool {
    switch calibration {
    case .declaredMetres:
      return metresPerSourceUnit == 1 && sourceCoordinateUnits == nil
        && metresPerSourceUnitExact == nil && targetDetailedLengthMetres == nil && scaleStatus == nil
    case .relative(let scale, let exact, let length):
      return scale.isFinite && scale > 0 && metresPerSourceUnit == scale
        && metresPerSourceUnitExact == exact && targetDetailedLengthMetres == length
        && length.isFinite && length > 0
        && sourceCoordinateUnits == "Relative original units; no recovered SI declaration."
        && scaleStatus == "NEW_ROOT_ADOPTED_UNIFORM_ENGINEERING_SCALE_NOT_RECOVERED"
    case .existingRelative(let scale, let exact):
      return scale.isFinite && scale > 0 && metresPerSourceUnit == scale
        && metresPerSourceUnitExact == exact && targetDetailedLengthMetres == nil
        && sourceCoordinateUnits == "Relative original units; no recovered SI declaration."
        && scaleStatus == "EXISTING_PER_ID_CALIBRATION_RETAINED_NO_R3_TARGET_FIT"
    }
  }

  private func approximately(_ left: Double, _ right: Double) -> Bool {
    left.isFinite && right.isFinite && abs(left - right) <= 1e-9 * max(1, max(abs(left), abs(right)))
  }
}

/// Authenticated, immutable data; unsupported IDs have no mass fallback or family estimate.
enum OriginalFleetPhysicalData {
  enum Failure: Error, Equatable, Sendable {
    case unissued(String)
    case unavailable
    case invalidResource(String)
  }

  enum Calibration: Sendable, Equatable {
    case declaredMetres
    case relative(scale: Double, exact: String, targetLengthMetres: Double)
    case existingRelative(scale: Double, exact: String)

    var metresPerSourceUnit: Double {
      switch self {
      case .declaredMetres: return 1
      case .relative(let scale, _, _): return scale
      case .existingRelative(let scale, _): return scale
      }
    }

    var exactScale: String {
      switch self {
      case .declaredMetres: return "1"
      case .relative(_, let exact, _): return exact
      case .existingRelative(_, let exact): return exact
      }
    }
  }

  struct Registration: Sendable {
    let id: String
    let sha256: String
    let bytes: Int
    let detailedSHA256: String
    let componentsSHA256: String
    let nativeSourcePath: String
    let nativeSourceSHA256: String
    let roleMapSHA256: String
    let calibration: Calibration

    init(
      id: String, sha256: String, bytes: Int, detailedSHA256: String, componentsSHA256: String,
      nativeSourcePath: String, nativeSourceSHA256: String,
      roleMapSHA256: String = OriginalFleetPhysicalData.roleMapSHA256,
      calibration: Calibration = .declaredMetres
    ) {
      self.id = id
      self.sha256 = sha256
      self.bytes = bytes
      self.detailedSHA256 = detailedSHA256
      self.componentsSHA256 = componentsSHA256
      self.nativeSourcePath = nativeSourcePath
      self.nativeSourceSHA256 = nativeSourceSHA256
      self.roleMapSHA256 = roleMapSHA256
      self.calibration = calibration
    }
  }

  static let roleMapSHA256 = "c70c7d725480d8dd346a5b13799c53b966a50fe32312071cd808f8a4f94baf80"
  static let policyProposalSHA256 = "8f864a534d96733218e126a480353441ac77d7f169936db9a7f4df821a2a2044"
  static let maximumResourceBytes = 1_048_576
  private static let resources: Bundle =
    Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
    } ?? Bundle.module
  static var folder: URL { resources.resourceURL!.appendingPathComponent("OriginalFleetPhysical") }

  private struct Loaded: Sendable {
    let records: [String: OriginalFleetPhysicalRecord]
    let failure: Failure?
  }

  private static let loaded: Loaded = {
    do { return .init(records: try load(from: folder), failure: nil) }
    catch let failure as Failure { return .init(records: [:], failure: failure) }
    catch { return .init(records: [:], failure: .unavailable) }
  }()

  static func record(for id: String) throws -> OriginalFleetPhysicalRecord {
    guard registrations[id] != nil else { throw Failure.unissued(id) }
    if let failure = loaded.failure { throw failure }
    guard let value = loaded.records[id] else { throw Failure.invalidResource(id) }
    return value
  }

  /// Cold atomic load authenticates exact bytes before interpreting any source budget.
  static func load(from directory: URL) throws -> [String: OriginalFleetPhysicalRecord] {
    let files = try FileManager.default.contentsOfDirectory(
      at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
    let expected = Set(registrations.keys.map { $0 + ".json" })
      .union([CurrentNewtKitSource.resourceFileName])
    guard Set(files.map(\.lastPathComponent)) == expected else { throw Failure.unavailable }
    var result: [String: OriginalFleetPhysicalRecord] = [:]
    for file in files {
      if file.lastPathComponent == CurrentNewtKitSource.resourceFileName {
        guard CurrentNewtKitSource.authenticResource(at: file) else { throw Failure.unavailable }
        continue
      }
      let id = file.deletingPathExtension().lastPathComponent
      guard let source = registrations[id] else { throw Failure.unissued(id) }
      let facts = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
      guard facts.isRegularFile == true, facts.isSymbolicLink != true,
        facts.fileSize == source.bytes, source.bytes <= maximumResourceBytes
      else { throw Failure.invalidResource(id) }
      let bytes = try Data(contentsOf: file)
      guard bytes.count == source.bytes, ScriptPackLibrary.hash(bytes) == source.sha256 else {
        throw Failure.invalidResource(id)
      }
      let value = try JSONDecoder().decode(OriginalFleetPhysicalRecord.self, from: bytes)
      guard value.validates(source: source) else { throw Failure.invalidResource(id) }
      result[id] = value
    }
    return result
  }
}
