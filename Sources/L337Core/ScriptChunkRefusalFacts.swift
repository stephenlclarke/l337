import Foundation

/// Failure-only, non-authoritative readings of bytes already supplied to the writer.
/// No complete JSON tree, chunk, Commander or callback is retained in the recorder.
enum ScriptChunkRefusalFacts {
  static let fields: Set<String> = [
    "savedHollowManifest", "savedNativePeopleCustody", "hollowManifestCrew",
    "secondNativeCommoditySale", "currentNewtKitStock",
    "currentNewtKitReceipt", "currentNewtKitConfiguration", "serviceCapturedAt",
    "savedBisonUnitAllocations", "bisonUnitJournalCheckpoint",
  ]

  struct Census {
    let counts: [String: Int]
    let placements: [String]
    let placementTotal: Int
    let complete: Bool
    let maximumDepth: Int
    let sampleOffset: Int?
  }

  private struct Frame {
    let object: Bool
    let path: String
    var key = ""
    var expectingKey = true
    var index = 0
  }

  /// One byte scan, O(depth) scratch and four bounded paths. This reads placement only;
  /// original validators alone decide JSON/claim validity and their errors are unchanged.
  static func census(_ data: Data, focus: Set<String> = fields) -> Census {
    data.withUnsafeBytes { storage in
      let bytes = storage.bindMemory(to: UInt8.self)
      var stack: [Frame] = []
      let keyDecoder = JSONDecoder()
      var counts: [String: Int] = [:]
      var placements: [String] = []
      var placementTotal = 0
      var maximumDepth = 0
      var complete = true
      var sampleOffset: Int?
      var i = 0
      func pathForValue() -> String {
        guard let last = stack.last else { return "$" }
        let part = last.object ? last.key : "[\(last.index)]"
        let path = last.path + "/" + part
        return path.count <= 96 ? path : String(path.prefix(88)) + "~pathcap"
      }
      while i < bytes.count {
        switch bytes[i] {
        case 123, 91:
          guard stack.count < 96 else {
            complete = false
            i = bytes.count
            continue
          }
          let path = pathForValue()
          stack.append(.init(object: bytes[i] == 123, path: path))
          maximumDepth = max(maximumDepth, stack.count)
        case 125, 93:
          if stack.isEmpty { complete = false } else { stack.removeLast() }
        case 44:
          if let last = stack.indices.last {
            if stack[last].object {
              stack[last].expectingKey = true
              stack[last].key = ""
            } else {
              stack[last].index += 1
            }
          }
        case 34:
          let start = i
          i += 1
          while i < bytes.count {
            if bytes[i] == 92 {
              i += 2
              continue
            }
            if bytes[i] == 34 { break }
            i += 1
          }
          guard i < bytes.count else {
            complete = false
            continue
          }
          if let last = stack.indices.last, stack[last].object, stack[last].expectingKey {
            let key: String
            if i - start <= 256,
              let decoded = try? keyDecoder.decode(
                String.self, from: Data(bytes[start...i]))
            {
              key = decoded
            } else {
              key = "~keycap"
              complete = false
            }
            stack[last].key = ascii(key, limit: 48)
            stack[last].expectingKey = false
            if fields.contains(key) {
              counts[key, default: 0] += 1
              if focus.contains(key) {
                placementTotal += 1
                if sampleOffset == nil { sampleOffset = start }
              }
              if focus.contains(key) && placements.count < 4 {
                var token = i + 1
                while token < bytes.count && [9, 10, 13, 32, 58].contains(bytes[token]) {
                  token += 1
                }
                placements.append(
                  key + "@\(start):path=" + pathForValue()
                    + ":token=\(token < bytes.count ? Int(bytes[token]) : -1)"
                )
              }
            }
          }
        default: break
        }
        i += 1
      }
      return .init(
        counts: counts, placements: placements, placementTotal: placementTotal,
        complete: complete && stack.isEmpty, maximumDepth: maximumDepth,
        sampleOffset: sampleOffset)
    }
  }

  private static func ascii(_ value: String, limit: Int) -> String {
    let bytes = value.utf8.prefix(limit).map { byte -> UInt8 in
      (33...126).contains(byte) && ![59, 91, 93].contains(byte) ? byte : 63
    }
    return String(decoding: bytes, as: UTF8.self) + (value.utf8.count > limit ? "~cap" : "")
  }

  static func render(
    name: String, outer: Int?, second: Int?, kit: Int?, data: Data?,
    commander: borrowing Commander, gate: ScriptRefusalStage = .storeChunks,
    publication: UUID? = nil
  ) -> String {
    let secondClaim = NativeSecondCommoditySaleSave.hasClaims(commander)
    let kitClaim = CurrentNewtKitSave.hasClaims(commander)
    let bisonClaim = commander.savedBisonUnitAllocations != nil
    let c03Claim = NativeHollowManifestSave.hasClaims(commander)
    let prefix =
      "chunk=\(ascii(name, limit: 48)),outer=\(outer?.description ?? "unreached")"
      + ",second=\(second?.description ?? "not-used"),kit=\(kit?.description ?? "not-used")"
      + ",typedSecond=\(secondClaim),typedKit=\(kitClaim),typedBison=\(bisonClaim)"
      + ",typedC03=\(c03Claim),publication=\(publication?.uuidString ?? "not-used")"
      + ",bytes=\(data?.count.description ?? "unavailable")"
    guard let data else { return prefix + ",raw=unavailable" }
    let focus: Set<String>
    switch gate {
    case .chunkC03, .chunkC03Match:
      focus = ["savedHollowManifest", "savedNativePeopleCustody", "hollowManifestCrew"]
    case .chunkCommodity: focus = ["secondNativeCommoditySale"]
    case .chunkNewt:
      focus = [
        "currentNewtKitStock", "currentNewtKitReceipt", "currentNewtKitConfiguration",
        "serviceCapturedAt", "savedBisonUnitAllocations", "bisonUnitJournalCheckpoint",
      ]
    case .chunkBison, .chunkPointerCheckpoint:
      focus = ["savedBisonUnitAllocations", "bisonUnitJournalCheckpoint"]
    default: focus = fields
    }
    let observed = census(data, focus: focus)
    let counts = fields.sorted().map { "\($0)=\(observed.counts[$0, default: 0])" }
      .joined(separator: ",")
    let base =
      prefix + ",rawComplete=\(observed.complete),depth=\(observed.maximumDepth)"
      + ",counts={" + counts + "},placementsTotal=\(observed.placementTotal)"
    var placements = observed.placements
    var sample = ""
    if let offset = observed.sampleOffset {
      let start = max(0, offset - 32)
      let end = min(data.count, start + 128)
      let bytes = data.subdata(in: (data.startIndex + start)..<(data.startIndex + end))
      sample =
        ",sampleOffset=\(start),sampleBytes=\(end - start),sampleBase64=\(bytes.base64EncodedString())"
    }
    var sampleOmitted = false
    while true {
      let text =
        base + ",placementsRetained=\(placements.count)"
        + ",placementsTruncated=\(observed.placementTotal > placements.count)"
        + ",placements={" + placements.joined(separator: ";") + "}"
        + (sampleOmitted ? ",sampleOmitted=budget" : sample)
      if text.utf8.count <= 1536, text.utf8.allSatisfy({ (32...126).contains($0) }) {
        return text
      }
      if !sample.isEmpty {
        sample = ""
        sampleOmitted = true
        continue
      }
      guard !placements.isEmpty else { return prefix + ",raw=incomplete-bound" }
      placements.removeLast()
    }

  }
}
