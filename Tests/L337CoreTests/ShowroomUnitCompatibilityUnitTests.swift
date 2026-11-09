import Foundation
import Testing

@testable import L337Core

struct ShowroomUnitCompatibilityUnitTests {
  private func profile(_ group: String) -> ShipProfile {
    .init(id: group, title: group, group: group, context: "unit compatibility fixture", fields: [])
  }

  private func field(_ value: Double, unit: String) -> ShipSpec {
    .init(
      key: "capacity", label: "Capacity", text: NativeShipValueFormat.tenths(value) + " " + unit,
      number: value, unit: unit, status: "game", basis: "unit compatibility fixture")
  }

  private func sourceComparison(baseline: String, selected: String) throws -> Game {
    var game = Game(executive: false)
    game.showroom.baselineUsesCurrent = false
    game.showroom.baseline = baseline
    game.showroom.selection = selected
    game.showroom.sourceProfiles = true
    game.showroom.profileIndex = try #require(
      game.showroomProfiles.firstIndex {
        $0.group == "project-refit-v1"
      })
    return game
  }

  @Test func differentCharterUnitsNeverGainBenefitsFromTheirSharedProfileGroup() throws {
    for (baseline, selected) in [("SH023", "SH013"), ("SH013", "SH023")] {
      let game = try sourceComparison(baseline: baseline, selected: selected)
      let before = game.commander
      let baselineProfile = try #require(game.showroomBaselineProfile)
      let selectedProfile = try #require(game.showroomProfile)
      #expect(baselineProfile.group == selectedProfile.group)
      for key in ["hull_energy", "initial_charter_passenger_berths"] {
        let a = try #require(baselineProfile.fields.first { $0.key == key })
        let b = try #require(selectedProfile.fields.first { $0.key == key })
        #expect(a.unit != b.unit)
        if key == "hull_energy" {
          #expect(a.number == (baseline == "SH023" ? 320.0 : 710.0))
          #expect(b.number == (selected == "SH023" ? 320.0 : 710.0))
        } else {
          #expect(a.number == 0 && b.number == 0)
        }
        #expect(!game.comparableShowroomField(a, b, baseline: baselineProfile, selected: selectedProfile))
        let row = try #require(game.showroomComparison.first { $0.label == b.label })
        #expect(row.rating == .unavailable && row.difference.isEmpty)
        #expect(row.baseline.hasPrefix(a.text) && row.selected.hasPrefix(b.text))
      }
      #expect(game.commander == before)
    }
  }

  @Test func matchingBlankAndExplicitSourceUnitsKeepTheirExistingComparisons() throws {
    let charter = "initial_charter_passenger_berths"
    for (baseline, selected, key, unit, rating, difference) in [
      ("SH025", "SH013", charter, "", ComparisonRating.same, "Diff +0"),
      ("SH002", "SH029", charter, "berths", .same, "Diff +0 berths"),
      ("SH169", "SH170", "cargo_tonnes", "t", .better, "Diff +6 t"),
      ("SH170", "SH169", "cargo_tonnes", "t", .worse, "Diff -6 t"),
    ] {
      let game = try sourceComparison(baseline: baseline, selected: selected)
      let a = try #require(
        game.showroomBaselineProfile?.fields.first {
          $0.key == key
        })
      let b = try #require(
        game.showroomProfile?.fields.first {
          $0.key == key
        })
      #expect(a.unit == unit && b.unit == unit)
      #expect(
        game.comparableShowroomField(
          a, b, baseline: game.showroomBaselineProfile, selected: game.showroomProfile))
      let row = try #require(game.showroomComparison.first { $0.label == b.label })
      #expect(row.rating == rating && row.difference == difference)
    }

    // Current original hulls all start with zero charter berths. Exercise nonzero
    // matching berth differences directly without changing a catalogue field.
    let game = Game(executive: false)
    let source = profile("project-refit-v1")
    let one = field(1, unit: "berths"), two = field(2, unit: "berths")
    for (a, b, rating, difference) in [
      (one, two, ComparisonRating.better, "Diff +1 berths"),
      (two, one, .worse, "Diff -1 berths"),
    ] {
      let compatible = game.comparableShowroomField(a, b, baseline: source, selected: source)
      #expect(compatible && ComparisonRating.compare(a, b, compatible: compatible) == rating)
      #expect(ShipComparisonRow.difference(a, b, comparable: compatible) == difference)
    }
  }

  @Test func nativePrecisionAndCrossProfileCapacityPolicyRemainUnchanged() {
    let game = Game(executive: false)
    let native = profile("native-game")
    let source = profile("project-refit-v1")
    let current = profile("native-current")
    let a = field(1.24, unit: "speed")
    let b = field(1.25, unit: "speed")
    let compatible = game.comparableShowroomField(a, b, baseline: native, selected: native)
    #expect(compatible && ComparisonRating.compare(a, b, compatible: compatible) == .same)
    #expect(
      !game.comparableShowroomField(
        a, field(1.25, unit: "km/s"), baseline: native, selected: native))
    #expect(!game.comparableShowroomField(nil, b, baseline: native, selected: native))
    #expect(!game.comparableShowroomField(a, nil, baseline: native, selected: native))
    for unit in ["t", "LY", "0.1 LY", "people", "berths", "missiles", "pylons"] {
      let left = field(1, unit: unit)
      let right = field(2, unit: unit)
      #expect(game.comparableShowroomField(left, right, baseline: current, selected: source))
      #expect(!game.comparableShowroomField(right, left, baseline: source, selected: current))
      #expect(!game.comparableShowroomField(left, right, baseline: native, selected: source))
    }
    #expect(
      !game.comparableShowroomField(
        field(1, unit: "t"), field(2, unit: "kg"), baseline: current, selected: source))
    #expect(!game.comparableShowroomField(a, b, baseline: current, selected: source))
    let infinite = field(.infinity, unit: "speed")
    #expect(
      ComparisonRating.compare(
        infinite, b,
        compatible: game.comparableShowroomField(infinite, b, baseline: native, selected: native))
        == .unavailable)
  }
}
