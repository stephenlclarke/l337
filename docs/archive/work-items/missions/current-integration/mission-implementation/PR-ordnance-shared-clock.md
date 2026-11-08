# Prepare native ordnance once and retain actual clock prefixes

## Motivation

The native shared clock needs the real existing missile path before moving the clock. A future Game, an assigned historical emission time or repeated target steering cannot stand in for that opening. See [the issue](ISSUE-ordnance-shared-clock.md).

## Callable boundary

1. `Game.prepareGameplayOrdnanceFrame(until:)` captures the actual active opening cohort with unique IDs/actors, original body/state, context, epoch and one guidance trajectory per projectile. It allocates nothing and changes no Game state. Invalid/stale openings refuse. Already ended/dead projectiles keep their existing cleanup owner outside the active cohort.
2. `GameplayOrdnanceOpening.state(at:)` samples the same prepared path at arbitrary attained times. Its `trajectory` retains the reviewed position/leg interface and original start-time arithmetic. Samples after finite expiry are unavailable. A zero-duration T1 opening is inert; it cannot borrow the preceding frame.
3. `Game.prepareGameplayOrdnanceSlice(_:until:)` reads the actual current prefix, samples the original guidance, updates only a local muzzle/state copy and calls the unchanged native nearest-contact owner on the actual T0 geometry. It returns the contact, proposed state and `attainedEnd`. Mission contacts use G1's genuine `preflightNativeMissionOrdnanceContact` with the retained original emission. The returned `eventCapacity` is accounting, not a reservation.
4. G1 selects the physical endpoint and aggregates actual capacity plans with other effects before advancing its real clock. A prepared first hit/expiry can shorten the interval. A positive-time target-loss cleanup retains its existing no-motion state and occurs at the chosen real endpoint.
5. `Game.retainPreparedGameplayOrdnance(_:activeECM:)` requires the matching actual state, body, actor, epoch and real clock at `attainedEnd`. It rejoins live native geometry and consumes only prepared motion through the original collision/effect loop. Accepted prefixes change their actual stored cursor or termination, so replay of that same slice refuses. An event-pressure retry may legitimately retain no motion and is reported separately.
6. The returned `GameplayOrdnanceRetention` contains the real `OrdnanceUpdate`, `motionRetained` and certificates from G1's actual combat or mission owner. `applying(to:)` replays those actual allocations from the exact opening and compares with the actual closing flight state; it never adopts closing counters. G1 must require both accepted motion and valid certificate replay for a completed leg.

Retention contains kernel partial mutations in a transaction at the already attained actual clock. Source and geometry preflight use the actual opening; only then does a same-clock candidate call the genuine owners. Invalid final flight, failed motion or an incomplete allocation chain discards the candidate and reports rejected motion with no published impact, counter, resource, message or ECM change. The candidate never supplies a future geometry/proof source. G1 separately stages its whole clock leg and must publish clock advancement only with accepted retention.

## Preserved owners

The original `advanceOrdnance` signature delegates to the same core with no preparation or allocation recorder. Its default branch retains the original move, muzzle, collision, practice, damage, event-pressure catch, projection, termination and safe-gunnery paths. The original motion implementation and collision/proof/damage methods remain byte-identical. The existing player/NPC missile launch and admission functions remain unchanged.

Only the existing ECM completion clause is extracted as `finishGameplayOrdnanceUpdate`. Both the original runtime and prepared retainer call that same clause, preserving `endedNow`, own-field attribution, destruction count and retaliation. Enemy ECM chance and activation stay in their original runtime position. Preparation and retention introduce no RNG draw.

## Actual G1 API dependencies

- `GameplayCombat.applyNativeCombatHit(_:origin:kind:damage:emissionPosition:)` returns the genuine accepted hit/destruction allocation chain.
- `NativeMissionImpact.applyNativeMissionOrdnanceImpact(_:)` invokes the original native proof/damage owner and returns its actual mission allocation certificate.
- `NativeMissionImpact.preflightNativeMissionOrdnanceContact(bodyID:state:contact:)` stages only the next incident for the real contact/original origin and uses the original damage/capacity policy.

The packet pins their actual authored source. It does not invent replacements or include edits to those owning files. Original native practice contact allocates no flight IDs and remains with its real practice owner.

## Remaining native integration limits

The read-only T0 query uses the current native query's static scene. It does not establish continuous collision against independently moving targets. Rechecking at the attained clock prevents a stale T0 prediction from authorizing a different hit, but it does not prove that two endpoint queries detected every intervening crossing. G1/G3 must join the sampled actual ordnance trajectory to the continuous physical first-hit owner and provide that owner's real selected contact at the shared-clock boundary. No caller-created contact, guessed sphere, whole future Game or disabled validation is an acceptable substitute. Until that join is implemented and tested, this remains a source candidate rather than complete shared-clock ordnance admission.

G1 must aggregate all returned event-capacity plans before the real clock when several effects share a boundary. If another effect fills the queue after preview, the original live owner still refuses and the retainer reports no accepted motion. Do not count that as a completed leg or force its old cursor forward. Newly born actors need an actual opening at their own birth clock. Culled/destroyed/invalid and ended-body cleanup remains with the existing termination owner.

The retainer currently consumes positive-time prefixes. An already overlapping T0 contact needs the genuine native zero-time contact/effect boundary; do not manufacture a positive-time motion or advance its clock to make a proof. Zero-duration T1 newborn slices deliberately retain no preceding motion. This boundary must be joined by G1/G3 before a complete native-admission claim.

## Validation

All new owning tests are authored and unrun. Source checks cover unchanged native motion/collision/proof/damage methods, launch/admission functions, exact enemy ECM and completion-clause preservation, closed payload scope, real-owner APIs and no clock/RNG/actor allocation in preparation or retention. Exact text replay and Markdownlint are recorded in the manifest. No compiler, native test, standalone test runner, renderer or project helper was executed.

New owning cases include ordinary/mission allocator-edge and ledger refusals after valid preflight, player fatal/nonfatal missile impacts and actual missile interception. These complement the new genuine mission destruction, full-queue preview/refusal and certificate mismatch checks. The unchanged mission-impact test file is an existing control, not evidence that these new wrappers or tests passed.

## Same-slice review correction

The successor to immutable 4ddaa905 replaces the retainer's timestamp-proximity success inference with an explicit result from the actual motion/effect owner. The owner sets advanced/terminal only after those real paths and marks every caught rollback refused. The original public `OrdnanceUpdate` interface is retained by projection; no native policy, motion math, error catch, damage or effect order changes. The same-clock transaction still requires valid actual state/flight and genuine accepted allocation replay.

The existing full-queue and late allocator/ledger cases now also exercise a real suffix between 1e-10 and 1e-8 seconds, reached by an accepted preceding prefix of the genuine first-hit trajectory. Original full-prefix assertions remain; tiny-prefix assertions compare the actual slice opening, not a fabricated historical cursor. The existing genuine mission destruction case now compares the original same-prefix event arrays/sequence identities, exactly one damaged and destroyed event for the actual actor/instance, unchanged event counts after duplicate refusal, and identical law/cash/kill/body/commander results. No separate leaf test was run.

The successor is a changed source/test candidate for the same whole review. The original packet stays immutable; continuous moving-target and zero-time source-query work remains a separate child.

## Compatibility policy

Current-format runtime work only. No save migration, historical reader, alias, source grant or compatibility path is added. No Game/tick/CurrentNewt integration is included. Required final review, CI and release gates remain unchanged.
