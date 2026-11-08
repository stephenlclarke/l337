import Darwin
import Foundation

/// A private, pre-existing directory used for the ordinary app's persistent data.
struct IsolatedApplicationData: Sendable {
  let directory: URL
  var defaultSave: URL { directory.appendingPathComponent("commander.json") }
  private var lastSave: URL { directory.appendingPathComponent(".last-commander") }

  static func parse(_ arguments: [String], liveDirectory: URL) throws -> Self? {
    guard !arguments.contains(where: { $0.hasPrefix("--data-directory=") }) else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let options = arguments.indices.filter { arguments[$0] == "--data-directory" }
    guard let option = options.first else { return nil }
    guard options.count == 1, arguments.indices.contains(option + 1),
      arguments[option + 1].hasPrefix("/")
    else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let supplied = URL(fileURLWithPath: arguments[option + 1]).standardizedFileURL
    let directory = supplied.deletingLastPathComponent().resolvingSymlinksInPath()
      .appendingPathComponent(supplied.lastPathComponent, isDirectory: true)
    let livePaths = [liveDirectory.standardizedFileURL, liveDirectory.resolvingSymlinksInPath()]
      .map(\.pathComponents)
    let requested = directory.pathComponents
    guard !livePaths.contains(where: { requested.starts(with: $0) || $0.starts(with: requested) })
    else { throw CocoaError(.fileReadNoPermission) }
    try checkPrivateDirectory(directory)
    return Self(directory: directory)
  }

  private static func checkPrivateDirectory(_ url: URL) throws {
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    guard url.resolvingSymlinksInPath().path == url.path,
      attributes[.type] as? FileAttributeType == .typeDirectory,
      (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == geteuid(),
      let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue,
      permissions & 0o077 == 0
    else {
      throw CocoaError(.fileReadNoPermission)
    }
  }

  func checked(_ url: URL) throws -> URL {
    let candidate = url.standardizedFileURL
    let base = directory.pathComponents
    let components = candidate.pathComponents
    guard candidate.isFileURL, components.starts(with: base), components.count > base.count else {
      throw CocoaError(.fileReadNoPermission)
    }
    try Self.checkPrivateDirectory(directory)
    var current = directory
    for component in components.dropFirst(base.count) {
      current.appendPathComponent(component)
      do {
        let attributes = try FileManager.default.attributesOfItem(atPath: current.path)
        let type = attributes[.type] as? FileAttributeType
        guard type == .typeDirectory
          || (current.path == candidate.path && type == .typeRegular
            && (attributes[.referenceCount] as? NSNumber)?.intValue == 1)
        else {
          throw CocoaError(.fileReadNoPermission)
        }
      } catch let error as CocoaError where error.code == .fileReadNoSuchFile
        || error.code == .fileNoSuchFile
      {
        // A normal first launch and Save As may create their destination.
        break
      }
    }
    return candidate
  }

  func checkedTree(_ url: URL) throws -> URL {
    let accepted = try checked(url)
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: accepted.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    {
      for child in try FileManager.default.contentsOfDirectory(
        at: accepted, includingPropertiesForKeys: nil)
      {
        _ = try checkedTree(child)
      }
    }
    return accepted
  }

  func checkedSave(_ url: URL) throws -> URL {
    let accepted = try checked(url)
    guard accepted.pathExtension == "json" else { throw CocoaError(.fileReadInvalidFileName) }
    _ = try checkedTree(accepted.appendingPathExtension("missions"))
    return accepted
  }

  func packDirectories() throws -> (legacy: URL, script: URL) {
    let legacy = try checkedTree(directory.appendingPathComponent("mission-packs"))
    let script = try checkedTree(directory.appendingPathComponent("script-packs"))
    return (legacy, script)
  }

  func rememberedSave() throws -> URL? {
    let pointer = try checked(lastSave)
    guard FileManager.default.fileExists(atPath: pointer.path) else { return nil }
    let handle = try FileHandle(forReadingFrom: pointer)
    defer { try? handle.close() }
    guard let data = try handle.read(upToCount: 4097), data.count <= 4096,
      let path = String(data: data, encoding: .utf8), !path.isEmpty, !path.hasPrefix("/")
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    return try checkedSave(directory.appendingPathComponent(path))
  }

  func rememberSave(_ url: URL) throws {
    let accepted = try checked(url)
    let relativePath = accepted.pathComponents.dropFirst(directory.pathComponents.count)
      .joined(separator: "/")
    try Data(relativePath.utf8).write(to: checked(lastSave), options: .atomic)
  }
}
