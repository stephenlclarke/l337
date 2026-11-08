# Reconcile retained mission corrections with current main

## Problem and resulting behavior

The four retained correction rows are not present in main `f1568bf6bd0464c8769cd22b4a87dea891772808`. This increment carries forward their reviewed behavior and existing meaningful tests as one current-base source change. It adds no mission-completion claim.

| Existing work row | Retained source | Result |
| --- | --- | --- |
| M-C23-CONSOLE-DRAFTS | Corrected draft writer `c987835e` and editor `80dcaada` | Persistent port/starboard player plans, explicit confirmation, typed painted input, writer rollback/retry and cold recall |
| M-F13-HULL-CANCELLATION | Cancellation `e50bcc39`, marker guidance `cce1ba56` and cold-library correction `a11c3b89` | Cancellation after a real hull exchange; exact unread-marker loss guidance; original-carrier requirement retained for successful reception |
| M-G05-OUTLOOK-MARKER-LOSS | `b75cb037` | Exact unread-marker loss guidance while preserving both passengers and requiring real care return |
| M-PLANS-OWNED-ENERGY | `9149046c` | Preserve paid energy hardware and its ownership records when awarding the Naval Energy Unit and 256 points once |

None of these rows was already integrated or superseded at the stated main commit. Their new test paths and the new editor/marker-loss source files were absent. The relevant mission-owned production paths matched their retained before-state; current shared files and the Plans resource required preservation of newer unrelated content.

## Implementation

The old source and test payloads are retained exactly where they apply. The C23 Game display getter is adapted to the current typed pointer-backed read accessor; its actor-owned editor session, snapshot refresh and key ingress remain narrow additions. Existing current Game and AppKit behavior stays in place. Only the approved three Plans changes are applied to its current TOML: reward description, debriefing text and removal of destructive Extra Energy Unit removal from the delivery action list.

The F13 marker-loss test includes the approved correction that installs its real source pack for cold recall. Historical handoff documents and ledger overlays are not restored. Current implementation notes are under `docs/meridian/missions/implementation`.

## Validation

- Reuse the existing independent source reviews and verified original packet hashes.
- Compare every retained production/test payload with its pinned source and current-main before-state.
- Check that the composed patch replays forward and backward exactly against the stated main tree.
- Check scoped Markdown and patch whitespace.
- Parse Plans TOML and verify that unrelated current data remains identical.

The seven retained test files contain 14 methods and 16 declared cases, including the native view test. They are uncompiled and unrun for this composition. No helper, compiler, game, geometry or renderer execution is performed in this reconciliation.

## Compatibility and risk

No save version, new authority factory, physical admission rule, reward amount, acquisition rule or equipment price is changed. Player planning labels remain non-authoritative. Missing physical and earned-helper prerequisites remain explicit. G1 owns execution and final shared integration; G3/G1 own the separate C03 composition.

## Linked work

See the [problem and gameplay requirements](ISSUE-retained-mission-corrections.md). Root's existing completion ledger and four work rows remain the sole assignment and acceptance records.
