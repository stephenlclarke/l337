# Signed macOS distribution

The published [L337 1.6.0 release](https://github.com/stephenlclarke/l337/releases/tag/v1.6.0) is built from qualified protected-main source `05b3cd499058b1d2b2b532dd79a1018fae61c1bc`. Its universal app supports Apple silicon and Intel on macOS 14 or later, with Developer ID signing, Apple Accepted notarization, a stapled ticket and Gatekeeper acceptance. The [delivery receipt](../evidence/M03-l337-1-6-public-release.json) separates actual source quality, package verification and anonymous fresh-download trust. Historical Elite downloads and later source-only proposals remain separate. Existing `ELITE_*` signing variables, notary profile names and physical runner directories remain operator compatibility interfaces.

New releases use one generated plan. On the exact clean, reviewed and quality-qualified protected-main source, `make release-plan` selects the highest actually published stable ancestor tag and calculates SemVer from all reachable non-merge Conventional Commits since that tag: `!` or a `BREAKING CHANGE:`/`BREAKING-CHANGE:` footer makes a major release, `feat` a minor release, and `fix`/`perf` a patch. The highest impact wins once per release. Other types, including documentation and chores, do not release by themselves. Invalid non-merge headers and existing calculated tags refuse. Actual merge commits are excluded to avoid counting their child commits twice; squash commits count as their actual conventional header/footer. Use Conventional Commit PR titles and merge subjects, preserving declared breaking changes. Existing history and published tags are not rewritten.

The plan records the exact source, published base tag/commit, complete classified commit inventory and its SHA-256. Packaging validates those recorded inputs rather than independently choosing a version. A branch-only `--preview` can show the calculation but cannot package or publish. Historical release tags may identify later artifact/documentation commits, as recorded below; new tags identify the exact protected-main executable source. SonarQube analysis remains separate and uses the exact main commit SHA, not the app's SemVer.

```sh
make release-plan
ELITE_NOTARY_PROFILE=elite-release make package-macos
make publish-release
make release-readme
make homebrew-cask ELITE_HOMEBREW_TAP=/path/to/homebrew-tap
```

Keep the generated `dist/release-plan.json` for this whole sequence. `make release` combines plan generation, packaging and publication; it does not merge a PR or waive quality/review gates. Do not pass a manually chosen version. The app bundle, ZIP names, checksum, signing manifest, release tag, README links and cask all consume the same plan. Each later delivery needs a plan from its own actual protected-main history; historical Elite plans cannot publish a new L337 product.

`make package-macos` builds a Release executable for Apple silicon and Intel, assembles `L337.app`, copies exact runtime resources and legal notices, signs with Developer ID Application, enables the hardened runtime and requests Apple's secure timestamp. New artifacts are written to ignored `dist/macos/`; existing historical tracked downloads remain intact. The bundle and signing manifest identify the plan's exact source commit, and the manifest binds the plan's SHA-256. No private signing keys or notarization credentials belong in Git. Set `ELITE_SIGNING_IDENTITY` to use another valid Developer ID Application identity.

Publication requires the exact current main source's successful quality/main-analysis check, verified signatures/notarization/Gatekeeper manifest, matching archive/checksum/plan and Apple's Accepted report. It creates the source-pinned tag and a draft, verifies every uploaded asset's identity, size and server SHA-256, then publishes. Partial failures leave no successful-publication receipt; matching drafts can resume without overwriting existing assets. README and Homebrew updates require the actual published tag and verified artifacts, and still go through the normal review/merge process. The authoritative plan is not regenerated for those consumers.

If a configured notarytool keychain profile is available, set `ELITE_NOTARY_PROFILE` before packaging. The workflow submits the signed ZIP, waits for Apple's decision, staples and validates the ticket, then requires Gatekeeper acceptance. Without a configured profile it still creates and validates the signed package, recording `notarized: false` and the actual Gatekeeper result. Developer ID signing and notarization are separate states; inspect the supplied manifest before distribution.

On the release Mac, the validated profile is `elite-release`. Its Apple account, team and app-specific password come from local secret files `APPLE_ID`, `DEVELOPER_TEAM_ID` and `APPLE_NOTARIZATION` under `~/.secrets/`; their contents remain outside Git and logs. Configure the profile securely before running a new committed build:

```sh
ELITE_NOTARY_PROFILE=elite-release make package-macos
```

The local `make run` workflow uses an ad hoc signed debug build. After publishing the signed ZIP and manifest, follow the [Homebrew release instructions](HOMEBREW.md) to synchronize and validate the cask.
