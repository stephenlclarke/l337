import Foundation
import Testing

@testable import L337Core

/// Exercises the EXISTING raw-input loader, not just its validator. Adds no raw reader,
/// migration policy or positive native authority fixture. All execution is UNRUN.
struct NativeUnderTowRawLoadBoundaryUnitTests {
  @Test func misplacedRawClaimsRefuseBeforeDecodeAndPreserveTheActualLiveCommanderAndFiles() async throws {
    let fixture = try await UnderTowOpeningFixture()
    defer { fixture.clean() }
    // Existing accepted base input: establish that the input itself reaches the raw path
    // successfully. This prevents an unrelated decoder/fit refusal satisfying the negatives.
    var base = Commander()
    base.name = "RAW-CONTROL"
    let baseBytes = try JSONEncoder().encode(base)
    let controlURL = fixture.files.root.appendingPathComponent("raw-control.json")
    try baseBytes.write(to: controlURL)
    let control = GameRuntime(game: Game(executive: false))
    try await control.load(from: controlURL, persistMigrations: false)
    #expect(await control.snapshot().commander.name == base.name)
    #expect(try Data(contentsOf: controlURL) == baseBytes)
    #expect(throws: (any Error).self) { try JSONDecoder().decode(ScriptSavePointer.self, from: baseBytes) }

    let text = try #require(String(data: baseBytes, encoding: .utf8))
    try #require(text.last == "}")
    let input = fixture.files.root.appendingPathComponent("misplaced-raw-claim.json")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for key in ["savedUnderTow", "underTow", "savedUnder\\u0054ow", "under\\u0054ow"] {
      for value in ["{}", "null"] {
        let bytes = Data((String(text.dropLast()) + ",\"" + key + "\":" + value + "}").utf8)
        try bytes.write(to: input)
        let before = await fixture.runtime.snapshot()
        try #require(before.nativeMainStationDockEvidenceIsCurrent)
        let world = try encoder.encode(before.scriptWorldSave)
        let files = try ScriptFinanceTestFixture.files(fixture.files.root)
        await #expect(throws: SaveError.invalidCommander) {
          try await fixture.runtime.load(from: input, persistMigrations: false)
        }
        let refused = await fixture.runtime.snapshot()
        #expect(refused.commander == before.commander && refused.bodies == before.bodies)
        #expect(refused.nativeStationRuntimeEpoch == before.nativeStationRuntimeEpoch)
        #expect(refused.inventoryContextEpoch == before.inventoryContextEpoch)
        #expect(refused.nativeMainStationDockEvidenceIsCurrent)
        #expect(try encoder.encode(refused.scriptWorldSave) == world)
        #expect(try Data(contentsOf: input) == bytes)
        #expect(try ScriptFinanceTestFixture.files(fixture.files.root) == files)
      }
    }
    #expect(try Data(contentsOf: controlURL) == baseBytes)
  }
}
