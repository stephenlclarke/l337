import Foundation
import Testing

@testable import L337Core

/// Runs in the existing W03 qualification, using an actually born kit and captured NPC.
func verifyWantedNewtCarrierControls() throws {
  var game = try NativePagedSalvageFixture.equippedNewtStowedGame()
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
  let fullHeader = try JSONEncoder().encode(game.commander)
  let original = game.commander
  for schema in [CurrentNewtKitSave.version, CurrentNewtKitSave.alienVersion] {
    for header in [arrayHeader, objectHeader] {
      #expect(
        try CurrentNewtKitSave.validateFields(
          json(header), location: .commander, schema: schema))
    }
    #expect(
      try CurrentNewtKitSave.validateFields(fullHeader, location: .commander, schema: schema))
  }
  #expect(game.commander == original)

  // A raw carrier is not authority to create a career, substitute its actor, or
  // detach the captured kit from the current flight counters and physical clock.
  var forged = career
  forged.binding = .init(
    system: snapshot.actor.system, visit: snapshot.actor.visit,
    entity: snapshot.actor.entity + 1)
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
