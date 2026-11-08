# Issue: Bison test compilation fails before discovery

## Actual failure

Main 311 build session 58201 stopped after 880.010 seconds. Core compiled and the game linked, but the test module reported nested Testing requirements, a mutating attack-origin call inside a requirement, and a missing explicit people argument in the selected SH029 load fixture. The compiler guard log is empty; no tests or discovery completed.

## Scope and acceptance

Correct the complete affected test expression/API caller class. Keep all test predicates, cases, parameters, frame counts and original data. The selected KitLoad file contains four methods in the original 198 selection, so its shared-helper change needs an explicit before/after dataflow proof. No production fallback or empty-person default is justified by a file hash. See [the implementation handoff](PR-58201-bison-test-compiler-family.md).
