"""Ensure the maintained equality inventory catches future omissions and ordering drift."""

import re
import unittest

from script_instance_equality import COMMANDER_SOURCE, SOURCE, inspect_equality, inspect_instance_storage


class ScriptInstanceEqualityTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()

    def test_all_actual_fields_are_compared(self):
        fields = inspect_equality(self.source)
        self.assertIn("savedNativeCrewLog", fields)
        self.assertIn("randomState", fields)

    def test_new_stored_field_cannot_be_silently_omitted(self):
        changed = self.source.replace(
            "    let id: UUID\n", "    let addedForFixture: String\n    let id: UUID\n", 1
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed)

    def test_missing_duplicate_or_reordered_comparisons_are_rejected(self):
        first = "    guard equalId(lhs.payload, rhs.payload) else { return false }\n"
        second = "    guard equalDefinition(lhs.payload, rhs.payload) else { return false }\n"
        for changed in [
            self.source.replace(first, "", 1),
            self.source.replace(first, first + first, 1),
            self.source.replace(first + second, second + first, 1),
        ]:
            with self.subTest(changed=changed[:40]):
                with self.assertRaisesRegex(ValueError, "every stored field"):
                    inspect_equality(changed)

    def test_different_member_on_right_is_rejected(self):
        changed = self.source.replace("lhs.id == rhs.id", "lhs.id == rhs.definition", 1)
        with self.assertRaisesRegex(ValueError, "same member"):
            inspect_equality(changed)

    def test_computed_and_static_properties_are_not_stored_equality_fields(self):
        changed = self.source.replace(
            "    let id: UUID\n",
            "    static let fixture: Int = 1\n    var computed: Int { 1 }\n    let id: UUID\n",
            1,
        )
        self.assertEqual(inspect_equality(changed), inspect_equality(self.source))

    def test_early_success_cannot_bypass_the_comparisons(self):
        changed = self.source.replace(
            "    guard equalId(lhs.payload, rhs.payload)", "    return true\n    guard equalId(lhs.payload, rhs.payload)", 1
        )
        with self.assertRaisesRegex(ValueError, "short circuit"):
            inspect_equality(changed)

    def test_observed_stored_properties_cannot_evade_the_inventory(self):
        for declaration in [
            "    var added: Int { didSet {} }\n",
            "    var added: Int {\n      willSet {}\n    }\n",
            "    var added: Int = 0 { didSet {} }\n",
        ]:
            with self.subTest(declaration=declaration):
                changed = self.source.replace("    let id: UUID\n", declaration + "    let id: UUID\n", 1)
                with self.assertRaisesRegex(ValueError, "Observed stored"):
                    inspect_equality(changed)

    def test_multiple_bindings_cannot_hide_the_second_stored_field(self):
        for declaration in [
            "    let added: Int, omitted: Int\n",
            "    var added: Int = 1, omitted: Int = 2\n",
        ]:
            with self.subTest(declaration=declaration):
                changed = self.source.replace("    let id: UUID\n", declaration + "    let id: UUID\n", 1)
                with self.assertRaisesRegex(ValueError, "Multiple bindings"):
                    inspect_equality(changed)

    def test_inferred_type_cannot_evade_the_inventory(self):
        changed = self.source.replace("    let id: UUID\n", "    let fixture = 1\n    let id: UUID\n", 1)
        with self.assertRaisesRegex(ValueError, "explicit type"):
            inspect_equality(changed)


class ScriptInstanceStorageInventoryTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()
        self.fields = inspect_instance_storage(self.source)
        self.wrapped = set(re.findall(r"^    var (\w+): Field<[^\n]+>\?", self.source, re.M))
        self.assertEqual(len(self.fields), 64)
        self.assertIn("savedHollowManifest", self.fields)
        self.assertIn("savedTitheCommission", self.fields)

    def changed(self, before, after):
        self.assertIn(before, self.source)
        return self.source.replace(before, after, 1)

    def test_added_payload_or_facade_field_fails_closed(self):
        for before, after in [
            ("    let id: UUID", "    var omitted: Int = 0\n    let id: UUID"),
            ("  private var payload: Storage", "  var omitted: Int = 0\n  private var payload: Storage"),
        ]:
            with self.subTest(before=before), self.assertRaises(ValueError):
                inspect_instance_storage(self.changed(before, after))

    def test_every_mutable_projection_requires_both_detaches(self):
        for field in self.fields[4:]:
            field = field + ("!.value" if field in self.wrapped else "")
            for projection in [
                f"      ensureUniqueStorage()\n      payload.{field} = newValue",
                f"      ensureUniqueStorage()\n      yield &payload.{field}",
            ]:
                with self.subTest(field=field, projection=projection):
                    with self.assertRaisesRegex(ValueError, "detach before"):
                        inspect_instance_storage(self.changed(
                            projection, projection.replace("      ensureUniqueStorage()\n", "")))

    def test_shared_clone_and_each_field_copy_are_required(self):
        with self.assertRaisesRegex(ValueError, "clone shared"):
            inspect_instance_storage(self.changed(
                "payload = Storage(copying: payload)", "payload = payload"))
        for field in self.fields[4:]:
            helper = "copy" + field[0].upper() + field[1:]
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, "allocate first"):
                inspect_instance_storage(self.changed(f"      {helper}(from: source)\n", ""))
        with self.assertRaisesRegex(ValueError, "same logical member"):
            inspect_instance_storage(self.changed("revision = source.revision", "revision = source.randomState"))

    def test_copy_helpers_cannot_be_inlined_into_an_aggregate_frame(self):
        with self.assertRaisesRegex(ValueError, "separate frames"):
            inspect_instance_storage(self.changed(
                "    @inline(never)\n    private func copyData", "    private func copyData"))

    def test_every_codec_key_and_encoder_call_is_required(self):
        for field in self.fields:
            helper = "encode" + field[0].upper() + field[1:]
            for before in [f"    case {field}\n", f"      try {helper}(to: &values)\n"]:
                with self.subTest(field=field, before=before), self.assertRaisesRegex(ValueError, "Codec"):
                    inspect_instance_storage(self.changed(before, ""))

    def test_required_decode_and_optional_omission_cannot_be_defaulted(self):
        for before, after in [
            ("values.decode(UInt64.self, forKey: .revision)", "values.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0"),
            ("values.decodeIfPresent(String.self, forKey: .suspension)", "values.decode(String.self, forKey: .suspension)"),
            ("values.encodeIfPresent(suspension, forKey: .suspension)", "values.encode(suspension, forKey: .suspension)"),
        ]:
            with self.subTest(before=before), self.assertRaisesRegex(ValueError, "Codec"):
                inspect_instance_storage(self.changed(before, after))


    def test_default_constructor_and_each_field_initializer_are_required(self):
        for name in self.wrapped:
            helper = "initialize" + name[0].upper() + name[1:]
            before = f"      {helper}()\n"
            with self.subTest(field=name), self.assertRaisesRegex(ValueError, "Default construction"):
                inspect_instance_storage(self.changed(before, ""))
        with self.assertRaisesRegex(ValueError, "Clone allocation"):
            inspect_instance_storage(self.changed(
                "      self.digest = digest", "      self.digest = digest\n      initializeSavedGlassMeridian()"))

    def test_child_handle_cannot_replace_the_original_logical_equality(self):
        with self.assertRaisesRegex(ValueError, "logical field values"):
            inspect_instance_storage(self.changed(
                "lhs.savedGlassMeridian!.value == rhs.savedGlassMeridian!.value",
                "lhs.savedGlassMeridian == rhs.savedGlassMeridian"))

    def test_optional_tag_reader_requires_borrowed_presence_without_payload_projection(self):
        for before, after in [
            ("    @inline(never)\n    func hasValue()", "    func hasValue()"),
            ("    @inline(never)\n    private static func isPresent",
             "    private static func isPresent"),
            ("values.withUnsafeBufferPointer { storage in",
             "values.withUnsafeMutableBufferPointer { storage in"),
            ("Self.isPresent(storage.baseAddress!.pointee)", "Self.isPresent(values[0])"),
            ("Self.isPresent(storage.baseAddress!.pointee)", "Self.isPresent(value)"),
            ("Self.isPresent(storage.baseAddress!.pointee)", "true"),
            ("isPresent(_ value: borrowing Value?)", "isPresent(_ value: Value?)"),
            ("case .none: false", "case .none: true"),
            ("case .some: true", "case .some: false"),
            ("switch value {", "switch value { default: true"),
            ("    func hasValue() -> Bool {", "    func uncheckedReader() -> Bool {"),
            ("    func hasValue() -> Bool {",
             "    func extraUncheckedReader() -> Bool { true }\n    func hasValue() -> Bool {"),
        ]:
            with self.subTest(before=before, after=after), self.assertRaisesRegex(ValueError, "typed Array COW"):
                inspect_instance_storage(self.changed(before, after))

    def test_typed_field_cow_and_initialized_count_cannot_be_removed(self):
        for before, after in [
            ("_modify { yield &values[0] }", "_modify { fatalError() }"),
            ("initializedCount = 1", "initializedCount = 0"),
            ("destination.baseAddress!.initialize(to: nil)", ""),
            ("    @inline(never)\n    init() {", "    init() {"),
        ]:
            with self.subTest(before=before), self.assertRaisesRegex(ValueError, "typed Array COW"):
                inspect_instance_storage(self.changed(before, after))



    def test_new_mission_fields_retain_logical_equality_and_optional_codec(self):
        for field, value_type in [
            ("savedHollowManifest", "NativeHollowManifestState"),
            ("savedTitheCommission", "NativeTitheCommissionState"),
        ]:
            for before, after, reason in [
                (f"lhs.{field}!.value == rhs.{field}!.value",
                 f"lhs.{field} == rhs.{field}", "logical field values"),
                (f"lhs.{field}!.value == rhs.{field}!.value",
                 f"lhs.{field}!.value == rhs.savedGlassMeridian!.value", "same member"),
                (f"{field} = source.{field}", f"{field} = source.savedGlassMeridian",
                 "same logical member"),
                (f"{value_type}.self, forKey: .{field}",
                 f"{value_type}.self, forKey: .savedGlassMeridian", "Codec"),
                (f"try values.encodeIfPresent({field}!.value, forKey: .{field})",
                 f"try values.encode({field}!.value, forKey: .{field})", "Codec"),
                (f"{field} = Field<{value_type}>()", f"{field} = nil", "Default construction"),
            ]:
                with self.subTest(field=field, before=before), self.assertRaisesRegex(ValueError, reason):
                    inspect_instance_storage(self.changed(before, after))


class ScriptEngineEqualityInventoryTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()

    def test_actual_fields_include_inferred_clocks_and_exclude_computed_aliases(self):
        fields = inspect_equality(self.source, "ScriptEngineState")
        self.assertEqual(fields[-4:], [
            "flightSeconds", "localSeconds", "calendarSeconds", "transitSeconds"
        ])
        self.assertIn("savedWorldJobs", fields)
        self.assertNotIn("worldJobs", fields)

    def test_added_engine_stored_field_cannot_be_omitted(self):
        changed = self.source.replace(
            "  var savedMeasuredExtractionSource:",
            "  var omittedByFixture: Int\n  var savedMeasuredExtractionSource:",
            1,
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed, "ScriptEngineState")

    def test_engine_stored_field_after_initializer_cannot_evade_inventory(self):
        changed = self.source.replace(
            "  public init() {}",
            "  public init() {}\n  public var omittedAfterInitializer: Int = 0",
            1,
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed, "ScriptEngineState")

    def test_only_original_inferred_clock_declarations_are_supported(self):
        changed = self.source.replace(
            "  public var flightSeconds = 0.0", "  public var addedByFixture = 0.0\n  public var flightSeconds = 0.0", 1
        )
        with self.assertRaisesRegex(ValueError, "explicit type"):
            inspect_equality(changed, "ScriptEngineState")


class CommanderEqualityInventoryTests(unittest.TestCase):
    def setUp(self):
        self.source = COMMANDER_SOURCE.read_text()

    def test_private_saved_fields_are_compared_instead_of_defaulting_projections(self):
        fields = inspect_equality(self.source, "Commander")
        self.assertIn("savedScriptState", fields)
        self.assertIn("savedNativePeopleCustodyStorage", fields)
        self.assertNotIn("scriptState", fields)
        self.assertNotIn("savedNativePeopleCustody", fields)

    def test_added_commander_stored_field_after_initializer_is_rejected(self):
        changed = self.source.replace(
            "  public var availableCredits: Int {",
            "  var omittedByFixture: Int\n  public var availableCredits: Int {",
            1,
        )
        with self.assertRaisesRegex(ValueError, "every stored field"):
            inspect_equality(changed, "Commander")

    def test_unknown_commander_inferred_declaration_is_rejected(self):
        changed = self.source.replace(
            "  public var name = NewCommanderDefaults.name",
            "  var addedByFixture = false\n  public var name = NewCommanderDefaults.name",
            1,
        )
        with self.assertRaisesRegex(ValueError, "explicit type"):
            inspect_equality(changed, "Commander")


    def changed(self, before, after):
        self.assertIn(before, self.source)
        return self.source.replace(before, after, 1)

    def test_both_current_equality_paths_cover_all_fields_in_the_same_order(self):
        fields = inspect_equality(self.source, "Commander")
        self.assertEqual(fields[0], "savedMemoryAtlasWatcherSourceStorage")
        self.assertEqual(fields[-1], "finiteXYZzyCash")
        self.assertIn("savedNativePeopleCustodyStorage", fields)

    def test_entry_whitespace_does_not_change_the_checked_equality_contract(self):
        expected = inspect_equality(self.source, "Commander")
        for before, after in [
            ("public static func == (", "public static func ==\n  ("),
            ("fileprivate static func storedValuesEqual(",
             "fileprivate static func storedValuesEqual ("),
        ]:
            with self.subTest(before=before):
                self.assertEqual(inspect_equality(self.changed(before, after), "Commander"), expected)

    def test_reviewed_flight_bison_order_is_preserved_in_both_entries(self):
        fields = inspect_equality(self.source, "Commander")
        position = fields.index("savedBisonUnitAllocations")
        self.assertEqual(fields[position:position + 2],
                         ["savedBisonUnitAllocations", "savedFlightSimulation"])
        flight = "    guard equalSavedFlightSimulation(lhs, rhs) else { return false }\n"
        bison = "    guard equalSavedBisonUnitAllocations(lhs, rhs) else { return false }\n"
        self.assertEqual(self.source.count(flight + bison), 2)
        for occurrence in (0, 1):
            before = flight + bison
            index = [match.start() for match in re.finditer(re.escape(before), self.source)][occurrence]
            changed = self.source[:index] + bison + flight + self.source[index + len(before):]
            with self.subTest(occurrence=occurrence), self.assertRaises(ValueError):
                inspect_equality(changed, "Commander")

    def test_borrowed_and_pointer_members_cannot_be_crossed_or_defaulted(self):
        for before, after in [
            ("withUnsafePointer(to: rhs)", "withUnsafePointer(to: lhs)"),
            ("return left == right", "return true"),
            (r"pointer.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee",
             r"pointer.pointer(to: \.savedContracts)!.pointee"),
            (r"rhs.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee",
             r"rhs.pointer(to: \.savedContracts)!.pointee"),
            ("_ lhs: borrowing Self, _ rhs: borrowing Self",
             "_ lhs: Self, _ rhs: Self"),
        ]:
            with self.subTest(before=before), self.assertRaises(ValueError):
                inspect_equality(self.changed(before, after), "Commander")

    def test_each_entry_requires_every_guard_once_in_order_without_early_success(self):
        first = "    guard equalSavedMemoryAtlasWatcherSourceStorage(lhs, rhs) else { return false }\n"
        second = "    guard equalSavedContracts(lhs, rhs) else { return false }\n"
        # Mutate either public borrowed equality or the later pointer entry.
        for occurrence in (0, 1):
            for old, new in [(first, ""), (first, first + first),
                             (first + second, second + first), (first, "    return true\n" + first)]:
                index = [match.start() for match in re.finditer(re.escape(old), self.source)][occurrence]
                changed = self.source[:index] + new + self.source[index + len(old):]
                with self.subTest(occurrence=occurrence, replacement=new), self.assertRaises(ValueError):
                    inspect_equality(changed, "Commander")

    def test_neither_helper_family_accepts_extra_logic_or_a_changed_comparison(self):
        pointer = (r"lhs.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee == "
                   r"rhs.pointer(to: \.savedMemoryAtlasWatcherSourceStorage)!.pointee")
        for before, after in [
            ("return left == right", "return left == right || true"),
            ("return left == right", "return left != right"),
            ("let left = withUnsafePointer(to: lhs)",
             "let unusedFixture = true\n    let left = withUnsafePointer(to: lhs)"),
            (pointer, pointer + " || true"),
            (pointer, pointer.replace(" == ", " != ")),
            ("_ lhs: UnsafePointer<Self>, _ rhs: UnsafePointer<Self>\n  ) -> Bool {\n    lhs.pointer",
             "_ lhs: UnsafePointer<Self>, _ rhs: borrowing Self\n  ) -> Bool {\n    lhs.pointer"),
        ]:
            with self.subTest(before=before, after=after), self.assertRaises(ValueError):
                inspect_equality(self.changed(before, after), "Commander")

    def test_duplicate_missing_and_unbounded_helper_frames_are_rejected(self):
        helper = "equalSavedMemoryAtlasWatcherSourceStorage"
        for before, after in [
            (f"  @inline(never)\n  private static func {helper}(", f"  private static func {helper}("),
            (f"  private static func {helper}(", "  private static func equalMissingFixture("),
        ]:
            with self.subTest(before=before), self.assertRaises(ValueError):
                inspect_equality(self.changed(before, after), "Commander")


if __name__ == "__main__":
    unittest.main()
