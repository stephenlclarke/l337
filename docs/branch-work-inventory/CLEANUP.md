# Proposed branch cleanup

This is a reviewable deletion manifest, not an execution receipt. The human authorized cleanup. G1 remains the sole maintained writer and executes only after an independent safe-boundary review. [cleanup-manifest.json](cleanup-manifest.json) lists every proposed deletion and every retained ref with reasons.

One local branch is a content-proven candidate: `feat/m04-redtail-besra` at 41c69b40876e0d5e233617b1b7401b9278de8434. Its entire raw Git tree is77663e7693e0a4325040216a6bcb375a3d2ca0e0, exactly the same as audited main 0cc45. It has no unique file content. It is not checked out in the captured worktree list and has an exact matching configured upstream. Retain `refs/remotes/origin/feat/m04-redtail-besra` at that exact tip so the original feature commits remain available to coders.

G1 must recheck exact tip, full-tree equality, upstream, worktrees, active sessions and protection before using ordinary `git branch -d feat/m04-redtail-besra`. If ordinary deletion refuses or any condition changed, retain it and record why. Do not force or bypass the refusal. No server branch currently exists under that name, so this is not a remote-server deletion.

No live remote deletion is proposed. Other branches contain useful or uncertain work, are active/default/protected/support refs, or lack complete redundancy proof. Thirteen local pointers duplicate live upstream tips, but the associated work is not proved fully integrated and remains retained. Age, name, ancestry and partial file equality are not deletion evidence.

After actual G1 execution, record before/after refs, command outcome and retained history in this manifest/index and the main ledger. Until then `executed` remains false. No source, artifact, worktree, tag or historical evidence is deleted by this inventory.

## Actual safe-boundary result

G1 deleted only the local pointer with ordinary `git branch -d feat/m04-redtail-besra`. The [execution receipt](cleanup-execution.json) records all before/after refs, current remote protection/default/support checks and active checkout checks. The exact `41c69b40876e0d5e233617b1b7401b9278de8434` remote-tracking history remains. No remote branch, tag, worktree, source or historical artifact was deleted. The fresh comparison baseline was the protected live remote default 0cc45; divergent local human main bba862 was preserved without an equivalence claim.
