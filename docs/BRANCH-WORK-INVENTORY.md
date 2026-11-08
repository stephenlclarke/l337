# Branch work inventory

Audited 1 November 2026 against live main `0cc45dca928c7bae18a388fa775d7b53c6653d21`. This reference helps coders find existing work before starting a ledger item. It is not a second completion ledger and does not declare a campaign, hull or branch tested or finished.

## Start here

- [Work-item index](branch-work-inventory/WORK-ITEM-INDEX.md): look up a ledger key, canonical mission ID or hull ID, then follow the exact commit/path.
- [All branch refs](branch-work-inventory/REFS.md): every local, remote-tracking and live remote branch, with tip/date and one contents card per shared tip.
- [Machine-readable contents](branch-work-inventory/branches.json) and [all commit metadata](branch-work-inventory/commits.json).
- [Proposed cleanup](branch-work-inventory/CLEANUP.md) and [exact deletion/retain manifest](branch-work-inventory/cleanup-manifest.json).
- [Historical scope](branch-work-inventory/HISTORICAL.md) and [audit metadata/limits](branch-work-inventory/audit-metadata.json).

## Coverage

349 local branch heads and 78 remote-tracking refs (including one symbolic default pointer), plus 20 live GitHub branch heads, produce 447 scoped ref rows and 354 distinct tips.353 tips are locally available; one remote-only Dependabot change is read through GitHub without fetching.352 earlier exact-tip comparisons against unchanged main are reused. The active G1 tip is compared incrementally through 0e937 after a late ref recheck;195eb remains a historical observed card. There are 355 cards for 354 current tips plus that historical observation.

The inventory records 4,304 locally available branch-exclusive commits, two baseline/ancestor records and one remote-only commit. It extracts exact hunks for 743 recommended commits and source symbols/identities from 2,935 focused blobs. Every branch has a card with actual subjects, files, source identities, comparison evidence, dependencies and limits. These are source reviews, not new compile or gameplay results.

## How to use it

Find the work packet in the main [completion ledger](COMPLETION-LEDGER.md), then search the index. Read the exact source at the named commit and compare its listed hunks with current main. Keep useful partial implementations; do not blindly merge an older branch with unrelated history. Reconcile current original worlds, r3 hull/fitting, actor isolation, trusted mission events/rewards and the latest human rules before use.

A status describes the inspected work with its stated scope. `already-integrated-equivalent` means the important inspected files match main; only a separately documented whole-tree proof makes a cleanup candidate. `partially-integrated` means some inspected work matches and other parts differ or are missing. `useful-unintegrated` identifies actual source absent/different from main. `superseded` identifies a specific later replacement. `uncertain` needs owner semantic review. Branch names and squash ancestry never establish completion.

## Concrete mission reuse

- C01 stage 5: consult 03c670c822e5 (`feat/c01-timing-standard-wiring`) and its original timing-standard admission/state/pickup/save. It recovers actual 1 t standard while protecting the 8 kg recorder. Rebuild-lane and later stages remain unavailable.
- Isolation work: consult 4ac8334d2976 (`feature/native-isolation-provider`) for the actual parent/source/tool/work/return 970 CR/trusted-clue chain. The earlier 48db39be9386 parent bridge lacks receiving/payment and is superseded as the starting point.
- C03: consult 1b3afde09f for original source birth, seal and consent components. Inspection, laboratory, disposition and terminal work remain incomplete.
- C13 and the PLUGH decoder have opening-only branches. They are reusable entry work, not finished stories or a complete seven-step finale.

The exact cards and work-item entries give full SHAs and source paths. Narrative source IDs and executable definition IDs are separate fields and need explicit trusted joins. Original content replacement must include actual station render/collision/entry and separate source station/service bindings, not just names in a catalogue.

## Validation and cleanup

No checkout, fetch, ref/index/object/source write, compiler, native game, test, CI, renderer or repository helper ran. Existing test files, logs and commit claims are references only. Markdown and JSON/index checks validate this document packet, not the game.

The cleanup manifest proposes one exact-content duplicate local branch and no live remote deletion. Active worktrees/default/protected/release-support and uncertain or unique work remain. G1 rechecks each candidate immediately before ordinary non-force deletion and supplies the actual receipt. Main ledger status is unchanged by this inventory.

## Publication and current-state note

The tables above are an as-of audit against protected remote main `0cc45dca928c7bae18a388fa775d7b53c6653d21`, not a live replacement for Git or the completion ledger. At G1 publication, local human main is `bba862c558530ea2d40d634f84fbd490d9cc3401` (tree `52a8cfbc9ecfa493cfa240d8a0232e9125770490`), which differs from the audited baseline. G1 preserved it and made no equality or integration claim against that local work. Fresh network checks still identified the repository's protected live default main as 0cc45.

The bounded independent review verified payload integrity, joins, counts, links and cleanup evidence. It did not repeat every card's semantic review or independently recount the 64 canonical mission-source lookup claim; the 58 direct Cxx/Mxx keys have a different scope. The 745 unique recommendations comprise 743 branch-exclusive inspections and two baseline/ancestor references. Source inventory status does not grant gameplay, native or release acceptance.

The [actual cleanup receipt](branch-work-inventory/cleanup-execution.json) records the current checks and action. Snapshot tables keep their audited rows intact; consult that receipt and current Git before reusing or removing refs.
