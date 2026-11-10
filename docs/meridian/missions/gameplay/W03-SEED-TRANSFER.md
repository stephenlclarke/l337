# W03 · Seed-bank transfer

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#seed-bank-transfer) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against `19a177e66093716928947f7246e0b664e4a6ad07`. The native named-custodian profile integrated at `33304385e7327b13288bb2aa0d3685a01ac59d3c`. Its single owner run passed 20 methods and 21 cases, with native pack validation and full clean review. Current manual app and release acceptance remain open. [Native qualification](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/archive/work-items/missions/PR-original-seed-transfer.md#L13), [Source integration](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L4286)

## Offer, route and fit

**Custodian Lysa Verin** at **Celalen G01-S241 main orbital** releases one of six finite lots from `celalen-seed-bank-01`. **Custodian Oren Hale** at **Cedamar G01-S085 main orbital** receives the same sealed lot. Use **3 t of actual free hold** for one indivisible protected consignment, zero passenger berths and no deposit. The fixed outward jump is **1.975 LY**, 20 fuel tenths at stock multiplier. The quote **510 + 95 × L + 110 × H CR** gives **605 CR at L1/H0**. SH025's one intrinsic operating place, nominal 92 t hold, 9 LY hull reach and 13 LY tank give a candidate fit. Check actual fuel, hold and swept entry at both real ports. [Bundled terms and custodians](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/ScriptPacks/l337-seed-transfer/manifest.toml#L13), [Peregrine design](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH025.toml#L39)

The native ordinary development profile requires no accreditation. Finished Wayfarer Union access requires the paid product and actual C08 accreditation. The original **2,700 armed-flight-second** clock starts with confirmed pickup and keeps the original due value across Save and Continue. Pause freezes flight time. The two named actors supply institutional custody. They stay at their stations. [Actual release and clock](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainCommands.swift#L396)

## Play the three authored stages

| Stage | Player action and qualifying evidence |
| --- | --- |
| 1. `collect` | At real Celalen, review the exact lot and confirm Lysa Verin's native source release. Allocate its unit, reserve its actual 3 t, record her release and arm its clock atomically. Back changes nothing. |
| 2. `deliver` | Fly and dock at actual Cedamar with the same viable lot. Confirm **verify arrival**. Its objective receipt records the actual later berth without paying or completing custodian acceptance. |
| 3. `receive` | Confirm **receive and pay** with Oren Hale, the distinct receiving custodian at the same actual Cedamar office. Match the original release, lot, current arrival and valid integrity. Transfer custody, pay **605 CR once** and grant the first trusted `l337.unwritten-route/clue/exchange-service-seed-transfer`. |

Both custodian receipts bind the named role, lot, instance, actual station, epoch and exact content. The clock and receipt type are shared with W01, while W03 needs its explicit profile and distinct source and receiving identities. Another seed lot, a passenger transfer or a reference culture cannot substitute. [Custodian receipt producer](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainCommands.swift#L361), [Actual receiving publication](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainCommands.swift#L578)

[Pickup artwork](../../assets/missions/services/seed-transfer-collect.png) · [Carriage artwork](../../assets/missions/services/seed-transfer-deliver.png) · [Custodian reception artwork](../../assets/missions/services/seed-transfer-receive.png) · [Completed clue art](../../assets/missions/clues/exchange-service-seed-transfer.svg)

## Failure, cold Continue and owners

Expiry, genuine loss and exhaustion preserve the finite source and pay nothing. Another job requires a new unissued lot. Suspended expiry retry records the same terminal evidence. Writer refusal leaves custody and payment uncommitted. Continue retains both authentic custodian joins, original condition/clock, actual arrival and once-only payment and clue. Keep W03's explicit Normal 37/Alien 38 claims and genuine mixed W01/W02/W03 composition. The independent no-fee core inquiry can recover only the missing clue. [Save and native cases](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/archive/work-items/missions/PR-original-seed-transfer.md#L15)

- **G4 physical requirement.** Witness real loaded Celalen departure and Cedamar arrival, native fuel and both actual custodian actions.
- **MC1 mission requirement, via Root and G1.** Qualify the full current custody/clock/ship path and cold Continue. Exercise wrong custodian, stale or refused action, expiry, actual loss, no replenishment and one payment and clue. Keep final commercial access and independent clue path explicit.
- **Root source decisions.** Keep the fixed 605 CR, two named custodians and finite original stock. Current app/Gallery acceptance remains separate from the retained 20/21.

Historical source is `docs/meridian/missions/definitions/wayfarer-services.json#/templates/2` at `c70110b292077588a0855fb48127adfb1b611c9d`, SHA-256 `45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4`. The approved W03 handoff is under `docs/meridian/missions/gameplay/contracts/ux` at that commit.
