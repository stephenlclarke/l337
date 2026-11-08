import Foundation

/// Historical sightings only; neither browsing nor owning a hull records an encounter.
struct NativeFleetDiscoveryProgress: Sendable, Equatable {
  private static let eligibleIDs = Set(
    ShipCatalogue.all.filter {
      $0.originalDefinition != nil && $0.catalogue.discoveryEligible
    }.map(\.id))

  let encountered: Int
  let total: Int
  var label: String { "Seen \(encountered)/\(total)" }

  init(commander: borrowing Commander) {
    total = Self.eligibleIDs.count
    guard let discovery = commander.scriptState.savedFleetDiscovery,
      NativeFleetDiscoverySave.validateClaims(commander)
    else {
      encountered = 0
      return
    }
    encountered = discovery.entries.keys.filter { Self.eligibleIDs.contains($0) }.count
  }
}
