"""Read bounded owned checkpoint metadata; never infer a caller or launch work."""
import hashlib
import json
import os
from pathlib import Path
import stat

RECORD_LIMIT = 16_384
WRITE_LIMIT = 16_777_216
SCHEMA = "SH058_OPERATION_CHECKPOINT_V1"
SEMANTICS = "Before boundary; attempts are intent, completed counters are returns; no caller attribution"
UNKNOWN_QUERY = "CURRENT_QUERY_UNKNOWN_COUNTERS_ARE_COMPLETED_QUERY_PREFIX"
COMPLETED_PREFIX = "COMPLETED_QUERY_PREFIX"
PREFLIGHT = {
    "preflight-input", "preflight-criteria-and-reference", "preflight-original-resource-and-model",
    "preflight-showroom-model", "preflight-source-comparison", "preflight-pending-refusals",
    "preflight-scaled-mesh",
}
STAGES = PREFLIGHT | {
    "collision-preflight", "collision-query-intent", "collision-result-comparison",
    "render-transform-and-clip", "Display.draw", "imageForFrame",
    "existing-image-pixel-and-line-identity", "exact-original-current-pair-comparison",
    "PNG-encoding", "PNG-file-write", "final-pending-refusals", "formal-receipt-write", "formal-return",
}
COUNTERS = {
    "totalRayQueries", "totalTriangleCalls", "completedSUTQueries", "completedSUTTriangleCalls",
    "drawAttempts", "drawsCompleted", "imageAttempts", "imagesReturned", "imagesCompleted",
    "pngAttempts", "pngsCompleted",
}
LISTS = {"completedDrawSlotIDs", "completedImageSlotIDs", "completedRenderSlotIDs", "comparedPairIDs"}
STATE_KEYS = COUNTERS | LISTS | {
    "operation", "product", "stage", "triangleProgress", "lastCompletedQueryID", "currentQueryIntent",
    "sourceID", "admission",
}


def _require(condition, reason):
    if not condition:
        raise ValueError(reason)


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        _require(key not in result, "Duplicate JSON key")
        result[key] = value
    return result


def _constant(_value):
    raise ValueError("Nonfinite JSON constant")


def _require_pair_prefix(state, renders, pairs):
    """Pair returns follow successor comparison, not merely a returned image."""
    originals, successors = set(), set()
    for call in renders:
        product, separator, pair = call.partition("__")
        _require(separator and pair in pairs, "Render/pair identity")
        if product == "ORIGINAL_NATIVE":
            _require(pair not in originals, "Duplicate original pair image")
            originals.add(pair)
        else:
            _require(product == "CURRENT_NATIVE" and pair in originals and pair not in successors,
                     "Successor pair requires its preceding original image")
            successors.add(pair)
    _require(originals == successors == set(pairs), "Complete bound original/successor pairs")
    stage = state["stage"]
    if stage in PREFLIGHT or stage.startswith("collision-"):
        returned = 0
    elif stage in {"render-transform-and-clip", "Display.draw", "PNG-encoding", "PNG-file-write"}:
        returned = state["drawsCompleted"]
    elif stage in {"imageForFrame", "existing-image-pixel-and-line-identity", "exact-original-current-pair-comparison"}:
        # The pair-comparison checkpoint precedes the comparison and append.
        returned = state["drawsCompleted"] - 1
    else:
        returned = len(renders)
    _require(0 <= returned <= len(renders) and returned <= state["imagesCompleted"], "Returned pair phase/images")
    prefix = [call.partition("__")[2] for call in renders[:returned]
              if call.startswith("CURRENT_NATIVE__")]
    _require(state["comparedPairIDs"] == prefix, "Returned pair prefix at checkpoint phase")
    if stage == "exact-original-current-pair-comparison":
        _require(state["product"] == "CURRENT_NATIVE", "Pair comparison requires successor image")


def decode_snapshot(raw, wanted):
    """Validate one committed snapshot, not a history or an actual fatal call count."""
    _require(0 < len(raw) <= RECORD_LIMIT, "Checkpoint byte bound")
    value = json.loads(raw, object_pairs_hook=_unique_object, parse_constant=_constant)
    _require(type(value) is dict and set(value) == {"schema", "sequence", "semantics", "state"}, "Envelope fields")
    _require(value["schema"] == SCHEMA and value["semantics"] == SEMANTICS, "Envelope identity")
    _require(type(value["sequence"]) is int and 0 < value["sequence"] <= WRITE_LIMIT, "Sequence bound")
    s = value["state"]
    _require(type(s) is dict and set(s) == STATE_KEYS, "State fields")
    _require(s["sourceID"] == "SH058" and s["admission"] is False, "Source/refusal identity")
    _require(type(s["stage"]) is str and s["stage"] in STAGES, "Unknown stage")
    _require(type(s["operation"]) is str and 0 < len(s["operation"]) <= 256, "Operation ID bound")
    _require(type(s["product"]) is str and s["product"] in {"none", "ORIGINAL_NATIVE", "CURRENT_NATIVE", "CURRENT_NATIVE_0_2"}, "Product")
    _require(all(type(s[k]) is int and 0 <= s[k] <= 25_685 for k in COUNTERS), "Counter types/bounds")
    _require(type(s["currentQueryIntent"]) is bool, "Query intent type")
    intent, queries, triangles = s["currentQueryIntent"], s["completedSUTQueries"], s["completedSUTTriangleCalls"]
    calls = wanted["collisionCallIDs"]
    renders = wanted["renderCallIDs"]
    pairs = wanted["pairIDs"]
    _require(len(calls) == 239 and len(set(calls)) == 239 and len(renders) == 36 and len(set(renders)) == 36
             and len(pairs) == 18 and len(set(pairs)) == 18, "Bound schedule identity")
    _require(queries <= 239 and queries <= triangles <= 12_836, "Returned SUT caps")
    _require((queries != 0 or triangles == 0) and (queries != 239 or triangles == 12_836), "Completed prefix counters")
    _require(s["lastCompletedQueryID"] == (calls[queries - 1] if queries else None), "Completed query prefix ID")
    _require(s["triangleProgress"] == (UNKNOWN_QUERY if intent else COMPLETED_PREFIX), "Unknown/prefix semantics")
    _require(intent == (s["stage"] == "collision-query-intent"), "Query intent stage")
    baseline = 0 if s["stage"] in {"preflight-input", "preflight-criteria-and-reference"} else 251
    _require(s["totalRayQueries"] == baseline + queries + int(intent), "Query count at publication")
    _require(s["totalTriangleCalls"] == (12_849 if baseline else 0) + triangles, "Triangle prefix at publication")
    if s["stage"] in PREFLIGHT:
        _require(queries == 0 and triangles == 0 and s["operation"] == "formal-entry" and s["product"] == "none", "Preflight state")
    elif s["stage"] in {"collision-preflight", "collision-query-intent"}:
        _require(queries < 239 and s["operation"] == calls[queries], "Current query intent ID")
    elif s["stage"] == "collision-result-comparison":
        _require(queries > 0 and s["operation"] == calls[queries - 1], "Returned query ID")
    else:
        _require(queries == 239 and triangles == 12_836, "Render/final completed query prefix")
    if s["stage"] not in PREFLIGHT:
        if s["stage"] in {"final-pending-refusals", "formal-receipt-write", "formal-return"}:
            _require(s["operation"] == "final-pending-refusals" and s["product"] == "none", "Final operation")
        else:
            _require(s["operation"].startswith(s["product"] + "__") and s["product"] != "none", "Operation product")
            if not s["stage"].startswith("collision-"):
                _require(s["operation"] in renders, "Render operation ID")
    for key in LISTS:
        rows = s[key]
        _require(type(rows) is list and all(type(x) is str for x in rows) and len(rows) == len(set(rows)), "Slot IDs")
        if key == "comparedPairIDs":
            _require(len(rows) <= 18 and set(rows) <= set(pairs), "Pair IDs")
        else:
            _require(len(rows) <= 36 and rows == renders[:len(rows)], "Returned render prefix")
    _require(0 <= s["drawsCompleted"] <= s["drawAttempts"] <= 36
             and s["drawAttempts"] - s["drawsCompleted"] <= 1, "Draw intent/return")
    _require(0 <= s["imagesCompleted"] <= s["imagesReturned"] <= s["imageAttempts"] <= s["drawsCompleted"]
             and s["imageAttempts"] - s["imagesCompleted"] <= 1, "Image intent/return")
    _require(0 <= s["pngsCompleted"] <= s["pngAttempts"] <= s["imagesCompleted"]
             and s["pngAttempts"] - s["pngsCompleted"] <= 1, "PNG intent/return")
    _require(len(s["completedDrawSlotIDs"]) == s["drawsCompleted"]
             and len(s["completedImageSlotIDs"]) == s["imagesCompleted"]
             and len(s["completedRenderSlotIDs"]) <= s["pngsCompleted"], "Returned slot counters")
    if s["stage"] in {"render-transform-and-clip", "Display.draw"}:
        drawn = s["drawsCompleted"]
        _require(drawn < 36 and s["operation"] == renders[drawn], "Current draw slot")
        _require(s["drawAttempts"] == drawn + int(s["stage"] == "Display.draw"), "Current draw intent")
    elif s["stage"] in {"imageForFrame", "existing-image-pixel-and-line-identity",
                        "exact-original-current-pair-comparison", "PNG-encoding", "PNG-file-write"}:
        drawn = s["drawsCompleted"]
        _require(drawn > 0 and s["operation"] == renders[drawn - 1], "Returned draw slot")
        if s["stage"] == "imageForFrame":
            _require(s["imageAttempts"] == drawn and s["imagesReturned"] == drawn - 1
                     and s["imagesCompleted"] == drawn - 1, "Current image intent")
        else:
            _require(s["imagesCompleted"] == drawn, "Returned current image")
        if s["stage"] == "PNG-encoding":
            _require(s["pngAttempts"] == drawn and s["pngsCompleted"] == drawn - 1, "Current PNG intent")
        elif s["stage"] == "PNG-file-write":
            _require(s["pngsCompleted"] == drawn and len(s["completedRenderSlotIDs"]) == drawn - 1, "Encoded PNG not yet written")
    _require_pair_prefix(s, renders, pairs)
    if s["stage"] in PREFLIGHT or s["stage"].startswith("collision-"):
        _require(all(s[k] == 0 for k in COUNTERS - {"totalRayQueries", "totalTriangleCalls", "completedSUTQueries", "completedSUTTriangleCalls"})
                 and all(not s[k] for k in LISTS), "No rendering before query phase")
    return value


def _read_owned(path):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(descriptor, "rb") as stream:
        metadata = os.fstat(stream.fileno())
        _require(stat.S_ISREG(metadata.st_mode) and 0 <= metadata.st_size <= RECORD_LIMIT, "Owned regular file bound")
        raw = stream.read(RECORD_LIMIT + 1)
        _require(len(raw) == metadata.st_size and len(raw) <= RECORD_LIMIT, "Owned read changed/exceeded bound")
        return raw


def inspect_directory(directory, wanted):
    """Read only the two fixed run-owned names; absent/invalid evidence stays unknown."""
    result = {"status": "UNKNOWN", "attemptsAfterSnapshot": "UNKNOWN", "caller": "UNKNOWN",
              "pending": {"status": "ABSENT"}, "snapshot": None}
    try:
        directory = Path(directory)
        metadata = directory.lstat()
        _require(stat.S_ISDIR(metadata.st_mode), "Owned directory must not be symbolic")
        # Staging bytes are retained as uncommitted metadata, never decoded as progress.
        try:
            result["pending"] = {"status": "UNKNOWN"}
            raw = _read_owned(directory / ".last-operation.pending")
            result["pending"] = {"status": "UNCOMMITTED", "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        except FileNotFoundError:
            result["pending"] = {"status": "ABSENT"}
        raw = _read_owned(directory / "last-operation.json")
        value = decode_snapshot(raw, wanted)
        result.update(status="VALID_SNAPSHOT", snapshot=value, sha256=hashlib.sha256(raw).hexdigest(), bytes=len(raw))
    except (OSError, ValueError, TypeError, KeyError, UnicodeError, RecursionError) as error:
        result["reason"] = type(error).__name__ + ": " + str(error)
    return result


def require_complete(inspection):
    """Require final returned counters; XML/receipt/image verification remains separate."""
    _require(inspection["status"] == "VALID_SNAPSHOT" and inspection["pending"]["status"] == "ABSENT", "Complete committed journal required")
    state = inspection["snapshot"]["state"]
    _require(state["stage"] == "formal-return" and state["operation"] == "final-pending-refusals"
             and state["product"] == "none" and not state["currentQueryIntent"], "Final return stage")
    _require(state["totalRayQueries"] == 490 and state["totalTriangleCalls"] == 25_685
             and state["completedSUTQueries"] == 239 and state["completedSUTTriangleCalls"] == 12_836, "Final query counters")
    _require(all(state[k] == 36 for k in ("drawAttempts", "drawsCompleted", "imageAttempts", "imagesReturned", "imagesCompleted", "pngAttempts", "pngsCompleted"))
             and all(len(state[k]) == 36 for k in LISTS - {"comparedPairIDs"})
             and len(state["comparedPairIDs"]) == 18, "Final render counters")
    return state
