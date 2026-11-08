# Stage a finite EMP bank and metered main transfer

## Changes

EMPBankState requires explicit physical module UUID, capacity, remaining
energy and clock. Its zero state remains valid. It stages capacity changes
with discard accounting, uncharged clock skips and exact released-pulse
debits. Its validated Codable representation retains modeled release history;
missing or malformed history/balances refuse decoding. No full-bank default,
native save registration, new receipt registry or secondary main balance exists.

EMPBankTransfer requires all owner terms explicitly and returns immutable
expected/result bank and ElectricalReserve snapshots. It refuses missing,
invalid, foreign, paused, disabled or unposted inputs and consumes no source
authority. The main reserve is already posted at interval end. One existing
drain pays actual bank gain and conversion loss; no reserve.advance or
elapsed generation/catch-up is used. Full capacity or explicit zero headroom
stages no debit while consuming that modeled interval. Absent terms refuse.

Pulse debits require the full representable cost. Charging rounds only
towards a smaller paid transfer/gain, never overpayment or free charge;
an invisible debit/gain refuses. No numeric epsilon is introduced.
Repeating an unapplied plan is deterministic; only a future revalidated
owner commit can consume actual
state. Snapshot equality is not item, interval, payment or publish authority.

## Validation

Two test files contain sixteen authored plain methods/cases. They exercise
finite capacity and zero, exact discharge, copy/value coding and modeled
replay, malformed decoding, monotonic skip, paid transfer/loss, independent
limits, full/no-headroom behavior, missing terms, stale/foreign supply and
precision/overflow refusal. Values are explicit test inputs, not production
balance approvals. No test, compiler, typecheck or discovery was run.

Author source inspection and static whitespace/hash checks are recorded by
the candidate packet. Independent code review and focused execution are
still pending. Existing125/174 expectations and all prior candidates remain
unchanged; these sixteen new definitions are separate and UNRUN.

## Required production joins

- Existing physical item owner must store/revalidate bank state, preserve it
  through every move/rebuild/upgrade/hull transaction and use validated native
  codecs. This leaf does not prove Commander save/load, legacy downgrade,
  write-failure or cross-owner/clock-domain safety.
- Actual paid equipment/catalogue owners must supply bank capacity, recharge,
  pulse cost, conversion efficiency, admitted main headroom and explicit
  purchase/loan starting charge. Spec proposals are not runtime authority.
- G3's actual Game owner must supply qualified intervals and uncharged skips;
  menus, pause, load and refitting must never mint elapsed recharge.
- The existing private EMP candidate/event owner must stage and persist bank
  release with victims/emission exactly once. Replace the old main outgoing
  cost in bank mode while preserving real incoming self-hit costs and failed
  publication rollback. No double debit or audit import is authorized.

Shared inventory/codec/EMPElectricalRuntime/GameConservedPower/Game hunks were
requested through Root and are not edited by this candidate. The existing
profile and F27 calculation remain unchanged; no new axes/prices or free
entitlements are installed. There is no complete bank gameplay, compile,
native, permission, integration, release or feature claim.

## Scope and compatibility

Exactly two new production files, two new test files and this paired issue/PR
documentation are staged under /tmp. No existing source, save pair, Game,
Package, Tools/group, harness, primary checkout or Git object is changed.
Root owns later integration and G1 is the sole executor after its current
priority. Related issue: ISSUE-emp-finite-bank-and-metered-transfer.md.
