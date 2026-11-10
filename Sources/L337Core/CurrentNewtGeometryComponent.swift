import Foundation

extension CurrentNewtKitComponent {
  /// Source poses are already system-space. Display consumes them directly.
  var validForCurrentNewtQuery: Bool {
    !id.isEmpty && pose.position.finite && pose.orientation.validRotation
      && velocity.finite && angularVelocity.finite
      && CurrentNewtKitMass.componentIsValid(massProperties)
      && (collisionMesh.map(Self.currentNewtCollisionMeshIsValid) ?? true)
      && (displayMesh.map(Self.currentNewtDisplayMeshIsValid) ?? true)
  }

  /// Native body queries need body-local vertices; remove the actual body's
  /// system model pose once, rather than applying the parent a second time.
  func collisionMesh(relativeTo bodyModel: ShipPose) -> Mesh? {
    collisionMesh.map { mesh in
      .init(vertices: mesh.vertices.map { bodyModel.shipPoint(pose.systemPoint($0)) },
        faces: mesh.faces, preserveWinding: true)
    }
  }

  static func currentNewtCollisionMeshIsValid(_ mesh: Mesh) -> Bool {
    currentNewtDisplayMeshIsValid(mesh)
      && mesh.faces.reduce(0, { $0 + $1.count - 2 }) <= 512
  }

  private static func currentNewtDisplayMeshIsValid(_ mesh: Mesh) -> Bool {
    !mesh.vertices.isEmpty && mesh.vertices.allSatisfy(\.finite) && !mesh.faces.isEmpty
      && mesh.faces.allSatisfy({ face in
        face.count >= 3 && face.allSatisfy(mesh.vertices.indices.contains)
      })
  }
}

extension Game {
  /// Return authoritative system-space parts, including mass-only allocations.
  /// Nil means bare/unclaimed; invalid present evidence never falls back to a hull.
  @inline(never)
  func currentNewtGeometryComponents(for body: borrowing SpaceBody) throws -> [CurrentNewtKitComponent]? {
    guard body.nativeGeometryHasPhysical() else { return nil }
    if let diagnostic = nativeEncounterBirthDiagnostic, let actor = body.nativeGeometryIdentity() {
      diagnostic.clearComponentSourceRefusal(actor: actor)
    }
    let state = CurrentNewtKitReceipt.BodyState(pose: modelPose(of: body),
      velocity: body.nativeGeometryVelocity()!, angularVelocity: body.nativeGeometryAngularVelocity()!)
    let now = storedFlightSimulation().physicalTime
    if let receipt = body.nativeGeometryReceipt() {
      return try currentNewtReceiptGeometry(for: body, receipt: receipt, state: state, now: now)
    }
    return try currentNewtStockGeometry(for: body, state: state, now: now)
  }

  @inline(never)
  private func currentNewtReceiptGeometry(
    for body: borrowing SpaceBody, receipt: CurrentNewtKitReceipt,
    state: CurrentNewtKitReceipt.BodyState, now: Double
  ) throws -> [CurrentNewtKitComponent] {
    guard currentOccupiedNewtPodHasCurrentCustody(body) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "released-pod-current-custody", body: body, time: now)
    }
    guard let source = CurrentNewtKitSource.current else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "released-current-source-present", body: body, time: now)
    }
    guard let parts = source.components(receipt: receipt, at: now, pod: state) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "released-source-components", body: body, time: now)
    }
    guard Self.currentNewtReleasedPartsMatchSource(parts, expected: source.releasedParts, source: source) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "released-parts-match-source", body: body, time: now)
    }
    return parts.sorted { $0.id < $1.id }
  }

  @inline(never)
  private func currentNewtStockGeometry(
    for body: borrowing SpaceBody, state: CurrentNewtKitReceipt.BodyState, now: Double
  ) throws -> [CurrentNewtKitComponent]? {
    guard let stock = body.nativeGeometryStock() else { return nil }
    return try currentNewtAttachedGeometry(for: body, stock: stock, state: state, now: now)
  }

  @inline(never)
  private func currentNewtAttachedGeometry(
    for body: borrowing SpaceBody, stock: CurrentNewtKitStock,
    state: CurrentNewtKitReceipt.BodyState, now: Double
  ) throws -> [CurrentNewtKitComponent] {
    let identity = body.nativeGeometryIdentity()!
    let bodyID = body.id
    guard stock.structurallyValid else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "stock-structure", body: body, time: now)
    }
    guard body.nativeGeometryCatalogueID() == stock.issue.birthLoad.catalogueShipID else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "catalogue-birth-load", body: body, time: now)
    }
    guard body.hull == .cobra else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "control-hull", body: body, time: now)
    }
    guard body.scriptNPC == nil else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "script-npc-absent", body: body, time: now)
    }
    guard body.missionActorID == nil else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "mission-actor-absent", body: body, time: now)
    }
    guard body.missionInstanceID == nil else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "mission-instance-absent", body: body, time: now)
    }
    guard body.nativeGeometryCrew() == nil else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "crew-pod-absent", body: body, time: now)
    }
    guard identity.system == systemIdentity else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "current-system", body: body, time: now)
    }
    guard identity.visit == storedFlightSimulation().visit else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "current-visit", body: body, time: now)
    }
    guard bodies.filter({ $0.physical?.identity == identity }).count == 1 else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "unique-actor", body: body, time: now)
    }
    guard bodies.contains(where: { $0.id == bodyID && $0.physical?.identity == identity }) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "current-body-membership", body: body, time: now)
    }
    guard let source = CurrentNewtKitSource.current else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "current-source-present", body: body, time: now)
    }
    guard source.matches(stock.issue) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "current-source-matches-issue", body: body, time: now)
    }
    guard source.matches(stock, at: now) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "current-source-matches-stock-time", body: body, time: now)
    }
    guard stock.actuation == nil || stock.observedAt == now else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "actuation-observation-time", body: body, time: now)
    }
    if stock.phase == .actuating && stock.interruptedAt == nil,
      !source.matchesAttachedObservation(stock: stock, state: state, at: now)
    {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "attached-observation", body: body, time: now)
    }
    try requireCurrentNewtGeometryCustody(for: body, stock: stock, identity: identity, now: now)
    return try assembleCurrentNewtAttachedGeometry(for: body, stock: stock, source: source, state: state, now: now)
  }

  @inline(never)
  private func requireCurrentNewtGeometryCustody(
    for body: borrowing SpaceBody, stock: CurrentNewtKitStock, identity: ActorIdentity, now: Double
  ) throws {
    if let logical = body.nativeGeometryEMPSource() {
      guard nativeMechanicalStoredEMPState()?.valid == true else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "emp-state-valid", body: body, time: now)
      }
      guard let record = CurrentNewtObservedEMPRecord.observe(state: nativeMechanicalStoredEMPState(), source: logical) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "emp-source-observation", body: body, time: now)
      }
      guard record.hasHullBinding(identity) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "emp-current-hull-binding", body: body, time: now)
      }
      guard record.hasHullStock(stock) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "emp-current-hull-stock", body: body, time: now)
      }
    } else {
      guard let logical = nativeMechanicalStoredNPCPersistence().logicalIdentity(for: identity) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "npc-actual-logical-owner", body: body, time: now)
      }
      guard logical == stock.issue.birthActor else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "npc-logical-owner-equals-birth", body: body, time: now)
      }
      guard let original = nativeMechanicalStoredNPCPersistence().snapshot(for: logical)?.currentNewtKitStock else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "npc-original-stock-snapshot", body: body, time: now)
      }
      guard CurrentNewtKitStock.permitsTransition(from: original, to: stock) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "npc-stock-transition", body: body, time: now)
      }
      guard stock.validForNPC(catalogueShipID: body.nativeGeometryCatalogueID(), actor: identity, physicalTime: now) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "npc-current-stock-valid", body: body, time: now)
      }
    }
  }

  @inline(never)
  private func assembleCurrentNewtAttachedGeometry(
    for body: borrowing SpaceBody, stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    state: CurrentNewtKitReceipt.BodyState, now: Double
  ) throws -> [CurrentNewtKitComponent] {
    guard let load = currentNewtKitLoad(for: body) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "actual-load-present", body: body, time: now)
    }
    guard let model = source.loadModel else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "load-model-present", body: body, time: now)
    }
    guard model.matchesInventory(load) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "actual-load-matches-model", body: body, time: now)
    }
    guard let allocations = model.allocations(load) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "actual-load-allocations", body: body, time: now)
    }
    guard let cell = currentNewtCellComponentContract(for: body) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "actual-person-cell-contract", body: body, time: now)
    }
    guard cell.kitID == stock.issue.kitID else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "cell-kit-identity", body: body, time: now)
    }
    guard cell.sourceSHA256 == stock.issue.sourceSHA256 else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "cell-source-identity", body: body, time: now)
    }
    guard let parts = source.components(stock: stock, at: now, parent: state, load: load, cell: cell) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "source-assembled-parts", body: body, time: now)
    }
    guard parts.allSatisfy(\.validForCurrentNewtQuery) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "assembled-part-query-validity", body: body, time: now,
        detail: parts.map { "id=\($0.id),mass=\($0.massProperties),pose=\($0.pose),velocity=\($0.velocity),spin=\($0.angularVelocity),collisionFaces=\($0.collisionMesh?.faces.count ?? 0),displayFaces=\($0.displayMesh?.faces.count ?? 0)" }.joined(separator: ";"))
    }
    guard Set(parts.map(\.id)).count == parts.count else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "unique-part-ids", body: body, time: now)
    }
    guard let bare = parts.first(where: { $0.id == stock.issue.birthLoad.catalogueShipID + "-bare-carrier" }) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "bare-carrier-part", body: body, time: now)
    }
    guard source.matchesMass(bare.massProperties, source.bareParent) else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "bare-carrier-source-mass", body: body, time: now)
    }
    guard bare.collisionMesh != nil else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "bare-carrier-collision-present", body: body, time: now)
    }
    guard bare.displayMesh != nil else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "bare-carrier-display-present", body: body, time: now)
    }
    try requireCurrentNewtAssembledParts(parts, stock: stock, source: source,
      allocations: allocations, cell: cell, body: body, now: now)
    return parts.sorted { $0.id < $1.id }
  }

  @inline(never)
  private func requireCurrentNewtAssembledParts(
    _ parts: [CurrentNewtKitComponent], stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    allocations: [CurrentNewtKitLoadModel.Allocation], cell: CurrentNewtCellComponentContract,
    body: borrowing SpaceBody, now: Double
  ) throws {
    let releasedIDs = Set(cell.parts.map(\.id))
    let expected = Set(source.retainedParts.map(\.id))
      .union([stock.issue.birthLoad.catalogueShipID + "-bare-carrier"])
      .union(allocations.map(\.id))
      .union(stock.phase == .released ? Set<String>() : releasedIDs)
    guard Set(parts.map(\.id)) == expected else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "complete-part-id-set", body: body, time: now,
        detail: "actualIDs=\(parts.map(\.id)) expectedIDs=\(expected.sorted())")
    }
    guard parts.count == expected.count else {
      throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
        predicate: "complete-part-count", body: body, time: now,
        detail: "actualIDs=\(parts.map(\.id)) expectedIDs=\(expected.sorted())")
    }
    for reference in source.retainedParts {
      guard let part = parts.first(where: { $0.id == reference.id }) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "retained-part-present", body: body, time: now, detail: "part=\(reference.id)")
      }
      guard source.matchesMass(part.massProperties, reference.stowed) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "retained-part-source-mass", body: body, time: now, detail: "part=\(reference.id)")
      }
      let geometry: Mesh? = reference.mesh
      guard (part.collisionMesh == nil) == (geometry == nil) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "retained-collision-presence", body: body, time: now, detail: "part=\(reference.id)")
      }
      guard (part.displayMesh == nil) == (geometry == nil) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "retained-display-presence", body: body, time: now, detail: "part=\(reference.id)")
      }
    }
    for reference in allocations {
      guard let part = parts.first(where: { $0.id == reference.id }) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "allocation-part-present", body: body, time: now, detail: "part=\(reference.id)")
      }
      guard source.matchesMass(part.massProperties, CurrentNewtKitMass.translated(reference.mass, by: reference.offset * -1)) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "allocation-source-mass", body: body, time: now, detail: "part=\(reference.id)")
      }
      guard part.collisionMesh?.vertices == reference.mesh.vertices else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "allocation-collision-vertices", body: body, time: now, detail: "part=\(reference.id)")
      }
      guard part.collisionMesh?.faces == reference.mesh.faces else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "allocation-collision-faces", body: body, time: now, detail: "part=\(reference.id)")
      }
      guard part.displayMesh?.vertices == reference.mesh.vertices else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "allocation-display-vertices", body: body, time: now, detail: "part=\(reference.id)")
      }
      guard part.displayMesh?.faces == reference.mesh.faces else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "allocation-display-faces", body: body, time: now, detail: "part=\(reference.id)")
      }
    }
    if stock.phase != .released {
      let occupied = parts.filter { releasedIDs.contains($0.id) }
      guard Self.currentNewtReleasedPartsMatchSource(occupied, expected: cell.parts, source: source) else {
        throw refusedCurrentNewtComponentSource(nativeEncounterBirthDiagnostic,
          predicate: "occupied-cell-released-parts-match-source", body: body, time: now)
      }
    }
  }

  @inline(never)
  func currentNewtCompoundCollisionMeshes() throws -> [Int: [Mesh]] {
    var result: [Int: [Mesh]] = [:]
    for body in bodies where body.energy > 0 {
      guard let components = try currentNewtGeometryComponents(for: body) else { continue }
      let meshes = components.compactMap { $0.collisionMesh(relativeTo: modelPose(of: body)) }
      guard !meshes.isEmpty else { throw MissionNativeBridgeError.invalidGeometry }
      result[body.id] = meshes
    }
    return result
  }

  static func currentNewtReleasedPartsMatchSource(
    _ parts: [CurrentNewtKitComponent], expected: [CurrentNewtKitSource.ReleasedPart],
    source: CurrentNewtKitSource
  ) -> Bool {
    guard parts.allSatisfy(\.validForCurrentNewtQuery),
      parts.count == expected.count,
      Set(parts.map(\.id)) == Set(expected.map(\.id))
    else { return false }
    // Valid source components can include exact point allocations. The
    // tolerance check still requires positive-definite whole-body inertia.
    for reference in expected {
      guard let part = parts.first(where: { $0.id == reference.id }),
        part.massProperties == reference.mass
          || source.matchesMass(part.massProperties, reference.mass),
        (part.collisionMesh == nil) == (reference.collisionMesh == nil),
        (part.displayMesh == nil) == (reference.displayMesh == nil),
        part.collisionMesh?.vertices == reference.collisionMesh?.vertices,
        part.collisionMesh?.faces == reference.collisionMesh?.faces,
        part.displayMesh?.vertices == reference.displayMesh?.vertices,
        part.displayMesh?.faces == reference.displayMesh?.faces,
        part.displayMesh?.faceMaterials == reference.displayMesh?.faceMaterials,
        part.displayMesh?.materials == reference.displayMesh?.materials
      else { return false }
    }
    return true
  }
}

/// Only failed validation enters this helper. No source lookup, allocator,
/// validation replay, clock advance, geometry computation or fallback occurs.
@inline(never)
private func refusedCurrentNewtComponentSource(
  _ diagnostic: GameplayEncounterBirthDiagnostic?, predicate: String,
  body: borrowing SpaceBody, time: Double, detail: String = ""
) -> MissionNativeBridgeError {
  if let diagnostic, let actor = body.nativeGeometryIdentity() {
    let stock = body.nativeGeometryStock()
    let receipt = body.nativeGeometryReceipt()
    let npc = body.nativeLaunchNPC()
    diagnostic.recordComponentSourceRefusal(actor: actor, detail:
      "predicate=\(predicate) actor=\(actor) time=\(time) bodyID=\(body.id)"
      + " catalogue=\(body.nativeGeometryCatalogueID() ?? "nil") hull=\(body.hull)"
      + " configuration=\(stock?.issue.configuration ?? receipt?.issue.configuration ?? "nil")"
      + " issueSHA=\(stock?.issue.sourceSHA256 ?? receipt?.issue.sourceSHA256 ?? "nil")"
      + " birthActor=\(String(describing: stock?.issue.birthActor ?? receipt?.issue.birthActor))"
      + " birthSpawn=\(String(describing: stock?.issue.birthSpawn ?? receipt?.issue.birthSpawn))"
      + " stockPhase=\(String(describing: stock?.phase)) observedAt=\(String(describing: stock?.observedAt))"
      + " issuedAt=\(String(describing: stock?.issue.issuedAt ?? receipt?.issue.issuedAt))"
      + " birthLoad=\(String(describing: stock?.issue.birthLoad ?? receipt?.issue.birthLoad))"
      + " liveResources=\(String(describing: npc?.resources)) liveCargo=\(String(describing: npc?.ordinaryCargo))"
      + " liveCargoProvenance=\(String(describing: npc?.cargoProvenance))"
      + " missiles=\(body.missiles) ecm=\(body.ecmEnabled) scoops=\(String(describing: npc?.hasFuelScoops))"
      + " position=\(body.position) orientation=\(body.orientation) rotation=\(body.rotation) rotationRate=\(body.rotationRate)"
      + " velocity=\(String(describing: body.nativeGeometryVelocity())) angularVelocity=\(String(describing: body.nativeGeometryAngularVelocity()))"
      + " expectedNewtSHA=\(CurrentNewtKitPhysicalSource.sourceSHA256)"
      + " expectedBisonSHA=\(CurrentBisonWideShoePhysicalSource.sourceSHA256) \(detail)")
  }
  return .invalidGeometry
}
