# W02 · Closed repair exchange

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#closed-repair-exchange) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against `19a177e66093716928947f7246e0b664e4a6ad07`. The ordinary native pickup, repair and original-owner return path integrated at `c2c76fd3` after one 16-method, 17-case owner run, native pack validation and clean complete review. Signed limited 1.4.889 verified the actual pack. Current manual flight, workshop, return and release acceptance remain open. [Native qualification](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/archive/work-items/quality-delivery/PR-original-repair-loop.md#L13), [Signed artifact scope](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L4152)

## Offer, route and fit

An original **Cedamar G01-S085 main-orbital owner** lends one of six original failed scoop-control units from `cedamar-repair-01`. Use **2 t** of real hold and inventory space. The unit remains a transport-only loan before and after repair. Fly **Cedamar → Celalen G01-S241 → Cedamar**, 1.975 LY each way and **3.950 LY** total. At stock multiplier the two jumps take 20 fuel tenths each. The quote **430 + 90 × L + 80 × H CR** gives **610 CR at L2/H0**, with no berth, deposit, workshop fee or deadline. Check actual reach, fuel, hold and swept fit of the owned carrier. SH025 has one intrinsic operating place, 92 t nominal hold, 9 LY hull reach and 13 LY tank. The ordinary development row has no accreditation gate. Finished Wayfarer Union access requires the paid product and actual C08 accreditation. [Bundled terms](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/ScriptPacks/l337-repair-loop/manifest.toml#L13), [Native quote and custody](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerRepairLoopCommands.swift#L296), [World coordinates](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/OriginalWorlds/catalogue.json)

## Play the three authored stages

| Stage | Player action and qualifying evidence |
| --- | --- |
| 1. `collect` | At actual Cedamar review the original available serial and confirm the fresh native pickup. Allocate the same finite source unit, loan obligation and protected 2 t atomically. Back changes nothing. |
| 2. `service` | Carry the failed serial to the actual Celalen workshop. Confirm **Repair loop: service original unit**. The actual item changes from failed to serviced and keeps its original serial and custody. Keep it aboard and return to actual Cedamar. |
| 3. `receive` | Confirm **Repair loop: return to owner** with the original Cedamar owner. Match native issue, real workshop service and the serviced original. Settle the loan, release its hold and pay **610 CR once** with the first trusted `l337.unwritten-route/clue/exchange-service-repair-loop`. |

The loan uses the native Fuel Scoops equipment type and remains transport-only throughout. It supplies no usable player fitting, replacement, acquisition title or salvage reward. A live operation quote binds the original instance, current inventory revision, dock and epoch. A workshop receipt alone neither pays nor releases the loan. [Native operation and service](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerRepairLoopCommands.swift#L411), [Same-owner terminal](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerRepairLoopCommands.swift#L492)

[Pickup artwork](../../assets/missions/services/repair-loop-collect.png) · [Workshop artwork](../../assets/missions/services/repair-loop-service.png) · [Owner reception artwork](../../assets/missions/services/repair-loop-receive.png) · [Completed clue art](../../assets/missions/clues/exchange-service-repair-loop.svg)

## Failure, cold Continue and owners

Actual escape or fatal loss preserves the original serial's loss, obligation disposition and no reward. A later legitimate job needs another unissued original. A failed writer leaves native issue, service or return uncommitted and permits a fresh valid retry. Continue retains stock, serial and condition, protected load, issue, workshop and owner-return receipts, once-only cash and clue. Preserve closed Normal 37/Alien 38 W02 validation and current shared envelope. The independent no-fee core inquiry can recover only the missing clue. [Loss and mixed-save proof](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/archive/work-items/quality-delivery/PR-original-repair-loop.md#L17), [Save profile](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/WayfarerRepairLoopSave.swift#L3)

- **G4 physical requirement.** Witness both loaded jumps and native Celalen workshop and Cedamar owner docking with the same transport serial.
- **MC1 mission requirement, via Root and G1.** Qualify ordinary current pickup, repair, actual same-owner return, loss, finite stock, current gallery and cold Continue. Keep final paid access and independent clue separate from the development row.
- **Root source decisions.** Preserve Cedamar's six originals, the actual physical workshop, same owner and 610 CR. Qualify the exact current delivery separately from the retained 16/17.

Historical source is `docs/meridian/missions/definitions/wayfarer-services.json#/templates/1` at `c70110b292077588a0855fb48127adfb1b611c9d`, SHA-256 `45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4`.
