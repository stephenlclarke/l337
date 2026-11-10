# C02 · A Choir Beneath the Static

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#a-choir-beneath-the-static) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against source at `19a177e66093716928947f7246e0b664e4a6ad07`. Only the commissioning path is in current source. Genuine positive commissioning and all eight field and terminal stages remain open.

This is the C02 opening contract for **A Choir Beneath the Static**. The original story and nine objectives come from `docs/meridian/missions/definitions/quiet-choir.json` at authored commit `c70110b292077588a0855fb48127adfb1b611c9d` (SHA256 `41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60`). That immutable definition is included verbatim in the implementation artifact; this checkout does not recreate the superseded complete oracle tree.

## Player-facing contract

Speak to Captain Tamsin Holt at the living Omdogan main orbital berth in Galaxy 4 (`galaxy: 3, system: 40`). The offer requires four genuinely visited distinct systems and a real Larvaal vessel identification obtained through native Identification targeting. Returning to one system repeatedly cannot meet the four-system requirement. Viewing a ship in the showroom, seeing a model or receiving an unqualified script encounter cannot identify a Larvaal vessel.

The campaign is independent of The Glass Meridian and every other paid campaign. Purchase order is unrestricted. The commercial campaign's suggested chapter order is guidance unless a chapter has a specific authored internal dependency. A purchase never grants identification, a completed chapter, equipment, money, permission or a clue. Product entitlement enforcement belongs to the separate catalogue workstream; this opening implementation adds no purchase or test-entitlement shortcut.

Acceptance requires no trade, kill count, rank, currently fitted scanner or free cargo tonne. The historical identification remains valid after a refit or later ship change. The briefing shows the later requirements before confirmation. Identification targeting will be needed again for field observations. The original phase collector and repair culture each occupy one tonne at their separate transfer stages; neither is issued or reserved on acceptance.

The board opens the review on Back. Escape or Back changes no commander property or save file. Confirmation rechecks the real berth, retained observations, identification, carrier, inventory revision, commander resources, runtime epoch and exact original pack. A stale or blocked review cannot accept the case. The existing runtime's durable script-command transaction publishes the complete candidate; a writer failure must publish none of it.

Acceptance creates one commander-owned mission instance, the original `l337.quiet-choir/accept` receipt, milestone zero and the two original briefing lines. It changes no equipment, credits, cargo, people, station state, flight history or clue journal. It creates no reference emitter, collector, repair culture, probe, signal reading, consent or receiving permission.

## Original progression

| Stage | Location in Galaxy 4 | Required play |
| --- | --- | --- |
| Accept | Omdogan | Review and confirm Holt's signal investigation after genuine history prerequisites. |
| Calibrate | Lobagom | Measure three separate reference emitters and separate receiver drift from interference. |
| Recover collector | Lodogom | Physically recover the original one-tonne sealed phase collector from a dead relay. No ship disablement is required. |
| Interpret | Balmabol | Transfer the original collector to Agent Mara Vale for analysis and receive the separate one-tonne repair culture. |
| Repair probe | Balgodan | Deliver that culture to the actual stranded Larvaal Probe through the original receiving transaction. |
| Listen | Dalonom | Measure three distinct safe positions around the gathering. |
| Expose imitation | Fobolan | Silence the real counterfeit transmitter by presenting its forged certificate or disabling its exposed unmanned component. Unrelated destruction is not evidence. |
| Rendezvous | Omdogan | Transmit the corrected reply and choose the civilian greeting or supervised listening relay. Both legitimate choices reconverge. |
| Close case | Omdogan | Confirm the completed accord, commit the once-only 6,400 CR fee and silent-voice clue together. Optional compatible resonance-filter fitting can wait without delaying the clue or paying again. |

The gallery presents these nine original objectives. Before acceptance none is completed. After this opening only Accept is completed. All eight later objectives remain visibly unavailable until their real native actors, observations, custody, consent, receiving, branch and settlement implementations exist. There is no generic finish, trial, retry or journal command that can bypass them. The core main-story clue recovery policy remains separate; it never substitutes for paid chapter completion or a product prize.

## Current saved representation

The optional `savedQuietChoir` instance leaf contains acceptance facts and their deterministic acceptance-operation identity. Acceptance records the mission/commander, historical carrier and inventory revision, real dock receipt, four native station observations, the exact retained Larvaal identification, event sequence, physical time and calendar time. These values describe history; decoding them cannot create authority.

Current claim validation checks the original definition/version/digest, single active instance, exact acceptance receipt and milestone, exact briefing, acknowledged real event, historical dock, world/owner and visit/time bounds. The identification must still equal the actual global discovery entry for that original Larvaal source, and its current source must remain admitted and discoverable. Later revisits may replace a station's latest observation without rewriting the saved acceptance. Later refits or legitimate hull changes must not require the old carrier to remain active.

Before typed decoding, the existing bounded duplicate-key lexer selects C02 presence. The mission reader rejects orphaned metadata, missing/null/unknown fields, oversized or malformed leaves, duplicate keys, aliases, hidden claims and placement in commander/contracts/pointer data. The leaf is allowed only in the current missions instance archive. There are no legacy readers, migrations, fallback aliases or alternate acceptance forms. Current-format missing content can retain a real commission as unavailable; it cannot invent later progress.

## Implementation and validation status

The owned implementation supplies commissioning, strict current save/load joins, contract board and gallery code. The durable source artifact contains exact minimal shared hooks against maintained commit `32dd637a08c469ba298041fe2cc0d9864f5cc7a1`. It leaves maintained files unchanged here. G1 applies those hooks after checking current ownership and preimages; in particular it preserves C01 publication and C23 calibration changes.

Seven new test methods cover exact opening content, four actual native observations with missing identification, repeated-system refusal, an uncommissioned current cold read/load, generic command refusal, malformed current archives and the gallery. Six existing C02 history/objective tests accompany them. All are **UNCOMPILED / UNRUN in this authoring session**. Controlled remote test scenes use real observation and swept-berth producers but do not establish a fuel-paid flown route.

The indispensable positive input is still missing: a genuine admitted Larvaal actor and its native identification. At the pinned maintained base, SH124/SH125 have original Larvaal metadata but remain behind detailed-hull runtime admission; SH162 remains an unavailable, nondiscoverable probe. The native fleet observer also refuses script NPCs. G1 owns actual fleet admission and observation; G4 owns the source qualification. No historical alias, constructed saved proof, generic authority factory or weakened source gate can replace this input.

The positive tests below remain mandatory and are **BLOCKED / NOT IMPLEMENTED AS EXECUTABLE FIXTURES** until that real input exists. The source packet is not integration-ready, a passing test result or evidence of a playable campaign.

## Required positive acceptance evidence

1. Use an actual newborn commander, real Identification fitting and admitted Larvaal producer. Select the physical craft through native targeting and record its genuine identification. Retain the exact actor/player/visit/time/source proof; do not append a saved entry directly.
2. Obtain four distinct native system observations and an actual Omdogan swept arrival. No trade or C01 completion is needed. Refitting away the scanner must not erase historical eligibility; acceptance must leave all equipment and resources unchanged and create exactly the original prefix.
3. Exercise the board's Back, Confirm and existing atomic writer. Block the real destination writer, prove producer construction succeeded, then prove unchanged commander and on-disk files. Restore the same writer and retry once; duplicate confirmation must not create another instance or receipt.
4. Save the accepted case, perform a genuine cold current read/load and compare its exact saved acceptance. A loaded runtime must invalidate the old transient quote. Revisit a prior system through the actual native producer and retain the historical acceptance. A legitimate refit and hull transfer must preserve it too.
5. Mutate only negative copies of the genuine accepted archive: remove or replace the identification, use another owner, backdate or move its visit, remove one system, add future milestones/receipts/items/cash/clue or hide a leaf. Require strict rejection and no partial writer result. Exercise both direct current archives and the real composition reader.
6. Show exactly one original nine-objective gallery row. Only Accept is complete; all eight physical stages remain unavailable, with no trial digest or generic retry. Remove the content and preserve the genuine commission as unavailable; restoring exact current content must not pay or issue anything.

These are acceptance criteria, not completed tests. The existing main ledger remains the only work-packet authority; this document is an implementation contract, not a second ledger.

## Offer, fit and ordinary route

Holt wants to restore safe mining navigation without ordering an attack based on interference alone. Vale distinguishes the damaged probe's pauses for its missing companions from the imitation that human smugglers use to conceal their traffic. The player's evidence must justify that distinction before the fleet negotiates a greeting or supervised relay.

Reach Galaxy 4 through ordinary travel. A Galactic Hyperdrive is consumed on a genuine galactic transfer. Budget access to that equipment and a reachable launch point for each necessary transfer. Once in Galaxy 4, dock at Omdogan after four distinct native system observations and one genuine Larvaal vessel identification. The qualification checks a native ship with alien origin and Larvaal family, and can use a valid historical identification after refitting. An illustration, script NPC, archive clue or SH162 environment object does not establish this proof. [Galactic transfer](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Game.swift#L6293), [Native identification gate](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeQuietChoirTravelHistory.swift#L49), [Fleet observation refusals](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeFleetDiscovery.swift#L145)

| Objective in Galaxy 4 | From the preceding objective |
| --- | --- |
| Omdogan (G04-S040) | Actual Holt main-orbital commission. |
| Lobagom (G04-S249) | 1.945 LY |
| Lodogom (G04-S078) | 3.382 LY |
| Balmabol (G04-S109) | 2.643 LY. Actual Vale orbital receiving is required. |
| Balgodan (G04-S184) | 6.106 LY. Use the agreed probe receiving path. |
| Dalonom (G04-S127) | 6.837 LY |
| Fobolan (G04-S132) | 7.349 LY direct. For a 7 LY fit, refuel via Lodogom at 2.485 + 5.051 LY. |
| Omdogan (G04-S040) | 4.748 LY. Return for the corrected reply and final actual berth. |

The original world coordinates support these distances. Refuel at an actual accessible orbital and verify fitted reach at departure. The nominal 9 LY SH025 can cover every listed direct leg with fuel. This is route geometry and a planning fit. Physical docking and actor placement still need their own proof. [World catalogue](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/OriginalWorlds/catalogue.json), [Jump and fuel checks](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/FuelStorage.swift#L8), [SH025 authored jump fit](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/Ships/SH025.toml#L194)

The player needs native Identification targeting for the opening identification and a qualified receiving and observation fit for the fieldwork. Reserve one free tonne after installed modules and ordinary cargo. Vale receives the original 1 t collector and issues the separate 1 t culture in one transaction, so they do not require 2 t simultaneously. The probe receives that same culture. The authored stages carry no player passengers. Exact collector tool and capture envelope, calibration geometry, safe listening volumes and the emitter isolation method require mission-specific sources. C01's numeric observation rules do not establish these values.

| Authored craft | Exact design and physical limit |
| --- | --- |
| **Larvaal Warship (SH124)** | Original source and native candidate data exist. The fleet accommodation design calls for four intrinsic and native crew places. A genuine placed ship could furnish a qualifying identification. Its current placement and mechanics remain pending and C02 supplies no roster or authority to admit one. |
| **Larvaal Drone (SH125)** | Original source and native candidate data exist. The fleet specifies zero native crew for autonomous operation and one crew place for a separate player conversion. It remains a possible identification subject after real placement. An armed or hostile drone is not a required target in this campaign. |
| **Larvaal Probe (SH162)** | Exact original 8 × 4 × 12 m mission environment object, player-flyable and purchase flags false. It has no ordinary crew/drive performance model and discovery is disabled. Its dedicated damaged source and culture receiving port, consent or control authority, repair state and actual response must be issued for Balgodan. |

[Warship design](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH124.toml), [Drone design](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH125.toml), [Exact runtime candidate records](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/OriginalFleetLarvaalPendingSourceRegistrations.swift#L114), [Probe configuration](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/Ships/SH162.toml#L3), [Probe reference image](../../assets/ships/SH162.png)

## Evidence, choices and closure

- **Lobagom and Lodogom.** Require distinct actual `reference-low`, `reference-mid` and `reference-high` observations. Their common pause after every third pulse distinguishes the signal from receiver drift. Recover the same original phase collector from the dead relay under its owner's authority. The relay remains intact and no ship needs disabling.
- **Balmabol and Balgodan.** Vale must receive and actually analyse the original collector. Her interpretation opens the repair-culture handoff. The same one-tonne culture must reach the original stranded probe and physically restore the resonator. Its short gold reply is evidence of repair, rather than a reward for targeting the prop.
- **Dalonom and Fobolan.** Measure `choir-near`, `choir-above` and `choir-aft` around the actual gathering without attacking it. Match the imitation's unbroken signal and the copied certificate to the specific Fobolan emitter. Choose **Broadcast the forged certificate and demand shutdown** and verify that the operator shuts down the exact emitter, or **Disable the unmanned transmitter** through a qualified physical action. Both branches need the same evidence of actual silence. An EMP pulse alone, unrelated combat, or a cut into an occupied hull cannot substitute.
- **Omdogan.** Transmit the corrected reply before choosing **Publish the civilian greeting** or **Establish a supervised listening relay**. Preserve which protocol and emitter branch were chosen. Holt closes only after the accord and proper orbital receiving. Commit 6,400 CR and `l337.unwritten-route/clue/choir-silent-voice` once with the same durable terminal action. Offer the resonance filter only for a compatible fit, with a separate reoffer if fitting must wait. It improves this campaign's signal identification. It grants no general immunity or energy increase and does not delay the clue.

There is no overall authored countdown. Any specific field timer must be defined and shown before a source arms it. Retain the actual mission actors, completed measurements, consent, item transfers, repair and loss outcomes, both branch receipts and final award on cold Continue. A fresh review must follow a stale quote. Lost originals and casualties remain recorded. Retry requires actual remaining authority and source property. The separate no-fee continuity design may award the missing clue only, with original failure and paid chapter rewards unchanged. No native C02 continuity or terminal path is issued on this head.

## Owners and unresolved source inputs

- **G4 physical requirement.** Qualify one real Larvaal ship, either the correctly crewed SH124 or independently authorized autonomous SH125, as a native Identification target. Validate the Balgodan SH162 repair port/approach as a separate object geometry and the actual Omdogan/Balmabol receiving berths for the selected player fit. Pin field-emitter geometry, collector approach and the three safe listening volumes once issued. The current fleet records provide suitability inputs without creating mission placement.
- **MC1 mission requirement, via Root and G1.** Retain the current opening and implement the first missing stage, the exact three Lobagom emitters and independent calibration receipts, before issuing the collector. Later work needs Vale's transactional receiving, one real probe repair, distinct safe listening measurements, evidence of actual emitter shutdown through either path, corrected signal/protocol and atomic original payment/clue. Exercise cold Continue after each transfer, each branch and terminal publication.
- **Root source decisions.** The real native vessel placement for opening eligibility, the three emitters' custody and physical envelopes, collector and culture stock/issuer, the probe's receiving authority and the allowed emitter shutdown action remain unissued. The authors specify the outcomes and leave those physical parameters open. The Voices in the Static entitlement and the independent core clue recovery are separate from C02's native commission.

The immutable story prose is `docs/meridian/missions/C02.md` and the definition is `docs/meridian/missions/definitions/quiet-choir.json` at `c70110b292077588a0855fb48127adfb1b611c9d`. The main story links here for flight, custody and implementation details. [Authored status on main](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L8129), [Current opening manifest](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/ScriptPacks/l337-quiet-choir/manifest.toml)
