# Branch work: feat(ci): execute sanitizer components with owned local authority

Audited 2026-11-01T12:45:12.064769+00:00. Baseline `0cc45dca928c7bae18a388fa775d7b53c6653d21`. Tip `f4beb7a7ed33d580bcb8712feac3c7cc58a5bd81` (2026-10-28T09:37:18Z).

Status: **partially-integrated**. Important inspected work only. Whole-tree counters retain all differences/absent paths; squash equality and unknown inherited work are not inferred from ancestry/name.

## Refs

- `local-git-database:refs/heads/fix/m01-local-sanitizers`

## Work and commits

- `f4beb7a7ed33d580bcb8712feac3c7cc58a5bd81` - feat(ci): execute sanitizer components with owned local authority. Changed paths and exact subjects are in [commits.json](../commits.json).
- `6651746ff3457338496c31bf31e169c88c240032` - fix(ci): accept the exact ASAN-only runner role profile. Changed paths and exact subjects are in [commits.json](../commits.json).
- `2c670642e0606d282d11d3cfeafd38c254da3537` - fix(ci): reduce ASAN test process memory retention. Changed paths and exact subjects are in [commits.json](../commits.json).
- `c15a20b9cdba3d43e5c2b168589f7fea8edf86f1` - fix(ci): cap ASAN build concurrency. Changed paths and exact subjects are in [commits.json](../commits.json).

## Important files

| Path | Compared with main | Symbols / exact change locators |
| --- | --- | --- |
| `docs/ISSUE-m01-local-sanitizers.md` | differs-from-main | `Exact resource/document path; @@ -0,0 +1,20 @@` |
| `docs/PR-m01-local-sanitizers.md` | differs-from-main | `Exact resource/document path; @@ -0,0 +1,81 @@` |
| `Tools/CI/prepare_native_runner.py` | differs-from-main | `Exact resource/document path; @@ -209,2 +209,3 @@ RECOVERABLE_ROLES = {"native_checks", "prepare_thread", "prepare_address", "nati; @@ -292,3 +293,4 @@ def reviewed_recoverable_policy(path, checksum, base):` |
| `Tools/CI/recoverable_shards.py` | differs-from-main | `Store, ObservedTestProgress, NativeAuthority, LocalAuthority, NativeBuilder, NativeMonitor; @@ -79,2 +79,4 @@ def require_fields(value, names):; @@ -413,2 +415,8 @@ def evidence_outputs(attempt, runtime, methods):` |
| `Tools/CI/test_native_runner.py` | differs-from-main | `NativeAuthorizationTests, RecoverableAuthorizationTests, UnprintableValueError, Remote, Workflow, Listener; @@ -587,2 +587,68 @@ class RecoverableAuthorizationTests(unittest.TestCase):` |
| `Tools/CI/test_recoverable_shards.py` | differs-from-main | `FakeExecutor, Fixture, PlanningTests, Builder, CheckpointTests, AdmissionTests; @@ -2836,2 +2836,446 @@ class AsanTestMemoryTests(Fixture):; @@ -2598,2 +2598,240 @@ class GranularityTests(Fixture):` |
| `docs/ISSUE-m01-asan-test-memory.md` | byte-identical | `Exact resource/document path; @@ -20 +20,5 @@ Focused Python fakes must cover exact inventory membership, indivisible groups,; @@ -0,0 +1,20 @@` |
| `docs/ISSUE-recoverable-parallel-quality.md` | byte-identical | `and; @@ -91 +91,7 @@ Reviewed d12 attempt3/native-checks job122240942376 correctly refused before any` |
| `docs/PR-m01-asan-test-memory.md` | byte-identical | `Exact resource/document path; @@ -27 +27,7 @@ The focused Python run passes 21 tests: 13 new ASAN memory cases, six existing p; @@ -0,0 +1,27 @@` |
| `docs/PR-recoverable-parallel-quality.md` | byte-identical | `in, and; @@ -225 +225,17 @@ Six focused new fake-only methods pass. They reproduce an actual early RAM refus` |

Whole-tree evidence: reused previous exact-tip/exact-baseline blob comparison; no repeated comparison. 3367 byte-identical paths; 17 absent paths; 657 differing paths. Important-file equality alone does not prove all inherited changes redundant.

## Dependencies and limits

- Use current GameRuntime actor isolation, actual current world/hull/equipment authorities and exact pack trust digest; old branch code is reference until reconciled.
- Consult the exact commit/path diff; do not merge all carried history.
- Pre-release: do not reintroduce old-content fallback or historical save/ownership maintenance.

Missing/divergent work is itemized in [branches.json](../branches.json). No compiler, native game, tests, CI, renderer or repository helper executed. Existing documents/commit claims are not independently verified test passes.

Existing source or document statements to check; these are not audit test results:

- `docs/PR-m01-local-sanitizers.md:28`: `The authority verifies immutable ancestry, all source pins, exact source location, physical Apple Silicon UUID, non-VM hardware, compiler/SDK/developer identity, clean committed head, disjoint owned storage and static ca`
- `docs/PR-m01-local-sanitizers.md:75`: `The existing full aggregate still requires both modes, matching full inventory, coverage and zero leaks. 'release_macos.publish' still requires exact-main required quality success/main analysis before tag or publication`
- `docs/PR-m01-local-sanitizers.md:79`: `Twenty-six focused fake tests pass: 16 new local cases, six existing planning cases and four affected GitHub authority/preparation/profile cases. They cover both modes, strict ownership and preprobe refusal, independentl`
- `Tools/CI/recoverable_shards.py:693`: `"""Live output observations only; XML and sealed receipts remain the pass authority."""`

Use [the work-item index](../WORK-ITEM-INDEX.md) before taking a work packet. Keep delivery status in the main completion ledger.
