import CoreFoundation
import Foundation

enum NativeC01CompletionSave {
  static func sourceValid(
    _ source: NativeC01CompletionSource, opening: borrowing NativeGlassMeridianState
  ) -> Bool {
    guard source.shapeValid, source.mission == opening.permission.mission,
      source.owner == opening.permission.owner, source.permission == opening.permission.operation,
      let capture = opening.surveyor?.capture,
      source.capture == capture.operation, source.marker == capture.marker.identity,
      source.recorderActor == capture.marker.body.physical?.identity,
      source.installation == opening.laneRepair?.installation?.operation,
      let arrival = opening.clinicEscort?.arrival,
      source.clinicArrival == arrival.operation, source.clinicReception == arrival.sourceReception,
      source.physicalTime >= arrival.physicalTime, source.physicalTime >= capture.physicalTime
    else { return false }
    return true
  }

  static func sourceHistoryValid(
    _ source: NativeC01CompletionSource, opening: borrowing NativeGlassMeridianState,
    commander: borrowing Commander
  ) -> Bool {
    guard sourceValid(source, opening: opening), source.owner == commander.equipmentOwnerID,
      let world = commander.nativeStations, world.mainStations.contains(source.dock.station),
      source.dock.sequence < world.nextMainDockSequence,
      source.dock.actor.visit <= commander.flightSimulation.visit,
      source.recorderActor.visit <= commander.flightSimulation.visit,
      source.physicalTime <= commander.flightSimulation.physicalTime,
      source.dock.calendarSeconds <= commander.scriptState.calendarSeconds
    else { return false }
    // Carrier, fitting, cash, epoch and purchase history can legitimately change later.
    return true
  }

  static func dispositionValid(
    _ value: NativeC01DispositionReceipt, opening: borrowing NativeGlassMeridianState,
    mission: ScriptInstance, engine: ScriptEngineState
  ) -> Bool {
    let receipt = value.choice
    guard sourceValid(value.source, opening: opening),
      let choice = NativeC01EvidenceChoice(rawValue: receipt.choice),
      receipt.label == choice.label, receipt.group == NativeC01Completion.group,
      receipt.dialogue == NativeC01Completion.dialogue,
      receipt.valid(for: mission, engine: engine),
      receipt.sequence == value.source.nextEvent + 1,
      receipt.revision == value.source.missionRevision + 1,
      receipt.cause?.revision == value.source.missionRevision,
      receipt.cause?.nativeMainDock == value.source.dock,
      receipt.committed.nativeMainDock == value.source.dock,
      receipt.cause?.galaxy == 0, receipt.cause?.system == 7,
      receipt.committed.galaxy == 0, receipt.committed.system == 7,
      value.operation == (try? NativeC01Completion.dispositionOperation(
        source: value.source, consent: value.consent, choice: choice,
        sequence: receipt.sequence, revision: receipt.revision))
    else { return false }
    return true
  }

  static func archiveShapeValid(_ opening: borrowing NativeGlassMeridianState) -> Bool {
    guard let archive = opening.surveyor?.archive else {
      return opening.completion?.terminal == nil
    }
    guard opening.surveyor?.capture != nil, opening.surveyor?.loss == nil,
      let completion = opening.completion, let terminal = completion.terminal,
      sourceValid(archive.source, opening: opening),
      archive.disposition == completion.disposition.operation,
      archive.source.physicalTime >= completion.disposition.source.physicalTime,
      archive.source.missionRevision >= completion.disposition.choice.revision,
      archive.source.nextEvent >= completion.disposition.choice.sequence,
      archive.sequence == archive.source.nextEvent + 1,
      archive.revision == archive.source.missionRevision + 1,
      archive.operation == (try? NativeC01Completion.archiveOperation(
        source: archive.source, consent: archive.consent, disposition: archive.disposition,
        sequence: archive.sequence, revision: archive.revision)),
      terminal.archive == archive.operation, terminal.sequence == archive.sequence,
      terminal.revision == archive.revision
    else { return false }
    let payment = terminal.payment
    guard payment.archive == archive.operation, payment.amount == NativeC01Completion.payment,
      payment.creditsBefore == archive.source.funds,
      (0...4_294_967_295 - NativeC01Completion.payment).contains(payment.creditsBefore),
      payment.creditsAfter == payment.creditsBefore + NativeC01Completion.payment,
      payment.operation == (try? NativeC01Completion.paymentOperation(
        archive: archive.operation, before: payment.creditsBefore, after: payment.creditsAfter)),
      (0...512).contains(terminal.journalCount),
      ScriptCompletionReceipt.validDigest(terminal.journalFingerprint),
      terminal.clinicLosses.count <= 1,
      terminal.clinicLosses == terminal.clinicLosses.sorted(by: { $0.uuidString < $1.uuidString }),
      Set(terminal.clinicLosses).count == terminal.clinicLosses.count,
      terminal.clinicDispositionRevision < UInt64(Int64.max) - 1,
      terminal.operation == (try? NativeC01Completion.terminalOperation(
        archive: terminal.archive, payment: payment.operation, sequence: terminal.sequence,
        revision: terminal.revision, journalCount: terminal.journalCount,
        journalFingerprint: terminal.journalFingerprint, clinicLosses: terminal.clinicLosses,
        clinicRevision: terminal.clinicDispositionRevision))
    else { return false }
    return true
  }

  static func archiveHistoryValid(
    _ opening: borrowing NativeGlassMeridianState, mission: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    guard archiveShapeValid(opening) else { return false }
    guard let archive = opening.surveyor?.archive else { return true }
    guard mission.outcome == .complete else { return false }
    guard sourceHistoryValid(archive.source, opening: opening, commander: commander) else {
      return false
    }
    guard archive.sequence <= commander.scriptState.nextEvent else { return false }
    guard mission.hasAcknowledged(archive.sequence) else { return false }
    return true
  }

  /// No call to receipt.valid, full Commander validation, or the clue journal here.
  /// The generic receipt validator and outer native save seam both use this DAG leaf.
  static func validCompletion(
    _ receipt: ScriptCompletionReceipt, state mission: borrowing ScriptInstance,
    engine: borrowing ScriptEngineState
  ) -> Bool {
    guard mission.definition == NativeGlassMeridian.stateID,
      mission.digest == NativeGlassMeridian.digest, mission.version == NativeGlassMeridian.version,
      mission.outcome == .complete, receipt.outcome == .complete,
      receipt.instance == mission.id, receipt.definition == mission.definition,
      receipt.version == mission.version, receipt.digest == mission.digest,
      receipt.causeKind == "mission.receipted", mission.contract == nil,
      let opening = mission.savedGlassMeridian, archiveShapeValid(opening),
      let completion = opening.completion, let terminal = completion.terminal,
      let archive = opening.surveyor?.archive, let clinic = opening.clinicEscort,
      NativeC01ClinicEscortSave.shapeValid(clinic),
      dispositionValid(completion.disposition, opening: opening, mission: mission, engine: engine),
      receipt.sequence == terminal.sequence, receipt.revision == terminal.revision,
      receipt.committed.revision == terminal.revision,
      receipt.cause?.revision == archive.source.missionRevision,
      receipt.cause?.nativeMainDock == archive.source.dock,
      receipt.committed.nativeMainDock == archive.source.dock,
      receipt.milestones == Array(0...8), mission.milestones == Set(0...8),
      receipt.choices == mission.choiceReceipts,
      mission.choiceReceipts == [NativeC01Completion.group: completion.disposition.choice],
      receipt.settlementAmount == nil,
      terminal.sequence <= engine.nextEvent, mission.hasAcknowledged(terminal.sequence),
      mission.journal.count >= terminal.journalCount,
      terminal.journalFingerprint == (try? NativeC01Completion.journalHash(
        Array(mission.journal.prefix(terminal.journalCount))))
    else { return false }
    let losses = NativeC01Completion.losses(clinic)
    guard let post = completion.postTerminalClinicLoss else {
      return mission.revision == terminal.revision
        && mission.journal.count == terminal.journalCount
        && Set(losses.map(\.operation)) == Set(terminal.clinicLosses)
        && losses.allSatisfy { $0.physicalTime <= archive.source.physicalTime }
    }
    guard terminal.revision < UInt64(Int64.max) - 1,
      post.terminal == terminal.operation, post.beforeRevision == terminal.revision,
      post.afterRevision == terminal.revision + 1, mission.revision == post.afterRevision,
      post.sequence > terminal.sequence, post.sequence < UInt64(Int64.max), post.sequence <= engine.nextEvent,
      mission.hasAcknowledged(post.sequence), (0..<2).contains(post.ordinal),
      let loss = clinic.parkedLosses.first(where: { $0.operation == post.loss }),
      loss.ordinal == post.ordinal, loss.launch == nil, clinic.launch(for: post.ordinal) == nil,
      post.ordinal != clinic.current?.ordinal, loss.sourceDisposition == post.sourceDisposition,
      post.physicalTime.isFinite, loss.physicalTime == post.physicalTime,
      loss.physicalTime > archive.source.physicalTime,
      loss.actor.presence == .destroyed, loss.actor.body.energy == 0,
      loss.actor.body.physical?.deathIncidentID != nil,
      post.operation == (try? NativeC01Completion.postTerminalOperation(
        terminal: terminal.operation, loss: loss, sequence: post.sequence,
        before: post.beforeRevision, after: post.afterRevision)),
      Set(losses.filter { $0.operation != loss.operation }.map(\.operation))
        == Set(terminal.clinicLosses), losses.count == terminal.clinicLosses.count + 1,
      mission.journal.count == terminal.journalCount + 1,
      mission.journal.last == NativeC01Completion.casualtyJournal
    else { return false }
    return true
  }

  static func valid(_ mission: ScriptInstance, commander: borrowing Commander) -> Bool {
    guard let opening = mission.savedGlassMeridian,
      mission.milestones == NativeC01Completion.milestones(opening),
      mission.conversationReceipts.isEmpty
    else { return false }
    let local = mission.receipts.intersection(NativeC01Completion.localReceipts)
    guard let completion = opening.completion else {
      return mission.outcome == .active && mission.completionReceipt == nil
        && mission.choiceReceipts.isEmpty && opening.surveyor?.archive == nil && local.isEmpty
    }
    let disposition = completion.disposition
    guard sourceHistoryValid(disposition.source, opening: opening, commander: commander),
      dispositionValid(disposition, opening: opening, mission: mission, engine: commander.scriptState),
      mission.choiceReceipts == [NativeC01Completion.group: disposition.choice]
    else { return false }
    if completion.terminal == nil {
      guard mission.outcome == .active, mission.completionReceipt == nil,
        completion.postTerminalClinicLoss == nil, opening.surveyor?.archive == nil,
        local == [NativeC01Completion.choiceReceipt, NativeC01Completion.group],
        commander.scriptState.savedClueJournal?.awards[NativeC01Completion.sourceID] == nil
      else { return false }
      if let loss = opening.surveyor?.loss {
        guard let later = opening.reservationCase?.laterLoss, later.loss == loss,
          later.audit == opening.reservationCase?.audit?.operation,
          later.sequence > disposition.choice.sequence, later.sequence <= commander.scriptState.nextEvent,
          mission.hasAcknowledged(later.sequence), loss.physicalTime >= disposition.source.physicalTime
        else { return false }
      }
      return true
    }
    guard local == NativeC01Completion.localReceipts,
      archiveHistoryValid(opening, mission: mission, commander: commander),
      let receipt = mission.completionReceipt,
      receipt.valid(for: mission, engine: commander.scriptState),
      validCompletion(receipt, state: mission, engine: commander.scriptState),
      let award = commander.scriptState.savedClueJournal?.awards[NativeC01Completion.sourceID],
      award.completion == receipt, award.clueID == "meridian-offset",
      award.receiptID == "l337.unwritten-route/clue/meridian-offset",
      let terminal = completion.terminal, let people = commander.nativePeople?.clinicSource,
      let clinic = opening.clinicEscort,
      NativeC01ClinicPeopleSave.sourceClaimsMatch(clinic, mission: mission, commander: commander)
    else { return false }
    let extra: UInt64 = completion.postTerminalClinicLoss == nil ? 0 : 1
    guard people.revision == terminal.clinicDispositionRevision + extra else { return false }
    if let post = completion.postTerminalClinicLoss {
      guard let disposition = people.disposition(post.ordinal),
        disposition.operation == post.sourceDisposition, disposition.assignment == nil,
        case .casualty = disposition.kind
      else { return false }
    }
    return true
  }

  static func hasRetainedSpare(_ opening: NativeGlassMeridianState, commander: borrowing Commander) -> Bool {
    guard let clinic = opening.clinicEscort, let arrived = clinic.current,
      clinic.arrival != nil, let people = commander.nativePeople?.clinicSource,
      let group = commander.scriptState.instances[opening.permission.mission]?
        .ownedEncounters[NativeC01ClinicEscort.sourceEncounter]
    else { return false }
    return clinic.birth.units.contains { unit in
      guard unit.ordinal != arrived.ordinal, clinic.launch(for: unit.ordinal) == nil,
        clinic.loss(for: unit.ordinal) == nil, people.assignment(unit.ordinal) == nil,
        people.disposition(unit.ordinal) == nil,
        let actor = group.actors[NativeC01ClinicEscort.stockTarget(unit.ordinal)],
        NativeC01ClinicEscort.original(actor, source: clinic.source, ordinal: unit.ordinal),
        actor.body.energy > 0, [.present, .unloaded, .outside].contains(actor.presence),
        actor.body.physical?.deathIncidentID == nil
      else { return false }
      return true
    }
  }

  /// Called only after the existing actual private witness prepared its native casualty.
  /// MC1 custody and the unchanged current mission are still installed at this point.
  static func recordPostTerminalLoss(
    _ loss: NativeC01ClinicHullLoss, mission: inout ScriptInstance, commander: borrowing Commander
  ) throws -> UInt64? {
    guard mission.outcome == .complete else { return nil }
    guard var opening = mission.savedGlassMeridian, var completion = opening.completion,
      let terminal = completion.terminal, let receipt = mission.completionReceipt,
      completion.postTerminalClinicLoss == nil, mission.revision == terminal.revision + 1,
      terminal.revision == receipt.revision, loss.launch == nil,
      let clinic = opening.clinicEscort, loss.ordinal != clinic.current?.ordinal,
      loss.physicalTime > (opening.surveyor?.archive?.source.physicalTime ?? .infinity),
      commander.scriptState.nextEvent < UInt64(Int64.max) - 1,
      mission.journal.count <= 512
    else { throw SaveError.invalidCommander }
    let sequence = commander.scriptState.nextEvent + 1
    completion.postTerminalClinicLoss = .init(
      operation: try NativeC01Completion.postTerminalOperation(
        terminal: terminal.operation, loss: loss, sequence: sequence,
        before: terminal.revision, after: mission.revision),
      terminal: terminal.operation, loss: loss.operation, sourceDisposition: loss.sourceDisposition,
      ordinal: loss.ordinal, sequence: sequence, beforeRevision: terminal.revision,
      afterRevision: mission.revision, physicalTime: loss.physicalTime)
    opening.completion = completion
    mission.savedGlassMeridian = opening
    mission.acknowledge(sequence)
    var engine = commander.scriptState
    engine.nextEvent = sequence
    guard validCompletion(receipt, state: mission, engine: engine) else { throw SaveError.invalidCommander }
    return sequence
  }

  static func projectedOutcome(_ mission: ScriptInstance, commander: borrowing Commander) -> String? {
    guard mission.definition == NativeGlassMeridian.stateID, mission.version == NativeGlassMeridian.version,
      mission.digest == NativeGlassMeridian.digest, let opening = mission.savedGlassMeridian,
      opening.permission.owner == commander.equipmentOwnerID,
      valid(mission, commander: commander),
      let choice = opening.completion.flatMap({ NativeC01EvidenceChoice(rawValue: $0.disposition.choice.choice) })
    else { return nil }
    return NativeC01Completion.rumour(choice, complete: mission.outcome == .complete)
  }

  // New current-format wrappers have literal closed keys. Existing nested native codecs
  // retain their field names; strict C01 contexts require the actual native main dock.
  private static func object(
    _ value: Any?, required: String, optional: String = "", limit: Int = 8192
  ) throws -> [String: Any] {
    guard let value = value as? [String: Any] else { throw SaveError.invalidCommander }
    let keys = Set(value.keys), needed = Set(required.split(separator: " ").map(String.init))
    let allowed = needed.union(optional.split(separator: " ").map(String.init))
    guard needed.isSubset(of: keys), keys.isSubset(of: allowed),
      !value.values.contains(where: { $0 is NSNull }),
      try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).count <= limit
    else { throw SaveError.invalidCommander }
    return value
  }
  private static func integer(_ value: Any?) -> Bool {
    guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
    let type = String(cString: number.objCType)
    return !["f", "d"].contains(type) && number.int64Value >= 0
      && number.uint64Value < UInt64(Int64.max)
  }
  private static func positive(_ value: Any?) -> Bool {
    integer(value) && (((value as? NSNumber)?.int64Value ?? 0) > 0)
  }
  private static func checkSource(_ raw: Any?) throws {
    let source = try object(raw, required: "mission owner permission capture marker recorderActor installation clinicArrival clinicReception dock carrier inventoryRevision inventoryFingerprint historyPresent historyRevision historyFingerprint missionRevision nextEvent funds physicalTime epoch")
    for key in ["inventoryRevision", "historyRevision", "missionRevision", "nextEvent", "funds"] {
      guard integer(source[key]) else { throw SaveError.invalidCommander }
    }
    guard let present = source["historyPresent"] as? NSNumber,
      CFGetTypeID(present) == CFBooleanGetTypeID()
    else { throw SaveError.invalidCommander }
    try checkDock(source["dock"])
    try checkActor(source["recorderActor"])
    let decoded = try JSONDecoder().decode(NativeC01CompletionSource.self,
      from: JSONSerialization.data(withJSONObject: source))
    guard decoded.shapeValid else { throw SaveError.invalidCommander }
  }
  private static func checkSystem(_ raw: Any?) throws {
    let value = try object(raw, required: "galaxy system", limit: 128)
    guard integer(value["galaxy"]), integer(value["system"]) else { throw SaveError.invalidCommander }
  }
  private static func checkActor(_ raw: Any?) throws {
    let value = try object(raw, required: "system visit entity", limit: 512)
    try checkSystem(value["system"])
    guard positive(value["visit"]), integer(value["entity"]) else { throw SaveError.invalidCommander }
  }
  private static func checkDock(_ raw: Any?) throws {
    let value = try object(raw, required: "station actor commanderOwner sequence calendarSeconds", limit: 2048)
    let station = try object(value["station"], required: "world system resource", limit: 768)
    try checkSystem(station["system"])
    try checkActor(value["actor"])
    guard positive(value["sequence"]) else { throw SaveError.invalidCommander }
  }
  private static func checkContext(_ raw: Any?) throws {
    let value = try object(raw, required: "galaxy system docked mainStation revision frameSeconds localSeconds flightSeconds calendarSeconds transitSeconds nativeMainDock", optional: "playerPosition", limit: 4096)
    for key in ["galaxy", "system", "revision"] {
      guard integer(value[key]) else { throw SaveError.invalidCommander }
    }
    for key in ["docked", "mainStation"] {
      guard let n = value[key] as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else {
        throw SaveError.invalidCommander
      }
    }
    try checkDock(value["nativeMainDock"])
    if let position = value["playerPosition"] { _ = try object(position, required: "x y z", limit: 256) }
    let decoded = try JSONDecoder().decode(ScriptEventContext.self,
      from: JSONSerialization.data(withJSONObject: value))
    guard decoded.valid, decoded.galaxy == 0, decoded.system == 7,
      decoded.docked, decoded.mainStation
    else { throw SaveError.invalidCommander }
  }
  private static func checkArchive(_ raw: Any?) throws {
    let value = try object(raw, required: "operation source disposition consent sequence revision", limit: 16384)
    try checkSource(value["source"])
    guard positive(value["sequence"]), positive(value["revision"]) else { throw SaveError.invalidCommander }
    let decoded = try JSONDecoder().decode(NativeC01RecorderArchive.self,
      from: JSONSerialization.data(withJSONObject: value))
    guard (value as NSDictionary).isEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
    else { throw SaveError.invalidCommander }
  }
  private static func checkCompletion(_ raw: Any?) throws {
    let value = try object(raw, required: "disposition", optional: "terminal postTerminalClinicLoss", limit: 65536)
    let disposition = try object(value["disposition"], required: "operation source consent choice", limit: 24576)
    try checkSource(disposition["source"])
    let choice = try object(disposition["choice"], required: "instance group choice label dialogue sequence revision cause committed", limit: 12288)
    guard positive(choice["sequence"]), positive(choice["revision"]) else { throw SaveError.invalidCommander }
    try checkContext(choice["cause"])
    try checkContext(choice["committed"])
    if let rawTerminal = value["terminal"] {
      let terminal = try object(rawTerminal, required: "operation archive payment sequence revision journalCount journalFingerprint clinicLosses clinicDispositionRevision", limit: 4096)
      let payment = try object(terminal["payment"], required: "operation archive amount creditsBefore creditsAfter", limit: 1024)
      for key in ["amount", "creditsBefore", "creditsAfter"] {
        guard integer(payment[key]) else { throw SaveError.invalidCommander }
      }
      for key in ["sequence", "revision", "journalCount", "clinicDispositionRevision"] {
        guard integer(terminal[key]) else { throw SaveError.invalidCommander }
      }
      guard let losses = terminal["clinicLosses"] as? [Any], losses.count <= 1 else {
        throw SaveError.invalidCommander
      }
    }
    if let rawPost = value["postTerminalClinicLoss"] {
      let post = try object(rawPost, required: "operation terminal loss sourceDisposition ordinal sequence beforeRevision afterRevision physicalTime", limit: 2048)
      guard value["terminal"] != nil else { throw SaveError.invalidCommander }
      for key in ["ordinal", "sequence", "beforeRevision", "afterRevision"] {
        guard integer(post[key]) else { throw SaveError.invalidCommander }
      }
    }
    let decoded = try JSONDecoder().decode(NativeC01CompletionState.self,
      from: JSONSerialization.data(withJSONObject: value))
    if let terminal = decoded.terminal {
      let payment = terminal.payment
      guard terminal.sequence > 0, terminal.revision > 0, (0...512).contains(terminal.journalCount),
        ScriptCompletionReceipt.validDigest(terminal.journalFingerprint),
        payment.amount == NativeC01Completion.payment,
        (0...4_294_967_295 - NativeC01Completion.payment).contains(payment.creditsBefore),
        payment.creditsAfter == payment.creditsBefore + payment.amount
      else { throw SaveError.invalidCommander }
    }
    if let post = decoded.postTerminalClinicLoss {
      guard post.sequence > 0, post.beforeRevision > 0, post.afterRevision > 0,
        (0..<2).contains(post.ordinal), post.physicalTime.isFinite,
        (0...1e12).contains(post.physicalTime)
      else { throw SaveError.invalidCommander }
    }
    guard (value as NSDictionary).isEqual(try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)))
    else { throw SaveError.invalidCommander }
  }
  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part, schema: Int?) throws {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      root["completion"] == nil, root["nativeC01Completion"] == nil, root["recorderArchive"] == nil
    else { throw SaveError.invalidCommander }
    func check(_ object: [String: Any], embedded: Bool) throws {
      let raw = object["instances"]
      let values: [Any]
      if let dictionary = raw as? [String: Any], dictionary.count <= 128 { values = Array(dictionary.values) }
      else if let array = raw as? [Any], array.count <= 256, array.count.isMultiple(of: 2) {
        values = stride(from: 1, to: array.count, by: 2).map { array[$0] }
      } else if raw == nil { values = [] }
      else { throw SaveError.invalidCommander }
      for rawMission in values {
        guard let mission = rawMission as? [String: Any], mission["completion"] == nil,
          mission["nativeC01Completion"] == nil, mission["recorderArchive"] == nil
        else { throw SaveError.invalidCommander }
        guard let opening = mission["savedGlassMeridian"] as? [String: Any] else { continue }
        let completion = opening["completion"]
        let archive = (opening["surveyor"] as? [String: Any])?["archive"]
        guard completion != nil || archive != nil else { continue }
        guard !embedded, part == .missions, NativeC01ReservationAuditSave.contains(schema),
          mission["definition"] as? String == NativeGlassMeridian.stateID,
          mission["version"] as? String == NativeGlassMeridian.version,
          mission["digest"] as? String == NativeGlassMeridian.digest
        else { throw SaveError.invalidCommander }
        let hasTerminal = (completion as? [String: Any])?["terminal"] != nil
        guard hasTerminal == (archive != nil) else { throw SaveError.invalidCommander }
        if let completion { try checkCompletion(completion) }
        if let archive { try checkArchive(archive) }
      }
    }
    try check(root, embedded: part != .missions)
    if let embedded = root["savedScriptState"] as? [String: Any] { try check(embedded, embedded: true) }
  }
}
