# Actual 22962 C01 validation read-family stack fault

## Problem and motivation

The owning original-198-plus-two-causal qualification built and discovered successfully, then its native test helper terminated with SIGBUS. The matched PID and test-image UUID place the fault at ScriptOwnedActor.alias.read, called from the complete actor validator beneath timing shape/history validation, lane history, the armed lane endpoint and GameRuntime.advance. This is a new boundary after the earlier Newt correction; build success and empty RSS guard logs do not establish a runtime cure.

## Acceptance criteria

- Preserve every complete actor, NPC, timing shape, source, history, retained actor, equipment, carrier-loss, mission-revision and authority predicate in its original evaluation order.
- Borrow the one stored actor body for full validation rather than repeatedly materializing its public body value inside one guard frame. Keep actor storage, getters, setters, coding, equality and COW behavior.
- Finish bounded timing and lane read stages before entering subsequent history validators. Keep complete validation as the entry point; no cached selected-fact approval, partial validation or new capability.
- Retain the original 200-method source and configured arguments. Append a regression through fixture.work and the actual GameRuntime.advance armed-lane chain, plus actor predicate, original-value and codec checks.
- Keep Swift 6 ownership, the current save and all resource limits. No stack increase, new native workload, installed policy change or MC1 ordinary SH029 fixture edit.

## Evidence and scope

The matched report is swiftpm-testing-helper-2026-11-08-185857.ips, PID 51114, image UUID F1FF5F27-A936-4D25-880B-E463425BC1E9. The actual terminal remains failed. Native stack frame sizes and aggregate stack use remain unknown. The available committed source d1d23b2b has the exact same tree as Root-verified main dbcfbdc13791274de46ce7423fa174cb044b49c8. No fetch or checkout mutation is required for this source packet.

## Remaining risks

This is an uncompiled source correction. Source predicate and patch checks do not prove that the complete executor chain fits its existing stack or that the mission succeeds. G2 reviews the whole packet; G1 alone compiles and runs the owning qualification and preserves every actual outcome.
