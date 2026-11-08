# Refuse contract declines without a bound writer

## Change and cause

GameRuntime.declineContract now requires a non-nil scriptPublisher before it invokes the existing scriptCommand action. An unbound runtime receives a writable-save instruction and preserves the retained offer. Bound actors retain the existing validation, real publication, rollback and status-only decline behavior. The method is synchronous within the actor, so there is no suspension between this check and the existing commit.

The concrete source gap is the existing public decline action, not the generic command engine. The Game extension in ScriptContractCore.swift permits an available retained main-station board offer to be declined using its station/revision facts. The actor's constructor removes live authority and its writer, but the main-board value checks still permit that action. ScriptTransactions' existing nil-publisher return then retains the already-mutated game. The narrow public guard closes that route without changing value-model callers, native physical commands or other transaction owners.

## Owning regression and criteria

OriginalContractDeclineWriterTests has one complete original main-board consumer. It uses the existing OriginalSealedDispatchFixture.runtime MAIN constructor and actual offer generator, requiring the native main receipt, valid main board, original available offer and no accepted instance. It does not invoke the newly changed secondary-source constructor, invent a board or grant source authority.

- An unbound actor reconstructed from that actual snapshot must retain the exact board and require durability. A detached value-model control confirms this is a genuinely eligible decline, rather than a refusal caused by unavailable content or stale terms. The public actor must throw MissionPackError and preserve its full commander, complete world value and original file bundle. Before this guard, source shows the public action can instead return success and keep a declined status in memory; this is a source-based regression expectation, not an executed negative-control result.
- The original bound actor must fail through its genuinely blocked writer and preserve the complete commander/world and file bundle. Restoring that same writer and retrying the same offer must produce exactly the previous commander with only its first offer's status changed to declined, retaining current main authority and no new mission instance.
- The actual versioned save must retain the declined contract, unchanged cash, cargo, equipment, paid history, native people and script state. An independent current-format reader with the real matching content must preserve those facts, bind its writer and leave the file bundle unchanged when loading without republication.
- Repeating the same decline after the cold read must refuse without changing the complete commander/world or committed files. No payment, deposit, package, clue, new offer or hidden authority is created.

Run that complete method through G1's existing execution lane after independent source review. Existing original main-board cache/decline and writer rollback tests provide relevant interaction criteria; reuse unaffected results and batch any necessary current qualification. This is not another M01 startup gate, a replacement for physical journey acceptance or a request for an isolated native probe.

## Source validation and integration

Base is 0677291cee48773467a9d9d150dc51f33d6d6364. The source record pins the exact production wrapper preimage/afterimage, new-file absences, regression, relevant main fixture/station/offer/durability/transaction/current reader sources and replayable four-path runtime delta. The older author checkout is not a replacement runtime: apply the production file as a surgical parent-relative hunk, and copy only the three new test/note files. FIRST was hash-pinned before tracked source mutation and is included in the same coherent commit.

Local checks are exact forward/inverse replay and new-path absence, unchanged production bytes outside the wrapper, preservation of the earlier frozen dispatch packet and other owner files, Markdown lint and whitespace. All compiler/native/test execution is UNRUN. Independent review and actual focused PASS remain required before integration readiness or gameplay completion is claimed. No public/testability API, save/schema change, compatibility path, native source, actor permission or transaction semantics is added.
