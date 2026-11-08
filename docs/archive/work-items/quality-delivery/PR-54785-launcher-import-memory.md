# PR handoff: direct macOS executable entry point

## Resulting behavior

The L337 executable enters the existing L337App.main directly. Its MainActor isolation, async throwing signature, CLI branches and GUI lifecycle are unchanged. Package.swift declares L337Mac as the executable target; the redundant L337Launcher source and target are removed. The product and importable test module retain their existing names.

## Implementation and compatibility

This restores the entry structure used before the thin launcher was introduced. Keep L337App and main public so existing source clients retain access. SwiftPM supports test imports of executable targets on macOS and handles the renamed executable entry symbol separately from the test runner. Compiler-generated entry point arguments necessarily follow the changed target role; external flags, environment, memory and disk guards are unchanged. No custom calling convention, C bridge, task wrapper, library evolution flag or implementation-only import is added.

## Validation and risks

Source checks confirm that the only application source delta is the added main attribute. Every existing test source, registration, dependency and resource remains untouched. Author validation is source-only; no compiler, parser, native or probe execution was performed. The retained failure does not establish that removing the extra module import will put every later compile below the aggregate limit. G1 must build, link, discover and execute the original 198 methods on changed published main under the same operator and limits. Duplicate entry symbols, missing test imports, incomplete discovery, runtime assertion failures and resource refusals are failures. Existing CLI and renderer checks and make ci remain required before their respective acceptance claims. See [the observed issue](ISSUE-54785-launcher-import-memory.md).
