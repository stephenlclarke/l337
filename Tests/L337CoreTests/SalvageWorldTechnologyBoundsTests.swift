import Foundation
import Testing

@testable import L337Core

struct SalvageWorldTechnologyBoundsTests {
  private let wreck = WreckIdentity(
    system: .init(galaxy: 0, system: 69), site: 710, lineage: 1)
  private let section = SalvageSectionProfile(
    index: 0, kind: .hull, localPosition: .init(0, 0, 0), normal: .init(0, 0, 1),
    radius: 10, workSeconds: 12, structural: true, technologyDefinitionIDs: [], sourceFaceIndex: 0)

  private func source(technology: Int) -> SalvageLootSource {
    .init(
      roles: [.generalShip], legalValue: 0, economy: 3, technology: technology,
      ownership: .abandoned, manifest: [])
  }

  private func record(
    plan: SalvageLootPlan, seed: UInt64, progress: AlienStorageWorldProgress, owner: UUID
  ) -> AlienStorageWorldRecord {
    .plan(.init(
      id: UUID(), owner: owner, seed: seed, plan: plan, inspectedAt: 0,
      requiredWorkSeconds: section.workSeconds, workSeconds: 0, damagedTechnology: false,
      depleted: false, destroyed: false, lastOperation: nil, progress: progress))
  }

  @Test func currentWorldTechnologyPassesInspectionEmissionAndColdWorldValidation() throws {
    let maximum = Universe.originalWorlds.authoring.technologyMaximum
    try #require(maximum == 20)
    try #require(Universe.systemsIncludingPlugh(number: 0)[69].technology == 16)
    for technology in [0, 14, 15, 16, maximum] {
      let ledger = SalvageLedger()
      let facts = try #require(ledger.freshNativeInspection(
        wreck: wreck, section: section, source: source(technology: technology)))
      #expect(facts.plan.source.technology == technology && facts.matches(ledger))
      let deterministic = SalvageLootProfiles.plan(
        section: facts.plan.section, seed: facts.seed, source: facts.plan.source)
      #expect(facts.plan == deterministic)
      try SalvageSectionEmissionView(
        seed: facts.seed, plan: facts.plan, progress: facts.progress).validate()
      // Validate unissued storage-domain values across the real encoded record boundary.
      let owner = UUID()
      let records = [record(
        plan: facts.plan, seed: facts.seed, progress: facts.progress, owner: owner)]
      try AlienStorageWorldValidation.validate(records, owner: owner, sources: [])
      let bytes = try JSONEncoder().encode(records)
      let cold = try JSONDecoder().decode([AlienStorageWorldRecord].self, from: bytes)
      #expect(cold == records)
      try AlienStorageWorldValidation.validate(cold, owner: owner, sources: [])
    }
  }

  @Test func technologyOutsideTheAuthoredRangeRefusesEverySalvageValidationPath() throws {
    let maximum = Universe.originalWorlds.authoring.technologyMaximum
    for technology in [-1, maximum + 1] {
      let ledger = SalvageLedger()
      let source = source(technology: technology)
      #expect(ledger.freshNativeInspection(wreck: wreck, section: section, source: source) == nil)
      let plan = SalvageLootProfiles.plan(
        section: .init(wreck: wreck, section: section.index),
        seed: ledger.nativeInspectionSeed, source: source)
      let progress = AlienStorageWorldProgress(
        issued: Array(repeating: 0, count: plan.items.count),
        discarded: Array(repeating: false, count: plan.items.count),
        structuralUnits: 0, issuedStructural: 0, materialKind: nil, nextLot: 0)
      #expect(throws: AlienStorageError.self) {
        try SalvageSectionEmissionView(
          seed: ledger.nativeInspectionSeed, plan: plan, progress: progress).validate()
      }
      let owner = UUID()
      let records = [record(
        plan: plan, seed: ledger.nativeInspectionSeed, progress: progress, owner: owner)]
      #expect(throws: AlienStorageError.self) {
        try AlienStorageWorldValidation.validate(records, owner: owner, sources: [])
      }
    }
  }
}
