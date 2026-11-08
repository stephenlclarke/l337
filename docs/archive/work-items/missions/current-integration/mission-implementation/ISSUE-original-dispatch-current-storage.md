# Preserve both genuine current storage states in dispatch save checks

## Observed failure and cause

The actual77255 run at 8a5d66584a5416360fff2bde16903221e2b48eeb records dispatchSharesCurrentEnvelopeAndThreeSlotsWithExistingWayfarerServices failing at helper line9: prepared.commander.alienStorageState, current and current.snapshot are nil. This is a valid current commander. The shared MAIN service fixture buys its equipment and accepts the actual clinic, repair and dispatch jobs without acquiring a salvage hull. It must not be given a synthetic empty Alien store merely to satisfy a test helper.

The earlier correction correctly preserved earned salvage history for the other two callers, but made its existence mandatory for every caller. AlienStorageVersionedSave.stage already returns nil when the current commander does not use that feature. ScriptSaveStore writes the actual applicable current envelope, and Commander.publishAlienStorage(nil) makes no change. No production correction, historical reader or migration is required.

## Required correction and acceptance

Make the helper retain the actual optional snapshot. For genuine earned history retain the nonempty-world requirement, explicit history-erasure refusal and unchanged commander after refusal. For genuine absence require both runtime state and saved reference to be absent. The actual writer must return a publication exactly when storage exists. After the actual write/read, compare the complete published commander and complete world, exact optional storage snapshot, script state and production clue validity. Require current feature presence to equal its original actual state; absence must remain absent.

Both earned-history callers must independently require actual preexisting storage before calling the helper. The three-service caller must independently require actual absence. Its existing actual offers, inclusive three-slot count and refusal of a fourth job stay intact. After ordinary runtime save/load, require full commander equality, absence, the same three occupied slots and the same fourth-slot refusal.

Scope is the existing OriginalSealedDispatchTests file plus matching issue/PR/FIRST/source records. Preserve all production code, the cleared UI packet, exact private trust proof, altered-content refusal, packet join, Gallery and thermal loss corrections. G1's active checkout remains untouched. The log snapshot is partial, not a terminal suite result; corrected native behavior and coherent CI remain pending G1.
