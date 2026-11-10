# C07 · The Still Current

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#the-still-current) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against `19a177e66093716928947f7246e0b664e4a6ad07`. The reviewed opening source and corrected shared composition are retained outside executable main. The published branch has no original C07 pack, issued lattice or terminal. [Opening and reviewed composition](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L6976)

## Offer and story

After one ordinary trade, review the utility survey at Valrator's living main orbital in Galaxy 2. Use a writable save and actual trade evidence. There is no combat-rank gate. The original offer grants no tools, custody, charge or field authority. The **Last Light** product belongs to the separate launch catalogue and the core clue recovery is independent.

Physicist Anja Kest suspects conductive dust has bridged the isolation gaps of a supposedly dormant orbital lattice. The meter readings show its reservoir growing even though output is reported as zero. Salvage Chief Ruan Pell discovers that unmanned reclamation machines keep rebuilding the bridges under an obsolete commissioning order. The maintenance tender is trapped by heat. Rescue its technicians and establish the real energy balance before the settlements choose a supervised local buffer or safe material recovery.

## Geography and fit

| Galaxy 2 link | Distance and required use |
| --- | --- |
| Valrator G02-S090 ↔ Karrakor G02-S174 | 2.376 LY. Kest's actual laboratory at Valrator, the charged lattice and the real local rescue berth at Karrakor. |
| Karrakor ↔ Mortor G02-S159 | 5.106 LY. Mortor's external feedlines and actual branch receiving. |
| Mortor → Valrator | 2.819 LY. Return the original programmer and signed settlement. |

Refuel where needed and verify effective reach, the living station and fitted clearance. All local legs are within nominal 7 LY reach. Getting to Galaxy 2 from the starting galaxy needs an actual galactic transfer. A geometrical route establishes neither a physical receiving berth nor installed utility capacity. [World data](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/OriginalWorlds/catalogue.json), [Fuel and reach](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/FuelStorage.swift#L8), [Actual station proof](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/NativeStationServices.swift#L135)

Use normal flight, targeting and contextual Confirm. A normal SH025 can plan these legs. Reserve one free tonne after installed modules and trade cargo. The original charge cell is exchanged atomically for the distinct one-tonne baffle programmer at Valrator. The player never needs both aboard, carries no assigned rescue passengers and retains the programmer through both field proofs. Exact sensing, heat and insulated baffle envelopes are unissued.

| Authored craft | Exact nominal original fit |
| --- | --- |
| SH001 Mule | Two native operators, 76 t hold, 9 LY hull reach and 13 LY tank. Catalogue placement pending. [Reference image](../../assets/ships/SH001.png) |
| SH049 Hyena | Two native operators, 32 t hold, 8 LY hull reach and 12 LY tank. The source identifies a human pirate hull with placement pending. [Reference image](../../assets/ships/SH049.png) |
| SH061 Saiga | Two native operators, 84 t hold, 9 LY hull reach and 13 LY tank. Actual tender crew, accommodation and loaded clearance require their own physical proof. [Reference image](../../assets/ships/SH061.png) |

The authored list does not bind those three hulls to the stranded tender, replacement retrieval or optional scavengers. The unmanned sled and installed collectors require their own objects and safe interaction policy. [Mule design](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH001.toml), [Hyena design](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH049.toml), [Saiga design](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/fleet-design-v2/ships/SH061.toml)

## Play the twelve stages

| Stage | Player action and qualifying evidence |
| --- | --- |
| 1. `accept` | At Valrator Confirm the original utility survey after one genuine ordinary trade. |
| 2. `survey-current` | At Karrakor scan the real supply, reservoir and return meters. Separate physical charge growth from the reported zero output. |
| 3. `recover-cell` | Recover the original insulated one-tonne cell from its unmanned maintenance sled. No EMP into the charged lattice and no tractor on the collectors. |
| 4. `analyse-charge` | At Valrator Kest receives that same cell and lends the original programmer atomically. |
| 5. `rescue-technicians` | Escort the exact living tender through Karrakor's actual safe corridor and verify receiving at the designated berth. Maintain the separate identities of tender, technicians and destination. |
| 6. `map-feedlines` | At Mortor scan the actual port, keel and starboard feedlines. Identify the archived instruction still directing the reclamation machines. |
| 7. `place-baffles` | At Karrakor use the same programmer to position three distinct insulated baffles. Verify each actual placement. |
| 8. `choose-lattice` | At Valrator choose **Commission a bounded community energy buffer** or **Recover the stored energy and dismantle the collectors**. Record one result with the actual operators. |
| 9. `isolate-collectors` | At Karrakor revoke the archived authority and test the locally bounded quota for the buffer, or disable the archived work controller and verify all collector bus links are isolated for recovery. |
| 10. `settle-reservoir` | At Mortor verify the selected branch's actual energy and, for recovery, material receiving. Apply the limits below. |
| 11. `return-programmer` | At Valrator return the same loan and verify the measured final balance, baffles and exact authorized receiving proofs. |
| 12. `close-case` | Confirm genuine utility settlement. Record the chosen public outcome and commit 8,400 CR and `l337.unwritten-route/clue/current-resting-arc` together once. |

[Existing stage and branch packet](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L2152)

## Conservation, failure and continuation

The conserved accounting is **remaining + physically delivered + safely discharged + recovered = 900 charge units**. After isolation external input is zero. The buffer delivers exactly **300** measured units to the real local utility and retains exactly **600** in the tested bounded buffer. That branch cannot discharge energy or transfer it to recovery storage. Recovery leaves the reservoir empty through verified storage and controlled discharges capped at **90 units per operation**, then proves actual collector-material receiving. No duplicate, negative, mixed-branch or invented receiver transaction can complete either branch.

Heat accrues only from actual occupancy of the named geometric hazard volume in active simulation time. Pause stops it. There is no hidden global deadline. The physical heating rate, cooling and safe exposure envelope need source approval and a fit check. A genuine loss preserves technician and tender outcomes. Retry only from remaining real registered retrieval capacity and people. Combat or culling cannot supply an arrival or isolation receipt.

On cold Continue retain original meters, positions, remaining balances, occupied heat and exposure state where applicable, item custody, actual losses, revoked authority, chosen branch and settlement. Replaying a receipt cannot move charge, change the branch or pay twice. The intended no-fee alternate awards only the clue and preserves original failure. No general curse, damage entitlement, legal reset or free hull follows the survey.

- **G4 physical requirement.** Pin the lattice, three baffles, measurable heat volume and a safely navigable real rescue corridor. Approve the loaded tender and berth fit, the actual source sled and collector motion and the two physical receiver limits. Design hull names alone do not issue actors or make the rescue safe.
- **MC1 mission requirement, via Root and G1.** Rebind the reviewed opening to current shared paths, then issue the three actual meters and original insulated cell. Keep the single-tonne exchange, real rescue and baffle work, mutually exclusive settlement ledger and exact once-only 8,400 CR/clue.
- **Root source decisions.** Exact fitted tender role, crew, receiving staff and replacement capacity, heat envelopes, issued field props, finite inventory, actual utility and recovery receiving roles remain open. The 900/300/600/90 values are already authored.

The archived story and exact definition are `docs/meridian/missions/C07.md` and `docs/meridian/missions/definitions/still-current.json` at `c70110b292077588a0855fb48127adfb1b611c9d`, definition SHA-256 `a4cd54915cd51048002f88c862f99665bcc11f65785ec8fb3dc62a7109e67f47`. The branch-specific conservation rule also pins `original-missions/STILL-CURRENT-CONTRACT.md`, SHA-256 `ed92e61707ffdecd3f64d085621b6b9bd1c9cf2f6a8f493f243652d8b69d0b41`.
