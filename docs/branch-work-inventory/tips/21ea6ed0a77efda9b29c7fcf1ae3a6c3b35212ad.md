# Branch work: feat(fleet): activate original Dorcas Racer leisure hull

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `21ea6ed0a77efda9b29c7fcf1ae3a6c3b35212ad` (2026-10-27T10:15:26Z).

Status: **useful-unintegrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/feat/m04-dorcas-racer`

## Work and commits

- `21ea6ed0a77efda9b29c7fcf1ae3a6c3b35212ad` - feat(fleet): activate original Dorcas Racer leisure hull. Changed paths and exact subjects are in [commits.json](../commits.json).
- `2e6b84265f603fd246215cb110465e70149f3dcc` - feat(fleet): integrate original Gopher miner hull. Changed paths and exact subjects are in [commits.json](../commits.json).
- `dc9452c6466eaf5ad44aebca1b6f50bb6ea993ea` - Merge pull request #270 from stephenlclarke/feat/m04-aplomado. Changed paths and exact subjects are in [commits.json](../commits.json).
- `e464a990ed4421452f33aa5845dcca46b5f466c4` - fix(c01): integrate historical Harrier source isolation. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `Sources/L337Core/OriginalDorcasRacerActivation.swift` | absent-in-main | `OriginalDorcasRacerActivation, Failure, supports, resolve, originalEquipmentBudget; @@ -0,0 +1,57 @@` |
| `Tests/L337CoreTests/OriginalDorcasRacerUnitTests.swift` | absent-in-main | `OriginalDorcasRacerUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalLeisureMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -0,0 +1,323 @@` |
| `docs/ISSUE-m04-dorcas-racer.md` | absent-in-main | `authority` |
| `docs/PR-m04-dorcas-racer.md` | absent-in-main | `test` |
| `Sources/L337Core/OriginalFleetDefinition.swift` | differs-from-main | `OriginalFleetValue, OriginalFleetDefinition, definition, sourceLabel; @@ -27,3 +27,4 @@ public struct OriginalFleetDefinition: Sendable {` |
| `Sources/L337Core/OriginalHullPhysicalContract.swift` | differs-from-main | `OriginalHullEnvelope, admission, OriginalHullPhysicalContract, Failure, field; @@ -383,2 +383,10 @@ struct OriginalHullPhysicalContract: Sendable {; @@ -792,2 +800,12 @@ struct OriginalHullPhysicalContract: Sendable {` |
| `Sources/L337Core/OriginalPlayerHullActivation.swift` | differs-from-main | `OriginalPlayerHullActivation, Failure, resolve, acquisitionPolicy, metadata, standardProfile; @@ -48,2 +48,3 @@ enum OriginalPlayerHullActivation {` |
| `Sources/L337Core/ShipPerformance.swift` | differs-from-main | `ShipPerformance, valid, supports; @@ -75,3 +75,3 @@ extension Commander {` |
| `Tests/L337CoreTests/OriginalAplomadoUnitTests.swift` | absent-in-main | `OriginalAplomadoUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -114,3 +114,3 @@ struct OriginalAplomadoUnitTests {; @@ -211,3 +211,3 @@ struct OriginalAplomadoUnitTests {` |
| `Tests/L337CoreTests/OriginalArnaCutterUnitTests.swift` | absent-in-main | `OriginalArnaCutterUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalTransporterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSalvageConsumersKeepCompleteApprovedGeometryAndAppearance; @@ -107,3 +107,3 @@ struct OriginalArnaCutterUnitTests {; @@ -210,3 +210,3 @@ struct OriginalArnaCutterUnitTests {` |
| `Tests/L337CoreTests/OriginalBadgerUnitTests.swift` | absent-in-main | `OriginalBadgerUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMinerMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -108,3 +108,3 @@ struct OriginalBadgerUnitTests {; @@ -185,3 +185,3 @@ struct OriginalBadgerUnitTests {` |
| `Tests/L337CoreTests/OriginalBarbaryUnitTests.swift` | absent-in-main | `OriginalBarbaryUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -91,3 +91,3 @@ struct OriginalBarbaryUnitTests {; @@ -164,3 +164,3 @@ struct OriginalBarbaryUnitTests {` |
| `Tests/L337CoreTests/OriginalBazaFighterUnitTests.swift` | absent-in-main | `OriginalBazaFighterUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -108,3 +108,3 @@ struct OriginalBazaFighterUnitTests {; @@ -185,3 +185,3 @@ struct OriginalBazaFighterUnitTests {` |
| `Tests/L337CoreTests/OriginalBazaMkIIUnitTests.swift` | absent-in-main | `OriginalBazaMkIIUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalBountyHunterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -113,3 +113,3 @@ struct OriginalBazaMkIIUnitTests {; @@ -190,3 +190,3 @@ struct OriginalBazaMkIIUnitTests {` |
| `Tests/L337CoreTests/OriginalBurroActivationUnitTests.swift` | differs-from-main | `OriginalBurroActivationUnitTests, retained, originalMechanicsReplaceOnlyTheBurroRuntimeAndKeepHistoricalFields, playerAndPhysicalMeshesKeepEveryApprovedMetreVertexMaterialAndTexture, standardFitUsesOriginalLimitsWithoutAddingEquipmentOrWorkTools, number; @@ -40,3 +40,3 @@ struct OriginalBurroActivationUnitTests {; @@ -121,3 +121,3 @@ struct OriginalBurroActivationUnitTests {` |
| `Tests/L337CoreTests/OriginalCarabaoCarrierUnitTests.swift` | absent-in-main | `OriginalCarabaoCarrierUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalTransporterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSalvageConsumersKeepCompleteApprovedGeometryAndAppearance; @@ -107,3 +107,3 @@ struct OriginalCarabaoCarrierUnitTests {; @@ -215,3 +215,3 @@ struct OriginalCarabaoCarrierUnitTests {` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3333 byte-identical paths; 166 absent paths; 656 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

Existing source or document statements to check; these are not audit test results:

- `Sources/L337Core/ShipPerformance.swift:23`: `/// Optional on historical TOMLs: absent work-tool support is fail-closed.`

## Identity references

Literal source references: `SH002`, `SH003`, `SH004`, `SH005`, `SH006`, `SH007`, `SH012`, `SH016`, `SH017`, `SH018`, `SH019`, `SH020`, `SH025`, `SH027`, `SH028`, `SH029`, `SH030`, `SH031`, `SH032`, `SH033`, `SH035`, `SH036`, `SH041`, `SH042`. Shared-registry mentions alone do not implement those missions.

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
