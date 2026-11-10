# Contracts caller stack pressure

## Problem

The reviewed `e51937f0` correction compiled and discovered all four original receiver tests. The actual run still failed with SIGBUS before any method completed. The matched W03 seed pickup opened Contracts through Rows, Review and Quote, then hit the stack guard on the first `scriptUnavailable` spill. The terminal is `b50c31e4`; its matched image, crash and source maps are retained in the external evidence packet.

The actual dispatcher fixed frame fell from 39,600 to 10,064 bytes. This did not close the failure. Linked instructions before the fault show two full Commander copy initializations in Rows, two in Review and three in Quote. These callers also reserve metadata-sized stack storage. The exact total of those dynamic reservations is unmeasured; fixed prologues alone do not establish whole-route stack usage.

## Required behavior

Read current commander and script storage synchronously and project only the values needed by the caller. Borrow the selected installed pack through validation. Keep the first matching digest, complete UI and native validation, predicate and refusal order, original source and entitlement rules, physical dock and receiver authority, payment, stock custody and current save behavior.

## Acceptance

Retain all four ordinary W01/W03 selectors and the preview regression. The changed source must compile, discover exactly those methods and complete all four with passing console and XML results. Refusal coverage must include missing provider, rejected first duplicate, missing stock, empty initial fuel and oversized cargo requirements. Actual receipts, once-only payment, writer rollback and the named seed custodian journey remain required.

One complete source and executable preparation packet receives independent review before any new native assignment. Reuse unaffected evidence and preserve both failed runs. Future linked frames, copy-site changes and savings require actual changed-image evidence. No unchanged retry, integration or player completion claim follows from source inspection.
