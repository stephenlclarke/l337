# Branch work: chore(fleet): bind Aplomado to actual C01 canonical parent

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `c8ad8d0ac85f7ef33adb55d2f9ff18a8ed0bff58` (2026-10-27T07:51:23Z).

Status: **useful-unintegrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/feat/m04-aplomado`
- `local-git-database:refs/remotes/origin/feat/m04-aplomado`

## Work and commits

- `c8ad8d0ac85f7ef33adb55d2f9ff18a8ed0bff58` - chore(fleet): bind Aplomado to actual C01 canonical parent. Changed paths and exact subjects are in [commits.json](../commits.json).
- `f61f1309e7546030dc36edb6f54023eaa4814c14` - feat(fleet): activate original Aplomado Interceptor. Changed paths and exact subjects are in [commits.json](../commits.json).
- `4e046e901f036860b5f5e6fc32d79594f596e136` - merge(c01): bind qualified canonical fleet ancestry. Changed paths and exact subjects are in [commits.json](../commits.json).
- `2ddfd997141f216762567abf42717cbcd427abe9` - merge(c01): prepare historical Harrier fleet composition. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `Sources/L337Core/OriginalAplomadoActivation.swift` | absent-in-main | `OriginalAplomadoActivation, Failure, supports, resolve, originalAccommodation; @@ -0,0 +1,65 @@` |
| `Tests/L337CoreTests/OriginalAplomadoUnitTests.swift` | absent-in-main | `OriginalAplomadoUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -0,0 +1,311 @@` |
| `docs/ISSUE-m04-aplomado.md` | absent-in-main | `authority` |
| `docs/PR-m04-aplomado.md` | absent-in-main | `and, authority` |
| `Sources/L337Core/OriginalFleetDefinition.swift` | differs-from-main | `OriginalFleetValue, OriginalFleetDefinition, definition, sourceLabel; @@ -27,3 +27,4 @@ public struct OriginalFleetDefinition: Sendable {` |
| `Sources/L337Core/OriginalHullPhysicalContract.swift` | differs-from-main | `OriginalHullEnvelope, admission, OriginalHullPhysicalContract, Failure, field; @@ -223,2 +223,10 @@ struct OriginalHullPhysicalContract: Sendable {; @@ -576,2 +584,12 @@ struct OriginalHullPhysicalContract: Sendable {` |
| `Sources/L337Core/OriginalPlayerHullActivation.swift` | differs-from-main | `OriginalPlayerHullActivation, Failure, resolve, acquisitionPolicy, metadata, standardProfile; @@ -28,2 +28,3 @@ enum OriginalPlayerHullActivation {` |
| `Sources/L337Core/ShipPerformance.swift` | differs-from-main | `ShipPerformance, valid, supports; @@ -72,3 +72,4 @@ extension Commander {` |
| `Tests/L337CoreTests/NativeC01SurveyorUnitTests.swift` | differs-from-main | `C01SurveyorFixture, capture, held, commander, physicsGame, var; @@ -1,2 +1,3 @@; @@ -170,3 +171,5 @@ struct NativeC01SurveyorUnitTests {` |
| `Tests/L337CoreTests/OriginalArnaCutterUnitTests.swift` | absent-in-main | `OriginalArnaCutterUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalTransporterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSalvageConsumersKeepCompleteApprovedGeometryAndAppearance; @@ -65,3 +65,3 @@ struct OriginalArnaCutterUnitTests {; @@ -104,3 +104,4 @@ struct OriginalArnaCutterUnitTests {` |
| `Tests/L337CoreTests/OriginalBadgerUnitTests.swift` | absent-in-main | `OriginalBadgerUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMinerMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -66,3 +66,3 @@ struct OriginalBadgerUnitTests {; @@ -105,3 +105,4 @@ struct OriginalBadgerUnitTests {` |
| `Tests/L337CoreTests/OriginalBarbaryUnitTests.swift` | absent-in-main | `OriginalBarbaryUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -88,3 +88,4 @@ struct OriginalBarbaryUnitTests {; @@ -160,3 +161,4 @@ struct OriginalBarbaryUnitTests {` |
| `Tests/L337CoreTests/OriginalBazaFighterUnitTests.swift` | absent-in-main | `OriginalBazaFighterUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -66,3 +66,3 @@ struct OriginalBazaFighterUnitTests {; @@ -105,3 +105,4 @@ struct OriginalBazaFighterUnitTests {` |
| `Tests/L337CoreTests/OriginalBazaMkIIUnitTests.swift` | absent-in-main | `OriginalBazaMkIIUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalBountyHunterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -71,3 +71,3 @@ struct OriginalBazaMkIIUnitTests {; @@ -110,3 +110,4 @@ struct OriginalBazaMkIIUnitTests {` |
| `Tests/L337CoreTests/OriginalBurroActivationUnitTests.swift` | differs-from-main | `OriginalBurroActivationUnitTests, retained, originalMechanicsReplaceOnlyTheBurroRuntimeAndKeepHistoricalFields, playerAndPhysicalMeshesKeepEveryApprovedMetreVertexMaterialAndTexture, standardFitUsesOriginalLimitsWithoutAddingEquipmentOrWorkTools, number; @@ -37,3 +37,4 @@ struct OriginalBurroActivationUnitTests {; @@ -117,3 +118,4 @@ struct OriginalBurroActivationUnitTests {` |
| `Tests/L337CoreTests/OriginalCarabaoCarrierUnitTests.swift` | absent-in-main | `OriginalCarabaoCarrierUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalTransporterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSalvageConsumersKeepCompleteApprovedGeometryAndAppearance; @@ -66,3 +66,3 @@ struct OriginalCarabaoCarrierUnitTests {; @@ -104,3 +104,4 @@ struct OriginalCarabaoCarrierUnitTests {` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3333 byte-identical paths; 158 absent paths; 656 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

Existing source or document statements to check; these are not audit test results:

- `Sources/L337Core/ShipPerformance.swift:23`: `/// Optional on historical TOMLs: absent work-tool support is fail-closed.`

## Identity references

Literal source references: `SH002`, `SH003`, `SH004`, `SH005`, `SH006`, `SH007`, `SH012`, `SH016`, `SH017`, `SH018`, `SH019`, `SH020`, `SH025`, `SH026`, `SH027`, `SH028`, `SH029`, `SH030`, `SH031`, `SH032`, `SH033`, `SH035`, `SH036`, `SH041`. Shared-registry mentions alone do not implement those missions.

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
