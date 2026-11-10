import Foundation
import Testing

@testable import L337Core

private struct WantedNewtCarrierInput {
  let ledger: WantedCareerLedger
  let career: WantedCareer
  let stock: CurrentNewtKitStock
  let actor: ActorIdentity
  let header: Data
}

/// Runs in the existing W03 qualification, using an actually born kit and captured NPC.
func verifyWantedNewtCarrierControls() async throws {
  let input = try await wantedNewtCarrierInput()
  try verifyWantedNewtCarrierClaims(input)
}

// Return into the suspended caller's async storage before it captures or encodes
// the game. The native birth runs without the control helper's value temporaries
// and assertion captures occupying its synchronous stack.
@inline(never)
private func bornWantedNewtCarrierGame() async throws -> Game {
  try NativePagedSalvageFixture.equippedNewtStowedGame()
}

private func wantedNewtCarrierInput() async throws -> WantedNewtCarrierInput {
  var game = try await bornWantedNewtCarrierGame()
  let candidate = game.bodies.first { $0.physical?.currentNewtKitStock != nil }
  let body = try #require(candidate)
  let context = try #require(game.gameplayContext())
  let captured = NPCPersistenceSnapshot.capture(
    body: body, pose: game.commander.flightSimulation.pose,
    physicalTime: game.commander.flightSimulation.physicalTime,
    protection: context.protection)
  let snapshot = try #require(captured)
  let stock = try #require(snapshot.currentNewtKitStock)
  var ledger = WantedCareerLedger()
  ledger.observe(snapshot, logical: snapshot.actor, visible: true)
  try #require(ledger.valid(in: game.commander.flightSimulation))
  let career = try #require(ledger.careers[snapshot.actor])
  try #require(career.parked?.currentNewtKitStock == stock)
  game.commander.wantedCareers = ledger

  let original = game.commander
  let fullHeader = try JSONEncoder().encode(game.commander)
  #expect(game.commander == original)
  return .init(
    ledger: ledger, career: career, stock: stock, actor: snapshot.actor, header: fullHeader)
}

private func verifyWantedNewtCarrierClaims(_ input: WantedNewtCarrierInput) throws {
  let ledger = input.ledger
  let career = input.career
  let stock = input.stock
  let fullHeader = input.header
  func encoded(_ value: some Encodable) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
  }
  func json(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: .sortedKeys)
  }
  let rawStock = try encoded(stock)
  let parked: [String: Any] = ["currentNewtKitStock": rawStock]
  let arrayHeader: [String: Any] = ["savedWantedCareers": try encoded(ledger)]
  // Codable non-string dictionary keys produce alternating key/value arrays. The
  // lexical boundary also supports object dictionaries, as for NPC persistence.
  let objectHeader: [String: Any] = [
    "savedWantedCareers": ["careers": ["codec-only-key": ["parked": parked]]]
  ]
  for schema in [CurrentNewtKitSave.version, CurrentNewtKitSave.alienVersion] {
    for header in [arrayHeader, objectHeader] {
      #expect(
        try CurrentNewtKitSave.validateFields(
          json(header), location: .commander, schema: schema))
    }
    #expect(
      try CurrentNewtKitSave.validateFields(fullHeader, location: .commander, schema: schema))
  }

  // A raw carrier is not authority to create a career, substitute its actor, or
  // detach the captured kit from the current flight counters and physical clock.
  var forged = career
  forged.binding = .init(
    system: input.actor.system, visit: input.actor.visit,
    entity: input.actor.entity + 1)
  #expect(!forged.valid)
  forged = career
  forged.ship = "SH025"
  #expect(!forged.valid)
  forged = career
  forged.parked?.physicalTime = -1
  #expect(!forged.valid)

  let misplaced: [[String: Any]] = [
    ["savedWantedCareers": ["currentNewtKitStock": rawStock]],
    ["savedWantedCareers": ["parked": parked]],
    ["savedWantedCareers": ["careers": ["key": parked]]],
    ["savedWantedCareers": ["careers": ["key": ["snapshot": parked]]]],
    ["savedWantedCareers": ["careers": ["key": ["sighting": parked]]]],
    ["opaque": ["savedWantedCareers": ["careers": ["key": ["parked": parked]]]]],
    ["savedNPCPersistence": ["careers": ["key": ["parked": parked]]]],
    ["savedWantedCareers": ["aliases": ["key": ["parked": parked]]]],
    [
      "savedWantedCareers": [
        "careers": [
          "key": [
            "parked": [
              "currentNewtKitReceipt": rawStock
            ]
          ]
        ]
      ]
    ],
    [
      "savedWantedCareers": [
        "careers": [
          "key": [
            "parked": [
              "currentNewtKitConfiguration": "not-a-birth-request"
            ]
          ]
        ]
      ]
    ],
    [
      "savedWantedCareers": [
        "careers": [
          "key": [
            "parked": [
              "currentNewtKitStock": NSNull()
            ]
          ]
        ]
      ]
    ],
    [
      "savedWantedCareers": [
        "careers": [
          "key": [
            "parked": [
              "currentNewtKitStock": ["phase": "stowed"]
            ]
          ]
        ]
      ]
    ],
  ]
  for header in misplaced {
    #expect(throws: (any Error).self) {
      try CurrentNewtKitSave.validateFields(
        json(header), location: .commander, schema: CurrentNewtKitSave.version)
    }
  }
  for schema in [nil, 143, 144] as [Int?] {
    #expect(throws: (any Error).self) {
      try CurrentNewtKitSave.validateFields(
        json(arrayHeader), location: .commander, schema: schema)
    }
  }
  for location in [
    ScriptSaveJSONPreflight.InquiryArchiveLocation.world, .missions, .contracts, .pointer,
  ] {
    #expect(throws: (any Error).self) {
      try CurrentNewtKitSave.validateFields(
        json(arrayHeader), location: location, schema: CurrentNewtKitSave.version)
    }
  }
}
