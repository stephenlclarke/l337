#!/usr/bin/env python3
"""G1-only metadata join for the two exact original native component records."""
import argparse
import copy
import hashlib
import json
from pathlib import Path

CATALOGUE_SHA256 = "8c6ebaf30c854de426587289b82bf77d36f3cf6707625a50380dc23b0947364f"
PART_FIELDS = {"index", "name", "vertexStart", "vertexCount", "faceStart", "faceCount",
               "creatorMethod", "creatorForm", "creatorDomain", "exactMaterialRuns", "allowedSourceMaterials"}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("Duplicate JSON key")
        value[key] = item
    return value


def reject_constant(value):
    raise ValueError("Non-finite JSON constant: " + value)


def decode(raw):
    return json.loads(raw, object_pairs_hook=unique_object, parse_constant=reject_constant)


def raw_pin(pin, root):
    path = Path(pin["path"])
    path = path if path.is_absolute() else root / path
    if path.is_symlink() or not path.is_file() or not 0 < pin["bytes"] <= 8 * 1024 * 1024:
        raise ValueError("Invalid input path/bound")
    with path.open("rb") as stream:
        raw = stream.read(pin["bytes"] + 1)
    if len(raw) != pin["bytes"] or digest(raw) != pin["sha256"]:
        raise ValueError("Frozen input changed: " + str(path))
    return raw, path.resolve()


def load_catalogue(path):
    with Path(path).open("rb") as stream:
        raw = stream.read(1024 * 1024 + 1)
    if len(raw) > 1024 * 1024 or digest(raw) != CATALOGUE_SHA256:
        raise ValueError("Exact two-ID catalogue changed")
    value = decode(raw)
    if value["ids"] != ["SH124", "SH125"] or [r["id"] for r in value["rows"]] != value["ids"]:
        raise ValueError("Exact original identities required")
    return value


def augment(criteria, row, ownership):
    """Copy explicit source ranges, never derive them from mesh counts or bounds."""
    sid = row["id"]
    if sid not in {"SH124", "SH125"} or criteria["id"] != sid or ownership["id"] != sid:
        raise ValueError("Cross-member identity")
    if (ownership["geometrySHA256"] != row["originalSource"]["sha256"]
            or ownership["contractSHA256"] != row["contractSHA256"]
            or criteria["originalSource"]["sha256"] != row["originalSource"]["sha256"]
            or criteria["r3SHA256"] != row["contractSHA256"]):
        raise ValueError("Original source/R3 binding differs")
    original = ownership["models"]["nativeDesign"]
    parts = [{k: v for k, v in part.items() if k in PART_FIELDS} for part in original["parts"]]
    if parts != row["parts"] or [p["name"] for p in parts] != criteria["parts"]["names"]:
        raise ValueError("Explicit original native ownership differs")
    if original["vertices"] != row["originalTopology"]["vertices"] or original["faces"] != row["originalTopology"]["faces"]:
        raise ValueError("Source metadata totals differ; do not substitute candidate counts")
    if criteria["parts"]["originalPartRanges"] or criteria["parts"]["originalOwnership"] is not None:
        raise ValueError("Expected the frozen missing-partition preimage")
    if "referencePartitionBinding" in criteria:
        raise ValueError("Partition binding already present")
    after = copy.deepcopy(criteria)
    after["parts"]["originalPartRanges"] = copy.deepcopy(parts)
    after["parts"]["originalOwnership"] = copy.deepcopy(row["ownershipRecord"])
    after["referencePartitionBinding"] = dict(
        catalogueSHA256=CATALOGUE_SHA256, criteriaPreimageSHA256=row["criteriaPreimage"]["sha256"],
        referenceDocumentSHA256=row["referenceDocument"]["sha256"],
        ownershipRecordSHA256=row["ownershipRecord"]["sha256"], sourceTable="nativeDesign",
        authority="Original component correspondence only; no fidelity/physical/adoption approval")
    # An exact metadata inverse proves all geometry/UV/provenance/classification fields survived.
    inverse = copy.deepcopy(after)
    inverse["parts"]["originalPartRanges"] = criteria["parts"]["originalPartRanges"]
    inverse["parts"]["originalOwnership"] = criteria["parts"]["originalOwnership"]
    del inverse["referencePartitionBinding"]
    if inverse != criteria:
        raise ValueError("Unexpected criterion field change")
    return after


def materialize(catalogue_path, source_root, output_root):
    root = Path(source_root).resolve(strict=True)
    catalogue = load_catalogue(catalogue_path)
    output = Path(output_root)
    if output.exists() or output.is_symlink():
        raise ValueError("Output must be fresh")
    output = output.resolve()
    if output.is_relative_to(root) or root.is_relative_to(output):
        raise ValueError("Output overlaps source tree")
    blobs = {}
    for pin in [catalogue["physicalRegistrationSource"]] + [p for row in catalogue["rows"] for p in
            [row[k] for k in ["ownershipRecord", "originalSource", "currentResource", "referenceDocument",
                             "candidateDocument", "criteriaPreimage", "blueprint"]] + row["creatorPins"]]:
        raw, path = raw_pin(pin, root)
        if output.is_relative_to(path.parent) or path.parent.is_relative_to(output):
            raise ValueError("Output overlaps frozen input directory")
        blobs[pin["path"]] = raw
    output.mkdir(parents=True, exist_ok=False)
    files = []
    for row in catalogue["rows"]:
        # Only ownership metadata and criteria are decoded. Model/TOML/creator bytes stay opaque.
        original = decode(blobs[row["ownershipRecord"]["path"]])
        criteria = decode(blobs[row["criteriaPreimage"]["path"]])
        value = augment(criteria, row, original)
        raw = (json.dumps(value, indent=2, allow_nan=False) + "\n").encode()
        if len(raw) > 1024 * 1024:
            raise ValueError("Criterion output bound")
        name = row["id"] + ".json"
        with (output / name).open("xb") as stream:
            stream.write(raw)
        files.append(dict(id=row["id"], file=name, bytes=len(raw), sha256=digest(raw),
                          inputCriteriaSHA256=row["criteriaPreimage"]["sha256"],
                          referenceDocumentSHA256=row["referenceDocument"]["sha256"]))
    manifest = dict(status="ORIGINAL_REFERENCE_PARTITION_METADATA_ONLY", catalogueSHA256=CATALOGUE_SHA256,
                    files=files, candidateGeometryChanges=0, continuousFidelity="UNISSUED",
                    installedOccupiedLoadedPhysical="UNISSUED", acceptedHulls=0, runtimeActivation=False)
    raw = (json.dumps(manifest, indent=2) + "\n").encode()
    with (output / "manifest.json").open("xb") as stream:
        stream.write(raw)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["catalogue", "source-root", "output-root"]:
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(materialize(args.catalogue, args.source_root, args.output_root), sort_keys=True))


if __name__ == "__main__":
    main()
