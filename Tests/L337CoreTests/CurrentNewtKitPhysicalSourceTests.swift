import Foundation
import Testing

@testable import L337Core

struct CurrentNewtKitPhysicalSourceTests {
  @Test func physicalPhasesMatchActualAuthoredResource() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let file = root.appendingPathComponent("Sources/L337Core/Resources/OriginalFleetPhysical")
      .appendingPathComponent(CurrentNewtKitPhysicalSource.resourceFileName)
    let data = try Data(contentsOf: file)
    #expect(data.count == CurrentNewtKitPhysicalSource.sourceByteCount)
    let source = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(source["id"] as? String == CurrentNewtKitPhysicalSource.configurationID)
    let phases = try #require(source["physicalExpectations"] as? [String: [String: Any]])
    for (name, expected) in expectations {
      let row = try #require(phases[name])
      let mass = try #require(row["massKg"] as? Double)
      let centre = try #require(row["centreMetres"] as? [Double])
      let tensor = try #require(row["inertiaAboutCentreOfMassKgM2"] as? [Double])
      #expect(centre.count == 3)
      #expect(expected.matches(massKilograms: mass,
        centreMetres: Vector3(centre[0], centre[1], centre[2]),
        inertiaAboutCentreOfMassKgM2: tensor))
    }
  }

  @Test func finitePositiveForgeriesAndNonfinitePhasesAreRefused() {
    for (_, expected) in expectations {
      let mass = expected.massKilograms
      let centre = expected.centreMetres
      let tensor = expected.inertiaAboutCentreOfMassKgM2
      #expect(expected.matches(massKilograms: mass, centreMetres: centre,
        inertiaAboutCentreOfMassKgM2: tensor))
      for wrong in [mass + 0.01, 0, -1, .infinity, .nan] {
        #expect(!expected.matches(massKilograms: wrong, centreMetres: centre,
          inertiaAboutCentreOfMassKgM2: tensor))
      }
      for index in 0..<3 {
        var coordinates = [centre.x, centre.y, centre.z]
        coordinates[index] += 0.001
        #expect(!expected.matches(massKilograms: mass,
          centreMetres: Vector3(coordinates[0], coordinates[1], coordinates[2]),
          inertiaAboutCentreOfMassKgM2: tensor))
      }
      for index in 0..<9 {
        for value in [tensor[index] + 0.1, .infinity, .nan] {
          var wrong = tensor
          wrong[index] = value
          #expect(!expected.matches(massKilograms: mass, centreMetres: centre,
            inertiaAboutCentreOfMassKgM2: wrong))
        }
      }
      #expect(!expected.matches(massKilograms: mass, centreMetres: centre,
        inertiaAboutCentreOfMassKgM2: Array(tensor.dropLast())))
      #expect(!expected.matches(massKilograms: mass, centreMetres: Vector3(.nan, 0, 0),
        inertiaAboutCentreOfMassKgM2: tensor))
    }
  }

  @Test func unlockUsesActualLoweredAssemblyWithStowedRodsBeforeAnyNewEjectionVelocity() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let file = root.appendingPathComponent("Sources/L337Core/Resources/OriginalFleetPhysical")
      .appendingPathComponent(CurrentNewtKitPhysicalSource.resourceFileName)
    let data = try Data(contentsOf: file)
    let source = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let rows = try #require(source["retainedPartsLoweredCarrier"] as? [[String: Any]])
    let parts = try rows.map { try #require(CurrentNewtKitGeometry.mass(part: $0)) }
    let retained = try #require(CurrentNewtKitMass.combined(parts))
    #expect(CurrentNewtKitPhysicalSource.retainedAtUnlock.matches(
      massKilograms: retained.massKilograms, centreMetres: retained.centreOfMassMetres,
      inertiaAboutCentreOfMassKgM2: retained.inertiaKgM2))
    let bare = CurrentNewtKitPhysicalSource.bareParent
    let parent = try #require(CurrentNewtKitMass.combined([
      .init(massKilograms: bare.massKilograms, centreOfMassMetres: bare.centreMetres,
        inertiaKgM2: bare.inertiaAboutCentreOfMassKgM2), retained,
    ]))
    #expect(CurrentNewtKitPhysicalSource.carrierAtUnlock.matches(
      massKilograms: parent.massKilograms, centreMetres: parent.centreOfMassMetres,
      inertiaAboutCentreOfMassKgM2: parent.inertiaKgM2))
    #expect(!CurrentNewtKitPhysicalSource.carrierAfter.matches(
      massKilograms: parent.massKilograms, centreMetres: parent.centreOfMassMetres,
      inertiaAboutCentreOfMassKgM2: parent.inertiaKgM2))
    let pod = CurrentNewtKitPhysicalSource.occupiedPod
    let whole = try #require(CurrentNewtKitMass.combined([
      parent, .init(massKilograms: pod.massKilograms,
        centreOfMassMetres: pod.centreMetres + CurrentNewtKitPhysicalSource.podCentreInCarrierMetres,
        inertiaKgM2: pod.inertiaAboutCentreOfMassKgM2),
    ]))
    #expect(CurrentNewtKitPhysicalSource.installedAtUnlock.matches(
      massKilograms: whole.massKilograms, centreMetres: whole.centreOfMassMetres,
      inertiaAboutCentreOfMassKgM2: whole.inertiaKgM2))
  }

  private var expectations: [(String, CurrentNewtKitPhysicalSource.PhysicalExpectation)] {
    [
      ("bareParent", CurrentNewtKitPhysicalSource.bareParent),
      ("dryPod", CurrentNewtKitPhysicalSource.dryPod),
      ("occupiedPod", CurrentNewtKitPhysicalSource.occupiedPod),
      ("retainedStowed", CurrentNewtKitPhysicalSource.retainedStowed),
      ("retainedExtended", CurrentNewtKitPhysicalSource.retainedExtended),
      ("carrierBefore", CurrentNewtKitPhysicalSource.carrierBefore),
      ("carrierAfter", CurrentNewtKitPhysicalSource.carrierAfter),
      ("installedOccupied", CurrentNewtKitPhysicalSource.installedOccupied),
      ("separatedComposite", CurrentNewtKitPhysicalSource.separatedComposite),
    ]
  }
}
