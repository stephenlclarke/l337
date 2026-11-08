#!/usr/bin/env python3
"""Read-only cached-model input bridge; never qualify, generate or install a hull."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import tomllib

PLAN_SHA256 = "2847c68d4328956b776cf89217b8b42c35990b4b0fea87bac39247fafe3dc01f"
STATUS = "GENERATED_CANDIDATE_ONLY_NOT_INSTALLED_OR_NATIVE_QUALIFIED"
KIND = "original-fleet-candidate-qualification-inputs"
GEOMETRY_FIELDS = {"vertices", "faces", "faceMaterials", "faceTextures"}


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate JSON field: " + key)
        result[key] = value
    return result


def reject_constant(value):
    raise ValueError("Non-finite JSON constant: " + value)


def decode_json(raw):
    return json.loads(raw, object_pairs_hook=unique_object, parse_constant=reject_constant)


def checked_bytes(path, pin):
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise ValueError("Input must be a regular non-symlink file")
    with path.open("rb") as stream:
        raw = stream.read(pin["bytes"] + 1)
    if len(raw) != pin["bytes"] or digest(raw) != pin["sha256"]:
        raise ValueError("Input bytes/hash changed: " + str(path))
    return raw


def source_path(root, pin):
    path = Path(pin["path"])
    return path if path.is_absolute() else root / path


def load_plan(path):
    with Path(path).open("rb") as stream:
        raw = stream.read(2 * 1024 * 1024 + 1)
    if len(raw) > 2 * 1024 * 1024 or digest(raw) != PLAN_SHA256:
        raise ValueError("Qualification plan changed or oversized")
    plan = decode_json(raw)
    ids = [row["id"] for row in plan["rows"]]
    if len(ids) != 55 or len(set(ids)) != 55 or {"SH040", "SH162"} & set(ids):
        raise ValueError("Expected the exact reviewed55 set")
    return plan


def fan_triangles(faces):
    if not isinstance(faces, list) or not faces:
        raise ValueError("Missing native faces")
    if any(not isinstance(face, list) or len(face) < 3 for face in faces):
        raise ValueError("Invalid native face arity")
    return sum(len(face) - 2 for face in faces)


def validate_cached(document, row, original, resource, validate_design):
    """Transport/structure checks only. No continuous fidelity tolerance is issued."""
    if not isinstance(document, dict):
        raise ValueError("Cached envelope must be an object")
    if (document.get("status"), document.get("id"), document.get("originalSourceSHA256"),
            document.get("r3SHA256")) != (
            STATUS, row["id"], row["originalSource"]["sha256"], row["r3SHA256"]):
        raise ValueError("Cached status/identity/source/R3 mismatch")
    if original.get("proposal", {}).get("id") != row["id"]:
        raise ValueError("Original identity mismatch")
    catalogue = resource.get("catalogue", {})
    if (resource.get("id"), resource.get("name"), catalogue.get("family"),
            catalogue.get("objectKind"), catalogue.get("origin")) != (
            row["id"], row["name"], row["family"], row["objectKind"], row["catalogueOrigin"]):
        raise ValueError("Current resource/R3 identity/domain mismatch")
    if any(resource.get(key) != original.get(key) for key in ["design", "nativeDesign"]):
        raise ValueError("Packaged original tables differ")
    native, reference = document.get("nativeCandidate"), original.get("nativeDesign")
    if not isinstance(native, dict) or not isinstance(reference, dict) or native.keys() != reference.keys():
        raise ValueError("Native schema differs from own original")
    if any(native[key] != reference[key] for key in reference.keys() - GEOMETRY_FIELDS):
        raise ValueError("Original appearance/source declarations changed")
    triangles = fan_triangles(native.get("faces"))
    if triangles > 512:
        raise ValueError("Native candidate exceeds512 fan triangles")
    if any(len(face) != 3 for face in native["faces"]):
        raise ValueError("Current native consumer requires triangles")
    if not isinstance(native.get("vertices"), list) or len(native["vertices"]) > 1536:
        raise ValueError("Candidate vertex bound exceeded")
    if set(native.get("faceMaterials", [])) != set(reference.get("faceMaterials", [])):
        raise ValueError("Original used material missing")
    parts = document.get("parts")
    if not isinstance(parts, list) or [part.get("name") for part in parts] != row["parts"]["names"]:
        raise ValueError("Own component list/order changed")
    vertex_end = face_end = 0
    for index, part in enumerate(parts):
        if any(type(part.get(key)) is not int for key in ["vertexStart", "vertexCount", "faceStart", "faceCount"]):
            raise ValueError("Invalid component range")
        if (part["vertexStart"], part["faceStart"]) != (vertex_end, face_end):
            raise ValueError("Noncontiguous component ownership")
        if min(part["vertexCount"], part["faceCount"]) <= 0 or part.get("index", index) != index:
            raise ValueError("Missing/foreign component")
        vertex_end += part["vertexCount"]
        face_end += part["faceCount"]
    if vertex_end != len(native["vertices"]) or face_end != len(native["faces"]):
        raise ValueError("Component ranges do not cover native model")
    diagnostics = validate_design(native, row["id"] + ".cachedNativeCandidate")
    return native, dict(diagnostics, fanTriangles=triangles,
                        continuousFidelity="UNISSUED", nativePhysicalAdoption=False)


def encoded(value):
    return (json.dumps(value, sort_keys=True, allow_nan=False, separators=(",", ":")) + "\n").encode()


def prepare(plan_path, source_root, output_root):
    plan = load_plan(plan_path)
    source_root, terminal = Path(source_root).resolve(strict=True), Path(plan["terminalRoot"]).resolve(strict=True)
    output_root = Path(output_root)
    if output_root.exists() or output_root.is_symlink():
        raise ValueError("Output must be fresh and nonexistent")
    output_root = output_root.resolve()
    for protected in [source_root, terminal]:
        if output_root.is_relative_to(protected) or protected.is_relative_to(output_root):
            raise ValueError("Output overlaps source/input tree")
    for role in ["terminalManifest", "sourceMap", "g1InputFIRST"]:
        checked_bytes(plan[role]["path"], plan[role])
    # Authenticate all raw inputs BEFORE mesh decoding or existing-validator import.
    blobs = {}
    for row in plan["rows"]:
        for role in ["cache", "originalSource", "currentResource", "blueprint", "recipe", "tests", "physicalRecord"]:
            pin = row[role]
            if pin is None:
                continue
            path = terminal / pin["path"] if role == "cache" else source_path(source_root, pin)
            if str(path) not in blobs:
                blobs[str(path)] = checked_bytes(path, pin)
                if sum(len(raw) for raw in blobs.values()) > plan["finiteOperations"]["rawInputBytesAllFrozenRoles"]:
                    raise ValueError("Frozen raw-input byte budget exceeded")
    helper = source_path(source_root, plan["existingDesignValidator"])
    checked_bytes(helper, plan["existingDesignValidator"])
    spec = importlib.util.spec_from_file_location("existing_candidate_design_validator", helper)
    validator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(validator)
    output_root.mkdir(parents=True, exist_ok=False)
    files, jobs, total = [], [], 0

    def emit(relative, value):
        nonlocal total
        raw = encoded(value)
        total += len(raw)
        if len(raw) > plan["limits"]["maximumAssetBytes"] or total > plan["limits"]["maximumTotalBytes"]:
            raise ValueError("Existing inspection asset byte budget exceeded")
        path = output_root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as stream:
            stream.write(raw)
        entry = dict(file=relative, bytes=len(raw), sha256=digest(raw))
        files.append(entry)
        return entry

    for row in plan["rows"]:
        cached = decode_json(blobs[str(terminal / row["cache"]["path"])])
        original = tomllib.loads(blobs[str(source_path(source_root, row["originalSource"]))].decode())
        resource = tomllib.loads(blobs[str(source_path(source_root, row["currentResource"]))].decode())
        native, diagnostics = validate_cached(cached, row, original, resource, validator.validate_design)
        candidate_source = row["cache"]["path"]
        candidate = dict(id=row["id"], sourcePath=candidate_source, sourceSHA256=row["cache"]["sha256"], nativeDesign=native)
        reference = dict(id=row["id"], **row["referenceSource"], nativeDesign=original["nativeDesign"])
        units = original["proposal"].get("coordinateUnits")
        if units is not None:
            if not isinstance(units, str) or not units.strip():
                raise ValueError("Invalid original explicit units")
            candidate["coordinateUnits"] = reference["coordinateUnits"] = units
        candidate_pin = emit("candidates/" + row["id"] + ".json", candidate)
        reference_pin = emit("references/" + row["id"] + ".json", reference)
        descriptor = dict(row, candidateParts=cached["parts"], cachedCoordinateRule=cached.get("coordinateRule"),
                          cachedUnproven=cached.get("unproven"), diagnostics=diagnostics)
        criteria_pin = emit("criteria/" + row["id"] + ".json", descriptor)
        jobs.append(dict(id=row["id"], objectKind=row["objectKind"], r3SHA256=row["r3SHA256"],
                         candidate=dict(candidate_pin, sourcePath=candidate_source, sourceSHA256=row["cache"]["sha256"]),
                         reference=dict(reference_pin, **row["referenceSource"]), criteria=criteria_pin))
    manifest = dict(schemaVersion=1, kind=KIND, status="UNQUALIFIED_INSPECTION_INPUTS_ONLY",
                    sourcePlanSHA256=PLAN_SHA256, terminalManifestSHA256=plan["terminalManifest"]["sha256"], jobs=jobs,
                    files=files, acceptedHulls=0, runtimeActivation=False,
                    remaining=["continuous profile/material/UV/void fidelity assessment",
                               "native physical/collision/installed/occupied/loaded inputs",
                               "reviewed per-ID provenance/registry/asset adoption and actual journeys"])
    raw = encoded(manifest)
    if len(raw) > 262144 or total + len(raw) > plan["limits"]["maximumTotalBytes"]:
        raise ValueError("Inspection manifest/total byte budget exceeded")
    with (output_root / "manifest.json").open("xb") as stream:
        stream.write(raw)
    return dict(status=manifest["status"], jobs=len(jobs), manifestSHA256=digest(raw), bytes=total+len(raw),
                acceptedHulls=0, runtimeActivation=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["plan", "source-root", "output-root"]:
        parser.add_argument("--" + name, required=True, type=Path)
    args = parser.parse_args()
    print(json.dumps(prepare(args.plan, args.source_root, args.output_root), sort_keys=True))


if __name__ == "__main__":
    main()
