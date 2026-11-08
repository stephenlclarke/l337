"""Current fleet authoring authority; no geometry evaluation or runtime admission."""

from decimal import Decimal
from functools import lru_cache
import hashlib
import json
import math
from pathlib import Path
import tomllib


BACKLOG_SHA256 = "c19ae8604d16396bae5d551a28a713cc4ccc18b28a0d8d1a2cf8ecba08767d7d"
GAME_FIELDS = {
    "cargo": "cargoTonnes", "speed": "maxSpeed", "acceleration": "acceleration",
    "energy": "energyCapacity", "recharge": "energyRecharge", "roll": "roll",
    "pitch": "pitch", "yaw": "yaw", "shield": "shieldCapacityPerBank",
    "shieldRecharge": "shieldRechargePerBank", "jump": "maxJumpLY",
    "spool": "jumpChargeSeconds", "missiles": "missileCapacity",
    "facings": "laserFacingMask", "cargoExpansion": "cargoExpansionTonnes",
    "price": "hullPriceCR",
}


def bounded_bytes(path, maximum):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > maximum:
        raise ValueError("Unavailable bounded current source: " + str(path))
    with path.open("rb") as stream:
        data = stream.read(maximum + 1)
    if len(data) > maximum:
        raise ValueError("Current source exceeds byte bound: " + str(path))
    return data


@lru_cache(maxsize=1)
def contracts():
    """Resolve one exact 171-record R3 set once per authoring process."""
    root = Path(__file__).resolve().parents[2]
    data = bounded_bytes(root / "docs/milestones/FLEET-BACKLOG.json", 1_500_000)
    if hashlib.sha256(data).hexdigest() != BACKLOG_SHA256:
        raise ValueError("Current fleet source manifest changed; review its authority explicitly")
    rows = json.loads(data)["entries"]
    expected = {f"SH{index:03d}" for index in range(1, 172)}
    if len(rows) != 171 or {row["id"] for row in rows} != expected:
        raise ValueError("Current fleet must contain exactly 171 distinct stable IDs")
    result = {}
    for row in rows:
        identity = row["id"]
        source = bounded_bytes(root / "docs/fleet-design-v2/ships" / (identity + ".toml"), 65536)
        if hashlib.sha256(source).hexdigest() != row["contractSHA256"]:
            raise ValueError("Current R3 source digest mismatch: " + identity)
        contract = tomllib.loads(source.decode("utf-8"))
        if contract != row["contract"] or contract["id"] != identity:
            raise ValueError("Current R3 manifest/source mismatch: " + identity)
        result[identity] = contract
    return result


def require_matching(ship, contract):
    """Validate source identity and bare mechanics without granting live capabilities."""
    identity = contract["id"]
    metadata = ship.get("catalogue", {})
    origin = {"human": "human", "larvaal": "alien"}[contract["origin"]]
    if (ship.get("id"), ship.get("name"), metadata.get("family"),
        metadata.get("origin"), metadata.get("objectKind")) != (
        identity, contract["name"], contract["family"], origin, contract["objectKind"]
    ):
        raise ValueError("Resource identity is not current R3: " + identity)
    if "performance" not in contract:
        if "game" in ship:
            raise ValueError("Environment object cannot acquire ship mechanics: " + identity)
        return
    performance = contract["performance"]
    expected = {key: performance[source] for key, source in GAME_FIELDS.items()}
    fuel = Decimal(str(performance["fuelTankLY"])) * 10
    if not fuel.is_finite() or fuel != fuel.to_integral_value():
        raise ValueError("Current R3 tank is not exact native fuel units: " + identity)
    expected["fuel"] = int(fuel)
    compatible = contract["fitting"]["compatibleUtilities"]
    expected["workTools"] = [tool for tool in compatible if tool in ("miningLaser", "salvageCutter")]
    actual = ship.get("game")
    if not isinstance(actual, dict) or actual != expected:
        raise ValueError("Resource bare mechanics are not current R3: " + identity)
    for key, value in actual.items():
        if key != "workTools" and (type(value) not in (int, float) or not math.isfinite(value)):
            raise ValueError("Resource mechanics must be finite numbers: " + identity)


def require_current_ship(ship):
    identity = ship.get("id")
    current = contracts().get(identity)
    if current is None:
        raise ValueError("Unknown current fleet ID: " + str(identity))
    require_matching(ship, current)


def require_current_fleet(ships):
    current = contracts()
    if len(ships) != 171 or {ship.get("id") for ship in ships} != set(current):
        raise ValueError("Reference generation requires all 171 distinct current resources")
    for ship in ships:
        require_matching(ship, current[ship["id"]])
