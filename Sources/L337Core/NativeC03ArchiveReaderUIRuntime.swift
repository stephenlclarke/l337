import Foundation

extension GameRuntime {
  /// Called only after the existing typed menu intent has passed its currentness check.
  func handleC03ArchiveReaderUI(_ intent: MissionUIIntent) -> Bool {
    guard intent.action == .reviewRecoveredRegister else { return false }
    guard intent.isCurrent(in: game) else { return true }
    let previous = game.screen
    if previous != .library {
      // Retain ordinary work-stop, native admission, publication and writer rollback.
      key(MissionUIAction.library.rawValue)
      guard game.screen == .library else { return true }
    }
    do {
      let reader = try game.hollowManifestRecoveredArchiveReader()
      let page = try reader.page(in: game)
      c03ArchiveReaderUI = .init(reader: reader, previous: previous,
        epoch: game.nativeStationRuntimeEpoch, page: page)
      controls = Controls()
      invalidateInventoryContext()
      refreshC03ArchiveReaderProjection()
    } catch {
      resetC03ArchiveReaderUI()
      game.notify("RECOVERED REGISTER UNAVAILABLE - CHECK ORIGINAL KIT")
    }
    return true
  }

  /// Raw commands cannot move a visible page that was never painted to the player.
  func rejectUnprovedC03ArchiveReaderKey(_ key: String) -> Bool {
    guard game.screen == .library, c03ArchiveReaderUI != nil,
      Self.c03ArchiveReaderKeys.contains(key) || key == "i"
    else { return false }
    game.notify("USE THE CURRENT RECOVERED REGISTER PAGE")
    return true
  }

  static let c03ArchiveReaderKeys: Set<String> = [
    "left", "right", "up", "down", "pageup", "pagedown", "return", "tab", "escape", "k",
  ]

  /// Existing ScriptPageInput has already checked the exact painted page and viewport.
  func c03ArchiveReaderKey(_ key: String) {
    guard var session = currentC03ArchiveReaderSession() else { return }
    do {
      switch key {
      case "escape":
        c03ArchiveReaderUI = nil
        game.c03ArchiveReaderDisplay = nil
        game.screen = session.previous
        controls = Controls()
        invalidateInventoryContext()
        return
      case "k":
        session.generation = UUID()
        session.suspended = true
        c03ArchiveReaderUI = session
        game.c03ArchiveReaderDisplay = nil
        game.toggleHelp()
        controls = Controls()
        invalidateInventoryContext()
        return
      case "left", "right", "return", "tab":
        let oldSection = session.page.section
        session.page = try session.reader.move(key == "left" ? .previous : .next, in: game)
        if session.page.section != oldSection {
          session.scroll = 0
          session.generation = UUID()
        }
      case "up", "down", "pageup", "pagedown":
        let layout = NativeC03ArchiveReaderLayout(page: session.page,
          width: game.viewportWidth, height: game.viewportHeight, offset: session.scroll)
        let amount = (key == "up" || key == "pageup" ? -1 : 1)
          * (key.hasPrefix("page") ? 8 : 1)
        let scroll = layout.window.moved(amount)
        if scroll != session.scroll {
          session.scroll = scroll
          session.generation = UUID()
        }
      default: return
      }
      c03ArchiveReaderUI = session
      refreshC03ArchiveReaderProjection()
    } catch {
      resetC03ArchiveReaderUI()
      game.notify("RECOVERED REGISTER CHANGED - REOPEN FROM ORIGINAL KIT")
    }
  }

  func c03ArchiveReaderClick(x: Double, y: Double) {
    guard let session = currentC03ArchiveReaderSession() else { return }
    let layout = NativeC03ArchiveReaderLayout(page: session.page,
      width: game.viewportWidth, height: game.viewportHeight, offset: session.scroll)
    guard let key = layout.key(at: .init(x, y)) else { return }
    c03ArchiveReaderKey(key)
  }

  func refreshC03ArchiveReaderProjection() {
    guard var session = c03ArchiveReaderUI else {
      game.c03ArchiveReaderDisplay = nil
      return
    }
    guard session.epoch == game.nativeStationRuntimeEpoch else {
      resetC03ArchiveReaderUI()
      return
    }
    if game.screen == .help, game.helpReturn == .library {
      if !session.suspended { session.generation = UUID() }
      session.suspended = true
      c03ArchiveReaderUI = session
      game.c03ArchiveReaderDisplay = nil
      return
    }
    guard game.screen == .library else {
      resetC03ArchiveReaderUI()
      return
    }
    do {
      session.page = try session.reader.page(in: game)
      let layout = NativeC03ArchiveReaderLayout(page: session.page,
        width: game.viewportWidth, height: game.viewportHeight, offset: session.scroll)
      if session.scroll != layout.window.offset { session.generation = UUID() }
      session.scroll = layout.window.offset
      session.suspended = false
      c03ArchiveReaderUI = session
      game.c03ArchiveReaderDisplay = .init(generation: session.generation,
        page: session.page, scroll: session.scroll)
    } catch {
      resetC03ArchiveReaderUI()
      game.notify("RECOVERED REGISTER UNAVAILABLE - CHECK ORIGINAL KIT")
    }
  }

  /// A successful current load calls this after its throwing operation. Failed loads do not.
  func resetC03ArchiveReaderUI() {
    c03ArchiveReaderUI = nil
    game.c03ArchiveReaderDisplay = nil
  }

  private func currentC03ArchiveReaderSession() -> NativeC03ArchiveReaderUI? {
    guard game.screen == .library else { return nil }
    refreshC03ArchiveReaderProjection()
    return c03ArchiveReaderUI
  }
}
