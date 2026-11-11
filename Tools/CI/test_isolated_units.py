"""Unit fixtures for CI selection and report completeness; never launch Swift."""

from pathlib import Path
import re
import tempfile
import unittest
import xml.etree.ElementTree as ET

import isolated_units as units


class IsolatedReportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "tests.xml"

    def report(self):
        root = ET.Element("testsuites")
        suite = ET.SubElement(root, "testsuite")
        for name, methods in units.METHODS.items():
            for method in methods:
                suffix = "(installed:)" if method == "destroyedActualTargetNeverRestoresHeldOrInstalledMaterials" else "()"
                ET.SubElement(suite, "testcase", classname=name, name=method + suffix)
        return root, suite

    def write(self, root):
        ET.ElementTree(root).write(self.path)

    def optics_consumers(self):
        """Read the actual optics file's literal suite and @Test declarations."""
        path = units.ROOT / "Tests/L337CoreTests/NativeAssemblySurveyOpticsUnitTests.swift"
        suite = None
        consumers = []
        for line in path.read_text(encoding="utf-8").splitlines():
            declaration = re.match(r"struct (\w+)", line)
            if declaration:
                suite = declaration[1]
            method = re.match(r"\s+@Test func (\w+)\(", line)
            if method:
                self.assertIsNotNone(suite)
                consumers.append((suite, method[1]))
        return consumers

    def test_complete_report_records_actual_cases(self):
        root, suite = self.report()
        self.write(root)
        result = units.inspect_report(self.path)
        self.assertEqual(result["methods"], 697)
        self.assertEqual(result["reported_testcases"], len(suite))

    def test_optics_fixture_consumers_have_exact_selection_boundaries(self):
        suites = (
            "NativeAssemblySurveyOpticsUnitTests",
            "NativeAssemblySurveyInstrumentControlsUnitTests",
            "NativeAssemblyCalibrationIntegrationUnitTests",
            "NativeAssemblyCalibrationInputLifetimeUnitTests",
        )
        consumers = self.optics_consumers()
        self.assertEqual(len(consumers), 11)
        self.assertEqual(len(set(consumers)), 11)
        selected = [(suite, method) for suite in suites for method in units.METHODS[suite]]
        self.assertCountEqual(consumers, selected)
        pattern = re.compile(units.selection())
        for suite, method in consumers:
            with self.subTest(suite=suite, method=method):
                self.assertIsNotNone(pattern.search(f"L337CoreTests.{suite}/{method}()"))
                self.assertIsNone(pattern.search(f"Other{suite}/{method}()"))
                self.assertIsNone(pattern.search(f"{suite}/{method}Extra()"))

    def test_missing_optics_fixture_consumer_cannot_pass_a_complete_report(self):
        for name, method in self.optics_consumers():
            with self.subTest(suite=name, method=method):
                root, suite = self.report()
                row = next(row for row in suite if row.get("classname") == name
                           and row.get("name") == method + "()")
                suite.remove(row)
                self.write(root)
                with self.assertRaisesRegex(ValueError, "Missing selected unit methods"):
                    units.inspect_report(self.path)

    def test_empty_report_does_not_pass_on_zero_process_exit(self):
        self.write(ET.Element("testsuites"))
        with self.assertRaisesRegex(ValueError, "no test cases"):
            units.inspect_report(self.path)

    def test_missing_selected_method_cannot_be_hidden_by_duplicate_other_cases(self):
        root, suite = self.report()
        suite.remove(suite[0])
        ET.SubElement(suite, "testcase", **suite[-1].attrib)
        self.write(root)
        with self.assertRaisesRegex(ValueError, "Missing selected"):
            units.inspect_report(self.path)

    def test_failure_error_and_skip_are_not_success(self):
        for issue in ("failure", "error", "skipped"):
            with self.subTest(issue=issue):
                root, suite = self.report()
                ET.SubElement(suite[0], issue)
                self.write(root)
                with self.assertRaises(ValueError):
                    units.inspect_report(self.path)

    def test_unselected_method_and_suite_error_totals_are_rejected(self):
        root, suite = self.report()
        ET.SubElement(suite, "testcase", classname="GameRuntimeTests", name="journey()")
        self.write(root)
        with self.assertRaisesRegex(ValueError, "outside"):
            units.inspect_report(self.path)
        root, suite = self.report()
        suite.set("errors", "1")
        self.write(root)
        with self.assertRaisesRegex(ValueError, "suite reports"):
            units.inspect_report(self.path)

    def test_filter_selects_only_named_methods_in_the_named_suites(self):
        pattern = re.compile(units.selection())
        for suite, methods in units.METHODS.items():
            for method in methods:
                self.assertIsNotNone(pattern.search(f"L337CoreTests.{suite}/{method}()"))
                self.assertIsNone(pattern.search(f"L337CoreTests.OtherSuite/{method}()"))
                self.assertIsNone(pattern.search(f"L337CoreTests.{suite}/{method}Journey()"))
        self.assertIsNone(pattern.search("L337CoreTests.NativeMeasuredExtractionJourneyTests/fullJourney()"))


class CompilerIsolationReportTests(unittest.TestCase):
    report = IsolatedReportTests.report
    write = IsolatedReportTests.write

    def setUp(self):
        IsolatedReportTests.setUp(self)
        self.console = Path(self.directory.name) / "output.log"
        self.lines = []
        for suite, methods in units.COMPILER_ISOLATION_METHODS.items():
            for method in methods:
                parameterized = method == "destroyedActualTargetNeverRestoresHeldOrInstalledMaterials"
                signature = method + ("(installed:)" if parameterized else "()")
                aggregate = " with 2 test cases" if parameterized else ""
                self.lines.append("\u2714 Test " + signature + aggregate + " passed after 1.000 seconds.")
                if parameterized:
                    for value in ("false", "true"):
                        self.lines.append("\u25c7 Test case passing 1 argument installed \u2192 "
                                          + value + " to " + signature + " started.")
        self.write(self.report()[0])

    def inspect(self, lines=None):
        self.console.write_text("\n".join(self.lines if lines is None else lines) + "\n")
        return units.inspect_compiler_isolation_report(self.path, self.console)

    def test_all_seven_cases_require_six_aggregate_xml_rows_and_console_arguments(self):
        self.assertEqual(self.inspect(), {"compiler_isolation_methods": 6,
                                        "compiler_isolation_configured_cases": 7})

    def test_missing_duplicate_or_wrong_boolean_case_is_rejected(self):
        argument = next(line for line in self.lines if "installed \u2192 true" in line)
        variants = [
            [line for line in self.lines if line != argument],
            self.lines + [argument],
            [line.replace("installed \u2192 true", "installed \u2192 1") for line in self.lines],
        ]
        for lines in variants:
            with self.subTest(lines=lines), self.assertRaisesRegex(ValueError, "exactly once"):
                self.inspect(lines)

    def test_missing_duplicate_pass_and_wrong_case_count_are_rejected(self):
        passing = self.lines[0]
        variants = [self.lines[1:], self.lines + [passing],
                    [line.replace("with 2 test cases", "with 1 test cases") for line in self.lines]]
        for lines in variants:
            with self.subTest(lines=lines), self.assertRaisesRegex(ValueError, "passing method"):
                self.inspect(lines)

    def test_missing_or_duplicate_owning_xml_method_is_rejected(self):
        for duplicate in (False, True):
            root, suite = self.report()
            row = next(row for row in suite if row.get("name").startswith("noTradeBackAnd"))
            if duplicate:
                ET.SubElement(suite, "testcase", **row.attrib)
            else:
                suite.remove(row)
            self.write(root)
            with self.subTest(duplicate=duplicate), self.assertRaisesRegex(ValueError, "owning method exactly once"):
                self.inspect()

    def test_console_failure_cannot_be_hidden_by_passing_xml(self):
        with self.assertRaisesRegex(ValueError, "contains a failure"):
            self.inspect(self.lines + ["\u2718 Test anotherMethod() failed after 1.000 seconds."])


if __name__ == "__main__":
    unittest.main()
