# Store and validate the bank with the original EMP item

## Result

OwnedEquipmentItem now carries optional internal EMPBankState. Its original
public no-bank constructor and nine existing coding fields remain compatible.
Missing bank data stays absent; present data must be non-null, valid and
bound to the item's UUID and canonical EMP node. All three existing item
rebuilds retain the complete bank. The existing portable-transfer algorithm
therefore carries balance, clock and modeled release history with the module.

An internal explicit bank replacement uses the existing whole expected item,
revision/context validation and candidate mutation. Commander validation
rejects future bank clocks. A new purchase input accepts explicit bank state
only for the actual paid quote's reserved EMP item and current clock, while
retaining funds/history/fitting checks and rollback. Existing no-bank callers
retain their behavior. No production bank policy or runtime caller is added.

The current raw/pre22 EMP native-item guard rejects bank-key presence even
when null or attached to another node. Existing native save routing and
atomic writer remain; current item/Commander coding retains actual state.

## Evidence

Eight ownership tests and six native-codec tests are authored, all UNRUN.
They cover old fields/absence, strict malformed decode, fit/store/replacement,
stale and foreign inputs, original portable hull transfer, unrelated component
upgrade preservation, paid purchase, native cold load, checked-chunk corruption
with recomputed hashes, and actual writer-failure/hull-trade retry rollback.
No existing test or cohort was weakened or changed. Source inspection and
patch/hash/outside/inverse evidence are supplied by the frozen packet; they
do not replace compiler or test results. Independent review is pending.

## Limits

Bank value construction and inventory staging do not authorize main energy,
paid capacity upgrades, runtime release or durable publication. Actual item
and writer owners must still validate their complete transaction. The
historical release fixture tests serialization only, not real firing.

Optional bank storage does not detect wholesale field removal. G1 must
resolve bank-format requiredness/admission within the existing native family
before production enablement; this change chooses no new marker/version or
old-save migration policy. Approved initial charge, capacity/recharge terms,
paid upgrade catalogue and actual interval/headroom/event joins remain open.
No Game/EMP runtime/power/ScriptPersistence/Tools or new persistence system
is part of this scope. Existing outgoing/self-hit accounting and F27 stay.

Related issue: ISSUE-emp-module-bank-ownership.md. G1 alone integrates and
executes after main qualification/resource boundary and the M04 sequence;
actual main failure/full terminal priority remains. No feature/release claim.
