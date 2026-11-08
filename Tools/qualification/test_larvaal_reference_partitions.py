"""G1-only real frozen ownership/criteria metadata tests; no geometry or creators."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("larvaal_reference_partitions",
    ROOT / "Tools/qualification/prepare-larvaal-reference-partitions.py")
partitions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(partitions)


class OriginalLarvaalReferencePartitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path = ROOT / "docs/fleet-physical/larvaal-original-reference-partitions.json"
        cls.catalogue = partitions.load_catalogue(cls.path)
        cls.inputs = []
        for row in cls.catalogue["rows"]:
            criteria, _ = partitions.raw_pin(row["criteriaPreimage"], ROOT)
            ownership, _ = partitions.raw_pin(row["ownershipRecord"], ROOT)
            cls.inputs.append((row, partitions.decode(criteria), partitions.decode(ownership)))

    def test_two_actual_criteria_gain_only_own_native_partition_fields(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "criteria"
            manifest = partitions.materialize(self.path, ROOT, output)
            self.assertEqual([x["id"] for x in manifest["files"]], ["SH124", "SH125"])
            self.assertEqual(manifest["acceptedHulls"], 0)
            self.assertFalse(manifest["runtimeActivation"])
            for row, criteria, ownership in self.inputs:
                actual = json.loads((output / (row["id"] + ".json")).read_text())
                self.assertEqual(actual["parts"]["originalPartRanges"], row["parts"])
                self.assertEqual(actual["parts"]["originalOwnership"], row["ownershipRecord"])
                self.assertEqual(actual["candidateParts"], criteria["candidateParts"])
                self.assertEqual(actual["parts"]["sampledIndices"], criteria["parts"]["sampledIndices"])
                self.assertEqual(actual["parts"]["exactFixedIndices"], criteria["parts"]["exactFixedIndices"])
                actual["parts"]["originalPartRanges"] = criteria["parts"]["originalPartRanges"]
                actual["parts"]["originalOwnership"] = criteria["parts"]["originalOwnership"]
                del actual["referencePartitionBinding"]
                self.assertEqual(actual, criteria)
            with self.assertRaises(ValueError):
                partitions.materialize(self.path, ROOT, output)

    def test_other_actual_member_cannot_supply_reference_parts(self):
        row, criteria, _ = self.inputs[0]
        with self.assertRaisesRegex(ValueError, "Cross-member"):
            partitions.augment(criteria, row, self.inputs[1][2])

    def test_detailed_design_partition_cannot_replace_native_partition(self):
        for row, criteria, ownership in self.inputs:
            changed = copy.deepcopy(ownership)
            changed["models"]["nativeDesign"]["parts"] = changed["models"]["design"]["parts"]
            with self.assertRaisesRegex(ValueError, "native ownership differs"):
                partitions.augment(criteria, row, changed)

    def test_existing_partition_is_not_silently_overwritten_and_json_is_strict(self):
        row, criteria, ownership = self.inputs[0]
        changed = copy.deepcopy(criteria)
        changed["parts"]["originalPartRanges"] = row["parts"]
        with self.assertRaisesRegex(ValueError, "missing-partition preimage"):
            partitions.augment(changed, row, ownership)
        with self.assertRaises(ValueError):
            partitions.decode(b'{"id":"SH124","id":"SH125"}')
        with self.assertRaises(ValueError):
            partitions.decode(b'{"value":NaN}')


if __name__ == "__main__":
    unittest.main()
