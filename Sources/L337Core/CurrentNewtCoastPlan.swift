import Foundation

/// Actual rigid, rod-locked current inputs. G3 supplies the full-tensor native
/// coast curve; these facts prescribe no constant-world-omega endpoint.
struct CurrentNewtCoastPlan: Sendable {
  enum Source: Sendable {
    case parent(CurrentNewtKitStock, CurrentNewtKitLoad, CurrentNewtCellComponentContract)
    case pod(CurrentNewtKitReceipt)
  }
  let interval: CurrentNewtMechanicalInterval
  let actor: ActorIdentity
  let source: Source
  let before: CurrentNewtKitReceipt.BodyState
  let initial: CurrentNewtKitReceipt.BodyState
  let internalBrakeAt: Double?
  let mass: CurrentNewtKitReceipt.MassProperties
  let components: [CurrentNewtKitComponent]
}

extension Game {
  func currentNewtCoastPlans(owner: CurrentNewtMechanicalPlan.Owner,
    record: borrowing EMPHullRecord, interval: CurrentNewtMechanicalInterval)
    -> [CurrentNewtCoastPlan]?
  {
    var result = [CurrentNewtCoastPlan(interval: interval, actor: owner.parent,
      source: .parent(owner.stock, owner.load, owner.cell), before: owner.state, initial: owner.state,
      internalBrakeAt: nil, mass: owner.mass, components: owner.components)]
    guard let receipt = owner.stock.receipt else { return result }
    guard let podIndex = record.podIndex(for: receipt.issue.person.ordinal) else { return nil }
    guard let actor = record.pods[podIndex].binding else { return result }
    guard let body = bodies.first(where: { $0.physical?.identity == actor }),
      body.physical?.currentNewtKitReceipt == receipt,
      currentOccupiedNewtPodHasCurrentCustody(body), let source = CurrentNewtKitSource.current,
      let components = source.components(receipt: receipt, at: interval.start,
        pod: currentNewtBodyState(body)) else { return nil }
    result.append(.init(interval: interval, actor: actor, source: .pod(receipt),
      before: currentNewtBodyState(body), initial: currentNewtBodyState(body), internalBrakeAt: nil,
      mass: source.podMass, components: components))
    return result
  }
}


extension CurrentNewtCoastPlan {
  static func afterLoadChange(owner: CurrentNewtMechanicalPlan.Owner,
    interval: CurrentNewtMechanicalInterval, source: CurrentNewtKitSource) -> Self? {
    guard let stopped = CurrentNewtKitBrake.retainedState(components: owner.components,
      mass: owner.mass, before: owner.state, maximumAngularSpeed: source.maximumAngularSpeed)
    else { return nil }
    let parts = owner.components.map { part in
      CurrentNewtKitComponent(id: part.id, collisionMesh: part.collisionMesh,
        displayMesh: part.displayMesh, pose: part.pose, massProperties: part.massProperties,
        velocity: stopped.velocity + stopped.angularVelocity.cross(part.pose.position - stopped.pose.position),
        angularVelocity: stopped.angularVelocity)
    }
    return .init(interval: interval, actor: owner.parent,
      source: .parent(owner.stock, owner.load, owner.cell), before: owner.state,
      initial: stopped, internalBrakeAt: interval.start, mass: owner.mass, components: parts)
  }
}
