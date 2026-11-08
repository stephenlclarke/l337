import Foundation

/// One immutable observation of already-owned EMP history for a Newt read.
/// Missing history never enters the full-record materialization frame. Geometry,
/// load and cell callers retain this reference, not an inline EMPHullRecord?.
/// This creates no stock, custody, body binding or persistence authority.
final class CurrentNewtObservedEMPRecord: Sendable {
  private let record: EMPHullRecord

  @inline(never)
  static func observe(state: EMPState?, source: ActorIdentity) -> CurrentNewtObservedEMPRecord? {
    guard let state, let index = state.records.index(forKey: source) else { return nil }
    return .init(state: state, index: index)
  }

  @inline(never)
  private init(state: EMPState, index: Dictionary<ActorIdentity, EMPHullRecord>.Index) {
    // Initialize the stored record once, after presence is known. The immutable
    // dictionary value keeps this index valid for the duration of this initializer.
    record = state.records[index].value
  }

  var source: ActorIdentity { record.source }
  var isRecovered: Bool { record.isRecovered }
  var valid: Bool { record.valid }
  var salvageCargo: [CommodityAmount] { record.salvageCargo }
  var retainedNPC: NPCState? {
    record.activeTrafficTransfer?.npc ?? record.custody.original.body.nativeLaunchNPC()
  }

  @inline(never)
  func matchesArchivedBody(_ body: borrowing SpaceBody) -> Bool {
    guard record.hull.binding == nil else { return false }
    return record.hull.body == body
  }

  @inline(never)
  func hasHullStock(_ stock: CurrentNewtKitStock) -> Bool {
    record.hull.body.nativeGeometryStock() == stock
  }

  func hasHullBinding(_ binding: ActorIdentity?) -> Bool { record.hull.binding == binding }

  func crewOutcome(ordinal: Int) -> EMPCrewCustodyOutcome? {
    record.crewOutcome(ordinal: ordinal)
  }

  @inline(never)
  func podMatches(ordinal: Int, receipt: CurrentNewtKitReceipt) -> Bool {
    guard let pod = record.podIndex(for: ordinal) else { return false }
    return record.pods[pod].body.nativeGeometryReceipt() == receipt
  }

  func hasPod(ordinal: Int) -> Bool { record.podIndex(for: ordinal) != nil }

  @inline(never)
  func hasValidCapture(ordinal: Int) -> Bool {
    // Keep the existing complete receipt validator, including episode, owner,
    // actor, ordinal and deadline checks. No selected-person shortcut is authority.
    for capture in record.crewCaptures where capture.contains(ordinal) {
      if capture.valid(record: record) { return true }
    }
    return false
  }
}
