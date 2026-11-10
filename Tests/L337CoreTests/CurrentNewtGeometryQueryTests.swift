import Foundation
import Testing

@testable import L337Core

struct CurrentNewtGeometryQueryTests {
  @Test
  func authoredAtmospherePointMassRequiresAnExactMatch() throws {
    let source = try #require(CurrentNewtKitSource.current)
    let atmosphere = try #require(source.releasedParts.first { $0.id == "charged-free-atmosphere" })
    let mass = atmosphere.mass
    try #require(mass.massKilograms == 2.5 && mass.inertiaKgM2 == Array(repeating: 0, count: 9))
    try #require(atmosphere.collisionMesh == nil && atmosphere.displayMesh == nil)
    #expect(!source.matchesMass(mass, mass))

    func component(_ properties: CurrentNewtKitSource.Mass, collisionMesh: Mesh? = nil)
      -> CurrentNewtKitComponent
    {
      .init(
        id: atmosphere.id, collisionMesh: collisionMesh, displayMesh: nil,
        pose: ShipPose(), massProperties: properties, velocity: .init(0, 0, 0),
        angularVelocity: .init(0, 0, 0))
    }

    let exact = component(mass)
    try #require(exact.validForCurrentNewtQuery)
    #expect(
      Game.currentNewtReleasedPartsMatchSource([exact], expected: [atmosphere], source: source))

    let changedMass = component(
      .init(
        massKilograms: mass.massKilograms + 1e-9,
        centreOfMassMetres: mass.centreOfMassMetres, inertiaKgM2: mass.inertiaKgM2))
    try #require(changedMass.validForCurrentNewtQuery)
    #expect(
      !Game.currentNewtReleasedPartsMatchSource(
        [changedMass], expected: [atmosphere], source: source))

    let malformedMass = CurrentNewtKitSource.Mass(
      massKilograms: mass.massKilograms,
      centreOfMassMetres: mass.centreOfMassMetres, inertiaKgM2: [1, 0, 0, 0, 0, 0, 0, 0, 0])
    let malformedReference = CurrentNewtKitSource.ReleasedPart(
      id: atmosphere.id, mass: malformedMass,
      collisionMesh: nil, displayMesh: nil)
    #expect(
      !Game.currentNewtReleasedPartsMatchSource(
        [component(malformedMass)], expected: [malformedReference], source: source))

    let mesh = try #require(source.releasedParts.compactMap(\.collisionMesh).first)
    let substitutedGeometry = component(mass, collisionMesh: mesh)
    try #require(substitutedGeometry.validForCurrentNewtQuery)
    #expect(
      !Game.currentNewtReleasedPartsMatchSource(
        [substitutedGeometry], expected: [atmosphere], source: source))
  }

  @Test
  func actualSystemComponentsRoundTripThroughBodyModelExactlyOnce() throws {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyActualSystemComponentsRoundTripThroughBodyModelExactlyOnce(game)
  }

  @inline(never)
  private func verifyActualSystemComponentsRoundTripThroughBodyModelExactlyOnce(_ game: Game) throws {
    let bodyCandidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate)
    let componentsCandidate = try game.currentNewtGeometryComponents(for: body)
    let components = try #require(componentsCandidate)
    try #require(components.count > 1 && components.allSatisfy(\.validForCurrentNewtQuery))
    let bodyModel = game.modelPose(of: body)
    for component in components {
      guard let mesh = component.collisionMesh,
        let query = component.collisionMesh(relativeTo: bodyModel)
      else { continue }
      #expect(mesh.vertices.count == query.vertices.count && mesh.faces == query.faces)
      for index in mesh.vertices.indices {
        let expected = component.pose.systemPoint(mesh.vertices[index])
        let projected = bodyModel.systemPoint(query.vertices[index])
        #expect((projected - expected).length < 1e-6)
      }
      #expect(component.collisionTriangles <= 512)
    }
    #expect(game.gameplayMeshOverrides[body.id] == nil)
    let compound = try game.currentNewtCompoundCollisionMeshes()
    #expect(compound[body.id]?.count == components.filter { $0.collisionMesh != nil }.count)
    try requireOriginalGeometryParity(game)
  }

  @Test
  func authenticatedDryPodKeepsSeparateCollisionAndDisplayAndMassOnlyAllocations() throws {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyAuthenticatedDryPodKeepsSeparateCollisionAndDisplayAndMassOnlyAllocations(game)
  }

  @inline(never)
  private func verifyAuthenticatedDryPodKeepsSeparateCollisionAndDisplayAndMassOnlyAllocations(_ game: Game) throws {
    let bodyCandidate2 = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate2)
    let partsCandidate = try game.currentNewtGeometryComponents(for: body)
    let parts = try #require(partsCandidate)
    let capsule = try #require(OriginalCryostasisCapsule.source)
    let dryCandidate = parts.first { $0.id == "unchanged-current-newt-dry" }
    let dry = try #require(dryCandidate)
    #expect(dry.collisionMesh?.vertices == capsule.collisionDesign.rawMesh.vertices)
    #expect(dry.collisionMesh?.faces == capsule.collisionDesign.rawMesh.faces)
    #expect(dry.displayMesh?.vertices == capsule.displayMesh.vertices)
    #expect(dry.displayMesh?.faces == capsule.displayMesh.faces)
    #expect(dry.displayMesh?.faceMaterials == capsule.displayMesh.faceMaterials)
    #expect(dry.displayMesh?.materials == capsule.displayMesh.materials)
    #expect(dry.displayMesh?.opticalEnclosure?.paneFace == capsule.displayMesh.opticalEnclosure?.paneFace)
    #expect(dry.displayMesh?.opticalEnclosure?.firstInteriorFace
      == capsule.displayMesh.opticalEnclosure?.firstInteriorFace)
    let gasCandidate = parts.first { $0.id == "charged-free-atmosphere" }
    let gas = try #require(gasCandidate)
    let personCandidate = parts.first { $0.id == "actual-identified-person" }
    let person = try #require(personCandidate)
    #expect(gas.collisionMesh == nil && gas.displayMesh == nil)
    #expect(person.collisionMesh == nil && person.displayMesh == nil)
    #expect(gas.massProperties.massKilograms > 0 && person.massProperties.massKilograms == 100)
    try requireOriginalGeometryParity(game)
  }

  @Test
  func actualRodShoeFacesKeepFullSolidGeometryAndRejectAChangedSurface() throws {
    let game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyActualRodShoeFacesKeepFullSolidGeometryAndRejectAChangedSurface(game)
  }

  @inline(never)
  private func verifyActualRodShoeFacesKeepFullSolidGeometryAndRejectAChangedSurface(_ game: Game) throws {
    let bodyCandidate3 = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate3)
    let partsCandidate2 = try game.currentNewtGeometryComponents(for: body)
    let parts = try #require(partsCandidate2)
    let source = try #require(CurrentNewtKitSource.current)
    let rods = parts.filter { $0.id.hasPrefix("moving-rod-") }
    let shoes = parts.filter { $0.id.hasPrefix("portable-thrust-shoe-") }
    try #require(rods.count == 2 && shoes.count == 2)
    for rod in rods {
      let pairs = shoes.compactMap { shoe -> (CurrentNewtKitComponent, CurrentNewtDriveSurface)? in
        guard let surface = CurrentNewtDriveContact.surface(rod: rod, shoe: shoe, source: source)
        else { return nil }
        return (shoe, surface)
      }
      try #require(pairs.count == 1)
      let (shoe, surface) = pairs[0]
      #expect(surface.rodID == rod.id && surface.shoeID == shoe.id)
      #expect(abs(surface.gapMetres) < 1e-6)
      #expect(abs(surface.relativeNormalVelocity) < 1e-6)
      let original = try #require(rod.collisionMesh)
      var vertices = original.vertices
      vertices[0].x += 0.001
      let forged = CurrentNewtKitComponent(id: rod.id,
        collisionMesh: .init(vertices: vertices, faces: original.faces, preserveWinding: true),
        displayMesh: rod.displayMesh, pose: rod.pose, massProperties: rod.massProperties,
        velocity: rod.velocity, angularVelocity: rod.angularVelocity)
      #expect(CurrentNewtDriveContact.surface(rod: forged, shoe: shoe, source: source) == nil)
      #expect(CurrentNewtDriveContact.surface(rod: shoe, shoe: rod, source: source) == nil)
    }
    try requireOriginalGeometryParity(game)
  }


  @Test
  func fullActualInventoryAndMassOnlyAllocationsReachMechanicalAndWorkQueries() throws {
    var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
    try verifyFullActualInventoryAndMassOnlyAllocationsReachMechanicalAndWorkQueries(&game)
  }

  @inline(never)
  private func verifyFullActualInventoryAndMassOnlyAllocationsReachMechanicalAndWorkQueries(_ game: inout Game) throws {
    let bodyCandidate4 = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
    let body = try #require(bodyCandidate4)
    let stock = try #require(body.physical?.currentNewtKitStock)
    let source = try #require(CurrentNewtKitSource.current)
    let partsCandidate3 = try game.currentNewtGeometryComponents(for: body)
    let parts = try #require(partsCandidate3)
    let model = try #require(source.loadModel)
    let loads = try #require(model.masses(stock.issue.birthLoad))
    let assembly = try #require(source.assemblyMass(at: source.phase(elapsed: 0)))
    let expected = assembly.massKilograms + loads.reduce(0) { $0 + $1.massKilograms }
    let ownedPreparationRequired1 = CurrentNewtComponentMechanics.momentum(parts,
      about: game.modelPose(of: body).position)
    let momentum = try #require(ownedPreparationRequired1)
    #expect(abs(momentum.massKilograms - expected) < 1e-6)
    let workCandidate = game.currentNewtRigidWorkObstacles(for: body)
    let work = try #require(workCandidate)
    #expect(work.count == parts.filter { $0.collisionMesh != nil }.count)
    let allSatisfied = work.allSatisfy { $0.identity == body.physical?.identity }
    #expect(allSatisfied)
    let ownedPreparationRequired2 = game.currentNewtBroadPhaseEnvelope(for: body)
    let envelope = try #require(ownedPreparationRequired2)
    #expect(envelope.faces.reduce(0) { $0 + $1.count - 2 } <= 512)
    let allSatisfied2 = envelope.vertices.allSatisfy(\.finite)
    #expect(allSatisfied2)
    try requireOriginalGeometryParity(game)
  }

}


@inline(never)
private func requireOriginalGeometryParity(_ game: Game) throws {
  let before = game
  for body in game.bodies {
    let projected = try game.currentNewtGeometryComponents(for: body)
    let original = try game.originalGeometryComponents(for: body)
    let actualCell = game.currentNewtCellComponentContract(for: body)
    let describedCell = game.originalGeometryCell(for: body)
    #expect((actualCell == nil) == (describedCell == nil))
    if let actualCell, let describedCell { #expect(originalGeometryCellMatches(actualCell, expected: describedCell)) }
    #expect((projected == nil) == (original == nil))
    if let projected, let original {
      try #require(projected.count == original.count)
      for (a, b) in zip(projected, original) {
        #expect(a.id == b.id && a.pose == b.pose && a.massProperties == b.massProperties)
        #expect(a.velocity == b.velocity && a.angularVelocity == b.angularVelocity)
        expectOriginalGeometryMesh(a.collisionMesh, b.collisionMesh)
        expectOriginalGeometryMesh(a.displayMesh, b.displayMesh)
      }
    }
    var unphysical = body
    unphysical.physical = nil
    let absent = try game.currentNewtGeometryComponents(for: unphysical)
    let originalAbsent = try game.originalGeometryComponents(for: unphysical)
    #expect(absent == nil && originalAbsent == nil)
    if body.physical?.currentNewtKitStock != nil {
      var foreign = body
      foreign.physical?.catalogueShipID = "SH999"
      #expect(throws: (any Error).self) { _ = try game.currentNewtGeometryComponents(for: foreign) }
      #expect(throws: (any Error).self) { _ = try game.originalGeometryComponents(for: foreign) }
    }
  }
  #expect(game.currentNewtNativeCommanderMatches(before) && game.bodies == before.bodies)
  #expect(game.scriptWorldSave == before.scriptWorldSave)
}

@inline(never)
private func expectOriginalGeometryMesh(_ a: Mesh?, _ b: Mesh?) {
  #expect((a == nil) == (b == nil))
  if let a, let b {
    #expect(a.vertices == b.vertices && a.faces == b.faces && a.details == b.details)
    #expect(a.materials == b.materials && a.faceMaterials == b.faceMaterials && a.faceTextures == b.faceTextures)
    #expect(a.opticalEnclosure?.paneFace == b.opticalEnclosure?.paneFace
      && a.opticalEnclosure?.firstInteriorFace == b.opticalEnclosure?.firstInteriorFace)
  }
}

// Descriptive test data only. The independent parity checks below may return
// these fields; only the real source factory constructs a production contract.
fileprivate struct OriginalGeometryCellDescription {
  let kitID: UUID
  let sourceSHA256: String
  let occupied: Bool
  let parts: [CurrentNewtKitSource.ReleasedPart]
  let mass: CurrentNewtKitReceipt.MassProperties

  init(stock: CurrentNewtKitStock, occupied: Bool,
    parts: [CurrentNewtKitSource.ReleasedPart], mass: CurrentNewtKitReceipt.MassProperties) {
    kitID = stock.issue.kitID
    sourceSHA256 = stock.issue.sourceSHA256
    self.occupied = occupied
    self.parts = parts
    self.mass = mass
  }
}

@inline(never)
private func originalGeometryCellMatches(
  _ cell: CurrentNewtCellComponentContract, expected: OriginalGeometryCellDescription
) -> Bool {
  guard cell.kitID == expected.kitID, cell.sourceSHA256 == expected.sourceSHA256,
    cell.occupied == expected.occupied, cell.mass == expected.mass,
    cell.parts.count == expected.parts.count else { return false }
  for (a, b) in zip(cell.parts, expected.parts) {
    guard a.id == b.id, a.mass == b.mass,
      originalGeometryMeshesMatch(a.collisionMesh, b.collisionMesh),
      originalGeometryMeshesMatch(a.displayMesh, b.displayMesh) else { return false }
  }
  return true
}

@inline(never)
private func originalGeometryMeshesMatch(_ a: Mesh?, _ b: Mesh?) -> Bool {
  switch (a, b) {
  case (nil, nil): return true
  case (let a?, let b?):
    return a.vertices == b.vertices && a.faces == b.faces && a.details == b.details
      && a.materials == b.materials && a.faceMaterials == b.faceMaterials
      && a.faceTextures == b.faceTextures
      && a.opticalEnclosure?.paneFace == b.opticalEnclosure?.paneFace
      && a.opticalEnclosure?.firstInteriorFace == b.opticalEnclosure?.firstInteriorFace
  default: return false
  }
}

extension Game {
  @inline(never)
  fileprivate func originalGeometryComponents(for body: borrowing SpaceBody) throws -> [CurrentNewtKitComponent]? {
    guard body.nativeGeometryHasPhysical() else { return nil }
    let state = CurrentNewtKitReceipt.BodyState(pose: modelPose(of: body),
      velocity: body.nativeGeometryVelocity()!, angularVelocity: body.nativeGeometryAngularVelocity()!)
    let now = storedFlightSimulation().physicalTime
    if let receipt = body.nativeGeometryReceipt() {
      guard currentOccupiedNewtPodHasCurrentCustody(body),
        let source = CurrentNewtKitSource.current,
        let parts = source.components(receipt: receipt, at: now, pod: state),
        Self.originalReleasedPartsMatchSource(parts, expected: source.releasedParts, source: source)
      else { throw MissionNativeBridgeError.invalidGeometry }
      return parts.sorted { $0.id < $1.id }
    }
    guard let stock = body.nativeGeometryStock() else { return nil }
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
    if let logical = body.nativeGeometryEMPSource() {
      guard nativeMechanicalStoredEMPState()?.valid == true,
        let record = nativeMechanicalStoredEMPState()?.records[logical],
        record.hull.binding == identity,
        record.hull.body.physical?.currentNewtKitStock == stock
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
    guard let load = originalGeometryLoad(for: body),
      let model = source.loadModel, model.matchesInventory(load),
      let allocations = model.allocations(load),
      let describedCell = originalGeometryCell(for: body),
      let cell = currentNewtCellComponentContract(for: body),
      originalGeometryCellMatches(cell, expected: describedCell),
      cell.kitID == stock.issue.kitID, cell.sourceSHA256 == stock.issue.sourceSHA256,
      let parts = source.components(stock: stock, at: now, parent: state, load: load, cell: cell),
      parts.allSatisfy(\.validForCurrentNewtQuery), Set(parts.map(\.id)).count == parts.count,
      let bare = parts.first(where: { $0.id == stock.issue.birthLoad.catalogueShipID + "-bare-carrier" }),
      source.matchesMass(bare.massProperties, source.bareParent),
      bare.collisionMesh != nil, bare.displayMesh != nil
    else { throw MissionNativeBridgeError.invalidGeometry }
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
      guard Self.originalReleasedPartsMatchSource(occupied, expected: cell.parts, source: source) else {
        throw MissionNativeBridgeError.invalidGeometry
      }
    }
    return parts.sorted { $0.id < $1.id }
  }

  @inline(never)
  private static func originalReleasedPartsMatchSource(
    _ parts: [CurrentNewtKitComponent], expected: [CurrentNewtKitSource.ReleasedPart],
    source: CurrentNewtKitSource
  ) -> Bool {
    guard parts.allSatisfy(\.validForCurrentNewtQuery),
      parts.count == expected.count,
      Set(parts.map(\.id)) == Set(expected.map(\.id))
    else { return false }
    for reference in expected {
      let pointMass = reference.mass.inertiaKgM2.allSatisfy { $0 == 0 }
      guard let part = parts.first(where: { $0.id == reference.id }),
        pointMass
          ? part.massProperties == reference.mass
          : source.matchesMass(part.massProperties, reference.mass),
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

  @inline(never)
  fileprivate func originalGeometryLoad(for body: SpaceBody) -> CurrentNewtKitLoad? {
    guard let physical = body.physical, let stock = physical.currentNewtKitStock,
      let catalogue = physical.catalogueShipID,
      let r3 = OriginalFleetR3Data.contract(for: catalogue)
    else { return nil }
    let record = commander.savedEMPState?.records[stock.issue.person.source]
    let retained = stock.receipt?.loadAtRelease
    let retainedNPC = record?.activeTrafficTransfer?.npc
      ?? record?.custody.original.body.physical?.npc
    guard let resources = physical.npc?.resources ?? retained?.resources ?? retainedNPC?.resources,
      let cargo = physical.npc?.ordinaryCargo ?? record?.salvageCargo ?? retained?.cargo
    else { return nil }
    var people: [CurrentNewtKitLoad.Person] = []
    for person in stock.issue.birthLoad.people {
      guard let record else { people.append(person); continue }
      guard let outcome = record.crewOutcome(ordinal: person.identity.ordinal) else { return nil }
      switch outcome {
      case .aboard, .deceasedWithHull: people.append(person)
      case .captured:
        guard record.crewCaptures.contains(where: {
          $0.contains(person.identity.ordinal) && $0.valid(record: record)
        }) else { return nil }
      case .occupiedPod:
        guard record.podIndex(for: person.identity.ordinal) != nil else { return nil }
      }
    }
    let result = CurrentNewtKitLoad(catalogueShipID: catalogue, r3SHA256: r3.sourceSHA256,
      cargo: cargo,
      cargoProvenance: physical.npc?.cargoProvenance ?? retained?.cargoProvenance
        ?? retainedNPC?.cargoProvenance,
      resources: resources, missiles: body.missiles, ecmEnabled: body.ecmEnabled,
      hasFuelScoops: physical.npc?.hasFuelScoops ?? retained?.hasFuelScoops ?? retainedNPC?.hasFuelScoops,
      people: people)
    return result.structurallyValid ? result : nil
  }

  @inline(never)
  fileprivate func originalGeometryCell(for body: SpaceBody) -> OriginalGeometryCellDescription? {
    guard let physical = body.physical, let stock = physical.currentNewtKitStock,
      let source = CurrentNewtKitSource.current, source.matches(stock.issue),
      let load = originalGeometryLoad(for: body) else { return nil }
    let record = commander.savedEMPState?.records[stock.issue.person.source]
    let live = bodies.filter({ $0.id == body.id && $0.physical?.identity == physical.identity }).count == 1
      && bodies.contains(body)
    let archived = record?.hull.binding == nil && record?.hull.body == body
    guard live || archived else { return nil }
    if let record {
      guard record.valid, record.hull.body.physical?.currentNewtKitStock == stock,
        record.hull.binding == (live ? physical.identity : nil) else { return nil }
      if live, physical.empSource == nil {
        guard record.isRecovered,
          commander.npcPersistence.logicalIdentity(for: physical.identity) == record.source
        else { return nil }
      } else if let logical = physical.empSource, logical != record.source { return nil }
    } else {
      guard stock.phase == .stowed, physical.empSource == nil,
        commander.npcPersistence.logicalIdentity(for: physical.identity) == stock.issue.birthActor
      else { return nil }
    }
    let person = stock.issue.person
    if load.people.contains(where: { $0.identity == person && $0.profile == stock.issue.personProfile }) {
      guard commander.nativePeople?.admissions.contains(where: { $0.person == .emp(person) }) != true
      else { return nil }
      if let record = commander.savedEMPState?.records[person.source] {
        guard record.crewOutcome(ordinal: person.ordinal) == .aboard
          || record.crewOutcome(ordinal: person.ordinal) == .deceasedWithHull else { return nil }
      }
      return .init(stock: stock, occupied: true, parts: source.releasedParts, mass: source.podMass)
    }
    // A released cell's person belongs to its independently authenticated pod.
    // The parent carries no cell components; this contract is historical only.
    if stock.phase == .released, let receipt = stock.receipt,
      let record = commander.savedEMPState?.records[person.source],
      let pod = record.podIndex(for: person.ordinal),
      record.pods[pod].body.physical?.currentNewtKitReceipt == receipt {
      return .init(stock: stock, occupied: true, parts: source.releasedParts, mass: source.podMass)
    }
    guard let record = commander.savedEMPState?.records[person.source],
      record.hull.binding == (live ? physical.identity : nil),
      record.hull.body.physical?.currentNewtKitStock == stock,
      record.crewOutcome(ordinal: person.ordinal) == .captured,
      record.crewCaptures.contains(where: { $0.contains(person.ordinal) && $0.valid(record: record) }),
      commander.nativePeople?.admissions.filter({
        $0.person == .emp(person) && $0.origin == .capturedCrew && $0.valid(commander: commander)
      }).count == 1,
      stock.issue.configuration == CurrentNewtEmptyCellPhysicalSource.configurationID,
      stock.issue.sourceSHA256 == CurrentNewtEmptyCellPhysicalSource.configuredSourceSHA256,
      person.ordinal == CurrentNewtEmptyCellPhysicalSource.removedOriginalPersonOrdinal,
      let display = CurrentNewtEmptyCellDisplaySource.emptyDisplayMesh
    else { return nil }
    let parts = source.releasedParts.compactMap { part -> CurrentNewtKitSource.ReleasedPart? in
      if part.id == CurrentNewtEmptyCellPhysicalSource.removedPersonComponentID { return nil }
      return .init(id: part.id, mass: part.mass, collisionMesh: part.collisionMesh,
        displayMesh: part.id == CurrentNewtEmptyCellPhysicalSource.displayComponentID ? display : part.displayMesh)
    }
    guard parts.count + 1 == source.releasedParts.count,
      parts.map(\.id) == CurrentNewtEmptyCellPhysicalSource.retainedComponentIDs,
      parts.map({ $0.mass.massKilograms }) == CurrentNewtEmptyCellPhysicalSource.retainedComponentMassKilograms,
      let mass = CurrentNewtKitMass.combined(parts.map(\.mass)),
      CurrentNewtEmptyCellPhysicalSource.cellWithoutSelectedPerson.matches(
        massKilograms: mass.massKilograms, centreMetres: mass.centreOfMassMetres,
        inertiaAboutCentreOfMassKgM2: mass.inertiaKgM2) else { return nil }
    return .init(stock: stock, occupied: false, parts: parts, mass: mass)
  }
}
