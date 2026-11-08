import Foundation

public enum TargetingTier: Int, Sendable, Codable, CaseIterable, Comparable {
  case basic = 1
  case advanced, docking, identification, pirate, military
  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
  public var label: String {
    switch self {
    case .basic: "Basic"
    case .advanced: "Advanced"
    case .docking: "Docking"
    case .identification: "Identification"
    case .pirate: "Pirate"
    case .military: "Military"
    }
  }
  /// Independent targeting prices are tenths of a credit.
  public var price: Int { [8000, 20000, 40000, 60000, 100000, 120000][rawValue - 1] }
  public var technology: Int { [3, 4, 6, 8, 9, 10][rawValue - 1] }
  public var equipmentName: String { "Targeting: " + label }
  static func from(_ name: String) -> Self? { allCases.first { $0.equipmentName == name } }
}
extension Commander {
  public var targetingTier: TargetingTier? {
    fittedEquipment(at: .targetingCore).flatMap { TargetingTier.from($0.node.key) }
  }
  public var hasAutomaticDocking: Bool { targetingTier.map { $0 >= .docking } ?? false }
}
extension Hull {
  public var isTargetShip: Bool { ![Hull.station, .cargo, .asteroid, .missile].contains(self) }
  public var modelName: String {
    switch self {
    case .cobra, .viper, .sidewinder, .constrictor, .thargoid, .thargon:
      ShipCatalogue.nativeShip(self)?.name ?? "Unidentified craft"
    case .station: "Space station"
    case .cargo: "Cargo canister"
    case .asteroid: "Asteroid"
    case .missile: "Missile"
    }
  }
}

extension Display {
  /// Use the identical projection, hidden-face and clipping path as front-view rendering.
  static func visibleInFront(_ body: SpaceBody, game: borrowing Game, layout: CockpitLayout) -> Bool
  {
    // Front visibility uses the normal renderer without copying simulation state.
    let mesh: Mesh
    if let scripted = game.scriptNPCMesh(body) {
      mesh = scripted
    } else {
      mesh = game.gameplayMesh(for: body)
    }
    var frame = Frame()
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: layout.width, height: layout.height)
    frame.flightClip = layout.flightClip
    draw(
      body, game: game, into: &frame, projection: layout.projection, mesh: mesh, screen: .front)
    return !frame.shipLines.isEmpty || frame.hasShipSurfaces
  }
}

public struct TargetField: Sendable, Equatable {
  public let label: String
  public let value: String
  public var text: String { label + ": " + value }
}
public struct TargetInformation: Sendable, Equatable {
  public let id: Int
  public let model: String?
  public let status: String?
  public let fields: [TargetField]
  public var identifier: String { (model ?? "Target") + " #\(id)" }
}

extension Game {
  public var targetingEnabled: Bool {
    nativeStationAutoTargetingTier() != nil && (!nativeStationAutoXYZzyActive() || nativeStationAutoTargetFlag())
  }
  public var informationTargetBody: SpaceBody? {
    guard commander.targetingTier != nil else { return nil }
    if let target = autoTargetBody { return target }
    if let id = weaponsTargetID, let body = bodies.first(where: { $0.id == id && $0.energy > 0 }) {
      return body
    }
    return autoTargetBody
  }
  public var targetInformation: TargetInformation? {
    guard let body = informationTargetBody else { return nil }
    return information(for: body)
  }
  func information(for body: SpaceBody) -> TargetInformation? {
    guard let tier = commander.targetingTier else { return nil }
    guard body.hull != .station || tier >= .docking else { return nil }
    guard tier >= .identification else {
      return .init(id: body.id, model: nil, status: empTargetStatus(body), fields: [])
    }
    let shipStatus = body.hostile ? "Hostile" : "Neutral"
    let status: String
    if let electronic = empTargetStatus(body) {
      status = electronic
    } else if let work = workGuidance, let identity = body.physical?.identity,
      work.parent == identity
    {
      status = work.status
    } else {
      status = body.hull == .station ? autoPilot.status : shipStatus
    }
    var fields: [TargetField] = []
    if body.hull == .station {
      fields = [
        .init(label: "Entrance", value: autoPilot.ready ? "Ready" : "Aligning"),
        .init(
          label: "Rotation", value: String(format: "%.1f deg/s", body.rotationRate * 180 / .pi)),
        .init(label: "Range", value: String(format: "%.0f units", body.position.length)),
      ]
    } else {
      let facts = telemetryFacts(for: body)
      fields += TargetTelemetry.fields(
        facts: facts, tier: tier, targetIsShip: body.hull.isTargetShip,
        observerGalaxy: commander.galaxy, discloseLegal: true)
      if tier >= .military, body.hull.isTargetShip {
        // Ordinary catalogue hardware shares the same current source as its resource
        // readings. Distinct mission and untagged legacy owners retain their field policy.
        let ordinaryCatalogue = body.physical?.catalogueShipID != nil
          && body.physical?.npc?.role != .mission && body.scriptNPC == nil
          && body.missionInstanceID == nil && body.missionActorID == nil
          && !body.navalTarget && body.blackjackRole == nil
        let discloseHardware = !ordinaryCatalogue || (facts.resources != nil && body.missiles >= 0)
        fields += [
          .init(label: "Missiles", value: discloseHardware ? String(body.missiles) : "Unknown"),
          .init(label: "ECM equipped", value: discloseHardware ? (body.ecmEnabled ? "Yes" : "No") : "Unknown"),
          .init(
            label: "ECM active", value: discloseHardware
              ? (ecmFrames > 0 && enemyECMSource == body.id ? "Yes" : "No") : "Unknown"),
        ]
      }
    }
    if let context = gameplayContext(),
      let metadata = recoverableMetadata(for: body, context: context)
    {
      fields += [
        .init(label: "Type", value: metadata.category.rawValue),
        .init(label: "Custody", value: metadata.ownership.rawValue),
      ]
      if let work = workGuidance, work.parent == body.physical?.identity,
        let section = work.surface.section
      {
        fields.append(
          .init(
            label: "Section",
            value: salvageSectionIsDepleted(section) ? "Exhausted" : "Available"))
      }
    }
    let model: String
    if let npc = body.scriptNPC {
      if npc.fit.valid,
        npc.fit.models.values.allSatisfy({ commander.scriptState.geometry[$0] != nil })
      {
        model = npc.fit.definition.name
      } else {
        model = "Unidentified craft"
      }
    } else if body.isAegisPrototype, let name = AegisPrototype.source?.name {
      model = name
    } else {
      model = TargetTelemetry.modelName(
        catalogueShipID: body.physical?.catalogueShipID, missionName: body.blackjackRole?.name,
        fallbackHull: body.hull)
    }
    return .init(id: body.id, model: model, status: status, fields: fields)
  }
}
