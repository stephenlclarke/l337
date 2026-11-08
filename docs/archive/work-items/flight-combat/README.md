# Flight Combat: outstanding and unresolved work

272 retained records. These are current outstanding requirements or explicitly unresolved record-scope fix/integration cases. The existing archive path is a location only, not a completed-history label. Fixed and integrated records have been removed; use [Git history](https://github.com/stephenlclarke/l337/commits/952f0538687e8ffa77248e9ff876092f768c9a24/docs) and the [coverage/evidence table](../../../development/DOCUMENTATION-COVERAGE.csv) for removed records.

[Current work index](../../../milestones/WORK-ITEMS.md). Root’s [completion ledger](../../../COMPLETION-LEDGER.md) owns assignments and actual acceptance. Unknown is not done and does not assert a new defect or non-integration.

| Record | Status | Subject |
| --- | --- | --- |
| [ISSUE-actor-weapon-display-projection](ISSUE-actor-weapon-display-projection.md) | unresolved | Prepare weapon presentation before publishing runtime snapshots |
| [PR-actor-weapon-display-projection](PR-actor-weapon-display-projection.md) | unresolved | perf(cockpit): prepare weapon status in runtime snapshots |
| [ISSUE-alien-missile-relative-strength](ISSUE-alien-missile-relative-strength.md) | unresolved | Alien missiles must exceed standard speed and damage by 25% |
| [PR-alien-missile-relative-strength](PR-alien-missile-relative-strength.md) | unresolved | Correct alien missile damage relative to standard missiles |
| [ISSUE-alien-missile-service](ISSUE-alien-missile-service.md) | unresolved | Complete the physical alien seeker service loop |
| [PR-alien-missile-service](PR-alien-missile-service.md) | unresolved | Complete recovered alien drive and seeker routes |
| [ISSUE-alien-missile-silhouette](ISSUE-alien-missile-silhouette.md) | unresolved | Give alien missiles a distinct physical silhouette |
| [PR-alien-missile-silhouette](PR-alien-missile-silhouette.md) | unresolved | Draw alien seekers with a shared forked collision mesh |
| [ISSUE-alien-storage-legacy-normalization](ISSUE-alien-storage-legacy-normalization.md) | unresolved | Preserve original salvage evidence during alien-storage migration |
| [PR-alien-storage-legacy-normalization](PR-alien-storage-legacy-normalization.md) | unresolved | Add honest normalized legacy salvage records and conservation checks |
| [ISSUE-asteroid-contact-nil-frame](ISSUE-asteroid-contact-nil-frame.md) | unresolved | Nil contact steps reserve the nonempty planner's stack frame |
| [PR-asteroid-contact-nil-frame](PR-asteroid-contact-nil-frame.md) | unresolved | fix: enter asteroid contact planning only for a captured frame |
| [ISSUE-asteroid-rings](ISSUE-asteroid-rings.md) | unresolved | Add sparse asteroid rings with honest charts and finite ore sources |
| [PR-asteroid-rings](PR-asteroid-rings.md) | unresolved | Add deterministic sparse rings and conserved native-unit chunks |
| [ISSUE-asteroid-swept-impacts](ISSUE-asteroid-swept-impacts.md) | unresolved | Moving asteroid debris needs actual native impacts |
| [PR-asteroid-swept-impacts](PR-asteroid-swept-impacts.md) | unresolved | feat: add native swept debris contact core |
| [ISSUE-atomic-dock-preparation](ISSUE-atomic-dock-preparation.md) | unresolved | Atomic dock snapshot preparation |
| [PR-atomic-dock-preparation](PR-atomic-dock-preparation.md) | unresolved | fix: keep dock snapshot preparation atomic |
| [ISSUE-automated-release-version](ISSUE-automated-release-version.md) | unresolved | Automate source-bound release versions |
| [PR-automated-release-version](PR-automated-release-version.md) | unresolved | Derive release versions from Conventional Commits |
| [ISSUE-C01-surveyor-recorder](ISSUE-C01-surveyor-recorder.md) | unresolved | C01 stage three: recover the original surveyor recorder |
| [PR-C01-surveyor-recorder](PR-C01-surveyor-recorder.md) | unresolved | Recover Glass Meridian's original recorder at Navidor |
| [ISSUE-central-runtime-fixtures-021](ISSUE-central-runtime-fixtures-021.md) | unresolved | Distinguish migration, persistence and combat failures in the central gate |
| [PR-central-runtime-fixtures-021](PR-central-runtime-fixtures-021.md) | unresolved | Bind runtime regression assertions to their authoritative state |
| [ISSUE-compound-patrol-and-expiry-flight-fixtures](ISSUE-compound-patrol-and-expiry-flight-fixtures.md) | unresolved | Preserve real mission prerequisites in compound receipt and expiry fixtures |
| [PR-compound-patrol-and-expiry-flight-fixtures](PR-compound-patrol-and-expiry-flight-fixtures.md) | unresolved | Isolate compound receipt traffic and expose the first actual expiry-flight refusal |
| [ISSUE-CR-05-ecm-time](ISSUE-CR-05-ecm-time.md) | unresolved | CR-05: ECM duration changes with tick cadence |
| [PR-CR-05-ecm-time](PR-CR-05-ecm-time.md) | unresolved | CR-05: Use one elapsed-time ECM clock |
| [ISSUE-CR-09-mining-save-invariants](ISSUE-CR-09-mining-save-invariants.md) | unresolved | CR-09: Malformed mining state can enter saved commanders |
| [PR-CR-09-mining-save-invariants](PR-CR-09-mining-save-invariants.md) | unresolved | CR-09: Validate bounded mining persistence |
| [ISSUE-craft-aware-docking-cruise](ISSUE-craft-aware-docking-cruise.md) | unresolved | Use hull capability on the far station approach |
| [PR-craft-aware-docking-cruise](PR-craft-aware-docking-cruise.md) | unresolved | Use hull-aware cruise before station alignment |
| [ISSUE-critically-damped-work-approach](ISSUE-critically-damped-work-approach.md) | unresolved | Work approach retains inward momentum near an admitted hold point |
| [PR-critically-damped-work-approach](PR-critically-damped-work-approach.md) | unresolved | fix(flight): critically damp work approach velocity |
| [ISSUE-current-native-restore-fixtures](ISSUE-current-native-restore-fixtures.md) | unresolved | Current native save fixture admission |
| [PR-current-native-restore-fixtures](PR-current-native-restore-fixtures.md) | unresolved | Restore current audio and reward fixtures through their versioned save |
| [ISSUE-current-targeting-guide](ISSUE-current-targeting-guide.md) | unresolved | Targeting guide describes obsolete EMP behaviour |
| [PR-current-targeting-guide](PR-current-targeting-guide.md) | unresolved | Describe the current EMP charge and electrical effects |
| [ISSUE-current-wanted-save-bindings](ISSUE-current-wanted-save-bindings.md) | unresolved | Current wanted bindings were cleared late during save |
| [PR-current-wanted-save-bindings](PR-current-wanted-save-bindings.md) | unresolved | fix(wanted): align current career bindings with native scene boundaries |
| [ISSUE-economy-weighted-ring-presence](ISSUE-economy-weighted-ring-presence.md) | unresolved | Make industrial worlds more likely to have asteroid rings |
| [PR-economy-weighted-ring-presence](PR-economy-weighted-ring-presence.md) | unresolved | Weight new ring presence by economy and preserve recorded mining history |
| [ISSUE-emp-archive-phase-lifetimes](ISSUE-emp-archive-phase-lifetimes.md) | unresolved | EMP archive buffers overlap real crew-pod admission |
| [PR-emp-archive-phase-lifetimes](PR-emp-archive-phase-lifetimes.md) | unresolved | fix(emp): finish archive phases before crew admission |
| [ISSUE-emp-archive-stack](ISSUE-emp-archive-stack.md) | unresolved | EMP archive capture exhausts a cooperative thread stack |
| [PR-emp-archive-stack](PR-emp-archive-stack.md) | unresolved | Separate EMP archive capture lifetimes in nested saves |
| [ISSUE-emp-authoritative-test-timing](ISSUE-emp-authoritative-test-timing.md) | unresolved | Update older EMP regressions for electrical power and real charge timing |
| [PR-emp-authoritative-test-timing](PR-emp-authoritative-test-timing.md) | unresolved | Exercise older EMP regressions through the real charge and electrical boundary |
| [ISSUE-emp-boundary-station-phase](ISSUE-emp-boundary-station-phase.md) | unresolved | EMP unit boundary leaves native station spin behind its clock |
| [PR-emp-boundary-station-phase](PR-emp-boundary-station-phase.md) | unresolved | Project native station spin after the controlled EMP fixture clock step |
| [ISSUE-emp-capture-branches](ISSUE-emp-capture-branches.md) | unresolved | Nested EMP archive capture still exhausts the cooperative stack |
| [PR-emp-capture-branches](PR-emp-capture-branches.md) | unresolved | Separate archive reads and recovered, hull and pod capture frames |
| [ISSUE-emp-census-phases](ISSUE-emp-census-phases.md) | unresolved | Crew census temporaries overlap nested publication validation |
| [PR-emp-census-phases](PR-emp-census-phases.md) | unresolved | Separate source, receipt and crew census phase lifetimes |
| [ISSUE-emp-charge-outcome-diagnostics](ISSUE-emp-charge-outcome-diagnostics.md) | unresolved | Identify the charge stage in unresolved native EMP flight |
| [PR-emp-charge-outcome-diagnostics](PR-emp-charge-outcome-diagnostics.md) | unresolved | Observe actual EMP charge outcomes without changing native flight |
| [ISSUE-emp-disable-context-lifetime](ISSUE-emp-disable-context-lifetime.md) | unresolved | Physical context construction overlaps the EMP disable frame |
| [PR-emp-disable-context-lifetime](PR-emp-disable-context-lifetime.md) | unresolved | fix(emp): build the victim context before disablement |
| [ISSUE-emp-disable-phase-lifetimes](ISSUE-emp-disable-phase-lifetimes.md) | unresolved | Source custody overlaps completed EMP preflight and future record buffers |
| [PR-emp-disable-phase-lifetimes](PR-emp-disable-phase-lifetimes.md) | unresolved | fix(emp): separate preflight custody and record phases |
| [ISSUE-emp-disable-transition-lifetime](ISSUE-emp-disable-transition-lifetime.md) | unresolved | EMP zero-power admission retains the pulse-application stack frame |
| [PR-emp-disable-transition-lifetime](PR-emp-disable-transition-lifetime.md) | unresolved | Unwind pulse application before the real EMP disable transition |
| [ISSUE-emp-electrical-lifecycle](ISSUE-emp-electrical-lifecycle.md) | unresolved | Preserve live ships through charged electrical EMP effects |
| [PR-emp-electrical-lifecycle](PR-emp-electrical-lifecycle.md) | unresolved | Charge EMP pulses and retain current electrical recovery state |
| [ISSUE-emp-first-save-refusal-facts](ISSUE-emp-first-save-refusal-facts.md) | unresolved | EMP timer regression first-save refusal |
| [PR-emp-first-save-refusal-facts](PR-emp-first-save-refusal-facts.md) | unresolved | Record bounded facts after the actual EMP first-save failure |
| [ISSUE-emp-manual-fire-interruption](ISSUE-emp-manual-fire-interruption.md) | unresolved | Incoming damage incorrectly latches manual EMP firing |
| [PR-emp-manual-fire-interruption](PR-emp-manual-fire-interruption.md) | unresolved | Keep manual EMP firing available under incoming damage |
| [ISSUE-emp-native-boundary-regressions](ISSUE-emp-native-boundary-regressions.md) | unresolved | EMP acceptance needs real travel and assigned station police |
| [PR-emp-native-boundary-regressions](PR-emp-native-boundary-regressions.md) | unresolved | Exercise EMP through actual travel and security boundaries |
| [ISSUE-emp-native-flight-diagnostics](ISSUE-emp-native-flight-diagnostics.md) | unresolved | Identify the actual native EMP flight termination |
| [PR-emp-native-flight-diagnostics](PR-emp-native-flight-diagnostics.md) | unresolved | Record failure-only state at the native EMP flight boundary |
| [ISSUE-emp-pirate-blaster](ISSUE-emp-pirate-blaster.md) | unresolved | EMP disablement, occupied crew custody and shared target colours |
| [PR-emp-pirate-blaster](PR-emp-pirate-blaster.md) | unresolved | Add EMP Pirate Blaster, finite crew custody and target cues |
| [ISSUE-emp-post-pulse-assertions](ISSUE-emp-post-pulse-assertions.md) | unresolved | Native NPC hull aim and EMP acceptance |
| [PR-emp-post-pulse-assertions](PR-emp-post-pulse-assertions.md) | unresolved | fix: aim native NPC beams at the actual player hull |
| [ISSUE-emp-publication-lifetimes](ISSUE-emp-publication-lifetimes.md) | unresolved | EMP final validation retains discharge and capture workspaces |
| [PR-emp-publication-lifetimes](PR-emp-publication-lifetimes.md) | unresolved | Finish EMP candidate effects before custody publication validation |
| [ISSUE-emp-pulse-profile](ISSUE-emp-pulse-profile.md) | unresolved | One authoritative fitted-energy EMP profile |
| [PR-emp-pulse-profile](PR-emp-pulse-profile.md) | unresolved | Resolve future EMP balance from the actual fitted energy grade |
| [ISSUE-emp-travel-recovery-policy](ISSUE-emp-travel-recovery-policy.md) | unresolved | Native EMP travel assertions reach later failures |
| [PR-emp-travel-recovery-policy](PR-emp-travel-recovery-policy.md) | unresolved | State native catalogue and recovery expectations at the actual deadline |
| [ISSUE-emp-travel-threat-evidence](ISSUE-emp-travel-threat-evidence.md) | unresolved | Identify retained attackers at the original Cobra travel failure |
| [PR-emp-travel-threat-evidence](PR-emp-travel-threat-evidence.md) | unresolved | Report bounded retained threats without changing the flight scenario |
| [ISSUE-emp-validation-stack](ISSUE-emp-validation-stack.md) | unresolved | Cumulative EMP validation frames exhaust a nested timer save stack |
| [PR-emp-validation-stack](PR-emp-validation-stack.md) | unresolved | End EMP mutation and branch temporaries before nested validation |
| [ISSUE-emp-weapon-disablement](ISSUE-emp-weapon-disablement.md) | unresolved | EMP-disabled ships must stop firing and turn orange immediately |
| [PR-emp-weapon-disablement](PR-emp-weapon-disablement.md) | unresolved | Disable future weapons and show occupied EMP hulls in orange |
| [ISSUE-empty-npc-docking-state](ISSUE-empty-npc-docking-state.md) | unresolved | Docking materializes an absent NPC ledger |
| [PR-empty-npc-docking-state](PR-empty-npc-docking-state.md) | unresolved | Clear docking bindings only when NPCs are retained |
| [ISSUE-fixed-weapon-text-size](ISSUE-fixed-weapon-text-size.md) | unresolved | Weapon status grows with window width |
| [PR-fixed-weapon-text-size](PR-fixed-weapon-text-size.md) | unresolved | fix(ui): keep cockpit weapon text at the shared logical size |
| [ISSUE-freight-pure-preflight-work](ISSUE-freight-pure-preflight-work.md) | unresolved | Avoid repeated pure work during native freight flight |
| [PR-freight-pure-preflight-work](PR-freight-pure-preflight-work.md) | unresolved | Skip impossible rescue validation and reuse freight route systems |
| [ISSUE-gameplay-beam-damage-lifetimes](ISSUE-gameplay-beam-damage-lifetimes.md) | unresolved | Bound the gameplay NPC beam and shared player-hit lifetimes |
| [PR-gameplay-beam-damage-lifetimes](PR-gameplay-beam-damage-lifetimes.md) | unresolved | Separate gameplay NPC preparation and fatal-only player diagnostics |
| [ISSUE-government-encounter-dispositions](ISSUE-government-encounter-dispositions.md) | unresolved | Apply government hostility and anarchy wanted rates per generated ship |
| [PR-government-encounter-dispositions](PR-government-encounter-dispositions.md) | unresolved | Sample ordinary ambient hostility from one government table |
| [ISSUE-history-redock-defended-pilot](ISSUE-history-redock-defended-pilot.md) | unresolved | Generate historical arrival proof with the existing defended pilot |
| [PR-history-redock-defended-pilot](PR-history-redock-defended-pilot.md) | unresolved | Use the existing survival-aware pilot for the final history redock |
| [ISSUE-hosted399-collision-boundaries](ISSUE-hosted399-collision-boundaries.md) | unresolved | Component geometry measurement must target the selected hull |
| [PR-hosted399-collision-boundaries](PR-hosted399-collision-boundaries.md) | unresolved | test: scope component geometry measurements to the selected target |
| [ISSUE-hosted510-native-docking-frames](ISSUE-hosted510-native-docking-frames.md) | unresolved | Three docking fixtures detach visible geometry from native station authority |
| [PR-hosted510-native-docking-frames](PR-hosted510-native-docking-frames.md) | unresolved | test: retain native station sources in docking fixtures |
| [ISSUE-hostile-docking-acceptance](ISSUE-hostile-docking-acceptance.md) | unresolved | Sustained hostile-pressure docking lacks an end-to-end acceptance result |
| [PR-hostile-docking-acceptance](PR-hostile-docking-acceptance.md) | unresolved | test(docking): require live docking after observed native hostile pressure |
| [ISSUE-identified-salvage-alias-stack](ISSUE-identified-salvage-alias-stack.md) | unresolved | Captured stack exhaustion in identified-salvage alias lookup |
| [PR-identified-salvage-alias-stack](PR-identified-salvage-alias-stack.md) | unresolved | fix(game): borrow state for identified salvage aliases |
| [ISSUE-identified-salvage-facts-borrow](ISSUE-identified-salvage-facts-borrow.md) | unresolved | Borrow identified salvage selection facts after alias eligibility |
| [PR-identified-salvage-facts-borrow](PR-identified-salvage-facts-borrow.md) | unresolved | Borrow identified salvage facts behind exact alias eligibility |
| [ISSUE-idle-flight-trigger-interruption](ISSUE-idle-flight-trigger-interruption.md) | unresolved | Idle control changes create a held-fire stop |
| [PR-idle-flight-trigger-interruption](PR-idle-flight-trigger-interruption.md) | unresolved | fix(controls): avoid inventing held-fire stops during idle changes |
| [ISSUE-initial-main-station-docking](ISSUE-initial-main-station-docking.md) | unresolved | Initial SH025 main-station docking at native frame steps |
| [PR-initial-main-station-docking](PR-initial-main-station-docking.md) | unresolved | Refine a failed initial main-station hull proof |
| [ISSUE-legacy-npc-intent](ISSUE-legacy-npc-intent.md) | unresolved | Ordinary legacy attacks can outlive their player-directed intention |
| [PR-legacy-npc-intent](PR-legacy-npc-intent.md) | unresolved | Fix ordinary legacy player pursuit and retaliation targeting |
| [ISSUE-M02.P05-status-dock-context](ISSUE-M02.P05-status-dock-context.md) | unresolved | M02.P05.status-dock-context: truthful Status location |
| [PR-M02.P05-status-dock-context](PR-M02.P05-status-dock-context.md) | unresolved | M02.P05.status-dock-context: Status follows actual docking state |
| [ISSUE-mining-ore-supported-fixture](ISSUE-mining-ore-supported-fixture.md) | unresolved | Ore-motion fixture inherits a hull without its required mining utility |
| [PR-mining-ore-supported-fixture](PR-mining-ore-supported-fixture.md) | unresolved | test(mining): use a supported initial hull in ore-motion fixtures |
| [ISSUE-mining-work-tool-fixture](ISSUE-mining-work-tool-fixture.md) | unresolved | Mining fixture initializes hardware after canonical inventory exists |
| [PR-mining-work-tool-fixture](PR-mining-work-tool-fixture.md) | unresolved | Initialize the original mining fixture before native launch |
| [ISSUE-most-wanted-board](ISSUE-most-wanted-board.md) | unresolved | FR-035: usable Top 10 Wanted in station gossip |
| [PR-most-wanted-board](PR-most-wanted-board.md) | unresolved | feat(wanted): add persisted Top 10 Wanted careers and station gossip board |
| [ISSUE-mounted-laser-test-boundary](ISSUE-mounted-laser-test-boundary.md) | unresolved | Mounted-laser equipment test uses an obsolete Return route |
| [PR-mounted-laser-test-boundary](PR-mounted-laser-test-boundary.md) | unresolved | test(weapons): separate mounted damage from selected-tool input |
| [ISSUE-native-combat-system-projection](ISSUE-native-combat-system-projection.md) | unresolved | Bound the commander projection on the native combat stack |
| [PR-native-combat-system-projection](PR-native-combat-system-projection.md) | unresolved | Reuse the borrowed system projection during native combat |
| [ISSUE-native-emp-persistence-and-full-stock](ISSUE-native-emp-persistence-and-full-stock.md) | unresolved | Preserve native EMP coverage with explicit persistence preconditions |
| [PR-native-emp-persistence-and-full-stock](PR-native-emp-persistence-and-full-stock.md) | unresolved | test(emp): pair controlled persistence with full-stock disable coverage |
| [ISSUE-native-emp-real-charge-timeline](ISSUE-native-emp-real-charge-timeline.md) | unresolved | Exercise the current EMP timeline through actual native input |
| [PR-native-emp-real-charge-timeline](PR-native-emp-real-charge-timeline.md) | unresolved | Drive actual native EMP charging and saved crew ejection |
| [ISSUE-native-flight-control-authority](ISSUE-native-flight-control-authority.md) | unresolved | Shared flight controls and live weapon status |
| [PR-native-flight-control-authority](PR-native-flight-control-authority.md) | unresolved | fix(controls): use shared flight bindings and interrupt held weapon actions |
| [ISSUE-native-flight-versioned-save-fixture](ISSUE-native-flight-versioned-save-fixture.md) | unresolved | Ordinary save compatibility must distinguish native flight authority |
| [PR-native-flight-versioned-save-fixture](PR-native-flight-versioned-save-fixture.md) | unresolved | test(save): distinguish ordinary JSON from native flight storage |
| [ISSUE-native-identified-salvage](ISSUE-native-identified-salvage.md) | unresolved | Identified salvage owner return |
| [PR-native-identified-salvage](PR-native-identified-salvage.md) | unresolved | feat: add identified salvage owner returns |
| [ISSUE-native-ore-release](ISSUE-native-ore-release.md) | unresolved | Fresh ore overlap and premature recovery completion |
| [PR-native-ore-release](PR-native-ore-release.md) | unresolved | fix(mining): separate fresh ore births and wait for pending admission |
| [ISSUE-native-ore-spin](ISSUE-native-ore-spin.md) | unresolved | Native ore acquires legacy display spin during automatic selection |
| [PR-native-ore-spin](PR-native-ore-spin.md) | unresolved | fix(physics): honor native ore angular motion at admission |
| [ISSUE-native-paged-wreck-cutting](ISSUE-native-paged-wreck-cutting.md) | unresolved | Native wreck inspection and cutting still use ordinary lifetime pools |
| [PR-native-paged-wreck-cutting](PR-native-paged-wreck-cutting.md) | unresolved | Native paged wrecks and original cutting cycles |
| [ISSUE-native-work-hold-selection](ISSUE-native-work-hold-selection.md) | unresolved | Physical hold selection and extraction permission |
| [PR-native-work-hold-selection](PR-native-work-hold-selection.md) | unresolved | fix(targeting): separate physical holds from extraction permissions |
| [ISSUE-native-work-progress-trace](ISSUE-native-work-progress-trace.md) | unresolved | Native multi-batch work progress is unknown after timeout |
| [PR-native-work-progress-trace](PR-native-work-progress-trace.md) | unresolved | test(salvage): trace bounded native work progress on request |
| [ISSUE-native-work-sweep-result-trace](ISSUE-native-work-sweep-result-trace.md) | unresolved | The native hold is blocked without a retained clearance result |
| [PR-native-work-sweep-result-trace](PR-native-work-sweep-result-trace.md) | unresolved | Historical diagnostic: the existing refused work sweep result |
| [ISSUE-native-work-versioned-fixture](ISSUE-native-work-versioned-fixture.md) | unresolved | Native work fixture must load a genuine versioned scene |
| [PR-native-work-versioned-fixture](PR-native-work-versioned-fixture.md) | unresolved | test(ui): load a genuine versioned native work fixture |
| [ISSUE-154-npc-missile-identity-fixture](ISSUE-154-npc-missile-identity-fixture.md) | unresolved | NPC missile test must follow its original actor identity |
| [PR-154-npc-missile-identity-fixture](PR-154-npc-missile-identity-fixture.md) | unresolved | Track exact NPC missile and launcher identities |
| [ISSUE-npc-mounted-beam-ray](ISSUE-npc-mounted-beam-ray.md) | unresolved | NPC front beams track target centres inside the acquisition cone |
| [PR-npc-mounted-beam-ray](PR-npc-mounted-beam-ray.md) | unresolved | fix: fire NPC front beams along their mounted axis |
| [ISSUE-oblique-work-clearance](ISSUE-oblique-work-clearance.md) | unresolved | Oblique stand-off can request an endpoint inside its required hull gap |
| [PR-oblique-work-clearance](PR-oblique-work-clearance.md) | unresolved | fix(flight): validate oblique work endpoints before compensating stand-off |
| [ISSUE-ordnance-classic-fixture](ISSUE-ordnance-classic-fixture.md) | unresolved | Declare the classic ordnance test baseline |
| [PR-ordnance-classic-fixture](PR-ordnance-classic-fixture.md) | unresolved | Declare the classic ordnance test baseline |
| [ISSUE-original-gazelle-explorer](ISSUE-original-gazelle-explorer.md) | unresolved | M04.P02.H019 and M04.H019.runtime: Gazelle Explorer |
| [PR-original-gazelle-explorer](PR-original-gazelle-explorer.md) | unresolved | feat(fleet): bind original Gazelle Explorer leisure hull |
| [ISSUE-original-sparrowhawk](ISSUE-original-sparrowhawk.md) | unresolved | M04.P02.H030 and M04.H030.runtime: Sparrowhawk |
| [PR-original-sparrowhawk](PR-original-sparrowhawk.md) | unresolved | feat(fleet): bind original Sparrowhawk bounty-hunter hull |
| [ISSUE-phase-anchored-frame-cadence](ISSUE-phase-anchored-frame-cadence.md) | unresolved | Frame deadline drift after late wakes |
| [PR-phase-anchored-frame-cadence](PR-phase-anchored-frame-cadence.md) | unresolved | fix(frames): preserve deadline phase across late wakes |
| [ISSUE-physical-asteroid-fragments](ISSUE-physical-asteroid-fragments.md) | unresolved | Preserve physical mass after ordinary asteroid breakup |
| [PR-physical-asteroid-fragments](PR-physical-asteroid-fragments.md) | unresolved | feat: retain asteroid breakup mass and finite salvage |
| [ISSUE-plasma-preflight-lifetimes](ISSUE-plasma-preflight-lifetimes.md) | unresolved | Plasma readiness and preflight retain earlier Game buffers |
| [PR-plasma-preflight-lifetimes](PR-plasma-preflight-lifetimes.md) | unresolved | refactor(combat): narrow plasma preflight lifetimes |
| [ISSUE-pledge-preflight-lifetime](ISSUE-pledge-preflight-lifetime.md) | unresolved | Pledge preview still runs inside the job-admission preparation frame |
| [PR-pledge-preflight-lifetime](PR-pledge-preflight-lifetime.md) | unresolved | fix(pledges): finish preflight before preparing admission buffers |
| [ISSUE-recovered-flight-save-fixture](ISSUE-recovered-flight-save-fixture.md) | unresolved | Recovered flight mutation needs its genuine durable writer |
| [PR-recovered-flight-save-fixture](PR-recovered-flight-save-fixture.md) | unresolved | test: bind recovered flight transaction to durable storage |
| [ISSUE-refused-hot-work-control-state](ISSUE-refused-hot-work-control-state.md) | unresolved | Stop-state momentum and refused hot-work advance |
| [PR-refused-hot-work-control-state](PR-refused-hot-work-control-state.md) | unresolved | fix(controls): admit stopped work before actor advance |
| [ISSUE-regular-ore-motion-clock](ISSUE-regular-ore-motion-clock.md) | unresolved | Retain physical motion while ordinary ore awaits admission |
| [PR-regular-ore-motion-clock](PR-regular-ore-motion-clock.md) | unresolved | fix(mining): advance ordinary pending ore from timed snapshots |
| [ISSUE-residual-current-save-restore](ISSUE-residual-current-save-restore.md) | unresolved | Restore current work fixtures through their versioned save boundary |
| [PR-residual-current-save-restore](PR-residual-current-save-restore.md) | unresolved | test(work): restore residual boundaries through current saves |
| [ISSUE-retaliation-owned-ammo-fixture](ISSUE-retaliation-owned-ammo-fixture.md) | unresolved | Unlimited retaliation fixture disagrees with owned ammunition |
| [PR-retaliation-owned-ammo-fixture](PR-retaliation-owned-ammo-fixture.md) | unresolved | test: establish valid empty ammunition for unlimited retaliation |
| [ISSUE-route-score-overflow](ISSUE-route-score-overflow.md) | unresolved | Score supported large market quantities without integer overflow |
| [PR-route-score-overflow](PR-route-score-overflow.md) | unresolved | Accumulate actual route scores in their final floating-point domain |
| [ISSUE-safe-gunnery-lesson](ISSUE-safe-gunnery-lesson.md) | unresolved | T02.P01.lesson: native safe gunnery at Avenor |
| [PR-safe-gunnery-lesson](PR-safe-gunnery-lesson.md) | unresolved | T02.P01.lesson: consent, native hits, ceasefire and reception |
| [ISSUE-salvage-engagement-oracle](ISSUE-salvage-engagement-oracle.md) | unresolved | Salvage acquisition fixture assumes an idle trigger must be suspended |
| [PR-salvage-engagement-oracle](PR-salvage-engagement-oracle.md) | unresolved | Verify exact held-fire interruption state after genuine Tab acquisition |
| [ISSUE-salvage-native-cycle-export](ISSUE-salvage-native-cycle-export.md) | unresolved | Preserve original section cycles and seal native exports |
| [PR-salvage-native-cycle-export](PR-salvage-native-cycle-export.md) | unresolved | Share native section cycles and seal original exports |
| [ISSUE-salvage-persistence-caller-lifetime](ISSUE-salvage-persistence-caller-lifetime.md) | unresolved | Salvage persistence ancestor of EMP archive capture |
| [PR-salvage-persistence-caller-lifetime](PR-salvage-persistence-caller-lifetime.md) | unresolved | fix(salvage): separate post-EMP observation frame from archive capture |
| [ISSUE-salvage-pose-no-op](ISSUE-salvage-pose-no-op.md) | unresolved | Preserve absent salvage state during a no-op capture |
| [PR-salvage-pose-no-op](PR-salvage-pose-no-op.md) | unresolved | Avoid publishing unchanged salvage pose state |
| [ISSUE-salvage-save-binding-expectations](ISSUE-salvage-save-binding-expectations.md) | unresolved | Native salvage save expectations omit wanted and station binding phases |
| [PR-salvage-save-binding-expectations](PR-salvage-save-binding-expectations.md) | unresolved | test: retain native salvage disk and cold binding expectations |
| [ISSUE-salvage-versioned-save-fixture](ISSUE-salvage-versioned-save-fixture.md) | unresolved | Salvage fixture must reserve its wreck ID and read the actual save format |
| [PR-salvage-versioned-save-fixture](PR-salvage-versioned-save-fixture.md) | unresolved | test(salvage): reserve fixture identity and read versioned save |
| [ISSUE-shared-target-bindings](ISSUE-shared-target-bindings.md) | unresolved | Shared flight target bindings |
| [PR-shared-target-bindings](PR-shared-target-bindings.md) | unresolved | Shared flight target bindings |
| [ISSUE-station-auto-authentic-mounted-pressure](ISSUE-station-auto-authentic-mounted-pressure.md) | unresolved | Two station entry fixtures seed pressure through the separate legacy emitter |
| [PR-station-auto-authentic-mounted-pressure](PR-station-auto-authentic-mounted-pressure.md) | unresolved | test: seed station entry pressure through actual aligned native mounts |
| [ISSUE-station-auto-beam-pressure](ISSUE-station-auto-beam-pressure.md) | unresolved | Keep station AUTO defensive under uncovered active laser pressure |
| [PR-station-auto-beam-pressure](PR-station-auto-beam-pressure.md) | unresolved | Refuse unsafe AUTO handover and re-enter defence under active beams |
| [ISSUE-station-auto-clear-native-pressure-lane](ISSUE-station-auto-clear-native-pressure-lane.md) | unresolved | Existing police obstruct the two controlled station pressure fixtures |
| [PR-station-auto-clear-native-pressure-lane](PR-station-auto-clear-native-pressure-lane.md) | unresolved | test: give controlled station attackers a proved native firing lane |
| [ISSUE-station-auto-defence](ISSUE-station-auto-defence.md) | unresolved | Station AUTO must defend while completing native docking |
| [PR-station-auto-defence](PR-station-auto-defence.md) | unresolved | Add production station AUTO defence and evasion |
| [ISSUE-station-auto-defensive-transit](ISSUE-station-auto-defensive-transit.md) | unresolved | Prevent defensive AUTO from settling at the exposed docking waypoint |
| [PR-station-auto-defensive-transit](PR-station-auto-defensive-transit.md) | unresolved | Seek genuine station cover during defensive AUTO transit |
| [ISSUE-station-auto-finite-entry-braking](ISSUE-station-auto-finite-entry-braking.md) | unresolved | A transient police obstruction destroys an already validated entry course |
| [PR-station-auto-finite-entry-braking](PR-station-auto-finite-entry-braking.md) | unresolved | Preserve a validated entry course only while a finite stop is proved safe |
| [ISSUE-station-auto-first-course-refusal](ISSUE-station-auto-first-course-refusal.md) | unresolved | Freight trace omits the first fresh docking-course refusal |
| [PR-station-auto-first-course-refusal](PR-station-auto-first-course-refusal.md) | unresolved | Observe the actual first near-staging course refusal |
| [ISSUE-station-auto-mounted-pressure](ISSUE-station-auto-mounted-pressure.md) | unresolved | Station AUTO pressure fixture seeds a different beam path |
| [PR-station-auto-mounted-pressure](PR-station-auto-mounted-pressure.md) | unresolved | test: establish station AUTO pressure through an aligned native mount |
| [ISSUE-station-auto-moving-entry](ISSUE-station-auto-moving-entry.md) | unresolved | Active beam pressure can trap AUTO on a cover route instead of completing docking |
| [PR-station-auto-moving-entry](PR-station-auto-moving-entry.md) | unresolved | fix: continue a verified native docking course under known attack |
| [ISSUE-station-auto-native-pressure-proof](ISSUE-station-auto-native-pressure-proof.md) | unresolved | Station entry pressure prerequisites still fail in actual 669 |
| [PR-station-auto-native-pressure-proof](PR-station-auto-native-pressure-proof.md) | unresolved | test: expose native pressure refusal facts in existing station cases |
| [ISSUE-station-auto-police-corridor](ISSUE-station-auto-police-corridor.md) | unresolved | A police radius overlap revokes the genuine docking course |
| [PR-station-auto-police-corridor](PR-station-auto-police-corridor.md) | unresolved | Refine current docking-course candidates with actual hull geometry |
| [ISSUE-station-auto-protected-threat-evasion](ISSUE-station-auto-protected-threat-evasion.md) | unresolved | Permit station-cover evasion independently of offensive permission |
| [PR-station-auto-protected-threat-evasion](PR-station-auto-protected-threat-evasion.md) | unresolved | Separate physical station-cover evasion from firing authority |
| [ISSUE-station-auto-reciprocal-mounted-lane](ISSUE-station-auto-reciprocal-mounted-lane.md) | unresolved | The remaining station fixture needs both real fixed firing lanes |
| [PR-station-auto-reciprocal-mounted-lane](PR-station-auto-reciprocal-mounted-lane.md) | unresolved | test: prove reciprocal mounted rays before the station response |
| [ISSUE-station-auto-transit-waypoint-speed](ISSUE-station-auto-transit-waypoint-speed.md) | unresolved | Preserve defensive transit speed through intermediate avoidance waypoints |
| [PR-station-auto-transit-waypoint-speed](PR-station-auto-transit-waypoint-speed.md) | unresolved | Brake for the actual cover destination while passing avoidance waypoints |
| [ISSUE-station-auto-unproven-course-braking](ISSUE-station-auto-unproven-course-braking.md) | unresolved | A valid unresolved long course prevents a separately provable stop |
| [PR-station-auto-unproven-course-braking](PR-station-auto-unproven-course-braking.md) | unresolved | Prove a finite stop independently of an unresolved long route |
| [ISSUE-station-auto-weak-bank-heading](ISSUE-station-auto-weak-bank-heading.md) | unresolved | Weak-front AUTO protection can face the attacker instead of shielding that bank |
| [PR-station-auto-weak-bank-heading](PR-station-auto-weak-bank-heading.md) | unresolved | fix: turn the weak front bank away from its authenticated attacker |
| [ISSUE-station-tab-cycle-tail-bound](ISSUE-station-tab-cycle-tail-bound.md) | unresolved | One scene-count scan can stop before the main station after cycle reconciliation |
| [PR-station-tab-cycle-tail-bound](PR-station-tab-cycle-tail-bound.md) | unresolved | test: cover pending target tail and one fresh cycle |
| [ISSUE-station-tab-filter-selection](ISSUE-station-tab-filter-selection.md) | unresolved | Shared Tab helper hides the failed engagement stage |
| [PR-station-tab-filter-selection](PR-station-tab-filter-selection.md) | unresolved | test: identify failed station Tab engagement stages |
| [ISSUE-station-tab-reengagement-eligibility](ISSUE-station-tab-reengagement-eligibility.md) | unresolved | Main station eligibility after a real flight tick remains unresolved |
| [PR-station-tab-reengagement-eligibility](PR-station-tab-reengagement-eligibility.md) | unresolved | test: expose main station reengagement eligibility |
| [ISSUE-station-target-cycle](ISSUE-station-target-cycle.md) | unresolved | A new visit inherits an old station's target-cycle history |
| [PR-station-target-cycle](PR-station-target-cycle.md) | unresolved | Reset target history for an actual new flight origin |
| [ISSUE-141-station-target-reservation-frames](ISSUE-141-station-target-reservation-frames.md) | unresolved | Station targeting reservation frame repair |
| [PR-141-station-target-reservation-frames](PR-141-station-target-reservation-frames.md) | unresolved | Station targeting reservation frame repair |
| [ISSUE-sweep-pair-certificate](ISSUE-sweep-pair-certificate.md) | unresolved | Visited BVH leaves still evaluate irrelevant triangle pairs |
| [PR-sweep-pair-certificate](PR-sweep-pair-certificate.md) | unresolved | perf(geometry): certify irrelevant pairs inside visited BVH leaves |
| [ISSUE-sweep-scalar-reuse](ISSUE-sweep-scalar-reuse.md) | unresolved | Exact held-work geometry repeats immutable fast-kernel arithmetic |
| [PR-sweep-scalar-reuse](PR-sweep-scalar-reuse.md) | unresolved | perf(geometry): reuse immutable scalars in exact sweep fast kernels |
| [ISSUE-sweep-triangle-allocation](ISSUE-sweep-triangle-allocation.md) | unresolved | Temporary arrays in swept hull distance checks |
| [PR-sweep-triangle-allocation](PR-sweep-triangle-allocation.md) | unresolved | Preserve swept geometry checks without temporary triangle arrays |
| [ISSUE-sweep-triangle-bounds-reuse](ISSUE-sweep-triangle-bounds-reuse.md) | unresolved | Repeated triangle bounds during native cutter clearance checks |
| [PR-sweep-triangle-bounds-reuse](PR-sweep-triangle-bounds-reuse.md) | unresolved | Reuse immutable triangle bounds within the existing BVH traversal |
| [ISSUE-tab-flight-target-binding](ISSUE-tab-flight-target-binding.md) | unresolved | Use Tab alone for flight target selection |
| [PR-tab-flight-target-binding](PR-tab-flight-target-binding.md) | unresolved | Make Tab the single flight target key |
| [ISSUE-166-target-candidate-borrowing](ISSUE-166-target-candidate-borrowing.md) | unresolved | Borrow the shared targeting candidate receiver |
| [PR-166-target-candidate-borrowing](PR-166-target-candidate-borrowing.md) | unresolved | Borrow the shared targeting candidate receiver |
| [ISSUE-target-cue-surface-visibility](ISSUE-target-cue-surface-visibility.md) | unresolved | Hollow visible hulls can miss a centre-only glow ray |
| [PR-target-cue-surface-visibility](PR-target-cue-surface-visibility.md) | unresolved | Retain real surface visibility for hollow hull cues |
| [ISSUE-target-removal-fixture-lifetimes](ISSUE-target-removal-fixture-lifetimes.md) | unresolved | Target-removal fixture retains later scenarios during target setup |
| [PR-target-removal-fixture-lifetimes](PR-target-removal-fixture-lifetimes.md) | unresolved | test(targeting): separate target-removal scenario lifetimes |
| [ISSUE-target-transit-route](ISSUE-target-transit-route.md) | unresolved | Issue 18 child: disclose retained NPC transit routes |
| [PR-target-transit-route](PR-target-transit-route.md) | unresolved | Disclose actual retained NPC transit endpoints |
| [ISSUE-162-targeting-price-reference](ISSUE-162-targeting-price-reference.md) | unresolved | Use the named Pulse Laser in the targeting price assertion |
| [PR-162-targeting-price-reference](PR-162-targeting-price-reference.md) | unresolved | Use the named Pulse Laser in the targeting price assertion |
| [ISSUE-tilted-original-main-fixture](ISSUE-tilted-original-main-fixture.md) | unresolved | Tilted docking fixture must identify the original main station |
| [PR-tilted-original-main-fixture](PR-tilted-original-main-fixture.md) | unresolved | test(docking): identify the tilted fixture as the original main station |
| [ISSUE-typed-ordnance-runtime](ISSUE-typed-ordnance-runtime.md) | unresolved | Route actual missile launches through finite attributed flight |
| [PR-typed-ordnance-runtime](PR-typed-ordnance-runtime.md) | unresolved | Admit and simulate actual missiles before applying impact damage |
| [ISSUE-wanted-recorded-world-names](ISSUE-wanted-recorded-world-names.md) | unresolved | Resolve PLUGH in retained wanted reports |
| [PR-wanted-recorded-world-names](PR-wanted-recorded-world-names.md) | unresolved | Show recorded PLUGH names in wanted dossiers |
| [ISSUE-work-frame-roundoff](ISSUE-work-frame-roundoff.md) | unresolved | Work-frame orientation transfers amplify camera roundoff |
| [PR-work-frame-roundoff](PR-work-frame-roundoff.md) | unresolved | fix(flight): re-express work orientations with the actual frame inverse |
| [ISSUE-work-visible-approach](ISSUE-work-visible-approach.md) | unresolved | A visible oblique work face redirects guidance across its hull corner |
| [PR-work-visible-approach](PR-work-visible-approach.md) | unresolved | fix(flight): retain the visible approach to an oblique work surface |
