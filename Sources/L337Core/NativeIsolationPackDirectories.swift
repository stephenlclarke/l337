import Foundation

extension ScriptPackLibrary {
  static var bundledIsolationWorkParentDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-isolation-work")
  }

  static var bundledIsolationWorkDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent(
      "l337-isolation-work-source")
  }
}
