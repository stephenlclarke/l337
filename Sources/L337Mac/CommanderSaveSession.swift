import Foundation

/// Main-actor preferences only; validated game loading remains in GameRuntime.
@MainActor
final class CommanderSaveSession {
  private let preferences: UserDefaults?
  let isolatedData: IsolatedApplicationData?
  let defaultURL: URL
  var activeURL: URL
  private var rememberedURL: URL?
  private let key = "lastCommanderSavePath"
  init(
    preferences: UserDefaults? = .standard,
    defaultURL: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
      ".xyzzy/l337/commander.json")
  ) {
    self.preferences = preferences
    isolatedData = nil
    self.defaultURL = defaultURL
    activeURL = preferences?.string(forKey: key).map { URL(fileURLWithPath: $0) } ?? defaultURL
  }
  init(isolatedData: IsolatedApplicationData) throws {
    self.isolatedData = isolatedData
    preferences = nil
    defaultURL = isolatedData.defaultSave
    let remembered = try isolatedData.rememberedSave()
    rememberedURL = remembered
    activeURL = remembered ?? defaultURL
  }
  var startupURL: URL? {
    if let rememberedURL { return rememberedURL }
    if preferences?.string(forKey: key) != nil { return activeURL }
    return FileManager.default.fileExists(atPath: defaultURL.path) ? defaultURL : nil
  }
  func newCommanderDestination(afterFailedRestore: Bool) -> URL {
    if !afterFailedRestore, startupURL == nil { return defaultURL }
    return defaultURL.deletingLastPathComponent()
      .appendingPathComponent("new-commander-" + UUID().uuidString, isDirectory: true)
      .appendingPathComponent("commander.json")
  }
  func checkedSave(_ url: URL) throws -> URL {
    try isolatedData?.checkedSave(url) ?? url
  }
  func recordSave(to url: URL) throws {
    didSave(to: url)
    if let isolatedData {
      try isolatedData.rememberSave(url)
      rememberedURL = url
    }
  }
  func didSave(to url: URL) {
    activeURL = url
    preferences?.set(url.path, forKey: key)
  }
}
