import Foundation

/// Exact actual readings, not a kilogram/placement policy. The physical source must
/// model each counted load and every born crew member before this can qualify a kit.
public struct CurrentNewtKitLoad: Equatable, Codable, Sendable {
  public struct Person: Equatable, Codable, Sendable {
    let identity: EMPCrewIdentity
    let profile: CurrentNewtKitIssue.PersonProfile
  }

  let catalogueShipID: String
  let r3SHA256: String
  let cargo: [CommodityAmount]
  let cargoProvenance: NPCFactProvenance?
  let resources: NPCResources
  let missiles: Int
  let ecmEnabled: Bool
  let hasFuelScoops: Bool?
  let people: [Person]

  var structurallyValid: Bool {
    !catalogueShipID.isEmpty && r3SHA256.utf8.count == 64 && resources.valid
      && missiles >= 0 && cargo.allSatisfy(\.valid)
      && Set(cargo.map(\.commodity)).count == cargo.count
      && people.count <= EMPState.maximumPeople && Set(people.map(\.identity)).count == people.count
      && people.allSatisfy { person in
        person.identity.ordinal >= 0 && person.profile.massKilograms.isFinite
          && person.profile.massKilograms > 0 && person.profile.dimensionsMetres.finite
          && person.profile.dimensionsMetres.x > 0 && person.profile.dimensionsMetres.y > 0
          && person.profile.dimensionsMetres.z > 0
      }
  }
}

/// Original hardware and a born person are separate identities. These saved facts
/// require the current source and live birth/custody joins; decoding grants neither.
public struct CurrentNewtKitIssue: Equatable, Codable, Sendable {
  public struct PersonProfile: Equatable, Codable, Sendable {
    let id: String
    let sourceSHA256: String
    let massKilograms: Double
    let dimensionsMetres: Vector3
  }

  let kitID: UUID
  let configuration: String
  let sourceSHA256: String
  let birthSpawn: SpawnIdentity
  let birthActor: ActorIdentity
  let person: EMPCrewIdentity
  let personProfile: PersonProfile
  let issuedAt: Double
  let birthLoad: CurrentNewtKitLoad

  fileprivate init(kitID: UUID, configuration: String, sourceSHA256: String,
    birthSpawn: SpawnIdentity, birthActor: ActorIdentity, person: EMPCrewIdentity,
    personProfile: PersonProfile, issuedAt: Double, birthLoad: CurrentNewtKitLoad)
  {
    self.kitID = kitID
    self.configuration = configuration
    self.sourceSHA256 = sourceSHA256
    self.birthSpawn = birthSpawn
    self.birthActor = birthActor
    self.person = person
    self.personProfile = personProfile
    self.issuedAt = issuedAt
    self.birthLoad = birthLoad
  }

  var structurallyValid: Bool {
    !configuration.isEmpty && Self.validHash(sourceSHA256)
      && !personProfile.id.isEmpty && Self.validHash(personProfile.sourceSHA256)
      && personProfile.massKilograms == 100
      && personProfile.dimensionsMetres == .init(0.56, 0.38, 1.72)
      && birthSpawn.producer == .ambient && birthSpawn.member == 0
      && birthSpawn.system == birthActor.system && birthSpawn.visit == birthActor.visit
      && birthActor.entity > 1 && birthActor.entity < UInt64.max && birthActor.visit > 0
      && (0..<8).contains(birthActor.system.galaxy)
      && (0...256).contains(birthActor.system.system)
      && person.source == birthActor && person.ordinal == 0
      && issuedAt.isFinite && issuedAt >= 0 && birthLoad.structurallyValid
      && birthLoad.people.contains { $0.identity == person && $0.profile == personProfile }
  }

  fileprivate static func validHash(_ value: String) -> Bool {
    value.utf8.count == 64 && value.utf8.allSatisfy {
      (48...57).contains($0) || (97...102).contains($0)
    }
  }
}

public struct CurrentNewtKitStock: Equatable, Codable, Sendable {
  public enum Phase: String, Codable, Sendable { case stowed, actuating, released }

  public struct Actuation: Equatable, Codable, Sendable {
    let source: ActorIdentity
    let sequence: UInt64
    let parent: ActorIdentity
    let initialParent: CurrentNewtKitReceipt.BodyState
    let load: CurrentNewtKitLoad
    let startedAt: Double
    let unlockAt: Double
    let completeAt: Double
    let deadline: Double
  }

  public struct Charges: Equatable, Codable, Sendable {
    let guideMechanicalJoules: Double
    let ejectionMechanicalJoules: Double
    let electricalJoules: Double
    let oxygenKilograms: Double
    let sorbentCapacityKilogramsCO2: Double

    var structurallyValid: Bool {
      [guideMechanicalJoules, ejectionMechanicalJoules, electricalJoules,
        oxygenKilograms, sorbentCapacityKilogramsCO2].allSatisfy { $0.isFinite && $0 >= 0 }
    }

    func doesNotExceed(_ before: Self) -> Bool {
      structurallyValid && before.structurallyValid
        && guideMechanicalJoules <= before.guideMechanicalJoules
        && ejectionMechanicalJoules <= before.ejectionMechanicalJoules
        && electricalJoules <= before.electricalJoules
        && oxygenKilograms <= before.oxygenKilograms
        && sorbentCapacityKilogramsCO2 <= before.sorbentCapacityKilogramsCO2
    }
  }

  public struct WorkState: Equatable, Codable, Sendable {
    let loweredFraction: Double
    let rodMetres: Double
    let rodVelocity: Double
    let guideWorkJoules: Double
    let ejectionWorkJoules: Double

    var structurallyValid: Bool {
      [loweredFraction, rodMetres, rodVelocity, guideWorkJoules, ejectionWorkJoules]
        .allSatisfy(\.isFinite) && loweredFraction >= 0 && loweredFraction <= 1
        && rodMetres >= 0 && guideWorkJoules >= 0 && ejectionWorkJoules >= 0
    }
  }

  let issue: CurrentNewtKitIssue
  private(set) var work: WorkState
  private(set) var charges: Charges
  private(set) var observedAt: Double
  private(set) var interruptedAt: Double?
  private(set) var serviceCapturedAt: Double?
  private(set) var phase: Phase
  private(set) var actuation: Actuation?
  private(set) var receipt: CurrentNewtKitReceipt?

  fileprivate init(issue: CurrentNewtKitIssue, charges: Charges) {
    self.issue = issue
    self.charges = charges
    work = .init(loweredFraction: 0, rodMetres: 0, rodVelocity: 0,
      guideWorkJoules: 0, ejectionWorkJoules: 0)
    observedAt = issue.issuedAt
    interruptedAt = nil
    serviceCapturedAt = nil
    phase = .stowed
    actuation = nil
    receipt = nil
  }

  var remaining: Int { phase == .released ? 0 : 1 }

  var structurallyValid: Bool {
    guard issue.structurallyValid, charges.structurallyValid, work.structurallyValid,
      observedAt.isFinite, observedAt >= issue.issuedAt else { return false }
    switch phase {
    case .stowed:
      return actuation == nil && receipt == nil && interruptedAt == nil && serviceCapturedAt == nil
        && work.loweredFraction == 0 && work.rodMetres == 0 && work.rodVelocity == 0
        && work.guideWorkJoules == 0 && work.ejectionWorkJoules == 0
    case .actuating, .released:
      guard let actuation, actuation.source == issue.person.source,
        actuation.sequence > 0, actuation.parent.system == actuation.source.system,
        actuation.parent.entity > 1, actuation.parent.visit >= actuation.source.visit,
        actuation.initialParent.structurallyValid, actuation.load.structurallyValid,
        actuation.startedAt.isFinite, actuation.startedAt >= issue.issuedAt,
        actuation.unlockAt.isFinite, actuation.unlockAt > actuation.startedAt,
        actuation.completeAt.isFinite, actuation.completeAt > actuation.unlockAt,
        actuation.deadline.isFinite, actuation.unlockAt < actuation.deadline
      else { return false }
      if let interruptedAt {
        guard interruptedAt.isFinite, interruptedAt >= actuation.startedAt,
          interruptedAt <= observedAt else { return false }
      }
      if phase == .actuating { return receipt == nil && serviceCapturedAt == nil }
      if let serviceCapturedAt {
        guard serviceCapturedAt.isFinite, serviceCapturedAt >= actuation.unlockAt,
          serviceCapturedAt <= observedAt else { return false }
      }
      if let interruptedAt, let receipt, interruptedAt < receipt.releasedAt { return false }
      guard let receipt else { return false }
      return receipt.issue == issue && receipt.actuation == actuation
        && charges.doesNotExceed(receipt.remainingCharges)
        && receipt.structurallyValid && observedAt >= receipt.releasedAt
    }
  }
}

/// A proposal for one same-turn native admission. It is deliberately not Codable.
/// G3 rejoins the live parent's stock, physical time and custody before allocation.
struct CurrentNewtPodReleaseRequest: Sendable {
  let issue: CurrentNewtKitIssue
  let actuation: CurrentNewtKitStock.Actuation
  let system: SystemIdentity
  let visit: UInt64
  let revision: UInt64
  let physicalTime: Double
  let loadAtRelease: CurrentNewtKitLoad
  let parent: CurrentNewtKitReceipt.BodyState
  let pod: CurrentNewtKitReceipt.BodyState
  let parentMass: CurrentNewtKitReceipt.MassProperties
  let podMass: CurrentNewtKitReceipt.MassProperties
  let energyJoules: Double
  let remainingCharges: CurrentNewtKitStock.Charges
}

public struct CurrentNewtKitReceipt: Equatable, Codable, Sendable {
  public struct MassProperties: Equatable, Codable, Sendable {
    let massKilograms: Double
    let centreOfMassMetres: Vector3
    /// Full row-major tensor about this centre in the source body frame.
    let inertiaKgM2: [Double]

    var structurallyValid: Bool {
      guard massKilograms.isFinite, massKilograms > 0, centreOfMassMetres.finite,
        inertiaKgM2.count == 9, inertiaKgM2.allSatisfy(\.isFinite)
      else { return false }
      for row in 0..<3 {
        for column in 0..<3 {
          let a = inertiaKgM2[3 * row + column]
          let b = inertiaKgM2[3 * column + row]
          if abs(a - b) > max(1, max(abs(a), abs(b))) * 1e-10 { return false }
        }
      }
      let a = inertiaKgM2
      let minor = a[0] * a[4] - a[1] * a[3]
      let determinant = a[0] * (a[4] * a[8] - a[5] * a[7])
        - a[1] * (a[3] * a[8] - a[5] * a[6])
        + a[2] * (a[3] * a[7] - a[4] * a[6])
      return a[0] > 0 && minor.isFinite && minor > 0
        && determinant.isFinite && determinant > 0
    }
  }

  public struct BodyState: Equatable, Codable, Sendable {
    let pose: ShipPose
    let velocity: Vector3
    let angularVelocity: Vector3

    var structurallyValid: Bool {
      pose.position.finite && pose.orientation.validRotation
        && velocity.finite && angularVelocity.finite
    }
  }

  let issue: CurrentNewtKitIssue
  let actuation: CurrentNewtKitStock.Actuation
  let podActor: ActorIdentity
  let podSpawn: SpawnIdentity
  let releasedAt: Double
  let loadAtRelease: CurrentNewtKitLoad
  let parent: BodyState
  let pod: BodyState
  let parentMass: MassProperties
  let podMass: MassProperties
  let energyJoules: Double
  let remainingCharges: CurrentNewtKitStock.Charges

  var structurallyValid: Bool {
    issue.structurallyValid && actuation.source == issue.person.source
      && actuation.sequence > 0 && podActor.system == actuation.source.system
      && podActor.visit >= actuation.source.visit && podActor.entity > 1
      && podActor.entity < UInt64.max && podActor != actuation.parent
      && podSpawn.system == podActor.system && podSpawn.visit == podActor.visit
      && podSpawn.producer == .emp && podSpawn.sequence == actuation.sequence
      && podSpawn.member == UInt16(issue.person.ordinal + 1)
      && loadAtRelease.structurallyValid
      && releasedAt.isFinite && releasedAt >= actuation.unlockAt
      && releasedAt < actuation.deadline
      && parent.structurallyValid && pod.structurallyValid
      && parentMass.structurallyValid && podMass.structurallyValid
      && energyJoules.isFinite && energyJoules > 0 && remainingCharges.structurallyValid
  }
}

extension CurrentNewtKitStock {
  func validForNPC(catalogueShipID: String?, actor: ActorIdentity, physicalTime: Double) -> Bool {
    guard structurallyValid, catalogueShipID == "SH029", phase != .released,
      actor.system == issue.birthActor.system, actor.visit >= issue.birthActor.visit,
      actor.entity > 1, physicalTime.isFinite, physicalTime >= issue.issuedAt,
      let source = CurrentNewtKitSource.current, source.matches(self, at: physicalTime)
    else { return false }
    return actuation.map { $0.startedAt <= physicalTime } ?? true
  }

  /// Snapshot updates can retain or spend original hardware, never install or replace it.
  static func permitsTransition(from old: Self?, to new: Self?) -> Bool {
    switch (old, new) {
    case (nil, nil): return true
    case (.some(let old), .some(let new)):
      guard old.structurallyValid, new.structurallyValid, old.issue == new.issue,
        new.charges.doesNotExceed(old.charges), new.observedAt >= old.observedAt,
        new.work.loweredFraction >= old.work.loweredFraction,
        new.work.rodMetres >= old.work.rodMetres,
        new.work.guideWorkJoules >= old.work.guideWorkJoules,
        new.work.ejectionWorkJoules >= old.work.ejectionWorkJoules,
        old.interruptedAt == nil || old.interruptedAt == new.interruptedAt,
        old.serviceCapturedAt == nil || old.serviceCapturedAt == new.serviceCapturedAt
      else { return false }
      switch old.phase {
      case .stowed:
        return new.phase == .stowed || new.phase == .actuating || new.phase == .released
      case .actuating:
        return new.actuation == old.actuation && new.phase != .stowed
      case .released:
        return new.phase == .released && new.actuation == old.actuation && new.receipt == old.receipt
      }
    default: return false
    }
  }

  mutating func beginActuation(_ start: Actuation, charges next: Charges) -> Bool {
    guard phase == .stowed, actuation == nil, receipt == nil else { return false }
    var candidate = self
    candidate.phase = .actuating
    candidate.actuation = start
    candidate.observedAt = start.startedAt
    guard next.doesNotExceed(charges) else { return false }
    candidate.charges = next
    guard candidate.structurallyValid else { return false }
    self = candidate
    return true
  }

  mutating func observe(at time: Double, work nextWork: WorkState, charges next: Charges) -> Bool {
    guard time.isFinite, time >= observedAt, next.doesNotExceed(charges),
      nextWork.structurallyValid, nextWork.loweredFraction >= work.loweredFraction,
      nextWork.rodMetres >= work.rodMetres,
      nextWork.guideWorkJoules >= work.guideWorkJoules,
      nextWork.ejectionWorkJoules >= work.ejectionWorkJoules else {
      return false
    }
    observedAt = time
    work = nextWork
    charges = next
    return true
  }

  mutating func interrupt(at time: Double, stoppedAt: Double,
    work nextWork: WorkState, charges next: Charges) -> Bool {
    guard phase != .stowed, interruptedAt == nil, stoppedAt.isFinite,
      stoppedAt <= time, observe(at: time, work: nextWork, charges: next) else { return false }
    interruptedAt = stoppedAt
    return true
  }

  /// Only the completed actual custody candidate seals this once-only frontier.
  mutating func captureService(at time: Double) -> Bool {
    guard phase == .released, serviceCapturedAt == nil, let receipt,
      time.isFinite, time == observedAt, time >= receipt.releasedAt else { return false }
    serviceCapturedAt = time
    return true
  }

  mutating func release(_ delivery: CurrentNewtKitReceipt) -> Bool {
    guard phase == .actuating, interruptedAt == nil, delivery.issue == issue,
      delivery.actuation == actuation, delivery.structurallyValid, receipt == nil,
      delivery.releasedAt == observedAt, delivery.remainingCharges == charges,
      let source = CurrentNewtKitSource.current, source.matches(delivery),
      work == source.work(at: delivery.releasedAt, actuation: delivery.actuation)
    else { return false }
    var candidate = self
    candidate.phase = .released
    candidate.receipt = delivery
    candidate.charges = delivery.remainingCharges
    candidate.observedAt = delivery.releasedAt
    guard candidate.structurallyValid else { return false }
    self = candidate
    return true
  }
}

extension Game {
  /// This is called only by the ordinary body constructor after its real actor allocation.
  /// A request selector and a decoded issue cannot install hardware on an existing body.
  func issueCurrentNewtKit(request: SpawnRequest, body: SpaceBody, actor: ActorIdentity,
    context: EncounterContext) -> CurrentNewtKitStock?
  {
    guard let source = CurrentNewtKitSource.current,
      source.permitsBirth(request, context: context),
      actor.system == context.system, actor.visit == context.visit,
      actor.entity > 1, actor.entity < commander.flightSimulation.nextActor,
      !bodies.contains(where: { $0.physical?.identity == actor || $0.physical?.spawnIdentity == request.identity })
    else { return nil }
    guard let npc = body.physical?.npc, let resources = npc.resources,
      let catalogue = body.physical?.catalogueShipID,
      let r3 = OriginalFleetR3Data.contract(for: catalogue)
    else { return nil }
    let person = EMPCrewIdentity(source: actor, ordinal: 0)
    let load = CurrentNewtKitLoad(catalogueShipID: catalogue, r3SHA256: r3.sourceSHA256,
      cargo: npc.ordinaryCargo, cargoProvenance: npc.cargoProvenance, resources: resources,
      missiles: body.missiles, ecmEnabled: body.ecmEnabled, hasFuelScoops: npc.hasFuelScoops,
      people: [.init(identity: person, profile: source.personProfile)])
    let issue = CurrentNewtKitIssue(kitID: UUID(), configuration: source.configuration,
      sourceSHA256: source.sourceSHA256, birthSpawn: request.identity, birthActor: actor,
      person: person, personProfile: source.personProfile,
      issuedAt: context.physicalTime, birthLoad: load)
    guard issue.structurallyValid, source.matches(issue) else { return nil }
    return .init(issue: issue, charges: source.initialCharges)
  }
}

extension Game {
  /// A retained request address is selection only; the actual owner record supplies stock.
  func retainedCurrentNewtKitStock(for request: SpawnRequest) -> CurrentNewtKitStock? {
    if request.identity.producer == .persistence {
      return commander.npcPersistence.currentNewtKitStock(forOffer: request.identity)
    }
    guard request.identity.producer == .emp, request.identity.member == 0,
      let record = commander.savedEMPState?.records.values.first(where: {
        $0.source.system == request.identity.system && $0.sequence == request.identity.sequence
          && $0.hull.binding == nil && !$0.terminal && !$0.isRecovered
          && $0.hull.body.physical?.catalogueShipID == request.catalogueShipID
      })
    else { return nil }
    return record.hull.body.physical?.currentNewtKitStock
  }
}
