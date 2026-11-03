<!-- markdownlint-disable MD013 -->
# Hosted Sonar analysis repeats the complete normal test phase

In [the main quality run](https://github.com/stephenlclarke/l337/actions/runs/41610048074/attempts/2), the original `make ci` passed normal coverage, zero leaks and static checks. The main-only Sonar step then called `script/coverage.sh`. Hosted phase execution always creates a new monitored fresh cache, so this started another complete normal build and test run instead of using that job's completed evidence.

The first normal phase and leak result remain valid phase evidence. The second active phase and launcher expiry do not establish a scanner or workflow result. Preserve their actual outcomes and runner custody; do not raise the expiry, interrupt helpers, invent an attestation or retry an unchanged native run.

Bind each hosted phase to a fresh authenticated capture of that exact job's `make ci`. Publish a complete receipt only after the original aggregate, normal tests, coverage and leaks pass. Main Sonar must validate those same-job receipts, source and host identities, images, XML and coverage outputs without another test execution. Reject missing, changed, partial, ambiguous or cross-job evidence. Keep local Sonar coverage and all existing quality, authorization, resource and protected-merge requirements.
