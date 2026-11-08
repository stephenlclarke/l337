# Reconcile Plans courier tests with current main

## Problem and resulting behavior

Main `e8699658e6316fab0ab0e05cd14b22bc121837ed` already contains the Plans courier/save/reward production paths and the newer paid-energy ownership correction. It lacks the existing reviewed courier/cold-save test file. This increment adds that file and its initial-role refusal child together, without changing production source, resources or other tests.

## Retained source

| Source | Commit | Scope |
| --- | --- | --- |
| Courier parent | `8fa6e7771ae385a07e9c3240a4540b8aec1b6303` | Controlled remote approaches followed by actual swept collection/delivery berths, cold carrying and terminal saves, receipts, counters and reward once |
| Initial-role refusal child | `35ee94742332cc632a6cf1bad5e36ed059d775a7` | Current SH124/SH125 role and capacity distinctions, native admission refusal and cold carrying save without physical or legacy ambush bodies |

Both patches apply in order to the stated base. The resulting test file retains the exact reviewed child Git blob `f050c0d2ff7ac60e9e6eb3c756966e1a9c068f08`. Root's existing row records independent G2 source review of the parent and ordered child replay. This reconciliation does not claim a new execution result or reopen unchanged source review.

## Current-source evidence

- [Plans TOML](../../../../Sources/L337Core/Resources/MissionPacks/plans.toml): collection at galaxy index 2/system 83, delivery at index 2/system 36, terminal state and the Naval Energy Unit plus 256-point reward. The current action list preserves previously owned energy equipment.
- [Pack runtime](../../../../Sources/L337Core/PackRuntime.swift): installed-pack digest matching, bound naval progress and stage-scoped encounter lookup.
- [Simulation save](../../../../Sources/L337Core/ScriptSimulationSave.swift), [Game](../../../../Sources/L337Core/Game.swift) and [script persistence](../../../../Sources/L337Core/ScriptPersistence.swift): explicit random state, loop counter and spawn-delay serialization, save capture and restore.
- [Current R3 contracts](../../../../Sources/L337Core/OriginalFleetR3Data.swift): separate warship/drone families, native crew and autonomy, unincluded recommended kits and missile capacities.
- [Pending Larvaal registrations](../../../../Sources/L337Core/OriginalFleetLarvaalPendingSourceRegistrations.swift), [detailed hull stage](../../../../Sources/L337Core/OriginalDetailedHullStage.swift) and [runtime source selection](../../../../Sources/L337Core/OriginalFleetRuntimeHullSource.swift): engineering estimates remain unqualified; both ships are blocked from runtime sources and fail the native-LOD limit.
- [Existing paid-energy reward test](../../../../Tests/L337CoreTests/NavalPlansOwnedRewardJourneyTests.swift): a real purchase, cold carrying save, preservation of the original owned item and its records, reward acquisition/storage and terminal cold replay. This complementary file remains byte-identical to the base.

## Validation

Verify the original parent/child patch hashes, ordered replay and exact reviewed test blob. Check all added-file links, scoped Markdown, whitespace, forward/reverse indexed patch replay and unchanged production/resources/existing tests. Freeze the complete patch and machine-readable source evidence outside the repository for the existing integration row.

The new file contains two test methods. Both remain uncompiled and unrun for this composition. No compiler, native helper, geometry, renderer or game execution is performed. G1 must run the focused tests at the actual integration head; a source match or replay check is not mission acceptance.

## Compatibility and remaining risk

No save version, reward amount, equipment price, actor fit, placement, admission provider or shared Game/root-save behavior changes. Native ambush qualification and a complete flown mission remain open. Do not substitute catalogue capacities, historical ship generation, controlled approach setup or test receipts for those missing physical prerequisites.

## Linked work

See the [problem and acceptance criteria](ISSUE-plans-courier-current-save.md). This is the existing `M01-PLANS-COURIER-SAVE` work item; the documents create no separate ledger or completion claim.
