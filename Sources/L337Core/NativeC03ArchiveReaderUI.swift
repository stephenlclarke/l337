import Foundation

/// Actor-owned navigation of an already recovered original. Never encoded or saved.
struct NativeC03ArchiveReaderUI: Sendable {
  var reader: NativeC03RecoveredArchiveReader
  let previous: Screen
  let epoch: UUID
  var generation = UUID()
  var page: NativeC03RecoveredArchiveReader.Page
  var scroll = 0
  var suspended = false
}

/// Only immutable display data crosses into a Game snapshot or the main actor.
struct NativeC03ArchiveReaderDisplay: Equatable, Sendable {
  let generation: UUID
  let page: NativeC03RecoveredArchiveReader.Page
  let scroll: Int
}

extension Game {
  public var isC03ArchiveReaderVisible: Bool {
    screen == .library && c03ArchiveReaderDisplay != nil
  }

  var canOpenC03ArchiveReader: Bool {
    guard !isC03ArchiveReaderVisible, !acceptsTextInput, !showroom.trading,
      ![Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff, .showroom].contains(screen)
    else { return false }
    return (try? hollowManifestRecoveredArchiveReader()) != nil
  }

  /// A painted-input consistency token, never a physical observation or mission receipt.
  var c03ArchiveReaderPageDigest: String? {
    guard isC03ArchiveReaderVisible, let display = c03ArchiveReaderDisplay,
      viewportWidth.isFinite, viewportHeight.isFinite, viewportWidth > 0, viewportHeight > 0
    else { return nil }
    let fields = [
      "c03-register-reader-ui", display.generation.uuidString,
      display.page.register.uuidString, display.page.transfer.uuidString,
      String(display.page.section.rawValue), String(display.scroll),
      String(viewportWidth), String(viewportHeight), String(GameTypography.scale),
    ]
    return ScriptPackLibrary.hash(Data(fields.map { "\($0.utf8.count):\($0)" }.joined().utf8))
  }
}
