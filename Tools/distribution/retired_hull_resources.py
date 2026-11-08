#!/usr/bin/env python3
"""Check known retired meshes in the resolved current resource paths.

This file check covers pinned mesh arrays, catalogue mappings and declared bundled
model assets. Edited/reindexed/transformed meshes, arbitrary installed external packs
and compiled renderer behavior require their own review and runtime qualification.
"""
import argparse
from decimal import Decimal
import hashlib
import json
from pathlib import Path
import tomllib


POLICY = Path(__file__).with_name("retired_hull_policy.json")


def mesh_fingerprint(design):
    """Compare ordered numeric arrays independently of JSON/TOML number spelling."""
    def number(value):
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValueError("Mesh coordinate/index must be numeric")
        exact = Decimal(str(value))
        if not exact.is_finite():
            raise ValueError("Nonfinite mesh number")
        return "0" if exact == 0 else format(exact.normalize(), "f")

    arrays = {
        key: [[number(value) for value in row] for row in design[key]]
        for key in ("vertices", "faces")
    }
    encoded = json.dumps(arrays, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def reject_retired(design, policy, location):
    fingerprint = mesh_fingerprint(design)
    if any(row["meshSHA256"] == fingerprint for row in policy["retiredMeshes"]):
        raise ValueError("Retired mesh at " + str(location))
    return fingerprint


def verify_resource_tree(resources):
    """Resolve catalogue and declared pack model files at the loader's paths."""
    policy = json.loads(POLICY.read_bytes())
    ships = {}
    native = {}
    for path in sorted((resources / "Ships").glob("*.toml")):
        ship = tomllib.loads(path.read_text())
        identity = ship["id"]
        if identity != path.stem or identity in ships:
            raise ValueError("Ambiguous catalogue identity at " + str(path))
        ships[identity] = ship
        for field in ("design", "nativeDesign"):
            if field in ship:
                reject_retired(ship[field], policy, str(path) + "#" + field)
        if identity in policy["replacementIdentities"]:
            expected = policy["replacementIdentities"][identity]
            if ship["name"] != expected["name"] or ship["catalogue"]["family"] != expected["family"]:
                raise ValueError("Retired replacement identity changed: " + identity)
        if "nativeHull" in ship:
            allowed = policy["nativeAllowlist"].get(identity)
            resolved = ship.get("nativeDesign", ship["design"])
            if allowed != {"nativeHull": ship["nativeHull"], "meshSHA256": mesh_fingerprint(resolved)}:
                raise ValueError("Unexpected native catalogue mapping: " + identity)
            native[identity] = allowed
    expected_ids = {f"SH{index:03d}" for index in range(1, 172)}
    if set(ships) != expected_ids or native != policy["nativeAllowlist"]:
        raise ValueError("Current catalogue or native station/Kite mapping is incomplete")

    aegis = resources / "MissionPacks/NavalAegis.json"
    data = aegis.read_bytes()
    if hashlib.sha256(data).hexdigest() != policy["aegisSHA256"]:
        raise ValueError("Marked Aegis resource identity changed")
    reject_retired(json.loads(data)["nativeDesign"], policy, aegis)
    model_count = 0
    profile_count = 0
    for manifest in sorted((resources / "ScriptPacks").glob("*/manifest.toml")):
        document = tomllib.loads(manifest.read_text())
        models = {}
        for model in document.get("models", []):
            identity = model["id"]
            path = manifest.parent / model["path"]
            if identity in models or not path.resolve().is_relative_to(manifest.parent.resolve()):
                raise ValueError("Ambiguous/escaped model at " + str(manifest))
            data = path.read_bytes()
            if hashlib.sha256(data).hexdigest() != model["sha256"]:
                raise ValueError("Declared model bytes changed: " + str(path))
            reject_retired(json.loads(data), policy, path)
            models[identity] = path
            model_count += 1
        for profile in document.get("npcs", []):
            references = [profile["model"]] + [part["model"] for part in profile.get("components", [])]
            for reference in references:
                kind, separator, identity = reference.partition(":")
                available = ships if kind == "catalogue" else models if kind == "asset" else {}
                if not separator or identity not in available:
                    raise ValueError("Unresolved bundled model " + reference + " at " + str(manifest))
                profile_count += 1
    return {"catalogue": len(ships), "nativeMappings": sorted(native),
            "declaredAssets": model_count, "profileReferences": profile_count}


def verify(root, app=None):
    """Reuse packaging byte checks, then inspect source and resolved bundle trees."""
    if app is None:
        return {"source": verify_resource_tree(root / "Sources/L337Core/Resources")}
    from package_macos import verify_resources

    return verify_resources(app, source_root=root)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--app", type=Path)
    options = parser.parse_args()
    print(json.dumps(verify(options.root, options.app), sort_keys=True))


if __name__ == "__main__":
    main()
