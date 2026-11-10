# Contracts availability stack crash

## Problem

The actual W01/W03 run on `a8ef6f27` built and discovered the four ordinary receiver tests, then crashed while the wrong-actor test opened Contracts. No method completed. The matched test image reserved `0x9a90` bytes plus saved registers in `Game.scriptUnavailable` before its first availability branch. The faulting zero store targets that frame in the stack guard region.

## Required behavior

Ordinary Contracts must evaluate the same installed-content, native consent, capability, durability and dependency rules in the same order. Availability reads must not reserve owned pack copies for unrelated mission branches. Keep the authentic physical receiver, payment and current save rules.

## Validation

Retain the four exact ordinary W01/W03 selectors. Extend the wrong-actor journey to reopen an allowed pickup preview and compare its offer, commander and save files before acceptance. Preserve all later physical actor rejection, once-only payment and writer rollback assertions. Independent source/preparation review and one fresh Root native assignment are required before executing the changed candidate. The failed run is preserved separately.

## Limits

Source checks do not prove compilation, a smaller linked frame or a passing player journey. Full CI, coverage, leak gates, protected PR merge, main-only Sonar and release acceptance remain open.
