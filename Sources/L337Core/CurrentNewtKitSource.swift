import Foundation
import CoreFoundation

/// A fixed current source binding. Source data selects no actor and installs no hardware.
struct CurrentNewtKitSource: Sendable {
  typealias Mass = CurrentNewtKitReceipt.MassProperties
  typealias State = CurrentNewtKitReceipt.BodyState

  struct Part: Sendable {
    let id: String
    let stowed: Mass
    let lowered: Mass
    let extended: Mass
    let mesh: Mesh
  }

  struct ReleasedPart: Sendable {
    let id: String
    let mass: Mass
    let collisionMesh: Mesh?
    let displayMesh: Mesh?
  }

  let configuration: String
  let sourceSHA256: String
  let personProfile: CurrentNewtKitIssue.PersonProfile
  let bareParent: Mass
  let podMass: Mass
  let carrierBefore: Mass
  let carrierAfter: Mass
  let installedMass: Mass
  let separatedMass: Mass
  let retainedParts: [Part]
  let loadModel: CurrentNewtKitLoadModel?
  let releasedParts: [ReleasedPart]
  let podOrigin: Vector3
  let direction: Vector3
  let rackLowering: Vector3
  let maximumForceNewtons: Double
  let maximumGuideFrictionNewtons: Double
  let dropDuration: Double
  let ejectDuration: Double
  let duration: Double
  let stroke: Double
  let freeTravel: Double
  let releaseSpeed: Double
  let ejectionAcceleration: Double
  let maximumAngularSpeed: Double
  let maximumInitialAngularSpeed: Double
  let maximumCarrierAcceleration: Double
  let dropWork: Double
  let ejectWork: Double
  let initialCharges: CurrentNewtKitStock.Charges
  let startupElectricalJoules: Double
  let continuousPowerWatts: Double
  let oxygenKgPerSecond: Double
  let carbonDioxideKgPerSecond: Double
  let supportSeconds: Double

  static let current: Self? = load()

  static var resourceFileName: String { CurrentNewtKitPhysicalSource.resourceFileName }

  static func authenticResource(at file: URL) -> Bool {
    guard file.lastPathComponent == resourceFileName,
      let facts = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
      facts.isRegularFile == true, facts.isSymbolicLink != true,
      facts.fileSize == CurrentNewtKitPhysicalSource.sourceByteCount,
      let bytes = try? Data(contentsOf: file), bytes.count == CurrentNewtKitPhysicalSource.sourceByteCount
    else { return false }
    return ScriptPackLibrary.hash(bytes) == CurrentNewtKitPhysicalSource.sourceSHA256
  }

  @inline(never)
  private static func load() -> Self? {
    let file = OriginalFleetPhysicalData.folder.appendingPathComponent(resourceFileName)
    guard authenticResource(at: file), let bytes = try? Data(contentsOf: file),
      let root = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
      root["schemaVersion"] as? Int == 1,
      root["id"] as? String == CurrentNewtKitPhysicalSource.configurationID,
      root["status"] as? String == "NEW_AUTHORED_EQUIPPED_SOURCE_REQUIRES_LIVE_ADMISSION",
      root["parentCatalogueID"] as? String == "SH029", root["podCatalogueID"] as? String == "SH040",
      root["coordinateUnits"] as? String == "metres", root["podCount"] as? Int == 1,
      let pins = root["sourcePins"] as? [String: [String: Any]],
      authenticatedBundledPins(pins), OriginalCryostasisCapsule.source != nil
    else { return nil }
    return loadAuthenticatedSource(root)
  }

  @inline(never)
  private static func loadAuthenticatedSource(_ root: [String: Any]) -> Self? {
    guard let values = root["physicalExpectations"] as? [String: [String: Any]],
      let bare = mass(values["bareParent"]), let pod = mass(values["occupiedPod"]),
      let before = mass(values["carrierBefore"]), let after = mass(values["carrierAfter"]),
      let installed = mass(values["installedOccupied"]), let separated = mass(values["separatedComposite"]),
      let stowedParts = root["retainedPartsCarrier"] as? [[String: Any]],
      let loweredParts = root["retainedPartsLoweredCarrier"] as? [[String: Any]],
      let extendedParts = root["retainedPartsAfterStrokeCarrier"] as? [[String: Any]],
      let parts = parts(stowedParts, loweredParts, extendedParts),
      let releasedValues = root["releasedPartsLocal"] as? [[String: Any]],
      let released = releasedParts(releasedValues),
      let origin = vector(root["podCentreInCarrierMetres"]),
      let profile = root["personProfile"] as? [String: Any],
      let profileID = profile["modelID"] as? String,
      let personDimensions = vector(profile["dimensionsMetres"]),
      let personMass = number(profile["massKg"]),
      let release = root["release"] as? [String: Any], let service = root["service"] as? [String: Any],
      let direction = vector(release["directionCarrier"]),
      let rackLoweringMetres = number(release["rackLoweringMetres"]),
      let maximumForce = number(release["governedForceN"]),
      let maximumFriction = number(release["maximumGuideFrictionN"]),
      let dropDuration = number(release["rackLoweringDurationSeconds"]),
      let ejectDuration = number(release["ejectionDurationSeconds"]),
      let duration = number(release["conservativeDurationSeconds"]),
      let stroke = number(release["strokeMetres"]), let free = number(release["postStrokeFreeTravelMetres"]),
      let speed = number(release["relativeSpeedIncrementMetresPerSecond"]),
      let netForce = number(release["guaranteedNetForceN"]),
      let ratedMass = number(release["maximumRatedReleasedMassKg"]),
      let rodMass = number(release["movingRodMassKg"]),
      let angular = number(release["maximumIncludingRecoilAngularSpeed"]),
      let initialAngular = number(release["maximumInitialCarrierAngularSpeed"]),
      let carrierAcceleration = number(release["maximumCarrierAcceleration"]),
      let mechanical = number(release["initialStoredMechanicalJ"]),
      let dropWork = number(release["rackLoweringWorkDebitJ"]),
      let ejectWork = number(release["ejectionStrokeWorkDebitJ"]),
      let electrical = number(service["newlyRatedUsableElectricalJ"]),
      let startup = number(service["startupElectricalJ"]), let unlock = number(service["latchUnlockElectricalJ"]),
      let power = number(service["continuousPowerW"]), let oxygen = number(service["oxygenKg"]),
      let sorbent = number(service["sorbentCapacityKgCO2"]),
      let oxygenRate = number(service["oxygenConsumptionKgPerMinute"]),
      let co2Rate = number(service["carbonDioxideProductionKgPerMinute"]),
      let support = number(service["ratedSupportSeconds"])
    else { return nil }
    guard CurrentNewtKitPhysicalSource.bareParent.matches(massKilograms: bare.massKilograms,
        centreMetres: bare.centreOfMassMetres, inertiaAboutCentreOfMassKgM2: bare.inertiaKgM2),
      CurrentNewtKitPhysicalSource.occupiedPod.matches(massKilograms: pod.massKilograms,
        centreMetres: pod.centreOfMassMetres, inertiaAboutCentreOfMassKgM2: pod.inertiaKgM2),
      CurrentNewtKitPhysicalSource.carrierAfter.matches(massKilograms: after.massKilograms,
        centreMetres: after.centreOfMassMetres, inertiaAboutCentreOfMassKgM2: after.inertiaKgM2),
      personMass == CurrentNewtKitPhysicalSource.personMassKilograms,
      personDimensions == CurrentNewtKitPhysicalSource.personDimensionsMetres,
      profileID == CurrentNewtKitPhysicalSource.personProfileID,
      direction == CurrentNewtKitPhysicalSource.releaseDirectionInCarrier,
      origin == CurrentNewtKitPhysicalSource.podCentreInCarrierMetres,
      duration > 0, duration <= CurrentNewtKitPhysicalSource.maximumReleaseTimeSeconds,
      abs(duration - dropDuration - ejectDuration) <= 1e-9,
      rackLoweringMetres > 0, maximumForce > 0, maximumFriction >= 0,
      abs(maximumForce - maximumFriction - netForce) <= 1e-9,
      abs(maximumForce * stroke - ejectWork) <= 1e-6,
      dropDuration > 0, ejectDuration > 0, stroke > 0, free > 0, speed > 0,
      netForce > 0, ratedMass >= pod.massKilograms, rodMass > 0,
      dropWork > 0, ejectWork > 0, mechanical >= dropWork + ejectWork,
      electrical >= startup + power * support, startup >= unlock, oxygen >= oxygenRate * support / 60,
      sorbent >= co2Rate * support / 60
    else { return nil }
    let guideCharge = stowedParts.filter { ($0["id"] as? String)?.hasPrefix("rack-drop-guide-") == true }
      .compactMap { number($0["usableStoredMechanicalJ"]) }.reduce(0, +)
    let ejectCharge = stowedParts.filter { ($0["id"] as? String)?.hasPrefix("actuator-housing-") == true }
      .compactMap { number($0["usableStoredMechanicalJ"]) }.reduce(0, +)
    guard abs(guideCharge + ejectCharge - mechanical) <= 1e-6,
      guideCharge >= dropWork, ejectCharge >= ejectWork else { return nil }
    let result = Self(configuration: CurrentNewtKitPhysicalSource.configurationID,
      sourceSHA256: CurrentNewtKitPhysicalSource.sourceSHA256,
      personProfile: .init(id: profileID, sourceSHA256: CurrentNewtKitPhysicalSource.sourceSHA256,
        massKilograms: personMass, dimensionsMetres: personDimensions),
      bareParent: bare, podMass: pod, carrierBefore: before, carrierAfter: after,
      installedMass: installed, separatedMass: separated, retainedParts: parts,
      loadModel: CurrentNewtKitLoadModel.decode(root["ordinaryLoadModel"]), releasedParts: released,
      podOrigin: origin, direction: direction, rackLowering: .init(0, -rackLoweringMetres, 0),
      maximumForceNewtons: maximumForce, maximumGuideFrictionNewtons: maximumFriction, dropDuration: dropDuration, ejectDuration: ejectDuration,
      duration: duration, stroke: stroke, freeTravel: free, releaseSpeed: speed,
      ejectionAcceleration: netForce / (ratedMass + rodMass), maximumAngularSpeed: angular,
      maximumInitialAngularSpeed: initialAngular,
      maximumCarrierAcceleration: ((root["ordinaryLoadModel"] as? [String: Any])?["loadedReleaseBounds"]
        as? [String: Any]).flatMap { number($0["maximumCarrierAcceleration"]) } ?? carrierAcceleration,
      dropWork: dropWork, ejectWork: ejectWork,
      initialCharges: .init(guideMechanicalJoules: guideCharge,
        ejectionMechanicalJoules: ejectCharge, electricalJoules: electrical,
        oxygenKilograms: oxygen, sorbentCapacityKilogramsCO2: sorbent),
      startupElectricalJoules: startup, continuousPowerWatts: power,
      oxygenKgPerSecond: oxygenRate / 60, carbonDioxideKgPerSecond: co2Rate / 60,
      supportSeconds: support)
    guard result.massExpectationsAreCoherent() else { return nil }
    return result
  }

  var sourceQualifiedForBirth: Bool { loadModel != nil }

  func matches(_ issue: CurrentNewtKitIssue) -> Bool {
    issue.structurallyValid && issue.configuration == configuration
      && issue.sourceSHA256 == sourceSHA256 && issue.personProfile == personProfile
      && loadModel?.matches(issue.birthLoad, selectedPerson: issue.person) == true
  }

  func permitsBirth(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard loadModel != nil, request.currentNewtKitConfiguration == configuration,
      request.identity.producer == .ambient, request.identity.system == context.system,
      request.identity.visit == context.visit, request.identity.member == 0,
      request.identity.sequence > 0, request.identity.sequence < UInt64.max,
      request.catalogueShipID == "SH029", request.hull == .cobra,
      request.population == .civilian, request.priority == .ordinary,
      request.energy == nil, request.rock == nil, request.payload == nil, request.salvage == nil,
      let npc = request.npc, npc.role == .trader,
      npc.legalProvenance == .generated, npc.cargoProvenance == .generated,
      npc.routeProvenance == .generated,
      let parent = OriginalFleetRuntimeHullSource.source(for: "SH029"),
      parent.permitsAmbientTrader(context: context, position: request.position),
      EMPState.declaredNativeCrewCount(parent.ship) == 1,
      npc.resources == NPCResources.stock(parent.performance)
    else { return false }
    return true
  }

  private static func number(_ value: Any?) -> Double? {
    guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), n.doubleValue.isFinite
    else { return nil }
    return n.doubleValue
  }

  private static func vector(_ value: Any?) -> Vector3? {
    guard let a = value as? [Double], a.count == 3, a.allSatisfy(\.isFinite) else { return nil }
    return .init(a[0], a[1], a[2])
  }

  private static func mass(_ value: [String: Any]?) -> Mass? {
    guard let value, let m = number(value["massKg"]),
      let centre = vector(value["centreMetres"]),
      let inertia = value["inertiaAboutCentreOfMassKgM2"] as? [Double]
    else { return nil }
    let result = Mass(massKilograms: m, centreOfMassMetres: centre, inertiaKgM2: inertia)
    return result.structurallyValid ? result : nil
  }

  private static func parts(_ stowed: [[String: Any]], _ lowered: [[String: Any]],
    _ extended: [[String: Any]]) -> [Part]?
  {
    guard stowed.count == lowered.count, stowed.count == extended.count, !stowed.isEmpty else { return nil }
    var result: [Part] = []
    for i in stowed.indices {
      guard let id = stowed[i]["id"] as? String, lowered[i]["id"] as? String == id,
        extended[i]["id"] as? String == id,
        let a = mass(stowed[i]), let b = mass(lowered[i]), let c = mass(extended[i]),
        a.massKilograms == b.massKilograms, a.massKilograms == c.massKilograms,
        a.inertiaKgM2 == b.inertiaKgM2, a.inertiaKgM2 == c.inertiaKgM2,
        let mesh = CurrentNewtKitGeometry.mesh(part: stowed[i])
      else { return nil }
      result.append(.init(id: id, stowed: a, lowered: b, extended: c, mesh: mesh))
    }
    return Set(result.map(\.id)).count == result.count ? result : nil
  }

  private static func releasedParts(_ values: [[String: Any]]) -> [ReleasedPart]? {
    var result: [ReleasedPart] = []
    for value in values {
      guard let id = value["id"] as? String, let mass = CurrentNewtKitGeometry.mass(part: value) else {
        return nil
      }
      let interiorMass = id == "actual-identified-person" || id == "charged-free-atmosphere"
      let mesh = interiorMass ? nil : CurrentNewtKitGeometry.mesh(part: value)
      if !interiorMass && mesh == nil { return nil }
      let display = id == "unchanged-current-newt-dry" ? OriginalCryostasisCapsule.source?.displayMesh : mesh
      result.append(.init(id: id, mass: mass, collisionMesh: mesh, displayMesh: display))
    }
    return !result.isEmpty && Set(result.map(\.id)).count == result.count ? result : nil
  }

  private static func authenticatedBundledPins(_ pins: [String: [String: Any]]) -> Bool {
    let base = OriginalFleetPhysicalData.folder.deletingLastPathComponent()
    for relative in ["Ships/SH029.toml", "Ships/SH040.toml", "OriginalFleetPhysical/SH029.json",
      "OriginalFleetPhysical/SH040.json", "OriginalFleetShowroomModels/SH029.json",
      "OriginalFleetShowroomModels/SH040.json"]
    {
      guard let pin = pins["Sources/L337Core/Resources/" + relative],
        let expected = pin["sha256"] as? String, let count = pin["bytes"] as? Int,
        let file = try? base.appendingPathComponent(relative).resourceValues(
          forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
        file.isRegularFile == true, file.isSymbolicLink != true, file.fileSize == count,
        let bytes = try? Data(contentsOf: base.appendingPathComponent(relative)), bytes.count == count,
        ScriptPackLibrary.hash(bytes) == expected
      else { return false }
    }
    return true
  }
}
