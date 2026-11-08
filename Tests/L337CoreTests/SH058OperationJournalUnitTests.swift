import Foundation
import Testing

@MainActor
struct SH058OperationJournalUnitTests {
  private final class Storage: SH058OperationJournalStorage {
    enum Failure: Error { case injected }
    var committed: Data?
    var writes: [Data] = []
    var failNext = false
    func replace(with bytes: Data) throws {
      if failNext { failNext = false; throw Failure.injected }
      committed = bytes
      writes.append(bytes)
    }
  }

  private func record(_ bytes: Data?) throws -> [String: Any] {
    let value = try #require(bytes)
    let object = try JSONSerialization.jsonObject(with: value)
    return try #require(object as? [String: Any])
  }

  @Test func formalSourceRecordsPreflightAndOrdinaryBoundariesBeforeWork() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent()
    let text = try String(contentsOf: root.appendingPathComponent(
      "Tools/qualification/sh058/SH058SuccessorFormalQualificationTests.swift"), encoding: .utf8)
    let entry = try #require(text.range(of: "    try checkpoint()"))
    let inputRead = try #require(text.range(of: "    let inputFile = try FileHandle"))
    #expect(entry.upperBound < inputRead.lowerBound)
    let boundaries = [
      ("preflight-showroom-model", "let current = try OriginalFleetShowroomModels.model"),
      ("collision-query-intent", "let origin = try vector(witness.ray.origin)"),
      ("Display.draw", "Display.draw(carrier"),
      ("imageForFrame", "let result = imageForFrame"),
      ("PNG-encoding", "let destination = try #require(CGImageDestinationCreateWithData"),
      ("PNG-file-write", "try (data as Data).write"),
      ("formal-receipt-write", "let receipt = try JSONSerialization.data"),
    ]
    for (stage, operation) in boundaries {
      let marker = try #require(text.range(of: "activeStage = \"" + stage + "\""))
      let call = try #require(text.range(of: operation, range: marker.upperBound..<text.endIndex))
      #expect(text[marker.upperBound..<call.lowerBound].contains("try checkpoint()"))
    }
    let loopStart = try #require(text.range(of: "      for faceIndex in witness.faceIDs {"))
    let loopEnd = try #require(text.range(of: "      queriesCompleted += 1", range: loopStart.upperBound..<text.endIndex))
    let kernelLoop = text[loopStart.upperBound..<loopEnd.lowerBound]
    #expect(!kernelLoop.contains("try checkpoint()"))
    #expect(kernelLoop.contains("primitiveCalls += 1") && kernelLoop.contains("triangleCallsCompleted += 1"))
    #expect(!text.contains("try bytes.write(to: output.appendingPathComponent(\"last-operation.json\")"))
  }

  @Test func boundariesRetainIntentAndCompletedStateInOrder() throws {
    let storage = Storage()
    let owned = SH058OperationJournal(storage: storage)
    var returnedQueries = 0, returnedTriangles = 0
    try owned.checkpoint(["stage": "formal-entry", "completedSUTQueries": returnedQueries])
    try owned.checkpoint(["stage": "collision-query-intent", "operation": "Q1",
      "currentQueryIntent": true, "triangleProgress": "CURRENT_QUERY_UNKNOWN_COUNTERS_ARE_COMPLETED_QUERY_PREFIX",
      "completedSUTQueries": returnedQueries, "completedSUTTriangleCalls": returnedTriangles])
    let before = try #require((try record(storage.committed))["state"] as? [String: Any])
    #expect(before["completedSUTQueries"] as? Int == 0 && before["currentQueryIntent"] as? Bool == true)
    // Simulated kernel returns stay in memory until the query returns: no per-triangle writes.
    for _ in 0..<3 { returnedTriangles += 1 }
    #expect(storage.writes.count == 2)
    let interrupted = try #require((try record(storage.committed))["state"] as? [String: Any])
    #expect(interrupted["completedSUTTriangleCalls"] as? Int == 0)
    #expect(interrupted["triangleProgress"] as? String == "CURRENT_QUERY_UNKNOWN_COUNTERS_ARE_COMPLETED_QUERY_PREFIX")
    returnedQueries += 1
    try owned.checkpoint(["stage": "collision-result-comparison", "lastCompletedQueryID": "Q1",
      "currentQueryIntent": false, "triangleProgress": "COMPLETED_QUERY_PREFIX",
      "completedSUTQueries": returnedQueries, "completedSUTTriangleCalls": returnedTriangles])
    #expect(storage.writes.count == 3 && owned.sequence == 3)
    for (index, bytes) in storage.writes.enumerated() {
      #expect(try record(bytes)["sequence"] as? Int == index + 1)
    }
    let last = try #require((try record(storage.committed))["state"] as? [String: Any])
    #expect(last["completedSUTQueries"] as? Int == 1 && last["completedSUTTriangleCalls"] as? Int == 3)
    #expect(last["lastCompletedQueryID"] as? String == "Q1")
    #expect(owned.bytesWritten == storage.writes.reduce(0) { $0 + $1.count })
  }

  @Test func atomicFailureKeepsPreviousRecordAndRefusesNextBoundary() throws {
    let storage = Storage()
    let owned = SH058OperationJournal(storage: storage)
    try owned.checkpoint(["stage": "preflight"])
    let original = storage.committed
    storage.failNext = true
    var simulatedCalls = 0
    #expect(throws: Storage.Failure.self) {
      try owned.checkpoint(["stage": "Display.draw", "drawAttempts": 1, "drawsCompleted": 0])
      simulatedCalls += 1
    }
    #expect(storage.committed == original && storage.writes.count == 1)
    #expect(owned.sequence == 1 && owned.stopped && simulatedCalls == 0)
    #expect(throws: SH058OperationJournal.Failure.self) { try owned.checkpoint(["stage": "imageForFrame"]) }
    #expect(storage.writes.count == 1)
  }

  @Test func recordAndCumulativeBoundsFailBeforePublication() throws {
    let largeStorage = Storage()
    let recordBound = SH058OperationJournal(storage: largeStorage)
    #expect(throws: SH058OperationJournal.Failure.self) {
      try recordBound.checkpoint(["stage": String(repeating: "x", count: SH058OperationJournal.recordLimit)])
    }
    #expect(largeStorage.writes.isEmpty && recordBound.stopped)
    let storage = Storage(), bounded = SH058OperationJournal(storage: storage)
    let payload = ["stage": String(repeating: "b", count: 15_000)]
    var refused = false
    // At most 1,200 small fake records; no scientific kernel or renderer involved.
    for _ in 0..<1_200 {
      do { try bounded.checkpoint(payload) }
      catch SH058OperationJournal.Failure.byteLimit { refused = true; break }
    }
    #expect(refused && bounded.stopped && bounded.bytesWritten <= SH058OperationJournal.byteLimit)
    #expect(storage.writes.allSatisfy { $0.count <= SH058OperationJournal.recordLimit })
    #expect(bounded.sequence == storage.writes.count)
  }

  @Test func fileReplacementKeepsOneCompleteRecordAndRefusesReuse() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let output = root.appendingPathComponent("formal", isDirectory: true)
    let storage = try SH058FileOperationJournalStorage(freshDirectory: output.path, sourceRoot: root.appendingPathComponent("source").path)
    let journal = SH058OperationJournal(storage: storage)
    try journal.checkpoint(["stage": "formal-entry", "completed": 0])
    let file = storage.directory.appendingPathComponent("last-operation.json")
    let first = try Data(contentsOf: file)
    try journal.checkpoint(["stage": "preflight-input-validated", "completed": 0])
    let second = try Data(contentsOf: file)
    let secondRecord = try record(second)
    #expect(first != second && secondRecord["sequence"] as? Int == 2)
    #expect(try FileManager.default.contentsOfDirectory(atPath: storage.directory.path) == ["last-operation.json"])
    #expect(throws: SH058FileOperationJournalStorage.Failure.self) {
      _ = try SH058FileOperationJournalStorage(freshDirectory: output.path, sourceRoot: root.appendingPathComponent("source").path)
    }
    #expect(try Data(contentsOf: file) == second)
    // An occupied fixed staging path makes publication fail before replacing the good record.
    try Data("occupied".utf8).write(to: storage.directory.appendingPathComponent(".last-operation.pending"))
    #expect(throws: (any Error).self) { try journal.checkpoint(["stage": "Display.draw"]) }
    #expect(try Data(contentsOf: file) == second)
    #expect(journal.sequence == 2 && journal.stopped)
    #expect(throws: SH058FileOperationJournalStorage.Failure.self) {
      _ = try SH058FileOperationJournalStorage(freshDirectory: root.appendingPathComponent("source/nested").path,
        sourceRoot: root.appendingPathComponent("source").path)
    }
  }
}
