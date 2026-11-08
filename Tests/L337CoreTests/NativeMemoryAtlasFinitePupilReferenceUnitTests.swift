import Testing

@testable import L337Core

struct NativeMemoryAtlasFinitePupilReferenceUnitTests {
  private typealias Optics = NativeMemoryAtlasFinitePupilReference

  @Test func coaxialFinitePupilHasUnitFootprintAndClearance() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 3), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(0, 0, 10), axis: .init(0, 0, -2), radius: 2))
    let result = try #require(Optics.project(emitter: emitter, receiver: receiver))
    #expect(result.chiefRayPoint == .init(0, 0, 10))
    #expect(result.chiefRayTravel == 10 && result.centreOffset == 0)
    #expect(result.incidenceCosine == 1 && result.containingRadius == 1)
    #expect(result.nominalClearance == 1 && result.circularBoundFits)
  }

  @Test func threeFourFiveReceiverTiltEnlargesFiniteFootprint() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(0, 0, 10), axis: .init(0, 3, -4), radius: 2))
    let result = try #require(Optics.project(emitter: emitter, receiver: receiver))
    // 3-4-5 normal: cosine 4/5; a unit disk has largest projected semiaxis 5/4.
    #expect(abs(result.incidenceCosine - 0.8) < 1e-12)
    #expect(abs(result.containingRadius - 1.25) < 1e-12)
    #expect(abs(result.nominalClearance - 0.75) < 1e-12)
    #expect(result.chiefRayPoint == .init(0, 0, 10))
  }

  @Test func finitePupilClipsDespiteAChiefRayInsideTheReceiver() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(3, 4, 10), axis: .init(0, 0, -1), radius: 5.5))
    let result = try #require(Optics.project(emitter: emitter, receiver: receiver))
    #expect(result.centreOffset == 5 && result.centreOffset < receiver.radius)
    #expect(result.nominalClearance == -0.5 && !result.circularBoundFits)
    let tangent = try #require(Optics.Pupil(
      centre: receiver.centre, axis: receiver.axis, radius: 6))
    let boundary = try #require(Optics.project(emitter: emitter, receiver: tangent))
    #expect(boundary.nominalClearance == 0 && boundary.circularBoundFits)
  }

  @Test func conservativeCircleDoesNotClaimExactObliqueVignetting() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(1, 0, 10), axis: .init(0, 3, -4), radius: 2.2))
    let bound = try #require(Optics.project(emitter: emitter, receiver: receiver))
    // The ellipse's semiaxes are 1 and 1.25; the unit offset lies on its minor axis.
    // Its farthest point is 2 away, but offset + largest semiaxis bounds it by 2.25.
    // Thus a failed sufficient circle bound cannot itself establish actual clipping.
    #expect(abs(bound.centreOffset - 1) < 1e-12)
    #expect(abs(bound.containingRadius - 1.25) < 1e-12)
    #expect(abs(bound.nominalClearance - (-0.05)) < 1e-12)
    #expect(!bound.circularBoundFits)
  }

  @Test func translatedAndRotatedReferenceKeepsPhysicalOffsetAndTravel() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(7, -3, 5), axis: .init(1, 0, 0), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(17, -3, 5), axis: .init(-1, 0, 0), radius: 2))
    let result = try #require(Optics.project(emitter: emitter, receiver: receiver))
    #expect(result.chiefRayPoint == .init(17, -3, 5))
    #expect(result.chiefRayTravel == 10 && result.centreOffset == 0)
    #expect(result.containingRadius == 1 && result.nominalClearance == 1)
  }

  @Test(arguments: [0.0, -1.0, Double.nan, Double.infinity])
  func invalidPupilRadiusCannotSupplyAFiniteAperture(radius: Double) {
    #expect(Optics.Pupil(centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: radius) == nil)
  }

  @Test func invalidFramesRefuseAndAxisNormalizationHasNoNativeUnitCutoff() throws {
    #expect(Optics.Pupil(centre: .init(.nan, 0, 0), axis: .init(0, 0, 1), radius: 1) == nil)
    #expect(Optics.Pupil(centre: .init(0, 0, 0), axis: .init(0, 0, 0), radius: 1) == nil)
    #expect(Optics.Pupil(centre: .init(0, 0, 0), axis: .init(.infinity, 0, 1), radius: 1) == nil)
    let tiny = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, .leastNonzeroMagnitude), radius: 1))
    let huge = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, .greatestFiniteMagnitude), radius: 1))
    #expect(tiny.axis == .init(0, 0, 1) && huge.axis == tiny.axis)
  }

  @Test func parallelBackFacingBehindAndZeroTravelCannotCouple() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    for (centre, axis) in [
      (Vector3(0, 0, 10), Vector3(1, 0, 0)),
      (Vector3(0, 0, 10), Vector3(0, 0, 1)),
      (Vector3(0, 0, -10), Vector3(0, 0, -1)),
      (Vector3(0, 0, 0), Vector3(0, 0, -1)),
    ] {
      let receiver = try #require(Optics.Pupil(centre: centre, axis: axis, radius: 2))
      #expect(Optics.project(emitter: emitter, receiver: receiver) == nil)
    }
  }

  @Test func overflowingSeparationOrObliqueFootprintRefusesAResult() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, -.greatestFiniteMagnitude), axis: .init(0, 0, 1), radius: 1))
    let far = try #require(Optics.Pupil(
      centre: .init(0, 0, .greatestFiniteMagnitude), axis: .init(0, 0, -1), radius: 2))
    #expect(Optics.project(emitter: emitter, receiver: far) == nil)
    let origin = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let grazing = try #require(Optics.Pupil(
      centre: .init(0, 0, 10), axis: .init(1, 0, -.leastNonzeroMagnitude), radius: 2))
    #expect(Optics.project(emitter: origin, receiver: grazing) == nil)
  }

  @Test func uniformLocalUnitChangeDoesNotAdoptMetresOrChangeContainment() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 8))
    let receiver = try #require(Optics.Pupil(
      centre: .init(0, 0, 80), axis: .init(0, 0, -1), radius: 16))
    let result = try #require(Optics.project(emitter: emitter, receiver: receiver))
    #expect(result.chiefRayTravel == 80 && result.containingRadius == 8)
    #expect(result.nominalClearance == 8 && result.circularBoundFits)
  }

  @Test func whollyForwardTiltedDiskHasPositiveMinimumTravel() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(0, 0, 1), axis: .init(0, 3, -4), radius: 2))
    // Plane 3y - 4(z - 1) = 0 gives t(y) = 1 + 3y/4 on the emitting disk.
    // At y = -1 the minimum is 1/4; at y = 1 the maximum is 7/4.
    let result = try #require(Optics.project(emitter: emitter, receiver: receiver))
    #expect(abs(result.chiefRayTravel - 1) < 1e-12)
    #expect(abs(result.minimumRayTravel - 0.25) < 1e-12)
    #expect(result.minimumRayTravel > 0)
    #expect(abs(result.containingRadius - 1.25) < 1e-12)
    #expect(abs(result.nominalClearance - 0.75) < 1e-12)
    #expect(result.circularBoundFits)
  }

  @Test func tiltedDiskEdgeTouchingReceiverPlaneRefuses() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(0, 0, 0.75), axis: .init(0, 3, -4), radius: 2))
    // Plane 3y - 4(z - 3/4) = 0 gives t(y) = 3/4 + 3y/4.
    // The edge (0, -1, 0) has t = 0. Chief travel is positive and the
    // containing circle has radius 5/4 < 2, but forward travel must be strict.
    #expect(Optics.project(emitter: emitter, receiver: receiver) == nil)
  }

  @Test func tiltedDiskCrossingReceiverPlaneRefusesDespiteCircleFit() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(0, 0, 0.25), axis: .init(0, 3, -4), radius: 2))
    // Plane 3y - 4(z - 1/4) = 0 gives t(y) = 1/4 + 3y/4.
    // Its edge minimum is -1/2 and its chief travel is 1/4. The old circle
    // bound still fits (5/4 < 2), so containment alone cannot admit this disk.
    #expect(Optics.project(emitter: emitter, receiver: receiver) == nil)
  }

  @Test func tinyTiltCannotHideABackwardDiskEdgeInARoundedCosine() throws {
    let emitter = try #require(Optics.Pupil(
      centre: .init(0, 0, 0), axis: .init(0, 0, 1), radius: 1))
    let receiver = try #require(Optics.Pupil(
      centre: .init(0, 0, 1.0 / 268435456),
      axis: .init(0, 1, -134217728), radius: 2))
    // Plane y - 2^27(z - 2^-28) = 0 gives t(y) = 2^-28 + y * 2^-27.
    // At y = -1 the minimum is -2^-28 even if the normalized cosine rounds to 1.
    #expect(Optics.project(emitter: emitter, receiver: receiver) == nil)
  }
}
