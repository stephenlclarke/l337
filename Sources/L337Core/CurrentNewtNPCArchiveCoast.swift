import Foundation

extension Game {
  /// Pure complete-gap projection of the actual unbound NPC owner. No public
  /// snapshot, selector or decoded issue can acquire an archive/clock join here.
  func currentNewtUnboundNPCProjection(logical: ActorIdentity,
    snapshot: NPCPersistenceSnapshot, at time: Double) -> NPCPersistenceSnapshot? {
    guard time == commander.flightSimulation.physicalTime,
      commander.npcPersistence.unboundSnapshots[logical] == snapshot,
      commander.npcPersistence.binding(for: logical) == nil,
      snapshot.valid, let stock = snapshot.currentNewtKitStock,
      stock.issue.birthActor == logical,
      let source = CurrentNewtKitSource.source(for: stock.issue),
      source.matches(stock, at: snapshot.physicalTime),
      snapshot.rotation == 0, snapshot.rotationRate == 0,
      time > snapshot.physicalTime else { return nil }
    var result = snapshot
    if let record = commander.savedEMPState?.records[logical] {
      guard record.isRecovered, !record.terminal, record.savedOrdinaryTerminal == nil,
        record.hull.binding == nil, record.hull.physicalTime == snapshot.physicalTime,
        let protection = gameplayContext()?.protection,
        var expected = NPCPersistenceSnapshot.capture(body: record.hull.body,
          pose: .init(), physicalTime: record.hull.physicalTime, protection: protection)
      else { return nil }
      // These are the ledger's own resolved reference bindings, not independent
      // physical readings. Every actual body/resource/stock field must match.
      expected.firstAggressorBinding = snapshot.firstAggressorBinding
      expected.intentionTargetBinding = snapshot.intentionTargetBinding
      guard expected == snapshot,
        let projection = currentNewtArchiveCoastProjection(for: record.hull),
        let projected = projection.projected(at: time),
        let physical = projected.body.physical,
        let observed = physical.currentNewtKitStock,
        CurrentNewtKitStock.permitsTransition(from: stock, to: observed)
      else { return nil }
      result.position = projected.body.position
      result.orientation = projected.body.orientation
      result.velocity = physical.velocity
      result.angularVelocity = physical.angularVelocity
      result.rotation = projected.body.rotation
      result.rotationRate = projected.body.rotationRate
      result.currentNewtKitStock = observed
    } else {
      // A never-disabled original craft still owns all twelve born people. A
      // spent/missing-person claim requires its actual EMP/custody record above.
      guard stock.phase == .stowed, snapshot.catalogueShipID == source.parentCatalogueID,
        let resources = snapshot.npc.resources else { return nil }
      let load = CurrentNewtKitLoad(catalogueShipID: source.parentCatalogueID,
        r3SHA256: stock.issue.birthLoad.r3SHA256,
        cargo: snapshot.npc.ordinaryCargo, cargoProvenance: snapshot.npc.cargoProvenance,
        resources: resources, missiles: snapshot.missiles, ecmEnabled: snapshot.ecmEnabled,
        hasFuelScoops: snapshot.npc.hasFuelScoops, people: stock.issue.birthLoad.people)
      guard source.loadModel?.matches(load, selectedPerson: stock.issue.person) == true,
        let mass = source.loadedMechanicalMass(stock: stock, load: load),
        let coast = CurrentNewtRigidCoast(initial: .init(
          pose: .init(position: snapshot.position, orientation: snapshot.orientation),
          velocity: snapshot.velocity, angularVelocity: snapshot.angularVelocity),
          mass: mass, duration: time - snapshot.physicalTime,
          maximumAngularSpeed: source.maximumAngularSpeed),
        let end = coast.state(at: time - snapshot.physicalTime) else { return nil }
      result.position = end.pose.position
      result.orientation = end.pose.orientation
      result.velocity = end.velocity
      result.angularVelocity = end.angularVelocity
    }
    result.physicalTime = time
    return result.valid ? result : nil
  }
}
