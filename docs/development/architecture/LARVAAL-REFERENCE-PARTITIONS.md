# SH124 and SH125 original reference component partitions

The original own-component partitions already exist in source-authoritative ownership records. The frozen 55-entry criteria omitted them through the SH124/SH125 special cases that supplied names but empty `originalPartRanges`. This change provides the missing metadata join for a later qualification artifact. The active paired renderer, its guard, its FIRST, the passed prepared files and the original qualification plan remain unchanged.

SH124 uses `creator-ownership-records/SH124.json`, SHA-256 `653b81868573a72167bbf6fa83182d81649e0b49c2358a11beca34fc5fc14a8a`. Its original `nativeDesign.parts` explicitly owns eight consecutive operations: each side's closed lobe, end growth and exact reflected end growth, followed by central structural growth and the luminous aft organ. The record declares 744 original vertices and 1464 original native faces. These are source metadata, not candidate counts or a cap waiver.

SH125 uses `distinct-creator-ownership-records/SH125.json`, SHA-256 `e7ca2843dec75a90851abd9b2ca427f03096bc4459be6d80dbe74e6f7771baea`. Its original `nativeDesign.parts` explicitly owns four closed jade shell intervals followed by one complete gold core. It declares 2562 original vertices and 5112 original faces. The four intervals include their outer, inner and rim closure geometry. Their construction surrounds three real circumferential gaps. No range is inferred from bounds, material colour, count matching or a candidate mesh.

`OriginalFleetRelativePhysicalRegistrations.swift` already binds those exact component-record hashes to the same original source hashes: SH124 `1715f8fc7da8e0a7e3c0c17534087477b443508c174a0a4da4eb158829438732`, and SH125 `43340089afa8c01e2fe8e2482d9b8fa98e4735480ba45c65083d617e43bc66b1`. That source binding supports component correspondence. It does not qualify continuous fidelity or supply installed, occupied or loaded physical facts.

The new `docs/fleet-physical/larvaal-original-reference-partitions.json` copies the native range and creator-operation fields from those records. It deliberately excludes stock-role/mass declarations from the partition payload. The catalogue binds each exact ownership record, original/current source, creator/primitive, blueprint, passed reference/candidate/criteria and registration-source preimage. All eight SH124 and five SH125 ranges are preserved in original order. No geometry, face, UV, material, frame or resource is edited.

G1 alone may run the metadata consumer after the bounded source/input review:

```sh
python3 Tools/qualification/prepare-larvaal-reference-partitions.py \
  --catalogue docs/fleet-physical/larvaal-original-reference-partitions.json \
  --source-root "$FLEET_SOURCE_ROOT" \
  --output-root "$FRESH_EXTERNAL_PARTITION_CRITERIA"
```

Expected output is `SH124.json`, `SH125.json` and `manifest.json` in a fresh external directory. The consumer authenticates all raw inputs first. It decodes only the catalogue, the two ownership metadata documents and two criteria documents. Original/current TOML, model documents and creator source stay opaque. It imports no creator, bridge, geometry, renderer or native test module. Each criterion is bounded to 1 MiB; exactly two are emitted. Model assets are not rewritten or copied into a new catalogue.

Only `parts.originalPartRanges`, `parts.originalOwnership` and the new `referencePartitionBinding` change. A complete metadata inverse verifies all other field values remain unchanged, including own source/R3/provenance, candidate parts, original feature criteria, sampling and exact-fixed classifications, appearance/UV metadata, diagnostics and the 512 candidate triangle cap. Cross-member ownership, detailed `design` ranges used as `nativeDesign`, changed raw hashes and already-filled criterion preimages refuse. Original topology counts never become candidate admission evidence.

Four authored G1-only tests in `Tools/qualification/test_larvaal_reference_partitions.py` cover real two-ID materialisation/inverse, actual cross-member refusal, wrong original table refusal and overwrite/JSON refusal. They require the frozen actual metadata inputs and remain unrun by G4. Run them once as the metadata qualification stage if selected; no generator, prepared55, native-input55 or renderer repeat is necessary.

Future feature consumers can bind these new criterion hashes to the exact same passed reference documents. They must explicitly join the metadata result into a new reviewed evidence artifact. Do not overwrite current prepared criteria, alter the active renderer FIRST, replace old images or manufacture a second renderer PASS. Any new per-part numerical measurements belong to G1's later guarded feature stage and must retain the original frame. The active renderer can finish against its unchanged original descriptor and truthfully report that descriptor's missing partition.

This supplies source component ownership only. Whole changed profiles, voids, material distribution, complete UV mapping and an acceptable continuous fidelity metric/tolerance remain open. Native crew and conversion crew remain distinct. Authentic installed/occupied/loaded/system inputs and coherent per-ID source/physical/resource/admission/current-save adoption remain unissued. Nothing grants a hull, native actor, source approval or physical authority. G4 ran no target parser, compiler, test, model, geometry or renderer operation.
