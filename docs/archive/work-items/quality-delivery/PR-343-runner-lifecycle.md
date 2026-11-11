# Stage and admit the retained native runner

## Change

The existing installer now supports an exact stop/stage operation and a separate exact start operation under the same finite reviewed grant. The stopped stage preserves the old ticket and environment bytes and grants no workload authority. The actual installed hook verifies the new ACTIVE attempt and physical service before consuming its sole slot and publishing ACTIVE last.

The existing native job and checkout readers enforce the staged boundary from an explicit immutable policy field. They refuse missing or changed stage, STARTED or ACTIVE evidence after any partial publication. Exact old ticket and environment snapshots are checked before startup, ticket replacement and ACTIVE publication. Archive validation is shared between installation and hook admission. PR341 ACTIVE reuse keeps its existing entry point and focused tests.

## Validation

The packet records focused fake installer, admission and lifecycle results, source checks and exact patch replay. Tests use temporary homes, tiny archives and mocked service, process and GitHub observations. Regression controls cover deletion or replacement of stage evidence at every hook publication boundary and loss or modification of either historical snapshot. Restoring the previous two gate functions makes those new tests fail. The final operation must bind the adopted source and policy to fresh service and old-session generations before Root issues a grant.

## Scope

The source composition includes the three reviewed PR341 CI afterimages on current main, followed by the coupled lifecycle implementation and its documentation. Human operation decision 5094 remains NOT_GRANTED. Installation, service actions, dispatch and native execution remain pending their explicit authorizations and observations.
