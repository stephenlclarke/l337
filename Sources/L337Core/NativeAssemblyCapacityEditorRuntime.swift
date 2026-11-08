import Foundation

extension GameRuntime {
  /// Native menu and keyboard share this actor ingress. No editor keystroke calls Game.key.
  func handleAssemblyCapacityEditorKey(_ raw: String) -> Bool {
    let hadEditor = assemblyCapacityEditor != nil || game.nativeAssemblyCapacityEditorDisplay != nil
    synchronizeAssemblyCapacityEditor()
    let key = raw.lowercased()
    // An invalidated editor's queued key must never fall through to ordinary Inventory.
    if hadEditor, assemblyCapacityEditor == nil, key != MissionUIAction.assemblyCapacityConsole.rawValue {
      return true
    }
    if key == MissionUIAction.assemblyCapacityConsole.rawValue {
      guard game.canOpenAssemblyCapacityEditor else { return true }
      do {
        let context = try game.assemblyCapacityContext()
        assemblyCapacityEditor = try .init(game: game, context: context)
        game.screen = .inventory
        controls = Controls()
        invalidateInventoryContext()
        refreshAssemblyCapacityEditorProjection()
      } catch { game.notify("ORIGINAL ASSEMBLY CONSOLE UNAVAILABLE") }
      return true
    }
    guard var editor = assemblyCapacityEditor else { return false }
    if key == "pause" { return false }
    if MissionUIAction(rawValue: key) != nil {
      closeAssemblyCapacityEditor()
      return false
    }
    if key == "escape" {
      if editor.confirmation != nil {
        editor.confirmation = nil
        editor.confirms = false
      } else {
        closeAssemblyCapacityEditor()
        return true
      }
    } else if key == "return", editor.confirmation == nil, editor.selection == 8 {
      closeAssemblyCapacityEditor()
      return true
    } else if !editor.context.isCurrent(in: game) {
      editor.message = "The console changed. Use Back and reopen it."
    } else {
      do { try editAssemblyCapacityConsole(key, editor: &editor) }
      catch { editor.message = "Save failed. Your changes are still unsaved; retry or use Back." }
    }
    editor.nonce = UUID()
    assemblyCapacityEditor = editor
    refreshAssemblyCapacityEditorProjection()
    return true
  }

  private func editAssemblyCapacityConsole(_ key: String,
    editor: inout NativeAssemblyCapacityEditorSession) throws
  {
    if let operation = editor.confirmation {
      if key == "left" || key == "right" { editor.confirms.toggle() }
      else if key == "return" {
        guard editor.confirms else { editor.confirmation = nil; return }
        switch operation {
        case .save: _ = try saveAssemblyCapacityDraft(editor.draft, context: editor.context)
        case .clear: _ = try clearAssemblyCapacityDraft(editor.side, context: editor.context)
        }
        editor.context = try game.assemblyCapacityContext()
        editor.draft = try NativeAssemblyCapacityEditorSession.initialDraft(in: game,
          context: editor.context, side: editor.side)
        editor.dirty = false
        editor.confirmation = nil
        editor.confirms = false
        editor.message = operation == .save ? "Player proposal saved. No crews dispatched." : "Player proposal cleared."
      }
      return
    }
    switch key {
    case "up": editor.selection = (editor.selection + 8) % 9
    case "down": editor.selection = (editor.selection + 1) % 9
    case "left", "right":
      if editor.selection == 0 { try editor.chooseSide(in: game) }
      else if (1...5).contains(editor.selection) {
        try editor.editProposal(editor.selection - 1, direction: key == "left" ? -1 : 1)
      }
    case "return":
      if editor.selection == 0 { try editor.chooseSide(in: game) }
      else if editor.selection == 6 || editor.selection == 7 {
        editor.confirmation = editor.selection == 6 ? .save : .clear
        editor.confirms = false
        editor.message = ""
      }
    default: break
    }
  }

  private func closeAssemblyCapacityEditor() {
    if let editor = assemblyCapacityEditor, game.screen == .inventory {
      game.screen = editor.returnScreen
    }
    assemblyCapacityEditor = nil
    game.nativeAssemblyCapacityEditorDisplay = nil
    controls = Controls()
    invalidateInventoryContext()
  }

  /// A successful load/new-visit epoch or a replaced screen discards transient input.
  /// Case/fit changes in the same epoch retain edits but leave the captured context stale.
  private func synchronizeAssemblyCapacityEditor() {
    guard let editor = assemblyCapacityEditor else {
      if game.nativeAssemblyCapacityEditorDisplay != nil { game.nativeAssemblyCapacityEditorDisplay = nil }
      return
    }
    if editor.epoch != game.nativeStationRuntimeEpoch || game.screen != .inventory {
      assemblyCapacityEditor = nil
      game.nativeAssemblyCapacityEditorDisplay = nil
    }
  }

  func refreshAssemblyCapacityEditorProjection() {
    synchronizeAssemblyCapacityEditor()
    guard let editor = assemblyCapacityEditor,
      game.nativeAssemblyCapacityEditorDisplay?.nonce != editor.nonce
    else { return }
    game.nativeAssemblyCapacityEditorDisplay = .init(editor)
  }
}
