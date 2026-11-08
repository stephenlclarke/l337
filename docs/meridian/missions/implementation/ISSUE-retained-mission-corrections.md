# Retained mission corrections

## Motivation

Four previously authored mission corrections are absent from main `f1568bf6bd0464c8769cd22b4a87dea891772808`. Reconcile them together without importing historical Game files, changing ship qualification or duplicating the orchestrator's work ledger.

## Intended gameplay

- C23, Assembly of Orbits: a commander carrying the original reference can open the Assembly Planning Console from Missions. Port and starboard player proposals remain independently editable, including conflicting proposals. Save and Clear require explicit confirmation and a writable bound commander save. Back discards unsaved edits. A failed writer preserves the previous durable state and permits retry. Saved plans are player notes; they grant no surveyed register, crew, consent, corridor, physical work, mission progress or reward.
- F13, Original Survey: after changing ships, the commander can cancel the active survey at the actual Avenor office without payment. Successful reception still requires the original carrier and all three real readings. Old quotes stay stale after a hull exchange. If an exact registered unread marker is actually destroyed, the HUD and board direct the commander to cancellation. Missing or unloaded bodies do not prove destruction; completed readings remain valid.
- G05, Orbital Outlook: destruction of an exact registered unread viewing marker directs the commander to return both original passengers to Avenor care and review cancellation. People, cabins and existing views remain in custody until the real receiving operation. A missing body or destruction of an already completed view does not erase progress or justify abandoning passengers.
- Plans courier: delivery awards the Naval Energy Unit and exactly 256 combat points once. The paid Extra Energy Unit is preserved with its identity, component, purchase history and provenance. Better current equipment remains fitted; displaced or unfitted equipment stays owned in storage. The reward does not first delete the standard unit.

## Scope

Use the reviewed C23 draft-persistence dependency and planning editor together. Include the F13 row's reviewed marker-loss child and its corrected installed-library cold-load test. Preserve current Tithe, Bison, contacts, equipment values and C03 ownership. Keep the current Game storage accessor pattern.

## Acceptance criteria

The retained tests must exercise real writer refusal, retry and cold load; stale painted input; real hull exchange; registered marker destruction; original passenger care; and paid equipment ownership across the reward. Do not substitute a granted ship, invented crew, synthetic acquisition or helper receipt for the existing prerequisites.

## Remaining limits

This source increment has not been compiled or executed. Earned acquisition, native hull/marker qualification, physical passengers and care, mission flight, rendering and actual completion remain subject to G1's execution and the real providers. The retained F13 hull-exchange test must keep its earned Okapi acquisition prerequisite. No source-only result is mission acceptance.

## Coordination

Assignments and acceptance remain in the main completion ledger. The companion [change description](PR-retained-mission-corrections.md) records the reconciliation and validation scope.
