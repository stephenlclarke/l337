import Foundation

/// SH029-specific mass references after a proved transfer of original person0.
/// Actual roster/custody must select these values. An unknown roster is not empty;
/// deceasedWithHull retains the occupied physical body while that body remains.
enum CurrentNewtEmptyCellPhysicalSource {
  static let configurationID = "SH029-current-newt-escape-kit-v1"
  static let configuredSourceSHA256 = "7ba94c62149a2f0b7b882367c946a41516f49c6c58861d5e85eec255ba9d4b4a"
  static let removedOriginalPersonOrdinal = 0
  static let removedPersonComponentID = "actual-identified-person"
  static let displayComponentID = "unchanged-current-newt-dry"
  static let retainedComponentIDs = [
    "unchanged-current-newt-dry", "portable-isolating-coupler", "charged-free-atmosphere",
    "portable-thrust-shoe--0.75", "portable-thrust-shoe-0.75",
  ]
  static let retainedComponentMassKilograms = [248.0, 1.0, 2.5, 0.5, 0.5]

  static let cellWithoutSelectedPerson = CurrentNewtKitPhysicalSource.PhysicalExpectation(
    massKilograms: 252.5,
    centreMetres: Vector3(-0.0022949682977718225, -0.08846380209596807, -0.007828620213163662),
    inertiaAboutCentreOfMassKgM2: [
      160.5835033687641, 0.033016950011688126, 0.004592225774883746,
      0.033016950011688126, 163.98662776572408, -0.613418089076141,
      0.004592225774883746, -0.6134180890761415, 41.65359251258036,
    ])

  static let installedStowedWithoutSelectedPerson = CurrentNewtKitPhysicalSource.PhysicalExpectation(
    massKilograms: 46177.76639396747,
    centreMetres: Vector3(0.16359957602353473, -1.453225903122751, -2.1432166564448343),
    inertiaAboutCentreOfMassKgM2: [
      4175017.282733237, 14300.938505848484, -8607.833690235862,
      14300.938505848484, 5482072.429315313, -148019.92504300814,
      -8607.833690235862, -148019.92504300814, 1774813.7422978438,
    ])

  static let installedLoweredWithoutSelectedPerson = CurrentNewtKitPhysicalSource.PhysicalExpectation(
    massKilograms: 46177.76639396747,
    centreMetres: Vector3(0.16359957602353473, -1.4547338634037421, -2.1432166564448343),
    inertiaAboutCentreOfMassKgM2: [
      4175342.8755565546, 15113.353518831376, -8607.833690235864,
      15113.353518831376, 5482072.429315314, -147940.31802273984,
      -8607.833690235864, -147940.31802273984, 1775139.335121162,
    ])
}
