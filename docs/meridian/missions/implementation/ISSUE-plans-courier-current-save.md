# Plans courier and cold-save regression

## Motivation

The existing work item `M01-PLANS-COURIER-SAVE` retains a reviewed courier test parent and initial-role refusal child against an older base. Reconcile their complete test file with main `e8699658e6316fab0ab0e05cd14b22bc121837ed` so the integration owner can execute the missing coverage. The current production handoff, persistence and reward paths already exist. This increment needs no production change.

## Intended gameplay

After previously issued orders, an actual main-station berth at Nerith in galaxy 3 collects the plans. Carrying state, the installed pack digest, collection receipt and simulation counters survive a cold load. An actual main-station berth at Veyara delivers the plans, grants the Naval Energy Unit and adds exactly 256 combat points. Cargo and cash remain unchanged by those handoffs. Cold loading and reconsidering the completed berth must not grant the reward again.

Current SH124 Larvaal Warship and SH125 Larvaal Drone profiles are requirements, not installed combat fits. Their recommended role kits are not included. The warship has four native crew and eight missile places; the autonomous drone has no native crew and four missile places. Those capacities do not prove loaded ammunition or an encounter fit. Both sources remain outside the live ambush until qualified. Their current native-source face counts, 1,464 and 5,112, exceed the 512-face admission limit. Cold reopening the carrying save must not create those physical ships or legacy Thargoid/Thargon bodies.

## Acceptance criteria

- Run both methods in `NavalPlansCourierPersistenceUnitTests` against the actual integration head. Retain their controlled prior orders and remote approach setup as explicit limitations; collection and delivery still require real swept station entry.
- Verify collection/carrying/delivery stages, exact digest and receipts, cold-load random state, mission loop counter and spawn delay, unchanged cash/cargo, the single 256-point increase and no repeated reward or notice after a final cold load.
- Verify the exact current role, crew, missile-capacity and unincluded-kit distinctions, nil runtime sources and typed native-LOD refusals. Preserve both physical-ID and legacy-hull absence assertions after cold load.
- Keep the existing `NavalPlansOwnedRewardJourneyTests` and current Plans TOML unchanged. That separate test covers the paid Extra Energy Unit's identity, component, purchase history, provenance and storage when receiving the reward.

## Remaining limits

This increment is source only. It has not been compiled or executed on the stated base. It does not qualify an earned full mission journey, orders eligibility, a flown intersystem route, live ambush deployment, combat equipment, safe encounter placement, tactical carrier launch or native hull admission. The historical GTHG routine's two initial actors do not establish a modern safe placement or fit. No new authority, actor admission or save schema is introduced.

## Coordination

The main completion ledger and Root's existing `M01-PLANS-COURIER-SAVE` row remain the sole work and acceptance records. G1 owns current-main integration and execution. See the [change description](PR-plans-courier-current-save.md) for the exact retained sources and current-source evidence.
