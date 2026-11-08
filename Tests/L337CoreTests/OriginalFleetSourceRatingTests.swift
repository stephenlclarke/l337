import Foundation
import Testing

@testable import L337Core

struct OriginalFleetSourceRatingTests {
  @Test(arguments: [false, true])
  func actualOriginalSourceNotesUseVisiblePrecisionAndRealPriceDirection(reverse: Bool) throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let before = game.commander
    let onager = try #require(OriginalFleetR3Data.contract(for: "SH018")?.performance)
    let okapi = try #require(OriginalFleetR3Data.contract(for: "SH029")?.performance)
    #expect(onager.yaw == 0.84 && okapi.yaw == 0.78)
    #expect(onager.price == 281000 && okapi.price == 312000)
    game.showroom.baselineUsesCurrent = false
    game.showroom.baseline = reverse ? "SH029" : "SH018"
    game.showroom.selection = reverse ? "SH018" : "SH029"
    game.showroom.sourceProfiles = true
    game.showroom.profileIndex = try #require(game.showroomProfiles.firstIndex { $0.group == "project-refit-v1" })
    let baseline = try #require(game.showroomBaselineProfile)
    let selected = try #require(game.showroomProfile)
    try #require(baseline.group == "project-refit-v1" && selected.group == baseline.group)
    let left = try #require(baseline.fields.first { $0.key == "yaw_radians_per_second" })
    let right = try #require(selected.fields.first { $0.key == "yaw_radians_per_second" })
    #expect(left.number == (reverse ? 0.78 : 0.84) && right.number == (reverse ? 0.84 : 0.78))
    #expect(left.text == (reverse ? "0.78 rad/s" : "0.84 rad/s"))
    #expect(right.text == (reverse ? "0.84 rad/s" : "0.78 rad/s"))
    #expect(left.unit == "rad/s" && right.unit == left.unit)
    let yaw = try #require(game.showroomComparison.first { $0.label == right.label })
    #expect(yaw.baseline.hasPrefix(left.text) && yaw.selected.hasPrefix(right.text))
    #expect(!yaw.difference.isEmpty && yaw.rating == (reverse ? .better : .worse))
    let leftPrice = try #require(baseline.fields.first { $0.key == "hull_price_credits" })
    let rightPrice = try #require(selected.fields.first { $0.key == "hull_price_credits" })
    #expect(leftPrice.unit == "CR" && rightPrice.unit == "CR")
    #expect(leftPrice.number == Double(reverse ? 312000 : 281000))
    #expect(rightPrice.number == Double(reverse ? 281000 : 312000))
    let price = try #require(game.showroomComparison.first { $0.label == rightPrice.label })
    #expect(!price.difference.isEmpty && price.rating == (reverse ? .better : .worse))
    #expect(game.commander == before)
  }

  @Test func actualCompatibleNativeProjectionsKeepEqualDisplayedTenthsAndPriceDirection() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let before = game.commander
    game.showroom.baselineUsesCurrent = false
    game.showroom.baseline = "SH018"
    game.showroom.selection = "SH029"
    game.showroom.sourceProfiles = false
    let baseline = try #require(game.showroomBaselineProfile)
    let selected = try #require(game.showroomProfile)
    try #require(baseline.group == "native-game" && selected.group == baseline.group)
    let left = try #require(baseline.fields.first { $0.key == "yaw_radians_per_second" })
    let right = try #require(selected.fields.first { $0.key == "yaw_radians_per_second" })
    // Require actual transfer availability; an unavailable profile cannot be this control.
    try #require(left.number == 0.84 && right.number == 0.78)
    #expect(left.text == "0.8 rad/s" && right.text == left.text)
    let yaw = try #require(game.showroomComparison.first { $0.label == right.label })
    #expect(yaw.rating == .same)
    let price = try #require(game.showroomComparison.first { $0.label == "Hull price" })
    #expect(price.rating == .worse)
    #expect(game.commander == before)
  }

  @Test func actualUnavailableFitsAndIncompatibleSourceGroupsNeverReceiveBenefitRatings() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    let before = game.commander
    game.showroom.selection = "SH036"
    try #require(OriginalDetailedHullStage.blocksRuntime("SH036"))
    let unavailable = try #require(game.showroomProfile)
    #expect(unavailable.fields.allSatisfy { $0.number == nil && $0.text == "Unavailable" })
    #expect(game.showroomComparison.allSatisfy { $0.rating == .unavailable })
    game.showroom.selection = "SH018"
    game.showroom.sourceProfiles = true
    game.showroom.profileIndex = try #require(game.showroomProfiles.firstIndex { $0.group == "project-refit-v1" })
    let source = try #require(game.showroomProfile)
    let native = before.gameShipProfile
    let left = try #require(native.fields.first { $0.key == "yaw_radians_per_second" })
    let right = try #require(source.fields.first { $0.key == "yaw_radians_per_second" })
    try #require(left.unit == right.unit && native.group != source.group)
    let compatible = game.comparableShowroomField(left, right, baseline: native, selected: source)
    #expect(!compatible)
    #expect(ComparisonRating.compare(left, right, compatible: compatible) == .unavailable)
    #expect(game.commander == before)
  }
}
