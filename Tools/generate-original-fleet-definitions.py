#!/usr/bin/env python3
"""Generate current R3 immutable Swift records without reading geometry or granting runtime rights."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import tomllib

MIN_INT, MAX_INT = -(2**63), 2**63 - 1


def bounded(path, limit):
    with path.open("rb") as stream:
        raw = stream.read(limit + 1)
    if len(raw) > limit:
        raise ValueError("Oversized definition input")
    return raw


def safe(root, relative):
    p = Path(relative)
    if p.is_absolute() or ".." in p.parts:
        raise ValueError("Unsafe definition path")
    path = root / p
    if not path.resolve().is_relative_to(root):
        raise ValueError("Definition path escapes root")
    for candidate in (path, *path.parents):
        if candidate == root:
            break
        if candidate.is_symlink():
            raise ValueError("Symlink definition path")
    return path


def quote(value):
    if not isinstance(value, str) or any(0xD800 <= ord(c) <= 0xDFFF for c in value):
        raise ValueError("Invalid Swift Unicode string")
    return '"' + ''.join('\\\\' if c == '\\' else '\\"' if c == '"' else f'\\u{{{ord(c):x}}}' if ord(c) < 32 or ord(c) >= 127 else c for c in value) + '"'


def integer(value):
    return "Int64.min" if value == MIN_INT else str(value)


def value_lines(value, prefix, indent):
    """Explicit enum cases and bounded literals prevent one giant inferred expression."""
    if isinstance(value, dict):
        if not value:
            return [prefix + ".object([:])"]
        result = [prefix + ".object(["]
        for key, item in sorted(value.items()):
            child = value_lines(item, " " * (indent + 2) + quote(key) + ": ", indent + 2)
            result += child[:-1] + [child[-1] + ","]
        return result + [" " * indent + "])"]
    if isinstance(value, list):
        if not value:
            return [prefix + ".array([])"]
        result = [prefix + ".array(["]
        for item in value:
            child = value_lines(item, " " * (indent + 2), indent + 2)
            result += child[:-1] + [child[-1] + ","]
        return result + [" " * indent + "])"]
    if isinstance(value, bool):
        literal = ".boolean(" + str(value).lower() + ")"
    elif isinstance(value, int):
        literal = ".integer(" + integer(value) + ")" if MIN_INT <= value <= MAX_INT else ".largeInteger(" + quote(str(value)) + ")"
    elif isinstance(value, float) and math.isfinite(value):
        literal = ".number(" + repr(value) + ")"
    elif isinstance(value, str):
        literal = ".string(" + quote(value) + ")"
        if len(prefix) + len(literal) > 100:
            return [prefix + ".string(", " " * (indent + 2) + quote(value), " " * indent + ")"]
    else:
        raise ValueError("Unsupported/nonfinite authored value")
    return [prefix + literal]


def inline_value(item):
    if isinstance(item, dict):
        return ".object([" + ", ".join(quote(k) + ": " + inline_value(v) for k, v in sorted(item.items())) + "])" if item else ".object([:])"
    if isinstance(item, list):
        return ".array([" + ", ".join(inline_value(v) for v in item) + "])"
    return value_lines(item, "", 0)[0] if not isinstance(item, str) else ".string(" + quote(item) + ")"


def generate(staging, repo, expected=171, model_ids=()):
    """Current R3 only; output into a new handoff root. Reads no geometry or native state."""
    if repo.is_symlink():
        raise ValueError("Symlink output root")
    staging, repo = staging.resolve(), repo.resolve()
    if repo.is_relative_to(staging) or staging.is_relative_to(repo):
        raise ValueError("Input/output overlap")
    wanted = {f"SH{i:03}" for i in range(1, expected + 1)}
    if {p.stem for p in (staging / "ships").glob("*.toml")} != wanted:
        raise ValueError("Missing/extra current R3 files")
    if not set(model_ids).issubset(wanted):
        raise ValueError("Unexpected model ID")
    records = []
    for identifier in sorted(wanted):
        raw = bounded(safe(staging, "ships/" + identifier + ".toml"), 131072)
        spec = tomllib.loads(raw.decode())
        if spec.get("schema") != "l337.fleet-design/2" or spec.get("id") != identifier:
            raise ValueError("Current R3 schema/identity required")
        if any(not isinstance(spec.get(k), str) or not spec[k] for k in ("name", "family", "classification", "objectKind")):
            raise ValueError("Missing current identity")
        if any(not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", k) for k, v in spec.items() if isinstance(v, dict)):
            raise ValueError("Invalid Swift source field identifier")
        access = spec["access"]
        if type(access["playerFlyable"]) is not bool or access["purchasePolicy"] not in ("blueprintFabrication", "plughQuestFabrication", "never"):
            raise ValueError("Invalid current access policy")
        records.append((identifier, spec, hashlib.sha256(raw).hexdigest()))
    lines = ["// Current exact R3 definitions. Source rows confer no native or acquisition qualification.",
             "public enum OriginalFleetDefinitionData {", "  public static var staged: [OriginalFleetDefinition] {",
             "    OriginalFleetR3Data.ids.compactMap { definition(for: $0) }", "  }", "",
             "  @inline(never)",
             "  public static func definition(for id: String) -> OriginalFleetDefinition? {",
             "    guard let load = definitionLoader(for: id) else { return nil }",
             "    return load()", "  }", "",
             "  // Dispatch without reserving a full definition result for every source row.",
             "  @inline(never)",
             "  private static func definitionLoader(for id: String) -> (@Sendable () -> OriginalFleetDefinition)? {",
             "    switch id {"]
    lines += ["    case " + quote(i) + ": return { " + i.lower() + " }" for i, _, _ in records]
    lines += ["    default: return nil", "    }", "  }", ""]
    for identifier, spec, source_sha in records:
        lines += ["  private static let " + identifier.lower() + ": OriginalFleetDefinition = make" + identifier + "()",
                  "  private static func make" + identifier + "() -> OriginalFleetDefinition {",
                  "    guard let current = OriginalFleetR3Data.contract(for: " + quote(identifier) + "),",
                  "      current.sourceSHA256 == " + quote(source_sha), "    else {",
                  '      preconditionFailure("Missing generated current R3 contract ' + identifier + '")', "    }"]
        for key, item in spec.items():
            if isinstance(item, dict):
                lines += ["    let `" + key + "`: [String: OriginalFleetValue] = ["]
                lines += ["      " + quote(k) + ": " + inline_value(v) + "," for k, v in sorted(item.items())]
                lines += ["    ]"]
        lines += ["    let authored: [String: OriginalFleetValue] = ["]
        lines += ["      " + quote(k) + ": " + (".object(`" + k + "`)" if isinstance(v, dict) else inline_value(v)) + "," for k, v in spec.items()]
        lines += ["    ]", "    return .init(",
                  "      id: current.id, name: current.name, family: current.family, role: current.classification,",
                  "      playerFlyable: current.playerFlyable, purchasePolicy: current.purchasePolicy.rawValue,",
                  "      authored: authored, sourcePath: " + quote("fleet-design-v2/ships/" + identifier + ".toml") + ",",
                  "      sourceSHA256: current.sourceSHA256, nativePerformance: current.performance,",
                  "      approvedMeshAvailable: " + str(identifier in model_ids).lower() + ",",
                  '      integrationBlockers: ["native-and-actual-game-qualification", "paid-fitting-crew-and-acquisition-acceptance"]',
                  "    )", "  }", ""]
    lines += ["}", ""]
    data = "\n".join(lines).encode()
    output = safe(repo, "Sources/L337Core/OriginalFleetDefinitions.generated.swift")
    if output.exists():
        raise ValueError("Refusing to overwrite existing source handoff")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(data)
    manifest = dict(records=len(records), sourceSpecs=[dict(id=i, sha256=h) for i, _, h in records],
                    generatedSHA256=hashlib.sha256(data).hexdigest(), geometryRead=False, runtimeActivated=False)
    safe(repo, "original-fleet-definitions.manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--staging", type=Path, required=True)
    parser.add_argument("--repo-root", type=Path, required=True)
    parser.add_argument("--model-manifest", type=Path, required=True)
    parser.add_argument("--expected-count", type=int, default=171)
    args = parser.parse_args()
    try:
        raw = bounded(args.model_manifest, 262144)
        if hashlib.sha256(raw).hexdigest() != "6b1c2ab50305c0881c6994ddb01a26d0de7f4a861a75bbe56a06e6a886aab2b0":
            raise ValueError("Unrecognised current source-model manifest")
        models = json.loads(raw)["models"]
        manifest = generate(args.staging, args.repo_root, args.expected_count, {m["id"] for m in models})
        print("Authored " + str(manifest["records"]) + " current R3 source records; no native qualification")
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
