# C08 · Wayfarer Exchange

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#wayfarer-exchange) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against `19a177e66093716928947f7246e0b664e4a6ad07`. The exact main contains the native induction and accreditation paths. A single complete ordinary career still needs qualification. [Opening and child ownership](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L1974), [Current player instructions](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/README.md#L208)

## Offer and progression

Dispatcher Evi Senn and Custodian Tomas Veil want independent clinics, repair workshops, seed custodians and utility crews to share transport without giving up ownership. Rowan demonstrates four genuine receiving chains and makes a working utility route possible. The operators choose how to reserve scarce windows. They sign their own actual policy and Veil tests it before Senn accredits the commander.

At Avenor's living main orbital in Galaxy 1, review the induction after one genuine ordinary delivery or commodity sale. Use a writable save and one free tonne after fitted equipment and existing cargo. Preparation has no overall timer and no rank or rare-offer gate. Confirm keeps the existing commander and property and does not issue every later loan. The finished paid grouping is **The Wayfarer Union**. Product ownership and earned accreditation are separate, and an independently authorized core inquiry is the clue-only route. [Native induction source](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInduction.swift#L519), [Native offer and field history](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionBoard.swift#L651)

## Geography, custody and ship fit

| Galaxy 1 player objective leg | Nominal route at 9 LY with fuel |
| --- | --- |
| Avenor G01-S007 → Renas G01-S185 → Navidor G01-S164 | 3.365 + 7.481 LY |
| Navidor → Enmadan G01-S000 → Renas | 8.514 + 5.581 LY |
| Renas → Enlirin G01-S162 | Via Navidor, 7.481 + 6.103 LY. Direct is 11.638 LY. |
| Enlirin → Lareria G01-S091 | Via Navidor, 6.103 + 6.978 LY. Direct is 13.078 LY. |
| Lareria → Cevilis G01-S211 → Enmadan | 8.375 LY to Cevilis. Return to Enmadan via Lareria, 8.375 + 3.127 LY. |
| Enmadan → Enron G01-S190 → Avenor | 7.977 LY to Enron. Return via Navidor, 5.193 + 7.508 LY. |

Refuel against the actual fit and living orbital. The Enlirin–Lareria nominal path totals 13.081 LY before rounding and requires planned refuelling wherever the exact ship's attainable fuel falls short. These are player-planning routes. A native ark or rescue launch selects its own feasible route against its actual drive, tank and escort reach. It uses its own paid, finite fuel and station allocation. Do not promote any plotted route to an arrival. [Original catalogue](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/OriginalWorlds/catalogue.json), [Fuel](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/FuelStorage.swift#L8), [Ark route](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionArkRoute.swift#L16), [Rescue route](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionRescueRoute.swift#L4)

Keep one serial tonne of hold for the clinic crate, failed cassette, vault key or custody recorder as the current stage requires. They never overlap in the induction. Fit actual Fuel Scoops for the Cevilis recorder. The crew, seed and rescue consignments travel aboard the original NPC craft and require no player cabins. **SH025 Peregrine Mk V** is a route-planning player option. Prove actual receiving fit and the scoop approach on the selected player hull.

| Craft | Exact mission binding and fit boundary |
| --- | --- |
| **SH001 Mule / SH005 Bison** | Both are in the archived C08 ship list. The Mule's fleet design calls for two native crew and a 76 t hold. Bison's calls for twelve and a 1,108 t hold. Bison's 7 LY hull cannot be assumed to fly the listed 9 LY player plan. No original C08 transport, berth or roster is assigned by either catalogue entry. |
| **SH061 Saiga** | The native Enlirin ark uses original Saiga geometry and finite actual drive, fuel, 40 seed tonnes and six crew. Its vault key rides with the commander. Verify the same registered hull and full consignment at Lareria's distinct receiving cradle. The approved reserve holds one distinct Saiga, 40 real seed tonnes and six separate crew, with its own finite issue. |
| **SH029 Okapi** | The current mission code binds an empty disabled Cevilis tender and a distinct marked two-person launch. This native binding is more specific than the archived ship list, which omits SH029. The source board says 9 LY drive, while the exact SH029 fleet performance feeding the native profile lists 10 LY. The route actually limits reach by the source drive, tank and fitted escort. Verify the prepared actual route before displaying its limits. The 13 LY tank and separate 1,000 CR custodian funding are conserved. |

[SH001 reference](../../assets/ships/SH001.png), [SH005 reference](../../assets/ships/SH005.png), [SH061 reference](../../assets/ships/SH061.png), [SH029 renderer reference](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/SHIP-CATALOGUE.md#sh029---okapi), [SH061 ark identity](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionArkSource.swift#L17), [SH029 native source](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionCrewLogSource.swift#L43), [SH029 original performance](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH029.toml#L39), [Rescue board text](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionBoard.swift#L668)

## Play the fourteen stages

| Stage | Player action and qualifying evidence |
| --- | --- |
| 1. `accept` | At Avenor review and Confirm Senn's original induction. Back changes no holdings. |
| 2. `collect-coldcrate` | At Renas Confirm the original one-tonne sealed crate and its actual cooling budget. Starts 1,800 seconds of armed flight only at pickup. |
| 3. `deliver-coldchain` | At Navidor's real clinic berth receive the same intact original while remaining time is strictly positive. At zero, record spoilage without success. |
| 4. `recover-cassette` | At Enmadan take the actual failed one-tonne owner cassette. Keep serial custody. |
| 5. `close-repair-loop` | At Renas use the real repair desk to verify the completed service and close that same cassette's owner receiving. A similar unit or an ordinary commodity sale cannot complete it. |
| 6. `survey-seed-vault` | At Enlirin obtain genuine consent and borrow the original one-tonne key. The seed remains with the ark owner. |
| 7. `escort-seed-ark` | Escort the same crewed ark through actual admitted transit and any paid refuelling. At Lareria confirm real cradle acceptance of the original seeds and crew and return the key. |
| 8. `recover-crew-log` | At Cevilis scoop the same one-tonne recorder from beside the disabled tender. Use fitted scoops at no more than 15 m/s relative speed through the 16 m half-extents around the actual aperture. The recorder proves identities, not arrival. |
| 9. `return-survivors` | Guide the original living two-person launch, with its own fuel and berth events, to Enmadan. Confirm the genuine reception, same recorder and return of unused custodian funds. |
| 10. `reopen-utility-route` | At Enron obtain native maintenance authority. In front view separately review and arm each original inlet, buffer and return. Hold a clear work-face hit 50–150 m away, at up to 1 m/s and 2°, for 20 qualified seconds per handoff. Confirm actual Enron station receiving. |
| 11. `choose-charter` | At Avenor choose **Pool unused route windows with a published local minimum** or **Protect local reservations and share only released capacity**. Confirm the exact policy once. |
| 12. `commit-charter` | Get the three selected-policy signatures at the actual Renas clinic, Enmadan workshop and Enlirin seed custodian. Back at Avenor confirm the bounded audit using a real reachable lot, current source quote and read-only authority. Verify no policy consumes a protected unit. |
| 13. `certify-network` | At Avenor Veil checks all four original receiving chains, Enron's working handoffs, branch signatures and capacity audit. No payment at certification. |
| 14. `close-case` | Senn's real Avenor receiving verifies the certified network and commits 7,600 CR, the chosen charter, accreditation and `l337.unwritten-route/clue/exchange-unbooked-window` together. |

[Work envelopes](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionUtilityWorkState.swift#L158), [Operator consent and release](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionCharterConsentBoard.swift#L129), [Veil certification](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionNetworkBoard.swift#L25), [Senn settlement](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionAccreditationBoard.swift#L53)

## Failure, capacity and cold Continue

Pause stops the clinic's active flight budget and load preserves the same remaining time, seal and original consignment. Genuine spoilage or loss persists. Replacement requires actual remaining owner stock. A lost ark does not respawn and its one authorized separate reserve needs new genuine launch, crew, cargo and receiving. If the original Cevilis launch is destroyed, current source records its original two people as lost. The retained uncrewed spare is not a supported recovery path by itself. Never create replacement people or a duplicate recorder.

Each charter epoch has six indivisible units per operator, 18 total, with a protected minimum of two per operator. Pooled windows may draw only free surplus above the minimum. Protected reservations share only exact released units. Keep the signed choice, unit, stock, fit and real receiving bound. The repeat services share a three-active-contract limit. They are independent mission families with their own payment and first-success clue. W06 Convoy Watch remains unissued. Neither a repeat job nor the paid product can settle the induction again. [Charter terms](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeWayfarerInductionCharter.swift#L20), [Shared active limit](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/OriginalServiceReservationPolicy.swift#L4), [Current rescue-loss boundary](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L1924)

For full qualification use an ordinary current-format career, and cold Continue at each timed pickup, paid NPC refuel, living reception, policy choice and terminal. Both branches retain the exact current authority, cargo and conservation without duplicate stock, fee, accreditation or clue. Show the old loss and usable replacement separately. The free clue path preserves the induction outcome and grants no trade authority.

- **G4 physical requirement.** Check actual Renas, Navidor, Lareria, Cevilis, Enmadan and Enron approaches, the loaded Saiga and two-person Okapi and their real berth/refuel paths. Verify the three Enron work envelopes and actual stationary source frames. Do not substitute Mule or Bison for a named original.
- **MC1 mission requirement, via Root and G1.** Reconcile the fixed 9 LY rescue board label with the actual 10 LY source hull and route-minimum predicate. Qualify the original ordered induction, both charter branches, same serial items, reserved stock and six actual authority/receiving boundaries through cold Continue. Keep the unsupported original-crew spare path unavailable until genuine survival and reboarding sources exist.
- **Root source decisions.** Decide whether to issue a real Cevilis surviving-crew transfer to the spare. Any such source needs actual surviving custody. Product entitlement and W06 first-offer issuance are separate from C08 accreditation.

Historical prose and data are `docs/meridian/missions/C08.md` and `docs/meridian/missions/definitions/wayfarer-exchange.json` at `c70110b292077588a0855fb48127adfb1b611c9d`. Definition SHA-256 is `9be9729169d2f52ab0b10755b048a473d7fba470e02d707fcdcadcfaf737bd97`. [Current board and original runtime](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/ScriptPacks/l337-wayfarer-induction/manifest.toml)
