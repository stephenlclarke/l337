# fix(missions): borrow packs through availability dispatch

## Change

Borrow the read-only pack through the availability dispatcher and its no-inline helpers. Keep the single copies required by older native APIs within their selected helper. Capability and dependency checks also borrow the pack. All applicability predicates, branch order, refusal text and mission semantics are unchanged.

The caller trace was reviewed through `wayfarerPack`, `wayfarerColdChainQuote`, `wayfarerColdChainReview` and `wayfarerColdChainRows`. These callers and their source, entitlement, receiving, payment and save checks are unchanged. This correction targets the actual dispatcher entry fault; it does not claim to eliminate every aggregate copy elsewhere.

## Regression coverage

The existing ordinary wrong-actor test now reviews pickup twice before acceptance. It requires the same allowed offer, commander and on-disk files, then retains the complete original journey and stale-actor rejection. The other three exact receiver selectors are unchanged. All four tests remain unrun on this source until the reviewed native assignment.

## Validation and compatibility

Source parity is checked after removing only ownership annotations, explicit copy operators and the explanatory comment. The production code must otherwise match the failed source exactly. The test addition must leave the entire previous method body in order. Diff and Markdown checks are local static evidence only. No save schema, content, entitlement or actor-isolation change is included.

The complete source and execution preparation are sent together for one independent review. Preserve the previous parser corrections, native custody, both leases and actual build/test START audits. A fresh one-use Root grant is required. No unchanged retry or GUI launch is included.

Related issue: [Contracts availability stack crash](ISSUE-w01-w03-contracts-availability-stack.md).
