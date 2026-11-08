# Prepare and retain native ordnance on the shared clock

## Problem

The existing ordnance owner moves each live projectile to the current physical time, queries the nearest native collision, applies the existing damage and then stores its state. A shared clock cannot run that completed future step first and copy its endpoint or effects into an earlier mechanical leg. Repeated guidance preparation after moving targets would also choose a different path.

The reviewed `prepareOuterTrajectory` already uses the actual private motion kernel on a value copy. It needs an actual opening cohort, samples of the same selected path, a read-only first-hit/capacity query and retention only after the real clock reaches the selected prefix.

## Owned scope

Root reserves `GameplayOrdnance.swift`, `GameplayOrdnanceRuntime.swift` and new focused owning tests for this packet. G1 owns all Game/tick/CurrentNewt integration, compiler/native execution and its separate combat/mission allocation APIs. G3 owns continuous native physical contact and admission. Root alone writes the completion ledger. This isolated packet changes no maintained checkout, Package view, mission data or actor producer.

## Required invariants

- Keep the real missile launcher, ammunition transaction, muzzle distance, actor allocator, attack origin and emission time. T1 births are absent from the T0 cohort and cannot receive earlier time.
- Use the existing private motion function once to prepare the selected guidance path. Preserve `lastUpdatedAt`, finite propulsion range/lifetime, plasma inherited velocity and the seeker's existing one-over-120-second guidance limit. Samples within a leg use that leg's selected direction; they do not steer again.
- Keep the existing muzzle policy, native nearest-hit query and tie order. The actual current ordnance query passes radius zero to `nearestMissionCollision`; this packet preserves that exact authored-polygon/celestial path and introduces no missile mesh, new collision radius or second sphere solver.
- Keep ECM before motion, one unique activation's seeker resistance, the original enemy ECM chance after impact, ECM destruction feedback and retaliation. Pure preparation never consumes a field or draws random numbers. G1 must run the original enemy tactic phase once per outer frame, not once per cut.
- Keep real practice, mission impact and ordinary combat owners. Preparation is neither a damage capability nor a native impact proof. Every retained effect must join actual live geometry and source at the attained clock.
- Keep mission event-pressure refusal and the original retry rollback. A late refusal is reported as `motionRetained == false`; a replayable allocation certificate alone does not mean that motion was retained.

## Acceptance

The focused owning tests must pass through G1: full-step parity against the existing real advance path; three prefixes on one trajectory; real T1 launch without preceding motion; actual native first-hit selection and original impact/damage parity; changed geometry/epoch refusal; actual ECM activation; genuine mission hull destruction and original allocation replay; full-queue T0 refusal without clock changes; late-pressure rollback; lost-target cleanup only on retention; finite expiry at the original boundary. Existing ordnance tests remain unchanged, including all three profiles, turn bounds, muzzle return, ECM resistance, camera motion, damage and termination cases.

The actual operator must also contain partial kernel mutations. New owning cases cover both ordinary and mission late allocator/ledger refusals, exact unchanged commander/bodies/world/player resources/message after rejection, real NPC missile player survival and fatal hits, and interception between two actually launched missiles. Generic body-hit certificate parity alone does not cover these routes. G1's same-transition clock candidate must publish neither advanced time nor any effect when the operator reports rejected motion.

G2 reviews this whole source composition together with G1's real allocation/capacity APIs and the actual native clock/contact integration. Compiler, focused native tests and the required project checks remain pending. Source hashes, literal checks and authored tests do not establish playable completion.

## Review correction: explicit owner outcome

The initial 4ddaa905 packet inferred retained motion from termination or a cursor within 1e-8 of the requested clock. The actual kernel catches retryable failure and restores its opening motion state. A genuine positive prefix greater than the kernel's 1e-10 threshold but shorter than 1e-8 could therefore appear accepted after rollback. Empty allocation replay at the already attained endpoint did not prove motion.

The actual private advance owner now reports `unchanged`, `advanced`, `terminal` or `refused`. Its catch sets `refused` after restoration. The retainer accepts only the actual advanced/terminal outcomes, valid state/flight and genuine allocation replay; time proximity supplies no acceptance authority. The public original update API and physical/effect policy remain unchanged.

The same full-queue and late allocator/ledger refusal tests retain their original assertions and also run a tiny positive suffix. That suffix is derived from the actual first-hit time after its earlier prefix was genuinely retained through the same owner. It uses no assigned clock, synthetic actor or artificial frontier. The mission destruction test also compares original same-prefix pending event sequences/values, exact once-only damaged/destroyed events and law/consequence state. All successor tests remain unrun pending G1.
