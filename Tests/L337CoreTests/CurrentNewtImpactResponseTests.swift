import Foundation
import Testing

@testable import L337Core

struct CurrentNewtImpactResponseTests {
  @Test
  func offCentreFullTensorImpactPreservesBothMomentaAndPaysTheAuthoredEnergyLoss() throws {
    let source = try #require(CurrentNewtKitSource.current)
    let mass = CurrentNewtImpactMass.tensor(source.podMass)
    let a = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(0, 0, 0)),
      velocity: .init(0.01, 0, 0), angularVelocity: .init(0, 0, 0))
    let b = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(2, 0, 0)),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
    let point = Vector3(1, 0.2, 0.1), normal = Vector3(1, 0, 0)
    let result = try #require(CurrentNewtImpactResponse.resolve(source: a, mass: mass,
      target: b, mass: mass, point: point, normal: normal))
    #expect(result.source.pose == a.pose && result.target.pose == b.pose)
    #expect(result.source.angularVelocity.length > 0 && result.target.angularVelocity.length > 0)
    let p0 = mass.momentum(a, about: point), q0 = mass.momentum(b, about: point)
    let p1 = mass.momentum(result.source, about: point), q1 = mass.momentum(result.target, about: point)
    #expect((p0.linearMomentum + q0.linearMomentum - p1.linearMomentum - q1.linearMomentum).length < 1e-9)
    #expect((p0.angularMomentum + q0.angularMomentum - p1.angularMomentum - q1.angularMomentum).length < 1e-9)
    let loss = p0.kineticEnergyJoules + q0.kineticEnergyJoules
      - p1.kineticEnergyJoules - q1.kineticEnergyJoules
    #expect(loss > 0)
    #expect(abs(loss - result.effect.damage * AsteroidImpactPolicy.joulesPerEnergy) < 1e-9)
    let before = (mass.pointVelocity(a, at: point) - mass.pointVelocity(b, at: point)).dot(normal)
    let after = (mass.pointVelocity(result.source, at: point)
      - mass.pointVelocity(result.target, at: point)).dot(normal)
    #expect(abs(after + AsteroidImpactPolicy.restitution * before) < 1e-10)
  }

  @Test
  func commonWorldVelocityDoesNotCreateExtraCollisionDamageOrSpin() throws {
    let source = try #require(CurrentNewtKitSource.current)
    let mass = CurrentNewtImpactMass.tensor(source.podMass)
    func response(_ inherited: Vector3) throws -> CurrentNewtImpactResponse {
      try #require(CurrentNewtImpactResponse.resolve(
        source: .init(pose: .init(position: .init(0, 0, 0)),
          velocity: inherited + Vector3(0.01, 0, 0), angularVelocity: .init(0, 0, 0)), mass: mass,
        target: .init(pose: .init(position: .init(2, 0, 0)),
          velocity: inherited, angularVelocity: .init(0, 0, 0)), mass: mass,
        point: .init(1, 0.2, 0.1), normal: .init(1, 0, 0)))
    }
    let rest = try response(.init(0, 0, 0)), moving = try response(.init(80, -30, 20))
    #expect(abs(rest.effect.damage - moving.effect.damage) < 1e-12)
    #expect((rest.source.angularVelocity - moving.source.angularVelocity).length < 1e-10)
    #expect((rest.target.angularVelocity - moving.target.angularVelocity).length < 1e-10)
  }

  @Test
  func aMissingOrdinaryTensorCannotSilentlyAbsorbAnOffCentreTorque() throws {
    let source = try #require(CurrentNewtKitSource.current)
    let a = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(0, 0, 0)),
      velocity: .init(0.01, 0, 0), angularVelocity: .init(0, 0, 0))
    let b = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(2, 0, 0)),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
    #expect(CurrentNewtImpactResponse.resolve(source: a, mass: .tensor(source.podMass),
      target: b, mass: .translational(1000), point: .init(1, 0.2, 0), normal: .init(1, 0, 0)) == nil)
  }

  @Test
  func ordinaryCentralResponseKeepsExistingCollisionTuning() throws {
    let a = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(0, 0, 0)),
      velocity: .init(3, 0, 0), angularVelocity: .init(0, 0, 0))
    let b = CurrentNewtKitReceipt.BodyState(pose: .init(position: .init(2, 0, 0)),
      velocity: .init(0, 0, 0), angularVelocity: .init(0, 0, 0))
    let old = try #require(AsteroidImpactPolicy.impulse(sourceMass: 1000, targetMass: 2000,
      sourceVelocity: a.velocity, targetVelocity: b.velocity, normal: .init(1, 0, 0)))
    let result = try #require(CurrentNewtImpactResponse.resolve(source: a, mass: .translational(1000),
      target: b, mass: .translational(2000), point: .init(1, 0, 0), normal: .init(1, 0, 0)))
    #expect((result.source.velocity - old.source).length < 1e-12)
    #expect((result.target.velocity - old.target).length < 1e-12)
    #expect(abs(result.effect.damage - old.damage) < 1e-12)
  }
}
