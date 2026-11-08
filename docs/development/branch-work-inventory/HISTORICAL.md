# Historical scope and reconciliation

The earlier audit is retained unchanged outside the shipping tree. It recorded20 live GitHub heads,854 checkout/ref rows and 352 distinct retained tips against main 0cc45. The two inspected paths are worktrees sharing one Git common directory:854 rows represented427 unique local/remote-tracking refs, read twice. They were not854 different branches or two independent clones.

The current inventory deduplicates the Git common directory, lists all 349 local heads,78 remote-tracking refs (one symbolic default alias), and 20 live server heads. These447 scoped ref rows resolve to354 distinct tips.352 unchanged tip comparisons use the prior exact-baseline proof. The advanced G1 tip 195eb is compared separately. The remote-only Dependabot tip 06a119 is inspected through GitHub without fetching; its complete tree is not locally inspected. All 353 locally available tips have source/commit evidence in this inventory.

Only `refs/heads/fix/m04-compact-showroom-quote` advanced since the prior ref snapshot: from 2dbc3f9666b6d14644cfcad969509c2ecb95ae62 to195ebc7f255d1b1c7278124bd222c5667d42dae6. The previous tip remains retained by its remote-tracking/server refs. No earlier tip disappeared from the combined tip set. See the exact snapshot changes and prior artifact paths/SHA-256 in [audit-metadata.json](audit-metadata.json).

Historical refs include local-only backups, previous mission/hull attempts, inactive remote-tracking pointers and release support. They are indexed as references, not automatically active shipping content or ready-to-merge work. The earlier seven-candidate semantic salvage review is reused only for exact matching tips; it is not generalized to neighboring branch names.

Useful work must remain reachable after any branch cleanup. In particular the obsolete local Redtail/Besra pointer can be removed only while its exact tracking pointer remains: main has identical full content, but the feature commit itself is not in main's squash ancestry. Do not prune that retained tracking ref or lose the audit's historical Git objects.

## Late active-tip update

At 2026-11-01T13:07:46.155988+00:00 only the checked-out G1 branch advanced again, from 195eb to0e937. The additional commit and four source/test/tool files are inspected and the current ref table is updated. The 195eb card remains as an explicitly historical observed tip; it is reachable through the current branch. Current coverage is still354 distinct current tips, with355 cards including that historical observation. Live20server heads and main 0cc45 did not change.
