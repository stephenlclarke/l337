# Preserve the existing runner through exact next-attempt admission

## Problem

The existing runner 134 registration and LaunchAgent retain an expired terminal session. The reviewed PR341 reuse path requires an ACTIVE attempt and cannot stage a stopped runner before dispatch. PR343 supplies a coherent admission proposal, but its earlier archive policy names 2.338.1 while the installation matches every member of the verified official 2.338.2 archive.

## Required behavior

Preserve the existing service, credentials, vendor installation and historical session. Prepare the next exact attempt under both leases with an inert STAGED record. Permit the bounded stop and start only with the independently reviewed operation, explicit human decision and fresh Root grant. The actual first hook must verify the loaded source, service generation and ACTIVE job identity before any checkout or workload. Lifecycle admission must be required by the immutable reviewed policy. Missing stage or startup evidence cannot select the legacy admission path, and both old-generation snapshots must survive startup and ticket replacement.

## Acceptance

The focused fake tests must exercise the normal command paths and refuse wrong source, archive, actor, attempt, registration, service generation, hook, lease, expiry, partial publication and replay. The full source composition must retain the PR341 reviewed behavior. Actual service actions, dispatch and native qualification require their separate final authorization and evidence.
