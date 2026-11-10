# W01 · Cold-chain clinic service

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#cold-chain-clinic-service) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against `19a177e66093716928947f7246e0b664e4a6ad07`. The ordinary native board, stock, pickup, delivery and receiving path integrated at `62272297`, with an aggregate of 14 methods and 15 cases, native pack validation and clean review. A signed limited artifact verified the actual pack. Current manual W01 board, flight, clinic reception and release acceptance remain open. [Source qualification](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/archive/work-items/quality-delivery/PR-original-cold-chain.md#L11), [Signed pack verification](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L4152)

## Offer, route and fit

At **Cedamar G01-S085 main orbital**, collect one of six original sealed samples from finite batch `cedamar-clinic-01`. Fly to **Celalen G01-S241 main orbital**. The one quoted leg is **1.975 LY**, or 20 fuel tenths at the stock multiplier. The quote is **320 + 85 × L + 90 × H CR**, giving **405 CR at L1/H0**. Use **1 t free hold**, zero berths and no deposit. No special fitting is listed for this ordinary profile. SH025's one intrinsic operating place, 92 t nominal hold, 9 LY hull reach and 13 LY tank are a candidate baseline. Check actual fit, available fuel and both swept station approaches. [Bundled terms and sites](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/ScriptPacks/l337-cold-chain/manifest.toml#L13), [World coordinates](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/OriginalWorlds/catalogue.json), [Peregrine design](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH025.toml#L39)

The ordinary bundled development profile needs no accreditation. The authored finished-game **Wayfarer Union** paid product requires ownership and actual C08 accreditation for this family. Its independent core clue inquiry remains available without purchase or accreditation. The paid access rule and the existing development board qualification are separate. The integrity budget is an authored **2,700 armed flight seconds** from actual pickup. It runs on native flight time, freezes when paused and keeps its original due value across Save and Continue. Docking at the destination and receiving use the real viable sample. [Native pickup and timer](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainCommands.swift#L396), [Current board terms](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainBoard.swift#L285)

## Play the three authored stages

| Stage | Player action and qualifying evidence |
| --- | --- |
| 1. `collect` | At actual Cedamar confirm a fresh quote for the exact available sample. Atomically consume that source slot, place the unique protected one-tonne sample aboard and arm its flight clock. The cap is three active Original contracts/services. Back leaves stock and custody unchanged. |
| 2. `deliver` | Fly and dock through actual Celalen entry with that same viable sample. Confirm **verify arrival**. Require the later native objective dock and held unit. Arrival pays nothing and opens the separate receiver action. |
| 3. `receive` | At actual Celalen confirm **receive and pay**. Match the previous arrival, current valid clinic and same viable sample. Complete physical custody, pay **405 CR once** and award the first trusted `l337.unwritten-route/clue/exchange-service-cold-chain`. The same Celalen visit can support both confirmations. |

[Live board actions](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainBoard.swift#L57), [Native objective](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainCommands.swift#L502), [Native receiving](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainCommands.swift#L552)

[Pickup artwork](../../assets/missions/services/cold-chain-collect.png) · [Delivery artwork](../../assets/missions/services/cold-chain-deliver.png) · [Clinic artwork](../../assets/missions/services/cold-chain-receive.png) · [Completed clue art](../../assets/missions/clues/exchange-service-cold-chain.svg)

## Failure, cold Continue and owners

Actual loss or expiry pays nothing and never replenishes the six units. The retry shown for suspended expiry retries the same terminal recording and preserves original loss, rather than issuing new cargo. A later actual job needs a different available source unit. Continue keeps exact source and unit IDs, custody, original clock, objective and receiving evidence, once-only cash and clue. Closed Normal 35/Alien 36 apply to the bounded W01 profile and compose with later current claims. The independent no-fee core inquiry recovers only a missing clue. [Expiry and retry](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainCommands.swift#L615), [Save profile](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerColdChainSave.swift#L3)

- **G4 physical requirement.** Witness actual Cedamar exit, paid 1.975 LY flight, loaded Celalen docking and both current clinic confirmations.
- **MC1 mission requirement, via Root and G1.** Qualify the current ordinary board, cargo and both confirmations, strict live timer, pause, cold Continue, expiry/rollback, exhaustion, once-only settlement and gallery. Apply the finished product gate while retaining the independent clue path.
- **Root source decisions.** The six samples, clock, route and 405 CR are declared. Keep development access, final commercial policy and qualified app evidence separate.

Historical source is `docs/meridian/missions/definitions/wayfarer-services.json#/templates/0` at `c70110b292077588a0855fb48127adfb1b611c9d`, SHA-256 `45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4`.
