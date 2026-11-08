# Current hull fitting before the first save

## Problem

An ordinary fresh commander without a calendar record bypasses `passengerFit` in `accommodationValid` when no cabin or mission custody forces fitting. Real paid equipment can therefore exceed the selected hull budget. Saving establishes the calendar policy and can expose an outfit that the shop previously accepted.

Equipment quotations and the shop requirement text also check purchase eligibility and fitting sockets without validating the resulting commander. An over-budget quote can appear usable before the guarded commit refuses it.

## Required behavior

Use the existing canonical hull, cabin and common-equipment budget for ordinary current commanders from the first purchase. Keep the explicit secret-mode exception within its existing empty-cabin, no-held-person and no-contract bounds. A quote must preview the actual atomic purchase on an isolated candidate. A refused quote or commit must retain cash, ownership, item identity and payment history.

## Scope and validation

The change uses the existing purchase and fitting owners. The four new source methods cover actual SH025 budget ten, paid shop boundary and overflow, stale quote refusal, current cold save/load and hostile refitting of an actual paid held item. Fuel remains available through its separate paid transaction at the hardware limit. All four are UNRUN pending G1 execution. They contain no old-format or migration inputs. No generic device, capacity, staffing rule or per-ID resource is added.

Linked PR: not raised; this is a temporary source proposal for Root and G1.
