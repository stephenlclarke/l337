import Foundation
import Testing

@testable import L337Core

struct CurrentNewtKitSaveTests {
  // Synthetic wire values exercise raw boundaries only. They grant no physical stock or people.
  private let actor = ActorIdentity(system: .init(galaxy: 0, system: 7), visit: 1, entity: 2)

  @Test(arguments: ["stowed", "actuating", "released"])
  func currentEnvelopeAdmitsExactLeavesAtEveryRetainedCarrier(phase: String) throws {
    let stock = try stockObject(phase: phase)
    let physical = ["currentNewtKitStock": stock]
    let snapshot = ["currentNewtKitStock": stock]
    let object = ["body": ["physical": physical]]
    let record: [String: Any] = [
      "hull": object, "pods": [object],
      "custody": ["original": object, "traffic": snapshot],
      "savedCurrentTrafficTransfer": snapshot,
    ]
    let headers: [[String: Any]] = [
      ["savedEMPState": ["records": ["synthetic-key": record]]],
      ["savedEMPState": ["records": [try encoded(actor), record]]],
      ["savedNPCPersistence": ["entries": ["synthetic-key": ["snapshot": snapshot]]]],
      ["savedNPCPersistence": ["entries": [try encoded(actor), ["snapshot": snapshot]]]],
    ]
    for schema in [CurrentNewtKitSave.version, CurrentNewtKitSave.alienVersion] {
      for header in headers {
        #expect(
          try CurrentNewtKitSave.validateFields(
            json(header), location: .commander, schema: schema))
      }
      #expect(
        try CurrentNewtKitSave.validateFields(
          json(["bodies": [["physical": physical]]]), location: .world, schema: schema))
    }
  }

  @Test func currentReceiptSurvivesItsRetainedPodCarrier() throws {
    let receipt = try receiptObject()
    let pod = ["body": ["physical": ["currentNewtKitReceipt": receipt]]]
    let header = ["savedEMPState": ["records": ["synthetic-key": ["pods": [pod]]]]]
    #expect(
      try CurrentNewtKitSave.validateFields(
        json(header), location: .commander, schema: CurrentNewtKitSave.version))
    #expect(
      try CurrentNewtKitSave.validateFields(
        json(["bodies": [["physical": ["currentNewtKitReceipt": receipt]]]]),
        location: .world, schema: CurrentNewtKitSave.alienVersion))
    var retained = try stockObject(phase: "released")
    retained["observedAt"] = 3
    retained["charges"] = charges.mapValues { $0 * 0.5 }
    #expect(
      try CurrentNewtKitSave.validateFields(
        json(["bodies": [["physical": ["currentNewtKitStock": retained]]]]),
        location: .world, schema: CurrentNewtKitSave.version))
    let decoded = try JSONDecoder().decode(CurrentNewtKitStock.self, from: json(retained))
    let historical = try JSONDecoder().decode(CurrentNewtKitReceipt.self, from: json(receipt))
    #expect(decoded.receipt == historical)
  }

  @Test(arguments: [21, 22, 27, 39, 61, 139, 140, 141, 142, 143, 144])
  func predecessorEnvelopesCannotAcquireCurrentKitClaims(schema: Int) throws {
    let stock = try stockObject(phase: "stowed")
    let world = try json(["bodies": [["physical": ["currentNewtKitStock": stock]]]])
    let header = try json([
      "savedNPCPersistence": [
        "entries": [
          "synthetic-key": ["snapshot": ["currentNewtKitStock": stock]]
        ]
      ]
    ])
    for (data, location) in [
      (world, ScriptSaveJSONPreflight.InquiryArchiveLocation.world),
      (header, .commander),
    ] {
      #expect(throws: (any Error).self) {
        try CurrentNewtKitSave.validateFields(data, location: location, schema: schema)
      }
      #expect(throws: (any Error).self) {
        try CurrentNewtKitSave.validateFields(data, location: location, schema: nil)
      }
    }
  }

  @Test(arguments: [
    "unknown", "null", "nested-unknown", "nested-null", "missing",
    "mass", "phase", "actuating", "released", "integer-token", "duplicate", "escaped-duplicate",
    "charges-missing", "charges-null", "charges-negative", "released-charge-increase",
    "observed-missing", "observed-null", "observed-negative", "released-observed",
    "birth-load-missing", "start-load-missing", "work-missing", "work-null",
    "work-unknown", "work-invalid", "service-null", "service-stowed",
    "service-actuating", "service-before-unlock", "service-after-observation",
  ])
  func rawLeafCannotLoseFieldsOrInventAStateDuringDecode(form: String) throws {
    var stock = try stockObject(phase: "stowed")
    let fieldsValidated = try CurrentNewtKitSave.validateFields(
      json(["bodies": [["physical": ["currentNewtKitStock": stock]]]]),
      location: .world, schema: CurrentNewtKitSave.version)
    try #require(fieldsValidated)
    switch form {
    case "unknown": stock["approved"] = true
    case "service-null": stock["serviceCapturedAt"] = NSNull()
    case "service-stowed": stock["serviceCapturedAt"] = 0
    case "service-actuating":
      stock = try stockObject(phase: "actuating")
      stock["serviceCapturedAt"] = 1
    case "service-before-unlock", "service-after-observation":
      stock = try stockObject(phase: "released")
      stock["serviceCapturedAt"] = form == "service-before-unlock" ? 1 : 3
    case "work-missing": stock.removeValue(forKey: "work")
    case "work-null": stock["work"] = NSNull()
    case "work-unknown", "work-invalid":
      var work = try #require(stock["work"] as? [String: Double])
      work[form == "work-unknown" ? "unissuedWork" : "loweredFraction"] = 2
      stock["work"] = work
    case "birth-load-missing":
      var issue = try #require(stock["issue"] as? [String: Any])
      issue.removeValue(forKey: "birthLoad")
      stock["issue"] = issue
    case "start-load-missing":
      stock = try stockObject(phase: "actuating")
      var start = try #require(stock["actuation"] as? [String: Any])
      start.removeValue(forKey: "load")
      stock["actuation"] = start
    case "observed-missing": stock.removeValue(forKey: "observedAt")
    case "observed-null": stock["observedAt"] = NSNull()
    case "observed-negative": stock["observedAt"] = -1
    case "released-observed":
      stock = try stockObject(phase: "released")
      stock["observedAt"] = 1
    case "charges-missing": stock.removeValue(forKey: "charges")
    case "charges-null": stock["charges"] = NSNull()
    case "charges-negative":
      var depleted = charges
      depleted["oxygenKilograms"] = -1
      stock["charges"] = depleted
    case "released-charge-increase":
      stock = try stockObject(phase: "released")
      var receipt = try receiptObject()
      var depleted = charges
      depleted["electricalJoules"] = 0
      receipt["remainingCharges"] = depleted
      stock["receipt"] = receipt
    case "null": stock["receipt"] = NSNull()
    case "missing": stock.removeValue(forKey: "issue")
    case "phase": stock["phase"] = "refilled"
    case "actuating", "released": stock["phase"] = form
    case "nested-unknown", "nested-null", "mass":
      var issue = try #require(stock["issue"] as? [String: Any])
      if form == "nested-unknown" {
        issue["approved"] = true
      } else if form == "nested-null" {
        issue["birthActor"] = NSNull()
      } else {
        var profile = try #require(issue["personProfile"] as? [String: Any])
        profile["massKilograms"] = 99
        issue["personProfile"] = profile
      }
      stock["issue"] = issue
    default: break
    }
    var leaf = String(decoding: try json(stock), as: UTF8.self)
    if form == "integer-token" {
      leaf = leaf.replacingOccurrences(of: "\"entity\":2", with: "\"entity\":2.0")
    }
    if form == "duplicate" || form == "escaped-duplicate" {
      leaf.removeLast()
      leaf += form == "duplicate" ? ",\"phase\":\"stowed\"}" : ",\"ph\\u0061se\":\"stowed\"}"
    }
    let bytes = Data("{\"bodies\":[{\"physical\":{\"currentNewtKitStock\":\(leaf)}}]}".utf8)
    // Every mutation is legal JSON. The expected refusal must come from the native boundary.
    _ = try JSONSerialization.jsonObject(with: bytes)
    #expect(throws: (any Error).self) {
      try CurrentNewtKitSave.validateFields(
        bytes, location: .world, schema: CurrentNewtKitSave.version)
    }
  }

  @Test func misplacedNullAndSelectionOnlyFieldsRefuseBeforeTypedDecode() throws {
    let stock = try stockObject(phase: "stowed")
    let misplaced: [[String: Any]] = [
      ["currentNewtKitStock": stock],
      ["savedEMPState": ["currentNewtKitStock": stock]],
      ["savedNPCPersistence": ["currentNewtKitStock": stock]],
      [
        "savedNativePeopleCustody": ["admissions": [["currentNewtKitReceipt": try receiptObject()]]]
      ],
      ["bodies": [["physical": ["currentNewtKitStock": NSNull()]]]],
      ["bodies": [["physical": ["currentNewtKitConfiguration": "synthetic"]]]],
      ["serviceCapturedAt": 2],
      ["savedEMPState": ["records": ["synthetic-key": ["serviceCapturedAt": 2]]]],
      ["bodies": [["physical": ["serviceCapturedAt": 2]]]],
    ]
    for object in misplaced {
      for location in [
        ScriptSaveJSONPreflight.InquiryArchiveLocation.commander, .world,
        .missions, .contracts, .pointer,
      ] {
        #expect(throws: (any Error).self) {
          try CurrentNewtKitSave.validateFields(
            json(object), location: location,
            schema: CurrentNewtKitSave.version)
        }
      }
    }
  }

  @Test func pendingBirthSelectorHasOneNativeCarrierAndGrantsNoStock() throws {
    func header(_ selector: Any) throws -> Data {
      try json([
        "encounterDirector": ["pendingRequests": [["currentNewtKitConfiguration": selector]]]
      ])
    }
    for schema in [CurrentNewtKitSave.version, CurrentNewtKitSave.alienVersion] {
      #expect(
        try CurrentNewtKitSave.validateFields(
          header("synthetic-selector-only"), location: .commander, schema: schema))
    }
    for schema in [Int?.none, .some(22), .some(144)] {
      #expect(throws: (any Error).self) {
        try CurrentNewtKitSave.validateFields(
          header("synthetic-selector-only"), location: .commander, schema: schema)
      }
    }
    let invalidSelectors: [Any] = [
      NSNull(), 1, [String: Any](), "", String(repeating: "x", count: 257),
    ]
    for selector in invalidSelectors {
      #expect(throws: (any Error).self) {
        try CurrentNewtKitSave.validateFields(
          header(selector), location: .commander, schema: CurrentNewtKitSave.version)
      }
    }
    let request = [
      "encounterDirector": [
        "pendingRequests": [
          [
            "currentNewtKitStock": try stockObject(phase: "stowed")
          ]
        ]
      ]
    ]
    #expect(throws: (any Error).self) {
      try CurrentNewtKitSave.validateFields(
        json(request), location: .commander,
        schema: CurrentNewtKitSave.version)
    }
  }

  @Test func absentClaimsKeepTheirExistingPublicationSelection() throws {
    let commander = Game(executive: false).commander
    #expect(!CurrentNewtKitSave.hasClaims(commander))
    for alien in [false, true] {
      #expect(
        ScriptSaveStore.publicationSchema(commander, alien: alien)
          == ScriptSaveStore.featurePublicationSchema(commander, alien: alien))
    }
    #expect(
      try !CurrentNewtKitSave.validateFields(
        Data("{}".utf8), location: .commander, schema: CurrentNewtKitSave.version))
  }

  private func stockObject(phase: String) throws -> [String: Any] {
    var stock: [String: Any] = [
      "issue": try issueObject(), "phase": phase, "charges": charges, "observedAt": 0,
      "work": [
        "loweredFraction": 0.0, "rodMetres": 0.0, "rodVelocity": 0.0,
        "guideWorkJoules": 0.0, "ejectionWorkJoules": 0.0,
      ],
    ]
    if phase != "stowed" {
      stock["actuation"] = try actuationObject()
      stock["observedAt"] = 1
    }
    if phase == "released" {
      stock["receipt"] = try receiptObject()
      stock["observedAt"] = 2
    }
    return stock
  }

  private func issueObject() throws -> [String: Any] {
    [
      "kitID": "00000000-0000-4000-8000-000000000001",
      "configuration": "synthetic-codec-only", "sourceSHA256": String(repeating: "1", count: 64),
      "birthSpawn": try encoded(
        SpawnIdentity(system: actor.system, visit: 1, sequence: 1, member: 0)),
      "birthActor": try encoded(actor), "person": ["source": try encoded(actor), "ordinal": 0],
      "personProfile": try personProfileObject(), "birthLoad": try loadObject(),
      "issuedAt": 0,
    ]
  }

  private func actuationObject() throws -> [String: Any] {
    [
      "source": try encoded(actor), "sequence": 1, "parent": try encoded(actor),
      "initialParent": try bodyObject(), "load": try loadObject(),
      "startedAt": 1, "unlockAt": 2, "completeAt": 3, "deadline": 10,
    ]
  }

  private func personProfileObject() throws -> [String: Any] {
    [
      "id": "synthetic-codec-only", "sourceSHA256": String(repeating: "2", count: 64),
      "massKilograms": 100, "dimensionsMetres": try encoded(Vector3(0.56, 0.38, 1.72)),
    ]
  }

  private func loadObject() throws -> [String: Any] {
    let r3 = try #require(OriginalFleetR3Data.contract(for: "SH029"))
    let performance = try #require(r3.performance)
    let resources = try #require(NPCResources.stock(performance))
    return [
      "catalogueShipID": "SH029", "r3SHA256": r3.sourceSHA256,
      "cargo": [Any](), "resources": try encoded(resources), "missiles": 0,
      "ecmEnabled": false, "hasFuelScoops": false,
      "people": [
        [
          "identity": ["source": try encoded(actor), "ordinal": 0],
          "profile": try personProfileObject(),
        ]
      ],
    ]
  }

  private func bodyObject() throws -> [String: Any] {
    [
      "pose": try encoded(ShipPose()), "velocity": try encoded(Vector3(0, 0, 0)),
      "angularVelocity": try encoded(Vector3(0, 0, 0)),
    ]
  }

  private func receiptObject() throws -> [String: Any] {
    let pod = ActorIdentity(system: actor.system, visit: 1, entity: 3)
    let mass: [String: Any] = [
      "massKilograms": 1, "centreOfMassMetres": try encoded(Vector3(0, 0, 0)),
      "inertiaKgM2": [1, 0, 0, 0, 1, 0, 0, 0, 1],
    ]
    return [
      "issue": try issueObject(), "actuation": try actuationObject(), "podActor": try encoded(pod),
      "podSpawn": try encoded(
        SpawnIdentity(system: actor.system, visit: 1, sequence: 1, member: 1, producer: .emp)),
      "releasedAt": 2, "loadAtRelease": try loadObject(),
      "parent": try bodyObject(), "pod": try bodyObject(),
      "parentMass": mass, "podMass": mass, "energyJoules": 1, "remainingCharges": charges,
    ]
  }

  private var charges: [String: Double] {
    [
      "guideMechanicalJoules": 1, "ejectionMechanicalJoules": 1, "electricalJoules": 1,
      "oxygenKilograms": 1, "sorbentCapacityKilogramsCO2": 1,
    ]
  }

  private func encoded(_ value: some Encodable) throws -> Any {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
  }

  private func json(_ value: Any) throws -> Data {
    try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
  }
}
