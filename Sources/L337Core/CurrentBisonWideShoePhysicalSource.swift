import Foundation

/// Exact v2 full-material physical model for one fitted Bison and its twelve original
/// people. Actual ordinary birth, stock issue, identity, native motion and custody
/// must independently join this source. New engineering requires human review.
enum CurrentBisonWideShoePhysicalSource {
  static let configurationID = "SH005-current-newt-person7-wide-shoes-v2"
  static let parentCatalogueID = "SH005"
  static let resourceFileName = "SH005-current-newt-person7-wide-shoes-v2.json"
  static let sourceSHA256 = "48c747bffefc6abccee84e9eacaea361f318fe3afd6c52f82ce463a34b648a5e"
  static let sourceByteCount = 313350
  static let commissioningFileName = "SH005-current-newt-person7-wide-shoes-commissioning-v2.json"
  static let commissioningSHA256 = "574c69e938a2d801713b1c4292b9146609b95f6b7c5656c0d64e12dcde8fa683"
  static let commissioningByteCount = 49893
  static let r3SHA256 = "abb18a2f94877670d18008dddde590a16a2322bdcc2311cd11b3f241fac43bcd"
  static let originalNativeCrew = 12
  static let selectedPersonOrdinal = 7
  static let selectedPersonPhysicalComponentID = "original-person-ordinal-7"
  static let currentDryNewtPhysicalComponentID = "unchanged-current-Newt-dry"
  static let podQuantity = 1
  static let equipmentUnits = 1
  static let utilityMounts = 1
  static let newEngineeringHumanReviewPending = true
  static let personDimensionsMetres = Vector3(0.56, 0.38, 1.72)
  static let selectedPersonCentreInPodMetres = Vector3(0, 0.12, -0.02)
  static let podCentreInCarrierMetres = Vector3(37.56279264214047, -2.5, 15.0)
  static let unlockAfterStart = 0
  static let poweredStrokeCompleteAfterStart = 0.3782161142857142
  static let coastValidationAfterStart = 0.47821611428571426

  struct PersonModel: Sendable {
    let ordinal: Int
    let id: String
    let massKilograms: Double
    let centreInCarrierMetres: Vector3
  }

  // Poses are in this configuration's carrier frame. The issue wire contains
  // profile ID/hash/mass/dimensions; it does not hide a position alias.
  static let people: [PersonModel] = [
    .init(ordinal: 0, id: "SH005-person-0-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(-2.0, 9.66, -6.0)),
    .init(ordinal: 1, id: "SH005-person-1-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(0.0, 9.66, -6.0)),
    .init(ordinal: 2, id: "SH005-person-2-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(2.0, 9.66, -6.0)),
    .init(ordinal: 3, id: "SH005-person-3-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(-2.0, 9.66, -2.0)),
    .init(ordinal: 4, id: "SH005-person-4-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(0.0, 9.66, -2.0)),
    .init(ordinal: 5, id: "SH005-person-5-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(2.0, 9.66, -2.0)),
    .init(ordinal: 6, id: "SH005-person-6-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(-2.0, 9.66, 2.0)),
    .init(ordinal: 7, id: "SH005-person-7-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(37.56279264214047, -2.38, 14.98)),
    .init(ordinal: 8, id: "SH005-person-8-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(2.0, 9.66, 2.0)),
    .init(ordinal: 9, id: "SH005-person-9-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(-2.0, 9.66, 6.0)),
    .init(ordinal: 10, id: "SH005-person-10-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(0.0, 9.66, 6.0)),
    .init(ordinal: 11, id: "SH005-person-11-100kg-authored-v1", massKilograms: 100.0,
      centreInCarrierMetres: Vector3(2.0, 9.66, 6.0)),
  ]

  /// Numeric comparisons of model values, not an actor/stock admission API.
  /// Absolute inertia tolerance covers different summation orders at this scale.
  struct MassReference: Sendable {
    let massKilograms: Double
    let centreMetres: Vector3
    let inertiaKgM2: [Double]

    func matches(massKilograms mass: Double, centreMetres centre: Vector3,
      inertiaKgM2 tensor: [Double]) -> Bool
    {
      let actual = [centre.x, centre.y, centre.z]
      let expected = [centreMetres.x, centreMetres.y, centreMetres.z]
      return mass.isFinite && abs(mass - massKilograms) <= 1e-8
        && actual.allSatisfy(\.isFinite)
        && zip(actual, expected).allSatisfy { pair in abs(pair.0 - pair.1) <= 1e-8 }
        && tensor.count == 9 && tensor.allSatisfy(\.isFinite)
        && zip(tensor, inertiaKgM2).allSatisfy { pair in abs(pair.0 - pair.1) <= 1e-4 }
    }
  }

  static let newEmptyCarrier = MassReference(
    massKilograms: 499641.0,
    centreMetres: Vector3(0.0003517984594819346, 1.5925934011047618, -7.633053954657303),
    inertiaKgM2: [
      774523416.4985164, -1424.5098437610516, -4831.912975592447,
      -1424.5098437610516, 916183499.3170886, -1704331.5690859384,
      -4831.912975592447, -1704331.5690859384, 180549121.94190487,
    ])

  static let retainedStowed = MassReference(
    massKilograms: 1289.155268896322,
    centreMetres: Vector3(32.03107592265731, -2.5285793125205993, 14.988718506088443),
    inertiaKgM2: [
      861.3604527892192, 1.458003180182401, 2.842170943040401e-14,
      1.458003180182401, 4942.2893929587235, 3.3480163086352377e-16,
      2.842170943040401e-14, 3.3480163086352377e-16, 4411.981073722076,
    ])

  static let retainedExtended = MassReference(
    massKilograms: 1289.155268896322,
    centreMetres: Vector3(32.051246153992004, -2.5285793125205993, 14.988718506088443),
    inertiaKgM2: [
      861.3604527892192, 1.478173411517124, 1.4210854715202004e-14,
      1.478173411517124, 5175.087537510957, 3.3480163086352377e-16,
      1.4210854715202004e-14, 3.3480163086352377e-16, 4644.779218274311,
    ])

  // Only a proved physical transfer removes the original person. Unknown
  // roster is not empty; deceasedWithHull keeps the actual physical body.
  static let emptyConfiguredPod = MassReference(
    massKilograms: 252.5,
    centreMetres: Vector3(-0.0022906336574498214, -0.08850551497387935, -0.007828620213163662),
    inertiaKgM2: [
      160.5838524798743, 0.026996614327577398, 0.004583657376041217,
      0.026996614327577398, 163.98628645124157, -0.6133356341206517,
      0.004583657376041217, -0.6133356341206523, 41.65185030920805,
    ])

  static let occupiedPod = MassReference(
    massKilograms: 352.5,
    centreMetres: Vector3(-0.0016408085064002268, -0.029355014272069567, -0.011281493911556828),
    inertiaKgM2: [
      189.56526518789155, -0.007215147932472729, 0.006580747724928065,
      -0.007215147932472729, 191.26394059190488, -0.4315499739432859,
      0.006580747724928065, -0.4315499739432865, 48.58302724146665,
    ])

  static let bornAll12 = MassReference(
    massKilograms: 502412.6552688963,
    centreMetres: Vector3(0.10889277703460902, 1.5972715299255253, -7.5423665437354295),
    inertiaKgM2: [
      775549129.7345563, 223584.44533984156, -1233511.2045769955,
      223584.44533984156, 918929197.5755891, -1619034.7825137416,
      -1233511.2045769955, -1619034.7825137416, 182472345.54093507,
    ])

  static let captured01Person7StillAboard = MassReference(
    massKilograms: 502212.6552688963,
    centreMetres: Vector3(0.10933437991554036, 1.5940606476884946, -7.542980772201221),
    inertiaKgM2: [
      775535595.3570675, 221795.592962286, -1233853.4046236752,
      221795.592962286, 918928221.0472953, -1616546.6555135786,
      -1233853.4046236752, -1616546.6555135786, 182458885.18525496,
    ])

  static let captured01Person7StrokeComplete = MassReference(
    massKilograms: 501860.1552688963,
    centreMetres: Vector3(0.0830805262192328, 1.5969568808434504, -7.558806742667718),
    inertiaKgM2: [
      775350326.1752948, 167428.29220189204, -936772.5602060967,
      167428.29220189204, 918256065.1625609, -1649319.1425726896,
      -936772.5602060967, -1649319.1425726896, 181959956.37608033,
    ])

  static let captured01Person7Unlocked = MassReference(
    massKilograms: 501860.1552688963,
    centreMetres: Vector3(0.0830287138573089, 1.5969568808434504, -7.558806742667718),
    inertiaKgM2: [
      775350326.1752948, 167320.99752926064, -936186.2668279647,
      167320.99752926064, 918254170.3792573, -1649319.1425726896,
      -936186.2668279647, -1649319.1425726896, 181958061.59277642,
    ])

  static let captured0Person7StillAboard = MassReference(
    massKilograms: 502312.6552688963,
    centreMetres: Vector3(0.10931261371499401, 1.5956664084169385, -7.54267359682827),
    inertiaKgM2: [
      775542363.8878708, 221883.7638535528, -1233836.5378975621,
      221883.7638535528, 918928487.5406945, -1617790.9666808236,
      -1233836.5378975621, -1617790.9666808236, 182465394.8396509,
    ])

  static let captured0Person7StrokeComplete = MassReference(
    massKilograms: 501960.1552688963,
    centreMetres: Vector3(0.08306397499990849, 1.5985631922278347, -7.558496198747786),
    inertiaKgM2: [
      775357094.9426581, 167495.26704309933, -936759.6121376666,
      167495.26704309933, 918256336.058766, -1650575.7647778443,
      -936759.6121376666, -1650575.7647778443, 181966460.85410497,
    ])

  static let captured0Person7Unlocked = MassReference(
    massKilograms: 501960.1552688963,
    centreMetres: Vector3(0.08301217295999148, 1.5985631922278347, -7.558496198747786),
    inertiaKgM2: [
      775357094.9426581, 167387.93060225985, -936173.3268344714,
      167387.93060225985, 918254441.2746015, -1650575.7647778443,
      -936173.3268344714, -1650575.7647778443, 181964566.06994098,
    ])
}
