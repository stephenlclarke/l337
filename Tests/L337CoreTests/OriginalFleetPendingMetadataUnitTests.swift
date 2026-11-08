import Testing

@testable import L337Core

struct OriginalFleetPendingMetadataUnitTests {
  private func metadata(capital: Bool = false, ready: Bool = false) -> ShipCatalogueMetadata {
    .init(
      schemaVersion: 2, family: "source-only", aliases: [], objectKind: .ship, origin: .human,
      primaryType: .military, primaryRole: .military,
      roleWeights: ready ? [.init(role: .military, weight: 1)] : [], access: .normal,
      playerFlyable: ready && !capital, normalPurchaseEligible: ready && !capital,
      purchasePolicy: capital ? .never : ready ? .blueprintFabrication : .pendingFabrication,
      minimumBuildTechLevel: nil, isCapital: capital, capitalSubtype: capital ? .vessel : nil,
      collectionMilestone: capital ? .destruction : .blueprintAndFabrication,
      damagePolicy: .destructible, habitat: nil, discoveryEligible: true,
      encounterMode: ready ? .natural : .authored,
      mechanicsStatus: ready ? .ready : .pending,
      placementStatus: ready ? .declared : .pending, rarity: .pending,
      galaxies: ready ? [0] : [], regions: ready ? [.tradeLane] : [], authoredSystems: [],
      basis: "Explicit pending source: population and fabrication technology remain unissued.")
  }

  @Test func missingPopulationAndTechnologyCanBeRepresentedWithoutInventingAThreshold() {
    for capital in [false, true] {
      let source = metadata(capital: capital)
      #expect(source.valid(shipID: capital ? "SH043" : "SH036", performance: nil, nativeCombat: nil))
      #expect(!source.readyForNaturalEncounters && source.minimumBuildTechLevel == nil)
      #expect(source.encounterWeight(for: .military) == 0)
      #expect(!source.playerFlyable && !source.normalPurchaseEligible)
    }
  }

  @Test func pendingRarityCannotBecomeReadyOrIssueFabricationWithoutAnActualPolicy() throws {
    let source = metadata(ready: true)
    let performance = try #require(ShipCatalogue.ship("SH025")?.game)
    #expect(!source.valid(shipID: "SH036", performance: performance, nativeCombat: nil))
    #expect(!source.readyForNaturalEncounters)
  }
}
