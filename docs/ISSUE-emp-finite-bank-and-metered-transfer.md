# Finite module-bound EMP bank and paid transfer boundary

## Motivation

M08.SALVAGE.EMP-01 requires a finite rechargeable EMP capacitor, separate
from hull energy, the existing main ElectricalReserve and EMP trigger warmup.
Current firing uses the main reserve directly; savedEMPCharge represents
charging/release/cancellation, not stored shots. Reusing electrical zero's
disable episode for an empty capacitor would also prevent ordinary refill.

The controlling salvage contract requires measured main-to-bank transfer,
no refill from fit/store/upgrade/load, and one bank cost per actual release.
Its capacity, recharge, efficiency and new upgrade prices remain proposals.
This work must not guess those values or reinterpret F27 energy effects as
paid EMP upgrade entitlements.

## Bounded implementation

Add an EMP-only finite value keyed by the physical module UUID and require
explicit initial remaining energy, capacity and time. Empty is a valid bank.
Capacity growth preserves charge; shrinkage reports discarded excess without
crediting main energy or money. Model one released EMPChargeState debit and
retain its identity to reject duplicate/older events in subsequent values.

Add atomic arithmetic staging of the bank and the existing main reserve.
Require explicit capacity/rate/efficiency/withdrawal-headroom terms and a
matching interval/module snapshot. Missing terms are refusal, not zero demand
or a free supply. Refuse paused, disabled, unavailable or unposted supply.
Use only the existing reserve drain; never advance/catch up main recharge.
The actual debit must be representable, and bank gain plus reported loss
must equal that one paid debit. Floating-point rounding is conservative,
without an invented epsilon; if no paid gain can be represented, refuse
and publish neither value. Overflow also refuses.

## Existing contracts preserved

The current pulse profile remains cost8/heat18/warmup10/cooldown1.5, with
the existing actual fitted energy/F27 stage projection unchanged. The new
bank cost/rate/capacity/efficiency are mandatory caller terms; neither those
legacy constants nor proposed capacitor numbers enable a production profile.

Preserved2db943/adcd/6e174, existing outgoing main payment and incoming
self-hit accounting remain untouched. Later bank-mode integration must
replace the old direct-main outgoing debit, not add a bank debit beside it.
Incoming player splash must still debit actual main reserve independently.

## Acceptance and limits

Authored regression sources cover explicit/empty state, clipping/discard,
release refusal, modeled replay, strict value decoding, monotonic uncharged
time, finite shot counts, metered conservation, rate/headroom/capacity limits,
missing terms, pause/disable/stale refusal and floating-point no-mint cases.
All sixteen new methods/cases are UNRUN. No test registration or source group
was changed, and the old125/174 cohort remains immutable.

This is a parameterized state/staging leaf, not enabled gameplay. A stage,
snapshot match or Codable roundtrip is not charge/publication authority or
durable native replay protection. Actual item storage, native save/version
guards, writer rollback, purchase starting charge and fit/store/upgrade/hull
exchange persistence remain unimplemented owner joins, reserved through Root.
Qualified clock and admitted main headroom also need real owner producers.
Missing production terms must continue to refuse, not infer legacy generation.

No shared Game, inventory/codec, runtime/event owner, Tools, primary checkout,
compiler, helper, test, native, renderer, probe or CI action is authorized here.
G3 owns central Game; G1 owns integration/codec/qualification. Related handoff:
PR-emp-finite-bank-and-metered-transfer.md. No GitHub issue/PR number assigned.
