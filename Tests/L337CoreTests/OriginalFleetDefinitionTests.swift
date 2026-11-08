import Testing

@testable import L337Core

struct OriginalFleetDefinitionTests {
  @Test func currentDefinitionsPreserveR3ValuesAndExplicitUnpricedCapitalPolicy() throws {
    let definitions = OriginalFleetDefinitionData.staged
    #expect(definitions.count == 171)
    #expect(Set(definitions.map(\.id)).count == 171)
    for (id, definition) in zip(OriginalFleetR3Data.ids, definitions) {
      let loaded = try #require(ShipCatalogue.originalDefinition(for: id))
      #expect(loaded.id == id && definition.id == id)
      #expect(loaded.authored == definition.authored && loaded.sourceSHA256 == definition.sourceSHA256)
      #expect(loaded.sourcePath == definition.sourcePath && loaded.integrationBlockers == definition.integrationBlockers)
    }
    for unknown in ["", "SH000", "sh029", "SH029 ", "SH172", "SH999"] {
      #expect(ShipCatalogue.originalDefinition(for: unknown) == nil)
    }
    let optionalMule = definitions.first { $0.id == "SH001" }
    let mule = try #require(optionalMule)
    #expect(mule.name == "Mule" && mule.family == "mule")
    #expect(mule.nativePerformance?.cargo == 76)
    #expect(mule.nativePerformance?.speed == 33.2)
    guard case .object(let access)? = mule.authored["access"] else {
      Issue.record("Missing current access contract")
      return
    }
    #expect(access["playerFlyable"] == .boolean(true))
    let conflicts = definitions.filter { $0.nativePerformance?.valid == false }.map(\.id)
    #expect(conflicts == ["SH040", "SH043", "SH081", "SH123"])
    let optionalMedusa = definitions.first { $0.id == "SH171" }
    let medusa = try #require(optionalMedusa)
    #expect(medusa.purchasePolicy == "plughQuestFabrication")
    #expect(
      definitions.filter(\.runtimeReady).map(\.id) == [
        "SH002", "SH003", "SH004", "SH012", "SH018", "SH019", "SH027", "SH029", "SH030",
        "SH031", "SH032", "SH033", "SH035", "SH061", "SH103", "SH108",
      ])
  }
}
