import importlib.util
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("definitions", Path(__file__).resolve().parents[1] / "generate-original-fleet-definitions.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


class OriginalDefinitionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.stage = self.root / "current-r3"
        (self.stage / "ships").mkdir(parents=True)
        self.file = self.stage / "ships/SH001.toml"
        self.file.write_text('schema="l337.fleet-design/2"\nid="SH001"\nname="Current"\nfamily="current"\nclassification="trader"\nobjectKind="ship"\n[access]\nplayerFlyable=true\npurchasePolicy="blueprintFabrication"\n[acquisition]\ndestructionGrantsBlueprint=false\n')

    def test_current_source_is_deterministic_lazy_and_has_no_geometry_or_activation_grant(self):
        a = TOOL.generate(self.stage, self.root / "a", 1, {"SH001"})
        b = TOOL.generate(self.stage, self.root / "b", 1, {"SH001"})
        self.assertEqual(a, b)
        source = (self.root / "a/Sources/L337Core/OriginalFleetDefinitions.generated.swift").read_text()
        self.assertIn('"destructionGrantsBlueprint": .boolean(false)', source)
        self.assertIn("nativePerformance: current.performance", source)
        self.assertIn("private static let sh001", source)
        self.assertFalse(a["geometryRead"] or a["runtimeActivated"])
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, self.root / "a", 1, {"SH001"})

    def test_old_schema_wrong_identity_missing_extra_and_unknown_models_refuse(self):
        source = self.file.read_text()
        for text in [source.replace("l337.fleet-design/2", "old"), source.replace('id="SH001"', 'id="SH002"')]:
            self.file.write_text(text)
            with self.assertRaises(ValueError):
                TOOL.generate(self.stage, self.root / "bad", 1)
        self.file.write_text(source)
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, self.root / "unknown", 1, {"SH002"})
        (self.stage / "ships/SH002.toml").write_text(source)
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, self.root / "extra", 1)
        self.file.unlink()
        with self.assertRaises(ValueError):
            TOOL.generate(self.stage, self.root / "missing", 1)

    def test_swift_source_quotes_are_safe_and_large_integers_remain_explicit(self):
        self.assertEqual(TOOL.quote('"\\(bad)\n'), '"\\"\\\\(bad)\\u{a}"')
        self.assertIn('.largeInteger("9223372036854775808")', TOOL.inline_value(2**63))
        with self.assertRaises(ValueError):
            TOOL.inline_value(float("nan"))
        with self.assertRaises(ValueError):
            TOOL.quote("\ud800")


if __name__ == "__main__":
    unittest.main()
