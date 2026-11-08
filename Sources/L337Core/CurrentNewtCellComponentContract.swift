import Foundation

/// Source-owned expected parts for the actual selected person's custody. This
/// non-Codable value grants neither stock nor an actor and has no caller factory.
struct CurrentNewtCellComponentContract: Sendable {
  let kitID: UUID
  let sourceSHA256: String
  let occupied: Bool
  let parts: [CurrentNewtKitSource.ReleasedPart]
  let mass: CurrentNewtKitReceipt.MassProperties

  fileprivate init(stock: CurrentNewtKitStock, occupied: Bool,
    parts: [CurrentNewtKitSource.ReleasedPart], mass: CurrentNewtKitReceipt.MassProperties) {
    kitID = stock.issue.kitID
    sourceSHA256 = stock.issue.sourceSHA256
    self.occupied = occupied
    self.parts = parts
    self.mass = mass
  }
}

extension Game {
  @inline(never)
  func currentNewtCellComponentContract(for body: borrowing SpaceBody) -> CurrentNewtCellComponentContract? {
    guard body.nativeGeometryHasPhysical(), let stock = body.nativeGeometryStock(),
      let source = CurrentNewtKitSource.source(for: stock.issue), source.matches(stock.issue),
      let load = currentNewtKitLoad(for: body) else { return nil }
    return currentNewtCellForObservedLoad(body, stock: stock, source: source, load: load)
  }

  @inline(never)
  private func currentNewtCellForObservedLoad(
    _ body: borrowing SpaceBody, stock: CurrentNewtKitStock,
    source: CurrentNewtKitSource, load: CurrentNewtKitLoad
  ) -> CurrentNewtCellComponentContract? {
    let identity = body.nativeGeometryIdentity()!
    let record = CurrentNewtObservedEMPRecord.observe(
      state: nativeMechanicalStoredEMPState(), source: stock.issue.person.source)
    let bodyID = body.id
    let unique = bodies.filter({ $0.id == bodyID && $0.physical?.identity == identity }).count == 1
    let live: Bool
    if unique { live = bodies.contains(body) } else { live = false }
    let archived: Bool
    // Missing history cannot match an archive. Compare the complete actual body
    // inside its immutable observation, without force-unwrapping a full record.
    if let record { archived = record.matchesArchivedBody(body) } else { archived = false }
    guard live || archived else { return nil }
    if let record {
      guard record.valid, record.hasHullStock(stock),
        record.hasHullBinding(live ? identity : nil) else { return nil }
      if live, body.nativeGeometryEMPSource() == nil {
        guard record.isRecovered,
          nativeMechanicalStoredNPCPersistence().logicalIdentity(for: identity) == record.source
        else { return nil }
      } else if let logical = body.nativeGeometryEMPSource(), logical != record.source { return nil }
    } else {
      guard stock.phase == .stowed, body.nativeGeometryEMPSource() == nil,
        nativeMechanicalStoredNPCPersistence().logicalIdentity(for: identity) == stock.issue.birthActor
      else { return nil }
    }
    return currentNewtCellForPerson(body, stock: stock, source: source, load: load,
      live: live, identity: identity, record: record)
  }

  @inline(never)
  private func currentNewtCellForPerson(
    _ body: borrowing SpaceBody, stock: CurrentNewtKitStock, source: CurrentNewtKitSource,
    load: CurrentNewtKitLoad, live: Bool, identity: ActorIdentity,
    record: CurrentNewtObservedEMPRecord?
  ) -> CurrentNewtCellComponentContract? {
    let person = stock.issue.person
    if load.people.contains(where: { $0.identity == person && $0.profile == stock.issue.personProfile }) {
      guard commander.nativePeople?.admissions.contains(where: { $0.person == .emp(person) }) != true
      else { return nil }
      if let record {
        guard record.crewOutcome(ordinal: person.ordinal) == .aboard
          || record.crewOutcome(ordinal: person.ordinal) == .deceasedWithHull else { return nil }
      }
      return .init(stock: stock, occupied: true, parts: source.releasedParts, mass: source.podMass)
    }
    // A released cell's person belongs to its independently authenticated pod.
    // The parent carries no cell components; this contract is historical only.
    if stock.phase == .released, let receipt = stock.receipt,
      let record, record.podMatches(ordinal: person.ordinal, receipt: receipt) {
      return .init(stock: stock, occupied: true, parts: source.releasedParts, mass: source.podMass)
    }
    return currentNewtEmptyCellForCapturedPerson(stock: stock, source: source, person: person,
      live: live, identity: identity, record: record)
  }

  @inline(never)
  private func currentNewtEmptyCellForCapturedPerson(
    stock: CurrentNewtKitStock, source: CurrentNewtKitSource, person: EMPCrewIdentity,
    live: Bool, identity: ActorIdentity, record: CurrentNewtObservedEMPRecord?
  ) -> CurrentNewtCellComponentContract? {
    guard let record, record.hasHullBinding(live ? identity : nil),
      record.hasHullStock(stock),
      record.crewOutcome(ordinal: person.ordinal) == .captured,
      record.hasValidCapture(ordinal: person.ordinal),
      commander.nativePeople?.admissions.filter({
        $0.person == .emp(person) && $0.origin == .capturedCrew && $0.valid(commander: commander)
      }).count == 1,
      let empty = source.emptyCellParts()
    else { return nil }
    let (parts, mass) = empty
    return .init(stock: stock, occupied: false, parts: parts, mass: mass)
  }
}
