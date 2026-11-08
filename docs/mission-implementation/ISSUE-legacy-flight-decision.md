# Prepare legacy pursuit without running tactics or shooting early

## Actual owner boundary

planWorkScene in FlightWorkScene.swift sets workScenePlanned, runs navalTactics every eighth mission loop, then calls enemyAction for each hostile live nonspawn actor before preparing its obstacle velocity. enemyAction can fire a native beam. navalTactics changes energy, consumes random bytes and ammunition, and can create a missile or Thargon. None of that is a pure Newt trajectory preparation step.

The actual existing movement is small and deterministic. Ordinary enemyAction requires the actual allocated current-visit actor to engage the current player, then uses either the native naval radial speed with factor18 or its original X/Y damping and Z-above300 rule. It records displacement-derived physical velocity and tests beam range after movement. Blackjack takes its existing exception before the ordinary engagement guard, uses its own source speed without factor18, and does not update stored physical velocity. Its native controller recharges energy, moves, updates cooldown, and tests its original pre-movement distance before firing.

## Bounded pure contribution

Add prepareLegacyNPCFlightDecision over the exact captured body, explicit selected camera frame and positive finite delta. Retain the exact EMP, occupied-pod, actual player/actor/intent guards and Blackjack exception. Return only captured driver/body/actor/intention/Blackjack identity, actual opening epoch/time, view start/end and canonical displacement-derived velocity, with sampling of that one linear outer displacement. It does not run tactics, change an intent, recharge, update cooldown, fire, create a source or seal a proof.

The explicit frame is necessary because work planning uses its pre-camera frame while normal manual enemyAction operates after the selected camera transform. G1 can rebase only body geometry into the selected frame and retain the actual Game clock and source facts. Do not make a future Game or move the final whole Game into an early leg. The decision is plain non-Codable data, not permission to move an actor or apply effects.

All original controllers and planWorkScene remain byte-exact inputs and old-kernel test controls. This supplies the pure opening projection for G1's native path; it does not introduce a second ordinary AI policy or replace the normal branch. G1 owns actual actor/cohort/frame/birth/epoch adoption, contacts and once-only effects at attained time.

## Meaningful checks

Extend the existing stale-intent and actual nonplayer-assault refusal cases with read-only proposal refusal; retain every old input/action/assertion. New tests use the existing legacy unit fixture, actual adoption and original unchanged enemyAction as the control. Compare ordinary and Blackjack movement, actual source intent and frame conversion while proving preparation leaves bodies, commander/world, energy/shields, allocators, work-planning flags and future random-byte stream unchanged. Use the existing actual nonplayer assault to exercise Blackjack's real exception. Check its recharge/cooldown remain deferred and its pre-range gate remains distinct from ordinary post-range firing. A scalar fallback test grants no hull/role and preserves the original300 threshold and non-overshooting radial movement.

These declared legacy kernel fixtures do not qualify an original hull, source role or a fresh player journey. No positive role, stock, source or authority is manufactured. Reuse existing genuine EMP/occupied-pod and native beam/ordnance owning checks in the composed slice; no replacement stock or missing-source waiver belongs here.

## Scope and validation

Four TMP payload paths: new LegacyNPCFlightDecision, the existing LegacyNPCIntentTests with scoped added assertions/cases, and matching issue/PR notes. Existing Game, work scene, Blackjack, naval, native clock and renderer source remain unchanged. FIRST pins their actual maintained bytes. Only source/literal/hash checks, Git text replay and Markdown lint/whitespace run here. Compiler/parser/native/geometry are UNRUN. Root owns the sole ledger and review routing; G1 alone integrates and executes. No extra review gate or issue/PR number is created.
