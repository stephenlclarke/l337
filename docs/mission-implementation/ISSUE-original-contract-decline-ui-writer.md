# Prevent ordinary contract-board input from bypassing decline durability

## Existing gap

The public GameRuntime.declineContract guard is integrated at 17ab7e8b. It protects that explicit actor method, but ordinary contract-board keyboard and click input take a different path. ContractBoard.confirmContractDetailAction invokes the value-model Game.declineContract directly at lines 1101-1103. Both current-page keyboard and mouse callbacks can reach it. The actor then calls the unchanged command commit, whose nil-publisher branch can return after the value mutation.

A genuine reviewed original main-board offer can be copied into an actually unbound runtime. Construction correctly removes native authority and sets scriptDurabilityAvailable false, while retaining the current reviewed row. Main-board value decline still uses retained station/revision facts. The UI branch does not currently check writer availability. The public actor guard therefore does not establish complete decline behavior.

## Required correction

Check the existing scriptDurabilityAvailable flag in the ordinary UI decline confirmation branch before invoking the value mutation. Use the same writable-save refusal as the public actor action. Preserve ordinary acceptance, all earlier typed native/finance/provider branches, the value-model Game.declineContract rules, public actor guard and generic publisher/commit/physical behavior. No writer, source authority or positive actor is created by a flag assignment.

Use the existing real original MAIN fixture and generated offer. Open and select its actual review through ordinary input. Cover both current-page keyboard and actual Decline-button coordinates. Reconstruct the reviewed snapshot through the real unbound actor constructor, then require the writable-save refusal, unchanged full commander and files, and the existing review-to-list UI behavior with every saved world field compared against a UI-only reopening control. Preserve actual bound writer failure, same-review rollback, same-offer retry, exact status-only mutation, current save/cold facts and stale-input refusal after cold load.

## Scope and disposition

One ordinary-UI confirmation hunk, one owning parameterized keyboard/click regression and matching issue/PR/source/FIRST records. Do not edit the prior public-actor test, any M01/EMP/G3 consumer, Game, ScriptTransactions, ScriptContractCore, Package, resources or the live ledger. Root owns the single work ledger and final merge-tree disposition; G1 alone integrates and runs native tests.

This is a concrete bypass in the same decline behavior and must remain visible to G1/G2. The actor-only result must not be reported as complete UI coverage. Preserve M01 integration precedence; this packet introduces no new approval process, startup gate or unrelated work. Source review and authored tests remain separate from actual compilation, native PASS, final-head CI/review and release acceptance.
