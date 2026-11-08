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
  let parentCatalogueID: String
  let originalNativeCrew: Int
  let selectedPersonOrdinal: Int
  let selectedPersonComponentID: String
  let dryPodComponentID: String
  let baseParts: [FixedPart]
  let personSlots: [PersonSlot]
  let carrierCellService: CarrierCellService?
  let bisonCommissioning: CurrentBisonWideShoeCommissioning?
  let movingDriveComponentIDs: Set<String>
  let driveFollowerComponentIDs: Set<String>
  let driveContactPairs: [DriveContactPair]
  let centreTolerance: Double
  let inertiaTolerance: Double
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
  static let bison: Self? = loadBison()

  static var resourceFileName: String { CurrentNewtKitPhysicalSource.resourceFileName }

  static func authenticResource(at file: URL) -> Bool {
    let expectedBytes: Int
    let expectedSHA256: String
    switch file.lastPathComponent {
    case CurrentNewtKitPhysicalSource.resourceFileName:
      expectedBytes = CurrentNewtKitPhysicalSource.sourceByteCount
      expectedSHA256 = CurrentNewtKitPhysicalSource.sourceSHA256
    case CurrentBisonWideShoePhysicalSource.resourceFileName:
      expectedBytes = CurrentBisonWideShoePhysicalSource.sourceByteCount
      expectedSHA256 = CurrentBisonWideShoePhysicalSource.sourceSHA256
    case CurrentBisonWideShoePhysicalSource.commissioningFileName:
      expectedBytes = CurrentBisonWideShoePhysicalSource.commissioningByteCount
      expectedSHA256 = CurrentBisonWideShoePhysicalSource.commissioningSHA256
    default: return false
    }
    guard let facts = try? file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
      facts.isRegularFile == true, facts.isSymbolicLink != true, facts.fileSize == expectedBytes,
      let bytes = try? Data(contentsOf: file), bytes.count == expectedBytes else { return false }
    return ScriptPackLibrary.hash(bytes) == expectedSHA256
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
      authenticatedBundledPins(pins, parent: "SH029"), OriginalCryostasisCapsule.source != nil
    else { return nil }
    return loadAuthenticatedSource(root)
  }

  @inline(never)
  private static func loadAuthenticatedSource(_ root: [String: Any]) -> Self? {
    guard let parentHull = OriginalFleetRuntimeHullSource.source(for: "SH029"),
      let values = root["physicalExpectations"] as? [String: [String: Any]],
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
    let selectedProfile = CurrentNewtKitIssue.PersonProfile(id: profileID,
      sourceSHA256: CurrentNewtKitPhysicalSource.sourceSHA256,
      massKilograms: personMass, dimensionsMetres: personDimensions)
    guard let personPart = released.first(where: { $0.id == "actual-identified-person" }) else { return nil }
    let result = Self(configuration: CurrentNewtKitPhysicalSource.configurationID,
      parentCatalogueID: "SH029", originalNativeCrew: 1, selectedPersonOrdinal: 0,
      selectedPersonComponentID: "actual-identified-person", dryPodComponentID: "unchanged-current-newt-dry",
      baseParts: [.init(id: "SH029-bare-carrier", mass: bare,
        collisionMesh: parentHull.mesh, displayMesh: parentHull.mesh)],
      personSlots: [.init(ordinal: 0, componentID: personPart.id, profile: selectedProfile,
        massInCarrier: CurrentNewtKitMass.translated(personPart.mass, by: origin))],
      carrierCellService: nil, bisonCommissioning: nil,
      movingDriveComponentIDs: Set(parts.filter { $0.lowered != $0.extended }.map(\.id)),
      driveFollowerComponentIDs: [],
      driveContactPairs: [
        .init(driverID: "moving-rod--1.7612814939115569", shoeID: "portable-thrust-shoe--0.75"),
        .init(driverID: "moving-rod--0.26128149391155686", shoeID: "portable-thrust-shoe-0.75"),
      ], centreTolerance: 1e-9, inertiaTolerance: 1e-6,
      sourceSHA256: CurrentNewtKitPhysicalSource.sourceSHA256,
      personProfile: selectedProfile,
      bareParent: bare, podMass: pod, carrierBefore: before, carrierAfter: after,
      installedMass: installed, separatedMass: separated, retainedParts: parts,
      loadModel: CurrentNewtKitLoadModel.decode(root["ordinaryLoadModel"], people: [0: selectedProfile]), releasedParts: released,
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
    guard result.driveRolesAreCoherent, result.massExpectationsAreCoherent() else { return nil }
    return result
  }

  var sourceQualifiedForBirth: Bool {
    loadModel != nil && personSlots.count == originalNativeCrew
      && (parentCatalogueID == "SH029" || carrierCellService != nil)
  }

  func matches(_ issue: CurrentNewtKitIssue) -> Bool {
    issue.structurallyValid && issue.configuration == configuration
      && issue.sourceSHA256 == sourceSHA256 && issue.personProfile == personProfile
      && issue.person.ordinal == selectedPersonOrdinal
      && issue.birthLoad.people.count == originalNativeCrew
      && Set(issue.birthLoad.people.map { $0.identity.ordinal }) == Set(0..<originalNativeCrew)
      && issue.birthLoad.people.allSatisfy({ $0.identity.source == issue.birthActor })
      && matchesCarrierCells(issue)
      && loadModel?.matches(issue.birthLoad, selectedPerson: issue.person) == true
  }

  func permitsBirth(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    sourceQualifiedForBirth && permitsBirthDefinition(request, context: context)
  }

  /// Native constructor eligibility for an unobserved unit draft only. This is
  /// not the qualified birth predicate and cannot publish a body or issue stock.
  func permitsBirthDefinition(_ request: SpawnRequest, context: EncounterContext) -> Bool {
    guard loadModel != nil, personSlots.count == originalNativeCrew,
      request.currentNewtKitConfiguration == configuration,
      request.identity.producer == .ambient, request.identity.system == context.system,
      request.identity.visit == context.visit, request.identity.member == 0,
      request.identity.sequence > 0, request.identity.sequence < UInt64.max,
      request.catalogueShipID == parentCatalogueID, request.hull == .cobra,
      request.population == .civilian, request.priority == .ordinary,
      request.energy == nil, request.rock == nil, request.payload == nil, request.salvage == nil,
      let npc = request.npc, npc.role == .trader,
      npc.legalProvenance == .generated, npc.cargoProvenance == .generated,
      npc.routeProvenance == .generated,
      let parent = OriginalFleetRuntimeHullSource.source(for: parentCatalogueID),
      EMPState.declaredNativeCrewCount(parent.ship) == originalNativeCrew,
      npc.resources == NPCResources.stock(parent.performance)
    else { return false }
    if parentCatalogueID == "SH005" { return OriginalBisonActivation.matchesRequest(request, context: context) }
    return parent.permitsAmbientTrader(context: context, position: request.position)
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

  private static func releasedParts(_ values: [[String: Any]],
    personID: String = "actual-identified-person", dryID: String = "unchanged-current-newt-dry") -> [ReleasedPart]? {
    var result: [ReleasedPart] = []
    for value in values {
      guard let id = value["id"] as? String, let mass = CurrentNewtKitGeometry.mass(part: value) else {
        return nil
      }
      let interiorMass = id == personID || id == "charged-free-atmosphere"
      let mesh = interiorMass ? nil : CurrentNewtKitGeometry.mesh(part: value)
      if !interiorMass && mesh == nil { return nil }
      let display = id == dryID ? OriginalCryostasisCapsule.source?.displayMesh : mesh
      result.append(.init(id: id, mass: mass, collisionMesh: mesh, displayMesh: display))
    }
    return !result.isEmpty && Set(result.map(\.id)).count == result.count ? result : nil
  }

  private static func authenticatedBundledPins(_ pins: [String: [String: Any]], parent: String) -> Bool {
    let base = OriginalFleetPhysicalData.folder.deletingLastPathComponent()
    var paths = ["Ships/" + parent + ".toml", "Ships/SH040.toml", "OriginalFleetPhysical/SH040.json",
      "OriginalFleetShowroomModels/" + parent + ".json", "OriginalFleetShowroomModels/SH040.json"]
    if parent == "SH029" { paths.append("OriginalFleetPhysical/SH029.json") }
    for relative in paths {
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

extension CurrentNewtKitSource {
  @inline(never)
  private static func loadBison() -> Self? {
    let directory = OriginalFleetPhysicalData.folder
    let file = directory.appendingPathComponent(CurrentBisonWideShoePhysicalSource.resourceFileName)
    let commissioningFile = directory.appendingPathComponent(CurrentBisonWideShoePhysicalSource.commissioningFileName)
    guard authenticResource(at: file), authenticResource(at: commissioningFile),
      let bytes = try? Data(contentsOf: file), let commissioningBytes = try? Data(contentsOf: commissioningFile)
    else { return nil }
    return decodeBisonSource(bytes, commissioningBytes: commissioningBytes)
  }

  /// Pure exact-source decoding for review/tests. It cannot issue stock or
  /// observe/commission a physical unit. Birth still requires its actual owner.
  @inline(never)
  static func decodeBisonSource(_ bytes: Data, commissioningBytes: Data) -> Self? {
    guard bytes.count == CurrentBisonWideShoePhysicalSource.sourceByteCount,
      ScriptPackLibrary.hash(bytes) == CurrentBisonWideShoePhysicalSource.sourceSHA256,
      let commissioning = CurrentBisonWideShoeCommissioning.decode(commissioningBytes),
      let root = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
      root["schemaVersion"] as? Int == 1,
      root["id"] as? String == CurrentBisonWideShoePhysicalSource.configurationID,
      root["parentCatalogueID"] as? String == "SH005",
      root["status"] as? String == "NEW_AUTHORED_CONFIG_HUMAN_REVIEW_AND_NATIVE_ADMISSION_PENDING",
      root["originalNativeComplement"] as? Int == 12,
      root["ordinaryProducerRole"] as? String == "trader",
      root["existingProducerWeight"] as? Int == 4,
      let pins = root["sourcePins"] as? [String: [String: Any]],
      authenticatedBundledPins(pins, parent: "SH005"), OriginalCryostasisCapsule.source != nil
    else { return nil }
    return decodeAuthenticatedBisonSource(root, commissioning: commissioning)
  }

  @inline(never)
  private static func decodeAuthenticatedBisonSource(
    _ root: [String: Any], commissioning: CurrentBisonWideShoeCommissioning
  ) -> Self? {
    guard let hull = OriginalFleetRuntimeHullSource.source(for: "SH005"),
      hull.mesh.vertices.count == 296,
      hull.mesh.faces.reduce(0, { $0 + max(0, $1.count - 2) }) == 492,
      EMPState.declaredNativeCrewCount(hull.ship) == 12,
      hull.contract.sourceSHA256 == CurrentBisonWideShoePhysicalSource.r3SHA256,
      let stockValues = root["stockComponents"] as? [[String: Any]], stockValues.count == 107,
      let intrinsicValues = root["intrinsicHardware"] as? [[String: Any]], intrinsicValues.count == 24,
      let atmospheres = root["chargedCrewCellAtmosphere"] as? [[String: Any]], atmospheres.count == 12,
      let reserveValue = root["roundingReserve"] as? [String: Any],
      let reserve = CurrentNewtKitGeometry.mass(part: reserveValue),
      let reserveID = reserveValue["id"] as? String,
      let profileValues = root["crewPhysicalProfiles"] as? [[String: Any]], profileValues.count == 12,
      let stowed = root["retainedKitPartsStowed"] as? [[String: Any]],
      let extended = root["retainedKitPartsExtended"] as? [[String: Any]],
      let retained = parts(stowed, stowed, extended),
      let releasedValues = root["releasedPartsLocal"] as? [[String: Any]],
      let personID = root["selectedPersonPhysicalComponentID"] as? String,
      personID == CurrentBisonWideShoePhysicalSource.selectedPersonPhysicalComponentID,
      let dryID = root["currentDryNewtPhysicalComponentID"] as? String,
      dryID == CurrentBisonWideShoePhysicalSource.currentDryNewtPhysicalComponentID,
      let released = releasedParts(releasedValues, personID: personID, dryID: dryID),
      let pod = mass(root["releasedOccupiedPod"] as? [String: Any]),
      let origin = vector(root["podCentreInCarrierMetres"]),
      origin == CurrentBisonWideShoePhysicalSource.podCentreInCarrierMetres,
      let phases = root["referencePhysicalPhases"] as? [String: [String: Any]], phases.count == 7,
      let installed = mass(phases["bornAll12"]),
      let release = root["release"] as? [String: Any],
      let service = root["newServiceProfile"] as? [String: Any],
      let direction = vector(release["axisCarrier"]), direction == .init(1, 0, 0),
      number(release["unlockAfterStartSeconds"]) == 0,
      let duration = number(release["conservativeDurationSeconds"]), duration > 0, duration <= 0.5,
      let stroke = number(release["strokeMetres"]), stroke == 0.6,
      let free = number(release["freeTravelMetres"]), free == 0.3,
      let speed = number(release["relativeSpeedIncrement"]), speed == 3,
      let force = number(release["governedForceN"]), force == 4000,
      let friction = number(release["guideFrictionBoundN"]), friction == 500,
      let movingMass = number(release["movingEjectionMassKg"]), movingMass > 0,
      let ratedMass = number(release["maximumRatedOccupiedPodKg"]), ratedMass >= pod.massKilograms,
      let initialMechanical = number(release["initialMechanicalJ"]), initialMechanical == 3000,
      let debit = number(release["workDebitJ"]), abs(debit - force * stroke) <= 1e-8,
      let electrical = number(service["batteryUsableJ"]),
      let startup = number(service["startupJ"]),
      let power = number(service["continuousW"]),
      let oxygen = number(service["oxygenKg"]),
      let sorbent = number(service["sorbentCapacityKgCO2"]),
      let oxygenRate = number(service["oxygenKgPerMinute"]),
      let carbonRate = number(service["co2KgPerMinute"]),
      let support = number(service["ratedSupportSeconds"]),
      electrical > startup + power * support,
      oxygen >= oxygenRate * support / 60, sorbent >= carbonRate * support / 60,
      let angular = number(release["maximumTotalAngularSpeed"]), angular == 0.05,
      let initialAngular = number(release["maximumInitialAngularSpeed"]), initialAngular == 0.04,
      let acceleration = number(release["maximumCarrierAcceleration"]), acceleration == 0.5
    else { return nil }
    let stockMasses = stockValues.compactMap(CurrentNewtKitGeometry.mass)
    guard stockMasses.count == stockValues.count,
      let stockMass = CurrentNewtKitMass.combined(stockMasses),
      let intrinsic = fixedParts(intrinsicValues, collision: true),
      let atmosphereParts = fixedParts(atmospheres, collision: false),
      let emptyMass = CurrentNewtKitMass.combined([stockMass, reserve] + intrinsic.map(\.mass)),
      CurrentBisonWideShoePhysicalSource.newEmptyCarrier.matches(massKilograms: emptyMass.massKilograms,
        centreMetres: emptyMass.centreOfMassMetres, inertiaKgM2: emptyMass.inertiaKgM2),
      CurrentBisonWideShoePhysicalSource.occupiedPod.matches(massKilograms: pod.massKilograms,
        centreMetres: pod.centreOfMassMetres, inertiaKgM2: pod.inertiaKgM2),
      let slots = bisonPersonSlots(profileValues),
      let selected = slots.first(where: { $0.ordinal == CurrentBisonWideShoePhysicalSource.selectedPersonOrdinal }),
      let inventory = CurrentNewtKitLoadModel.decodeBison(root["actualInventoryLoadModel"],
        people: Dictionary(uniqueKeysWithValues: slots.map { ($0.ordinal, $0.profile) })),
      commissioning.matchesParts(retained: retained, released: released)
    else { return nil }
    let base: [FixedPart] = [.init(id: "SH005-bare-carrier", mass: stockMass,
      collisionMesh: hull.mesh, displayMesh: hull.mesh)] + intrinsic + atmosphereParts
      + [.init(id: reserveID, mass: reserve, collisionMesh: nil, displayMesh: nil)]
    let people = slots.filter { $0.ordinal != selected.ordinal }.map(\.massInCarrier)
    guard Set(base.map(\.id)).count == base.count,
      let carrierBefore = CurrentNewtKitMass.combined(base.map(\.mass) + people + retained.map(\.stowed)),
      let carrierAfter = CurrentNewtKitMass.combined(base.map(\.mass) + people + retained.map(\.extended)),
      let separated = CurrentNewtKitMass.combined([carrierAfter,
        CurrentNewtKitMass.translated(pod, by: origin + direction * (stroke + free))])
    else { return nil }
    let moving = retained.filter { $0.stowed.centreOfMassMetres != $0.extended.centreOfMassMetres }
    let caps = moving.filter { $0.id.hasPrefix("new-moving-tube-cap-") }
    let followers = moving.filter { $0.id.hasPrefix("new-load-catch-") }
    let shoes = released.filter { $0.id.hasPrefix("new-Bison-conformal-thrust-shoe-") }
    let contacts = commissioning.driveContactPairs.map {
      DriveContactPair(driverID: $0.capComponentID, shoeID: $0.shoeComponentID)
    }
    let stored = stowed.filter { ($0["id"] as? String)?.hasPrefix("new-ejection-housing-") == true }
      .compactMap { number($0["usableStoredMechanicalJ"]) }.reduce(0, +)
    guard caps.count == 2, shoes.count == 2, moving.count == 6,
      followers.count == 2, followers.allSatisfy({ $0.stowed.massKilograms == 4 }),
      abs(moving.reduce(0) { $0 + $1.stowed.massKilograms } - movingMass) <= 1e-8,
      stored == initialMechanical else { return nil }
    let result = Self(configuration: CurrentBisonWideShoePhysicalSource.configurationID,
      parentCatalogueID: "SH005", originalNativeCrew: 12, selectedPersonOrdinal: selected.ordinal,
      selectedPersonComponentID: personID, dryPodComponentID: dryID, baseParts: base,
      // These expected unit definitions do not supply actual private unit IDs,
      // observed gas/thermal/seal/operative state or commissioning custody.
      personSlots: slots, carrierCellService: nil, bisonCommissioning: commissioning,
      movingDriveComponentIDs: Set(moving.map(\.id)),
      driveFollowerComponentIDs: Set(followers.map(\.id)), driveContactPairs: contacts,
      centreTolerance: 1e-8, inertiaTolerance: 1e-4,
      sourceSHA256: CurrentBisonWideShoePhysicalSource.sourceSHA256,
      personProfile: selected.profile, bareParent: stockMass, podMass: pod,
      carrierBefore: carrierBefore, carrierAfter: carrierAfter, installedMass: installed,
      separatedMass: separated, retainedParts: retained, loadModel: inventory, releasedParts: released,
      podOrigin: origin, direction: direction, rackLowering: .init(0, 0, 0),
      maximumForceNewtons: force, maximumGuideFrictionNewtons: friction,
      dropDuration: 0, ejectDuration: duration, duration: duration,
      stroke: stroke, freeTravel: free, releaseSpeed: speed,
      ejectionAcceleration: (force - friction) / (ratedMass + movingMass),
      maximumAngularSpeed: angular, maximumInitialAngularSpeed: initialAngular,
      maximumCarrierAcceleration: acceleration, dropWork: 0, ejectWork: debit,
      initialCharges: .init(guideMechanicalJoules: 0, ejectionMechanicalJoules: stored,
        electricalJoules: electrical, oxygenKilograms: oxygen, sorbentCapacityKilogramsCO2: sorbent),
      startupElectricalJoules: startup, continuousPowerWatts: power,
      oxygenKgPerSecond: oxygenRate / 60, carbonDioxideKgPerSecond: carbonRate / 60,
      supportSeconds: support)
    guard result.driveRolesAreCoherent, result.massExpectationsAreCoherent(), result.bisonReferencePhasesMatch(phases) else { return nil }
    return result
  }

  private static func fixedParts(_ values: [[String: Any]], collision: Bool) -> [FixedPart]? {
    var result: [FixedPart] = []
    for value in values {
      guard let id = value["id"] as? String, let mass = CurrentNewtKitGeometry.mass(part: value) else { return nil }
      let mesh = collision ? CurrentNewtKitGeometry.mesh(part: value) : nil
      if collision && mesh == nil { return nil }
      result.append(.init(id: id, mass: mass, collisionMesh: mesh, displayMesh: mesh))
    }
    return Set(result.map(\.id)).count == result.count ? result : nil
  }

  private static func bisonPersonSlots(_ values: [[String: Any]]) -> [PersonSlot]? {
    var slots: [PersonSlot] = []
    for value in values {
      guard let ordinal = value["ordinal"] as? Int,
        let expected = CurrentBisonWideShoePhysicalSource.people.first(where: { $0.ordinal == ordinal }),
        let id = value["id"] as? String, id == "original-person-ordinal-" + String(ordinal),
        let profileID = value["profileID"] as? String, profileID == expected.id,
        let mass = CurrentNewtKitGeometry.mass(part: value), mass.massKilograms == expected.massKilograms,
        mass.centreOfMassMetres == expected.centreInCarrierMetres,
        let dimensions = vector(value["dimensionsMetres"]), dimensions == CurrentBisonWideShoePhysicalSource.personDimensionsMetres
      else { return nil }
      slots.append(.init(ordinal: ordinal, componentID: id,
        profile: .init(id: profileID, sourceSHA256: CurrentBisonWideShoePhysicalSource.sourceSHA256,
          massKilograms: mass.massKilograms, dimensionsMetres: dimensions), massInCarrier: mass))
    }
    guard Set(slots.map(\.ordinal)) == Set(0..<12) else { return nil }
    return slots.sorted { $0.ordinal < $1.ordinal }
  }

  private func bisonReferencePhasesMatch(_ phases: [String: [String: Any]]) -> Bool {
    for value in phases.values {
      guard let aboard = value["aboardOriginalOrdinals"] as? [Int],
        let pod = value["podOriginalOrdinals"] as? [Int],
        let stage = value["retainedMechanismStage"] as? String,
        let expected = Self.mass(value) else { return false }
      let deceased = value["deceasedOriginalOrdinals"] as? [Int] ?? []
      let retained = stage == "stowed" ? retainedParts.map(\.stowed) : retainedParts.map(\.extended)
      guard stage == "stowed" || stage == "extended" else { return false }
      let present = Set(aboard + deceased)
      var parts = baseParts.map(\.mass) + retained
      parts += personSlots.filter { $0.ordinal != selectedPersonOrdinal && present.contains($0.ordinal) }.map(\.massInCarrier)
      if present.contains(selectedPersonOrdinal) {
        parts.append(CurrentNewtKitMass.translated(podMass, by: podOrigin))
      } else if pod != [selectedPersonOrdinal] { return false }
      guard let aggregate = CurrentNewtKitMass.combined(parts), matchesMass(aggregate, expected) else { return false }
    }
    return true
  }
}
