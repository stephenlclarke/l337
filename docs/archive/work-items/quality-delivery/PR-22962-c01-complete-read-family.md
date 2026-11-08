# fix(c01): bound complete timing and lane validation reads

## Motivation

Actual qualification 22962 passed build and discovery, then the test helper faulted in the actor read reached from complete timing/history validation during an armed lane work frame. The complete nested read family must retain all validation while reducing full-value materialization and overlapping local lifetimes.

## Implementation

ScriptOwnedActor.valid first checks its alias, then borrows the stored body into a non-inlined complete body validator. Its existing full NPC validator is unchanged. This is the only reserved shared hunk in ScriptEncounters; actor storage, coding, equality, getters, setters and the other C03 seams are unchanged.

NativeC01TimingStandard.original borrows its actor and source. A borrowing body helper retains every identity, mission, hull, hostility, missile, ECM, rotation, profile and model check. Timing shape validation completes capture, use and loss sections separately. Complete timing history and validity execute source/opening, prior history, carrier, actor, capture, use and loss checks in the original order, with non-inlined helpers ending each read stage. Lane history completes source/opening reads before full surveyor, reservation and timing validation. No live authority, schema, save format, source data or ownership policy changes.

## Validation

Two appended regression methods configure 21 cases. Twenty component cases check valid and invalid actor/body/NPC/profile/model/source inputs, unchanged COW originals and actor codec round-trip. The async case uses the maintained controlled earlier history, actual pickup and arming, then fixture.work calls the actual GameRuntime.advance chain. It checks foreign-revision rejection, preserved original timing custody, physical-time advancement and complete post-frame timing/lane validation. This controlled fixture is not an M01 route or delivery acceptance claim.

G3 checked 26 exact source-text section/function comparisons, original test-file prefix preservation, exact committed baseline content, forward/reverse patch replay, whitespace and scoped Markdown lint. No Swift parser, compiler, helper, geometry, game, OS resource sample or native test ran. No stack-size reduction or runtime cure is claimed. G1 must compile and execute the changed source with the existing compiler 6 GiB, test/game 3 GiB, 2 GiB reserve, CPU 1, flags, disk allocation and timeout.

## Compatibility and coordination

The complete patch contains four production files, two append-only test files and this issue/PR pair. The exact ScriptOwnedActor.valid borrowing-helper hunk is separately identified for G1's C03 composition; do not apply it again after the complete patch. MC1's ordinary SH029 fixture and G1's other shared seams are outside this packet. All original 200 method bodies, annotations, arguments and assertions remain unchanged. The hosted memory packet is independent and intact. The matched crash, source binding, terminal, logs and image identity remain retained as failed evidence.

## Linked issue

See ISSUE-22962-c01-complete-read-family.md in this directory.
