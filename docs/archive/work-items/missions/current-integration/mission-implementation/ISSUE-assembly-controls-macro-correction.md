# Move four mutating Assembly calibration calls outside assertion macros

Independent complete source review found C23-CONTROLS-MACRO-01: the two new controls tests call the mutating, throwing `startCalibration` directly inside two positive `#require` and two negated `#expect` macros. The same receiver pattern failed in a separate actual 5699 compiler run because the macro's receiver is immutable. C23 itself remains uncompiled; this is a source finding grounded in that separate compiler evidence.

Evaluate each call once into a local constant immediately before its existing positive or negated assertion. Preserve throwing behaviour, order, predicates, fixture, budget, all four prior methods and controller bytes. The full report is frozen in the correction FIRST. All other controller/trust/clock/readout subjects were source-closed; review only this corrective delta. [Correction](PR-assembly-controls-macro-correction.md).
