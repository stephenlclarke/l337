import Foundation
import Testing

@testable import L337Core

struct CurrentNewtEmptyCellSourceTests {
  @Test func authenticatedEmptyDisplayRemovesOnlyFigureAndItsMaterials() throws {
    let occupied = try #require(OriginalCryostasisCapsule.source)
    let empty = try #require(CurrentNewtEmptyCellDisplaySource.emptyDisplayMesh)
    #expect(empty.vertices.count == 120 && empty.faces.count == 203)
    #expect(empty.faces.reduce(0) { $0 + $1.count - 2 } == 204)
    let allSatisfied = empty.materials.count == 4 && empty.faceMaterials.allSatisfy { (0..<4).contains($0) }
    #expect(allSatisfied)
    #expect(Array(empty.vertices.prefix(104)) == Array(occupied.displayMesh.vertices.prefix(104)))
    #expect(Array(empty.vertices.suffix(16)) == Array(occupied.displayMesh.vertices.suffix(16)))
    #expect(Array(empty.faces.prefix(179)) == Array(occupied.displayMesh.faces.prefix(179)))
    for offset in 0..<24 {
      #expect(empty.faces[179 + offset].map { $0 + 136 }
        == occupied.displayMesh.faces[391 + offset])
    }
    #expect(empty.faces[38] == [14, 15, 27, 26] && empty.faceMaterials[38] == 3)
    _ = try #require(empty.opticalEnclosure)
    #expect(occupied.collisionDesign.vertices.count == 48 && occupied.collisionDesign.faces.count == 92)
    #expect(ShipCatalogue.rawMesh("SH040") == nil)
  }

  @Test func emptyConfiguredCellAndActualPersonReassembleAllOccupiedMassMoments() throws {
    let empty = CurrentNewtEmptyCellPhysicalSource.cellWithoutSelectedPerson
    let person = CurrentNewtKitPhysicalSource.personMassKilograms
    let dimensions = CurrentNewtKitPhysicalSource.personDimensionsMetres
    let personTensor = [
      person * (dimensions.y * dimensions.y + dimensions.z * dimensions.z) / 12, 0, 0,
      0, person * (dimensions.x * dimensions.x + dimensions.z * dimensions.z) / 12, 0,
      0, 0, person * (dimensions.x * dimensions.x + dimensions.y * dimensions.y) / 12,
    ]
    let whole = try #require(CurrentNewtKitMass.combined([
      .init(massKilograms: empty.massKilograms, centreOfMassMetres: empty.centreMetres,
        inertiaKgM2: empty.inertiaAboutCentreOfMassKgM2),
      .init(massKilograms: person, centreOfMassMetres: CurrentNewtKitPhysicalSource.personCentreInPodMetres,
        inertiaKgM2: personTensor),
    ]))
    #expect(CurrentNewtKitPhysicalSource.occupiedPod.matches(massKilograms: whole.massKilograms,
      centreMetres: whole.centreOfMassMetres, inertiaAboutCentreOfMassKgM2: whole.inertiaKgM2))
    #expect(empty.massKilograms == 252.5 && whole.massKilograms == 352.5)
  }

  @Test func changingOnlyMassCannotLeaveCapturedPersonInEmptyCellTensor() {
    let empty = CurrentNewtEmptyCellPhysicalSource.cellWithoutSelectedPerson
    let occupied = CurrentNewtKitPhysicalSource.occupiedPod
    #expect(!empty.matches(massKilograms: 252.5, centreMetres: occupied.centreMetres,
      inertiaAboutCentreOfMassKgM2: occupied.inertiaAboutCentreOfMassKgM2))
    #expect(abs(CurrentNewtKitPhysicalSource.installedOccupied.massKilograms
      - CurrentNewtEmptyCellPhysicalSource.installedStowedWithoutSelectedPerson.massKilograms - 100) < 1e-8)
    #expect(abs(CurrentNewtKitPhysicalSource.installedAtUnlock.massKilograms
      - CurrentNewtEmptyCellPhysicalSource.installedLoweredWithoutSelectedPerson.massKilograms - 100) < 1e-8)
  }
}
