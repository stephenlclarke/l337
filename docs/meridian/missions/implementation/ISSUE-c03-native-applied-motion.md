# C03 native applied-motion evidence

## Problem

The native Newt path moves opening actors before `commitCurrentNewtNPCDecisions` commits their final intent and velocity. Those actors are excluded from the later legacy powered loop. The old C03 camera-then-powered witness therefore cannot describe their actual motion. A prepared path, copied endpoint or later intent commit cannot replace the missing applied phase.

`applyCurrentNewtNPCPaths` also runs on the predicted copy in `prepareCurrentNewtNativeSegment`. Capturing there would incorrectly promote prediction to observation. The actual publication boundary is `retainCurrentNewtNativeSegment` after its validated `self = retained` assignment.

## Required behavior

Capture the actual before-body set and published flight, bodies and celestials at that retention boundary. Retain captures only with the same candidate Game state; a discarded physical candidate must discard its capture too. Accept a chain only when the private native clock owner matches every capture to the exact accepted leg-opening object, accepted duration and retained state.

Use a distinct native record. Do not invent a late-powered or intermediate camera body for simultaneous native motion. Both the legacy record and native record can supply the existing inspection snapshot pair only after their respective sealers validate the complete original source and actual frame.

## Source and refusal boundaries

- The exact station-plus-originals scene gate is unchanged. An extra Newt body remains an unsupported opaque actor; it must not disappear from the proof.
- Genuine native segment capture without its accepted clock remains a missing phase. A different real clock with matching numeric endpoints remains insufficient.
- An actual native interval without the Game-owned outer frame remains insufficient. Tests must not increment `gameplayRevision` to manufacture that frame.
- Contact, stopped paths, births, ordnance effects, source changes and geometry changes remain refused for this observation contract.
- Native planning uses the actual current source route, and generic arrival is suppressed for C03 originals. The projected steering calculation remains preparation only.
- Four private ward, office, evidence-intake and resolution authorities remain unavailable. Motion evidence creates none of them and awards no unrelated stage, reward or clue.

## Ownership

Researcher owns the narrow `CurrentNewtNativeMotion.swift` retention/planning hunk and mission-owned capture, sealer, inspection consumer and tests. G1 owns Game, NPCFlight, Decision, Encounters, Admission, Persistence and CargoValidation. A separate Clock-owner proposal is required because only `CurrentNewtNativeClock.swift` can read its private accepted legs. The existing public final-clock and retained-scene checks alone do not expose exact leg-opening identity.

## Acceptance

Require real commissioned originals and actual native interval retention in chronology tests. Preparation must produce no capture. Omission, replay, another real clock, absence of a clock and an uninstalled route must refuse without changing actual physics. Keep the existing legacy tests and hard scene/missing-phase assertions unchanged. Actual Game-tick native dispatch, a qualified native cohort and full inspection/writer acceptance require G1 integration and execution.
