# Actual 55 cached candidate qualification handoff

G1 session 50084 completed 37 creator classes and 113 tests, producing 55 genuine cached candidates. That result covers generation and its authored tests. The candidates remain unqualified and uninstalled. This handoff consumes those cached outputs; it never imports a creator or repeats the 113 tests.

Actual session 17643 subsequently passed the isolated native input probe for all 55 candidates with zero failures, after the single retained preparation from session 44620. The complete terminal is `/tmp/l337-fleet-b0cdeaf5-17643-native-input-pass-terminal/manifest.json` (33,131 bytes, SHA-256 `645c68d5def5f9b0c42f3053688d4f90c5bb893057d6e3f3d2d7f93f73cf6057`). This establishes native input/source checks only. Continuous fidelity remains unissued; dry original-source records do not qualify occupied or loaded candidate systems. All candidates remain uninstalled, with zero accepted hulls and runtime activation false. The passed creator, preparation and native input checks must be reused without unchanged reruns. Default-suite tests and full normal CI remain open.

## Frozen inputs and transport

`docs/fleet-physical/actual55-candidate-qualification-inputs.json` binds each ID to its exact cached bytes, original authored TOML, current resource TOML/R3, own blueprint, recipe, tests, physical record and original component ownership metadata. It also binds the successful terminal manifest (34859 bytes, SHA-256 `a5fe5cc726431b5cb8602ffb89d1a0417394f9f73fb4145cb250316bf418b41d`) and G1 input FIRST (103289 bytes, SHA-256 `fadddd4899e7415028e3f82475d1060c041ab31a7ea6cb3c849a83704aa806aa`). SH040 and SH162 are excluded. SH161 is the station; the other 54 entries are ships. Missing station accommodation stays absent, never zero crew.

G1 runs the reviewed bridge once, inside its held execution lease, after G2 reviews the complete bridge, native probe and temporary test source view:

```sh
python3 Tools/prepare-original-fleet-candidate-qualification.py \
  --plan docs/fleet-physical/actual55-candidate-qualification-inputs.json \
  --source-root "$FLEET_SOURCE_ROOT" \
  --output-root "$FRESH_INSPECTION_ROOT"
```

The bridge authenticates raw inputs before model parsing or importing the existing `Tools/compile-original-fleet.py` validator. It checks identity, source/R3 bindings, unchanged non-geometry appearance declarations, used materials, own component order/ranges, and the actual fan-triangle cap. Each candidate must have at most 512 triangles, counted as `sum(len(face)-2)`. Current native consumers also require triangular faces. No scaling or recentering occurs in transport.

Output contains 55 candidate documents, 55 original reference documents, 55 criteria documents and a manifest. Each native document uses the existing `nativeDesign` decoder schema. Candidate provenance is the genuine `actual-run/candidates/ID.json` path and cache SHA, distinct from the original reference provenance. The manifest kind is `original-fleet-candidate-qualification-inputs`, with `acceptedHulls=0` and `runtimeActivation=false`. It cannot replace the shipping 171-model showroom manifest.

## One native probe

G1 composes `Tools/qualification/OriginalFleetCandidateQualificationProbe.swift` into the existing `L337CoreTests` target through the separately reviewed temporary source view. Keep all production targets, dependencies and resources. Discovery must select exactly `OriginalFleetCandidateQualificationProbe.cached55UseActualNativeDecodeMeshAndCalibrationWithoutAdoption`. Bind the source view preimage, afterimage and probe SHA; restore the view and source status in a finally step even on failure. This is a focused probe, not default suite or CI qualification.

Set `L337_FLEET_QUALIFICATION_INPUT_ROOT` to the bridge output, `L337_FLEET_QUALIFICATION_MANIFEST_SHA256` to its actual emitted manifest SHA, and `L337_FLEET_QUALIFICATION_REPORT_ROOT` to a fresh external directory. The probe writes `native-input-report.json` with actual per-ID checks/refusals and zero accepted hulls.

The probe uses actual `OriginalFleetShowroomModels.decode`, `ShipDesign.valid`, raw native mesh, R3 contracts, approved physical registrations, dry physical records and `OriginalHullEnvelope`. It checks triangles, native closed directed edges, used vertices, positive face areas and exact retained components including local faces, materials and UV. Uniform approved calibration preserves source origin and winding. It also verifies pending runtime guards and the current hull consumer's refusal of cached derivative provenance. The station must refuse through its own missing ship-contract path. A real physical or decoder refusal remains a failure; file presence does not excuse it.

`Tools/tests/test_original_fleet_candidate_qualification.py` contains four G1-only adapter regression methods using these actual frozen cache inputs. It is not portable without that cache. G1 must authenticate all 337 parent frozen input/source pins and all 331 unique seven-role blobs before any regression module import or source parse. Then run only these three negative regression methods:

- `test_bad_identity_source_r3_status_refuse_before_native_validation`
- `test_fan_triangle_cap_is_not_source_polygon_count`
- `test_changed_appearance_missing_part_and_duplicate_json_refuse`

Run the production CLI preparation once and retain its output for the native probe. The positive temporary preparation method `test_all_actual55_bridge_to_unchanged_paired_native_fields_without_adoption` stays explicitly UNRUN in this stage. No original creator test rerun is needed.

## Fidelity criteria and remaining authority

Every plan row contains its own component names, source ranges, sampled and exact retained indices, original blueprint criteria and source hashes. Fixed components require exact own-source vertices, local faces, full material sequence and face UV. Changed profiles require their own complete surfaces, stations, radii, offsets and material distribution; hollow features require their own cavities, slots, gaps, tubes, inner faces and caps. The plan carries the actual per-ID blueprint criteria rather than a generic hull substitute.

No general continuous surface metric or Hausdorff/profile tolerance has been issued. The bridge and probe do not invent one. Closed topology, UV validity, matching bounds, endpoints or a few samples cannot establish full profile, material, UV or void fidelity. G1 and the source owner must record a supported per-ID fidelity assessment or the exact missing criterion. Continuous fidelity remains `UNISSUED` even when structural checks pass.

Dry source-record validation and an envelope do not establish collision suitability, installed systems, occupied hardware, people, loaded mass, loaded centre of mass or loaded tensor. Actual source-backed installed/occupied/loaded inputs and their runtime acceptance remain required. Native crew and conversion crew stay distinct. SH155 uses the current Osprey Support identity; its old Carrier provenance creates no alias or entitlement.

## Adoption boundary

After genuine fidelity and physical qualification, a separate reviewed per-ID adoption change must bind the approved candidate bytes to native source path/SHA registrations, current `Ships/ID.toml` native design and resource SHA, pending-stage source authentication, original showroom asset entries and manifest/asset hashes, and physical registration/record source-frame consistency. Inspect `OriginalFleetCurrentHullSource`, `ShipCatalogue.rawMesh`, `OriginalFleetRuntimeHullSource` and `GameplayAdmission` together. Cached derivative provenance deliberately fails the current source binding today.

Removing a pending registration alone, reusing an old Hull, or assigning a positive identifier cannot perform adoption. SH161 needs its own station route. Real fabrication/purchase, fitting, paid equipment, source crew, current-save/load and supported journeys must be tested after the coherent source binding exists. No runtime or admission source is changed by this handoff; the established 23 ships and four station routes remain the acceptance baseline.

## Finite execution scope

One preparation performs 55 cached JSON decodes, 55 original and 55 current TOML decodes, and 55 calls to the existing validator. It emits 110 native documents and 55 criteria documents. The native probe visits 55 rows once. Candidate bounds are 512 triangular faces and 1536 vertices per row. One complete candidate-array pass spans at most 253440 vertex scalars or 84480 face indices across all rows; these are per-pass cardinality bounds, not a claim that validators traverse arrays only once. Reference arrays retain their exact frozen original sizes and the per-asset byte bound.

G1 FIRST retains its exact 56087354-byte cache/original/current subset provenance. The bridge authenticates all seven frozen roles: 331 unique files totaling 61429620 bytes, bounded by `rawInputBytesAllFrozenRoles`. The additional 5342266 bytes are blueprints (207873), recipes (328194), tests (328334) and physical records (4477865). These raw file byte totals do not parse mesh data. The plan is bounded to 2 MiB, each asset to 8 MiB, the manifest to 262144 bytes, and total emitted bytes to 128 MiB. G1 must authenticate inputs and source again after execution and retain actual output hashes, discovery, failures and restoration evidence. There are zero creator imports/calls and zero continuous-tolerance comparisons. G4 authored this handoff without running its Python, parsers, model operations, Swift probe or tests. Full normal `make ci`, coverage, leak gates and final-head checks remain later requirements. Sanitizers are manual opt-in checks and are not required by normal CI.
