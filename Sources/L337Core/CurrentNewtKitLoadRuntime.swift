import Foundation

extension CurrentNewtKitLoad {
  /// Real electrical clocks, charge/shield readings and heat may advance while
  /// mass-bearing stock remains fixed. This never ignores fuel or installed terms.
  func samePhysicalInventory(as other: Self) -> Bool {
    catalogueShipID == other.catalogueShipID && r3SHA256 == other.r3SHA256
      && cargo == other.cargo && cargoProvenance == other.cargoProvenance
      && missiles == other.missiles && ecmEnabled == other.ecmEnabled
      && hasFuelScoops == other.hasFuelScoops && people == other.people
      && resources.profile == other.resources.profile
      && resources.energyCapacity == other.resources.energyCapacity
      && resources.energyRecharge == other.resources.energyRecharge
      && resources.frontCapacity == other.resources.frontCapacity
      && resources.rearCapacity == other.resources.rearCapacity
      && resources.shieldRecharge == other.resources.shieldRecharge
      && resources.heatCapacity == other.resources.heatCapacity
      && resources.heatCooling == other.resources.heatCooling
      && resources.fuel == other.resources.fuel && resources.fuelCapacity == other.resources.fuelCapacity
      && resources.scoopRemainder == other.resources.scoopRemainder
  }
}

extension Game {
  /// Read actual live state first. A vacated hull retains its last real resources
  /// through the release/custody receipt; the current EMP manifest/people owner wins.
  @inline(never)
  func currentNewtKitLoad(for body: borrowing SpaceBody) -> CurrentNewtKitLoad? {
    guard body.nativeGeometryHasPhysical(), let stock = body.nativeGeometryStock(),
      let catalogue = body.nativeGeometryCatalogueID(),
      let sourceSHA = currentNewtLoadSourceSHA(catalogue)
    else { return nil }
    return currentNewtLoadFromObservedBody(body, stock: stock, catalogue: catalogue,
      sourceSHA: sourceSHA)
  }

  @inline(never)
  private func currentNewtLoadSourceSHA(_ catalogue: String) -> String? {
    OriginalFleetR3Data.contract(for: catalogue)?.sourceSHA256
  }

  @inline(never)
  private func currentNewtLoadFromObservedBody(
    _ body: borrowing SpaceBody, stock: CurrentNewtKitStock,
    catalogue: String, sourceSHA: String
  ) -> CurrentNewtKitLoad? {
    let record = nativeMechanicalStoredEMPState()?.records[stock.issue.person.source]
    let retained = stock.receipt?.loadAtRelease
    let retainedNPC = record?.activeTrafficTransfer?.npc
      ?? record?.custody.original.body.physical?.npc
    let npc = body.nativeLaunchNPC()
    guard let resources = npc?.resources ?? retained?.resources ?? retainedNPC?.resources,
      let cargo = npc?.ordinaryCargo ?? record?.salvageCargo ?? retained?.cargo
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
    let result = CurrentNewtKitLoad(catalogueShipID: catalogue, r3SHA256: sourceSHA,
      cargo: cargo,
      cargoProvenance: npc?.cargoProvenance ?? retained?.cargoProvenance
        ?? retainedNPC?.cargoProvenance,
      resources: resources, missiles: body.missiles, ecmEnabled: body.ecmEnabled,
      hasFuelScoops: npc?.hasFuelScoops ?? retained?.hasFuelScoops ?? retainedNPC?.hasFuelScoops,
      people: people)
    return result.structurallyValid ? result : nil
  }
}
