# Share actual legacy effect clauses without repeating movement

## Actual problem

The previous pure decision supplies an opening path. Calling enemyAction or advanceBlackjackNPC after retaining that path would translate the actor again and can fire again. G1 needs the original effect clauses separately, under its existing actual opening/retained endpoint and once-only owner. New effect code must preserve current source guards, Blackjack's pre-movement range, ordinary post-movement range and every native weapon allocation/effect.

## Surgical extraction

Replace only enemyAction's final ordinary beam clause with applyLegacyNPCFlightEffects. Keep its original pre-movement EMP/pod, Blackjack dispatch and ordinary current-player/allocated-actor/intent guards and all movement/velocity statements unchanged. The shared entry repeats the original source gates at the actual effect boundary and the original outer callers' live-actor selection. Its ordinary branch contains the exact original post-movement range, native-or-fallback damage and multiplier2 call. It does not move a body or run tactics/randomness.

Move only the Blackjack recharge statement and cooldown/fire block into file-private helpers in BlackjackEncounter.swift. Its original advanceBlackjackNPC calls recharge before its unchanged distance/movement and cooldown/fire after, using the same actual pre-movement distance. Direct old controller behavior is preserved. The native shared entry uses those same helpers after its actual live/source gate and requires the Blackjack opening distance before any resource mutation. Missing opening geometry is not guessed from the retained endpoint.

The new entry returns whether the eligible phase ran. This is not a discharge, hit, source approval or receipt; the existing native beam bridge retains those facts. No source token, new authority factory, queue, timer, RNG, naval policy or compatibility path is introduced. The file-private raw clauses cannot become a separate public native authorization API.

## Tests and composition

The test base is the immutable previous pure packet plus its G2 fraction correction. Current maintained tests were still older when FIRST was captured. Compose frozen2b50, f1882afc test correction, then this delta. Do not replace either pending test set with an older complete file. Every previous assertion, setup and fractional sample correction remains; only a current-controller comment and added effect assertions/cases change.

Extend existing genuine stale-intent/nonplayer-retarget refusal inputs to reject the effect entry without changing state. Split-mode tests retain only actual controller kinematic output in a detached unit scene, then compare actual shared effects against the complete controller's commander, world, bodies, resource and allocation outcome. No positive receipt, stock or complete future Game is copied. Crossing1500 preserves the two distinct range rules; missing Blackjack opening distance refuses before recharge; positive cooldown recharges/cools without fire or movement; an already killed actor cannot be recharged by the attained native entry.

These remain declared existing legacy unit scenes, not original hull/source-role qualification. Root/G1 retain the real physics, birth and actor adoption obligations.

## Ownership and validation

Five TMP payload paths: surgical Game enemyAction hunk, Blackjack helper extraction, composed LegacyNPCIntentTests delta and paired notes. Use the Game patch hunk only; its full TMP afterimage is for replay and must not overwrite G1's evolving tick file. Native bridge, naval/tactics, frame loop and pure predecessor artifacts remain unchanged.

FIRST pins actual current Game/Blackjack and the explicit composed test base before mutation. Source checks must reconstruct both original controllers and compare moved effect clauses literally, replay/invert the exact delta and lint the scoped notes. Compiler/parser/native/geometry are UNRUN. G1 alone adopts/executes; Root owns ledger and same whole review. No extra review gate or issue/PR number is created.
