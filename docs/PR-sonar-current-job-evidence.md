<!-- markdownlint-disable MD013 -->
# fix(ci): consume current-job quality evidence before Sonar

Hosted main Sonar verifies the exact job's completed normal, leak and complete `make ci` evidence instead of starting a second fresh normal phase. Local Sonar retains its coverage command. A new immutable capture identity binds the existing owned job assignment to both phase identities; a completed receipt is issued only after aggregate success.

The consumer rechecks the real installed host/source/assignment authorization, current inputs and environment, reviewed profiles, Swift/SDK, executable hashes and UUIDs, complete XML inventory, coverage and phase output hashes. It refuses missing, changed, partial, ambiguous and cross-job evidence. Existing remote main and Previous version settings checks, exact commit projectVersion, native phase monitoring, resource budgets and protected merge checks remain in place.

Validation: 39 offline Python contract tests passed, plus shell syntax and Markdown lint. The hosted routing regression failed with the old Sonar entry point; the fixed bytes were restored and it passed. These checks use fake processes and the shell entry point. Fixtures exercise one normal and one leak execution followed by repeated consumption with no extra execution; changed job identity, source, environment, SDK, image and outputs refuse. Failed or missing aggregate and leak results refuse. No new native, sanitizer, coverage, leak, Sonar, integration or release result is claimed for this patch.

The original live main run and runner custody remain separate. A changed reviewed commit and its required checks are needed before a new authoritative run; existing phase results are not transferred to another job or commit.
