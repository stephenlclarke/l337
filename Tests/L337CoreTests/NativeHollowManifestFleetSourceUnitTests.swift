import Foundation
import Testing

@testable import L337Core

/// Engineering source joins only; no actor, owned equipment, crew or berth is admitted here.
struct NativeHollowManifestFleetSourceUnitTests {
  @Test(arguments: NativeHollowManifestFleetSource.Role.allCases)
  func exactCurrentIdentityPerformanceGeometryAndEmptyFit(
    _ role: NativeHollowManifestFleetSource.Role
  ) throws {
    let source = try NativeHollowManifestFleetSource.resolve(role)
    let expected: (name: String, energy: Double, recharge: Double, speed: Double, crew: Int)
    switch role {
    case .inspectionFreighter: expected = ("Onager", 220, 3.1, 39, 1)
    case .custodyCarrier: expected = ("Okapi", 280, 3.5, 37.8, 1)
    case .evacuationLaunch: expected = ("Saiga", 310, 3.6, 32.7, 2)
    }
    let definition = try #require(OriginalFleetDefinitionData.definition(for: role.id))
    #expect(source.current.id == role.id && source.current.name == expected.name)
    #expect(source.physical.id == role.id && source.physical.name == expected.name)
    #expect(source.current.sourceSHA256 == definition.sourceSHA256)
    #expect(source.physical.specificationSHA256 == definition.sourceSHA256)
    #expect(source.current.referencedGeometrySHA256 == source.physical.model.sourceSHA256)
    #expect(source.performance == definition.nativePerformance)
    #expect(source.performance.energy == expected.energy)
    #expect(source.performance.recharge == expected.recharge)
    #expect(source.performance.speed == expected.speed)
    #expect(source.accommodation.operatingCrew == expected.crew)
    #expect(source.accommodation.intrinsicCrewPlaces == expected.crew)
    #expect(source.accommodation.initialPurchasedCabins == 0)
    #expect(!source.fitting.roleKitIncluded)
  }

  @Test func evacuationHullSourceCannotProvideSixPeopleWithIntrinsicAccommodation() throws {
    let source = try NativeHollowManifestFleetSource.resolve(.evacuationLaunch)
    #expect(source.current.id == "SH061")
    #expect(source.accommodation.intrinsicCrewPlaces == 2)
    #expect(source.accommodation.operatingCrew == 2)
    #expect(source.accommodation.initialPurchasedCabins == 0)
    #expect(source.accommodation.maximumCabins == 16)
    // Capacity to fit cabins is not a fitted cabin, a living crew member or an available berth.
    #expect(source.fitting.roleKitIncluded == false)
  }
}
