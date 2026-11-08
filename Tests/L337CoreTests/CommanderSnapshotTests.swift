import Foundation
import Testing

@testable import L337Core

@Test func contractAndRefusedReviewResourcesRemainFrozenAcrossNestedMutations() {
  var game = Game(executive: false)
  var source = game.commander
  source.cargo[0] = 2
  let station = ScriptStationResource(identity: UUID(), galaxy: 0, system: 7)
  source.scriptState.stationResources[station.key] = station
  game.commander = source
  let original = source.contractQuoteResources
  let contract = game.contractAcceptanceQuote(board: "missing-snapshot-board", offer: UUID())
  let refused = game.contractAcceptanceQuote(board: "other-missing-board", offer: UUID())
  let token = contract.reviewToken
  #expect(!contract.allowed && !refused.allowed)

  source.credits += 10
  source.cargo[0] = 9
  source.equipment.insert("Fuel Scoops")
  source.scriptState.stationResources[station.key]?.energy = 50
  #expect(source != original)
  #expect(contract.resources == original && refused.resources == original)

  for var readback in [contract.resources, refused.resources] {
    readback.credits = 0
    readback.cargo[0] = 0
    readback.equipment.removeAll()
    readback.scriptState.stationResources[station.key]?.destroyed = true
    #expect(readback != original)
    #expect(contract.resources == original && refused.resources == original)
  }
  var copied = contract
  copied.reviewToken = UUID()
  #expect(contract.reviewToken == token)
  #expect(copied.resources == original && !refused.allowed)
}
