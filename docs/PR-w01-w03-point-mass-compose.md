# fix(missions): compose the reviewed Newt point-mass correction

## Composition

Apply the existing G3 `CurrentNewtGeometryComponent.swift` and `CurrentNewtGeometryQueryTests.swift` patch without edits on the exact `a104d01c` lineage. The docs-only main merge `0d8cc9eb` is included as the second parent; its 215 paths are all under `docs/meridian`. Earlier code and test evidence remains scoped to the old main. Both starting file hashes match G3's frozen inputs; both resulting hashes match its frozen outputs. Forward and reverse application checks pass. G3 retains ownership of the hunk. The original observer, borrowing correction, four W01/W03 selectors and all three passing test bodies are unchanged.

The source patch is `98023165`, source record `75baef47` and criteria `331367de`. Prior independent whole source/binding review `56a737b7` covers the exact correction. This composition requires its own G2 review before any native action.

## Behavior

Each component still passes `validForCurrentNewtQuery`, and component counts and identities must match. Mass comparison accepts exact equality to the expected authored component before using the unchanged positive-definite tolerance. It does not relax whole-body inertia validation. Collision/display presence, vertices, faces and display materials must still match. Source identity, occupied-cell custody, real encounter admission and save behavior remain unchanged.

The supplied focused test uses the real atmosphere declaration. It checks exact acceptance, nearby changed mass refusal, identical malformed mass refusal and substituted real collision mesh refusal. Its independent parity helper uses exact equality only for the declared zero-tensor point allocation and retains the original tolerance for other components.

## Evidence and remaining gates

The earlier `ca061ce8` image recorded two actual passes: the focused point-mass control and the ordinary Renas regression. The runner then failed its post-test seal. Reconciliation `9f7c18d6` preserves both facts; other geometry-suite consumers were outside that invocation. Reuse this scoped evidence without promoting it to a clean earlier job or to results on this composition.

The current W03 failure is sealed in observation proof `41a9be03`; prior three-case proof `5b93e636` and linked comparison `af9685fe` remain separate. The exact G3 files retain 101 and 75 strict formatter diagnostics, compared with 99 and 60 before its patch. Those 2 and 15 additional diagnostics are reported for the combined review; the reserved frozen hunk is not reformatted. The new combined candidate has not been built or run. Its exact four original methods must complete with strict console/XML, mapped helper/image, ownership and actual START audit evidence. The observer remains available for real failure evidence and changes no decisions.

Executable preparation retains all existing guards, leases, source checks, original/immediate-parent reviews and one-use Root admission. It additionally binds G3's source, patch, review, criteria, exact resulting files and limited native reconciliation. No further serial diagnostic is planned. Full CI, coverage, leak gates, protected merge, exact-main Sonar, player acceptance and release remain open.

Related issue: [W03 Newt atmosphere refusal](ISSUE-w01-w03-point-mass-compose.md).
