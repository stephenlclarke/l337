import Foundation

/// A projection of existing current-format EMP, cutting and receiving custody.
/// It is neither encoded nor issuable by a kill, catalogue flag or caller-supplied receipt.
struct NativeFleetBlueprintAcquisition: Sendable, Equatable {
  let ship: String
  let source: ActorIdentity
  let section: WreckSectionIdentity
  let collection: UUID
  let receivedMassKg: Double
}

extension Commander {
  /// Each current R3 contract supplies its own intake requirement.
  /// No mass or inertia of the source hull is inferred from that requirement.
  func fleetBlueprintAcquisition(for shipID: String) -> NativeFleetBlueprintAcquisition? {
    guard !OriginalDetailedHullStage.blocksRuntime(shipID),
      let contract = OriginalFleetR3Data.contract(for: shipID),
      contract.purchasePolicy == .blueprintFabrication,
      let acquisition = contract.acquisition, acquisition.requiresPhysicalIntake,
      let ship = ShipCatalogue.ship(shipID), ship.name == contract.name,
      ship.catalogue.family == contract.family, ship.catalogue.playerFlyable,
      ship.catalogue.purchasePolicy == .blueprintFabrication,
      let owner = equipmentOwnerID, let current = alienStorageState?.current,
      current.owner == owner, alienStorageStateValid, equipmentStateValid,
      let history = equipmentPurchaseHistory, history.owner == owner
    else { return nil }
    let native = current.salvage.native
    for intake in current.salvage.receivedStructure[shipID] ?? [] {
      let received = intake.record
      let item = intake.item
      guard received.owner == owner,
        case .structural = received.origin,
        case .collected(let receipt) = received.state,
        receipt.at <= flightSimulation.physicalTime,
        let plan = native.plans[received.plan],
        plan.plan.source.ownership == .abandoned, !plan.plan.source.stolenProvenance,
        let inspection = native.inspections[plan.plan.section],
        inspection.preinspection == nil, inspection.initialProgress.nextLot == 0,
        let work = native.works[inspection.id], case .fresh(let inspected) = work.inspection,
        inspected == inspection.id,
        work.releases > 0, let release = work.lastRelease,
        release.creditedWorkSeconds == inspection.sectionProfile.workSeconds,
        work.beganAt <= received.issuedAt, received.issuedAt <= receipt.at,
        let wreck = native.wrecks[plan.plan.section.wreck], wreck.catalogueShipID == shipID,
        case .emp(let source, let sequence) = wreck.source,
        let disabled = nativeEMPCustodyRecord(for: source), disabled.sequence == sequence,
        disabled.wreck == wreck.identity, disabled.weaponOwner == owner,
        disabled.custody.original.body.physical?.catalogueShipID == shipID,
        disabled.crewAboard == 0, disabled.lostCrewCount == 0,
        disabled.pods.count + disabled.capturedCrewCount == disabled.crewTotal,
        disabled.disableIncident.physicalTime <= inspection.inspectedAt,
        case .paid(let buyer, let operation) = disabled.weapon.provenance, buyer == owner,
        history.paid.contains(where: {
          $0.owner == owner && $0.transaction == operation && $0.price > 0
            // Int.max is the existing unlimited-cash snapshot marker, not an actual debit.
            && $0.binding.snapshot.funds != Int.max && $0.binding.snapshot.funds >= $0.price
            && $0.node == disabled.weapon.node && $0.binding.request.newItem == disabled.weapon.id
        }),
        item.identity.section == plan.plan.section, item.massKg.isFinite, item.massKg >= acquisition.receivedSampleMassKg,
        item.legality.ownership == .abandoned && !item.legality.stolenProvenance,
        case .commodity(let original) = item.content,
        case .cargo(let actual, let before, let after) = receipt.effect,
        actual == original, before >= 0, after >= before, after - before == actual.quantity
      else { continue }
      return .init(
        ship: shipID, source: source, section: plan.plan.section,
        collection: receipt.operation, receivedMassKg: item.massKg)
    }
    return nil
  }
}
