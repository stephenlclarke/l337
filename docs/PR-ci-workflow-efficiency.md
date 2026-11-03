<!-- markdownlint-disable MD013 -->
# ci: reduce duplicate isolated-unit workflow runs

Automatic isolated units run on PRs to main and relevant main pushes. Feature branches use local make unit-ci or manual workflow dispatch. PR updates cancel older hosted isolated-unit runs. Existing runner/report/control checks run before toolchain/cache work.

Full native quality remains serialized and is not cancelled mid-run. No checks, tests, assertions, permissions, pinned actions, resource budgets, main-only Sonar restrictions or protected-merge requirements are removed.

Validation: actionlint; parsed-YAML comparison proves only push-branch selection, conditional cancellation and step order change; all original step bodies are identical. README documents the trigger and cancellation behavior. No runtime/native test result is claimed for a workflow-only patch.

Scope: isolated-unit workflow and README, with matching issue/PR notes. Production effect and measured time savings are pending protected integration and subsequent runs.
