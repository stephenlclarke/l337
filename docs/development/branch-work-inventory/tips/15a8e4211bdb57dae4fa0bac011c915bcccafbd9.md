# Branch work: feat(fleet): activate authenticated Larvaal Warden hull

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `15a8e4211bdb57dae4fa0bac011c915bcccafbd9` (2026-10-29T17:41:23Z).

Status: **useful-unintegrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/feat/m04-larvaal-warden`

## Work and commits

- `15a8e4211bdb57dae4fa0bac011c915bcccafbd9` - feat(fleet): activate authenticated Larvaal Warden hull. Changed paths and exact subjects are in [commits.json](../commits.json).
- `7c34e140c594935be6dfa84438231af5f0eb3919` - test(fleet): require Leopard preview before comparison. Changed paths and exact subjects are in [commits.json](../commits.json).
- `35c92f94089200e9c9213261729daca15fc47d83` - feat(fleet): compose Puma with frozen Leopard source. Changed paths and exact subjects are in [commits.json](../commits.json).
- `e0761e76d281ba493df9f0297cad5b870f486eac` - feat(fleet): activate authored Leopard Fighter hull. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `Sources/L337Core/OriginalLarvaalWardenActivation.swift` | absent-in-main | `OriginalLarvaalWardenActivation, Failure, supports, resolve; @@ -0,0 +1,32 @@` |
| `Tests/L337CoreTests/OriginalLarvaalWardenUnitTests.swift` | absent-in-main | `OriginalLarvaalWardenUnitTests, retained, strictWardenAuthorityRejectsForeignDefinitionsAndModelSubstitutions, changed, originalMechanicsAndCompletePhysicalAppearanceReplaceOnlyTheWarden, alienTaxonomyRetainsFunctionalRoleWeightsAndEveryAccessPlacementFact; @@ -0,0 +1,287 @@` |
| `docs/ISSUE-m04-larvaal-warden.md` | absent-in-main | `facts` |
| `docs/PR-m04-larvaal-warden.md` | absent-in-main | `Exact resource/document path` |
| `Sources/L337Core/OriginalFleetDefinition.swift` | differs-from-main | `OriginalFleetValue, OriginalFleetDefinition, definition, sourceLabel; @@ -27,3 +27,4 @@ public struct OriginalFleetDefinition: Sendable {; @@ -27,3 +27,4 @@ public struct OriginalFleetDefinition: Sendable {` |
| `Sources/L337Core/OriginalHullPhysicalContract.swift` | differs-from-main | `OriginalHullEnvelope, admission, OriginalHullPhysicalContract, Failure, field; @@ -199,2 +199,10 @@ struct OriginalHullPhysicalContract: Sendable {; @@ -384,2 +392,10 @@ struct OriginalHullPhysicalContract: Sendable {` |
| `Sources/L337Core/OriginalLeopardFighterActivation.swift` | absent-in-main | `OriginalLeopardFighterActivation, Failure, supports, resolve; @@ -0,0 +1,33 @@` |
| `Sources/L337Core/OriginalPlayerHullActivation.swift` | differs-from-main | `OriginalPlayerHullActivation, Failure, resolve, intent, resolveAlien, allegiance; @@ -25,2 +25,3 @@ enum OriginalPlayerHullActivation {; @@ -43,2 +44,52 @@ enum OriginalPlayerHullActivation {` |
| `Sources/L337Core/OriginalPumaActivation.swift` | absent-in-main | `OriginalPumaActivation, Failure, supports, resolve; @@ -0,0 +1,33 @@` |
| `Sources/L337Core/ShipPerformance.swift` | differs-from-main | `ShipPerformance, valid, supports; @@ -72,2 +72,3 @@ extension Commander {; @@ -71,3 +71,3 @@ extension Commander {` |
| `Tests/L337CoreTests/OriginalBesraUnitTests.swift` | differs-from-main | `OriginalBesraUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalBountyHunterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -129,2 +129,3 @@ struct OriginalBesraUnitTests {; @@ -217,2 +218,3 @@ struct OriginalBesraUnitTests {` |
| `Tests/L337CoreTests/OriginalBurroActivationUnitTests.swift` | differs-from-main | `OriginalBurroActivationUnitTests, retained, originalMechanicsReplaceOnlyTheBurroRuntimeAndKeepHistoricalFields, playerAndPhysicalMeshesKeepEveryApprovedMetreVertexMaterialAndTexture, standardFitUsesOriginalLimitsWithoutAddingEquipmentOrWorkTools, number; @@ -36,2 +36,3 @@ struct OriginalBurroActivationUnitTests {; @@ -112,2 +113,3 @@ struct OriginalBurroActivationUnitTests {` |
| `Tests/L337CoreTests/OriginalDonkeyUnitTests.swift` | differs-from-main | `OriginalDonkeyUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalTraderMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -66,2 +66,3 @@ struct OriginalDonkeyUnitTests {; @@ -134,2 +135,3 @@ struct OriginalDonkeyUnitTests {` |
| `Tests/L337CoreTests/OriginalFleetCatalogueUnitTests.swift` | differs-from-main | `OriginalFleetCatalogueUnitTests, exactCatalogueJoinsPreserveAllOriginalIdentitiesRolesAndAccessRules, sourceProfilesRetainEveryAuthoredFieldAndDoNotReplaceExistingProfiles, sourceDisplayKeepsLargeIntegersAndNestedValuesWithoutFloatingConversion, sourceRangeConflictsAndQuestRestrictionsRemainExplicitAfterJoining; @@ -26,3 +26,3 @@ struct OriginalFleetCatalogueUnitTests {; @@ -26,3 +26,3 @@ struct OriginalFleetCatalogueUnitTests {` |
| `Tests/L337CoreTests/OriginalFleetDefinitionTests.swift` | differs-from-main | `OriginalFleetDefinitionTests, stagedDefinitionsPreserveKnownCurrentOriginalValuesAndConflicts; @@ -24,2 +24,3 @@ struct OriginalFleetDefinitionTests {; @@ -23,3 +23,3 @@ struct OriginalFleetDefinitionTests {` |
| `Tests/L337CoreTests/OriginalFleetShowroomModelsTests.swift` | differs-from-main | `OriginalFleetShowroomModelsTests, digest, completeManifestRemainsSeparateFromLiveCatalogue, retainedAndEffectiveNewModelsPreserveCoordinatesAndUnits, currentBrandingModelRetainsApprovedExactGeometryAndPalette, unknownIDAndAlteredAssetRefuse; @@ -24,2 +24,3 @@ struct OriginalFleetShowroomModelsTests {; @@ -23,3 +23,3 @@ struct OriginalFleetShowroomModelsTests {` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3408 byte-identical paths; 33 absent paths; 658 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

Existing source or document statements to check; these are not audit test results:

- `Sources/L337Core/ShipPerformance.swift:23`: `/// Optional on historical TOMLs: absent work-tool support is fail-closed.`

## Identity references

Literal source references: `SH000`, `SH001`, `SH002`, `SH003`, `SH004`, `SH005`, `SH006`, `SH007`, `SH012`, `SH018`, `SH019`, `SH020`, `SH023`, `SH025`, `SH027`, `SH029`, `SH030`, `SH031`, `SH032`, `SH033`, `SH035`, `SH040`, `SH043`, `SH061`. Shared-registry mentions alone do not implement those missions.

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
