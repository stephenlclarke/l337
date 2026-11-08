# M03: show a readable original docking encounter in the README

## Problem

The current screenshot uses four copies of a simple training mesh. Near-frontal framing makes them look like squares. Native damage admission and a minimum projected beam length prove firing behavior, but they do not make the attack readable. The common accepted player-hit paths currently change shield and energy resources without a short visible hit indicator.

This is unfinished M03 visual acceptance. It is not a substitute for finishing M02 and M03's actual hull, mission, equipment, station and objective connections.

## Required result

Use four different currently activated original metre hulls: Gyrfalcon Assault, Ibex, Kite Interceptor and Redtail Mk III. Admit their real catalogue geometry through the mission engine. Use original capability values and normal bounded gun tracking while presenting legible oblique hull poses. Show actual accepted damage through the same brief cockpit feedback used during ordinary play.

Do not paint fake ships, beams, hits or health changes. Preserve real gun energy, heat, cooldown, aim, arc, collision and ledger checks. Environmental damage and misses must not create incoming-hit feedback.

## Acceptance

At a safe execution boundary, render three actual composition candidates through the maintained app renderer. Inspect full-resolution images and their 680-pixel README presentation before choosing the strongest. The selected image must make the original ships, real station entrance and incoming player hit clear. No beam-length or damage-only test can establish this visual result.

All 171 ships must still appear in the maintained tape, with exactly one and a half turns each. Actual station render, entry and collision geometry must first use the original station replacement; a new catalogue illustration over the old cube is insufficient. The current fourteen-path source proposal does not implement that separate station dependency.

Fresh current saving and loading must work. No pre-App-Store legacy compatibility or migration support is part of this change.

See [implementation and validation](PR-readme-actual-docking-attack.md).
