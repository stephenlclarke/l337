import Foundation
import Testing

@testable import L337Core

/// Arithmetic tests only. These values do not admit a hull, mission actor or projectile.
struct OuterKernelKinematicsTests {
  @Test func preparedNPCTranslationSamplesOneAccelerationDecisionAcrossCuts() throws {
    let movement = OuterNPCTranslation(position: .init(0, 0, 0), velocity: .init(0, 0, 0),
      desired: .init(100, 0, 0), acceleration: 100, delta: 0.1)
    #expect(movement.velocity == .init(10, 0, 0) && movement.end == .init(1, 0, 0))
    let first = try #require(movement.position(at: 0.025))
    let second = try #require(movement.position(at: 0.075))
    let end = try #require(movement.position(at: 0.1))
    #expect(first == .init(0.25, 0, 0) && second == .init(0.75, 0, 0))
    #expect(end == movement.end && (first + (second - first) + (end - second)) == end)
    #expect(movement.position(at: -0.001) == nil && movement.position(at: 0.101) == nil)
  }

  @Test func projectileGraceAndExpiryBoundThePreparedCollisionWindow() throws {
    let movement = OuterScriptProjectileTranslation(position: .init(10, 0, 0),
      velocity: .init(100, 0, 0), age: 0.04, lifetime: 0.12,
      collisionDelay: 0.06, delta: 0.1)
    #expect(abs(movement.duration - 0.08) < 1e-12 && abs(movement.age - 0.12) < 1e-12)
    #expect(abs(movement.end.x - 18) < 1e-12)
    let collision = try #require(movement.collisionStart)
    let range = try #require(movement.collisionRange)
    #expect(abs(collision.x - 12) < 1e-12 && abs(range - 6) < 1e-12)
    #expect(movement.position(at: 0.09) == nil)
    let grace = OuterScriptProjectileTranslation(position: .init(0, 0, 0),
      velocity: .init(0, 0, 100), age: 0, lifetime: 1, collisionDelay: 0.2, delta: 0.1)
    #expect(grace.collisionStart == nil && grace.collisionRange == nil)
    #expect(grace.end == .init(0, 0, 10))
  }

  @Test func actualEmissionWindowDoesNotCreditTimeBeforeBirth() throws {
    let old = try #require(OuterScriptProjectileTranslation.availableDelta(
      start: 10, end: 10.1, emittedAt: 9))
    let interior = try #require(OuterScriptProjectileTranslation.availableDelta(
      start: 10, end: 10.1, emittedAt: 10.04))
    #expect(abs(old - 0.1) < 1e-12 && abs(interior - 0.06) < 1e-12)
    #expect(OuterScriptProjectileTranslation.availableDelta(
      start: 10, end: 10.1, emittedAt: 10.1) == 0)
    #expect(OuterScriptProjectileTranslation.availableDelta(
      start: 10, end: 10.1, emittedAt: 11) == nil)
    #expect(OuterScriptProjectileTranslation.availableDelta(
      start: 10.1, end: 10, emittedAt: 9) == nil)
    #expect(OuterScriptProjectileTranslation.availableDelta(
      start: 10, end: .nan, emittedAt: 9) == nil)
  }
}
