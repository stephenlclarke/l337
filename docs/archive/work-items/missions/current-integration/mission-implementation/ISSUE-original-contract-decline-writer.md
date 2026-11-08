# Require a writer before declining an original contract offer

## Problem

At immutable 0677291cee48773467a9d9d150dc51f33d6d6364, GameRuntime.declineContract calls scriptCommand without checking for an actual publisher. Game.declineContract, in the Game extension of ScriptContractCore.swift lines 600-608, accepts a retained available main-station offer when its station and revision match. NativeOriginalSealedDispatchOrigin.contractBoardStation returns the current main contractStation for a docked main-station snapshot; that value check does not require a writer or live dock token.

An actual original G01 main-board snapshot can therefore remain value-model decline-eligible when reconstructed in an unbound runtime. The actor correctly invalidates live station authority and sets scriptDurabilityAvailable false, but these main-board decline checks do not use those conditions. scriptCommand first applies the action to its live game. commitScriptCommand then sees persistent changed state, gets no publisher or save URL and returns without throwing at ScriptTransactions.swift lines 124-125. The public command returns success with the decline retained only in memory.

## Required behavior

Refuse the public actor decline before mutation when scriptPublisher is absent, with a clear request to choose a writable commander save. Keep the existing value-model decline rules, ordinary scriptCommand publication/rollback and all shared native physics and save behavior unchanged. Do not add a broad generic commit guard or a new API.

Use the existing original sealed-dispatch MAIN constructor to establish its actual native berth, real generated board and bound save. Reconstruct an unbound runtime from that genuine snapshot, demonstrate retained value-model eligibility on a detached control only, and require the public actor refusal to preserve the full actual state and files. On the original bound actor, block its real writer, require rollback, restore the same files and decline the same offer. Only that exact offer status may change. Verify the current saved state, independent cold read and unchanged repeated-decline refusal.

## Scope and acceptance

Scope is one public decline wrapper hunk, one new owning original-contract test and matching issue/PR/source/FIRST records. No source or dock authority, mission acceptance, package, role, consent, funds or reward is manufactured. Reuse the existing main fixture's declared starting setup and real entry; this is not a secondary-source fitting journey or a fresh-start acceptance gate.

The current source-attribution chain, before/after bytes and replayable parent-relative delta are pinned for independent review. Native compilation and execution are UNRUN and remain G1-owned. Root records the work packet in the single live ledger. The previous dispatch cargo/fitting packet stays byte-identical and frozen; no G1/MC1/G3 reserved hunk, production transaction engine, compatibility reader or migration changes.
