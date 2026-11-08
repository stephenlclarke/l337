import Foundation
import Testing

@testable import L337Core

struct OriginalFleetDiscoveryProgressTests {
  @Test func wholeCurrentCollectionIncludesPendingOriginalsAndStationSubtypesExactlyOnce() throws {
    let ships = ShipCatalogue.all
    try #require(ships.count == 171 && Set(ships.map(\.id)).count == 171)
    let excluded: Set<String> = ["SH040", "SH156", "SH162", "SH171"]
    let expected = Set(ships.map(\.id)).subtracting(excluded)
    let actual = ships.filter { $0.originalDefinition != nil && $0.catalogue.discoveryEligible }
    #expect(Set(actual.map(\.id)) == expected && actual.count == 167)
    #expect(actual.filter { $0.catalogue.objectKind == .station || $0.catalogue.objectKind == .platform }.count == 6)
    #expect(actual.contains { OriginalDetailedHullStage.blocksRuntime($0.id) })
    #expect(excluded.allSatisfy { id in ships.first { $0.id == id }?.catalogue.discoveryEligible == false })
    let platform = try #require(ships.first { $0.id == "SH156" })
    #expect(platform.catalogue.objectKind == .platform && platform.catalogue.capitalSubtype == .platform)
    #expect(platform.catalogue.collectionMilestone == .none && !platform.catalogue.discoveryEligible)
    #expect(!expected.contains(platform.id) && !actual.contains { $0.id == platform.id })
    let game = Game(executive: false)
    let progress = NativeFleetDiscoveryProgress(commander: game.commander)
    #expect(progress.encountered == 0 && progress.total == expected.count)
    #expect(progress.label == "Seen 0/167")
  }

  @Test func browsingFiltersAndOwnedHullNeverCreateProgressOrChangeTheGlobalGoal() throws {
    var game = Game(executive: false)
    try game.commander.prepareEquipment(legacy: false)
    game.screen = .showroom
    game.showroom.detail = false
    game.showroom.compare = false
    let before = game.commander
    let progress = NativeFleetDiscoveryProgress(commander: before)
    try #require(progress.encountered == 0 && progress.total == 167)
    for width in [512.0, 1512] {
      for query in ["", "SH025", "SH040", "SH156", "no-such-original-ship"] {
        game.showroom.query = query
        game.showroom.sourceProfiles = !game.showroom.sourceProfiles
        let layout = ShowroomLayout(width: width, height: 982, detail: false)
        let frame = Display.showroomScreen(game, width: width, height: 982)
        let label = try #require(frame.labels.first { $0.text == progress.label })
        let heading = try #require(frame.labels.first { $0.text == "> Ships" })
        #expect(label.y == heading.y && label.x >= heading.bounds.maxX)
        #expect(label.bounds.maxX <= layout.list.maxX)
        #expect(NativeFleetDiscoveryProgress(commander: game.commander) == progress)
        #expect(game.commander == before)
      }
    }
  }
}
