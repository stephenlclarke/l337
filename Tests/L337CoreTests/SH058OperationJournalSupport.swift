import Darwin
import Foundation

// Test evidence only. This has no game, geometry, renderer or process-observation access.
@MainActor
protocol SH058OperationJournalStorage {
  func replace(with bytes: Data) throws
}

@MainActor
final class SH058OperationJournal {
  enum Failure: Error { case recordLimit, byteLimit, stopped }
  static let recordLimit = 16_384
  static let byteLimit = 16_777_216
  private let storage: any SH058OperationJournalStorage
  private(set) var sequence = 0
  private(set) var bytesWritten = 0
  private(set) var stopped = false

  init(storage: any SH058OperationJournalStorage) { self.storage = storage }

  // A saved boundary is intent. Only explicit completed counters prove a return.
  func checkpoint(_ state: [String: Any]) throws {
    guard !stopped else { throw Failure.stopped }
    do {
      let record: [String: Any] = [
        "schema": "SH058_OPERATION_CHECKPOINT_V1", "sequence": sequence + 1,
        "semantics": "Before boundary; attempts are intent, completed counters are returns; no caller attribution",
        "state": state,
      ]
      let bytes = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
      guard bytes.count <= Self.recordLimit else { throw Failure.recordLimit }
      guard bytes.count <= Self.byteLimit - bytesWritten else { throw Failure.byteLimit }
      try storage.replace(with: bytes)
      sequence += 1
      bytesWritten += bytes.count
    } catch {
      // Never continue scientific work with a silently missing checkpoint.
      stopped = true
      throw error
    }
  }
}

@MainActor
final class SH058FileOperationJournalStorage: SH058OperationJournalStorage {
  enum Failure: Error { case unsafeOutput, renameFailed(Int32) }
  let directory: URL
  private let destination: URL
  private let staging: URL

  init(freshDirectory path: String, sourceRoot: String) throws {
    let output = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    let root = URL(fileURLWithPath: sourceRoot, isDirectory: true).resolvingSymlinksInPath().path
    let resolved = output.resolvingSymlinksInPath().path
    guard path.hasPrefix("/"), output.path == path,
      resolved != root, !resolved.hasPrefix(root + "/"), !root.hasPrefix(resolved + "/"),
      !FileManager.default.fileExists(atPath: output.path)
    else { throw Failure.unsafeOutput }
    // The executor owns the fresh parent. Resolving it also rejects a dangling leaf symlink.
    let parent = output.deletingLastPathComponent().resolvingSymlinksInPath()
    let canonical = parent.appendingPathComponent(output.lastPathComponent, isDirectory: true)
    if (try? FileManager.default.attributesOfItem(atPath: canonical.path)) != nil {
      throw Failure.unsafeOutput
    }
    try FileManager.default.createDirectory(at: canonical, withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700])
    directory = canonical
    destination = canonical.appendingPathComponent("last-operation.json")
    staging = canonical.appendingPathComponent(".last-operation.pending")
  }

  func replace(with bytes: Data) throws {
    // One fixed staging file; sync complete bytes before publishing the atomic rename.
    // This survives process death. It makes no hardware/power-loss durability claim.
    try bytes.write(to: staging, options: .withoutOverwriting)
    do {
      let handle = try FileHandle(forWritingTo: staging)
      do { try handle.synchronize(); try handle.close() }
      catch { try? handle.close(); throw error }
      let result = staging.path.withCString { from in
        destination.path.withCString { to in Darwin.rename(from, to) }
      }
      guard result == 0 else { throw Failure.renameFailed(errno) }
    } catch {
      try? FileManager.default.removeItem(at: staging)
      throw error
    }
  }
}
