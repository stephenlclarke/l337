# Branch work: docs(m12): record finite-source review scope

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `1ec9c5522dce6749becfcaca2ec1a61c746a46dd` (2026-10-29T20:58:35Z).

Status: **useful-unintegrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/docs/m12-finite-source-review`

## Work and commits

- `1ec9c5522dce6749becfcaca2ec1a61c746a46dd` - docs(m12): record finite-source review scope. Changed paths and exact subjects are in [commits.json](../commits.json).
- `ad6724e60af6a2101fb68f8ba80fefbcf21ace02` - feat(m12): bound finite-disk reflector transfer. Changed paths and exact subjects are in [commits.json](../commits.json).
- `e0dd6ac12a477453d53fb59f9912f0c6b5dcf0dc` - feat(m12): bind Borrowed Dawn pack declaration. Changed paths and exact subjects are in [commits.json](../commits.json).
- `beb648d8555f242aae583b8ecebfd08984af1370` - fix(m12): reject opaque shutters touching mirror aperture. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `Sources/L337Core/NativeBorrowedDawnFiniteSource.swift` | absent-in-main | `NativeBorrowedDawnFiniteSource, Statistics, Result, Failure, evaluate, valid; @@ -0,0 +1,277 @@` |
| `Tests/L337CoreTests/NativeBorrowedDawnFiniteSourceUnitTests.swift` | absent-in-main | `NativeBorrowedDawnFiniteSourceUnitTests, receiver, fixedRadiancePolicyKeepsCalibrationAndFullSurfaceCellCanProvePositiveContribution, actualOffAxisGeometryCanExcludeTheEntireSolarDisk, partialDiskOverlapStaysAnIntervalInsteadOfAWholeCellCentreSample, sharedEndpointPartitionsRetainFullDomainAndBoundTheirWork; @@ -0,0 +1,164 @@` |
| `docs/ISSUE-m12-borrowed-dawn-pack-binding.md` | absent-in-main | `Exact resource/document path; @@ -0,0 +1,7 @@` |
| `docs/PR-m12-borrowed-dawn-pack-binding.md` | absent-in-main | `Exact resource/document path; @@ -0,0 +1,23 @@` |
| `Sources/L337Core/NativeBorrowedDawnOptics.swift` | absent-in-main | `NativeBorrowedDawnOptics, Rectangle, VisibilityBound, Interval, contained, Reading; @@ -112,2 +112,8 @@ enum NativeBorrowedDawnOptics {; @@ -139,2 +145,7 @@ enum NativeBorrowedDawnOptics {` |
| `Sources/L337Core/Resources/ScriptPacks/l337-borrowed-dawn/manifest.toml` | absent-in-main | `Exact resource/document path; @@ -0,0 +1,77 @@` |
| `Sources/L337Core/Resources/ScriptPacks/l337-borrowed-dawn/scripts/main.lua` | absent-in-main | `Exact resource/document path; @@ -0,0 +1,11 @@` |
| `Tests/L337CoreTests/NativeBorrowedDawnOpticsUnitTests.swift` | absent-in-main | `NativeBorrowedDawnOpticsUnitTests, receiver, evaluate, specularDirectionFiniteApertureAndOneCalibrationConservePower, sourceInverseSquareAndFiniteGeometryCannotInventAnEightyUnitTest, unresolvedOrBlockedWholeBeamCannotBecomeSafeFromItsMidpoint; @@ -104,2 +104,47 @@ struct NativeBorrowedDawnOpticsUnitTests {` |
| `Tests/L337CoreTests/NativeBorrowedDawnPackUnitTests.swift` | absent-in-main | `NativeBorrowedDawnPackFixture, NativeBorrowedDawnPackDocument, NativeBorrowedDawnPackUnitTests, source, document, exactCurrentDeclarationKeepsLogicalSourceSeparateFromRuntimeDefinition; @@ -0,0 +1,237 @@` |
| `Tests/L337CoreTests/NativeBorrowedDawnStageFixtureTests.swift` | absent-in-main | `NativeBorrowedDawnStageFixture, Stage, NativeBorrowedDawnStageFixtureTests, allNineAuthoredStagesKeepTheirOwnEventAndTargetRequirements, structuralStageRequirementsRefuseIncompleteAndForeignTargetShapes, bothSelectedBranchProofTargetsAreRequiredAndMixedHalvesNeverQualify; @@ -0,0 +1,152 @@` |
| `docs/gameplay-design/C10-PHYSICAL-SOURCE-BINDINGS.md` | absent-in-main | `value; @@ -190 +190,9 @@ Nine new methods/nine planned cases are authored UNRUN/unselected. They cover a; @@ -148 +148,43 @@ Root found one P2 on frozen optics leaf '256e1f898a78354a79ea1423fb22a60ebac1bfe` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3408 byte-identical paths; 92 absent paths; 658 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

Existing source or document statements to check; these are not audit test results:

- `docs/gameplay-design/C10-PHYSICAL-SOURCE-BINDINGS.md:96`: `This is a collimated, single-specular-direction approximation. The source sphere controls irradiance and reports its angular radius, but its finite disk, ray-angle spread, penumbra, coating microstructure, diffraction, p`
- `docs/gameplay-design/C10-PHYSICAL-SOURCE-BINDINGS.md:134`: `A physical receiver calibration mount can rotate its aperture from the fixed normal-operation 60-degree tilt toward 50 degrees at the nominal common-shaft pose. In the declared model its receiver cosine rises continuousl`

## Identity references

Literal source references: `SH028`, `SH061`, `l337.borrowed-dawn`, `l337.contract`, `l337.contract/borrowed-dawn`, `l337.design/borrowed-dawn`, `l337.guiding-light`, `l337.unwritten-route/clue`. Shared-registry mentions alone do not implement those missions.

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
