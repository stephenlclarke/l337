import Foundation

extension CurrentNewtKitSource {
  struct Phase: Sendable {
    let lower: Double
    let lowerRate: Double
    let rod: Double
    let rodRate: Double
    let distance: Double
    let speed: Double
  }

  struct MovingMass: Sendable {
    let properties: Mass
    let relativeVelocity: Vector3
  }

  func phase(elapsed: Double, stopped: Bool = false) -> Phase {
    let time = max(0, min(duration, elapsed))
    let u = min(1, time / dropDuration)
    let lower = u <= 0.5 ? 2 * u * u : 1 - 2 * (1 - u) * (1 - u)
    let lowerRate = time >= dropDuration || stopped ? 0
      : (u <= 0.5 ? 4 * u : 4 * (1 - u)) / dropDuration
    let eject = max(0, time - dropDuration)
    let accelerationTime = releaseSpeed / ejectionAcceleration
    let acceleratedDistance = 0.5 * releaseSpeed * accelerationTime
    let distance = min(stroke + freeTravel, eject <= accelerationTime
      ? 0.5 * ejectionAcceleration * eject * eject
      : acceleratedDistance + releaseSpeed * (eject - accelerationTime))
    let speed = stopped ? 0 : min(releaseSpeed, ejectionAcceleration * eject)
    return .init(lower: lower, lowerRate: lowerRate, rod: min(1, distance / stroke),
      rodRate: distance < stroke && !stopped ? speed / stroke : 0,
      distance: distance, speed: speed)
  }

  func movingMasses(_ p: Phase) -> [MovingMass] {
    var result = [MovingMass(properties: bareParent, relativeVelocity: .init(0, 0, 0))]
    result += retainedParts.map { part in
      let lower = part.lowered.centreOfMassMetres - part.stowed.centreOfMassMetres
      let rod = part.extended.centreOfMassMetres - part.lowered.centreOfMassMetres
      return MovingMass(properties: CurrentNewtKitMass.translated(part.stowed,
        by: lower * p.lower + rod * p.rod),
        relativeVelocity: lower * p.lowerRate + rod * p.rodRate)
    }
    result.append(.init(properties: CurrentNewtKitMass.translated(podMass,
      by: podOrigin + direction * p.distance),
      relativeVelocity: direction * p.speed))
    return result
  }

  func parentMass(at p: Phase) -> Mass? {
    CurrentNewtKitMass.combined(Array(movingMasses(p).dropLast()).map(\.properties))
  }

  func assemblyMass(at p: Phase) -> Mass? {
    CurrentNewtKitMass.combined(movingMasses(p).map(\.properties))
  }

  func massExpectationsAreCoherent() -> Bool {
    guard let a = assemblyMass(at: phase(elapsed: 0)),
      let b = assemblyMass(at: phase(elapsed: duration)),
      let before = parentMass(at: phase(elapsed: 0)),
      let after = parentMass(at: phase(elapsed: duration)),
      let occupied = CurrentNewtKitMass.combined(releasedParts.map(\.mass))
    else { return false }
    return matchesMass(a, installedMass) && matchesMass(b, separatedMass)
      && matchesMass(before, carrierBefore) && matchesMass(after, carrierAfter)
      && matchesMass(occupied, podMass)
  }

  func matchesMass(_ a: Mass, _ b: Mass) -> Bool {
    CurrentNewtKitMass.close(a, b, massTolerance: 1e-8, centreTolerance: 1e-9,
      inertiaTolerance: 1e-6)
  }

  /// Time determines the attached rack motion only. After unlock the real
  /// native drive reports rod displacement, velocity and consumed work.
  func work(at time: Double, actuation: CurrentNewtKitStock.Actuation,
    interruptedAt: Double? = nil) -> CurrentNewtKitStock.WorkState
  {
    let p = phase(elapsed: min(actuation.unlockAt, min(time, interruptedAt ?? time))
      - actuation.startedAt, stopped: interruptedAt != nil)
    return .init(loweredFraction: p.lower, rodMetres: 0, rodVelocity: 0,
      guideWorkJoules: dropWork * p.lower, ejectionWorkJoules: 0)
  }

  func phase(work: CurrentNewtKitStock.WorkState, at time: Double,
    actuation: CurrentNewtKitStock.Actuation?, interrupted: Bool) -> Phase {
    let rack = actuation.map { phase(elapsed: min(time, $0.unlockAt) - $0.startedAt,
      stopped: interrupted) } ?? phase(elapsed: 0)
    return .init(lower: work.loweredFraction, lowerRate: rack.lowerRate,
      rod: work.rodMetres / stroke, rodRate: interrupted ? 0 : work.rodVelocity / stroke,
      distance: 0, speed: 0)
  }

  func validWork(_ work: CurrentNewtKitStock.WorkState) -> Bool {
    work.structurallyValid && work.rodMetres <= stroke
      && work.rodVelocity >= 0 && work.rodVelocity <= releaseSpeed
      && (work.rodMetres < stroke || work.rodVelocity == 0)
      && abs(work.guideWorkJoules - dropWork * work.loweredFraction) <= 1e-6
      && abs(work.ejectionWorkJoules - maximumForceNewtons * work.rodMetres) <= 1e-6
      && work.ejectionWorkJoules <= ejectWork
      && work.ejectionWorkJoules <= initialCharges.ejectionMechanicalJoules
      && (work.rodMetres == 0 || work.loweredFraction == 1)
  }

  func charges(at time: Double, actuation: CurrentNewtKitStock.Actuation,
    interruptedAt: Double? = nil) -> CurrentNewtKitStock.Charges {
    charges(at: time, actuation: actuation,
      work: work(at: time, actuation: actuation, interruptedAt: interruptedAt))
  }

  func charges(at time: Double, actuation: CurrentNewtKitStock.Actuation,
    work: CurrentNewtKitStock.WorkState, serviceCapturedAt: Double? = nil)
    -> CurrentNewtKitStock.Charges {
    let elapsed = max(0, min(time, serviceCapturedAt ?? time) - actuation.startedAt)
    return .init(
      guideMechanicalJoules: max(0, initialCharges.guideMechanicalJoules - work.guideWorkJoules),
      ejectionMechanicalJoules: max(0, initialCharges.ejectionMechanicalJoules - work.ejectionWorkJoules),
      electricalJoules: max(0, initialCharges.electricalJoules
        - startupElectricalJoules - continuousPowerWatts * elapsed),
      oxygenKilograms: max(0, initialCharges.oxygenKilograms - oxygenKgPerSecond * elapsed),
      sorbentCapacityKilogramsCO2: max(0, initialCharges.sorbentCapacityKilogramsCO2
        - carbonDioxideKgPerSecond * elapsed))
  }

  func matchesCharges(_ a: CurrentNewtKitStock.Charges,
    _ b: CurrentNewtKitStock.Charges) -> Bool
  {
    a.structurallyValid && b.structurallyValid
      && abs(a.guideMechanicalJoules - b.guideMechanicalJoules) <= 1e-6
      && abs(a.ejectionMechanicalJoules - b.ejectionMechanicalJoules) <= 1e-6
      && abs(a.electricalJoules - b.electricalJoules) <= 1e-6
      && abs(a.oxygenKilograms - b.oxygenKilograms) <= 1e-10
      && abs(a.sorbentCapacityKilogramsCO2 - b.sorbentCapacityKilogramsCO2) <= 1e-10
  }

  func matches(_ stock: CurrentNewtKitStock, at time: Double) -> Bool {
    guard stock.structurallyValid, matches(stock.issue), time.isFinite,
      stock.observedAt <= time, stock.observedAt >= stock.issue.issuedAt, validWork(stock.work)
    else { return false }
    switch stock.phase {
    case .stowed: return matchesCharges(stock.charges, initialCharges)
    case .actuating:
      guard let a = stock.actuation, matches(a, issue: stock.issue),
        a.startedAt <= stock.observedAt,
        stock.observedAt <= a.unlockAt || stock.interruptedAt != nil,
        stock.work == work(at: stock.observedAt, actuation: a,
          interruptedAt: stock.interruptedAt)
      else { return false }
      return matchesCharges(stock.charges,
        charges(at: stock.observedAt, actuation: a, work: stock.work,
          serviceCapturedAt: stock.serviceCapturedAt))
    case .released:
      guard let receipt = stock.receipt else { return false }
      guard matches(receipt), let a = stock.actuation,
        stock.work.loweredFraction == 1, stock.observedAt >= a.unlockAt,
        stock.interruptedAt == nil || stock.work.rodVelocity == 0
      else { return false }
      return matchesCharges(stock.charges,
        charges(at: stock.observedAt, actuation: a, work: stock.work,
          serviceCapturedAt: stock.serviceCapturedAt))
    }
  }

  func matches(_ a: CurrentNewtKitStock.Actuation, issue: CurrentNewtKitIssue) -> Bool {
    matches(issue) && a.source == issue.person.source && a.sequence > 0
      && a.initialParent.structurallyValid
      && loadModel?.matches(a.load, selectedPerson: issue.person) == true
      && a.initialParent.angularVelocity.length <= maximumInitialAngularSpeed
      && a.startedAt.isFinite && a.startedAt >= issue.issuedAt
      && a.unlockAt.isFinite && abs(a.unlockAt - a.startedAt - dropDuration) <= 1e-9
      && a.completeAt.isFinite && abs(a.completeAt - a.startedAt - duration) <= 1e-9
      && a.deadline.isFinite && a.unlockAt < a.deadline
  }

  func components(stock: CurrentNewtKitStock, at time: Double, parent: State,
    load: CurrentNewtKitLoad, cell: CurrentNewtCellComponentContract? = nil)
    -> [CurrentNewtKitComponent]? {
    guard matches(stock, at: time) else { return nil }
    return components(stock: stock, work: stock.work, at: time, parent: parent, load: load, cell: cell)
  }

  /// Non-Codable planning supplies explicitly predicted work; it cannot alter
  /// an accepted stock or evade the current-scene observation join.
  func components(stock: CurrentNewtKitStock, work: CurrentNewtKitStock.WorkState,
    at time: Double, parent: State, load: CurrentNewtKitLoad,
    cell: CurrentNewtCellComponentContract? = nil) -> [CurrentNewtKitComponent]? {
    guard validWork(work), parent.structurallyValid,
      let model = loadModel, model.matchesInventory(load),
      let allocations = model.allocations(load),
      let hull = OriginalFleetRuntimeHullSource.source(for: "SH029")
    else { return nil }
    let p = phase(work: work, at: time, actuation: stock.actuation,
      interrupted: stock.interruptedAt != nil)
    var result = [CurrentNewtKitComponent(id: "SH029-bare-carrier", collisionMesh: hull.mesh,
      displayMesh: hull.mesh, pose: parent.pose, massProperties: bareParent,
      velocity: parent.velocity, angularVelocity: parent.angularVelocity)]
    for part in retainedParts {
      let lower = part.lowered.centreOfMassMetres - part.stowed.centreOfMassMetres
      let rod = part.extended.centreOfMassMetres - part.lowered.centreOfMassMetres
      let offset = lower * p.lower + rod * p.rod
      let relative = lower * p.lowerRate + rod * p.rodRate
      let worldOffset = parent.pose.orientation.apply(offset)
      result.append(.init(id: part.id, collisionMesh: part.mesh, displayMesh: part.mesh,
        pose: .init(position: parent.pose.position + worldOffset, orientation: parent.pose.orientation),
        massProperties: part.stowed,
        velocity: parent.velocity + parent.angularVelocity.cross(worldOffset)
          + parent.pose.orientation.apply(relative), angularVelocity: parent.angularVelocity))
    }
    for allocation in allocations {
      let offset = parent.pose.orientation.apply(allocation.offset)
      result.append(.init(id: allocation.id, collisionMesh: allocation.mesh,
        displayMesh: allocation.mesh,
        pose: .init(position: parent.pose.position + offset, orientation: parent.pose.orientation),
        massProperties: CurrentNewtKitMass.translated(allocation.mass, by: allocation.offset * -1),
        velocity: parent.velocity + parent.angularVelocity.cross(offset),
        angularVelocity: parent.angularVelocity))
    }
    if stock.phase != .released {
      let selectedParts: [ReleasedPart]
      if let cell {
        guard cell.kitID == stock.issue.kitID, cell.sourceSHA256 == sourceSHA256 else { return nil }
        selectedParts = cell.parts
      } else {
        guard load.people.contains(where: {
          $0.identity == stock.issue.person && $0.profile == stock.issue.personProfile
        }) else { return nil }
        selectedParts = releasedParts
      }
      let offset = podOrigin
      let worldOffset = parent.pose.orientation.apply(offset)
      let state = State(pose: .init(position: parent.pose.position + worldOffset,
        orientation: parent.pose.orientation), velocity: parent.velocity
          + parent.angularVelocity.cross(worldOffset),
        angularVelocity: parent.angularVelocity)
      result += podComponents(state: state, parts: selectedParts)
    }
    return result
  }

  func components(receipt: CurrentNewtKitReceipt, at time: Double, pod: State)
    -> [CurrentNewtKitComponent]?
  {
    guard matches(receipt, observedAt: time), pod.structurallyValid else { return nil }
    return podComponents(state: pod)
  }

  private func podComponents(state: State, parts: [ReleasedPart]? = nil) -> [CurrentNewtKitComponent] {
    (parts ?? releasedParts).map { part in
      .init(id: part.id, collisionMesh: part.collisionMesh, displayMesh: part.displayMesh,
        pose: state.pose, massProperties: part.mass, velocity: state.velocity,
        angularVelocity: state.angularVelocity)
    }
  }
}
