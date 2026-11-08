# fix(ci): apply compiler allowance in the hosted phase monitor

## Motivation

The real hosted full-CI phase wrapper bypasses the external renderer guard. Its fixed phase limit either prevents the approved compiler peak or would incorrectly permit tests to use that larger limit.

## Implementation

NativeRunner loads the maintained ship-reference classifier once and derives effective compiler, runtime and admission limits from its constants. Existing allocations below 3 GiB remain stricter. A nominal 3 GiB allocation admits the 6 GiB compiler peak without changing the installed policy or reserves. Recorded phase build admission uses that same effective allocation, and its existing validator compares it consistently.

NativeMonitor applies the shared classifier to each existing resident snapshot. It adds the bound observer and direct children to aggregate accounting without granting them cleanup ownership. It keeps runtime/test/game/unknown/overlap samples at 3 GiB and recognizes only the reviewed exclusive build branch and toolchain descendants. Resident ps uses -ww for full argv. The shared classifier additionally recognizes the exact hosted leak build and exact existing native-monitor sampler command.

The existing memory receipt records compiler/runtime limits, sample counts and separate high-water figures. Validation requires consistent counters, limits, helper samples and image lifecycle, and rejects an undifferentiated 6 GiB receipt. No separate wrapper or approval gate is added.

## Validation

Seven new fake methods exercise actual hosted wrapper construction, real NativeAuthority admission, real NativeMonitor observations, receipt validation and shared command classification. Cases cover exact 6 GiB compiler equality and one byte over with observer/sampler RSS included, the same-monitor transition to 3 GiB runtime equality and one byte over, nested runtime, nested second build, unknown/overlapping siblings, ancestor overflow, numeric 8 GiB admission refusal, receipt forgery and a large reservation that cannot raise runtime to 6 GiB. Existing phase fixtures are updated to record effective admission and separate phase evidence.

G3 performed Python AST parsing, exact committed baseline comparison, forward/reverse patch replay, whitespace checks and scoped Markdown lint only. G1 must run guard, recoverable-shard, quality-phase and native-runner fake suites. No test, compiler, native helper, game, RAM/disk probe or installed policy mutation ran during preparation.

## Compatibility and remaining risks

The complete delta has seven Python source/test paths and this matching issue/PR pair. The current owning 200-method run, source, frozen binding and operator remain untouched. The effective admission and new phase evidence must be included in G1's final activation before actual hosted CI can qualify this source. All original acceptance requirements and previous failures remain intact.

## Linked issue

See ISSUE-hosted-phase-compiler-runtime-memory.md in this directory.

## Whole-artifact review corrections

Every approved phase profile now includes the bound observer and its direct children from the same verified resident snapshot, including stricter fixed allocations below 3 GiB. Sanitizer/no-phase scope remains unchanged. New strict-profile fake cases cover exact aggregate equality, one byte over, the observer/sampler-only excess, missing observer identity/RSS and the unchanged strict peak plus reserve admission boundary.

The existing receipt now records the final sample kind explicitly. Validation requires nonnegative integer final RSS within the overall and selected-kind high-water marks and limit, an observed sample for that kind, and an exact kind/budget match. New mutations cover a claimed compiler final sample with no compiler samples, a runtime sample claiming a compiler budget, final RSS above either high-water mark or runtime limit, and invalid RSS types. Original helper/image/lifecycle requirements remain intact.
