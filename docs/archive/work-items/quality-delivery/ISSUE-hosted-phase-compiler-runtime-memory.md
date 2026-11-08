# Hosted full-CI compiler and runtime memory phases

## Problem and motivation

The corrected external ship-reference guard is not the maintained hosted full-CI caller. The real path is capture-quality, make ci, quality_phase_checkpoints.run_hosted_phase, NativeAuthority.admission and NativeMonitor. The phase monitor applies the installed phase allocation as one fixed RSS limit. Raising that fixed limit to 6 GiB would also raise the test and game limit, which is not authorized.

## Acceptance criteria

- Use the same reviewed closed compiler classifier in the actual hosted phase monitor. Compiler phases may use 6 GiB; runtime, test, game, unknown and overlapping samples retain 3 GiB. Existing stricter configured allocations remain stricter.
- Admit the maximum phase before launch. The existing nominal 3 GiB phase allocation requires a 6 GiB compiler peak plus its unchanged 2 GiB reserve. Keep CPU, disk, flags, timeout, exact installed authorization and process cleanup rules.
- Count all owned descendants, the bound observer and its direct children from the same resident snapshot. Keep the shared noncompiler ancestor ceiling and exact compiler tool checks. Use untruncated command text without another process sample.
- Preserve separate compiler/runtime sample counts and high-water figures in the existing receipt. Reject a fixed 6 GiB runtime receipt and retain helper/image lifecycle validation.
- Do not modify the installed policy, current 200-method run, frozen operator, input tree or Swift source.

## Compatibility and remaining risks

This source-only correction follows committed candidate d1d23b2b. It changes admission semantics and phase receipts, so prior fixed-budget phase proof cannot qualify the changed source. G1 owns fake execution, final installed activation and actual hosted CI verification. Source checks do not establish native or mission acceptance. Actual START 22962 remains a separate unchanged owning qualification.

## Whole-artifact review corrections

Every approved phase profile now includes the bound observer and its direct children from the same verified resident snapshot, including stricter fixed allocations below 3 GiB. Sanitizer/no-phase scope remains unchanged. New strict-profile fake cases cover exact aggregate equality, one byte over, the observer/sampler-only excess, missing observer identity/RSS and the unchanged strict peak plus reserve admission boundary.

The existing receipt now records the final sample kind explicitly. Validation requires nonnegative integer final RSS within the overall and selected-kind high-water marks and limit, an observed sample for that kind, and an exact kind/budget match. New mutations cover a claimed compiler final sample with no compiler samples, a runtime sample claiming a compiler budget, final RSS above either high-water mark or runtime limit, and invalid RSS types. Original helper/image/lifecycle requirements remain intact.
