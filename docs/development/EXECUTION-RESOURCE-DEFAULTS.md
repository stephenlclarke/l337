# Native execution resource defaults

Native build, test, renderer, packaging and CI commands use the operating system and toolchain resource defaults. The project imposes no RSS ceiling, RAM reserve, CPU/job/worker allocation ceiling, execution timeout, disk admission threshold, log quota or crash-artifact quota. It does not replace removed limits with large numeric limits.

Historical numeric admission fields remain readable so their immutable policies and failure evidence can be preserved. They do not gate new execution. Effective normal/leak build profiles are `toolchain-defaults-v1`, with empty admission settings and no forced job count or batch mode. Existing caller timeout arguments are compatibility metadata, not live deadlines. Shard duration estimates and explicitly requested packing targets are planning hints; every audited shared-process cohort and complete suite remains indivisible. There is no default memory-driven method-count ceiling.

The shared native child environment removes project parallelism variables, while retaining runtime sanitizer settings, coverage paths, source identity and unrelated environment values. Authorized worker names and canonical workspace paths still come from the approved policy and session. Removing a worker ceiling does not create workers or authorize unlisted identities. Normal and leak phases retain independent authorization.

## Protection boundaries

Exact source/input/toolchain/environment hashes, command shapes, executable hashes and UUIDs, full inventory reconciliation, real terminal exits, coverage, zero-leak checks, crash attribution and custody remain required. Source/game/save/content/physical/triangle validation and release checks are unchanged. An artifact is reusable only under its exact compatible identity; a historical failure never becomes a passing receipt.

Authorization expiry and explicitly granted finite diagnostic/session launch tickets remain permission controls. Correctness leases continue to serialize shared resources and preserve workspace ownership. Historical numeric reservation files remain evidence of actual workspace/attempt ownership, even though their numeric capacity policy is retired. Live or unresolved same-workspace ownership blocks a new reservation until its original lease and terminal proofs permit reclamation; missing workspace attribution is handled conservatively. Acquiring metadata/index locks waits without a project deadline; conflicting active workspace custody still refuses execution.

After a child has terminated or the operator explicitly cancels it, existing cleanup/drain handshakes remain. Signals require fresh matching PID/start identities. If shutdown cannot be proved, unresolved custody and its leases remain held until exact authorized resolution. These terminal/cancellation handshakes do not impose a deadline on live authorized builds, tests or renderers.

## Integration and activation

1. Integrate the reviewed source packet on the intended branch and retain its exact source delta and actual fake-test results. The packet does not alter the sanitizer shared-process membership file.
2. Run the resource-default, ownership, phase, sanitizer, crash-evidence and renderer fake families against that exact composed source. `native-runner-check` and hosted fake contracts include the resource-default regression suite.
3. Generate the host's normal/leak phase authorization and installed-source fingerprints from the actual committed target. Preserve the reviewed runner/workspace membership, event checks, executor/control leases and optional diagnostic custody directory. Numeric fields from a historical policy are not a new allocation grant or resource gate.
4. Bind executable inputs, helper source hashes, workflow bytes, installed guard bytes, SDK/toolchain, command, environment and actual physical image for that target. Changes to maintained guard source require fresh installed-source and activation fingerprints; old deployed fingerprints cannot authorize changed bytes.
5. The existing authorized native executor performs actual qualification and records START, original logs, image identity and terminal outcomes. Source/fake checks alone do not establish native/game acceptance. Complete `make ci`, committed-main Sonar analysis with the exact projectVersion SHA, required review/checks and release validation separately.

This document records the maintained policy. It does not claim that an installed runner was updated or that native quality, Sonar, gameplay or release checks passed.
