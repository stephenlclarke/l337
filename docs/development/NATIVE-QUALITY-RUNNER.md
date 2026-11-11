# Physical native quality runner

The required `quality` check runs the complete `make ci` pipeline on the physical Apple Silicon Mac. The existing `elite-ci` runner stays inside its isolated VM for the maintained unit selection. Neither the VM label nor its guard is changed. The native renderer tests require a real Metal device, eight-sample rendering and a command queue; CPU fallback or a skipped hardware assertion does not qualify this check.

## Authorization and source

New reviewed policies for the active CI use exactly `jobs: [native_checks]` and both independently validated normal/leak resource profiles. The installer rejects that singleton role if either profile is missing or malformed. Historical full and sanitizer role sets remain manual-only options; CI does not request their proofs.

The physical runner uses the separate `elite-native` label and dedicated `~/Library/EliteNativeCI/native-runner` checkout. Ordinary preparation registers ephemerally, listens for one job and unregisters after that job. The retained runner 134 LaunchAgent has a separate reviewed handoff path described below. Only the repository owner's internal reviewed PR, main push or explicit branch dispatch is accepted. Forks, another actor, a different workflow/job, another head, forced main pushes and deleted branches fail closed.

Workflow routing is not the security boundary. Before registration, `Tools/CI/prepare_native_runner.py` copies the reviewed guard outside both the runner application and checkout, and writes an owned read-only policy pinning the exact approved head and compiler/SDK identities. The runner's own `.env` installs its pre-job hook. The hook validates immutable event metadata before any workflow step or checkout and publishes an exact-head attestation. A rejected hook fails the job; `continue-on-error` cannot override it. [GitHub's pre-job hook contract](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/run-scripts) describes this ordering and failure behavior.

The hook and its immutable authorization files live under `~/Library/EliteNativeAuthorization/<head>`, outside the runner and checkout. Actions dispatches the hook through a shell, so preparation refuses whitespace in that hook path. Normal step scripts are also dispatched through an unquoted upstream shell placeholder, so the dedicated runner installation/work root must be whitespace-free as well. Preparation rejects either unsupported path before mutation. Arguments inside the generated hook remain shell-quoted. Previous inactive `Application Support` installations are preserved for audit; they are not reused or deleted.

The workflow also routes untrusted events to a hosted runner and fails before checkout. Such failures or missing physical capacity remain failed or pending quality checks; they never count as a qualified pass. Checkout has read-only repository permissions and does not persist credentials. A second check validates the actual assigned checkout and confines the incremental cache to the dedicated owned workspace. The original required check name, coverage threshold, unfiltered normal tests, leak check and committed-main-only SonarQube analysis remain intact.

## Preparing one approved job

Use the reviewed clean commit and the verified SHA-256 of the official macOS ARM64 Actions runner release archive. Preparation requires Python 3.12 or later for safe archive extraction. Registration obtains a short-lived token through the existing authenticated `gh` session, captures configuration output without printing credentials, and passes no secret through the public workflow.

```sh
python3.12 Tools/CI/prepare_native_runner.py \
  --approved-head "$APPROVED_ELITE_HEAD" \
  --runner-archive "$VERIFIED_RUNNER_ARCHIVE" \
  --archive-sha256 "$VERIFIED_RUNNER_ARCHIVE_SHA256" \
  --register --run
```

Set repository variable `ELITE_NATIVE_RUNNER_ENABLED=true` only after the reviewed setup is ready. Use a source policy and ephemeral registration for each approved PR/main checkpoint. A prepare-only invocation can be followed by registration at the same approved head. Setup creates missing trust folders privately and rejects symlinks or group/world-writable trust folders. Reuse requires identical owned, immutable guard, hook and policy bytes, permissions and toolchain identities; the read-only installation marker is verified without being rewritten. Every installed archive file and link is checked against the verified archive before reuse; an ownership marker or recorded archive digest alone is insufficient. Preserve a previous registered runner instead of overwriting its active configuration. The source policy and guard are outside the checkout and cannot be removed by its clean step.

Keep the console session available for the existing AppKit window and actual-renderer assertions. Capability is established by those unchanged hard tests in the affected batch and full required run, not by hardware labels. Retain the exact source, toolchain, selector, XML when produced, terminal log, timing, GPU result and runtime diagnostics. A failure or unavailable capability remains a blocker.

## Current CI scope

Changes confined to `docs/meridian/**` use a hosted Python documentation-scope check and keep the required `quality` result without starting a game build or Swift unit build. The exact single README story-link insertion may accompany them; every other README change requires the build. The classifier reads the complete Git diff, including both sides of renames, and uses its trusted base version. Mixed changes, workflow/helper changes, missing history, classification errors and manual dispatch retain the full existing checks and exact-head native authorization. Use `make change-scope-check` for its offline Git and routing tests. The workflow change that introduces this route also requires full validation once. A documentation result does not claim native tests, coverage, leak or Sonar acceptance.

ASAN and TSAN are optional manual diagnostics. The active reusable workflow runs the real `make ci` command in its authorized `native_checks` job after the hosted fake checks. Normal tests, full inventory and coverage validation, zero leaks, static checks, raw runtime evidence and committed-main-only SonarQube analysis remain required. No sanitizer preparation, shard, local-proof verification or sanitizer-plan aggregate job is part of CI. Normal and leak phases require their own reviewed resource profiles and retain the existing shared executor lease, admission and RSS monitoring. New source and workflow bytes require fresh exact-head runner authorization; old policies and proof files are preserved as historical evidence.

## Ordinary ship-media generation

Use `make ships`, followed by `make ships-check`. The maintained generator owns a normal subprocess/session with shared controller/executor leases, fresh RAM/disk admission, one nonbatch compiler worker, sampled PID/start-lineage RSS, bounded output and timeout/cleanup. A routine metadata or renderer error returns failure after bounded cleanup; it does not write diagnostic custody, create MAX1 policies/journals, wait inertly or impose another approval layer. The external M01 asset wrappers are historical evidence only. Existing unresolved historical custody remains respected until its reviewed recovery. See [the focused correction and remaining OS limits](../archive/work-items/quality-delivery/PR-m01-asset-execution.md).

The per-probe freezes, complete historical-descendant proof and routine-reboot recovery were self-imposed asset coordination rules. They are superseded for ordinary assets by the human's simplification instruction. This does not change trusted GitHub event/head authorization, normal test inventory, coverage, zero leaks, required PR review/checks or main-only exact-SHA Sonar analysis.

## Optional local full-suite sanitizers

`make threads` runs `swift test --scratch-path .build/tsan --sanitize=thread`. `make address` runs `ASAN_OPTIONS=detect_leaks=0 swift test --scratch-path .build/asan --sanitize=address --no-parallel`. These are the original whole-suite commands from before sharding. `make threads-full` aliases the thread target. `make sanitizers` runs thread then address and stops on failure.

Both are off by default, including in hosted CI. Use `ELITE_SANITIZERS=1 make ci` to run both after the normal required checks locally, or invoke either standalone target on another Mac with Xcode selected. Standalone sanitizer targets do not use this physical runner's authorization, shard controller, checkpoints, policies, counters or proof bridge. They use the local Swift toolchain and separate scratch directories, with all tests and their existing concurrency/assertions. They do not reuse historical sanitizer proofs. ASan's original leak detection setting remains disabled because macOS leaks has its separate gate.

## Checkout cleanup and immutable phase evidence

The existing cleanup keeps only the root `.build/` cache and `reports/quality-phases/` evidence tree. Successful phase attempts contain read-only proof files and directories; they stay unchanged across the next checkout. Git still removes other ignored and untracked inputs, including unexpected source files and writable report outputs outside that exact phase path. This prevents a successful run's frozen proof from making the next guarded checkout fail with a permission error. It does not qualify old outcomes for another source revision or weaken source, authorization, coverage or leak checks.

## Retained service and stopped staging

The coupled lifecycle command preserves registration 134 and the existing LaunchAgent, credentials, vendor files, archive marker and resource policy. It requires a clean approved execution checkout, a new independently reviewed policy for the actual verified archive, the exact old expired exhausted idle session, a pinned whole-operation review, an explicit human decision and a fresh finite Root grant. The current retained human decision is NOT_GRANTED. Source preparation and fake tests grant no operational authority.

The immutable reviewed policy for this operation requires `"runner_lifecycle": "staged-service-handoff-v1"`. The field participates in the policy digest and installed contract. Every admission, authorization and checkout reader requires the complete stage, STARTED, ACTIVE, binding and ticket evidence for that policy. Missing or replaced records refuse. Policies without the field use the existing session contract. Ordinary registration and renewal reject a policy that requires this service lifecycle.

The operation has two explicit calls to the existing installer. Both use the same pinned plan, policy, archive, human decision and Root grant with all normal session flags. Add `--lifecycle stage` for the first call and `--lifecycle start` for the second. Each also requires all four `--stale-session-plan`, `--stale-session-plan-sha256`, `--stale-session-grant` and `--stale-session-grant-sha256` inputs. The command rejects `--run` and `--register` on these paths.

Stage takes the controller and shared executor leases, verifies the actual loaded service and process generation, runner identity, terminal old attempt, current PR refs and the completed attempt preceding the proposed rerun. It claims one stop operation before booting out only `gui/501/actions.runner.stephenlclarke-l337.elite-mbp-native`. It then requires the service to be absent, the same remote runner to be offline and idle, and all local runner processes to be absent. It preserves exact old ticket and environment bytes, verifies every installed archive member, installs the new pinned authorization package, replaces only the hook line in the environment and publishes STAGED last. The old ticket, binding and terminal state remain intact. Both exact ticket and environment snapshots are checked before bootstrap, before ticket replacement and before ACTIVE publication. Missing or altered snapshots refuse. STAGED grants no checkout or workload permission.

Start repeats the stopped, offline and local absence observations under both leases and verifies the staged environment and package. It claims one start operation before bootstrapping the same preserved plist. Its STARTED record binds the observed new service generation. GitHub dispatch remains a separate authorized action. A STARTED record records service startup, and the first actual hook establishes job admission.

The installed first hook takes both leases and verifies its own loaded path and digest, policy, hook, helpers, archive members, preserved inputs and loaded service generation. It checks the actual ACTIVE run, exact attempt, execution and PR source, actor and triggering actor, runner 134, assigned native job and finite single slot. It claims the slot once, writes the new binding and consumed running state, replaces the ticket and publishes ACTIVE last. Every admission, authorization and checkout reader requires a coherent ACTIVE receipt and ticket when the policy has a stage marker. A partial publication, expired input, changed identity, held lease or replay refuses and preserves its records.

The implementation does not mark a running slot terminal. Existing terminal evidence and a separately reviewed later disposition must establish completion. Interrupted or uncertain service operations retain their claims. They require operator review before any new operation.
