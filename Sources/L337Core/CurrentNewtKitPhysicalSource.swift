import Foundation

/// One newly authored equipped Okapi definition. These source values neither issue
/// a kit nor create crew, fit an existing actor, or qualify an occupied release.
/// The bare Okapi and current cryopod assets remain separate and unchanged.
enum CurrentNewtKitPhysicalSource {
  static let configurationID = "SH029-current-newt-escape-kit-v1"
  static let parentCatalogueID = "SH029"
  static let podCatalogueID = "SH040"
  static let parentPhysicalSHA256 = "f64a24c2863cf047f852d99313ca7ee131ebcda40c3e140f43572d6fbf3aa827"
  static let podPhysicalSHA256 = "0d7cd491b77b6e14016daa8a3c5e622416963870f669f80d63ad3b4d74aaee17"
  static let podResourceSHA256 = "510a2059ce49a7d902c11ca65303264afa8ee103cd1a9e9ad823dbe05fee816c"
  static let parentBareKilograms = 45_520.0
  static let podBareKilograms = 248.0
  static let podCount = 1
  static let fittingSlot = ComponentFittingSlot.utility(.escapePod)
  static let equipmentUnits = 1
  static let utilityMounts = 1

  // New occupied source model for this configuration only. The actual born crew
  // identity must bind this allocation; the decorative figure is not that person.
  static let personMassKilograms = 100.0
  static let personProfileID = "SH029-newt-single-identified-person-100kg-authored-v1"
  static let personDimensionsMetres = Vector3(0.56, 0.38, 1.72)
  static let personCentreInPodMetres = Vector3(0, 0.12, -0.02)
  static let maximumDesignPersonKilograms = 120.0
  static let podCentreInCarrierMetres = Vector3(12.5, -3, -1)

  // New mechanical design limits. Actual stock charge and timed travel are required.
  static let releaseDirectionInCarrier = Vector3(1, 0, 0)
  static let actuatorStrokeMetres = 0.60
  static let postStrokeFreeTravelMetres = 0.30
  static let relativeReleaseSpeedMetresPerSecond = 3.0
  static let maximumReleaseTimeSeconds = 0.80
  static let governedReleaseForceNewtons = 4_000.0
  static let guideFrictionBoundNewtons = 500.0
  static let initialUsableMechanicalJoules = 6_000.0
  static let maximumInitialCarrierAngularSpeed = 0.04
  static let maximumCarrierAngularSpeedIncludingRecoil = 0.05
  static let maximumCarrierAcceleration = 0.5
  static let minimumReleaseSeparationMetres = 0.25

  static let resourceFileName = "SH029-current-newt-escape-kit-v1.json"
  static let sourceSHA256 = "7ba94c62149a2f0b7b882367c946a41516f49c6c58861d5e85eec255ba9d4b4a"
  static let sourceByteCount = 162569
  static let rackLoweringMetres = 0.40
  static let rackLoweringWorkJoules = 2_000.0
  static let ejectionWorkJoules = 2_400.0
  static let fullReleaseWorkJoules = 4_400.0
  static let remainingMechanicalJoules = 1_600.0
  static let minimumMechanismClearanceMetres = 0.05

  /// Row-major tensor about the phase COM, in kg m^2, in its source frame.
  /// These comparisons are source checks; G3 must also join actual stock,
  /// person, timed native motion, energy and live custody before admission.
  struct PhysicalExpectation: Sendable {
    let massKilograms: Double
    let centreMetres: Vector3
    let inertiaAboutCentreOfMassKgM2: [Double]

    func matches(massKilograms mass: Double, centreMetres centre: Vector3,
      inertiaAboutCentreOfMassKgM2 tensor: [Double]) -> Bool
    {
      let coordinates = [centre.x, centre.y, centre.z]
      let expected = [centreMetres.x, centreMetres.y, centreMetres.z]
      return mass.isFinite && abs(mass - massKilograms) <= 1e-8
        && coordinates.allSatisfy(\.isFinite)
        && zip(coordinates, expected).allSatisfy { pair in abs(pair.0 - pair.1) <= 1e-9 }
        && tensor.count == 9 && tensor.allSatisfy(\.isFinite)
        && zip(tensor, inertiaAboutCentreOfMassKgM2).allSatisfy { pair in abs(pair.0 - pair.1) <= 1e-6 }
    }
  }

  static let bareParent = PhysicalExpectation(
    massKilograms: 45520.0,
    centreMetres: Vector3(-1.3986174459247845e-16, -1.4257199113686845, -2.1596843453779724),
    inertiaAboutCentreOfMassKgM2: [
      4171309.2074277224, 25.521504283102313, 8.650912642919666e-11,
      25.521504283102313, 5394472.820061804, -149467.49059116415,
      8.650912642919666e-11, -149467.49059116415, 1685907.5230456782,
    ])

  static let carrierAfter = PhysicalExpectation(
    massKilograms: 45925.26639396747,
    centreMetres: Vector3(0.09588544862181851, -1.4457515135577765, -2.149459091201536),
    inertiaAboutCentreOfMassKgM2: [
      4174177.356742373, 10004.560940004292, -5057.59222653345,
      10004.560940004292, 5443059.550056043, -148410.64636419347,
      -5057.59222653345, -148410.64636419347, 1735898.4313435045,
    ])

  static let carrierBefore = PhysicalExpectation(
    massKilograms: 45925.26639396747,
    centreMetres: Vector3(0.09578588930819847, -1.4442352624164194, -2.149459091201536),
    inertiaAboutCentreOfMassKgM2: [
      4173850.512383561, 9180.183217983329, -5052.3881507634915,
      9180.183217983329, 5442957.092723802, -148490.68807164673,
      -5052.3881507634915, -148490.68807164673, 1735469.1296524506,
    ])

  static let dryPod = PhysicalExpectation(
    massKilograms: 248.0,
    centreMetres: Vector3(-1.432429374083494e-18, -0.08877245895850502, -0.004039220176708969),
    inertiaAboutCentreOfMassKgM2: [
      159.01711421642565, 4.095609550727572e-17, 5.5700885745886595e-05,
      4.095609550727572e-17, 162.14744347245028, -0.41661110632905385,
      5.5700885745886595e-05, -0.4166111063290544, 41.252894705227675,
    ])

  static let installedOccupied = PhysicalExpectation(
    massKilograms: 46277.76639396747,
    centreMetres: Vector3(0.1902568704118494, -1.4563089691565154, -2.1407895370223393),
    inertiaAboutCentreOfMassKgM2: [
      4175372.156896015, 16057.260769499388, -9990.484542206941,
      16057.260769499388, 5497411.376965904, -147860.01369506065,
      -9990.484542206941, -147860.01369506065, 1790206.4795492762,
    ])

  static let occupiedPod = PhysicalExpectation(
    massKilograms: 352.5,
    centreMetres: Vector3(-0.0016439134615244969, -0.02932513483470055, -0.011281493911556948),
    inertiaAboutCentreOfMassKgM2: [
      189.56367019592184, -0.0012526950389259305, 0.006593095282574485,
      -0.0012526950389259305, 191.2642833301962, -0.4316687962967723,
      0.006593095282574485, -0.43166879629677274, 48.58352498778836,
    ])

  static let retainedExtended = PhysicalExpectation(
    massKilograms: 405.266393967464,
    centreMetres: Vector3(10.865852280896583, -3.6957247292512667, -1.0009464658276694),
    inertiaAboutCentreOfMassKgM2: [
      258.9327718202702, 71.13664681002835, -0.04249008742839265,
      71.13664681002835, 621.1447811130931, 0.26238031722746813,
      -0.04249008742839265, 0.26238031722746813, 494.78390758908307,
    ])

  static let retainedStowed = PhysicalExpectation(
    massKilograms: 405.266393967464,
    centreMetres: Vector3(10.854570101895163, -3.523901359182796, -1.0009464658276694),
    inertiaAboutCentreOfMassKgM2: [
      233.57954555775103, 6.226186329902182, -0.08974481231600605,
      6.226186329902182, 617.1230989288636, 0.19647389091558332,
      -0.08974481231600605, 0.19647389091558332, 465.40899914233415,
    ])

  static let separatedComposite = PhysicalExpectation(
    massKilograms: 46277.76639396747,
    centreMetres: Vector3(0.19721101520052167, -1.457813670939099, -2.1407895370223393),
    inertiaAboutCentreOfMassKgM2: [
      4175697.3205723306, 17373.566937040538, -10353.985404955256,
      17373.566937040538, 5505605.746810138, -147780.57568540293,
      -10353.985404955256, -147780.57568540293, 1798726.0130698262,
    ])

  // Existing latches unlock before the powered stroke. These are source-profile
  // clock offsets, never proof that native movement or custody transfer occurred.
  static let coastValidationAfterStart = 0.7450115701345215
  static let poweredStrokeCompleteAfterStart = 0.6450115701345215
  static let unlockAfterStart = 0.2821027929916644

  static let retainedAtUnlock = PhysicalExpectation(
    massKilograms: 405.266393967464,
    centreMetres: Vector3(10.854570101895163, -3.6957247292512667, -1.0009464658276694),
    inertiaAboutCentreOfMassKgM2: [
      258.9327718202702, 74.1836176787841, -0.08974481231600605,
      74.1836176787841, 617.1230989288636, 0.26238031722746813,
      -0.08974481231600605, 0.26238031722746813, 490.76222540485327,
    ])

  static let carrierAtUnlock = PhysicalExpectation(
    massKilograms: 45925.26639396747,
    centreMetres: Vector3(0.09578588930819847, -1.4457515135577765, -2.149459091201536),
    inertiaAboutCentreOfMassKgM2: [
      4174177.356742373, 9997.320385338608, -5052.3881507634915,
      9997.320385338608, 5442957.092723802, -148410.64636419347,
      -5052.3881507634915, -148410.64636419347, 1735795.9740112629,
    ])

  static let installedAtUnlock = PhysicalExpectation(
    massKilograms: 46277.76639396747,
    centreMetres: Vector3(0.1902568704118494, -1.457813670939099, -2.1407895370223393),
    inertiaAboutCentreOfMassKgM2: [
      4175697.3205723306, 16867.81952211142, -9990.484542206941,
      16867.81952211142, 5497411.376965904, -147780.57568540293,
      -9990.484542206941, -147780.57568540293, 1790531.6432255919,
    ])
}
