import Foundation

enum NativeUtilityEngineerSave {
  static func decodeClosed(_ bytes: Data) throws -> NativeUtilityEngineerState {
    guard bytes.count <= NativeUtilityEngineer.maximumSourceBytes,
      let raw = try JSONSerialization.jsonObject(with: bytes) as? [String: Any]
    else { throw SaveError.invalidCommander }
    let state = try JSONDecoder().decode(NativeUtilityEngineerState.self, from: bytes)
    let canonical = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    guard (raw as NSDictionary).isEqual(canonical) else { throw SaveError.invalidCommander }
    return state
  }

  static func shapeValid(_ state: borrowing NativeUtilityEngineerState) -> Bool {
    let birth = state.registration
    let identity = birth.identity
    guard identity.id != identity.owner,
      birth.operation == NativeUtilityEngineer.birthOperation(owner: identity.owner),
      birth.station == identity.station, birth.sourceVersion == OriginalStationSite.sourceVersion,
      birth.binding.valid(for: birth.station), birth.spawn.system == birth.station.system,
      birth.spawn.visit == birth.binding.actor.visit,
      birth.spawn.sequence > 0, birth.spawn.sequence < UInt64.max,
      validTime(birth.physicalTime), state.inspections.count <= 2
    else { return false }
    let utility = NativeUtilityState(owner: identity.owner)
    var operations: Set<UUID> = [birth.operation]
    var jobs: Set<UUID> = []
    var sockets: Set<Int> = []
    var time = birth.physicalTime
    var revision: UInt64 = 0
    for inspection in state.inspections {
      let installed = inspection.installation
      let dock = inspection.dock
      guard (0..<2).contains(installed.socket),
        (0..<2).contains(where: { utility.consignmentID($0) == inspection.consignment }),
        jobs.insert(inspection.consignment).inserted, sockets.insert(installed.socket).inserted,
        operations.insert(inspection.operation).inserted,
        installed.engineer == identity.id,
        installed.component == utility.component(installed.socket),
        installed.revision > 0, installed.revision < UInt64(Int64.max) - 1,
        inspection.utilityRevision == installed.revision + 1,
        inspection.utilityRevision > revision,
        installed.operation == utility.operation(
          inspection.consignment, stage: "install", revision: installed.revision),
        inspection.operation == utility.operation(
          inspection.consignment, stage: "receive", revision: inspection.utilityRevision),
        dock.station == birth.station, dock.commanderOwner == identity.owner,
        dock.dockingBinding.valid(for: birth.station),
        dock.dockingBinding.actor.visit >= birth.binding.actor.visit,
        dock.sequence > 0, dock.sequence < UInt64(Int64.max),
        dock.lifecycleRevision > 0, dock.lifecycleRevision < UInt64(Int64.max),
        installed.contact.valid, installed.contact.lifecycle == dock.lifecycleRevision,
        installed.contact.sequence <= dock.sequence,
        installed.contact.visit <= dock.dockingBinding.actor.visit,
        validTime(inspection.physicalTime), inspection.physicalTime >= time
      else { return false }
      revision = inspection.utilityRevision
      time = inspection.physicalTime
    }
    guard let casualty = state.casualty else { return true }
    guard casualty.operation == NativeUtilityEngineer.casualtyOperation(
      owner: identity.owner, binding: casualty.binding, incident: casualty.incident),
      operations.insert(casualty.operation).inserted,
      casualty.binding.valid(for: birth.station),
      casualty.binding.actor.visit >= birth.binding.actor.visit,
      casualty.priorLifecycleRevision > 0,
      casualty.priorLifecycleRevision < UInt64(Int64.max) - 1,
      casualty.tombstone.revision == casualty.priorLifecycleRevision + 1,
      casualty.tombstone.destroyedBinding == casualty.binding,
      validTime(casualty.startTime), validTime(casualty.physicalTime), casualty.startTime >= time,
      casualty.usedDuration.isFinite, casualty.usedDuration > 0, casualty.usedDuration <= 0.1,
      casualty.physicalTime == casualty.startTime + casualty.usedDuration,
      casualty.physicalTime > casualty.startTime,
      casualty.preNextIncident > 0, casualty.postNextIncident > casualty.preNextIncident,
      casualty.incident >= casualty.preNextIncident, casualty.incident < casualty.postNextIncident
    else { return false }
    if let origin = casualty.origin {
      guard origin.owner.system == birth.station.system, origin.owner.visit > 0,
        origin.owner.visit <= casualty.binding.actor.visit,
        origin.emissionID > 0, origin.emissionID < UInt64.max,
        validTime(origin.emittedAt), origin.emittedAt <= casualty.physicalTime
      else { return false }
    }
    return true
  }

  private static func validTime(_ time: Double) -> Bool {
    time.isFinite && (0...1e12).contains(time)
  }

  /// Only bounded reciprocal data joins. Never enter a global validity chain from here.
  static func validSource(
    _ optional: NativeUtilityEngineerState?, custody: NativePeopleCustodyState,
    commander: borrowing Commander) -> Bool
  {
    let station = OriginalStationSite.remoteUtility.identity(world: custody.owner)
    let record = commander.nativeStations?.ledger.records.first { $0.identity == station }
    guard let state = optional else { return record?.utilitySourceBirth == nil }
    let birth = state.registration
    guard custody.owner == commander.equipmentOwnerID, birth.identity.owner == custody.owner,
      shapeValid(state), let world = commander.nativeStations, let record,
      let marker = record.utilitySourceBirth,
      marker.operation == birth.operation, marker.station == birth.station,
      marker.binding == birth.binding, marker.spawn == birth.spawn,
      marker.physicalTime == birth.physicalTime,
      birth.physicalTime <= commander.flightSimulation.physicalTime,
      birth.binding.actor.visit <= commander.flightSimulation.visit,
      birth.binding.actor.entity < commander.flightSimulation.nextActor,
      birth.spawn.sequence < commander.flightSimulation.nextSpawn,
      let utility = record.utility, utility.owner == custody.owner,
      let pose = world.pose(for: station),
      custody.admissions.allSatisfy({ $0.person.nativeID != birth.identity.id }),
      custody.crewService?.people.allSatisfy({ $0.identity.id != birth.identity.id }) ?? true,
      custody.clinicSource?.registration.units.allSatisfy({
        $0.pilot.id != birth.identity.id
      }) ?? true,
      commander.accommodation.ownedBerths.allSatisfy({ $0.use.personID != birth.identity.id }),
      state.inspections.count == utility.consignments.filter({ $0.reception != nil }).count
    else { return false }
    for inspection in state.inspections {
      guard let job = utility.consignments.first(where: { $0.id == inspection.consignment }),
        job.installation == inspection.installation, let reception = job.reception,
        reception.operation == inspection.operation,
        reception.installation == inspection.installation.operation,
        reception.engineer == birth.identity.id,
        reception.contact == NativeUtilityStationContact(inspection.dock),
        reception.revision == inspection.utilityRevision,
        inspection.physicalTime <= commander.flightSimulation.physicalTime,
        inspection.dock.lifecycleRevision <= record.revision,
        inspection.dock.sequence < world.ledger.nextDockSequence,
        inspection.dock.dockingBinding.actor.visit <= commander.flightSimulation.visit,
        inspection.dock.dockingBinding.actor.entity < commander.flightSimulation.nextActor
      else { return false }
    }
    if let casualty = state.casualty {
      guard record.tombstone == casualty.tombstone, record.binding == nil, pose.energy == 0,
        casualty.physicalTime <= commander.flightSimulation.physicalTime,
        casualty.binding.actor.visit <= commander.flightSimulation.visit,
        casualty.binding.actor.entity < commander.flightSimulation.nextActor,
        casualty.postNextIncident <= commander.flightSimulation.nextIncident
      else { return false }
      if let origin = casualty.origin {
        guard origin.emissionID < commander.flightSimulation.nextEmission,
          origin.owner.entity < commander.flightSimulation.nextActor else { return false }
      }
    } else if record.tombstone != nil || pose.energy <= 0 {
      return false
    }
    return true
  }

  static func validateFields(_ bytes: Data, part: ScriptFreightVersionedSave.Part) throws {
    guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
      root["utilityEngineer"] == nil
    else { throw SaveError.invalidCommander }
    guard part == .commander else {
      guard root["savedNativePeopleCustody"] == nil else { throw SaveError.invalidCommander }
      return
    }
    let custody = root["savedNativePeopleCustody"] as? [String: Any] ?? [:]
    let containers = [
      "savedAccommodation", "savedEquipmentInventory", "savedScriptState", "savedContracts",
    ]
    for key in containers {
      let container = root[key] as? [String: Any] ?? [:]
      guard container["utilityEngineer"] == nil else { throw SaveError.invalidCommander }
    }
    guard let raw = custody["utilityEngineer"] else { return }
    _ = try decodeClosed(JSONSerialization.data(withJSONObject: raw))
  }
}
