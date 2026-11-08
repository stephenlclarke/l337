"""Current source checks do not install mechanics or evaluate native geometry."""

import copy
import importlib.util
from pathlib import Path
import tempfile
import tomllib
import unittest


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(filename))
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


authority = module("current_fleet_contract_test", "fleet-source-contract.py")
files = module("current_fleet_files_test", "ship-files.py")


class CurrentFleetSourceContractTests(unittest.TestCase):
    def ship(self, identity):
        return tomllib.loads((files.SHIP_FOLDER / (identity + ".toml")).read_text())

    def test_current_ready_and_pending_resources_keep_their_real_policy(self):
        for identity in ("SH025", "SH067", "SH171"):
            ship = self.ship(identity)
            before = copy.deepcopy(ship)
            authority.require_current_ship(ship)
            self.assertEqual(ship, before)
            self.assertNotEqual(ship["catalogue"]["purchasePolicy"], "xyzzyOnly")
        self.assertEqual(self.ship("SH067")["catalogue"]["mechanicsStatus"], "pending")
        self.assertEqual(self.ship("SH171")["catalogue"]["purchasePolicy"], "never")

    def test_old_balance_identity_capacity_origin_and_environment_mechanics_refuse(self):
        ship = self.ship("SH025")
        contract = authority.contracts()[ship["id"]]
        for section, key, value in (
            (None, "name", "Cobra Mk III"),
            ("catalogue", "family", "cobra"),
            ("catalogue", "origin", "alien"),
            ("catalogue", "objectKind", "capsule"),
            ("game", "cargo", 99999),
            ("game", "fuel", 1300),
            ("game", "workTools", ["miningLaser", "salvageCutter"]),
        ):
            with self.subTest(key=key):
                changed = copy.deepcopy(ship)
                target = changed if section is None else changed[section]
                target[key] = value
                with self.assertRaises(ValueError):
                    authority.require_matching(changed, contract)
        probe = authority.contracts()["SH162"]
        controlled = {"id": probe["id"], "name": probe["name"],
                      "catalogue": {"family": probe["family"], "origin": "alien", "objectKind": "other"}}
        authority.require_matching(controlled, probe)
        controlled["game"] = ship["game"]
        with self.assertRaises(ValueError):
            authority.require_matching(controlled, probe)

    def test_current_writer_preserves_all_values_and_refuses_before_overwriting(self):
        ship = self.ship("SH025")
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "SH025.toml"
            files.write_ship(output, ship)
            expected = output.read_bytes()
            self.assertEqual(tomllib.loads(expected.decode()), ship)
            altered = copy.deepcopy(ship)
            altered["game"]["cargo"] = 99999
            with self.assertRaises(ValueError):
                files.write_ship(output, altered)
            self.assertEqual(output.read_bytes(), expected)
        with self.assertRaises(ValueError):
            authority.require_current_fleet([ship] * 171)

    def test_original_capsule_and_environment_sources_roundtrip_without_invalid_overwrite(self):
        ordinary = self.ship("SH025")
        with tempfile.TemporaryDirectory() as directory:
            for identity in ("SH040", "SH156", "SH161", "SH162", "SH164"):
                with self.subTest(identity=identity):
                    ship = self.ship(identity)
                    before = copy.deepcopy(ship)
                    source = files.SHIP_FOLDER / (identity + ".toml")
                    source_bytes = source.read_bytes()
                    authority.require_current_ship(ship)
                    output = Path(directory) / (identity + ".toml")
                    files.write_ship(output, ship)
                    expected = output.read_bytes()
                    self.assertEqual(tomllib.loads(expected.decode("utf-8")), before)
                    self.assertEqual(ship, before)
                    altered = copy.deepcopy(ship)
                    if identity == "SH040":
                        self.assertEqual(ship["game"]["energy"], 70)
                        # A mission marker's old100 is not this capsule's source.
                        altered["game"]["energy"] = 100
                    else:
                        self.assertNotIn("game", ship)
                        altered["game"] = copy.deepcopy(ordinary["game"])
                    with self.assertRaises(ValueError):
                        files.write_ship(output, altered)
                    self.assertEqual(output.read_bytes(), expected)
                    self.assertEqual(source.read_bytes(), source_bytes)
                    self.assertEqual(ship, before)


if __name__ == "__main__":
    unittest.main()
