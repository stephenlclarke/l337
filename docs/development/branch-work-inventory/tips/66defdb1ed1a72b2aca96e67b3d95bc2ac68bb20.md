# Branch work: feat(c03): retain bounded native consent candidates

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `66defdb1ed1a72b2aca96e67b3d95bc2ac68bb20` (2026-10-30T00:41:49Z).

Status: **useful-unintegrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/feat/hollow-manifest-consent-builders`

## Work and commits

- `66defdb1ed1a72b2aca96e67b3d95bc2ac68bb20` - feat(c03): retain bounded native consent candidates. Changed paths and exact subjects are in [commits.json](../commits.json).
- `4a0d4103090768bae9386d3c7d335fe2e4cb11a1` - test(c03): reject damaged seals without compromise history. Changed paths and exact subjects are in [commits.json](../commits.json).
- `03c4b9dc14ad3b2c92255d98d1fab46fd39a4d49` - feat(c03): validate admitted original source claims. Changed paths and exact subjects are in [commits.json](../commits.json).
- `3c349d27c0fd63ea446097686e297a0ec7bb27a0` - feat(c03): gate issued originals and retain actual root effects. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `Sources/L337Core/NativeHollowManifestCommission.swift` | absent-in-main | `NativeHollowManifestAction, NativeHollowManifestReview, NativeHollowManifestCommission, mission, operation, marked; @@ -459 +459,58 @@ extension Game {; @@ -87,4 +87,3 @@ enum NativeHollowManifestCommission {` |
| `Sources/L337Core/NativeHollowManifestSave.swift` | absent-in-main | `NativeHollowManifestSave, Failure, encode, decode, historicalOwnerMatches, historicalActor; @@ -293,2 +293,30 @@ extension NativeHollowManifestSave {` |
| `Sources/L337Core/NativeHollowManifestState.swift` | absent-in-main | `NativeHollowManifestState, Phase, Failure, Reference, Admission, RootIncident; @@ -827 +827,155 @@ extension NativeHollowManifestState {; @@ -713 +713,115 @@ extension NativeHollowManifestState {` |
| `Tests/L337CoreTests/NativeHollowManifestAdmittedClaimsUnitTests.swift` | absent-in-main | `NativeHollowManifestAdmittedClaimsUnitTests, Fixture, resources, fixture, stored, completeTypedAdmittedHistoryPassesStructuralChecksWithoutLifeOrMotionAuthority; @@ -175,3 +175,3 @@ struct NativeHollowManifestAdmittedClaimsUnitTests {; @@ -231,2 +231,5 @@ struct NativeHollowManifestAdmittedClaimsUnitTests {` |
| `Tests/L337CoreTests/NativeHollowManifestCommissionUnitTests.swift` | absent-in-main | `HollowManifestCommissionFixture, clean, review, selectConfirm, NativeHollowManifestCommissionUnitTests, explicitNativeConfirmPublishesExactlyTwoOriginalsAndOneAcceptance; @@ -488,2 +488,6 @@ struct NativeHollowManifestCommissionUnitTests {; @@ -7,3 +7,3 @@ import Testing` |
| `Tests/L337CoreTests/NativeHollowManifestStateUnitTests.swift` | absent-in-main | `NativeHollowManifestStateUnitTests, fixture, object, changed, effect, unadmittedStateCannotContainActorsProgressOrImplicitReadmissionMotion; @@ -644,2 +644,289 @@ struct NativeHollowManifestStateUnitTests {; @@ -412,2 +412,234 @@ struct NativeHollowManifestStateUnitTests {` |
| `docs/ISSUE-c03-consent-builders.md` | absent-in-main | `Exact resource/document path; @@ -0,0 +1,17 @@` |
| `docs/PR-c03-consent-builders.md` | absent-in-main | `Exact resource/document path; @@ -0,0 +1,19 @@` |
| `docs/ISSUE-c03-admitted-state-claims.md` | absent-in-main | `could; @@ -17 +17,5 @@ Author structural complete/malformed case tests for absent/partial/unadmitted en; @@ -0,0 +1,17 @@` |
| `docs/ISSUE-c03-original-life-root-retention.md` | absent-in-main | `Exact resource/document path; @@ -0,0 +1,15 @@` |
| `docs/PR-c03-admitted-state-claims.md` | absent-in-main | `could; @@ -23 +23,5 @@ Fixtures construct typed histories and bodies only. They do not establish an act; @@ -0,0 +1,23 @@` |
| `docs/PR-c03-original-life-root-retention.md` | absent-in-main | `name; @@ -0,0 +1,25 @@` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3383 byte-identical paths; 88 absent paths; 679 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

Existing source or document statements to check; these are not audit test results:

- `docs/PR-c03-admitted-state-claims.md:17`: `Eight focused methods/thirty-eight planned cases are authored but UNRUN/unselected. A complete typed admitted history and matching terminal history pass only structural checks; both retain the readmission refusal. Malfor`

## Identity references

Literal source references: `l337.contract/hollow-manifest`, `l337.hollow-manifest/accept`. Shared-registry mentions alone do not implement those missions.

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
