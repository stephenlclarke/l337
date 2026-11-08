# Correct four mutating test calls in the Assembly calibration controls

Each of the four `startCalibration` calls now executes once into a `let` immediately before its existing assertion. The positive results still use throwing `#require`; the negative results still assert their negation. A thrown start error still propagates. No assertion, invocation order, selection, fixture, funding or production controller changes.

Correction FIRST 17fc1dcc freezes the whole before/after test file, exact four literal edits, forward/inverse patches, unchanged production/packet pins and full independent report: `/tmp/elite-g2-7c1665-c23-controls-complete-source-finding.json`, 5911 bytes, SHA256 f50ffbc0bb83adc5ecbcc6bf10199233f462c4f853cb792f6aadd63ab8656be6. Parent controls packet 7c166529 remains immutable. The original fixture and four optics methods stay byte-exact; only the four reviewed sites in the two appended controls methods change.

Raw-byte/hash/literal, whitespace and exact Git forward/inverse replay checks pass. Both new controls methods and the inherited four optics methods remain UNCOMPILED/UNRUN. No Swift parser/compiler, native/model/numeric/helper execution, test run, renderer, markdownlint, coverage or CI ran. G1 owns compiler and test qualification. The controller, trust, currentness, clock and readout subjects reuse their completed source review; only C23-CONTROLS-MACRO-01 needs delta review. This is not integration-ready or playable.

No mission receipt, Darik register, consent, milestone, work, reward or clue is added. Shared runtime/UI reservation preparation was paused for this correction and may resume after handoff. Root retains the sole completion ledger. [Issue](ISSUE-assembly-controls-macro-correction.md).
