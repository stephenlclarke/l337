# Separate outer kinematics from native flight effects

## Concrete problem

The maintained moveBodies tail calls advanceScriptNPCFlight, advanceScriptNPCWeapons and advanceScriptNPCShots in sequence. advanceScriptNPCFlight also observes transit spool failure, recharges energy, changes intent status, emits arrival/lost events and resolves clinic, Ark and transit motion. Calling that whole routine per Newt cut would repeat state transitions and evaluate steering against different snapshots. Copying its completed Game into an early cut would instead expose future effects.

stepMissionNativeProjectile seals and applies an impact, projects it, or moves/ages/removes the live shot. Its actual proof joins the retained archive to the live shot and sweeps from its current position. advanceOrdnance likewise receives ECM, steers/moves, checks muzzle clearance, resolves contact, applies damage/law/projection, terminates and notifies observers. These wholesale routines cannot serve as pure segment predictors.

## Small source extraction

Extract the existing bounded NPC turn and semi-implicit translation formulas into immutable OuterNPCTranslation. Extract the mission shot's existing lifetime/grace/movement formulas into OuterScriptProjectileTranslation, reused by both its current collision proof producer and its no-hit path. No source join, native proof constructor, hit effect or cleanup rule is moved out of its owner. Birth-window arithmetic is separate pure data: an actual T1 emission has zero preceding-frame delta. The owner must read emission time from the actual archive and integrate that window; this extraction does not grant a source.

The ordnance value type already owns pure move math. Split its current private method into the unchanged native context wrapper and the exact same math with an explicit selected target snapshot and endpoint clock. New prepareOuterTrajectory iterates a copied OrdnanceState through its existing finite guidance/range/lifetime steps, without changing Game, receiving ECM or creating a native contact capability. It requires the opening context and lastUpdatedAt to agree; stale state refuses instead of retrospectively moving it through earlier cuts. Its output is a kinematic proposal, not an accepted endpoint.

## Exact NPC owner blocker

Full NPC preparation is blocked by c01ClinicGuidance in NativeC01ClinicEscortFlight.swift. It calculates geometry and then mutates c01ClinicEscortRuntime.controls and reason. Its proof start time also depends on the actual physical clock and attained sample. The smallest owner change is to separate its read-only course calculation from its existing control-proof installation. Prepare the course once from the selected outer snapshot; install/rejoin the existing proof only at the actual owner boundary with its real epoch, start/duration and attained sample. Do not call the mutating method on a scratch final Game or install the T1 proof at T0. G1 retains this change; this packet does not create a new proof factory or relax its checks.

The existing transit-spool observer, arrival/lost events, recharge, clinic/Ark/transit resolution and native impact/cleanup effects also remain owner integration work. The paired PR document gives exact once-only obligations. The pure extraction is useful independently, but it is not a complete segmented runtime.

## Scope and ownership

Eight TMP-only paths: three existing source files, one new pure helper, one existing test file, one new arithmetic test file and matching issue/PR notes. Shared Game, Newt clock/mover, clinic and native source files remain untouched. The current preimages include actual maintained worktree inputs, not stale author files. No hull roles, actors, ammunition, energy, native source receipts, save namespaces or compatibility paths are introduced.

Swift/compiler/parser/native/geometry execution is UNRUN. Meaningful source-authored tests compare pure ordnance preparation against the existing native kernel and check birth, grace, expiry, cut sampling and unchanged live effects. G1 alone executes and integrates the coherent slice. Root owns the sole work ledger; no extra review or approval gate is introduced. No GitHub issue or PR number is assigned.
