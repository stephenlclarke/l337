# Full CI compiler and runtime memory phases

## Problem and motivation

The human-approved compiler allowance is 6 GiB, while tests and game execution remain at 3 GiB. The focused operator applies those separate limits, but the outer `/usr/bin/make ci` guard still applies 3 GiB to compilation. The real coverage-build argument order is also outside the old closed command matcher. Mission-pack validation combines build and execution in one command.

## Acceptance criteria

- Recognize the exact maintained coverage, leak and mission-pack pure-build commands with their serial nonbatch flags.
- Allow 6 GiB only for one exclusive recognized build branch. Re-evaluate every sample. Runtime-only, overlapping runtime, parallel build, unknown and malformed commands retain the 3 GiB aggregate guard.
- Count all selected RSS, including the observer and sampler. Keep noncompiler ancestors within 3 GiB even while compiling.
- Admit mixed CI at its maximum 6 GiB phase plus the unchanged 2 GiB reserve. Preserve CPU, disk, timeout, ownership and cleanup rules.
- Preserve exact numeric RAM and disk available, required, reserve and per-worker figures when positive resource bounds refuse admission. Do not take another sample or invent unavailable CPU observations.
- Split mission-pack build from skip-build validation without changing the validation input.

## Scope and compatibility

No Swift, acceptance method, package, game state, active operator or frozen binding changes. Existing failures remain failures. This source change does not qualify any native result. Runtime acceptance requires the integrated source and its own evidence.

## Related work and risks

This follows the compiler-memory allowance already present in main e8699658. The external full-CI launcher must use `execution_admission_peak(command, profile)` for admission; the static mixed-CI execution limit intentionally remains 3 GiB. Missing or ambiguous command observations fail closed at 3 GiB. No new native launch is authorized by this packet.

## Descendant review correction

The first packet incorrectly treated arbitrary nested build descendants as one compilation branch. Only a genuine `swift` dispatcher and its direct, identically normalized `swift-build` child may share that branch. A second actual build, mismatched child, test/game runtime or unknown descendant retains the 3 GiB whole-tree limit. Other compilation descendants must be recognized compiler/linker tools in the same toolchain directory. New fake cases cover descendant runtimes, unknown tools, nested second builds, direct matching dispatch, mismatched dispatch and indirect or third builds. This correction changes no admission or aggregate accounting rule.
