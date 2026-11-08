import Foundation

/// Strict current state-leaf codec; registration in the current root format belongs to G1.
/// Decoding grants no current source, life, motion, contact or physical permission.
enum NativeHollowManifestSave {
  enum Failure: Error, Equatable { case resourceLimit, invalidLeaf, noncanonical, changedHistory }
  static let maximumBytes = NativeHollowManifestBirthCodec.maximumBytes

  static func encode(_ state: NativeHollowManifestState) throws -> Data {
    guard collectionsBounded(state), typedStringsBounded(state) else { throw Failure.resourceLimit }
    guard state.shapeValid else { throw Failure.invalidLeaf }
    _ = try NativeHollowManifestBirthCodec.encode(state.birth)
    let bytes = try canonical(state)
    _ = try boundedBirthSlice(bytes)
    return bytes
  }

  static func decode(
    _ bytes: Data, owner: UUID, mission: UUID, existing: NativeHollowManifestState? = nil
  ) throws -> NativeHollowManifestState {
    let birthBytes = try boundedBirthSlice(bytes)
    let birth = try NativeHollowManifestBirthCodec.decode(
      birthBytes, owner: owner, mission: mission, existingBirth: existing?.birth)
    let state = try JSONDecoder().decode(NativeHollowManifestState.self, from: bytes)
    guard collectionsBounded(state), typedStringsBounded(state), state.birth == birth,
      state.shapeValid
    else { throw Failure.invalidLeaf }
    guard try canonical(state) == bytes else { throw Failure.noncanonical }
    if let existing, !state.preservesHistory(of: existing) { throw Failure.changedHistory }
    return state
  }

  /// Historical joins only. Current carrier, item availability and fitting are not history.
  static func historicalOwnerMatches(
    _ state: NativeHollowManifestState, commander: borrowing Commander, mission: UUID
  ) -> Bool {
    let flight = commander.flightSimulation
    guard collectionsBounded(state), typedStringsBounded(state), state.shapeValid, flight.valid,
      NativeHollowManifestBirthCodec.historicalOwnerMatches(
        state.birth, commander: commander, mission: mission),
      state.admissions.allSatisfy({
        historicalActor($0.original.actor, flight: flight)
          && $0.original.issuedTime <= flight.physicalTime && $0.spawn.sequence < flight.nextSpawn
      })
    else { return false }
    for inspection in state.inspections {
      guard inspection.facts.last.physicalTime <= flight.physicalTime,
        historicalActor(inspection.facts.player, flight: flight),
        historicalActor(inspection.facts.original.actor, flight: flight)
      else { return false }
    }
    if let trail = state.wakeTrail {
      guard trail.origin.physicalTime <= flight.physicalTime,
        historicalActor(trail.origin.anchors.station.identity, flight: flight),
        trail.admissions.allSatisfy({
          historicalActor($0.actor, flight: flight) && $0.spawn.sequence < flight.nextSpawn
            && $0.physicalTime <= flight.physicalTime
        }),
        trail.observations.allSatisfy({
          historicalActor($0.player, flight: flight) && $0.reading.physicalTime <= flight.physicalTime
        })
      else { return false }
    }
    if let register = state.custodyRegister {
      guard register.origin.physicalTime <= flight.physicalTime,
        historicalActor(register.origin.anchors.station.identity, flight: flight),
        register.admissions.allSatisfy({
          historicalActor($0.actor, flight: flight) && $0.spawn.sequence < flight.nextSpawn
            && $0.physicalTime <= flight.physicalTime
        })
      else { return false }
      if let recovery = register.recovery {
        guard historicalActor(recovery.facts.player, flight: flight),
          recovery.facts.readout.physicalTime <= flight.physicalTime,
          recovery.facts.inventoryRevision <= (commander.equipmentInventory?.revision ?? 0)
        else { return false }
      }
    }
    let roots = state.terminals.map(\.effect) + state.withdrawals.map(\.effect)
    for root in roots {
      guard root.incident.id < flight.nextIncident,
        root.incident.physicalTime <= flight.physicalTime,
        root.contactPhysicalTime.map({ $0 <= flight.physicalTime }) ?? true,
        historicalOrigin(root.incident.origin, flight: flight),
        root.incident.lawIncident.map({ historicalLaw($0, flight: flight) }) ?? true
      else { return false }
      if let death = root.destructionIncident, !historicalLaw(death, flight: flight) {
        return false
      }
    }
    for effect in state.firstCompromises + [state.latestSealDamage].compactMap({ $0 }) {
      guard effect.facts.cause.id < flight.nextIncident,
        effect.facts.cause.physicalTime <= flight.physicalTime,
        historicalOrigin(effect.facts.cause.origin, flight: flight)
      else { return false }
    }
    return state.consents.allSatisfy { value in
      historicalActor(value.request.player, flight: flight)
        && value.request.physicalTime <= flight.physicalTime
        && [value.reply?.physicalTime, value.revocation?.physicalTime]
          .compactMap { $0 }.allSatisfy { $0 <= flight.physicalTime }
    }
  }

  private static func historicalActor(_ actor: ActorIdentity, flight: FlightSimulationState) -> Bool
  {
    (0..<8).contains(actor.system.galaxy) && (0...256).contains(actor.system.system)
      && actor.visit > 0 && actor.visit <= flight.visit && actor.entity < flight.nextActor
  }
  private static func historicalOrigin(_ origin: AttackOrigin?, flight: FlightSimulationState)
    -> Bool
  {
    guard let origin else { return true }
    return origin.emissionID > 0 && origin.emissionID < flight.nextEmission
      && origin.emittedAt <= flight.physicalTime
      && historicalActor(origin.owner, flight: flight)
      && (origin.ordnance.map { $0.entity > 1 && historicalActor($0, flight: flight) } ?? true)
  }

  private static func historicalLaw(_ event: CombatIncident, flight: FlightSimulationState) -> Bool
  {
    event.id > 0 && event.id < flight.nextIncident && event.physicalTime <= flight.physicalTime
      && historicalOrigin(event.origin, flight: flight)
      && (event.victim.map { historicalActor($0, flight: flight) } ?? true)
      && (event.firstAggressor.map { historicalActor($0, flight: flight) } ?? true)
  }

  private static func typedStringsBounded(_ state: NativeHollowManifestState) -> Bool {
    // Collection bounds precede this walk; every caller-controlled string precedes ANY encoder.
    guard [state.birth.rootDesign, state.birth.master.template].allSatisfy(designStringsBounded)
    else { return false }
    let roots = state.terminals.map(\.effect) + state.withdrawals.map(\.effect)
    let origins =
      roots.flatMap {
        [$0.incident.origin, $0.incident.lawIncident?.origin, $0.destructionIncident?.origin]
      }
      + (state.firstCompromises + [state.latestSealDamage].compactMap { $0 }).map {
        $0.facts.cause.origin
      }
    let strings = origins.compactMap { $0?.sourcePart }
    let parts = roots.flatMap {
      [
        $0.incident.victimPart, $0.incident.lawIncident?.victimPart,
        $0.destructionIncident?.victimPart,
      ]
    }.compactMap { $0 }
    let effects = state.firstCompromises + [state.latestSealDamage].compactMap { $0 }
    let references = state.admissions.map(\.geometry) + effects.map { $0.facts.geometry }
    let descriptors =
      [state.ownedEncounterID].compactMap { $0 } + parts
      + effects.compactMap { $0.facts.cause.victimPart }
      + references.flatMap { [$0.rootGeometryHash, $0.sealGeometryHash] }
    return (strings + descriptors).allSatisfy(boundedString)
      && strings.reduce(0) { $0 + $1.utf8.count } <= 8192
  }

  private static func collectionsBounded(_ state: NativeHollowManifestState) -> Bool {
    guard state.birth.originals.count == 2, state.birth.operations.count == 7,
      state.admissions.count <= 20, state.firstAdmissions.count <= 2,
      state.latestAdmissions.count <= 2,
      state.terminals.count <= 2, state.consents.count <= 2, state.firstCompromises.count <= 2,
      state.withdrawals.count <= 2, state.routes.count <= 2, state.inspections.count <= 2,
      state.wakeTrail.map({ $0.admissions.count <= 9 && $0.observations.count <= 3 }) ?? true,
      state.custodyRegister.map({
        $0.admissions.count <= 3 && $0.origin.contents.seals.count == 2
          && $0.origin.contents.wakeObservations.count == 3
          && ($0.recovery.map({ $0.facts.comparison.bounded && $0.facts.readout.heights.count == 3
            && $0.facts.readout.surfaceRanges.count == 12 }) ?? true)
      }) ?? true
    else { return false }
    return designCollectionsBounded(state.birth.rootDesign, vertices: 140, faces: 236)
      && designCollectionsBounded(state.birth.master.template, vertices: 64, faces: 96)
  }

  private static func designCollectionsBounded(_ design: ShipDesign, vertices: Int, faces: Int)
    -> Bool
  {
    guard design.vertices.count == vertices, design.faces.count == faces,
      design.vertices.allSatisfy({ $0.count == 3 }), design.faces.allSatisfy({ $0.count == 3 }),
      (design.details?.count ?? 0) <= 256, (design.materials?.count ?? 0) <= 256,
      (design.faceMaterials?.count ?? 0) <= 256, (design.sourceFaceColours?.count ?? 0) <= 256,
      (design.sourceTextures?.count ?? 0) <= 256, (design.resolvedTextures?.count ?? 0) <= 256,
      (design.textures?.count ?? 0) <= 256,
      (design.sourceFaceTextures?.count ?? 0) <= 256, (design.faceTextures?.count ?? 0) <= 256
    else { return false }
    return (design.sourceFaceColours ?? []).allSatisfy { $0.count <= 4 }
      && ((design.sourceFaceTextures ?? []) + (design.faceTextures ?? [])).allSatisfy {
        $0.uv.count <= 4 && $0.uv.allSatisfy { $0.count <= 2 }
      }
  }

  private static func designStringsBounded(_ design: ShipDesign) -> Bool {
    let metadata =
      [design.license, design.source]
      + [
        design.paletteName, design.appearanceSource, design.appearanceLicense,
        design.appearanceBasis,
      ].compactMap { $0 }
    let materials = (design.materials ?? []).map(\.name)
    let source = (design.sourceTextures ?? []).flatMap { [$0.name, $0.source, $0.license] }
    let resolved = (design.resolvedTextures ?? []).flatMap {
      [$0.asset, $0.material, $0.definition, $0.modelSHA256]
    }
    let textures = (design.textures ?? []).flatMap { [$0.asset, $0.license] }
    return (metadata + materials + source + resolved + textures).allSatisfy(boundedString)
  }

  private static func boundedString(_ string: String) -> Bool {
    guard string.utf8.count <= NativeHollowManifestBirthCodec.maximumStringBytes else {
      return false
    }
    // Conservative quoted JSON bound, including control/quote escapes and Unicode surrogates.
    let encoded = string.unicodeScalars.reduce(0) { count, scalar in
      let value = scalar.value
      return count
        + (value < 32 || value == 34 || value == 92 || value >= 128
          ? (value > 65535 ? 12 : 6) : 1)
    }
    return encoded <= NativeHollowManifestBirthCodec.maximumStringBytes
  }

  private static func canonical(_ state: NativeHollowManifestState) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(state)
  }

  /// Reuses the reviewed global string/depth/scalar/geometry bounds BEFORE Foundation allocation.
  /// This extra scanner only caps state collections and slices the original nested birth bytes;
  /// reserializing a Foundation dictionary could normalize the birth's canonical numbers.
  static func boundedBirthSlice(_ data: Data) throws -> Data {
    try NativeHollowManifestBirthCodec.preflight(data)
    struct Frame {
      let closing: UInt8
      let maximum: Int
      let birthStart: Int?
      var commas = 0
      var key: String?
      var expectsKey = true
    }
    let bytes = [UInt8](data)
    var frames: [Frame] = []
    var quoted = false
    var escaped = false
    var keyString = false
    var start = 0
    var birthRange: Range<Int>?
    for (index, byte) in bytes.enumerated() {
      if quoted {
        if escaped {
          escaped = false
        } else if byte == 92 {
          escaped = true
        } else if byte == 34 {
          quoted = false
          if keyString {
            frames[frames.count - 1].key = String(decoding: bytes[start..<index], as: UTF8.self)
            frames[frames.count - 1].expectsKey = false
          }
        }
        continue
      }
      switch byte {
      case 34:
        quoted = true
        keyString = frames.last?.closing == 125 && frames.last?.expectsKey == true
        start = index + 1
      case 91, 123:
        let key = frames.last?.key
        let maximum: Int
        switch key {
        case "observations": maximum = 3
        case "admissions": maximum = 20
        case "firstAdmissions", "latestAdmissions", "terminals", "consents",
          "firstCompromises", "withdrawals", "routes", "inspections":
          maximum = 2
        default: maximum = 256
        }
        frames.append(
          .init(
            closing: byte == 91 ? 93 : 125, maximum: byte == 91 ? maximum : 64,
            birthStart: frames.count == 1 && key == "birth" && byte == 123 ? index : nil))
      case 93, 125:
        guard let frame = frames.popLast(), frame.closing == byte else { throw Failure.invalidLeaf }
        if let start = frame.birthStart {
          guard birthRange == nil else { throw Failure.noncanonical }
          birthRange = start..<(index + 1)
        }
      case 44:
        guard !frames.isEmpty else { throw Failure.invalidLeaf }
        frames[frames.count - 1].commas += 1
        guard frames[frames.count - 1].commas < frames[frames.count - 1].maximum
        else { throw Failure.resourceLimit }
        if frames.last?.closing == 125 { frames[frames.count - 1].expectsKey = true }
      default: break
      }
    }
    guard let birthRange else { throw Failure.invalidLeaf }
    return data.subdata(in: birthRange)
  }
}

extension NativeHollowManifestSave {
  static let field = "savedHollowManifest"

  /// The ordinary writer escapes slashes. Require its EXACT encoding, then enter the unchanged
  /// strict standalone codec. No Foundation dictionary round-trip normalizes birth numbers.
  static func decodePublication(_ bytes: Data, owner: UUID, mission: UUID) throws
    -> NativeHollowManifestState
  {
    _ = try boundedBirthSlice(bytes)
    let state = try JSONDecoder().decode(NativeHollowManifestState.self, from: bytes)
    let writer = ScriptValueStorage.encoder()
    guard try writer.encode(state) == bytes else { throw Failure.noncanonical }
    return try decode(encode(state), owner: owner, mission: mission)
  }

  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.withReadOnlyScriptState { $0.instances.values.contains(where: NativeHollowManifestCommission.marked) }
  }
  @inline(never)
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    let cases = commander.withReadOnlyScriptState {
      $0.instances.values.filter { NativeHollowManifestCommission.marked($0) }
    }
    guard cases.count <= 1 else { return false }
    for instance in cases {
      guard NativeHollowManifestCommission.prefixValid(instance),
        let state = instance.savedHollowManifest,
        historicalOwnerMatches(state, commander: commander, mission: instance.id)
      else { return false }
      if state.crewSource != nil {
        guard let custody = commander.nativePeople, let source = custody.hollowManifestCrew,
          NativeC03CrewSourceSave.validSource(source, custody: custody, commander: commander),
          source.missionReference == state.crewSource,
          source.crewLogAccess == state.crewLogAccess
        else { return false }
      }
      if let file = state.caseFile, !file.valid(commander: commander) { return false }
      if let lab = state.laboratory {
        guard lab.facts.physicalTime <= commander.flightSimulation.physicalTime,
          NativeStationPassengerJourney.historicalDock(lab.facts.dock, commander: commander),
          let inventory = commander.equipmentInventory,
          inventory.owner == state.birth.input.owner,
          inventory.revision >= lab.facts.afterInventoryRevision,
          let issue = instance.gearIssues[NativeHollowManifestKitDefinition.resource]
        else { return false }
        let originals = inventory.items.filter { $0.id == lab.facts.originalKit }
        if state.caseFile?.evidenceReturn != nil {
          guard issue.status == .returned, originals.isEmpty else { return false }
        } else if issue.consumed.contains(lab.facts.originalKit) {
          guard originals.isEmpty else { return false }
        } else {
          guard originals.count == 1, let item = originals.first,
            item.node == NativeHollowManifestKitDefinition.node, item.location == nil,
            item.component == nil, item.nativeRepairLoopCondition == nil,
            item.provenance == .missionIssue(
              mission: instance.id, resource: NativeHollowManifestKitDefinition.resource,
              index: 0, packDigest: instance.digest)
          else { return false }
        }
      }
      if state.phase != .unadmitted,
        !admittedGeometryMatches(state, instance: instance, commander: commander)
      {
        return false
      }
    }
    return true
  }

  private static func admittedGeometryMatches(
    _ state: NativeHollowManifestState, instance: borrowing ScriptInstance,
    commander: borrowing Commander
  ) -> Bool {
    // The pure actor predicate sees only its instance. Join the actual saved geometry table
    // through G3's closed overlay aliases, not similar body shapes or inferred body hashes.
    guard let frame = state.sourceFrame, let anchors = state.routeAnchors,
      let owned = instance.ownedEncounters[NativeHollowManifestCommission.encounter],
      let declarations = try? NativeHollowManifestCommission.admissionDeclarations(
        birth: state.birth, anchors: anchors, sourceFrame: frame,
        encounter: NativeHollowManifestCommission.encounter), declarations.designs.count == 2
    else { return false }
    for (reference, design) in declarations.designs {
      guard let bytes = try? ScriptPackLibrary.canonicalGeometry(design) else { return false }
      let hash = ScriptPackLibrary.hash(bytes)
      guard commander.scriptState.geometry[hash] == design else { return false }
      for actor in owned.actors.values {
        guard actor.body.scriptNPC?.fit.models[reference] == hash else { return false }
      }
    }
    if state.wakeTrail != nil {
      guard let wakes = instance.ownedEncounters[NativeC03WakeTrail.encounter] else { return false }
      for mark in NativeC03WakeGeometry.Mark.allCases {
        guard let hash = try? NativeC03WakeGeometry.geometryHash(mark),
          commander.scriptState.geometry[hash] == NativeC03WakeGeometry.design(mark),
          wakes.actors[mark.rawValue]?.body.scriptNPC?.fit.models == [mark.model: hash]
        else { return false }
      }
    }
    if let register = state.custodyRegister {
      guard let owned = instance.ownedEncounters[NativeC03RegisterState.encounter],
        let actor = owned.actors[NativeC03CustodyRegisterContent.target],
        let current = register.latest,
        commander.scriptState.geometry[current.rootGeometry] == NativeC03RegisterGeometry.rootDesign,
        commander.scriptState.geometry[current.faceGeometry] == NativeC03RegisterGeometry.faceDesign,
        actor.body.scriptNPC?.fit.models == [
          NativeC03RegisterGeometry.rootModel: current.rootGeometry,
          NativeC03RegisterGeometry.faceModel: current.faceGeometry,
        ]
      else { return false }
    }
    return true
  }

  static func validateFields(_ data: Data, part: ScriptFreightVersionedSave.Part)
    throws
  {
    // Slice and bound raw leaves BEFORE allocating the enclosing Foundation object. Keys are
    // decoded (including escapes), so a disguised native key cannot bypass this boundary.
    let leaves = try publicationLeaves(data)
    guard leaves.isEmpty || part == .missions else {
      throw SaveError.invalidCommander
    }
    struct Header: Decodable {
      struct Birth: Decodable {
        struct Input: Decodable {
          let owner: UUID
          let mission: UUID
        }
        let input: Input
      }
      let birth: Birth
    }
    var states: [UUID: NativeHollowManifestState] = [:]
    for leaf in leaves {
      _ = try boundedBirthSlice(leaf)
      let header = try JSONDecoder().decode(Header.self, from: leaf).birth.input
      guard states[header.mission] == nil else { throw SaveError.invalidCommander }
      states[header.mission] = try decodePublication(
        leaf, owner: header.owner, mission: header.mission)
    }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    for (key, value) in root where key != "instances" { try rejectMisplaced(value, key: key) }
    let instances = try publicationInstances(root["instances"])
    var seen: Set<UUID> = []
    for instance in instances {
      for (key, value) in instance where key != field { try rejectMisplaced(value, key: key) }
      let named = instance["definition"] as? String == NativeHollowManifestCommission.stateID
      let pinned = instance["digest"] as? String == NativeHollowManifestCommission.digest
      let claimed = instance.keys.contains(field)
      guard named == pinned, named == claimed else { throw SaveError.invalidCommander }
      guard named else { continue }
      guard part == .missions,
        let idText = instance["id"] as? String, let id = UUID(uuidString: idText),
        instance["definition"] as? String == NativeHollowManifestCommission.stateID,
        instance["version"] as? String == NativeHollowManifestCommission.version,
        instance["digest"] as? String == NativeHollowManifestCommission.digest,
        instance[field] is [String: Any], states[id] != nil, seen.insert(id).inserted
      else { throw SaveError.invalidCommander }
    }
    guard seen.count == states.count, seen.count <= 1
    else { throw SaveError.invalidCommander }
  }

  private static func publicationInstances(_ value: Any?) throws -> [[String: Any]] {
    guard let value else { return [] }
    let entries: [Any]
    if let dictionary = value as? [String: Any], dictionary.count <= 128 {
      entries = Array(dictionary.values)
    } else if let array = value as? [Any], array.count <= 256, array.count.isMultiple(of: 2) {
      entries = stride(from: 1, to: array.count, by: 2).map { array[$0] }
    } else {
      throw SaveError.invalidCommander
    }
    guard entries.allSatisfy({ $0 is [String: Any] }) else { throw SaveError.invalidCommander }
    return entries.compactMap { $0 as? [String: Any] }
  }

  private static func rejectMisplaced(_ value: Any, key: String? = nil, depth: Int = 0) throws {
    guard depth <= 96, key != field else { throw SaveError.invalidCommander }
    if let object = value as? [String: Any] {
      for (name, child) in object { try rejectMisplaced(child, key: name, depth: depth + 1) }
    } else if let array = value as? [Any] {
      for child in array { try rejectMisplaced(child, depth: depth + 1) }
    }
  }

  /// C03-specific raw field slicer; the existing global preflight and Foundation own JSON grammar.
  private static func publicationLeaves(_ data: Data) throws -> [Data] {
    try ScriptSaveJSONPreflight.validate(data)
    var leaves: [Data] = []
    var index = 0
    func whitespace(_ byte: UInt8) -> Bool { [9, 10, 13, 32].contains(byte) }
    while index < data.count {
      guard data[index] == 34 else {
        index += 1
        continue
      }
      let start = index
      index += 1
      var escaped = false
      while index < data.count {
        let byte = data[index]
        index += 1
        if escaped {
          escaped = false
        } else if byte == 92 {
          escaped = true
        } else if byte == 34 {
          break
        }
      }
      let end = index
      while index < data.count, whitespace(data[index]) { index += 1 }
      guard index < data.count, data[index] == 58 else { continue }
      let key = try JSONDecoder().decode(String.self, from: Data(data[start..<end]))
      guard key == field else { continue }
      index += 1
      while index < data.count, whitespace(data[index]) { index += 1 }
      guard index < data.count, data[index] == 123, leaves.count < 128 else {
        throw SaveError.invalidCommander
      }
      let leafStart = index
      var depth = 0
      var quoted = false
      escaped = false
      repeat {
        guard index < data.count, index - leafStart < maximumBytes else {
          throw Failure.resourceLimit
        }
        let byte = data[index]
        index += 1
        if quoted {
          if escaped {
            escaped = false
          } else if byte == 92 {
            escaped = true
          } else if byte == 34 {
            quoted = false
          }
        } else if byte == 34 {
          quoted = true
        } else if byte == 123 || byte == 91 {
          depth += 1
        } else if byte == 125 || byte == 93 {
          depth -= 1
        }
      } while depth > 0
      leaves.append(Data(data[leafStart..<index]))
    }
    return leaves
  }
}
