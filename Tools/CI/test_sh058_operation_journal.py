"""Synthetic record/file regressions only; no game or scientific data imports."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import sh058_operation_journal as journal


class OperationJournalTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.root = Path(self.folder.name).resolve(strict=True)
        pairs = [f"VIEW{i:02}__whiteWireframe" for i in range(18)]
        self.wanted = {
            "collisionCallIDs": [f"CURRENT_NATIVE__Q{i:03}" for i in range(239)],
            "renderCallIDs": [product + "__" + pair for product in ("ORIGINAL_NATIVE", "CURRENT_NATIVE") for pair in pairs],
            # Set membership order is deliberately distinct from actual render order.
            "pairIDs": list(reversed(pairs)),
        }

    def tearDown(self):
        self.folder.cleanup()

    def envelope(self, stage="preflight-input"):
        state = {key: 0 for key in journal.COUNTERS}
        state.update({key: [] for key in journal.LISTS})
        state.update(operation="formal-entry", product="none", stage=stage,
                     triangleProgress=journal.COMPLETED_PREFIX, lastCompletedQueryID=None,
                     currentQueryIntent=False, sourceID="SH058", admission=False)
        return dict(schema=journal.SCHEMA, sequence=1, semantics=journal.SEMANTICS, state=state)

    def encode(self, value):
        return json.dumps(value, sort_keys=True).encode()

    def save(self, value):
        (self.root / "last-operation.json").write_bytes(self.encode(value))

    def complete(self):
        value = self.envelope("formal-return")
        state = value["state"]
        state.update(operation="final-pending-refusals", totalRayQueries=490, totalTriangleCalls=25_685,
                     completedSUTQueries=239, completedSUTTriangleCalls=12_836,
                     lastCompletedQueryID=self.wanted["collisionCallIDs"][-1])
        for key in journal.COUNTERS - {"totalRayQueries", "totalTriangleCalls", "completedSUTQueries", "completedSUTTriangleCalls"}:
            state[key] = 36
        for key in journal.LISTS - {"comparedPairIDs"}:
            state[key] = list(self.wanted["renderCallIDs"])
        state["comparedPairIDs"] = [call.partition("__")[2] for call in self.wanted["renderCallIDs"]
                                    if call.startswith("CURRENT_NATIVE__")]
        value["sequence"] = 1_000
        return value

    def test_intent_retains_unknown_current_query_and_completed_prefix(self):
        value = self.envelope()
        self.save(value)
        initial = journal.inspect_directory(self.root, self.wanted)
        self.assertEqual(initial["status"], "VALID_SNAPSHOT")
        self.assertEqual(initial["attemptsAfterSnapshot"], "UNKNOWN")
        state = value["state"]
        state.update(stage="collision-query-intent", operation=self.wanted["collisionCallIDs"][0],
                     product="CURRENT_NATIVE", currentQueryIntent=True, triangleProgress=journal.UNKNOWN_QUERY,
                     totalRayQueries=252, totalTriangleCalls=12_849)
        value["sequence"] = 2
        self.save(value)
        # Even a complete-looking pending record is never interpreted as returned work.
        (self.root / ".last-operation.pending").write_bytes(self.encode(self.complete()))
        interrupted = journal.inspect_directory(self.root, self.wanted)
        self.assertEqual(interrupted["snapshot"]["state"]["completedSUTTriangleCalls"], 0)
        self.assertEqual(interrupted["pending"]["status"], "UNCOMMITTED")
        self.assertEqual(interrupted["caller"], "UNKNOWN")
        state.update(stage="collision-result-comparison", currentQueryIntent=False,
                     triangleProgress=journal.COMPLETED_PREFIX, completedSUTQueries=1,
                     completedSUTTriangleCalls=3, totalTriangleCalls=12_852,
                     lastCompletedQueryID=self.wanted["collisionCallIDs"][0])
        value["sequence"] = 3
        result = journal.decode_snapshot(self.encode(value), self.wanted)
        self.assertEqual(result["state"]["completedSUTTriangleCalls"], 3)
        self.assertEqual(interrupted["snapshot"]["sequence"], 2)
        # Exercise the ordinary rendering transcript with synthetic IDs/counters only.
        value = self.complete()
        state = value["state"]
        state.update(product="ORIGINAL_NATIVE", operation=self.wanted["renderCallIDs"][0])
        for key in journal.COUNTERS - {"totalRayQueries", "totalTriangleCalls", "completedSUTQueries", "completedSUTTriangleCalls"}:
            state[key] = 0
        for key in journal.LISTS:
            state[key] = []
        steps = [
            ("render-transform-and-clip", {}),
            ("Display.draw", dict(drawAttempts=1)),
            ("imageForFrame", dict(drawsCompleted=1, completedDrawSlotIDs=self.wanted["renderCallIDs"][:1], imageAttempts=1)),
            ("existing-image-pixel-and-line-identity", dict(imagesReturned=1, imagesCompleted=1,
                                                           completedImageSlotIDs=self.wanted["renderCallIDs"][:1])),
            ("PNG-encoding", dict(pngAttempts=1)),
            ("PNG-file-write", dict(pngsCompleted=1)),
        ]
        for stage, counters in steps:
            state.update(counters, stage=stage)
            with self.subTest(stage=stage):
                snapshot = journal.decode_snapshot(self.encode(value), self.wanted)
                premature = copy.deepcopy(value)
                premature["state"]["comparedPairIDs"] = list(self.wanted["pairIDs"])
                with self.assertRaises(ValueError):
                    journal.decode_snapshot(self.encode(premature), self.wanted)
                self.assertEqual(snapshot["state"]["stage"], stage)
                broken = copy.deepcopy(value)
                broken["state"]["operation"] = self.wanted["renderCallIDs"][1]
                with self.assertRaises(ValueError):
                    journal.decode_snapshot(self.encode(broken), self.wanted)

        # First successor: its image can return before its pair comparison returns.
        value = self.complete()
        state = value["state"]
        state.update(stage="existing-image-pixel-and-line-identity", product="CURRENT_NATIVE",
                     operation=self.wanted["renderCallIDs"][18], drawAttempts=19, drawsCompleted=19,
                     imageAttempts=19, imagesReturned=19, imagesCompleted=19,
                     pngAttempts=18, pngsCompleted=18,
                     completedDrawSlotIDs=self.wanted["renderCallIDs"][:19],
                     completedImageSlotIDs=self.wanted["renderCallIDs"][:19],
                     completedRenderSlotIDs=self.wanted["renderCallIDs"][:18], comparedPairIDs=[])
        first_pair = self.wanted["renderCallIDs"][18].partition("__")[2]
        for stage in ("existing-image-pixel-and-line-identity", "exact-original-current-pair-comparison"):
            state["stage"] = stage
            self.assertEqual(journal.decode_snapshot(self.encode(value), self.wanted)["state"]["comparedPairIDs"], [])
            premature = copy.deepcopy(value)
            premature["state"]["comparedPairIDs"] = [first_pair]
            with self.assertRaises(ValueError):
                journal.decode_snapshot(self.encode(premature), self.wanted)
        # PNG intent follows the returned comparison and must retain exactly that pair.
        state.update(stage="PNG-encoding", pngAttempts=19, comparedPairIDs=[first_pair])
        self.assertEqual(journal.decode_snapshot(self.encode(value), self.wanted)["state"]["comparedPairIDs"], [first_pair])
        state["comparedPairIDs"] = []
        with self.assertRaises(ValueError):
            journal.decode_snapshot(self.encode(value), self.wanted)

    def test_invalid_envelope_types_prefixes_and_bounds_are_rejected(self):
        valid = self.complete()
        mutations = [
            ("sequence", True), ("sequence", 0), ("sequence", journal.WRITE_LIMIT + 1),
            ("schema", "wrong"), ("semantics", "all calls completed"),
        ]
        for key, replacement in mutations:
            with self.subTest(key=key, replacement=replacement):
                value = copy.deepcopy(valid)
                value[key] = replacement
                with self.assertRaises(ValueError):
                    journal.decode_snapshot(self.encode(value), self.wanted)
        for key, replacement in [
            ("completedSUTQueries", True), ("completedSUTTriangleCalls", 0),
            ("lastCompletedQueryID", "foreign"), ("currentQueryIntent", True),
            ("triangleProgress", journal.UNKNOWN_QUERY), ("admission", True),
            ("completedDrawSlotIDs", list(reversed(self.wanted["renderCallIDs"]))),
            ("comparedPairIDs", ["foreign"]), ("comparedPairIDs", list(self.wanted["pairIDs"])),
            ("product", "CURRENT_NATIVE"),
        ]:
            with self.subTest(state=key):
                value = copy.deepcopy(valid)
                value["state"][key] = replacement
                with self.assertRaises(ValueError):
                    journal.decode_snapshot(self.encode(value), self.wanted)
        for raw in [b"{" * (journal.RECORD_LIMIT + 1), b'{"schema":1,"schema":2}', b'{"sequence":NaN}', b"{}"]:
            with self.subTest(raw=raw[:30]):
                with self.assertRaises(ValueError):
                    journal.decode_snapshot(raw, self.wanted)
        # A final stage label cannot replace evidence of the last returned image.
        missing_image = self.complete()
        missing_image["state"].update(imagesCompleted=35, pngAttempts=35, pngsCompleted=35,
                                     completedImageSlotIDs=self.wanted["renderCallIDs"][:35],
                                     completedRenderSlotIDs=self.wanted["renderCallIDs"][:35])
        with self.assertRaises(ValueError):
            journal.decode_snapshot(self.encode(missing_image), self.wanted)

    def test_final_return_requires_complete_counters_and_no_pending(self):
        value = self.complete()
        self.save(value)
        evidence = journal.inspect_directory(self.root, self.wanted)
        state = journal.require_complete(evidence)
        self.assertEqual(state["stage"], "formal-return")
        self.assertEqual(evidence["attemptsAfterSnapshot"], "UNKNOWN")
        for stage in ["final-pending-refusals", "formal-receipt-write"]:
            value["state"]["stage"] = stage
            self.save(value)
            with self.assertRaises(ValueError):
                journal.require_complete(journal.inspect_directory(self.root, self.wanted))
        value = self.complete()
        value["state"]["completedRenderSlotIDs"].pop()
        self.save(value)
        with self.assertRaises(ValueError):
            journal.require_complete(journal.inspect_directory(self.root, self.wanted))
        self.save(self.complete())
        (self.root / ".last-operation.pending").write_bytes(b"partial")
        with self.assertRaises(ValueError):
            journal.require_complete(journal.inspect_directory(self.root, self.wanted))

    def test_absent_invalid_symbolic_and_oversized_files_stay_unknown(self):
        for directory in [self.root / "absent", self.root]:
            result = journal.inspect_directory(directory, self.wanted)
            self.assertEqual(result["status"], "UNKNOWN")
            self.assertEqual(result["attemptsAfterSnapshot"], "UNKNOWN")
            self.assertIsNone(result["snapshot"])
        committed = self.root / "last-operation.json"
        committed.write_bytes(b"partial")
        self.assertEqual(journal.inspect_directory(self.root, self.wanted)["status"], "UNKNOWN")
        self.assertEqual(committed.read_bytes(), b"partial")
        foreign = self.root / "foreign"
        foreign.write_bytes(self.encode(self.complete()))
        committed.unlink()
        committed.symlink_to(foreign)
        self.assertEqual(journal.inspect_directory(self.root, self.wanted)["status"], "UNKNOWN")
        committed.unlink()
        committed.write_bytes(b"x" * (journal.RECORD_LIMIT + 1))
        self.assertEqual(journal.inspect_directory(self.root, self.wanted)["status"], "UNKNOWN")
        committed.write_bytes(foreign.read_bytes())
        pending = self.root / ".last-operation.pending"
        pending.write_bytes(b"x" * (journal.RECORD_LIMIT + 1))
        result = journal.inspect_directory(self.root, self.wanted)
        self.assertEqual(result["status"], "UNKNOWN")
        self.assertEqual(result["pending"]["status"], "UNKNOWN")
        self.assertIsNone(result["snapshot"])
        self.assertEqual(pending.stat().st_size, journal.RECORD_LIMIT + 1)
        linked = self.root / "linked"
        linked.symlink_to(self.root, target_is_directory=True)
        self.assertEqual(journal.inspect_directory(linked, self.wanted)["status"], "UNKNOWN")


if __name__ == "__main__":
    unittest.main()
