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
    guard currentOccupiedNewtPodHasCurrentCustody(body),
      let source = CurrentNewtKitSource.current,
      let parts = source.components(receipt: receipt, at: now, pod: state),
      Self.currentNewtReleasedPartsMatchSource(parts, expected: source.releasedParts, source: source)
    else { throw MissionNativeBridgeError.invalidGeometry }
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
    guard stock.structurallyValid,
      body.nativeGeometryCatalogueID() == stock.issue.birthLoad.catalogueShipID, body.hull == .cobra,
      body.scriptNPC == nil, body.missionActorID == nil, body.missionInstanceID == nil,
      body.nativeGeometryCrew() == nil, identity.system == systemIdentity,
      identity.visit == storedFlightSimulation().visit,
      bodies.filter({ $0.physical?.identity == identity }).count == 1,
      bodies.contains(where: { $0.id == bodyID && $0.physical?.identity == identity }),
      let source = CurrentNewtKitSource.current, source.matches(stock.issue),
      source.matches(stock, at: now),
      stock.actuation == nil || stock.observedAt == now
    else { throw MissionNativeBridgeError.invalidGeometry }
    if stock.phase == .actuating && stock.interruptedAt == nil,
      !source.matchesAttachedObservation(stock: stock, state: state, at: now)
    { throw MissionNativeBridgeError.invalidGeometry }
    try requireCurrentNewtGeometryCustody(for: body, stock: stock, identity: identity, now: now)
    return try assembleCurrentNewtAttachedGeometry(for: body, stock: stock, source: source, state: state, now: now)
  }

  @inline(never)
  private func requireCurrentNewtGeometryCustody(
    for body: borrowing SpaceBody, stock: CurrentNewtKitStock, identity: ActorIdentity, now: Double
  ) throws {
    if let logical = body.nativeGeometryEMPSource() {
      guard nativeMechanicalStoredEMPState()?.valid == true,
        let record = CurrentNewtObservedEMPRecord.observe(
          state: nativeMechanicalStoredEMPState(), source: logical),
        record.hasHullBinding(identity), record.hasHullStock(stock)
      else { throw MissionNativeBridgeError.invalidGeometry }
    } else {
      guard let logical = nativeMechanicalStoredNPCPersistence().logicalIdentity(for: identity),
        logical == stock.issue.birthActor,
        let original = nativeMechanicalStoredNPCPersistence().snapshot(for: logical)?.currentNewtKitStock,
        CurrentNewtKitStock.permitsTransition(from: original, to: stock),
        stock.validForNPC(catalogueShipID: body.nativeGeometryCatalogueID(),
          actor: identity, physicalTime: now)
      else { throw MissionNativeBridgeError.invalidGeometry }
    }
  }

  @inline(never)
  private func assembleCurrentNewtAttachedGeometry(
    for body: borrowing SpaceBody, stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    state: CurrentNewtKitReceipt.BodyState, now: Double
  ) throws -> [CurrentNewtKitComponent] {
    guard let load = currentNewtKitLoad(for: body),
      let model = source.loadModel, model.matchesInventory(load),
      let allocations = model.allocations(load),
      let cell = currentNewtCellComponentContract(for: body),
      cell.kitID == stock.issue.kitID, cell.sourceSHA256 == stock.issue.sourceSHA256,
      let parts = source.components(stock: stock, at: now, parent: state, load: load, cell: cell),
      parts.allSatisfy(\.validForCurrentNewtQuery), Set(parts.map(\.id)).count == parts.count,
      let bare = parts.first(where: { $0.id == stock.issue.birthLoad.catalogueShipID + "-bare-carrier" }),
      source.matchesMass(bare.massProperties, source.bareParent),
      bare.collisionMesh != nil, bare.displayMesh != nil
    else { throw MissionNativeBridgeError.invalidGeometry }
    try requireCurrentNewtAssembledParts(parts, stock: stock, source: source, allocations: allocations, cell: cell)
    return parts.sorted { $0.id < $1.id }
  }

  @inline(never)
  private func requireCurrentNewtAssembledParts(
    _ parts: [CurrentNewtKitComponent], stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    allocations: [CurrentNewtKitLoadModel.Allocation], cell: CurrentNewtCellComponentContract
  ) throws {
    let releasedIDs = Set(cell.parts.map(\.id))
    let expected = Set(source.retainedParts.map(\.id))
      .union([stock.issue.birthLoad.catalogueShipID + "-bare-carrier"])
      .union(allocations.map(\.id))
      .union(stock.phase == .released ? Set<String>() : releasedIDs)
    guard Set(parts.map(\.id)) == expected, parts.count == expected.count else {
      throw MissionNativeBridgeError.invalidGeometry
    }
    for reference in source.retainedParts {
      guard let part = parts.first(where: { $0.id == reference.id }),
        source.matchesMass(part.massProperties, reference.stowed)
      else { throw MissionNativeBridgeError.invalidGeometry }
      let geometry: Mesh? = reference.mesh
      guard (part.collisionMesh == nil) == (geometry == nil),
        (part.displayMesh == nil) == (geometry == nil)
      else { throw MissionNativeBridgeError.invalidGeometry }
    }
    for reference in allocations {
      guard let part = parts.first(where: { $0.id == reference.id }),
        source.matchesMass(part.massProperties,
          CurrentNewtKitMass.translated(reference.mass, by: reference.offset * -1)),
        part.collisionMesh?.vertices == reference.mesh.vertices,
        part.collisionMesh?.faces == reference.mesh.faces,
        part.displayMesh?.vertices == reference.mesh.vertices,
        part.displayMesh?.faces == reference.mesh.faces
      else { throw MissionNativeBridgeError.invalidGeometry }
    }
    if stock.phase != .released {
      let occupied = parts.filter { releasedIDs.contains($0.id) }
      guard Self.currentNewtReleasedPartsMatchSource(occupied, expected: cell.parts, source: source) else {
        throw MissionNativeBridgeError.invalidGeometry
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

  private static func currentNewtReleasedPartsMatchSource(
    _ parts: [CurrentNewtKitComponent], expected: [CurrentNewtKitSource.ReleasedPart],
    source: CurrentNewtKitSource
  ) -> Bool {
    guard parts.allSatisfy(\.validForCurrentNewtQuery),
      parts.count == expected.count,
      Set(parts.map(\.id)) == Set(expected.map(\.id))
    else { return false }
    for reference in expected {
      guard let part = parts.first(where: { $0.id == reference.id }),
        source.matchesMass(part.massProperties, reference.mass),
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
