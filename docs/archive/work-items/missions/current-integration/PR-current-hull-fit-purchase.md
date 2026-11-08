# fix(equipment): validate fresh paid outfits before quotation

## Behavior

Ordinary fresh commanders now use the selected hull's existing fitting budget before their first calendar/save record. Shop quotations preview the real atomic purchase on an isolated commander, and requirement text uses that same quote. Overflow refuses before debit or publication. Commit still independently checks its complete source commander and current shop context.

## Implementation

Restrict the existing accommodation exception to explicit secret mode with its same custody and contract bounds. Reuse `acceptEquipmentPurchase` for the isolated quote preview and report its existing `incompatibleFit` error in the requirement text. The preview creates temporary identities and data only; it publishes no item, receipt or commander and performs no I/O or actor reentry. There is no recursive Game quote call in Commander validation.

## Validation and limits

Four new source methods use the current active original SH025, its actual ten-unit profile and real paid utilities/tanks. They cover an exact fit, a two-unit overflow, actual purchase-intent refusal, stale/replayed quotes, real current save/load and rejected refitting of a paid held item. The full-budget test also preserves Fuel's separate requirement and real paid purchase path. All tests are UNRUN; source text and patch/hash checks are not compiler or gameplay evidence. G1 must run the focused methods, the existing equipment transaction tests and the required final gates on the composed candidate. Review must consider repeated UI quotation cost because it now previews full Commander validation.

This is fresh/current behavior only. No historical save support, per-ID resource, generic utility, crew grant, CI change or live PR299 update is included. Pending mission producers and actual M02/M03 acceptance remain separate work. Source candidate only; no PR has been raised.

Linked issue: ISSUE-current-hull-fit-purchase.md.
