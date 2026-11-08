# fix(ci): apply compiler memory allowance throughout full CI

## Motivation

Full CI needs the approved 6 GiB compiler allowance while preserving the 3 GiB test and game limit. The previous outer guard prevented compiler phases from using that allowance.

## Implementation

Normalize the actual native coverage-build argument order and recognize only the maintained leak and mission-pack pure-build commands. For the exact full-CI entry point, inspect command text in the existing process-memory sample. Select 6 GiB only for a single recognized pure-build branch with its ancestors, observer and exact sampler. Nested Swift dispatcher/build processes are one branch. Unknown or overlapping siblings, parallel builds and completed compiler phases retain 3 GiB. Sum all RSS and independently retain the 3 GiB noncompiler ancestor ceiling.

Expose `execution_admission_peak` so the external full-CI launcher reserves 6 GiB plus its existing 2 GiB reserve before launch. Keep the static mixed-CI execution limit at 3 GiB. Split mission validation into a pure build and a skip-build run. Enrich the existing worker-limit refusal with the existing sanitized numeric schema; do not sample resources again.

## Validation

Authored fake tests cover exact real commands, changed flags, inclusive compiler limit and one byte over, all-RSS accounting, the transition from compiler to runtime in the same guard, unknown and overlapping branches, nested dispatch, orphan and malformed commands, observer overflow, mission build/run separation, maximum-phase admission and exact RAM/disk refusal figures. G3 performed only Python AST parsing, exact baseline comparison, forward and reverse patch replay, whitespace checks and scoped Markdown lint. Fake execution and full `make ci` remain for G1. No compiler, game, resource sample or project test ran while preparing this packet.

## Compatibility and remaining risks

The five maintained source/test paths and this issue/PR note pair are the complete delta. No Swift or original 198-method acceptance inputs change. The active e869/33a run, frozen operator and binding remain untouched. The outer launcher must adopt the admission-peak API when qualifying this source. Real process command observations and full CI still require validation by the sole native executor. No prior success or failure is reclassified.

## Linked issue

See `ISSUE-make-ci-compiler-runtime-memory.md` in this directory.

## Descendant review correction

The first packet incorrectly treated arbitrary nested build descendants as one compilation branch. Only a genuine `swift` dispatcher and its direct, identically normalized `swift-build` child may share that branch. A second actual build, mismatched child, test/game runtime or unknown descendant retains the 3 GiB whole-tree limit. Other compilation descendants must be recognized compiler/linker tools in the same toolchain directory. New fake cases cover descendant runtimes, unknown tools, nested second builds, direct matching dispatch, mismatched dispatch and indirect or third builds. This correction changes no admission or aggregate accounting rule.
