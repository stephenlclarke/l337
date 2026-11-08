import Foundation

extension SpaceBody {
  @inline(never)
  func nativeGeometryHasPhysical() -> Bool {
    withUnsafePointer(to: physical) { stored in
      if case .none = stored.pointee { return false }
      return true
    }
  }

  @inline(never)
  func nativeGeometryCrew() -> EMPCrewIdentity? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.empCrewPod
    }
  }

  @inline(never)
  func nativeGeometryIdentity() -> ActorIdentity? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.identity
    }
  }

  @inline(never)
  func nativeGeometryReceipt() -> CurrentNewtKitReceipt? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.currentNewtKitReceipt
    }
  }

  @inline(never)
  func nativeGeometryStock() -> CurrentNewtKitStock? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.currentNewtKitStock
    }
  }

  @inline(never)
  func nativeGeometryVelocity() -> Vector3? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.velocity
    }
  }

  @inline(never)
  func nativeGeometryAngularVelocity() -> Vector3? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.angularVelocity
    }
  }

  @inline(never)
  func nativeGeometryCatalogueID() -> String? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.catalogueShipID
    }
  }

  @inline(never)
  func nativeGeometryEMPSource() -> ActorIdentity? {
    withUnsafePointer(to: physical) { stored in
      stored.pointee?.empSource
    }
  }

}

private final class CurrentOccupiedNewtCustody {
  private let record: EMPHullRecord

  @inline(never)
  init?(state: EMPState?, source: ActorIdentity) {
    guard let record = state?.records[source] else { return nil }
    self.record = record
  }

  @inline(never)
  func matches(_ body: borrowing SpaceBody, person: EMPCrewIdentity, in game: borrowing Game) -> Bool {
    guard let podIndex = record.podIndex(for: person.ordinal) else { return false }
    // A crew identity can only come from this same immutable physical value.
    let identity = body.nativeGeometryIdentity()!
    guard record.pods[podIndex].binding == identity,
      record.pods[podIndex].body.id == body.id,
      record.pods[podIndex].body.physical?.currentNewtKitReceipt == body.nativeGeometryReceipt(),
      identity.system == game.systemIdentity,
      identity.visit == game.storedFlightSimulation().visit,
      game.nativeGeometryWorldOwnedPod(person),
      game.bodies.filter({ $0.physical?.identity == identity }).count == 1
    else { return false }
    return validateObservation(body, in: game)
  }

  @inline(never)
  private func validateObservation(_ body: borrowing SpaceBody, in game: borrowing Game) -> Bool {
    let observed = EMPStoredObject(
      body: copy body, pose: game.storedFlightSimulation().pose,
      time: game.storedFlightSimulation().physicalTime)
    return observed.validCurrentOccupiedNewt(in: record)
  }
}

extension Game {
  @inline(never)
  func currentOccupiedNewtPodHasCurrentCustody(_ body: borrowing SpaceBody) -> Bool {
    guard let person = body.nativeGeometryCrew(),
      nativeMechanicalStoredEMPState()?.valid == true,
      let custody = CurrentOccupiedNewtCustody(
        state: nativeMechanicalStoredEMPState(), source: person.source)
    else { return false }
    return custody.matches(body, person: person, in: self)
  }

  @inline(never)
  func currentOccupiedNewtPodMesh(_ body: SpaceBody) -> Mesh? {
    guard body.physical?.empCrewPod != nil,
      currentOccupiedNewtPodHasCurrentCustody(body),
      let source = CurrentNewtKitSource.current
    else { return nil }
    return Self.currentNewtPodCollisionMesh(source: source)
  }

  /// Only the authenticated emitted module is flattened, within the existing
  /// collision cap. Carrier components remain distinct throughout queries.
  static func currentNewtPodCollisionMesh(source: CurrentNewtKitSource) -> Mesh? {
    let meshes = source.releasedParts.compactMap(\.collisionMesh)
    guard !meshes.isEmpty,
      meshes.allSatisfy(CurrentNewtKitComponent.currentNewtCollisionMeshIsValid),
      meshes.reduce(0, { count, mesh in
        count + mesh.faces.reduce(0, { $0 + $1.count - 2 })
      }) <= 512
    else { return nil }
    var vertices: [Vector3] = []
    var faces: [[Int]] = []
    for mesh in meshes {
      let offset = vertices.count
      vertices += mesh.vertices
      faces += mesh.faces.map { $0.map { $0 + offset } }
    }
    return .init(vertices: vertices, faces: faces, preserveWinding: true)
  }
}
