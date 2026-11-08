import Foundation
import Testing

@testable import L337Core

struct NativeSalvageReleasePlacementTests {
  @Test(arguments: [1, 3, 5])
  func actualOkapiHullReleaseClearsEveryParentPanelAndPreservesIssuedProperty(units: Int) throws {
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH029"))
    let section = try #require(profile.sections.first { $0.index == 0 && $0.structural })
    let hull = try PreparedHull(mesh: profile.mesh)
    let identity = WreckSectionIdentity(
      wreck: .init(system: .init(galaxy: 0, system: 69), site: 2147483649, lineage: 2), section: 0)
    let source = SalvageLootSource(
      roles: profile.sourceRoles, legalValue: 0, economy: 3, technology: 16, ownership: .abandoned)
    let plan = SalvageLootProfiles.plan(section: identity, seed: 9, source: source)
    let item = SalvageLotEmission.structural(
      plan: plan, quantity: units, material: .alloys, identity: .init(section: identity, lot: 0))
    var rotated = Basis3()
    rotated.x = .init(0, 0, -1)
    rotated.z = .init(1, 0, 0)
    let poses = [ShipPose(), .init(position: .init(125_000, -250, 1500), orientation: rotated)]
    for pose in poses {
      let direction = pose.orientation.apply(section.normal.unit)
      let original = SalvageLot(
        identity: item.identity, content: .commodity(.init(commodity: .alloys, quantity: units)),
        position: pose.systemPoint(section.localPosition) + direction * (item.halfExtents.length + 10),
        velocity: .init(1, 2, 3), halfExtents: item.halfExtents, massKg: item.massKg, loot: item)
      if units == 3 {
        let oldPlacement = HullSweepSafety.validatePlacement(center: original.position,
          radius: original.halfExtents.length, hull: hull, pose: pose, requiredClearance: 8)
        #expect(oldPlacement.failure == .clearanceViolation)
      }
      let placed = try #require(NativeSalvageReleasePlacement.outsideParent(
        [original], mesh: profile.mesh, pose: pose, normal: section.normal).first)
      let proof = HullSweepSafety.validatePlacement(center: placed.position,
        radius: placed.halfExtents.length, hull: hull, pose: pose, requiredClearance: 8)
      #expect(proof.safe)
      #expect(placed.position != original.position)
      var restored = placed
      restored.position = original.position
      #expect(restored == original)
      #expect(placed.massKg == Double(units) * 1000)
      let delta = placed.position - original.position
      #expect(delta.dot(direction) > 0 && delta.cross(direction).length < 1e-8)
    }
  }

  @Test func invalidReleaseGeometryRefusesBeforeReturningAnyPlacedLots() throws {
    let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH029"))
    #expect(throws: (any Error).self) {
      try NativeSalvageReleasePlacement.outsideParent([], mesh: profile.mesh, pose: .init(),
        normal: .init(0, 0, 0))
    }
    #expect(throws: (any Error).self) {
      try NativeSalvageReleasePlacement.outsideParent([], mesh: profile.mesh, pose: .init(),
        normal: .init(.nan, 0, 1))
    }
  }
}
