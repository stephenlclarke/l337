# fix(missions): borrow current state through Contracts callers

## Change

Rows, Review, Quote and the selected pack and dock readers now use the existing synchronous stored-state borrowing helpers. They return source, custody, dock, scalar or presentation fields instead of full Commander and script engine values. Pack headers and active row headers leave their read scope before full row validation begins. Active rows retain the same instance UUID order, stock units retain their UUID order and installed providers retain their original order and first-match behavior.

The shared potentially noncopyable pointee helper becomes module-visible without changing its body. This is the same visibility change already present in the separately held T04 source; integration must deduplicate that shared hunk, not import the rest of T04.

The owning `wayfarerPack` result remains available to the existing transaction code. Its new borrowed selection validates the original terms, state ID and availability before copying the selected result. Quote uses the borrowed validation directly. Missing or rejected first matches cannot fall through to a later duplicate, including when a read callback itself returns nil.

## Preserved validation

Review still checks writable saves, original provider availability and accreditation before the action. Pickup checks the source digest, full quote and unit, then cargo and mission capacity. Objective and receiving actions retain current custody, provider equality, repeated availability, live docking evidence, owner, living resource, integrity and receiver checks. Expiry and unavailable actions keep their original conditions and messages.

Quote retains the service slot check first, then original stock, ledger owner, source validity and first available unit. It validates the exact provider and terms, the actual living source dock and every route edge using current fuel for the first leg and full capacity for later legs. The quote identity and returned terms are unchanged. Dock reads keep the original ordered mode, energy, epoch, receipt, owner, site, destroyed-resource and full resource checks.

Native receiving, stock transactions, money and save publication code are unchanged. No source, entitlement, content, schema, migration or actor-isolation policy changes are included. The read callbacks are synchronous and cannot suspend or mutate their borrowed state.

## Tests and evidence

The four exact ordinary selectors remain. The wrong-actor journey retains its preview and complete original body. Its new refusal checks use copies of the actual pre-acceptance docked game. A deliberately missing first declaration is refusal-only test input, never content or consent authority. The live runtime, commander and save files must stay unchanged. The first matching optional-nil callback must execute once; no provider fallback is allowed. Empty fuel still refuses the route, and oversized cargo still short-circuits safely. Test comparisons use the existing stored commander equality helper to avoid adding owned Commander locals beneath the production calls.

The other three ordinary test bodies and native transaction code are unchanged. New tests are authored but UNRUN until an exact reviewed native assignment. Source, formatter, documentation and offline operator checks are distinct from Swift execution. Known evidence is the previous changed-image terminal proof `b8db6038` and frame comparison `ca868552`; the dynamic caller totals and savings of this correction remain unmeasured.

The execution preparation retains the four selectors, prior source and preparation reviews, strict console/XML parser, mapped helper/image join, both leases, resource guards and separate actual build/test START audits. One new G2 source-and-preparation receipt binds the exact new source and plan; a fresh Root one-use grant remains required. Full CI, coverage, leak gates, protected merge, main-only Sonar, playable acceptance and release remain open.

Related issue: [Contracts caller stack pressure](ISSUE-w01-w03-borrowed-callers.md).
