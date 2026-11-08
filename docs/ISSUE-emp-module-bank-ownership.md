# Retain the finite bank on its actual physical EMP module

## Problem

The reviewed finite-bank leaf provides state and arithmetic but has no
physical item storage or native item-codec join. Fit/store and graded/repair
item rebuilds currently reconstruct the old fields. A separately constructed
bank value or value JSON roundtrip cannot establish actual ownership,
purchase payment, native persistence or durable release authority.

## Bounded change

Add one internal optional empBank to OwnedEquipmentItem. Keep the existing
public initializer and all nine old Codable fields. Old bank-absent records
remain unbanked; decode never initializes or fills them. Present bank fields
decode strictly, including rejecting null, invalid balances and foreign
module/node bindings. Empty balance remains valid.

Carry exact bank state through moved, graded replacement and repair copies.
Use the existing expected-item/revision/context mutation for explicit bank
replacement. The current portable hull-transfer path needs no source edit.
Commander equipment validity also checks bank time against its actual finite
physical clock. Existing old-item validation and transaction rollback stay.

Add an explicit initial-bank input to Commander purchase acceptance, binding
the real quote-reserved item ID, canonical EMP node and current clock. Reuse
the actual quote, funds, purchase history, fitting and candidate publication.
The old no-bank entry remains compatible; production Game callers and initial
charge policy are unchanged. No numeric balance value is installed.

Extend the existing raw/pre22 native EMP item guard to bank-key presence,
including null, in its native inventory paths. Existing EMP retained-feature
writer and Commander/inventory codecs carry the state; no new save framework,
pair, marker, version or global registry is introduced.

## Validation and remaining work

Fourteen new plain tests are authored and UNRUN. They include actual paid
quote acceptance, full expected-item rollback, real portable transfer,
current native save/cold load and writer-failure retry/hull-trade rollback.
Fixture bank values and modeled history are not approved production terms
or actual pulse/emission receipts. No compiler, discovery or test ran.

An optional field cannot detect wholesale removal from an old-compatible EMP
item. Bank-specific admission/requiredness for22+ native envelopes and older
binaries remains an explicit G1 codec prerequisite before production bank
enablement. Bank-absent old saves remain loadable without any created charge.
Actual bank purchase starting charge, capacity/rate/cost terms, paid upgrade
axes, qualified recharge intervals and atomic runtime release joins remain
unimplemented prerequisites. This batch does not complete the gameplay feature.

Scope: four production files, two new test files and paired notes under /tmp;
original eight logical source hunks plus Root's one-line inventory comment
addendum. No HullTransfer/Game/EMP runtime/power/ScriptPersistence/Tools edit.
Related handoff: PR-emp-module-bank-ownership.md. No issue number assigned.
