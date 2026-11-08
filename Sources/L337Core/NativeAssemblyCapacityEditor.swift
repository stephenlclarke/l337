import Foundation

/// Actor-owned unsaved input. Model labels are not adopted people or surveyed requests.
struct NativeAssemblyCapacityEditorSession: Sendable {
  enum Operation: Sendable, Equatable { case save, clear }
  var context: NativeAssemblyCapacityContext
  let epoch: UUID
  let returnScreen: Screen
  var side: NativeAssemblyCapacityDraft.Side = .port
  var draft: NativeAssemblyCapacityDraft
  var selection = 0
  var confirmation: Operation?
  var confirms = false
  var dirty = false
  var message = ""
  var nonce = UUID()

  init(game: borrowing Game, context: NativeAssemblyCapacityContext) throws {
    self.context = context
    epoch = game.nativeStationRuntimeEpoch
    returnScreen = game.screen
    draft = try Self.initialDraft(in: game, context: context, side: .port)
  }

  static func initialDraft(in game: borrowing Game, context: NativeAssemblyCapacityContext,
    side: NativeAssemblyCapacityDraft.Side) throws -> NativeAssemblyCapacityDraft
  {
    if let stored = try game.savedAssemblyCapacityDraft(side, context: context) { return stored }
    return try emptyModel(mission: context.mission, side: side)
  }

  static func emptyModel(mission: UUID, side: NativeAssemblyCapacityDraft.Side) throws
    -> NativeAssemblyCapacityDraft
  {
    let register = NativeAssemblyCapacityRegisterCandidate(mission: mission,
      proposals: (0..<NativeAssemblyCapacityRules.proposals).map {
        ScriptIdentity.uuid("assembly-player-model:\(mission):proposal:\($0)")
      }, crews: (0..<NativeAssemblyCapacityRules.crews).map {
        ScriptIdentity.uuid("assembly-player-model:\(mission):team-label:\($0)")
      }, protectedSlot: NativeAssemblyCapacityRules.slots - 1)
    return try .init(register: register, side: side)
  }

  mutating func chooseSide(in game: borrowing Game) throws {
    guard !dirty else { message = "Save or use Back before changing sides."; return }
    side = side == .port ? .starboard : .port
    draft = try Self.initialDraft(in: game, context: context, side: side)
    message = ""
  }

  mutating func editProposal(_ index: Int, direction: Int) throws {
    let id = draft.register.proposals[index]
    let existing = draft.choices.first { $0.proposal == id }?.allocation
    let current: Int
    switch existing {
    case nil: current = 0
    case .some(.waiting): current = 1
    case .some(.working(let slot, let crew)):
      guard let label = draft.register.crews.firstIndex(of: crew) else {
        throw NativeAssemblyCapacityDraft.Failure.invalidDraft
      }
      current = 2 + slot * NativeAssemblyCapacityRules.crews + label
    }
    let count = 2 + NativeAssemblyCapacityRules.slots * NativeAssemblyCapacityRules.crews
    let next = (current + direction + count) % count
    if next == 0 { draft = try draft.removing(id) }
    else if next == 1 { draft = try draft.setting(.init(proposal: id, allocation: .waiting)) }
    else {
      let slot = (next - 2) / NativeAssemblyCapacityRules.crews
      let label = (next - 2) % NativeAssemblyCapacityRules.crews
      draft = try draft.setting(.init(proposal: id,
        allocation: .working(slot: slot, crew: draft.register.crews[label])))
    }
    dirty = true
    message = "Unsaved changes. Planning does not dispatch crews."
  }

  func allocationLabel(_ index: Int) -> String {
    let id = draft.register.proposals[index]
    guard let allocation = draft.choices.first(where: { $0.proposal == id })?.allocation else {
      return "Unsubmitted"
    }
    switch allocation {
    case .waiting: return "Waiting"
    case .working(let slot, let crew):
      let label = draft.register.crews.firstIndex(of: crew).map { String($0 + 1) } ?? "?"
      return "Slot \(slot + 1), team label \(label)"
    }
  }
}

/// Immutable presentation only. No controller, private source capability or live context escapes.
final class NativeAssemblyCapacityEditorDisplay: Sendable {
  let nonce: UUID
  let side: String
  let rows: [String]
  let selection: Int
  let protectedSlot: Int
  let confirmation: String?
  let confirms: Bool
  let feedback: [String]
  let message: String
  let dirty: Bool

  init(_ session: NativeAssemblyCapacityEditorSession) {
    nonce = session.nonce
    side = session.side.rawValue.uppercased()
    rows = ["Side: " + side]
      + (0..<NativeAssemblyCapacityRules.proposals).map {
        "Proposal \($0 + 1): " + session.allocationLabel($0)
      } + ["Save proposal", "Clear saved proposal", "Back"]
    selection = session.selection
    protectedSlot = session.draft.register.protectedSlot + 1
    confirmation = session.confirmation.map { $0 == .save ? "Save this player proposal?" : "Clear the saved proposal?" }
    confirms = session.confirms
    feedback = (try? session.draft.assess().feedback) ?? ["Proposal cannot currently be assessed."]
    message = session.message
    dirty = session.dirty
  }
}

extension Game {
  var canOpenAssemblyCapacityEditor: Bool {
    nativeAssemblyCapacityEditorDisplay == nil && !acceptsTextInput && !showroom.trading
      && ![Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff].contains(screen)
      && (try? assemblyCapacityContext()) != nil
  }
}
