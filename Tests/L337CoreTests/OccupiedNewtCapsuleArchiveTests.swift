import Foundation
import Testing

@testable import L337Core

struct OccupiedNewtCapsuleArchiveTests {
  @Test
  func originalOccupiedKitPersonAndReceiptSurviveCurrentArchiveEncoding() throws {
    let (game, source) = try NativePagedSalvageFixture.empGame()
    try verifyOriginalOccupiedArchiveEncoding(game, source: source)
  }

  @inline(never)
  private func verifyOriginalOccupiedArchiveEncoding(_ game: Game, source: NativePagedSalvageFixture.EMPWorkSource) throws {
    let capturedOwnerCheck1 = game.commander.savedEMPState
    let state = try #require(capturedOwnerCheck1)
    let record = try #require(state.records[source.actor])
    let pod = try #require(record.pods.first)
    let stock = try #require(record.hull.body.physical?.currentNewtKitStock)
    let receipt = try #require(pod.body.physical?.currentNewtKitReceipt)
    try #require(state.valid && record.valid && record.pods.count == 1)
    #expect(stock.phase == .released && stock.remaining == 0)
    #expect(stock.receipt == receipt && receipt.issue == stock.issue)
    let physical = try #require(CurrentNewtKitSource.current)
    #expect(receipt.releasedAt == receipt.actuation.unlockAt)
    #expect(receipt.actuation.completeAt > receipt.releasedAt)
    #expect(physical.matchesCharges(receipt.remainingCharges,
      physical.charges(at: receipt.releasedAt, actuation: receipt.actuation)))
    #expect(physical.matchesCharges(stock.charges,
      physical.charges(at: stock.observedAt, actuation: receipt.actuation, work: stock.work,
        serviceCapturedAt: stock.serviceCapturedAt)))
    #expect(stock.observedAt >= receipt.releasedAt)
    #expect(receipt.issue.person == pod.body.physical?.empCrewPod)
    #expect(!pod.valid && pod.validCurrentOccupiedNewt(in: record))
    let restored = try JSONDecoder().decode(EMPState.self, from: JSONEncoder().encode(state))
    #expect(restored == state && restored.valid)
    #expect(restored.records[source.actor]?.pods.first == pod)
    #expect(ShipCatalogue.rawMesh("SH040") == nil)
  }

  @Test
  func aConsumedOriginalKitCannotAllocateAnotherPodOrPerson() throws {
    var (game, source) = try NativePagedSalvageFixture.empGame()
    try verifyConsumedKitCannotAllocateAgain(&game, source: source)
  }

  @inline(never)
  private func verifyConsumedKitCannotAllocateAgain(_ game: inout Game, source: NativePagedSalvageFixture.EMPWorkSource) throws {
    let capturedOwnerCheck2 = game.commander.savedEMPState?.records[source.actor]
    let record = try #require(capturedOwnerCheck2)
    let receipt = try #require(record.pods.first?.body.physical?.currentNewtKitReceipt)
    let ownedPreparationRequired1 = game.gameplayContext()
    let context = try #require(ownedPreparationRequired1)
    let replay = CurrentNewtPodReleaseRequest(
      issue: receipt.issue, actuation: receipt.actuation,
      system: context.system, visit: context.visit, revision: context.revision,
      physicalTime: context.physicalTime, loadAtRelease: receipt.loadAtRelease,
      parent: receipt.parent, pod: receipt.pod,
      parentMass: receipt.parentMass, podMass: receipt.podMass,
      energyJoules: receipt.energyJoules, remainingCharges: receipt.remainingCharges)
    let before = game
    let result = game.admitCurrentOccupiedNewtPod(replay)
    #expect(result.actor == nil && result.refusal != nil)
    let capturedOwnerCheck3 = game.commander == before.commander && game.bodies == before.bodies
    #expect(capturedOwnerCheck3)
    let capturedOwnerCheck4 = game.nextBodyID == before.nextBodyID && game.gameplayRevision == before.gameplayRevision
    #expect(capturedOwnerCheck4)
    let capturedOwnerCheck5 = game.time == before.time
    #expect(capturedOwnerCheck5)
  }

  @Test(arguments: [
    "parent-mass", "pod-mass", "parent-tensor", "pod-tensor", "energy", "release-time",
    "parent-position", "pod-position", "parent-velocity", "pod-velocity",
    "guide-charge", "ejection-charge", "electrical-charge", "oxygen-charge", "sorbent-charge",
  ])
  func agreeingReceiptCopiesCannotForgePhysicalRelease(condition: String) throws {
    let (game, source) = try NativePagedSalvageFixture.empGame()
    try requireCapturedServicePredicateParity(game)
    try verifyAgreeingReceiptCopies(game, source: source, condition: condition)
  }

  @inline(never)
  private func verifyAgreeingReceiptCopies(_ game: Game, source: NativePagedSalvageFixture.EMPWorkSource, condition: String) throws {
    let capturedOwnerCheck6 = game.commander.savedEMPState?.records[source.actor]
    let original = try #require(capturedOwnerCheck6)
    try #require(original.valid && original.pods.count == 1)
    let receipt = try #require(original.pods[0].body.physical?.currentNewtKitReceipt)
    let changed: CurrentNewtKitReceipt = try altered(receipt) { object in
      switch condition {
      case "parent-mass", "pod-mass":
        let key = condition == "parent-mass" ? "parentMass" : "podMass"
        var mass = try #require(object[key] as? [String: Any])
        mass["massKilograms"] = try #require(mass["massKilograms"] as? Double) + 1
        object[key] = mass
      case "parent-tensor", "pod-tensor":
        let key = condition == "parent-tensor" ? "parentMass" : "podMass"
        var mass = try #require(object[key] as? [String: Any])
        var tensor = try #require(mass["inertiaKgM2"] as? [Double])
        tensor[0] += 1
        mass["inertiaKgM2"] = tensor
        object[key] = mass
      case "guide-charge", "ejection-charge", "electrical-charge", "oxygen-charge", "sorbent-charge":
        let keys = ["guide-charge": "guideMechanicalJoules", "ejection-charge": "ejectionMechanicalJoules",
                    "electrical-charge": "electricalJoules", "oxygen-charge": "oxygenKilograms",
                    "sorbent-charge": "sorbentCapacityKilogramsCO2"]
        let key = try #require(keys[condition])
        var charges = try #require(object["remainingCharges"] as? [String: Any])
        charges[key] = try #require(charges[key] as? Double) + 1
        object["remainingCharges"] = charges
      case "energy": object["energyJoules"] = try #require(object["energyJoules"] as? Double) + 1
      case "release-time": object["releasedAt"] = try #require(object["releasedAt"] as? Double) + 0.001
      case "parent-position", "pod-position", "parent-velocity", "pod-velocity":
        let key = condition.hasPrefix("parent-") ? "parent" : "pod"
        var body = try #require(object[key] as? [String: Any])
        if condition.hasSuffix("position") {
          var pose = try #require(body["pose"] as? [String: Any])
          var vector = try #require(pose["position"] as? [String: Any])
          vector["x"] = try #require(vector["x"] as? Double) + 1
          pose["position"] = vector
          body["pose"] = pose
        } else {
          var vector = try #require(body["velocity"] as? [String: Any])
          vector["x"] = try #require(vector["x"] as? Double) + 1
          body["velocity"] = vector
        }
        object[key] = body
      default: throw SaveError.invalidCommander
      }
    }
    var forged = original
    let stock = try #require(forged.hull.body.physical?.currentNewtKitStock)
    forged.hull.body.physical?.currentNewtKitStock = try altered(stock) { object in
      object["receipt"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(changed))
      object["charges"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(changed.remainingCharges))
    }
    forged.pods[0].body.physical?.currentNewtKitReceipt = changed
    #expect(!forged.valid)
    #expect(!forged.pods[0].validCurrentOccupiedNewt(in: forged))
    #expect(original.valid && original.pods[0].body.physical?.currentNewtKitReceipt == receipt)
  }

  @Test(arguments: ["missing", "kit", "person", "configuration", "birth", "source"])
  func missingOrForeignOriginalIssueCannotBecomeCurrentCustody(condition: String) throws {
    let (game, source) = try NativePagedSalvageFixture.empGame()
    try verifyForeignOriginalIssue(game, source: source, condition: condition)
  }

  @inline(never)
  private func verifyForeignOriginalIssue(_ game: Game, source: NativePagedSalvageFixture.EMPWorkSource, condition: String) throws {
    let capturedOwnerCheck7 = game.commander.savedEMPState?.records[source.actor]
    let original = try #require(capturedOwnerCheck7)
    try #require(original.valid && original.pods.count == 1)
    var forged = original
    if condition == "missing" {
      forged.pods[0].body.physical?.currentNewtKitReceipt = nil
    } else {
      let receipt = try #require(forged.pods[0].body.physical?.currentNewtKitReceipt)
      forged.pods[0].body.physical?.currentNewtKitReceipt = try altered(receipt) { object in
        var issue = try #require(object["issue"] as? [String: Any])
        switch condition {
        case "kit": issue["kitID"] = UUID().uuidString
        case "configuration": issue["configuration"] = "foreign-current-kit"
        case "source": issue["sourceSHA256"] = String(repeating: "0", count: 64)
        case "person":
          var person = try #require(issue["person"] as? [String: Any])
          person["ordinal"] = 1
          issue["person"] = person
        case "birth":
          var actor = try #require(issue["birthActor"] as? [String: Any])
          actor["entity"] = 1
          issue["birthActor"] = actor
        default: throw SaveError.invalidCommander
        }
        object["issue"] = issue
      }
    }
    #expect(!forged.valid && !forged.pods[0].validCurrentOccupiedNewt(in: forged))
    #expect(original.valid)
  }

  @Test
  func retainedHardwareAndPersonCannotBeCountedTwiceAcrossArchives() throws {
    let (game, source) = try NativePagedSalvageFixture.empGame()
    try verifyUniqueRetainedHardware(game, source: source)
  }

  @inline(never)
  private func verifyUniqueRetainedHardware(_ game: Game, source: NativePagedSalvageFixture.EMPWorkSource) throws {
    let capturedOwnerCheck8 = game.commander.savedEMPState?.records[source.actor]
    let record = try #require(capturedOwnerCheck8)
    let issue = try #require(record.custody.original.body.physical?.currentNewtKitStock?.issue)
    #expect(CurrentOccupiedNewtValidation.issuesAreUnique([issue]))
    #expect(!CurrentOccupiedNewtValidation.issuesAreUnique([issue, issue]))
  }

  @Test
  func aMatchingServiceTimestampAndChargeCannotInventCapturedCustody() throws {
    let (game, source) = try NativePagedSalvageFixture.empGame()
    try expectMatchingServiceCannotInventCustody(game, source: source)
  }

  @inline(never)
  private func expectMatchingServiceCannotInventCustody(
    _ game: Game, source: NativePagedSalvageFixture.EMPWorkSource
  ) throws {
    let original = try #require(game.commander.savedEMPState?.records[source.actor])
    let stock = try #require(original.hull.body.physical?.currentNewtKitStock)
    let receipt = try #require(stock.receipt)
    let physical = try #require(CurrentNewtKitSource.current)
    try #require(stock.serviceCapturedAt == nil && original.pods.count == 1)
    let time = original.pods[0].physicalTime
    let charges = physical.charges(at: stock.observedAt, actuation: receipt.actuation,
      work: stock.work, serviceCapturedAt: time)
    var record = original
    record.hull.body.physical?.currentNewtKitStock = try altered(stock) { fields in
      fields["serviceCapturedAt"] = time
      fields["charges"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(charges))
    }
    record.pods[0].binding = nil
    var forged = game.commander
    forged.savedEMPState?.records[source.actor] = record
    #expect(!forged.currentNewtCapturedServiceCustodyValid)
    #expect(!forged.nativePeopleStateValid && !forged.valid)
    #expect(game.commander.currentNewtCapturedServiceCustodyValid && original.valid)
  }

  @inline(never)
  private func requireCapturedServicePredicateParity(_ game: Game) throws {
    let opening = game
    let original = originalCapturedServicePredicate(game.commander)
    let actual = game.commander.currentNewtCapturedServiceCustodyValid
    try #require(actual)
    #expect(actual == original)
    let capturedOwnerCheck9 = game.currentNewtNativeCommanderMatches(opening) && game.bodies == opening.bodies
    #expect(capturedOwnerCheck9)
    let capturedOwnerCheck10 = game.scriptWorldSave == opening.scriptWorldSave
    #expect(capturedOwnerCheck10)
  }

  @inline(never)
  private func originalCapturedServicePredicate(_ commander: Commander) -> Bool {
    guard let emp = commander.savedEMPState else { return true }
    for record in emp.records.values {
      guard let stock = record.hull.body.physical?.currentNewtKitStock else { continue }
      guard let receipt = stock.receipt else {
        if stock.serviceCapturedAt != nil { return false }
        continue
      }
      let person = receipt.issue.person
      let admissions = commander.nativePeople?.admissions.filter { $0.person == .emp(person) } ?? []
      guard let index = record.podIndex(for: person.ordinal),
        record.source == person.source, stock.issue == receipt.issue,
        let podActor = record.pods[index].body.physical?.identity,
        record.pods[index].body.physical?.empCrewPod == person,
        record.pods[index].body.physical?.currentNewtKitReceipt == receipt
      else { return false }
      if let capturedAt = stock.serviceCapturedAt {
        guard capturedAt.isFinite, capturedAt >= receipt.releasedAt,
          capturedAt <= stock.observedAt, stock.observedAt <= commander.flightSimulation.physicalTime,
          record.pods[index].physicalTime == capturedAt, record.pods[index].binding == nil,
          admissions.count == 1, let admission = admissions.first,
          admission.origin == .rescuedPod, admission.actor == podActor,
          admission.physicalTime == capturedAt, !commander.worldOwnedPod(person),
          let source = CurrentNewtKitSource.current,
          let service = source.service(receipt, observedAt: capturedAt),
          service.kitID == stock.issue.kitID
        else { return false }
      } else if !admissions.isEmpty { return false }
    }
    return true
    }

  private func altered<Value: Codable>(
    _ value: Value, change: (inout [String: Any]) throws -> Void
  ) throws -> Value {
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    try change(&object)
    return try JSONDecoder().decode(Value.self, from: JSONSerialization.data(withJSONObject: object))
  }
}
