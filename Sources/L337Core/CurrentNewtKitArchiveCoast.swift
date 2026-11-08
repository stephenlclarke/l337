import Foundation

/// Pure coast calculation from an authenticated current archive input. A result
/// grants no publication/clock authority; Game rejoins its real accepted clock.
struct CurrentNewtArchiveCoastProjection: Sendable {
  let opening: EMPStoredObject
  let mass: CurrentNewtKitReceipt.MassProperties
  private let source: CurrentNewtKitSource

  fileprivate init(opening: EMPStoredObject, mass: CurrentNewtKitReceipt.MassProperties,
    source: CurrentNewtKitSource) {
    self.opening = opening
    self.mass = mass
    self.source = source
  }

  func projected(at time: Double) -> EMPStoredObject? {
    let duration = time - opening.physicalTime
    guard duration.isFinite, duration > 0, let physical = opening.body.physical else { return nil }
    let initial = CurrentNewtKitSource.State(
      pose: Game.modelPose(of: opening.body, player: .init()), velocity: physical.velocity,
      angularVelocity: physical.angularVelocity)
    guard let coast = CurrentNewtRigidCoast(initial: initial, mass: mass,
      duration: duration, maximumAngularSpeed: source.maximumAngularSpeed),
      let end = coast.state(at: duration) else { return nil }
    var stock = physical.currentNewtKitStock
    if var current = stock, let actuation = current.actuation {
      guard current.observe(at: time, work: current.work,
        charges: source.charges(at: time, actuation: actuation, work: current.work,
          serviceCapturedAt: current.serviceCapturedAt)) else { return nil }
      stock = current
    }
    var candidate = opening
    candidate.body.position = end.pose.position
    candidate.body.orientation = end.pose.orientation
    candidate.body.physical?.velocity = end.velocity
    candidate.body.physical?.angularVelocity = end.angularVelocity
    candidate.body.physical?.canonicalSpin = true
    candidate.body.rotation = 0
    candidate.body.rotationRate = 0
    candidate.body.physical?.currentNewtKitStock = stock
    candidate.physicalTime = time
    return candidate
  }
}

extension Game {
  func currentNewtArchiveCoastProjection(for object: EMPStoredObject)
    -> CurrentNewtArchiveCoastProjection?
  {
    guard let physical = object.body.physical,
      let issue = physical.currentNewtKitStock?.issue ?? physical.currentNewtKitReceipt?.issue,
      let source = CurrentNewtKitSource.source(for: issue) else { return nil }
    let mass: CurrentNewtKitSource.Mass
    if let stock = physical.currentNewtKitStock {
      guard let record = commander.savedEMPState?.records[stock.issue.person.source],
        record.hull == object, object.binding == nil,
        stock.phase == .stowed || stock.interruptedAt != nil
        || (stock.phase == .released && stock.work.rodMetres == source.stroke),
        stock.work.rodVelocity == 0,
        let load = currentNewtKitLoad(for: object.body),
        let cell = currentNewtCellComponentContract(for: object.body),
        let properties = source.loadedMechanicalMass(stock: stock, load: load, cell: cell)
      else { return nil }
      mass = properties
    } else if let receipt = physical.currentNewtKitReceipt {
      guard let person = physical.empCrewPod, commander.worldOwnedPod(person),
        let record = commander.savedEMPState?.records[person.source],
        record.pods.contains(where: { $0 == object && $0.binding == nil }),
        object.validCurrentOccupiedNewt(in: record),
        source.matches(receipt, observedAt: object.physicalTime) else { return nil }
      mass = source.podMass
    } else { return nil }
    return .init(opening: object, mass: mass, source: source)
  }

  /// The actual archive coast owner supplies its complete accepted gap. No
  /// duration truncation, active offscreen forces or partial object/service commit.
  func coastCurrentNewtArchiveObject(_ object: inout EMPStoredObject, to time: Double) -> Bool {
    guard time == commander.flightSimulation.physicalTime,
      let coast = currentNewtArchiveCoastProjection(for: object),
      let candidate = coast.projected(at: time) else { return false }
    object = candidate
    return true
  }
}
