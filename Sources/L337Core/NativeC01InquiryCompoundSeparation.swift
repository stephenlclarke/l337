import Foundation

/// Adopted C01 star-graph policy preparation. Inputs describe proposed actual
/// accepted events; they grant no cut/death/material/debris authority. G1 must
/// bind the real event and qualify all native remainder curves before commit.
enum NativeC01InquiryCompoundSeparation {
  typealias Role = NativeC01InquiryFixtureGeometry.Part
  struct Preparation: Sendable {
    let components: [NativeC01InquiryCompoundRigidState]
    let removedMaterial: [NativeC01InquiryCompoundRigidState.ReleasedPart]
    let removedHeadEdges: [Role]
  }

  static func prepare(_ current: NativeC01InquiryCompoundRigidState,
    destroyed: [Role], cutHeadEdges: [Role]) -> Preparation?
  {
    let roles = current.representation.mass.parts.map(\.kind)
    guard Set(destroyed.map(\.rawValue)).count == destroyed.count,
      Set(cutHeadEdges.map(\.rawValue)).count == cutHeadEdges.count,
      destroyed.allSatisfy(roles.contains),
      cutHeadEdges.allSatisfy({ $0 != .support && roles.contains(.support) && roles.contains($0) })
    else { return nil }
    if destroyed.isEmpty && cutHeadEdges.isEmpty {
      return .init(components: [current], removedMaterial: [], removedHeadEdges: [])
    }
    let living = roles.filter { !destroyed.contains($0) }
    let removedEdges = [Role.head0, .head1, .head2].filter { head in
      roles.contains(.support) && roles.contains(head)
        && (destroyed.contains(.support) || destroyed.contains(head) || cutHeadEdges.contains(head))
    }
    var components: [NativeC01InquiryCompoundRigidState] = []
    if living.contains(.support) {
      let joined = living.filter { $0 == .support || !removedEdges.contains($0) }
      guard let component = current.component(parts: joined) else { return nil }
      components.append(component)
    }
    for head in living where head != .support
      && (!living.contains(.support) || removedEdges.contains(head))
    {
      guard let component = current.component(parts: [head]) else { return nil }
      components.append(component)
    }
    var removed: [NativeC01InquiryCompoundRigidState.ReleasedPart] = []
    for role in roles where destroyed.contains(role) {
      guard let material = current.releasedPart(role) else { return nil }
      removed.append(material)
    }
    // Complete destruction may have no survivor; material routing is retained
    // for the real native destruction owner rather than manufactured as debris.
    return .init(components: components, removedMaterial: removed, removedHeadEdges: removedEdges)
  }
}
