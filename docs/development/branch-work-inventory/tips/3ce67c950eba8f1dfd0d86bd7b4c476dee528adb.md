# Branch work: feat(fleet): compose authenticated transporter pilot with Chimango

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `3ce67c950eba8f1dfd0d86bd7b4c476dee528adb` (2026-10-29T18:03:38Z).

Status: **useful-unintegrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/feat/m04-warthog-6-chimango-composition`

## Work and commits

- `3ce67c950eba8f1dfd0d86bd7b4c476dee528adb` - feat(fleet): compose authenticated transporter pilot with Chimango. Changed paths and exact subjects are in [commits.json](../commits.json).
- `3f65adcf1d7f1737d9c9163ba774f9e8a33b335c` - feat(fleet): activate authored Chimango bounty hunter hull. Changed paths and exact subjects are in [commits.json](../commits.json).
- `223bdbb6fb201cef476aba1765746689865393ae` - feat(fleet): activate Warthog 10 Guard on frozen Mangalica. Changed paths and exact subjects are in [commits.json](../commits.json).
- `27f171b8470fc3c57285dff9648c0e01d64bcc96` - feat(fleet): activate Mangalica with authored accommodation. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `Sources/L337Core/OriginalChimangoActivation.swift` | absent-in-main | `OriginalChimangoActivation, Failure, supports, resolve, originalEquipmentBudget; @@ -0,0 +1,57 @@` |
| `Sources/L337Core/OriginalWarthog10GuardActivation.swift` | absent-in-main | `OriginalWarthog10GuardActivation, Failure, supports, resolve, originalAccommodation; @@ -0,0 +1,68 @@` |
| `Sources/L337Core/OriginalWarthog6Activation.swift` | absent-in-main | `OriginalWarthog6Activation, Failure, supports, resolve, originalAccommodation; @@ -0,0 +1,68 @@` |
| `Tests/L337CoreTests/OriginalChimangoUnitTests.swift` | absent-in-main | `OriginalChimangoUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalBountyHunterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance; @@ -130,3 +130,3 @@ struct OriginalChimangoUnitTests {; @@ -210,3 +210,3 @@ struct OriginalChimangoUnitTests {` |
| `Tests/L337CoreTests/OriginalWarthog10GuardUnitTests.swift` | absent-in-main | `OriginalWarthog10GuardUnitTests, retained, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalMilitaryMechanicsRetainAllHistoricalFieldsAndOtherHullBindings, physicalPlayerAndSourceNotesKeepCompleteApprovedGeometryAndAppearance` |
| `Tests/L337CoreTests/OriginalWarthog6UnitTests.swift` | absent-in-main | `OriginalWarthog6UnitTests, retained, performance, exactMetreContractRejectsOtherHullIdentityUnitsPathAndHash, changed, originalTransporterMechanicsRetainAllHistoricalFieldsAndOtherHullBindings` |
| `docs/ISSUE-m04-chimango.md` | absent-in-main | `Exact resource/document path` |
| `docs/ISSUE-m04-warthog-10-guard.md` | absent-in-main | `Exact resource/document path` |
| `docs/ISSUE-m04-warthog-6-transporter.md` | absent-in-main | `facts` |
| `docs/PR-m04-chimango.md` | absent-in-main | `retains, facts` |
| `docs/PR-m04-warthog-10-guard.md` | absent-in-main | `facts` |
| `docs/PR-m04-warthog-6-transporter.md` | absent-in-main | `cases` |
| `Sources/L337Core/OriginalFleetDefinition.swift` | differs-from-main | `OriginalFleetValue, OriginalFleetDefinition, definition, sourceLabel; @@ -27,3 +27,4 @@ public struct OriginalFleetDefinition: Sendable {; @@ -27,3 +27,4 @@ public struct OriginalFleetDefinition: Sendable {` |
| `Sources/L337Core/OriginalHullPhysicalContract.swift` | differs-from-main | `OriginalHullEnvelope, admission, OriginalHullPhysicalContract, Failure, field; @@ -207,2 +207,10 @@ struct OriginalHullPhysicalContract: Sendable {; @@ -417,2 +425,12 @@ struct OriginalHullPhysicalContract: Sendable {` |
| `Sources/L337Core/OriginalMangalicaActivation.swift` | absent-in-main | `OriginalMangalicaActivation, Failure, supports, resolve, originalAccommodation; @@ -0,0 +1,67 @@` |
| `Sources/L337Core/OriginalPlayerHullActivation.swift` | differs-from-main | `OriginalPlayerHullActivation, Failure, resolve, metadata, standardProfile; @@ -28,2 +28,3 @@ enum OriginalPlayerHullActivation {; @@ -41,3 +42,3 @@ enum OriginalPlayerHullActivation {` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3408 byte-identical paths; 45 absent paths; 658 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

## Identity references

Literal source references: `SH002`, `SH003`, `SH004`, `SH005`, `SH006`, `SH007`, `SH012`, `SH018`, `SH019`, `SH020`, `SH025`, `SH027`, `SH029`, `SH030`, `SH031`, `SH032`, `SH033`, `SH035`, `SH061`, `SH068`, `SH094`, `SH095`, `SH096`, `SH100`. Shared-registry mentions alone do not implement those missions.

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
