"""Prepare an ephemeral physical runner with an immutable, host-owned exact-head hook."""

import argparse
from contextlib import contextmanager
from contextvars import ContextVar
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import plistlib
import shlex
import signal
import subprocess
import tarfile
import time
import uuid

import native_runner

ROOT = Path(__file__).resolve().parents[2]
HOME_ROOT = native_runner.diagnostic_custody_root().parent
RUNNER = HOME_ROOT / "native-runner"
AUTHORIZATION_ROOT = Path.home() / "Library/EliteNativeAuthorization"
DEVELOPER = "/Applications/Xcode.app/Contents/Developer"


def output(*args: str, environment: dict) -> str:
    """Capture non-secret tool identities without shell interpretation."""
    _require_provisioning(executor=True)
    return subprocess.check_output(args, cwd=ROOT, env=environment, text=True,
                                   stderr=subprocess.PIPE).strip()


def ensure_owned_directory(path: Path) -> None:
    """Create private trust directories and reject writable or substituted parents."""
    if path.is_symlink():
        raise ValueError("Runner trust directory must be physical.")
    if not path.exists():
        ensure_owned_directory(path.parent)
        path.mkdir(mode=0o700)
    if (not path.is_dir() or path.stat().st_uid != os.getuid()
            or path.stat().st_mode & 0o022):
        raise ValueError("Runner trust directory must be owned and not publicly writable.")


def _prepare_locked(approved: str, archive: Path, archive_hash: str, reviewed_policy=None, policy_sha256=None, registered=False, stale=None) -> Path:
    """Install only a verified runner archive and reviewed guard into dedicated owned paths."""
    if not re.fullmatch(r"[0-9a-f]{40}", approved):
        raise ValueError("Invalid approved source identity.")
    if not re.fullmatch(r"[0-9a-f]{64}", archive_hash):
        raise ValueError("A verified runner archive digest is required.")
    environment = dict(os.environ, DEVELOPER_DIR=DEVELOPER)
    if output("git", "rev-parse", "HEAD", environment=environment) != approved:
        raise ValueError("Prepare from the exact approved checkout.")
    if output("git", "status", "--porcelain", environment=environment):
        raise ValueError("Prepare from a clean committed checkout.")
    guard = ROOT / "Tools/CI/native_runner.py"
    archive = archive.resolve(strict=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != archive_hash:
        raise ValueError("Runner archive digest differs from the verified release asset.")
    authorization = AUTHORIZATION_ROOT / approved
    if any(character.isspace() for character in str(authorization)):
        raise ValueError("The runner dispatches its hook through a shell; its path must not contain whitespace.")
    if any(character.isspace() for character in str(RUNNER)):
        raise ValueError("The runner dispatches temporary scripts through a shell; its root must not contain whitespace.")
    guard_copy = authorization / "guard.py"
    policy = authorization / "policy.json"
    hook = authorization / "job-started.sh"
    guard_bytes = guard.read_bytes()
    expected_policy = {
        "approved_head": approved, "runner_root": str(RUNNER), "developer_dir": DEVELOPER,
        "swift": output("swift", "--version", environment=environment),
        "sdk": output("xcrun", "--sdk", "macosx", "--show-sdk-version", environment=environment),
        "guard_sha256": hashlib.sha256(guard_bytes).hexdigest(),
        "runner_archive_sha256": archive_hash,
    }
    helpers = []
    if reviewed_policy is not None:
        if guard.is_symlink():
            raise ValueError("Reviewed guard source must be a physical file.")
        expected_policy = reviewed_recoverable_policy(reviewed_policy, policy_sha256, expected_policy)
        authorization = authorization / ("recoverable-" + policy_sha256)
        guard_copy, policy, hook = (authorization / name for name in ("native_runner.py", "policy.json", "job-started.sh"))
        helpers = [(authorization / name, (ROOT / "Tools/CI" / name).read_bytes(), 0o400)
                   for name in expected_policy["recoverable_activation"]["guard_files"]]
    policy_bytes = (json.dumps(expected_policy, indent=2) + "\n").encode()
    hook_bytes = ("#!/bin/bash\nset -euo pipefail\nexec /usr/bin/python3 "
                  + shlex.quote(str(guard_copy)) + " --policy " + shlex.quote(str(policy)) + "\n").encode()
    if reviewed_policy is not None:
        hook_bytes = session_hook(policy, guard_copy)
    ensure_owned_directory(HOME_ROOT)
    ensure_owned_directory(authorization.parent)
    if RUNNER.is_symlink():
        raise ValueError("Runner directory must be physical.")
    if RUNNER.exists():
        if (not RUNNER.is_dir() or RUNNER.stat().st_uid != os.getuid()
                or RUNNER.stat().st_mode & 0o022):
            raise ValueError("Existing runner directory is not owned by this setup.")
        marker = RUNNER / ".elite-native-owner"
        if marker.is_symlink() or not marker.is_file() or marker.read_text() != "stephenlclarke/l337\n":
            raise ValueError("Existing runner ownership marker differs.")
        if (RUNNER / ".runner").exists() or (RUNNER / ".runner").is_symlink():
            if not (reviewed_policy is not None and registered):
                raise ValueError("The previous runner registration is still active.")
            require_registration(expected_policy)
            if stale is not None and (
                    getattr(_require_provisioning(executor=True), 'stale_reuse', None) is not stale
                    or expected_policy != stale['policy']):
                raise ValueError("Unwitnessed stale-registration transition.")
    else:
        RUNNER.mkdir(mode=0o700)
        with tarfile.open(archive) as source:
            source.extractall(RUNNER, filter="data")
        (RUNNER / ".elite-native-owner").write_text("stephenlclarke/l337\n")
    verify_installed_archive(RUNNER, archive)
    installation = RUNNER / ".elite-native-installation.json"
    installation_bytes = (json.dumps({"archive_sha256": archive_hash}) + "\n").encode()
    if installation.is_symlink():
        raise ValueError("Installation provenance must be physical.")
    if installation.exists():
        if (not installation.is_file() or installation.stat().st_uid != os.getuid()
                or installation.stat().st_mode & 0o777 != 0o400
                or installation.read_bytes() != installation_bytes):
            raise ValueError("Existing immutable installation provenance differs.")
    else:
        with installation.open("xb") as destination:
            destination.write(installation_bytes)
        installation.chmod(0o400)
    files = [(guard_copy, guard_bytes, 0o500), (policy, policy_bytes, 0o400),
             (hook, hook_bytes, 0o500), *helpers]
    if authorization.is_symlink():
        raise ValueError("Authorization directory must be physical.")
    if authorization.exists():
        ensure_owned_directory(authorization)
        for path, expected, mode in files:
            if (path.is_symlink() or not path.is_file() or path.stat().st_uid != os.getuid()
                    or path.stat().st_mode & 0o777 != mode or path.read_bytes() != expected):
                raise ValueError("Existing immutable authorization differs; preserving it.")
    else:
        ensure_owned_directory(authorization.parent)
        authorization.mkdir(parents=True, exist_ok=False, mode=0o700)
        for path, data, mode in files:
            with path.open("xb") as destination:
                destination.write(data)
                destination.flush()
                os.fsync(destination.fileno())
            path.chmod(mode)
    if (RUNNER / ".env").is_symlink():
        raise ValueError("Runner environment file is not physical.")
    environment_bytes = "ACTIONS_RUNNER_HOOK_JOB_STARTED=" + str(hook) + "\nDEVELOPER_DIR=" + DEVELOPER + "\n"
    if stale is not None:
        _replace_stale_hook(stale, policy, hook)
        return policy
    if registered:
        if (RUNNER / ".env").read_bytes() != environment_bytes.encode():
            _require_reused_environment(expected_policy, policy, hook)
        return policy  # A resumed registration never rewrites unrelated environment keys.
    (RUNNER / ".env").write_text(environment_bytes)
    (RUNNER / ".env").chmod(0o600)
    return policy


def prepare(approved: str, archive: Path, archive_hash: str, reviewed_policy=None, policy_sha256=None, registered=False) -> Path:
    """Acquire common custody before the first source/tool probe or installation."""
    with recoverable_control(), quiescent_legacy():
        if registered:
            if reviewed_policy is None:
                raise ValueError("A caller flag cannot authorize an existing registration.")
            _registered_slot_proof(owned_json(reviewed_policy))
        return _prepare_locked(approved, archive, archive_hash, reviewed_policy, policy_sha256, registered)


def verify_installed_archive(root: Path, archive: Path) -> None:
    """Use the same member validation at preparation and actual first-hook admission."""
    native_runner.verify_runner_archive(root, archive)


def _register_locked(runner_name="elite-mbp-native", deadline=None, descriptors=()) -> None:
    """Use one repository registration token without printing or persisting it ourselves."""
    _require_provisioning(executor=True)
    def bounds():
        if deadline is None:
            return {}
        remaining = deadline - time.time()
        if remaining <= 0:
            raise ValueError("Registration deadline expired.")
        return {"timeout": remaining, "pass_fds": tuple(descriptors)}
    result = subprocess.run(
        ["gh", "api", "--method", "POST", "repos/stephenlclarke/l337/actions/runners/registration-token"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **bounds())
    if result.returncode:
        raise ValueError("Repository runner registration token was unavailable.")
    token = json.loads(result.stdout)["token"]
    environment = dict(os.environ, DEVELOPER_DIR=DEVELOPER)
    configured = subprocess.run(
        [str(RUNNER / "config.sh"), "--url", "https://github.com/stephenlclarke/l337",
         "--token", token, "--name", runner_name, "--labels", "elite-native",
         "--work", "_work", "--unattended", "--ephemeral", "--disableupdate"],
        cwd=RUNNER, env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, **bounds())
    if configured.returncode:
        raise ValueError("Ephemeral runner registration failed.")
    print("Ephemeral native runner registered with its host-owned exact-head hook.")


def register_and_run(run: bool, runner_name="elite-mbp-native", deadline=None, descriptors=()) -> None:
    """Configure under both leases, then release executor custody before listening."""
    with recoverable_control() as control:
        if run and _require_provisioning().executor is not None:
            raise ValueError("A listener cannot inherit a parent-held executor lease.")
        with quiescent_legacy():
            _register_locked(runner_name, deadline, (*descriptors, control.fileno()))
        if run:
            _require_provisioning()
            remaining = None if deadline is None else deadline - time.time()
            if remaining is not None and remaining <= 0:
                raise ValueError("Registration deadline expired before listening.")
            completed = subprocess.run([str(RUNNER / "run.sh"), "--once"], cwd=RUNNER,
                env={**{key: value for key, value in os.environ.items() if key not in ("GH_TOKEN", "GITHUB_TOKEN")},
                     "DEVELOPER_DIR": DEVELOPER}, pass_fds=(control.fileno(),), timeout=remaining)
            if completed.returncode:
                raise ValueError("Ephemeral runner process failed.")



RECOVERABLE_ROLES = {"native_checks", "prepare_thread", "prepare_address", "native_phase",
                     "thread_shards", "address_shards", "native_aggregate"}
ASAN_RECOVERABLE_ROLES = {"native_checks", "prepare_address", "address_shards"}
NORMAL_CI_ROLES = {"native_checks"}
MAX_SESSION_SECONDS = 7 * 86400


def owned_json(path):
    path = Path(path)
    if not path.is_absolute() or path != path.resolve():
        raise ValueError("Owned input must be an absolute physical path.")
    from native_runner import require_owned_activation_file
    require_owned_activation_file(path)
    if path.stat().st_mode & 0o777 != 0o400:
        raise ValueError("Reviewed/session input must be immutable and owned.")
    return json.loads(path.read_text())


def publish_json(path, value, immutable=False):
    """Keep budget/session state durable before any registration can occur."""
    ensure_owned_directory(path.parent)
    if path.is_symlink():
        raise ValueError("Session state must be physical.")
    temporary = path.with_name(path.name + ".pending-" + str(uuid.uuid4()))
    with temporary.open("x") as destination:
        json.dump(value, destination, sort_keys=True, allow_nan=False)
        destination.write("\n")
        destination.flush()
        os.fsync(destination.fileno())
    temporary.chmod(0o400 if immutable else 0o600)
    temporary.replace(path)
    descriptor = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(descriptor)
    finally:
        os.close(descriptor)


def reviewed_recoverable_policy(path, checksum, base):
    """Install an explicitly reviewed contract; never synthesize a broader authorization."""
    from native_runner import policy_digest, backend_descriptor, read_local_components_binding, LOCAL_COMPONENTS_BACKEND, LOCAL_COMPONENT_ROLES
    path = Path(path)
    if path.is_relative_to(ROOT) or path.is_relative_to(RUNNER):
        raise ValueError("Reviewed policy must be outside checkout and runner data.")
    value = owned_json(path)
    if (not re.fullmatch(r"[0-9a-f]{64}", checksum or "")
            or hashlib.sha256(path.read_bytes()).hexdigest() != checksum
            or set(value) != set(base) | {"recoverable_activation", "recoverable_shards"}
            or any(value[name] != expected for name, expected in base.items())):
        raise ValueError("Reviewed recoverable policy differs from source/archive/toolchain.")
    activation, config = value["recoverable_activation"], value["recoverable_shards"]
    required = {"schema", "enabled", "revoked", "expires_at", "head", "workflow_ref", "workflow_sha256",
                "reusable_workflow_sha256", "manifest_sha256", "runners", "assignment_root", "guard_files"}
    if (not required <= set(activation) or set(activation) - required - {"pr_head", "sanitizer_backend", "local_components"}
            or type(activation["schema"]) is not int or activation["schema"] != 1
            or activation["enabled"] is not True or activation["revoked"] is not False
            or type(activation["expires_at"]) not in (int, float) or not math.isfinite(activation["expires_at"])
            or not time.time() < activation["expires_at"] <= time.time() + MAX_SESSION_SECONDS
            or activation["head"] != base["approved_head"]):
        raise ValueError("Recoverable activation is missing, expired or outside its finite bound.")
    prefix = "stephenlclarke/l337/.github/workflows/ci.yml@"
    if not activation["workflow_ref"].startswith(prefix):
        raise ValueError("Installer supports only the actual required CI caller.")
    ref = activation["workflow_ref"].removeprefix(prefix)
    if ref != "refs/heads/main" and not re.fullmatch(r"refs/pull/[1-9][0-9]*/merge", ref):
        raise ValueError("Recoverable CI ref is outside main/internal PR execution.")
    if ref == "refs/heads/main" and "pr_head" in activation:
        raise ValueError("Main approval must not substitute a PR source identity.")
    if ref.startswith("refs/pull/") and not re.fullmatch(r"[0-9a-f]{40}", activation.get("pr_head", "")):
        raise ValueError("PR source and execution heads must be separately approved.")
    for name, field in (("ci.yml", "workflow_sha256"), ("recoverable-quality.yml", "reusable_workflow_sha256")):
        source = ROOT / ".github/workflows" / name
        if source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != activation[field]:
            raise ValueError("Reviewed caller/called workflow bytes changed.")
    helpers = {"recoverable_shards.py", "sanitizer_checkpoints.py", "quality_phase_checkpoints.py", "crash_artifacts.py"}
    if set(activation["guard_files"]) != helpers:
        raise ValueError("Recoverable installation requires all five pinned Python files.")
    for name, digest in activation["guard_files"].items():
        source = ROOT / "Tools/CI" / name
        if source.is_symlink() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
            raise ValueError("Reviewed helper source bytes changed.")
    if len(activation["runners"]) != 1:
        raise ValueError("This installer reserves exactly one physical runner.")
    runner_name, instance = next(iter(activation["runners"].items()))
    backend, _ = backend_descriptor(value)
    allowed_roles = (LOCAL_COMPONENT_ROLES,) if backend == LOCAL_COMPONENTS_BACKEND else (RECOVERABLE_ROLES, ASAN_RECOVERABLE_ROLES, NORMAL_CI_ROLES)
    if (not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", runner_name)
            or set(instance) != {"workspace", "jobs"}
            or instance["workspace"] != str(RUNNER / "_work/l337/l337")
            or set(instance["jobs"]) not in allowed_roles
            or len(instance["jobs"]) != len(set(instance["jobs"]))):
        raise ValueError("Recoverable runner/workspace/role reservation differs.")
    if backend == native_runner.GITHUB_BACKEND and set(instance['jobs']) == NORMAL_CI_ROLES:
        if native_runner.phase_profile(value, 'normal') is None:
            raise ValueError('Current CI role reservation requires both normal/leaks phase profiles')
    if (type(config.get("schema")) is not int or config.get("schema") != 1 or set(config) - {"schema", "host", "cache", "legacy_cache", "workers", "admission", "planning", "phase_profiles"}
            or not config.get("workers")
            or not re.fullmatch(r"[0-9A-F]{8}(?:-[0-9A-F]{4}){3}-[0-9A-F]{12}", config.get("host", ""))):
        raise ValueError("Recoverable execution needs approved physical worker identities.")
    spaces = [Path(config[name]) for name in ("cache", "legacy_cache")]
    spaces += [*(Path(value) for value in config["workers"].values()), Path(activation["assignment_root"])]
    protected = [ROOT, RUNNER, AUTHORIZATION_ROOT, HOME_ROOT / "recoverable-sessions"]
    if (any(not path.is_absolute() or path != path.resolve() for path in spaces)
            or any(a.is_relative_to(b) or b.is_relative_to(a) for a in spaces for b in protected)
            or any(a.is_relative_to(b) or b.is_relative_to(a) for i, a in enumerate(spaces) for b in spaces[i + 1:])):
        raise ValueError("Reviewed execution/assignment paths overlap mutable or authorization data.")
    manifest = {name: activation[name] for name in ("schema", "enabled", "revoked", "expires_at", "head", "workflow_sha256",
                "reusable_workflow_sha256", "runners", "assignment_root")}
    manifest.update(ref=ref, workflow_file="ci.yml")
    if "pr_head" in activation:
        manifest["pr_head"] = activation["pr_head"]
    for name in ("sanitizer_backend", "local_components"):
        if name in activation:
            manifest[name] = activation[name]
    if policy_digest(manifest) != activation["manifest_sha256"]:
        raise ValueError("Reviewed published activation manifest is inconsistent.")
    if backend == LOCAL_COMPONENTS_BACKEND:
        read_local_components_binding(value)
    return value


_PROVISIONING = ContextVar("native_provisioning_custody", default=None)
_PROVISIONING_SEAL = object()


class _ProvisioningCustody:
    def __init__(self, lock, witness, seal):
        if seal is not _PROVISIONING_SEAL:
            raise ValueError("Untrusted provisioning custody.")
        self.lock, self.controller = lock, witness
        self.executor, self.executor_path = None, None


def _require_provisioning(executor=False):
    custody = _PROVISIONING.get()
    if not isinstance(custody, _ProvisioningCustody):
        raise ValueError("Provisioning requires witnessed controller custody.")
    custody.controller.verify()
    if executor:
        if custody.executor is None:
            raise ValueError("Provisioning requires witnessed executor custody.")
        custody.executor.verify()
    native_runner.require_diagnostic_custody_clear()
    return custody


def _operator_only():
    # These entrypoints take controller custody. Actual NativeAuthority jobs do not.
    job_keys = {"GITHUB_JOB", "GITHUB_RUN_ID", "GITHUB_WORKFLOW_REF"}
    if (os.environ.get("GITHUB_ACTIONS") == "true" or job_keys.intersection(os.environ)
            or any(key.startswith("RUNNER_") for key in os.environ)):
        raise ValueError("Controller-needing provisioning is ineligible inside a listener job.")


@contextmanager
def recoverable_control():
    """Reuse only a live in-process acquisition; the listener retains controller custody."""
    _operator_only()
    if _PROVISIONING.get() is not None:
        yield _require_provisioning().lock
        return
    ensure_owned_directory(HOME_ROOT)
    path = HOME_ROOT / "recoverable-control.lock"
    descriptor = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "a") as lock:
        info = os.fstat(lock.fileno())
        if path != path.resolve() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Recoverable control lease is foreign.")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with native_runner._diagnostic_lease_context(lock, "controller") as witness:
            token = _PROVISIONING.set(_ProvisioningCustody(lock, witness, _PROVISIONING_SEAL))
            try:
                _require_provisioning()
                yield lock
            finally:
                _PROVISIONING.reset(token)


@contextmanager
def quiescent_legacy(policy=None):
    """Use the existing physical shared executor, always after controller acquisition."""
    custody = _require_provisioning()
    path = HOME_ROOT / "sanitizer-checkpoints/executor.lock"
    if policy is not None and Path(policy["recoverable_shards"]["legacy_cache"]) / "executor.lock" != path:
        raise ValueError("Reviewed provisioning must use the common physical executor lease.")
    if custody.executor is not None:
        if custody.executor_path != path:
            raise ValueError("Nested executor custody differs.")
        _require_provisioning(executor=True)
        yield
        return
    descriptor = os.open(path, os.O_RDWR | os.O_NOFOLLOW)
    with os.fdopen(descriptor, "a") as lock:
        info = os.fstat(lock.fileno())
        if path != path.resolve() or info.st_uid != os.getuid() or info.st_mode & 0o022:
            raise ValueError("Existing physical executor lease is foreign.")
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with native_runner._diagnostic_lease_context(lock, "executor") as witness:
            custody.executor, custody.executor_path = witness, path
            try:
                _require_provisioning(executor=True)
                yield
            finally:
                custody.executor = custody.executor_path = None


def session_hook(policy_path, guard_path):
    """Admit the exact session and host without requiring unavailable job-level env."""
    return ("#!/bin/bash\nset -euo pipefail\nexec /usr/bin/python3 -E -s -B "
            + shlex.quote(str(guard_path)) + " --policy " + shlex.quote(str(policy_path)) + " --admit\n").encode()


def require_registration(policy):
    registration = RUNNER / ".runner"
    from native_runner import require_owned_activation_file
    require_owned_activation_file(registration)
    value = json.loads(registration.read_text(encoding="utf-8-sig"))
    name = next(iter(policy["recoverable_activation"]["runners"]))
    if value.get("agentName") != name or value.get("gitHubUrl") != "https://github.com/stephenlclarke/l337" or value.get("workFolder") != "_work":
        raise ValueError("Existing registration is not this approved repository/runner.")


def session_run_active(policy, binding):
    """Read only this exact approved run; a new attempt requires a new session."""
    _require_provisioning()
    result = subprocess.run(["gh", "api", "repos/stephenlclarke/l337/actions/runs/" + binding["run_id"]],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            timeout=max(0, binding["expires_at"] - time.time()))
    if result.returncode:
        raise ValueError("Workflow run metadata is unavailable; renewal stopped.")
    run = json.loads(result.stdout)
    activation = policy["recoverable_activation"]
    expected = activation.get("pr_head", policy["approved_head"])
    workflow = ".github/workflows/ci.yml"
    ref = activation["workflow_ref"].split("@", 1)[1]
    paths = {workflow, workflow + "@" + ref, workflow + "@" + str(run.get("head_branch")), workflow + "@" + expected}
    if (str(run["id"]) != binding["run_id"] or str(run["run_attempt"]) != binding["run_attempt"]
            or run.get("path") not in paths or run.get("event") not in (("pull_request",) if "pr_head" in activation else ("push", "workflow_dispatch"))
            or run["head_sha"] != expected or run["repository"]["full_name"] != "stephenlclarke/l337"
            or str(run["actor"]["id"]) != "22142777" or str(run["triggering_actor"]["id"]) != "22142777"):
        raise ValueError("Workflow run/attempt/source differs; renewal stopped.")
    if run["status"] == "completed":
        return False
    if run["status"] not in ("queued", "in_progress", "waiting"):
        raise ValueError("Workflow run is not active; renewal stopped.")
    return True


def _renew_locked(policy_path, run_id, attempt, maximum, expires, register, listen, lock):
    """Consume a finite durable slot before registration; preserve ambiguous listeners."""
    from native_runner import policy_digest
    policy = owned_json(policy_path)
    if (not re.fullmatch(r"[1-9][0-9]*", run_id or "") or not re.fullmatch(r"[1-9][0-9]*", attempt or "")
            or type(maximum) is not int or not 1 <= maximum <= 256 or type(expires) not in (int, float)
            or not math.isfinite(expires) or not time.time() < expires <= policy["recoverable_activation"]["expires_at"]):
        raise ValueError("A finite exact-run/attempt/job/expiry session is required.")
    root = HOME_ROOT / "recoverable-sessions"
    ensure_owned_directory(root)
    binding_path = root / (policy_digest(policy) + "-" + run_id + "-" + attempt + ".json")
    binding = dict(schema=1, policy_sha256=policy_digest(policy), head=policy["approved_head"], run_id=run_id,
                   run_attempt=attempt, max_jobs=maximum, expires_at=expires)
    if binding_path.exists():
        if owned_json(binding_path) != binding:
            raise ValueError("Existing immutable session bounds differ; preserving them.")
    else:
        publish_json(binding_path, binding, immutable=True)
    state_path = binding_path.with_suffix(".state")
    if state_path.exists():
        from native_runner import require_owned_activation_file
        require_owned_activation_file(state_path)
        state = json.loads(state_path.read_text())
        if (set(state) != {"used", "phase"} or type(state["used"]) is not int or not 0 <= state["used"] <= maximum
                or state["phase"] not in ("idle", "registered", "running", "stopped")):
            raise ValueError("Session budget state is invalid.")
    else:
        state = {"used": 0, "phase": "idle"}
    if state["phase"] == "running":
        raise ValueError("Listener outcome is unresolved; preserve it and do not renew.")
    while time.time() < expires:
        with quiescent_legacy(policy):
            active = session_run_active(policy, binding)
        if not active:
            return {"used": state["used"], "reason": "workflow completed"}
        if state["phase"] != "registered":
            if not register or state["used"] >= maximum:
                return {"used": state["used"], "reason": "registration budget exhausted"}
            if (RUNNER / ".runner").exists() or (RUNNER / ".runner").is_symlink():
                raise ValueError("An existing registration must finish before renewal.")
            state.update(used=state["used"] + 1, phase="stopped")
            publish_json(state_path, state)
            publish_json(root / "ticket.json", {"binding": str(binding_path), "binding_sha256": hashlib.sha256(binding_path.read_bytes()).hexdigest(),
                         "ordinal": state["used"], "policy_sha256": policy_digest(policy)}, immutable=True)
            with quiescent_legacy(policy):
                try:
                    register_and_run(False, next(iter(policy["recoverable_activation"]["runners"])),
                                     deadline=expires, descriptors=(lock.fileno(),))
                except subprocess.TimeoutExpired:
                    state["phase"] = "running"
                    publish_json(state_path, state)
                    raise ValueError("Registration outcome is unresolved; no renewal authorized.") from None
            state["phase"] = "registered"
            publish_json(state_path, state)
        with quiescent_legacy(policy):
            _registered_slot_proof(policy)
        if not listen:
            return {"used": state["used"], "reason": "registered only"}
        state["phase"] = "running"
        publish_json(state_path, state)
        try:
            process = subprocess.Popen([str(RUNNER / "run.sh"), "--once"], cwd=RUNNER,
                                      env={**{key: value for key, value in os.environ.items() if key not in ("GH_TOKEN", "GITHUB_TOKEN")},
                                           "DEVELOPER_DIR": DEVELOPER}, pass_fds=(lock.fileno(),), start_new_session=True)
        except OSError:
            state["phase"] = "registered"
            publish_json(state_path, state)
            raise ValueError("Listener did not launch; registered slot retained.") from None
        while True:
            remaining = expires - time.time()
            if remaining <= 0:
                raise ValueError("Session expired with unresolved listener; no signals or renewal sent.")
            try:
                code = process.wait(timeout=min(30, remaining))
                break
            except subprocess.TimeoutExpired:
                if not session_run_active(policy, binding):
                    # Signal only our unreaped listener, within this session, never a native helper/group.
                    remaining = expires - time.time()
                    if remaining <= 0:
                        raise ValueError("Session expired with unresolved listener; no signal authorized.")
                    process.send_signal(signal.SIGINT)
                    try:
                        process.wait(timeout=min(30, remaining))
                    except subprocess.TimeoutExpired:
                        raise ValueError("Completed-run listener did not stop; no renewal authorized.") from None
                    state["phase"] = "stopped"
                    publish_json(state_path, state)
                    return {"used": state["used"], "reason": "workflow completed"}
        state["phase"] = "idle" if code == 0 else "stopped"
        publish_json(state_path, state)
        if code != 0:
            raise ValueError("Listener failed; raw runner logs and consumed budget retained.")
        if not register:
            return {"used": state["used"], "reason": "registered slot completed"}
    return {"used": state["used"], "reason": "session expired"}


def renew_recoverable(policy_path, run_id, attempt, maximum, expires, register, listen, lock=None):
    """Direct and nested renewal share the same actual controller acquisition."""
    with recoverable_control() as held:
        if lock is not None and lock is not held:
            raise ValueError("A supplied descriptor is not controller custody.")
        return _renew_locked(policy_path, run_id, attempt, maximum, expires, register, listen, held)


def _registered_slot_proof(policy):
    """Bind existing registration to the current immutable ticket and finite consumed slot."""
    from native_runner import policy_digest, require_owned_activation_file
    root = HOME_ROOT / "recoverable-sessions"
    ticket = owned_json(root / "ticket.json")
    if set(ticket) != {"binding", "binding_sha256", "ordinal", "policy_sha256"}:
        raise ValueError("Existing registration lacks an exact issued ticket.")
    path = Path(ticket["binding"])
    binding = owned_json(path)
    state_path = path.with_suffix(".state")
    require_owned_activation_file(state_path)
    state = json.loads(state_path.read_text())
    if (set(binding) != {"schema", "policy_sha256", "head", "run_id", "run_attempt", "max_jobs", "expires_at"}
            or type(binding["schema"]) is not int or binding["schema"] != 1
            or type(ticket["ordinal"]) is not int or binding["policy_sha256"] != policy_digest(policy)
            or binding["head"] != policy["approved_head"] or path.parent != root
            or path.name != policy_digest(policy) + "-" + binding["run_id"] + "-" + binding["run_attempt"] + ".json"
            or not re.fullmatch(r"[1-9][0-9]*", binding["run_id"])
            or not re.fullmatch(r"[1-9][0-9]*", binding["run_attempt"])
            or type(binding["max_jobs"]) is not int or not 1 <= binding["max_jobs"] <= 256
            or type(binding["expires_at"]) not in (int, float) or not math.isfinite(binding["expires_at"])
            or not time.time() < binding["expires_at"] <= policy["recoverable_activation"]["expires_at"]
            or set(state) != {"used", "phase"} or state["phase"] != "registered"
            or type(state["used"]) is not int or not 1 <= state["used"] <= binding["max_jobs"]
            or state_path.stat().st_mode & 0o777 != 0o600
            or ticket != {"binding": str(path), "binding_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "ordinal": state["used"], "policy_sha256": policy_digest(policy)}):
        raise ValueError("Existing registration/session/budget is not the current issued slot.")
    require_registration(policy)


def registered_session_slot(policy, args):
    """An existing registration is resumable only with its exact durable issued ticket."""
    from native_runner import policy_digest, require_owned_activation_file
    if not args.run:
        raise ValueError("Existing registration requires explicit --run of its issued session slot.")
    root = HOME_ROOT / "recoverable-sessions"
    path = root / (policy_digest(policy) + "-" + str(args.session_run_id) + "-" + str(args.session_run_attempt) + ".json")
    binding = owned_json(path)
    expected = dict(schema=1, policy_sha256=policy_digest(policy), head=policy["approved_head"],
                    run_id=args.session_run_id, run_attempt=args.session_run_attempt,
                    max_jobs=args.max_jobs, expires_at=args.session_expires_at)
    state_path = path.with_suffix(".state")
    require_owned_activation_file(state_path)
    state = json.loads(state_path.read_text())
    ticket = owned_json(root / "ticket.json")
    if (binding != expected or state.get("phase") != "registered"
            or ticket != {"binding": str(path), "binding_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                          "ordinal": state.get("used"), "policy_sha256": policy_digest(policy)}):
        raise ValueError("Existing registration is not this exact issued session; preserving it.")
    return True

# This transition reuses an observed registration; it never calls config.sh or requests a token.
STALE_VENDOR_FILES = ('.runner', '.credentials', '.credentials_rsaparams',
                      '.elite-native-owner', '.elite-native-installation.json', '.env')


def _pinned_bytes(path, digest, mode=None):
    path = Path(path)
    if path != path.resolve() or not re.fullmatch(r'[0-9a-f]{64}', digest or ''):
        raise ValueError('Stale-session input path or digest differs.')
    native_runner.require_owned_activation_file(path)
    with os.fdopen(os.open(path, os.O_RDONLY | os.O_NOFOLLOW), 'rb') as stream:
        before = os.fstat(stream.fileno())
        data = stream.read()
        after = os.fstat(stream.fileno())
    current = path.lstat()
    identity = lambda info: (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_mode)
    if (identity(before) != identity(after) or identity(after) != identity(current)
            or (mode is not None and before.st_mode & 0o777 != mode)
            or hashlib.sha256(data).hexdigest() != digest):
        raise ValueError('Stale-session bytes changed; preserve the registration.')
    return data


def _vendor_bytes(path, pin):
    if not isinstance(pin, dict) or set(pin) != {'sha256', 'device', 'inode', 'uid', 'mode'}:
        raise ValueError('Complete vendor file identity is required.')
    data = _pinned_bytes(path, pin['sha256'], pin['mode'])
    info = path.lstat()
    if (info.st_dev, info.st_ino, info.st_uid, info.st_mode & 0o777) != (pin['device'], pin['inode'], pin['uid'], pin['mode']):
        raise ValueError('Vendor file identity changed since review.')
    return data


def _pinned_ref(value, expected=None, mode=0o400):
    if not isinstance(value, dict) or set(value) != {'path', 'sha256'}:
        raise ValueError('An exact immutable stale-session reference is required.')
    path = Path(value['path'])
    if expected is not None and path != expected:
        raise ValueError('Stale-session reference names a different object.')
    return _pinned_bytes(path, value['sha256'], mode)


def _exclusive_json(path, value):
    """A durable exclusive claim makes interrupted or racing reuse fail closed."""
    ensure_owned_directory(path.parent)
    pending = path.with_name(path.name + '.pending-' + str(uuid.uuid4()))
    try:
        with pending.open('xb') as stream:
            stream.write((json.dumps(value, sort_keys=True, allow_nan=False) + '\n').encode())
            stream.flush()
            os.fsync(stream.fileno())
        pending.chmod(0o400)
        os.link(pending, path, follow_symlinks=False)
        descriptor = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    finally:
        pending.unlink(missing_ok=True)


def _require_reused_environment(policy, policy_path, hook):
    """An existing reuse receipt binds preserved extra keys; it grants no new slot."""
    _require_provisioning(executor=True)
    _registered_slot_proof(policy)
    ticket = owned_json(HOME_ROOT / 'recoverable-sessions/ticket.json')
    binding_path = Path(ticket['binding'])
    binding = owned_json(binding_path)
    receipt = owned_json(binding_path.with_suffix('.reuse.json'))
    if (receipt.get('kind') != 'preserved-registration-reuse-v1'
            or receipt.get('binding') != binding or receipt.get('policy') != str(policy_path)):
        raise ValueError('An active registration uses a different hook; preserving it.')
    data = _pinned_bytes(RUNNER / '.env', receipt['environment_sha256'], 0o600)
    for key, value in ((b'ACTIONS_RUNNER_HOOK_JOB_STARTED', str(hook).encode()),
                       (b'DEVELOPER_DIR', DEVELOPER.encode())):
        lines = [line for line in data.splitlines() if line.startswith(key + b'=')]
        if lines != [key + b'=' + value]:
            raise ValueError('The reused policy hook environment differs.')


def _stale_remote(path, expires):
    _require_provisioning(executor=True)
    result = subprocess.run(['gh', 'api', 'repos/stephenlclarke/l337/' + path],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                            timeout=max(0, expires - time.time()))
    if result.returncode:
        raise ValueError('Stale-session remote identity is unavailable.')
    return json.loads(result.stdout)


def _stale_live(context, installed=False):
    """Recheck under both leases; online alone never proves listener custody."""
    _require_provisioning(executor=True)
    plan, policy = context['plan'], context['policy']
    if context.get('lifecycle'):
        return _lifecycle_live(context, installed)
    expires = plan['new']['expires_at']
    if not time.time() < expires <= context['grant_expiry'] <= policy['recoverable_activation']['expires_at']:
        raise ValueError('Transition or grant expired before activation.')
    for path, digest in context['inputs']:
        _pinned_bytes(path, digest, 0o400)
    for name, digest in plan['old']['files'].items():
        if name == '.env' and installed:
            digest = context['new_environment_pin']
        path = RUNNER / name
        if digest is None:
            if path.exists() or path.is_symlink():
                raise ValueError('Previously absent vendor state appeared.')
        else:
            _vendor_bytes(path, digest)
    for key, expected in context['old_refs'].items():
        _pinned_ref(plan['old'][key], expected, 0o600 if key == 'state' else 0o500 if key == 'hook' else 0o400)
    registration = json.loads((RUNNER / '.runner').read_text(encoding='utf-8-sig'))
    require_registration(policy)
    if type(registration.get('agentId')) is not int or registration['agentId'] != plan['runner']['id']:
        raise ValueError('Vendor registration identity changed.')
    remote = _stale_remote('actions/runners/' + str(plan['runner']['id']), expires)
    keys = {'id', 'name', 'os', 'labels', 'status', 'busy'}
    if ({key: remote.get(key) for key in keys} != plan['runner']
            or remote.get('busy') is not False or remote.get('status') != 'online'):
        raise ValueError('Existing remote runner is missing, changed or busy.')
    old_run = _stale_remote('actions/runs/' + context['old_binding']['run_id']
                            + '/attempts/' + context['old_binding']['run_attempt'], expires)
    old_policy = context['old_policy']
    old_source = old_policy['recoverable_activation'].get('pr_head', old_policy['approved_head'])
    if (str(old_run.get('id')) != context['old_binding']['run_id']
            or str(old_run.get('run_attempt')) != context['old_binding']['run_attempt']
            or old_run.get('head_sha') != old_source or old_run.get('status') != 'completed'
            or old_run.get('event') != ('pull_request' if 'pr_head' in old_policy['recoverable_activation'] else 'push')
            or old_run.get('path') != '.github/workflows/ci.yml'
            or old_run.get('conclusion') not in {'success', 'failure', 'cancelled', 'timed_out', 'skipped', 'neutral', 'action_required', 'startup_failure'}
            or old_run.get('repository', {}).get('id') != 1416155405
            or old_run.get('repository', {}).get('full_name') != 'stephenlclarke/l337'
            or old_run.get('actor', {}).get('id') != 22142777
            or old_run.get('triggering_actor', {}).get('id') != 22142777):
        raise ValueError('Previous run is active, uncertain or belongs to another identity.')
    ref = policy['recoverable_activation']['workflow_ref'].split('@', 1)[1]
    head_ref = ref.removesuffix('/merge') + '/head'
    refs = output('git', 'ls-remote', 'https://github.com/stephenlclarke/l337.git', ref, head_ref,
                  environment=dict(os.environ))
    if set(refs.splitlines()) != {policy['approved_head'] + '\t' + ref, plan['new']['pr_head'] + '\t' + head_ref}:
        raise ValueError('Actual PR merge/source identity changed.')
    new_run = _stale_remote('actions/runs/' + plan['new']['run_id'], expires)
    if new_run.get('repository', {}).get('id') != 1416155405:
        raise ValueError('New run repository identity differs.')
    if not session_run_active(policy, context['binding']):
        raise ValueError('New exact run/attempt is not active.')
    # Controlled listeners retain the controller lease. Reject unowned listeners too.
    census = output('ps', '-axo', 'pid=,command=', environment=dict(os.environ))
    for line in census.splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2 or not fields[0].isdigit():
            raise ValueError('Local listener census is uncertain.')
        words = shlex.split(fields[1])
        if any(Path(word).name in {'Runner.Listener', 'Runner.Worker'}
               or word == str(RUNNER / 'run.sh') for word in words):
            raise ValueError('A local runner listener or worker is still present.')


def _stale_hook_bytes(context, policy_path, hook):
    custody = _require_provisioning(executor=True)
    if (getattr(custody, 'stale_reuse', None) is not context
            or policy_path != context['installed_policy']):
        raise ValueError('Stale reuse is outside its exact witnessed installation.')
    _stale_live(context)
    old = _vendor_bytes(RUNNER / '.env', context['plan']['old']['files']['.env'])
    expected = b'ACTIONS_RUNNER_HOOK_JOB_STARTED=' + str(context['old_hook']).encode()
    lines = old.splitlines(keepends=True)
    slots = [i for i, line in enumerate(lines) if line.startswith(b'ACTIONS_RUNNER_HOOK_JOB_STARTED=')]
    if len(slots) != 1 or lines[slots[0]].rstrip(b'\r\n') != expected:
        raise ValueError('The exact old hook binding changed.')
    index = slots[0]
    lines[index] = lines[index].replace(expected, b'ACTIONS_RUNNER_HOOK_JOB_STARTED=' + str(hook).encode(), 1)
    return old, b''.join(lines)


def _replace_stale_hook(context, policy_path, hook):
    old, new = _stale_hook_bytes(context, policy_path, hook)
    path = RUNNER / '.env'
    pending = path.with_name('.env.pending-' + str(uuid.uuid4()))
    try:
        with pending.open('xb') as stream:
            stream.write(new)
            stream.flush()
            os.fsync(stream.fileno())
        pending.chmod(0o600)
        if _vendor_bytes(path, context['plan']['old']['files']['.env']) != old:
            raise ValueError('Hook changed before atomic installation.')
        pending.replace(path)
        descriptor = os.open(RUNNER, os.O_RDONLY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)
    finally:
        pending.unlink(missing_ok=True)
    info = path.lstat()
    context['new_environment_sha256'] = hashlib.sha256(new).hexdigest()
    context['new_environment_pin'] = dict(sha256=context['new_environment_sha256'], device=info.st_dev,
                                          inode=info.st_ino, uid=info.st_uid, mode=info.st_mode & 0o777)


def _reuse_context(args, lifecycle=False):
    plan = json.loads(_pinned_bytes(args.stale_session_plan, args.stale_session_plan_sha256, 0o400))
    grant = json.loads(_pinned_bytes(args.stale_session_grant, args.stale_session_grant_sha256, 0o400))
    if (set(plan) != ({'schema', 'kind', 'new', 'old', 'runner', 'service'} if lifecycle else {'schema', 'kind', 'new', 'old', 'runner'}) or type(plan['schema']) is not int or plan['schema'] != 1
            or plan['kind'] != ('staged-service-handoff-v1' if lifecycle else 'stale-session-reuse-v1')
            or set(grant) != ({'schema', 'kind', 'plan_sha256', 'review', 'new', 'expires_at', 'revoked', 'human'} if lifecycle else {'schema', 'kind', 'plan_sha256', 'review', 'new', 'expires_at', 'revoked'})
            or type(grant['schema']) is not int or grant['schema'] != 1 or grant['kind'] != ('reviewed-service-handoff-grant-v1' if lifecycle else 'reviewed-stale-session-reuse-grant-v1')
            or grant['plan_sha256'] != args.stale_session_plan_sha256 or grant['new'] != plan['new']
            or grant['revoked'] is not False):
        raise ValueError('Transition plan, review or Root grant differs.')
    for path in (args.stale_session_plan, args.stale_session_grant, Path(grant['review']['path'])):
        if path.is_relative_to(ROOT) or path.is_relative_to(RUNNER):
            raise ValueError('Repository or runner data cannot supply transition approval.')
    _pinned_ref(grant['review'])
    new = plan['new']
    expected = dict(policy_sha256=args.recoverable_policy_sha256, head=args.approved_head,
                    run_id=args.session_run_id, run_attempt=args.session_run_attempt,
                    max_jobs=args.max_jobs, expires_at=args.session_expires_at)
    if (set(new) != set(expected) | ({'pr_head', 'hook', 'job_name'} if lifecycle else {'pr_head', 'hook'}) or any(new[k] != v for k, v in expected.items())
            or type(new['max_jobs']) is not int or not 1 <= new['max_jobs'] <= 256
            or any(not re.fullmatch(r'[1-9][0-9]*', new[k] or '') for k in ('run_id', 'run_attempt'))
            or type(new['expires_at']) not in (int, float) or not math.isfinite(new['expires_at'])
            or type(grant['expires_at']) not in (int, float) or not math.isfinite(grant['expires_at'])
            or not time.time() < new['expires_at'] <= grant['expires_at']):
        raise ValueError('Exact finite transition session bounds differ.')
    policy = json.loads(_pinned_bytes(args.recoverable_policy, args.recoverable_policy_sha256, 0o400))
    if (git_head := output('git', 'rev-parse', 'HEAD', environment=dict(os.environ))) != args.approved_head:
        raise ValueError('Transition checkout differs from approved execution.')
    if output('git', 'status', '--porcelain', environment=dict(os.environ)):
        raise ValueError('Transition requires a clean committed checkout.')
    archive = args.runner_archive.resolve(strict=True)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != args.archive_sha256:
        raise ValueError('Transition archive differs.')
    base = dict(approved_head=git_head, runner_root=str(RUNNER), developer_dir=DEVELOPER,
                swift=output('swift', '--version', environment=dict(os.environ, DEVELOPER_DIR=DEVELOPER)),
                sdk=output('xcrun', '--sdk', 'macosx', '--show-sdk-version', environment=dict(os.environ, DEVELOPER_DIR=DEVELOPER)),
                guard_sha256=hashlib.sha256((ROOT / 'Tools/CI/native_runner.py').read_bytes()).hexdigest(),
                runner_archive_sha256=args.archive_sha256)
    reviewed_recoverable_policy(args.recoverable_policy, args.recoverable_policy_sha256, base)
    if (policy['recoverable_activation'].get('pr_head') != new['pr_head']
            or not new['expires_at'] <= grant['expires_at'] <= policy['recoverable_activation']['expires_at']):
        raise ValueError('Policy/source/grant expiry differs.')
    old = plan['old']
    if set(old) != {'policy', 'hook', 'ticket', 'binding', 'state', 'files'} or set(old['files']) != set(STALE_VENDOR_FILES):
        raise ValueError('Complete old registration pins are required.')
    if not isinstance(old['files']['.env'], dict) or old['files']['.env'].get('mode') != 0o600:
        raise ValueError('The reviewed hook environment must retain its private mode.')
    root = HOME_ROOT / 'recoverable-sessions'
    ticket = json.loads(_pinned_ref(old['ticket'], root / 'ticket.json'))
    old_binding_path = Path(ticket['binding'])
    old_binding = json.loads(_pinned_ref(old['binding'], old_binding_path))
    old_state = json.loads(_pinned_ref(old['state'], old_binding_path.with_suffix('.state'), 0o600))
    old_policy = json.loads(_pinned_ref(old['policy']))
    old_digest = native_runner.policy_digest(old_policy)
    if (set(old_binding) != {'schema', 'policy_sha256', 'head', 'run_id', 'run_attempt', 'max_jobs', 'expires_at'}
            or type(old_binding.get('schema')) is not int or old_binding['schema'] != 1
            or type(old_binding.get('max_jobs')) is not int or not 1 <= old_binding['max_jobs'] <= 256
            or type(old_state.get('used')) is not int
            or any(not isinstance(old_binding[k], str) or not re.fullmatch(r'[1-9][0-9]*', old_binding[k]) for k in ('run_id', 'run_attempt'))
            or type(old_binding['expires_at']) not in (int, float) or not math.isfinite(old_binding['expires_at'])
            or old_binding_path != root / (old_digest + '-' + old_binding['run_id'] + '-' + old_binding['run_attempt'] + '.json')
            or (new['run_id'], new['run_attempt']) == (old_binding['run_id'], old_binding['run_attempt'])
            or old_binding['head'] != old_policy['approved_head'] or old_binding['policy_sha256'] != old_digest
            or ticket != dict(binding=str(old_binding_path), binding_sha256=old['binding']['sha256'], ordinal=old_binding['max_jobs'], policy_sha256=old_digest)
            or old_state != {'used': old_binding['max_jobs'], 'phase': 'idle'}
            or not old_binding['expires_at'] <= time.time() or new['max_jobs'] != old_binding['max_jobs']
            or old_policy['recoverable_shards'] != policy['recoverable_shards']
            or old_policy['recoverable_activation']['runners'] != policy['recoverable_activation']['runners']):
        raise ValueError('Old session is not the exact expired exhausted idle registration.')
    provenance = json.loads(_vendor_bytes(RUNNER / '.elite-native-installation.json', old['files']['.elite-native-installation.json']))
    if provenance != {'archive_sha256': args.archive_sha256}:
        raise ValueError('Installed archive provenance differs from reviewed archive.')
    old_hook = Path(old['policy']['path']).parent / 'job-started.sh'
    _pinned_ref(old['hook'], old_hook, 0o500)
    if (set(plan['runner']) != {'id', 'name', 'os', 'labels', 'status', 'busy'}
            or type(plan['runner']['id']) is not int or plan['runner']['id'] <= 0):
        raise ValueError('Exact remote registration identity is required.')
    binding = dict(schema=1, policy_sha256=native_runner.policy_digest(policy), head=args.approved_head,
                   run_id=new['run_id'], run_attempt=new['run_attempt'], max_jobs=new['max_jobs'], expires_at=new['expires_at'])
    installed_policy = AUTHORIZATION_ROOT / args.approved_head / ('recoverable-' + args.recoverable_policy_sha256) / 'policy.json'
    expected_hook = installed_policy.parent / 'job-started.sh'
    expected_hook_sha = hashlib.sha256(session_hook(installed_policy, installed_policy.parent / 'native_runner.py')).hexdigest()
    if new['hook'] != {'path': str(expected_hook), 'sha256': expected_hook_sha}:
        raise ValueError('Reviewed new policy hook path or bytes differ.')
    context = dict(plan=plan, policy=policy, binding=binding, old_binding=old_binding, old_policy=old_policy,
                   installed_policy=installed_policy, old_hook=old_hook, grant_expiry=grant['expires_at'],
                   inputs=[(args.stale_session_plan, args.stale_session_plan_sha256),
                           (args.stale_session_grant, args.stale_session_grant_sha256),
                           (Path(grant['review']['path']), grant['review']['sha256']),
                           (args.recoverable_policy, args.recoverable_policy_sha256)],
                   old_refs={key: Path(old[key]['path']) for key in ('policy', 'hook', 'ticket', 'binding', 'state')})
    context.update(grant=grant, archive=archive)
    return context


def reuse_stale_session(args):
    """Install one reviewed policy on the same idle registration, without starting it."""
    with recoverable_control(), quiescent_legacy():
        context = _reuse_context(args)
        plan, policy, binding = (context[name] for name in ('plan', 'policy', 'binding'))
        new = plan['new']
        root = HOME_ROOT / 'recoverable-sessions'
        installed_policy = context['installed_policy']
        expected_hook = Path(new['hook']['path'])
        archive = context['archive']
        _stale_live(context)
        binding_path = root / (binding['policy_sha256'] + '-' + new['run_id'] + '-' + new['run_attempt'] + '.json')
        state_path = binding_path.with_suffix('.state')
        receipt = binding_path.with_suffix('.reuse.json')
        if any(q.exists() or q.is_symlink() for q in (binding_path, state_path, receipt)):
            raise ValueError('Transition session already exists; no replay or partial-state recovery.')
        claim = root / ('reuse-' + args.stale_session_grant_sha256 + '.json')
        _exclusive_json(claim, dict(plan_sha256=args.stale_session_plan_sha256, grant_sha256=args.stale_session_grant_sha256, binding=binding))
        _exclusive_json(binding_path, binding)
        _exclusive_json(state_path, {'used': 1, 'phase': 'stopped'})
        state_path.chmod(0o600)
        stopped_sha = hashlib.sha256(state_path.read_bytes()).hexdigest()
        custody = _require_provisioning(executor=True)
        custody.stale_reuse = context
        try:
            installed = _prepare_locked(args.approved_head, archive, args.archive_sha256,
                                        args.recoverable_policy, args.recoverable_policy_sha256,
                                        registered=True, stale=context)
        finally:
            custody.stale_reuse = None
        _stale_live(context, installed=True)
        _pinned_bytes(installed, hashlib.sha256((json.dumps(policy, indent=2) + '\n').encode()).hexdigest(), 0o400)
        _pinned_ref(new['hook'], expected_hook, 0o500)
        _pinned_bytes(installed.parent / 'native_runner.py', policy['guard_sha256'], 0o500)
        for name, digest in policy['recoverable_activation']['guard_files'].items():
            _pinned_bytes(installed.parent / name, digest, 0o400)
        publish_json(root / 'ticket.json', dict(binding=str(binding_path), binding_sha256=hashlib.sha256(binding_path.read_bytes()).hexdigest(),
                                               ordinal=1, policy_sha256=binding['policy_sha256']), immutable=True)
        _exclusive_json(receipt, dict(kind='preserved-registration-reuse-v1', claim=str(claim), runner=plan['runner'],
                                     policy=str(installed), binding=binding, environment_sha256=context['new_environment_sha256']))
        _pinned_bytes(state_path, stopped_sha, 0o600)
        _pinned_bytes(binding_path, hashlib.sha256((json.dumps(binding, sort_keys=True, allow_nan=False) + '\n').encode()).hexdigest(), 0o400)
        expected_ticket = dict(binding=str(binding_path), binding_sha256=hashlib.sha256(binding_path.read_bytes()).hexdigest(),
                               ordinal=1, policy_sha256=binding['policy_sha256'])
        if owned_json(root / 'ticket.json') != expected_ticket:
            raise ValueError('Transition ticket changed before commit; preserve stopped state.')
        publish_json(state_path, {'used': 1, 'phase': 'registered'})
        return dict(policy=str(installed), receipt=str(receipt), reason='same registration reused; no listener started')



def _lifecycle_service_context(context):
    service = context["plan"]["service"]
    label = "actions.runner.stephenlclarke-l337.elite-mbp-native"
    expected = {"pointer", "plist", "pointer_identity", "plist_identity", "plist_mode", "domain", "label", "program", "generation", "processes"}
    if (set(service) != expected or service["label"] != label
            or service["domain"] != "gui/" + str(os.getuid())
            or service["program"] != str(RUNNER / "runsvc.sh")
            or service["pointer"]["path"] != str(RUNNER / ".service")
            or service["plist"]["path"] != str(Path.home() / "Library/LaunchAgents" / (label + ".plist"))
            or context["plan"]["runner"]["id"] != 134 or context["binding"]["max_jobs"] != 1
            or int(context["binding"]["run_attempt"]) < 2
            or set(service["generation"]) != {"loaded", "pid", "start_command"}
            or service["generation"]["loaded"] is not True
            or type(service["generation"]["pid"]) is not int or service["generation"]["pid"] <= 0
            or not isinstance(service["generation"]["start_command"], str)
            or not service["generation"]["start_command"]):
        raise ValueError("The exact preserved runner134 service and next single slot are required")
    if native_runner.lifecycle_read(service["pointer"], service["pointer_identity"]["mode"]).decode().strip() != label:
        raise ValueError("Service pointer changed")
    plist = plistlib.loads(native_runner.lifecycle_read(service["plist"], service["plist_mode"]))
    if (plist.get("Label") != label or plist.get("ProgramArguments") != [service["program"]]
            or plist.get("WorkingDirectory") != str(RUNNER) or plist.get("RunAtLoad") is not True
            or plist.get("Disabled", False) is not False):
        raise ValueError("Service plist command, path or enabled state changed")
    grant = context["grant"]
    human = json.loads(_pinned_ref(grant["human"]))
    if Path(grant["human"]["path"]).is_relative_to(ROOT) or Path(grant["human"]["path"]).is_relative_to(RUNNER):
        raise ValueError("Human operation decision must be external")
    actions = [["/bin/launchctl", "bootout", service["domain"] + "/" + label],
               ["/bin/launchctl", "bootstrap", service["domain"], service["plist"]["path"]]]
    if human != dict(schema=1, kind="human-service-handoff-decision-v1", decision="APPROVED",
                     plan_sha256=context["inputs"][0][1], actions=actions):
        raise ValueError("Explicit human decision for both exact actions is missing")
    context["inputs"].append((Path(grant["human"]["path"]), grant["human"]["sha256"]))
    context.update(lifecycle=True, service=service, actions=actions, phase="online")


def _lifecycle_live(context, installed=False):
    """Revalidate archive, old generation, service, PR and predispatch attempt under both leases."""
    _require_provisioning(executor=True)
    plan, policy = context["plan"], context["policy"]
    expiry = context["binding"]["expires_at"]
    if not time.time() < expiry <= context["grant_expiry"] <= policy["recoverable_activation"]["expires_at"]:
        raise ValueError("Lifecycle plan/grant/policy expired")
    for path, digest in context["inputs"]:
        _pinned_bytes(path, digest, 0o400)
    for key, expected in context["old_refs"].items():
        _pinned_ref(plan["old"][key], expected, 0o600 if key == "state" else 0o500 if key == "hook" else 0o400)
    for name, reference in plan["old"]["files"].items():
        if name == ".env" and installed:
            reference = context["new_environment_pin"]
        if reference is None:
            if (RUNNER / name).exists() or (RUNNER / name).is_symlink():
                raise ValueError("An absent vendor generation appeared")
        else:
            _vendor_bytes(RUNNER / name, reference)
    verify_installed_archive(RUNNER, context["archive"])
    require_registration(policy)
    registration = json.loads((RUNNER / ".runner").read_text(encoding="utf-8-sig"))
    if registration.get("agentId") != 134:
        raise ValueError("Preserved registration changed")
    old = _stale_remote("actions/runs/" + context["old_binding"]["run_id"] + "/attempts/"
                        + context["old_binding"]["run_attempt"], expiry)
    expected_source = context["old_policy"]["recoverable_activation"].get("pr_head",
                        context["old_policy"]["approved_head"])
    if (str(old.get("id")) != context["old_binding"]["run_id"]
            or str(old.get("run_attempt")) != context["old_binding"]["run_attempt"]
            or old.get("head_sha") != expected_source or old.get("status") != "completed"
            or old.get("path") != ".github/workflows/ci.yml"
            or old.get("event") != ("pull_request" if "pr_head" in context["old_policy"]["recoverable_activation"] else "push")
            or old.get("conclusion") not in {"success", "failure", "cancelled", "timed_out", "skipped", "neutral", "action_required", "startup_failure"}
            or old.get("repository", {}).get("id") != 1416155405
            or old.get("repository", {}).get("full_name") != native_runner.REPOSITORY
            or old.get("actor", {}).get("id") != int(native_runner.ACTOR)
            or old.get("triggering_actor", {}).get("id") != int(native_runner.ACTOR)):
        raise ValueError("Old terminal run generation differs")
    stage = dict(binding=context["binding"], runner=plan["runner"], job_name=plan["new"]["job_name"])
    remote = native_runner.require_lifecycle_run(policy, stage, {}, active=False)
    expected_status = "online" if context["phase"] == "online" else "offline"
    if remote.get("status") != expected_status or remote.get("busy") is not False:
        raise ValueError("Runner is not in the required idle online/offline state")
    observed = native_runner.lifecycle_service(context["service"], expiry)
    expected_service = context["service"]["generation"] if context["phase"] == "online" else {"loaded": False}
    if observed != expected_service:
        raise ValueError("Service generation is not the reviewed lifecycle state")
    census = output("ps", "-axo", "pid=,ppid=,pgid=,lstart=,command=", environment=dict(os.environ))
    processes = []
    for line in census.splitlines():
        fields = line.strip().split(None, 8)
        if len(fields) != 9 or not all(field.isdigit() for field in fields[:3]):
            raise ValueError("Local runner census is uncertain")
        words = shlex.split(fields[8])
        if any(Path(word).name in {"Runner.Listener", "Runner.Worker", "RunnerService.js"}
               or word in {str(RUNNER / "run.sh"), str(RUNNER / "runsvc.sh")} for word in words):
            processes.append(line.strip())
    expected_processes = context["service"]["processes"] if context["phase"] == "online" else []
    if processes != expected_processes or (context["phase"] == "online"
            and not any(row.split()[0] == str(observed["pid"]) for row in processes)):
        raise ValueError("Local runner process generation differs")


def _lifecycle_action(context, action):
    """Execute only a precomputed service action after the exclusive claim."""
    _require_provisioning(executor=True)
    remaining = context["binding"]["expires_at"] - time.time()
    if remaining <= 0 or action not in context["actions"]:
        raise ValueError("Service operation expired or changed")
    result = subprocess.run(action, capture_output=True, text=True, timeout=remaining)
    if result.returncode:
        raise ValueError("Service operation failed; retain its one-use claim")


def stage_service_session(args):
    """Stop one granted service and install a nonexecuting next-attempt generation."""
    with recoverable_control(), quiescent_legacy():
        context = _reuse_context(args, lifecycle=True)
        _lifecycle_service_context(context)
        _lifecycle_live(context)
        root = HOME_ROOT / "recoverable-sessions"
        stage_path = root / ("lifecycle-" + native_runner.policy_digest(context["policy"]) + ".json")
        claim = stage_path.with_suffix(".stop-claim.json")
        _exclusive_json(claim, dict(plan=context["inputs"][0][1], grant=context["inputs"][1][1]))
        _lifecycle_live(context)
        _lifecycle_action(context, context["actions"][0])
        context["phase"] = "offline"
        _lifecycle_live(context)
        # Preserve the complete old public pointer and env bytes before changing the hook.
        old_ticket = root / (stage_path.stem + ".old-ticket.json")
        native_runner.lifecycle_publish_bytes(old_ticket, _pinned_ref(context["plan"]["old"]["ticket"]))
        old_env = root / (stage_path.stem + ".old-env")
        native_runner.lifecycle_publish_bytes(
            old_env, _vendor_bytes(RUNNER / ".env", context["plan"]["old"]["files"][".env"]))
        custody = _require_provisioning(executor=True)
        custody.stale_reuse = context
        try:
            installed = _prepare_locked(args.approved_head, context["archive"], args.archive_sha256,
                                        args.recoverable_policy, args.recoverable_policy_sha256,
                                        registered=True, stale=context)
        finally:
            custody.stale_reuse = None
        _lifecycle_live(context, installed=True)
        preserved = [{"ref": dict(path=str(path), sha256=digest), "mode": 0o400}
                     for path, digest in context["inputs"]]
        preserved += [{"ref": native_runner.lifecycle_ref(RUNNER / name), "mode": reference["mode"],
                       "identity": context["new_environment_pin"] if name == ".env" else reference}
                      for name, reference in context["plan"]["old"]["files"].items()
                      if reference is not None]
        preserved += [{"ref": native_runner.lifecycle_ref(Path(value["path"])),
                       "mode": 0o600 if key == "state" else 0o500 if key == "hook" else 0o400}
                      for key, value in context["plan"]["old"].items() if key not in {"files", "ticket"}]
        preserved += [{"ref": native_runner.lifecycle_ref(installed.parent / name), "mode": 0o400}
                      for name in context["policy"]["recoverable_activation"]["guard_files"]]
        for file in (installed, installed.parent / "job-started.sh", installed.parent / "native_runner.py"):
            _pinned_bytes(file, hashlib.sha256(file.read_bytes()).hexdigest(), 0o500 if file.name != "policy.json" else 0o400)
        stage = dict(schema=1, kind="staged-service-session-v1", phase="STAGED", binding=context["binding"],
                     policy=native_runner.lifecycle_ref(installed),
                     guard=native_runner.lifecycle_ref(installed.parent / "native_runner.py"),
                     hook=context["plan"]["new"]["hook"], service=context["service"], runner=context["plan"]["runner"],
                     archive=native_runner.lifecycle_ref(context["archive"]),
                     archive_mode=context["archive"].stat().st_mode & 0o777,
                     environment_pin=context["new_environment_pin"], job_name=context["plan"]["new"]["job_name"], preserved=preserved,
                     old_ticket=context["plan"]["old"]["ticket"],
                     old_ticket_snapshot=native_runner.lifecycle_ref(old_ticket),
                     old_environment_snapshot=native_runner.lifecycle_ref(old_env))
        _require_provisioning(executor=True)
        if not time.time() < context["binding"]["expires_at"]:
            raise ValueError("Staging deadline expired")
        _exclusive_json(stage_path, stage)
        return {"stage": native_runner.lifecycle_ref(stage_path), "phase": "STAGED", "workload": False}


def start_service_session(args):
    """One explicit bootstrap after stopped/offline verification; dispatch is separate."""
    with recoverable_control(), quiescent_legacy():
        context = _reuse_context(args, lifecycle=True)
        _lifecycle_service_context(context)
        context["phase"] = "offline"
        path = HOME_ROOT / "recoverable-sessions" / ("lifecycle-" + native_runner.policy_digest(context["policy"]) + ".json")
        stage = json.loads(native_runner.lifecycle_read(native_runner.lifecycle_ref(path)))
        env = next(row["ref"] for row in stage["preserved"] if row["ref"]["path"] == str(RUNNER / ".env"))
        context.update(new_environment_pin=stage["environment_pin"])
        if env["sha256"] != context["new_environment_pin"]["sha256"]:
            raise ValueError("Staged environment identity differs")
        _lifecycle_live(context, installed=True)
        if stage["phase"] != "STAGED" or stage["binding"] != context["binding"]:
            raise ValueError("Stage is a different exact generation")
        native_runner.require_lifecycle_preserved(stage)
        _exclusive_json(path.with_suffix(".start-claim.json"), {"stage": native_runner.lifecycle_ref(path)})
        _lifecycle_live(context, installed=True)
        _lifecycle_action(context, context["actions"][1])
        generation = native_runner.lifecycle_service(context["service"], context["binding"]["expires_at"])
        if generation.get("loaded") is not True:
            raise ValueError("Bootstrap generation is unresolved; preserve its claim")
        _require_provisioning(executor=True)
        if not time.time() < context["binding"]["expires_at"]:
            raise ValueError("Bootstrap deadline expired; preserve its claim")
        native_runner.require_lifecycle_preserved(stage)
        _exclusive_json(path.with_suffix(".started.json"),
                        dict(phase="STARTED", stage=native_runner.lifecycle_ref(path), service_generation=generation))
        return {"phase": "STARTED", "stage": native_runner.lifecycle_ref(path), "workload": False}


def main() -> None:
    """Prepare first; registration and listening require explicit operator flags."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approved-head", required=True)
    parser.add_argument("--runner-archive", type=Path, required=True)
    parser.add_argument("--archive-sha256", required=True)
    parser.add_argument("--recoverable-policy", type=Path)
    parser.add_argument("--recoverable-policy-sha256")
    parser.add_argument("--session-run-id")
    parser.add_argument("--session-run-attempt")
    parser.add_argument("--max-jobs", type=int)
    parser.add_argument("--session-expires-at", type=float)
    parser.add_argument("--register", action="store_true")
    parser.add_argument("--run", action="store_true")
    parser.add_argument("--lifecycle", choices=("stage", "start"))
    parser.add_argument("--stale-session-plan", type=Path)
    parser.add_argument("--stale-session-plan-sha256")
    parser.add_argument("--stale-session-grant", type=Path)
    parser.add_argument("--stale-session-grant-sha256")
    args = parser.parse_args()
    stale_values = (args.stale_session_plan, args.stale_session_plan_sha256,
                    args.stale_session_grant, args.stale_session_grant_sha256)
    if any(value is not None for value in stale_values):
        if not all(value is not None for value in stale_values) or args.register or args.run or args.recoverable_policy is None:
            parser.error("Exact stale plan/grant and policy are required; reuse never registers or starts a listener.")
        operation = stage_service_session if args.lifecycle == "stage" else start_service_session if args.lifecycle == "start" else reuse_stale_session
        print(json.dumps(operation(args)))
        return
    if args.lifecycle:
        parser.error("Lifecycle requires the exact reviewed plan and grant.")
    if args.recoverable_policy is not None:
        with recoverable_control() as lock:
            # Reading a reviewed policy is allowed; the old executor lease must be quiescent before installation.
            reviewed = owned_json(args.recoverable_policy)
            if (not re.fullmatch(r"[0-9a-f]{64}", args.recoverable_policy_sha256 or "")
                    or hashlib.sha256(args.recoverable_policy.read_bytes()).hexdigest() != args.recoverable_policy_sha256):
                raise ValueError("Reviewed input policy hash differs; no installation attempted.")
            existing = RUNNER / ".runner"
            if existing.is_symlink():
                raise ValueError("Existing registration is not physical.")
            registered = registered_session_slot(reviewed, args) if existing.exists() else False
            with quiescent_legacy(reviewed):
                policy = prepare(args.approved_head, args.runner_archive, args.archive_sha256,
                                 args.recoverable_policy, args.recoverable_policy_sha256, registered=registered)
            print("Prepared recoverable policy: " + str(policy))
            if args.register or args.run:
                result = renew_recoverable(policy, args.session_run_id, args.session_run_attempt, args.max_jobs,
                                          args.session_expires_at, args.register, args.run, lock)
                print(json.dumps(result))
        return
    if any(value is not None for value in (args.recoverable_policy_sha256, args.session_run_id, args.session_run_attempt,
                                           args.max_jobs, args.session_expires_at)):
        raise ValueError("Session flags require explicit recoverable mode.")
    if args.run and not args.register:
        raise ValueError("Listening requires explicit ephemeral registration.")
    policy = prepare(args.approved_head, args.runner_archive, args.archive_sha256)
    print("Prepared host-owned source policy: " + str(policy))
    if args.register:
        register_and_run(args.run)


if __name__ == "__main__":
    try:
        main()
    except (KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        raise SystemExit("Native runner preparation failed: " + type(error).__name__) from None
