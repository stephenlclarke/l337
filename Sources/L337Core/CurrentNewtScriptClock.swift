import Foundation

/// Flags captured by GameRuntime before native preparation. This does not hold
/// a future clock value: only an actually attained prefix can project time.
struct CurrentNewtScriptClockProjection: Sendable {
  let scripted: Bool
  let flight: Bool
  let local: Bool
  let calendar: Bool
  let missionCalendar: Bool

  init?(game: borrowing Game, flight: Bool, local: Bool, calendar: Bool) {
    let scripted =
      !game.commander.scriptState.instances.isEmpty
      || !game.commander.contracts.boards.isEmpty
    guard game.requiresScriptDurability, !game.paused, scripted || calendar,
      flight || local || calendar
    else { return nil }
    self.scripted = scripted
    self.flight = flight
    self.local = local
    self.calendar = calendar
    missionCalendar = game.missionCalendarActive
  }

  @discardableResult
  func apply(attained delta: Double, to game: inout Game) -> Bool {
    guard delta.isFinite, delta > 0, delta <= 0.1 + 1e-9 else { return false }
    // A contact may have paused the game after this prefix was attained. Its
    // physical time stays real, so the original preparation flags still apply.
    game.projectScriptClockValues(
      delta: delta, scripted: scripted, flight: flight,
      local: local, calendar: calendar, missionCalendar: missionCalendar)
    return true
  }
}
