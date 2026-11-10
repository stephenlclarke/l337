# T03 · Defensive flight practice

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#defensive-flight-practice) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against `19a177e66093716928947f7246e0b664e4a6ad07`. Main includes the native lesson from reviewed PR87 integration `ba83e0d273849ab96b6bd6aea7da7d513dee9dba`. The historical evidence is the front-view observation method pass at `bcd75d29` and two Normal/Alien codec cases at `33a57dca`. Current manually flown four-phase completion and separate debrief remain unqualified. [Scoped qualification](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L668)

## Offer, route and fit

Use the current owned ship at actual **Avenor G01-S007 main orbital**. Fly the local course and return to the same real berth. No hyperspace leg, targeting equipment, cargo, cabins, deposit, donation, cash reward or deadline is required. Resolve any prior player projectiles and other active native practice range before accepting. T02 is optional. The actual hull's measured radius and the full swept route must fit. The SH025 design gives one intrinsic operator, 92 t nominal hold and working flight control. Its current raw display mesh has approximately **72.547** units maximum vertex radius, a static input for course assessment. Actual admission measures the live player mesh and course obstruction. [Bundled terms](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/ScriptPacks/l337-defensive-flight/manifest.toml#L13), [Live review fit](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeDefensiveFlightBoard.swift#L44), [SH025 mesh](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/Ships/SH025.toml)

## Play the three authored stages

| Stage | Player action and qualifying evidence |
| --- | --- |
| 1. `accept` | At actual Avenor confirm **Defensive flight / review and consent**. Start in the current owner and carrier. Admit the three inert 6 m beacons only after physical range and hull clearance checks. Back changes nothing. |
| 2. `perform` | Manually acquire the exact centre reference, fly signed gate A, cross x=0 and reverse through gate B, then complete the measured withdrawal. Use the real criteria below. The course retires after verified break-off. |
| 3. `receive` | Return through the later real Avenor doorway in the original carrier and separately confirm **Defensive flight / receive verified practice**. Bind the four measured phases, crossing and real arrival. Award the first trusted `l337.unwritten-route/clue/defensive-flight-family-trace` with zero financial settlement. |

| Phase | Measured criteria in the centre beacon's course frame |
| --- | --- |
| Acquisition | Front view, x/y within 50 m, z from −500 to −350 m, range 350–500 m, speed at most 5 m/s, nose within 5° of centre and unobstructed centre-directed ray. Hold for 2 continuous active seconds. |
| Gate A | Player centre within 40 m of `(+180, 0, -450)` for 0.5 s, speed 5–30 m/s, lateral velocity at least +3 m/s and nose within 30° of velocity. |
| Gate B | Actual intervening x=0 crossing, then centre within 40 m of `(-180, 0, -450)` for 0.5 s, speed 5–30 m/s, lateral velocity at most −3 m/s and nose within 30° of velocity. |
| Break-off | Clear exit x within 250 m, y within 150 m and z from −1,450 to −450 m. Beyond the 1,100 m rear plane, separate at least 5 m/s at 5–30 m/s total speed, nose at least 150° away from centre, for three continuous active seconds. |

The native provider checks the actual whole course, with **over 32 m** swept hull/beacon clearance. Target acquisition uses the front-view centre reference and real raycast. The exercise advances on actual attained manual flight with no autopilot or work guidance. It has no attacker, live-fire score or damage simulation. Traffic intrusion resets the unfinished window and preserves the traffic. Pause, help and offline time earn no credit. [Geometry and exact thresholds](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeDefensiveFlightGeometry.swift#L62), [Actual observation source](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeDefensiveFlightObservation.swift#L16), [Player-facing details](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeDefensiveFlightBoard.swift#L197)

[Offer artwork](../../assets/missions/services/defensive-flight-accept.png) · [Course artwork](../../assets/missions/services/defensive-flight-perform.png) · [Debrief artwork](../../assets/missions/services/defensive-flight-receive.png) · [Completed clue art](../../assets/missions/clues/defensive-flight-family-trace.svg)

## Failure, cold Continue and owners

Actual discharge, ordinary harm, collision or an unsafe near-pass fails the attempt and preserves ordinary consequences. Escape leaves the active exercise. The station's **close or cancel this attempt** action can close it without reward or clue. A new attempt needs a fresh native review and available board record capacity. Continue preserves original authority, completed phase measurements, genuine failure and terminal reception through the closed Normal 135 and Alien 136 format where applicable. Re-establish live motion for unfinished observations after load. The independent no-cost core inquiry can recover only the missing clue. [Lesson save validation](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeDefensiveFlightSave.swift#L3)

- **G4 physical requirement.** Witness actual hull fit, clear course admission, manual crossing and withdrawal and real later Avenor swept return.
- **MC1 mission requirement, via Root and G1.** Qualify the manual ordered acquisition and measured manoeuvres, traffic resets, genuine failures, separate debrief, gallery and cold Continue on current source.
- **Root source decisions.** Keep the existing non-firing lesson and scoped historical corrections. Retain separate proof for the current full manual itinerary.

Historical source is `docs/meridian/missions/definitions/original-families.json#/templates/17` at `c70110b292077588a0855fb48127adfb1b611c9d`, SHA-256 `abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5`. The approved T03.P01 handoff is under `docs/meridian/missions/gameplay/contracts/ux` at that commit.
