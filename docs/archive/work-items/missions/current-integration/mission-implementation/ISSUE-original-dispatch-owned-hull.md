# Original dispatch needs real fitting prerequisites and retained cargo accounting

## Problem

The original secondary-source consumers need a ship that actually fits their native station apertures. They now earn and pay for SH029 through the existing complete acquisition producer, retain its real save writer, confirm captured-person care, sell actual unreserved ordinary goods and travel normally. The main-only constructor remains separate and unchanged.

Actual session 18883 at b11df8e4 compiled and ran, then exposed two remaining prerequisite errors. Eight compound source-arrival failures establish cargoTonnes is nonzero. The right-hand instances.isEmpty expression was not evaluated. Two other cases threw incompatibleFit while adding the optional escape or galactic equipment. The log does not give the numeric cargo total, commodity contents or first failed fitting guard.

## Source-backed causes

CommanderCargoValidation counts every owned EMP item, including inventory-stored items, at EMPModuleGradePolicy.massKilograms, currently 100 kg. It rounds the combined EMP, retained salvage inventory and alien stored mass up to whole tonnes. Care removes the exact captured-person cargo; real market sales remove actual ordinary commodities. Neither operation removes the paid EMP or its carried mass. An empty commodity array therefore does not establish zero total hold use. No ordinary travel pickup or automatic trade is established by this failure.

SH029's authoritative R3 contract has three ordinary utility mounts. The actual acquisition fit uses EMP, salvage cutter and fuel scoops. Adding an escape pod or galactic drive as a fourth fitted utility violates OriginalFleetR3Fitting's unchanged mount-count contract. The normal inventory Store action can keep the exact paid cutter aboard while freeing its mount. Storing the EMP would still retain its counted mass and is not a cargo workaround.

## Required correction

Keep the genuine acquisition, care, exact ordinary market transactions, paid purchases, navigation, fuel, travel, source entry and save writer. Before an optional escape/galactic utility purchase, store only the actual fitted salvage cutter through the current preview and real actor inventory transaction. Preserve its item identity, provenance, component and paid history, all other owned items, fitted EMP and scoops, exact bank/grades, cash, cargo, people, acquisition and authority.

Calculate the retained cargo baseline from the actual owned EMP count and current authoritative mass policy plus the actual retained salvage and alien stored mass. Require the ordinary commodity array to remain empty and the total to equal that baseline before acceptance. Require exactly baseline plus one tonne while the original sealed package is held, and exactly the same baseline after delivery, abandonment, escape or fatal loss. Preserve the original package, payload, source, receiving, payment, clue, replay, current-save and Gallery assertions. The full-hold/stale-review test fills only standardCargoCapacity minus the retained baseline with its declared ordinary test goods, then frees exactly one tonne.

Separate the constructor's total and empty-instance checks. Include bounded factual cargo context in its existing failure: commodity array, actual total, calculated retained mass, baseline, sealed tonnes, EMP count and case count. Do not clear cargo or script state, remove the EMP, loosen a fit allowance, add ticks or create a probe run.

## Scope and validation

The b11 correction changes four existing original-dispatch test files and these two issue/PR notes. Gallery changes are limited to the original-dispatch cargo baseline, package and settlement assertions; other UI/cold work remains separately owned. Production source, resources, acquisition producer, G1's genuine resume consumer, shared EMP fixtures, motion/geometry and the live ledger remain untouched. Root owns the single completion ledger.

Source-only checks bind the exact b11 preimages/dependencies and session evidence, replay the complete delta forward and backward, preserve test names/arguments and all unaffected authority/receiving/durability/UI assertions, and check Markdown/whitespace. Native compilation and tests are UNRUN for this changed packet and remain G1-owned. Independent review and focused PASS are still required. No compatibility reader, migration, role grant or new production/testability API is needed.
