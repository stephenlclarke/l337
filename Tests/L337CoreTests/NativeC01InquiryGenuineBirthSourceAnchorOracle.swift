import Foundation
import Testing

@testable import L337Core

/// Actual-fixture acceptance oracles ONLY. No @Test is registered here because
/// G3's mathematical fixtures cannot construct a genuine birth preparation.
/// G1 must invoke these from its real source fixture; that invocation and the
/// original positive acceptance remain OPEN. No skip, fake token or pass claim.
/// Caller retains/settles this SAME actual residual Work once with its owner.
/// Existing deep native-currentness traversal metering remains OPEN separately.
enum NativeC01InquiryGenuineBirthSourceAnchorOracle {
  private typealias S = NativeC01InquiryCompoundValidatedCurve
  private typealias P = NativeC01InquiryPreparationWork
  private typealias G = NativeC01InquiryCurveGeometry

  static func positive(_ preparation: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    game: borrowing Game, workOwner: NativeC01InquiryNativeQueryWork,
    work: inout NativeC01InquiryCurveGeometry.Work) throws {
    let commander = game.commander, bodies = game.bodies
    let flight = game.storedFlightSimulation(), epoch = game.nativeStationRuntimeEpoch
    let registry = game.c01InquiryNativeRegistry
    #expect(preparation.matchesCurrentBirthSource(game: game, workOwner: workOwner))
    let original = preparation.seed, originalTime = preparation.actualBirthPhysicalTime
    let beforeQueries = work.queries, beforeTriangles = work.triangles, beforeNodes = work.nodes
    guard case .prepared(let source, let actual) = S.prepareConstrainedInitialSeed(preparation,
      game: game, workOwner: workOwner, work: &work) else {
      Issue.record("Genuine current same-owner birth source must satisfy original positive source/time acceptance")
      throw P.Failure.unproven
    }
    #expect(actual.queries == work.queries - beforeQueries)
    #expect(actual.triangles == work.triangles - beforeTriangles && actual.triangles > 0)
    #expect(actual.nodes == work.nodes - beforeNodes && actual.nodes > 0)
    #expect(source.declaredAnchorTime == originalTime)
    #expect(source.view.atlas === original.materialView.atlas)
    #expect(source.view.vertexIDs == original.materialView.vertexIDs && source.view.facetIDs == original.materialView.facetIDs)
    #expect(source.state.quaternion.components == original.state.quaternion.components)
    #expect(same(source.state.centreOfMass, original.state.centreOfMass))
    #expect(same(source.state.linearMomentum, original.state.linearMomentum))
    #expect(same(source.state.worldAngularMomentum, original.state.worldAngularMomentum))
    guard case .translatedBirth(let retained) = source.source else {
      Issue.record("Actual birth cannot be replaced by a diagnostic raw-source IVP")
      throw P.Failure.unproven
    }
    #expect(retained.frameProjection.quaternion.components == original.frameProjection.quaternion.components)
    #expect(retained.frameProjection.rotation == original.frameProjection.rotation)
    #expect(retained.frameProjection.rotationMinusNativeBasis == original.frameProjection.rotationMinusNativeBasis)
    #expect(samePose(retained.frameProjection.nativeSourceFrame, original.frameProjection.nativeSourceFrame))
    #expect(samePose(retained.nativeCOMShadow, original.nativeCOMShadow))
    #expect(retained.actualRecipes.count == 4 && retained.actualRecipes.count == original.actualRecipes.count)
    for (a, b) in zip(retained.actualRecipes, original.actualRecipes) {
      #expect(a.kind == b.kind && a.hull == b.hull && samePose(a.pose, b.pose))
      #expect(a.mesh.vertices == b.mesh.vertices && a.mesh.faces == b.mesh.faces)
      #expect(a.velocity == b.velocity && a.angularVelocity == b.angularVelocity)
      #expect(a.massKilograms == b.massKilograms && a.maximumEnergy == b.maximumEnergy)
    }
    #expect(retained.materialPoints.count == 32 && retained.materialPoints.count == original.materialPoints.count)
    for (a, b) in zip(retained.materialPoints, original.materialPoints) {
      #expect(a.role == b.role && a.recipeVertex == b.recipeVertex && a.atlasVertex == b.atlasVertex)
      #expect(same(a.projectedPosition, b.projectedPosition))
      #expect(a.representedRecipePosition == b.representedRecipePosition && same(a.projectedMinusRecipe, b.projectedMinusRecipe))
    }
    let initial = try S.prepareConstrainedCellStart(source, cutHeadEdges: [.head0],
      anchorTime: originalTime, activeBasis: [], work: &work)
    #expect(initial.initialSeed === source && initial.anchorTime == originalTime && initial.elapsed == .point(0))
    #expect(initial.sourceBoundary.patches.count == 1 && initial.sourceBoundary.parentView.atlas === source.view.atlas)
    #expect(preparation.matchesCurrentBirthSource(game: game, workOwner: workOwner))
    #expect(game.commander == commander && game.bodies == bodies)
    #expect(game.storedFlightSimulation() == flight && game.nativeStationRuntimeEpoch == epoch)
    #expect(game.c01InquiryNativeRegistry === registry)
  }

  /// G1 supplies a genuinely different phase owner/current Game; no fake birth
  /// construction or fresh default allowance is created by this oracle.
  static func foreignOwner(_ preparation: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    game: borrowing Game, foreignWorkOwner: NativeC01InquiryNativeQueryWork,
    work: inout NativeC01InquiryCurveGeometry.Work) throws {
    let beforeTriangles = work.triangles, beforeNodes = work.nodes
    guard case .refused(.invalidSource, let actual) = S.prepareConstrainedInitialSeed(preparation,
      game: game, workOwner: foreignWorkOwner, work: &work) else {
      Issue.record("Foreign work owner cannot qualify actual birth source/time")
      throw P.Failure.unproven
    }
    #expect(actual.triangles == work.triangles - beforeTriangles && actual.triangles > 0)
    #expect(actual.nodes == work.nodes - beforeNodes && actual.nodes > 0)
  }

  /// Actual source change/install is performed by G1's fixture before calling.
  /// It must invalidate the existing genuine preparation, never reanchor it.
  static func changedSource(_ preparation: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    game: borrowing Game, workOwner: NativeC01InquiryNativeQueryWork,
    work: inout NativeC01InquiryCurveGeometry.Work) throws {
    #expect(!preparation.matchesCurrentBirthSource(game: game, workOwner: workOwner))
    guard case .refused(.invalidSource, _) = S.prepareConstrainedInitialSeed(preparation,
      game: game, workOwner: workOwner, work: &work) else {
      Issue.record("Changed source cannot reuse old genuine seed/time provenance")
      throw P.Failure.unproven
    }
  }

  /// G1 supplies actual deliberately constrained remaining Work; this helper
  /// never creates/resets allowances or infers that currentness was fully paid.
  static func allowance(_ preparation: NativeC01InquiryNativeQueryWork.GameBirthPreparation,
    game: borrowing Game, workOwner: NativeC01InquiryNativeQueryWork,
    work: inout NativeC01InquiryCurveGeometry.Work) throws {
    let beforeQueries = work.queries, beforeTriangles = work.triangles, beforeNodes = work.nodes
    guard case .refused(.allowance, let actual) = S.prepareConstrainedInitialSeed(preparation,
      game: game, workOwner: workOwner, work: &work) else {
      Issue.record("Actual remaining allowance must refuse before unpaid source retention")
      throw P.Failure.unproven
    }
    #expect(actual.queries == work.queries - beforeQueries)
    #expect(actual.triangles == work.triangles - beforeTriangles && actual.nodes == work.nodes - beforeNodes)
  }

  private static func same(_ a: S.VectorBox, _ b: S.VectorBox) -> Bool { a.x == b.x && a.y == b.y && a.z == b.z }
  private static func samePose(_ a: ShipPose, _ b: ShipPose) -> Bool {
    a.position == b.position && a.orientation.x == b.orientation.x && a.orientation.y == b.orientation.y && a.orientation.z == b.orientation.z
  }
}
