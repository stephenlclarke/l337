import Foundation
import Testing

@testable import L337Core

/// Mechanics units only. No body, person, kit or admission is installed here.
struct CurrentNewtRigidCoastTests {
  @Test
  func aGenuinePointZeroFourIsotropicSpinFitsThePointZeroFiveLimit() throws {
    let mass = properties([20, 20, 20])
    let initial = state(omega: .init(0.04, 0, 0))
    let flow = try #require(CurrentNewtRigidCoast(initial: initial, mass: mass,
      duration: 0.1, maximumAngularSpeed: 0.05))
    let end = try #require(flow.state(at: 0.1))
    #expect(end.angularVelocity == initial.angularVelocity)
    try conservation(initial, end, mass: mass, duration: 0.1)
  }

  @Test
  func nonprincipalSpinUsesTheFullTensorAndPreservesWorldMomentum() throws {
    let mass = properties([2, 3, 4])
    let initial = state(omega: .init(0.02, 0.03, 0.01))
    let flow = try #require(CurrentNewtRigidCoast(initial: initial, mass: mass,
      duration: 0.1, maximumAngularSpeed: 0.05))
    let end = try #require(flow.state(at: 0.1))
    #expect((end.angularVelocity - initial.angularVelocity).length > 1e-8)
    try conservation(initial, end, mass: mass, duration: 0.1)
    let speed = try #require(flow.pointSpeedBound(localExtent: 2))
    #expect(speed >= end.velocity.length)
  }

  @Test
  func aRealLongArchiveDurationIsNotClippedToOneNativeTick() throws {
    let mass = properties([2, 3, 4])
    let initial = state(omega: .init(0.02, 0.03, 0.01))
    let flow = try #require(CurrentNewtRigidCoast(initial: initial, mass: mass,
      duration: 12.5, maximumAngularSpeed: 0.05))
    let end = try #require(flow.state(at: 12.5))
    let oneTick = try #require(flow.state(at: 0.1))
    #expect((end.pose.position - oneTick.pose.position).length > 10)
    try conservation(initial, end, mass: mass, duration: 12.5)
  }

  @Test
  func anActualZeroSpinLongCoastHasItsExactLinearSolution() throws {
    let mass = properties([2, 3, 4])
    let initial = state(omega: .init(0, 0, 0))
    let flow = try #require(CurrentNewtRigidCoast(initial: initial, mass: mass,
      duration: 100_000, maximumAngularSpeed: 0.05))
    let end = try #require(flow.state(at: 100_000))
    #expect(end.pose.orientation == initial.pose.orientation)
    #expect(end.velocity == initial.velocity && end.angularVelocity == initial.angularVelocity)
    #expect((end.pose.position - initial.pose.position - initial.velocity * 100_000).length < 1e-8)
  }

  @Test
  func theSourceSpinLimitIsNotWidenedToAcceptAnInvalidOpening() {
    #expect(CurrentNewtRigidCoast(initial: state(omega: .init(0.051, 0, 0)),
      mass: properties([20, 20, 20]), duration: 0.1, maximumAngularSpeed: 0.05) == nil)
  }

  private func conservation(_ before: CurrentNewtKitReceipt.BodyState,
    _ after: CurrentNewtKitReceipt.BodyState, mass: CurrentNewtKitReceipt.MassProperties,
    duration: Double) throws
  {
    let p0 = CurrentNewtKitMass.centreVelocity(mass, state: before) * mass.massKilograms
    let p1 = CurrentNewtKitMass.centreVelocity(mass, state: after) * mass.massKilograms
    let c0 = CurrentNewtKitMass.centre(mass, state: before)
    let c1 = CurrentNewtKitMass.centre(mass, state: after)
    let l0 = CurrentNewtKitMass.spin(mass, state: before)
    let l1 = CurrentNewtKitMass.spin(mass, state: after)
    #expect((p0 - p1).length < 1e-9 && (l0 - l1).length < 1e-9)
    #expect((c1 - c0 - p0 * (duration / mass.massKilograms)).length < 1e-8)
    #expect(abs(CurrentNewtKitMass.kineticEnergy(mass, state: after)
      - CurrentNewtKitMass.kineticEnergy(mass, state: before)) < 1e-8)
  }

  private func state(omega: Vector3) -> CurrentNewtKitReceipt.BodyState {
    .init(pose: .init(position: .init(10, -20, 30)),
      velocity: .init(3, -2, 1), angularVelocity: omega)
  }
  private func properties(_ diagonal: [Double]) -> CurrentNewtKitReceipt.MassProperties {
    .init(massKilograms: 100, centreOfMassMetres: .init(0.2, -0.1, 0.05),
      inertiaKgM2: [diagonal[0], 0, 0, 0, diagonal[1], 0, 0, 0, diagonal[2]])
  }
}
