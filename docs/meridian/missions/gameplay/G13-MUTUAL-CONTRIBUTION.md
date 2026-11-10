# G13 · Mutual relief contribution

[Illustrated story](../../INTENDED-GAME-STORY-WALKTHROUGH.md#mutual-relief-contribution) · [Mission walkthrough checklist](../README.md)

Design walkthrough complete against `19a177e66093716928947f7246e0b664e4a6ad07`. The 17-path native source is integrated at `2f5227681b2b8aa99ebbae4ca81c342d8d14a4aa`, with one actual owner run of 18 methods and 36 cases, matching native pack validation and a clean independent review. Current ordinary app and release acceptance remain open. [Source integration](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/COMPLETION-LEDGER.md#L4551), [Owner qualification](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/archive/work-items/quality-delivery/PR-original-mutual-contribution.md#L13)

## Offer, route and fit

The **Cedamar Orbital Relief Reserve** offers one voluntary **500 CR** contribution row on the actual **Cedamar G01-S085 main-orbital** board. Begin with at least 500 CR of available cash. The job has **zero route legs**, cargo, cabins, deposit, cash reward and deadline. Any ordinarily dock-capable hull can bring the commander to Cedamar. No ship, crew, fitting or fuel is consumed by the payment itself. Keep the exact living main-station arrival and writable commander state for the review. [Bundled terms](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/Resources/ScriptPacks/l337-mutual-contribution/manifest.toml#L13), [Exact recipient and amount](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/OriginalMutualContribution.swift#L3)

## Play the three authored stages

| Stage | Player action and qualifying evidence |
| --- | --- |
| 1. `accept` | At actual Cedamar review the board's one credit row. Read the named fund and exact debit. Review and **Back** change nothing. **Decline** closes that offer without transferring money. |
| 2. `perform` | Deliberately confirm **Donate** on the current native quote. Validate this owner, live berth, epoch and offer revision. In one durable update debit exactly **500 CR** and issue the actual reserve's matching receipt. Food, cargo and fittings are unaffected. |
| 3. `receive` | The same operation publishes the reserve's acknowledgement and the completed zero-reward contract. The first valid receipt grants `l337.unwritten-route/clue/mutual-contribution-family-trace`. The station displays receipt state. A second confirmation, contact or handoff is unnecessary. |

Use the actual pledge receipt as the fund acknowledgement. It binds the exact installed pack, original instance and offer, identical actual Cedamar cause and committed dock, and 5,000 decicredits of real debit. The native success predicate joins the receipt to the zero-value completed settlement before awarding or validating the clue. Ordinary acceptance is insufficient. There is no refund, rank, trading privilege or cash prize. [Native receipt and clue checks](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Sources/L337Core/OriginalMutualContribution.swift#L38), [Current board and writer cases](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/Tests/L337CoreTests/OriginalMutualContributionTests.swift#L32)

[Offer artwork](../../assets/missions/services/mutual-contribution-accept.png) · [Contribution artwork](../../assets/missions/services/mutual-contribution-perform.png) · [Acknowledgement artwork](../../assets/missions/services/mutual-contribution-receive.png) · [Completed clue art](../../assets/missions/clues/mutual-contribution-family-trace.svg)

## Refusal, cold Continue and owners

A stale quote, wrong dock, paused play, short cash or writer refusal leaves the contribution uncommitted. Reopen a current review after redocking or resource change. A later hourly local-clock offer permits another deliberate donation of 500 CR. Replaying the same offer cannot charge twice. A later real donation retains the first clue without another award. Existing current Normal and Alien save formats retain the exact ledger and completed contract. Test pristine cold load and rejection after stripping or altering the receipt, cash debit, dock, fund or content identity. The independent no-cost core inquiry remains available for the missing clue. [Hourly policy and validation scope](https://github.com/stephenlclarke/l337/blob/19a177e66093716928947f7246e0b664e4a6ad07/docs/archive/work-items/quality-delivery/PR-original-mutual-contribution.md#L7)

- **G4 physical requirement.** Use the real Cedamar main orbital and current docking receipt. The contribution adds no flight segment or special fitting.
- **MC1 mission requirement, via Root and G1.** Qualify the exact current board and Donate, Back, Decline, wrong or stale dock, 499.9 CR refusal and exact 500 CR debit, durable retry and cold Continue. Keep the hourly second offer and single clue distinct.
- **Root source decisions.** The reserve and full voluntary amount are declared. Keep the station-only native owner pass distinct from an executed current-app and gallery receipt.

Historical source is `docs/meridian/missions/definitions/original-families.json#/templates/12` at `c70110b292077588a0855fb48127adfb1b611c9d`, SHA-256 `abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5`. The approved G13 implementation handoff is under `docs/meridian/missions/gameplay/contracts/ux` at the same commit.
