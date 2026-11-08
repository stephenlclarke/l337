#!/usr/bin/env python3
"""Build a signed macOS ZIP from a committed source checkpoint."""

import argparse
import datetime
import hashlib
import json
import os
import plistlib
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]



def run(*arguments, capture=False, check=True):
    """Run a distribution tool without logging credential-bearing arguments."""
    result = subprocess.run(
        arguments, cwd=ROOT, text=True, capture_output=capture, check=False
    )
    if check and result.returncode:
        raise RuntimeError(
            f"{Path(arguments[0]).name} failed (exit {result.returncode})."
        )
    return result


def source_checkpoint(action="packaging"):
    """Refuse to label modified/untracked maintained source as a committed build."""
    if run(
        "git", "status", "--porcelain", "--untracked-files=no", capture=True
    ).stdout.strip():
        raise RuntimeError(f"Commit tracked changes before {action}.")
    untracked = run(
        "git",
        "ls-files",
        "--others",
        "--exclude-standard",
        "--",
        "Sources",
        "Tests",
        "Tools",
        "script",
        "Resources",
        "Package.swift",
        "Package.resolved",
        "Makefile",
        capture=True,
    ).stdout
    if untracked.strip():
        raise RuntimeError(f"Commit maintained source files before {action}.")
    return run("git", "rev-parse", "HEAD", capture=True).stdout.strip()


def create_bundle(directory, binary_directory, version, revision):
    """Package the release executable and its exact runtime resources."""
    app = directory / "L337.app"
    contents = app / "Contents"
    macos = contents / "MacOS"
    resources = contents / "Resources"
    macos.mkdir(parents=True)
    resources.mkdir()
    shutil.copy2(binary_directory / "L337", macos / "L337")
    shutil.copytree(
        binary_directory / "L337_L337Core.bundle",
        resources / "L337_L337Core.bundle",
    )
    for source, name in [
        ("Resources/L337.icns", "L337.icns"),
        ("LICENSE", "LICENSE"),
        ("NOTICE.md", "NOTICE.md"),
    ]:
        shutil.copy2(ROOT / source, resources / name)
    info = {
        "CFBundleExecutable": "L337",
        "CFBundleIdentifier": "io.xyzzy.l337",
        "CFBundleName": "L337",
        "CFBundleDisplayName": "L337",
        "CFBundlePackageType": "APPL",
        "CFBundleIconFile": "L337.icns",
        "CFBundleShortVersionString": version,
        "CFBundleVersion": version,
        "LSMinimumSystemVersion": "14.0",
        "NSPrincipalClass": "NSApplication",
        "NSHighResolutionCapable": True,
        "L337SourceRevision": revision,
    }
    with (contents / "Info.plist").open("wb") as stream:
        plistlib.dump(info, stream)
    return app


def bundle_resources(app):
    """Resolve SwiftPM's flat or nested macOS resource bundle."""
    bundle = app / "Contents/Resources/L337_L337Core.bundle"
    return bundle / "Contents/Resources" if (bundle / "Contents/Resources").is_dir() else bundle


def _manifest_parts(tokens):
    """Split literal Swift arguments/array items without evaluating the manifest."""
    parts, current, stack = [], [], []
    closing = {"(": ")", "[": "]", "{": "}"}
    for token in tokens:
        if token == "," and not stack:
            if current:
                parts.append(current)
                current = []
            continue
        if token in closing:
            stack.append(closing[token])
        elif token in closing.values():
            if not stack or stack.pop() != token:
                raise RuntimeError("Unbalanced Package.swift resource declaration")
        current.append(token)
    if stack:
        raise RuntimeError("Unbalanced Package.swift resource declaration")
    if current:
        parts.append(current)
    return parts


def _manifest_call_end(tokens, start):
    depth = 0
    for index in range(start, len(tokens)):
        if tokens[index] == "(":
            depth += 1
        elif tokens[index] == ")":
            depth -= 1
            if depth == 0:
                return index
    raise RuntimeError("Unbalanced Package.swift target declaration")


def _manifest_tokens(text):
    """Scan strings and nested Swift comments in one bounded, nonrecursive pass."""
    tokens, index = [], 0
    word = re.compile(r"[A-Za-z_]\w*")
    while index < len(text):
        if text[index].isspace():
            index += 1
        elif text.startswith("//", index):
            end = text.find("\n", index + 2)
            index = len(text) if end < 0 else end + 1
        elif text.startswith("/*", index):
            depth = 1
            index += 2
            while depth and index < len(text):
                if text.startswith("/*", index):
                    depth += 1
                    index += 2
                elif text.startswith("*/", index):
                    depth -= 1
                    index += 2
                else:
                    index += 1
            if depth:
                raise RuntimeError("Unterminated Package.swift block comment")
        elif text[index] == '"':
            start = index
            index += 1
            while index < len(text):
                if text[index] == "\\":
                    index += 2
                elif text[index] == '"':
                    index += 1
                    tokens.append(text[start:index])
                    break
                else:
                    index += 1
            else:
                raise RuntimeError("Unterminated Package.swift string")
        else:
            match = word.match(text, index)
            if match:
                tokens.append(match.group())
                index = match.end()
            else:
                tokens.append(text[index])
                index += 1
    return tokens


def resource_declarations(source_root):
    """Read only L337Core's explicit .copy/.process literals; unsupported syntax refuses."""
    text = (Path(source_root) / "Package.swift").read_text()
    tokens = _manifest_tokens(text)
    targets = []
    for index in range(len(tokens) - 2):
        if tokens[index:index + 3] != [".", "target", "("]:
            continue
        end = _manifest_call_end(tokens, index + 2)
        arguments = _manifest_parts(tokens[index + 3:end])
        if ["name", ":", '"L337Core"'] not in arguments:
            continue
        resources = [part[2:] for part in arguments if part[:2] == ["resources", ":"]]
        if len(resources) != 1 or resources[0][:1] != ["["] or resources[0][-1:] != ["]"]:
            raise RuntimeError("L337Core resources must be one literal array in Package.swift")
        targets.append(_manifest_parts(resources[0][1:-1]))
    if len(targets) != 1 or not targets[0]:
        raise RuntimeError("Expected one nonempty L337Core resource declaration")
    declarations = []
    for part in targets[0]:
        if (len(part) != 5 or part[0] != "." or part[1] not in ("copy", "process")
                or part[2] != "(" or part[4] != ")"):
            raise RuntimeError("Unsupported L337Core resource declaration in Package.swift")
        try:
            path = json.loads(part[3])
        except (ValueError, TypeError) as error:
            raise RuntimeError("Resource paths must be literal strings") from error
        if (not isinstance(path, str) or not path.startswith("Resources/")
                or "\\" in path or any(piece in ("", ".", "..") for piece in path.split("/"))):
            raise RuntimeError(f"Invalid L337Core resource path: {path!r}")
        declarations.append((part[1], Path(*path.split("/")[1:])))
    return tuple(declarations)


def resource_targets(source_root):
    """Map every maintained file once to its exact copied/processed bundle location."""
    resources = Path(source_root) / "Sources/L337Core/Resources"
    declarations = resource_declarations(source_root)
    by_path = {}
    for rule, relative in declarations:
        if relative in by_path:
            raise RuntimeError(f"Resource must have exactly one Package.swift declaration: {relative}")
        by_path[relative] = rule
        path = resources / relative
        if path.is_symlink() or not path.exists():
            raise RuntimeError(f"Missing/invalid declared source resource: {relative}")
    result, owners = {}, {}
    for source in sorted(resources.rglob("*")):
        relative = source.relative_to(resources)
        if source.is_symlink():
            raise RuntimeError(f"Invalid symbolic source resource: {relative}")
        if not source.is_file():
            continue
        matches = [(by_path[path], path) for path in (relative, *relative.parents)
                   if path in by_path]
        if len(matches) != 1:
            raise RuntimeError(f"Resource must have exactly one Package.swift declaration: {relative}")
        rule, declared = matches[0]
        target = (Path(declared.name) / relative.relative_to(declared)
                  if rule == "copy" else Path(source.name))
        if target in owners:
            raise RuntimeError(f"Packaged resource destination collision: {owners[target]} and {relative}")
        result[relative] = target
        owners[target] = relative
    return result


def verify_resources(app, source_root=None):
    """Verify every maintained resource byte at its Package.swift-defined location."""
    from retired_hull_resources import verify_resource_tree

    root = Path(ROOT if source_root is None else source_root)
    targets = resource_targets(root)
    source_provenance = verify_resource_tree(root / "Sources/L337Core/Resources")
    bundle = bundle_resources(app)
    for relative, packaged in targets.items():
        source = root / "Sources/L337Core/Resources" / relative
        target = bundle / packaged
        if target.is_symlink() or not target.is_file() or source.read_bytes() != target.read_bytes():
            raise RuntimeError(f"Missing/changed packaged resource: {relative}")
    return {"source": source_provenance, "bundle": verify_resource_tree(bundle)}


def package(options):
    """Build, sign, optionally notarize, then verify the extracted deliverable."""
    from release_version import artifact_prefix, load_plan, plan_digest

    revision = source_checkpoint()
    plan = load_plan(options.release_plan, current=True, root=ROOT)
    version = plan["version"]
    scratch = ROOT / ".build/distribution"
    build = [
        "swift",
        "build",
        "--configuration",
        "release",
        "--scratch-path",
        str(scratch),
        "--arch",
        "arm64",
        "--arch",
        "x86_64",
        "--jobs",
        "1",
        "-Xswiftc",
        "-disable-batch-mode",
    ]
    run(*build)
    binary_directory = Path(run(*build, "--show-bin-path", capture=True).stdout.strip())
    output = ROOT / "dist/macos"
    output.mkdir(parents=True, exist_ok=True)
    name = artifact_prefix(plan)
    archive = output / (name + ".zip")
    with tempfile.TemporaryDirectory(
        prefix="l337-package-", dir=ROOT / ".build"
    ) as temporary:
        directory = Path(temporary)
        app = create_bundle(directory, binary_directory, version, revision)
        verify_resources(app)
        run(
            "codesign",
            "--force",
            "--timestamp",
            "--sign",
            options.identity,
            str(app / "Contents/Resources/L337_L337Core.bundle"),
        )
        run(
            "codesign",
            "--force",
            "--timestamp",
            "--options",
            "runtime",
            "--sign",
            options.identity,
            str(app),
        )
        notarized = False
        if options.notary_profile:
            submission = directory / "submission.zip"
            run(
                "ditto",
                "-c",
                "-k",
                "--sequesterRsrc",
                "--keepParent",
                str(app),
                str(submission),
            )
            accepted = run(
                "xcrun",
                "notarytool",
                "submit",
                str(submission),
                "--keychain-profile",
                options.notary_profile,
                "--wait",
                "--output-format", "json",
                capture=True,
            )
            submission_result = json.loads(accepted.stdout)
            if submission_result.get("status") != "Accepted":
                raise RuntimeError("Apple did not accept the notarization submission.")
            report = run("xcrun", "notarytool", "log", submission_result["id"],
                         "--keychain-profile", options.notary_profile,
                         "--output-format", "json", capture=True)
            apple_log = json.loads(report.stdout)
            if apple_log.get("status") != "Accepted":
                raise RuntimeError("Apple's notarization log did not confirm acceptance.")
            (output / (name + "-notarization.json")).write_text(json.dumps(apple_log, indent=2) + "\n")
            run("xcrun", "stapler", "staple", str(app))
            notarized = True
        run(
            "ditto",
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            str(app),
            str(archive),
        )
        if archive.stat().st_size >= 95 * 1024 * 1024:
            raise RuntimeError(
                "Archive exceeds the repository's 95 MiB packaging limit."
            )
        extracted = directory / "extracted"
        run("ditto", "-x", "-k", str(archive), str(extracted))
        delivered = extracted / "L337.app"
        run("codesign", "--verify", "--strict", "--deep", "--verbose=2", str(delivered))
        details = run("codesign", "-dvv", str(delivered), capture=True).stderr
        if (
            "Authority=Developer ID Application:" not in details
            or "runtime" not in details
            or "Timestamp=" not in details
        ):
            raise RuntimeError(
                "Expected a timestamped Developer ID signature with hardened runtime."
            )
        architectures = run(
            "lipo", "-archs", str(delivered / "Contents/MacOS/L337"), capture=True
        ).stdout.split()
        if set(architectures) != {"arm64", "x86_64"}:
            raise RuntimeError("Universal artifact is missing an architecture.")
        build_versions = run(
            "xcrun",
            "vtool",
            "-show-build",
            str(delivered / "Contents/MacOS/L337"),
            capture=True,
        ).stdout
        minimums = re.findall(r"minos\s+([0-9.]+)", build_versions)
        if minimums != ["14.0", "14.0"]:
            raise RuntimeError("Both executable slices must target macOS 14.0.")
        verify_resources(delivered)
        run(str(delivered / "Contents/MacOS/L337"), "--diagnostics")
        gatekeeper = run(
            "spctl",
            "--assess",
            "--type",
            "execute",
            "--verbose=2",
            str(delivered),
            capture=True,
            check=False,
        )
        if notarized:
            run("xcrun", "stapler", "validate", str(delivered))
            if gatekeeper.returncode:
                raise RuntimeError(
                    "Notarized artifact did not pass Gatekeeper assessment."
                )
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        (output / (name + ".sha256")).write_text(digest + "  " + archive.name + "\n")
        manifest = {
            "appVersion": version,
            "sourceRevision": revision,
            "releasePlanSha256": plan_digest(plan),
            "builtAtUTC": datetime.datetime.now(datetime.UTC).isoformat(),
            "minimumMacOS": "14.0",
            "verifiedMachOMinimums": minimums,
            "architectures": sorted(architectures),
            "archive": archive.name,
            "archiveBytes": archive.stat().st_size,
            "sha256": digest,
            "signature": "Developer ID Application",
            "signatureDetails": [
                "Executable=L337.app/Contents/MacOS/L337"
                if line.startswith("Executable=")
                else line
                for line in details.splitlines()
            ],
            "hardenedRuntime": True,
            "secureTimestamp": True,
            "notarized": notarized,
            "gatekeeperAccepted": gatekeeper.returncode == 0,
            "gatekeeperAssessment": (gatekeeper.stdout + gatekeeper.stderr)
            .strip()
            .replace(str(delivered), "L337.app"),
            "verification": "Extracted ZIP: strict deep signature, architectures, exact resources and diagnostics passed.",
        }
        (output / (name + ".json")).write_text(json.dumps(manifest, indent=2) + "\n")
        (output / (name + "-release-plan.json")).write_text(json.dumps(plan, indent=2) + "\n")
        print(
            f"Signed package: {archive.relative_to(ROOT)} ({archive.stat().st_size:,} bytes)"
        )
        print(
            f"Source checkpoint: {revision}; notarized: {notarized}; Gatekeeper accepted: {gatekeeper.returncode == 0}"
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release-plan", type=Path, default=ROOT / "dist/release-plan.json")
    parser.add_argument(
        "--identity",
        default=os.environ.get(
            "ELITE_SIGNING_IDENTITY",
            "Developer ID Application: Steve Clarke (4MEB7MUTAV)",
        ),
    )
    parser.add_argument(
        "--notary-profile", default=os.environ.get("ELITE_NOTARY_PROFILE")
    )
    options = parser.parse_args()
    try:
        package(options)
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Packaging failed: {error}\n")


if __name__ == "__main__":
    main()
