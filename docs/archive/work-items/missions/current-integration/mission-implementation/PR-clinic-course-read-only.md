# Extract read-only NPC flight decisions and verify the actual clinic split

## Change

Add a nonmutating per-body flight proposal using the exact current desired-velocity, intent, steering, follow/flee/braking, transit-goal and arrival/lost conditions. Its immutable result contains orientation, OuterNPCTranslation, proposed intent/status and at most one pending descriptor. It uses the existing read-only clinic course and Ark/rescue/transit queries and never constructs a proof, allocates an actor, recharges energy, observes a spool or emits an event.

The original actual loop keeps its existing effect order and calls the same extracted decision math after original guidance installation. Recharge, clinic proof installation, event emission, actual state writes and all native motion resolvers remain in that owner. The pure clinic selection computes capacity after excluding that actor's existing controls, matching the original mutating guidance's remove-before-capacity rule while changing nothing. An unavailable clinic course/capacity retains the old Ark/rescue fallback. Native source, epoch, birth, frame and retained-endpoint joins stay G1-owned.

## Meaningful tests and limits

- Genuine C01 source fixture, parked and actual consenting operating pilot variants. Production source preparation and a real runtime advance provide the cohort and attained sample. No test constructs positive stock, consent, token, proof or observation.
- Repeated c01ClinicCourse and full decision preparation leave actual commander, world, bodies/celestials, energy/shields, allocator, clock, HUD state, review, attained sample, control fields, pending-death references and reason unchanged. Current saved files remain unchanged.
- Original c01ClinicGuidance returns the same selected course, preserves those scene facts, replaces only its actual actor's control and updates only its reason. Every unrelated control field is preserved. Its genuine control consumes the actual actor/epoch/start/duration and refuses the other actual stock actor, a foreign negative epoch and mismatched start/duration.
- A negative source alias substitution and invalid delta refuse both course/guidance without updating state. The tests do not demand a fictitious course epoch check or infer receiving authority from a geometric proposal.
- Existing NPC fixture supplies actual declared hold/attack/follow intents. Pure arrival/lost proposals publish no event. The old actual loop applies their exact status/endpoint and emits one matching event; repeating the loop does not emit that notice again. Follow proposals are independent of body array order with one frozen owned-target snapshot.

This packet tests the course/decision boundary, not G1's trajectory/proof integration. It does not qualify moving contacts, save formats, native receiving, full C01 completion or Newt gameplay. G1 alone compiles/runs the same composed slice and retains its actual integration tests.

## Validation and handoff

Six TMP-only payload paths: modified ScriptNPCFlight and appended ScriptNPCTests, new ScriptNPCFlightDecision and NativeC01ClinicCourseTests, and these matching issue/PR notes. Actual clinic source files and the already integrated OuterKernelKinematics are pinned dependencies only. Use the exact current delta; no stale author file or shared Game/tick patch is supplied.

Source checks must reconstruct the full original actual loop by replacing only its extracted block and obsolete forwarding wrapper. The extracted conditional math is compared to its original after explicit variable/write-to-proposal substitutions and whitespace normalization. Existing tests retain an identical prefix. Exact source/hash checks, patch forward/inverse replay and scoped Markdown lint/whitespace must pass before handoff. All authored tests remain UNCOMPILED/UNRUN; no native PASS, integrated build or performance result is claimed. Root/G1 reuse the existing whole-slice review/execution route. [Issue](ISSUE-clinic-course-read-only.md).
