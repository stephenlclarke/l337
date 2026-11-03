<!-- markdownlint-disable MD013 -->
# Reduce duplicate isolated-unit workflow runs

Feature-branch pushes and pull-request updates currently start the same isolated-unit selection. Superseded PR runs continue, and cheap report/control failures are detected after toolchain and cache work.

Keep automatic unit checks on PRs to main and relevant main pushes, plus manual dispatch for other branches. Cancel only superseded PR isolated-unit runs, which use hosted macOS. Preserve self-hosted push/manual jobs and full native quality serialization. Run runner/report/control checks before cache restoration and unit execution.

The required quality name, exact-head authorization, complete normal coverage, leak checks, static gates, protected merge and committed-main Sonar policy remain required. The isolated selection is not equivalent to full quality coverage, so both checks remain.

Validation: actionlint and YAML semantic comparison; every existing step definition, permission, action pin, cache key, artifact, runner expression and timeout is retained. No live workflow or native job is cancelled for this change. Main deployment and required final-head checks remain pending until the change is merged.
