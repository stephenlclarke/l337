# Original hull identities

Use stable SH IDs with their actual original design bindings. The [reviewed fleet r3 packet](../milestones/FLEET-DESIGN-PACKETS.md) is the design authority, while the runtime TOMLs and the [completion ledger](../COMPLETION-LEDGER.md) determine what is active and qualified. A design import or story illustration does not activate a hull.

| ID | Original design | Source and boundary at this documentation checkpoint |
| --- | --- | --- |
| SH025 | Peregrine Mk V | [Original contract](../fleet-design-v2/ships/SH025.toml); [runtime definition](../../Sources/L337Core/Resources/Ships/SH025.toml). Fresh original-world commander’s starter; physical docking acceptance remains separate. |
| SH026 | Harrier | [Original contract](../fleet-design-v2/ships/SH026.toml). The checked-in runtime resource still contains a predecessor definition; do not use it as proof that the original Harrier is active. |
| SH162 | Larvaal Probe | [Original contract](../fleet-design-v2/ships/SH162.toml). Mission object, never a purchase or player hull. |
| SH171 | Medusa | [Original contract](../fleet-design-v2/ships/SH171.toml). The intended finale requires real EMP disablement, recovery of the original 50 kg controller, actual PLUGH receiving, then optional paid fabrication; no preview, clue count or XYZZY shortcut grants it. |

These bindings support the [original commander story](../meridian/INTENDED-GAME-STORY-WALKTHROUGH.md). The BBC Executive mission names and predecessor Cobra/Constrictor records in [research](../research/README.md) and the [archive](../archive/README.md) remain historical evidence, not current original-mission instructions.

A remaining development-source limitation is explicit: `Game.refitXYZzyCobra` still selects legacy SH023. XYZZY and its C refit are diagnostic features outside the original fleet journey. They are not a verified original replacement-hull path. Normal original play starts in SH025; changing this diagnostic behavior requires a separately assigned code change and its own tests. This documentation does not invent a replacement, mark SH026/SH171 admitted or claim the legacy path has been corrected.

The [runtime ship folder](../../Sources/L337Core/Resources/Ships), [generated catalogue](../SHIP-CATALOGUE.md) and [source provenance](../SHIP-PROVENANCE.md) can contain both activated original data and retained predecessor data. Read their source labels and the ledger rather than inferring current availability from a name or picture.
