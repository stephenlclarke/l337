# Branch work: fix(ci): reduce the local TSAN working set

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `dfd4eee25f26ffa07ba4c288adb7a289ead8641b` (2026-10-28T10:11:48Z).

Status: **partially-integrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/fix/m01-local-tsan-memory`

## Work and commits

- `dfd4eee25f26ffa07ba4c288adb7a289ead8641b` - fix(ci): reduce the local TSAN working set. Changed paths and exact subjects are in [commits.json](../commits.json).
- `cee8ccc3a73050bc5d6f471ad4d3481570b6a692` - fix(ci): acquire the controller lease before local startup. Changed paths and exact subjects are in [commits.json](../commits.json).
- `f4beb7a7ed33d580bcb8712feac3c7cc58a5bd81` - feat(ci): execute sanitizer components with owned local authority. Changed paths and exact subjects are in [commits.json](../commits.json).
- `2c670642e0606d282d11d3cfeafd38c254da3537` - fix(ci): reduce ASAN test process memory retention. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `docs/ISSUE-m01-asan-test-memory.md` | byte-identical | `Exact resource/document path; @@ -0,0 +1,20 @@` |
| `docs/ISSUE-m01-local-sanitizers.md` | byte-identical | `Exact resource/document path; @@ -12,3 +12,3 @@ The adapter must use a distinct owned local approval and real local session IDs.; @@ -19,3 +19,3 @@ Every maintained 'Tools/' input participates in runtime identity. This source ch` |
| `docs/PR-m01-asan-test-memory.md` | byte-identical | `Exact resource/document path; @@ -0,0 +1,27 @@` |
| `docs/PR-m01-local-sanitizers.md` | byte-identical | `Exact resource/document path; @@ -4,3 +4,3 @@; @@ -70,3 +70,3 @@ G1 reserved policy storage under '~/Library/EliteNativeAuthorization/local-revie` |
| `Tools/CI/recoverable_shards.py` | differs-from-main | `Store, ObservedTestProgress, NativeAuthority, LocalAuthority, NativeBuilder, NativeMonitor; @@ -42,2 +42,3 @@ PACKED_ID_TARGET = 64; @@ -1470,2 +1471,5 @@ class NativeAuthority:` |
| `Tools/CI/test_recoverable_shards.py` | differs-from-main | `FakeExecutor, Fixture, PlanningTests, Builder, CheckpointTests, AdmissionTests; @@ -2837,3 +2837,4 @@ class AsanTestMemoryTests(Fixture):; @@ -2851,3 +2852,3 @@ class LocalSanitizerTests(Fixture):` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3369 byte-identical paths; 17 absent paths; 655 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

Existing source or document statements to check; these are not audit test results:

- `docs/ISSUE-m01-asan-test-memory.md:12`: `- Reuse the existing process monitor to sample aggregate resident size for fresh owned descendants. Retain the sampled maximum and fail when samples are missing or the configured worker allocation is exceeded.`
- `docs/PR-m01-asan-test-memory.md:13`: `'processes.json' retains sample count, helper sample count, current sum, high-water sum, configured budget and failure reason. Missing RSS, snapshot errors, no helper sample or a sum above 'recoverable_shards.admission.p`
- `docs/PR-m01-asan-test-memory.md:27`: `No native compiler, test, game, GUI, resource probe or 'make ci' ran in this source-only assignment. G1 is the sole native operator. Independent MBA review is required before integration. G1 must qualify actual ASAN exec`
- `docs/PR-m01-asan-test-memory.md:33`: `Four focused fake tests pass: two new role-profile cases and the two affected existing installation/refusal cases. The new cases exercise all 128 subsets of the seven roles, duplicate and extra roles, both supplied role`

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
