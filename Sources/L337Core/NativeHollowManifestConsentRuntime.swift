import Foundation

/// Actor-owned review data only. Historical permission, current source life and instrument
/// capability remain separate. No constructed review or request is a captain reply.
struct NativeHollowManifestConsentReview: Sendable {
  enum Button: String, Sendable { case back, request }
  fileprivate let contact: NativeHollowManifestConsentContact
  let nonce: UUID
  let button: Button
  let issues: [String]
  var slot: NativeHollowManifestState.Slot { contact.life.original.slot }
  var bodyID: Int { contact.bodyID }
  var requestAvailable: Bool { issues.isEmpty && contact.targetingItem != nil }
  var historical: NativeHollowManifestState.Consent? {
    contact.life.pin.state.consents.first { $0.requestAdmission.slot == slot }
  }

  fileprivate init(
    contact: NativeHollowManifestConsentContact, nonce: UUID = UUID(),
    button: Button = .back, issues: [String]
  ) {
    self.contact = contact
    self.nonce = nonce
    self.button = button
    self.issues = issues
  }

  func selecting(_ button: Button) -> Self {
    .init(contact: contact, nonce: nonce, button: button, issues: issues)
  }
}

/// Only the real Game resolver below constructs this contact. It contains no caller-supplied
/// State, captain name, generic communications Boolean or fabricated equipment reference.
private final class NativeHollowManifestConsentContact: Sendable {
  let source: NativeHollowManifestConsentSource
  var life: NativeHollowManifestOriginalLife { source.life }
  var admission: NativeHollowManifestState.Admission { source.admission }
  let bodyID: Int
  let player: ActorIdentity
  let carrier: UUID
  let inventoryRevision: UInt64
  let targetingItem: UUID?

  init(
    source: NativeHollowManifestConsentSource,
    bodyID: Int, player: ActorIdentity, carrier: UUID, inventoryRevision: UInt64,
    targetingItem: UUID?
  ) {
    self.source = source
    self.bodyID = bodyID
    self.player = player
    self.carrier = carrier
    self.inventoryRevision = inventoryRevision
    self.targetingItem = targetingItem
  }
}

/// One bounded, read-only proposed fact. Only the actual contact resolver below can create it.
/// Keeping it outside scriptCommand avoids any Game beforeimage or flush on ordinary frames.
struct NativeHollowManifestConsentReplyPreparation {
  fileprivate let contact: NativeHollowManifestConsentContact
  fileprivate let state: NativeHollowManifestState
  fileprivate let body: SpaceBody
  fileprivate let flight: FlightSimulationState

}

enum NativeHollowManifestConsentFailure: Error {
  case unavailableContact, staleReview, requestUnavailable
}

extension Game {
  /// Source-specific contact review, never a scan or permission grant. A missing targeting-item
  /// reference is visible OPEN contract eligibility; it cannot create a new equipment policy.
  func makeHollowManifestConsentReview() throws -> NativeHollowManifestConsentReview {
    let contact = try currentHollowManifestConsentContact(reviewing: false)
    let pin = contact.life.pin
    var issues: [String] = []
    if !hollowManifestConsentWorkIsEligible(contact.source) {
      issues.append("This assignment is not currently accepting new inspection requests.")
    }
    if pin.state.consents.contains(where: { $0.requestAdmission.slot == contact.life.original.slot }
    ) {
      issues.append("A request has already been sent to this captain.")
    }
    if pin.state.firstCompromises.contains(where: {
      $0.admission.slot == contact.life.original.slot
    })
      || pin.state.withdrawals.contains(where: {
        $0.effect.admission.slot == contact.life.original.slot
      })
    {
      issues.append("This captain can no longer grant inspection permission.")
    }
    if contact.targetingItem == nil {
      issues.append("Your current equipment cannot send this request. You can return to flight.")
    }
    if pin.state.nextSourceSequence >= UInt64(Int64.max) - 1 {
      issues.append("The captain cannot accept another request. You can return to flight.")
    }
    return .init(contact: contact, issues: issues)
  }

  /// The explicit handoff Confirm owner may prepare a request ONLY. G2's pure State candidate
  /// and existing writer must subsequently commit it atomically; this function installs nothing.
  func prepareHollowManifestConsentRequest(_ review: NativeHollowManifestConsentReview) throws
    -> NativeHollowManifestSealConsentRequest
  {
    guard screen == .handoff, review.button == .request, review.requestAvailable,
      acceptsHollowManifestConsentSource(review.contact.source)
    else { throw NativeHollowManifestConsentFailure.requestUnavailable }
    let current = try currentHollowManifestConsentContact(reviewing: true)
    let old = review.contact
    guard current.admission == old.admission, current.bodyID == old.bodyID,
      current.player == old.player, current.carrier == old.carrier,
      current.inventoryRevision == old.inventoryRevision,
      current.targetingItem == old.targetingItem,
      current.life.pin.missionID == old.life.pin.missionID,
      current.life.original == old.life.original, let item = current.targetingItem,
      hollowManifestConsentWorkIsEligible(current.source),
      !current.life.pin.state.consents.contains(where: { $0.requestAdmission.slot == review.slot }),
      !current.life.pin.state.firstCompromises.contains(where: { $0.admission.slot == review.slot }
      ),
      !current.life.pin.state.withdrawals.contains(where: {
        $0.effect.admission.slot == review.slot
      }),
      current.life.pin.state.nextSourceSequence < UInt64(Int64.max) - 1
    else { throw NativeHollowManifestConsentFailure.staleReview }
    let sequence = current.life.pin.state.nextSourceSequence
    let request = NativeHollowManifestSealConsentRequest(
      operation: ScriptIdentity.uuid(
        "c03-seal-request-v1:\(current.life.pin.missionID):\(current.life.original.source):\(sequence)"
      ),
      binding: current.admission.original, purpose: .observeOriginalCargoSeal,
      player: current.player, playerHull: current.carrier, targetingEquipment: item,
      inventoryRevision: current.inventoryRevision, sequence: sequence,
      physicalTime: commander.flightSimulation.physicalTime)
    guard request.structurallyMatches(current.admission.original) else {
      throw NativeHollowManifestConsentFailure.staleReview
    }
    return request
  }

  private func currentHollowManifestConsentContact(reviewing: Bool) throws
    -> NativeHollowManifestConsentContact
  {
    guard !docked, !paused, !playerEMPDisabled, !isMissionTrial, trialTitle == nil,
      screen == (reviewing ? .handoff : .front),
      systemIdentity == NativeHollowManifestDefinition.freighterWorld,
      let targetID = informationTargetBody?.id ?? weaponsTargetID,
      bodies.filter({ $0.id == targetID }).count == 1,
      let body = bodies.first(where: { $0.id == targetID }),
      let player = commander.flightSimulation.player, let carrier = commander.hullInstanceID,
      let inventory = commander.equipmentInventory, inventory.activeHull == carrier
    else { throw NativeHollowManifestConsentFailure.unavailableContact }
    for slot in NativeHollowManifestState.Slot.allCases {
      guard let source = try? hollowManifestConsentSource(slot: slot),
        source.owned.presence == .present, source.owned.body.id == body.id,
        body.physical?.identity == source.admission.original.actor,
        body.missionInstanceID == source.life.pin.missionID,
        body.missionActorID == source.owned.identity,
        inventory.owner == source.life.pin.owner, acceptsHollowManifestConsentSource(source)
      else { continue }
      let item = commander.fittedEquipment(at: .targetingCore)
      let actualItem = item.flatMap { value -> UUID? in
        guard value.location?.hullInstanceID == carrier,
          TargetingTier.from(value.node.key) != nil,
          inventory.items.filter({ $0.id == value.id }).count == 1
        else { return nil }
        return value.id
      }
      return .init(
        source: source, bodyID: body.id, player: player,
        carrier: carrier, inventoryRevision: inventory.revision, targetingItem: actualItem)
    }
    throw NativeHollowManifestConsentFailure.unavailableContact
  }
}

extension Game {
  var hollowManifestConsentTarget: ActorIdentity? {
    let id = informationTargetBody?.id ?? weaponsTargetID
    return bodies.first { $0.id == id }?.physical?.identity
  }

  private mutating func installHollowManifestConsentState(
    _ state: NativeHollowManifestState, contact: NativeHollowManifestConsentContact,
    expectedBody: SpaceBody, flight: FlightSimulationState
  ) throws {
    let pin = contact.life.pin
    guard acceptsHollowManifestConsentSource(contact.source),
      commander.flightSimulation == flight,
      bodies.filter({ $0.id == expectedBody.id }).count == 1,
      bodies.first(where: { $0.id == expectedBody.id }) == expectedBody,
      let instance = commander.scriptState.instances[pin.missionID]
    else { throw NativeHollowManifestConsentFailure.staleReview }
    var candidate = instance
    candidate.savedHollowManifest = state
    commander.scriptState.instances[pin.missionID] = candidate
  }

  fileprivate mutating func retainHollowManifestConsentRequest() throws {
    guard let review = hollowManifestConsentReview else {
      throw NativeHollowManifestConsentFailure.staleReview
    }
    let request = try prepareHollowManifestConsentRequest(review)
    let contact = try currentHollowManifestConsentContact(reviewing: true)
    let body = try consentBody(contact)
    let flight = commander.flightSimulation
    let state = try contact.life.pin.state.retainingConsentRequest(
      request: request, admission: contact.admission.reference)
    try installHollowManifestConsentState(
      state, contact: contact, expectedBody: body, flight: flight)
    // Keep the historical request visible. A later flight contact is required for any reply.
    let refreshed = try currentHollowManifestConsentContact(reviewing: true)
    hollowManifestConsentReview = .init(
      contact: refreshed, issues: ["Request retained. Return to flight for the captain's reply."])
  }

  private func consentBody(_ contact: NativeHollowManifestConsentContact) throws -> SpaceBody {
    guard let body = bodies.first(where: { $0.id == contact.bodyID }),
      bodies.filter({ $0.id == contact.bodyID }).count == 1,
      body.physical?.identity == contact.admission.original.actor
    else { throw NativeHollowManifestConsentFailure.unavailableContact }
    return body
  }

  /// The source-native cooperative contact policy runs only on an attained positive flight
  /// step. No UI confirmation, elapsed unloaded time or silence can manufacture its reply.
  func prepareHollowManifestConsentReply(
    delta: Double, startTime: Double, startPlayer: ActorIdentity?
  ) throws -> NativeHollowManifestConsentReplyPreparation? {
    let flight = commander.flightSimulation
    guard delta.isFinite, delta > 0, startTime.isFinite,
      flight.physicalTime > startTime, flight.player == startPlayer,
      let contact = try? currentHollowManifestConsentContact(reviewing: false)
    else { return nil }
    let state = contact.life.pin.state
    let slot = contact.admission.reference.slot
    guard let consent = state.consents.first(where: { $0.requestAdmission.slot == slot }),
      consent.revocation == nil, flight.physicalTime > consent.request.physicalTime,
      state.nextSourceSequence < UInt64(Int64.max) - 1
    else { return nil }
    let decision: NativeHollowManifestSealConsentReply.Decision
    if let reply = consent.reply {
      guard reply.decision == .granted,
        state.withdrawals.contains(where: { $0.effect.admission.slot == slot })
          || state.firstCompromises.contains(where: { $0.admission.slot == slot })
      else { return nil }
      decision = .revoked
    } else {
      // The actual commander and case survive a genuine native visit rebind. This frame's
      // start/end player is bound above; the old request's visit address is historical only.
      guard hollowManifestConsentWorkIsEligible(contact.source),
        consent.request.binding.owner == contact.life.pin.owner,
        consent.request.binding.mission == contact.life.pin.missionID,
        consent.request.binding.slot == contact.life.original.slot,
        consent.request.binding.source == contact.life.original.source,
        consent.request.binding.hull == contact.life.original.hull,
        consent.request.binding.captain == contact.life.original.captain,
        consent.request.binding.seal == contact.life.original.seal,
        consent.request.binding.master == contact.life.original.master,
        consent.request.binding.imprint == contact.life.original.imprint,
        consent.request.binding.component == contact.admission.original.component
      else { return nil }
      decision = .granted
    }
    let reply = NativeHollowManifestSealConsentReply(
      operation: ScriptIdentity.uuid(
        "c03-seal-reply-v1:\(contact.life.pin.missionID):\(contact.life.original.source):\(state.nextSourceSequence)"
      ),
      request: consent.request.operation, originalSource: contact.life.original.source,
      captain: contact.life.original.captain, seal: contact.life.original.seal,
      decision: decision, revision: decision == .revoked ? 2 : 1,
      previousReply: decision == .revoked ? consent.reply?.operation : nil,
      sequence: state.nextSourceSequence, physicalTime: flight.physicalTime)
    let candidate =
      decision == .revoked
      ? try state.retainingConsentRevocation(
        revocation: reply, admission: contact.admission.reference)
      : try state.retainingConsentReply(reply: reply, admission: contact.admission.reference)
    let body = try consentBody(contact)
    return .init(contact: contact, state: candidate, body: body, flight: flight)
  }

  mutating func installHollowManifestConsentReply(
    _ prepared: NativeHollowManifestConsentReplyPreparation
  ) throws {
    let current = try currentHollowManifestConsentContact(reviewing: false)
    guard current.admission == prepared.contact.admission,
      current.player == prepared.contact.player, current.bodyID == prepared.body.id,
      current.carrier == prepared.contact.carrier,
      current.inventoryRevision == prepared.contact.inventoryRevision,
      current.targetingItem == prepared.contact.targetingItem
    else { throw NativeHollowManifestConsentFailure.staleReview }
    try installHollowManifestConsentState(
      prepared.state, contact: prepared.contact, expectedBody: prepared.body,
      flight: prepared.flight)
  }
}

extension GameRuntime {
  func openHollowManifestConsentReview() {
    guard !controls.fire, let review = try? game.makeHollowManifestConsentReview() else { return }
    game.hollowManifestConsentReview = review
    game.screen = .handoff
    controls = Controls()
  }

  func handleHollowManifestConsentKey(_ key: String) -> Bool {
    guard game.screen == .handoff, let review = game.hollowManifestConsentReview else {
      return false
    }
    if key == "escape" || (key == "return" && review.button == .back) {
      game.hollowManifestConsentReview = nil
      game.screen = .front
    } else if ["left", "right", "up", "down"].contains(key) {
      game.hollowManifestConsentReview = review.selecting(
        review.button == .back && review.requestAvailable ? .request : .back)
    } else if key == "return" {
      guard scriptSaveURL != nil, galleryNamespace == nil, galleryParent == nil else {
        game.notify("SAVE YOUR COMMANDER BEFORE SENDING A REQUEST")
        return true
      }
      do {
        try scriptCommand { candidate in try candidate.retainHollowManifestConsentRequest() }
      } catch {
        game.notify("REQUEST NOT COMMITTED - REVIEW THE CURRENT CONTACT AND SAVE")
      }
    }
    return true
  }

  func receiveHollowManifestConsentAfterPhysics(
    delta: Double, startTime: Double, startPlayer: ActorIdentity?
  ) {
    guard scriptSaveURL != nil, galleryNamespace == nil, galleryParent == nil,
      let prepared = try? game.prepareHollowManifestConsentReply(
        delta: delta, startTime: startTime, startPlayer: startPlayer)
    else { return }
    do {
      // Snapshot begins AFTER native physics/capture/restore. Writer refusal rolls back only
      // this proposed consent history, preserving physical damage and current admissions.
      try scriptCommand { candidate in
        try candidate.installHollowManifestConsentReply(prepared)
      }
    } catch {
      game.notify("CAPTAIN REPLY NOT RETAINED - SAVE FAILED", voiced: false)
    }
  }
}

extension GameRuntime {
  func hollowManifestConsentClick(x: Double, y: Double) {
    guard game.screen == .handoff, let review = game.hollowManifestConsentReview,
      x >= 0, y >= 0, x <= game.viewportWidth, y <= game.viewportHeight
    else { return }
    let contentWidth = min(650, game.viewportWidth - 48)
    let left = (game.viewportWidth - contentWidth) / 2
    guard y >= game.viewportHeight - 52, y <= game.viewportHeight - 28,
      x >= left, x <= left + contentWidth
    else { return }
    let request = x < left + contentWidth / 2
    guard !request || review.requestAvailable else { return }
    game.hollowManifestConsentReview = review.selecting(request ? .request : .back)
    _ = handleHollowManifestConsentKey("return")
  }
}

extension Display {
  static func hollowManifestConsentHandoff(_ game: Game, width: Double, height: Double) -> Frame {
    guard let review = game.hollowManifestConsentReview else {
      return blackjackHandoff(game, width: width, height: height)
    }
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let font = GameTypography.scale
    let contentWidth = min(650, width - 48)
    let left = (width - contentWidth) / 2
    frame.label("ORIGINAL FREIGHTER CAPTAIN", left, 20, scale: font, ink: .yellow)
    frame.label(
      review.slot == .first ? "Freighter A" : "Freighter B",
      left, 48, scale: font, ink: .cyan)
    var paragraphs = [
      "Request permission to observe this original cargo seal.",
      "Confirm sends a request only. The captain can reply during later flight contact.",
      "Permission does not perform a scan or prove the seal's condition.",
    ]
    if let consent = review.historical {
      let status =
        consent.revocation?.decision.rawValue ?? consent.reply?.decision.rawValue
        ?? "awaiting reply"
      paragraphs.append("Retained captain history: \(status).")
    }
    paragraphs += review.issues
    let lines = paragraphs.flatMap {
      MissionNotice.wrap($0, width: max(10, Int(contentWidth / (6 * font))))
    }
    for (index, line) in lines.prefix(max(1, Int((height - 180) / 19))).enumerated() {
      frame.label(line, left, 80 + Double(index) * 19, scale: font)
    }
    if game.messageTime > 0 {
      frame.label(game.message, left, height - 82, scale: font, ink: .orange)
    }
    frame.label(
      (review.button == .request ? "> " : "  ")
        + (review.requestAvailable ? "Send request" : "Request unavailable"),
      left, height - 48, scale: font, ink: review.requestAvailable ? .cyan : .orange)
    frame.label(
      (review.button == .back ? "> " : "  ") + "Back",
      left + contentWidth / 2, height - 48, scale: font, ink: .cyan)
    frame.label("Arrows: choose  Return: confirm  Esc: back", left, height - 22, scale: font)
    return frame
  }
}
