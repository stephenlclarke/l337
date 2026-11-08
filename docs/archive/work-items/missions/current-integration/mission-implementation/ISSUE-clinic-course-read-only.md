# Prepare NPC flight decisions without installing future effects

## Concrete scope

G1 split c01ClinicCourse from the old c01ClinicGuidance owner. The former calculates a course without installing a control proof or status. The latter still computes the actual attained-time proof, replaces that actor's control and updates reason. The remaining NPC loop still mixes desired-velocity/intent calculations with status and arrival/lost events. Pure outer preparation needs the same exact decision without any of those effects.

Extract a per-body ScriptNPCFlightDecision containing proposed orientation, the existing OuterNPCTranslation, proposed intent/status and an optional closed arrival/lost descriptor. A nonmutating prepareScriptNPCFlightDecision uses c01ClinicCourse and the existing read-only Ark, rescue and transit queries. It applies the existing clinic control-capacity selection without removing controls. Its shared decision math is also called by the original actual loop after that loop's original guidance installation. No course result or pending notice is a source, native proof, accepted actor or authority to emit an event.

## Preserve actual owner behavior

The existing loop retains its actual snapshot/owned-target map, transit-spool observer, eligibility/inertia exclusions, recharge, original mutating clinic guidance and Ark/rescue fallback order. It applies the proposed orientation, emits the pending arrival/lost event once, then writes intent/velocity/position. Its original clinic/Ark/transit resolvers still follow the loop. The now-unused steerScriptNPC forwarding wrapper is removed; the exact turn math remains in the already maintained OuterNPCTranslation helper. No saved state, source role, actor, equipment, proof constructor or compatibility path is introduced.

Read-only preparation must not update reason, controls, an attained sample, persistent commander/world, clocks, native effects or files. The actual guidance path must still install a control bound to the actual actor, runtime epoch and attained interval. Wrong actor/epoch/start/duration must fail consumption of that genuine control. These are control-proof checks, not fabricated receiving or motion acceptance.

## Source-backed tests

Use the existing C01ClinicPeopleJourneyFixture and its actual clinic source preparation. The parked variant retains the stored pilot. The operating variant uses the real launch review and confirmation to obtain consent/assignment. A real runtime advance provides the attained sample; no test writes one. Compare the actual read-only course and full decision against the original actual guidance, require unchanged commander/world/body/clock/effect and clinic transient facts, preserve unrelated controls and exercise wrong-source/invalid-delta refusals. Negative epoch/time checks consume the genuine original guidance proof; the course itself has no epoch parameter and should not be misrepresented as an arrival gate.

Append decision tests to the existing ScriptNPCTests file so its actual private fixture and declared intents are reused. Hold and lost-target decisions must propose notices without publishing them; the original owner then emits once and retains exactly the proposed orientation, translation and status. Follow decisions use the same frozen owned snapshot across array order. Existing tests and their source fixtures stay unchanged. These generic fixture checks do not grant original hull roles or prove Newt integration.

## Ownership and validation

All work is in isolated TMP. FIRST and the scope-extension DECISION-FIRST pin actual maintained preimages and the new clinic API before edits. G1 retains actor/trajectory/frame/birth/native-clock/proof integration and sole native execution. Root owns the sole ledger and review routing. Only source/literal/hash checks, forward/inverse Git text replay and scoped Markdown lint/whitespace run here. Compiler, native and geometry are UNRUN. No independent review gate, GitHub issue number or PR number is created.
