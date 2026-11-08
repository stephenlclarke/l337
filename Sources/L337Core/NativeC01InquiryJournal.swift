import Foundation

/// Transient presentation only. No saved award, case, approval or clock is held here.
struct NativeC01InquiryJournalState: Sendable {
  var selection = 0
  var detail = false
  var scroll = 0
  var action: ContractBoardAction = .back
  var review: NativeC01InquiryRequestReview?
  var previous: Screen = .status
  var generation = UUID()
}

struct NativeC01InquiryJournalRow: Sendable {
  enum Kind: Sendable { case request, retainedClue }
  let kind: Kind
  let key: String
  let title: String
  let detail: [String]
}

/// Existing painted-page transport DATA, never a source or publication seal.
public struct NativeC01InquiryJournalPageIdentity: Codable, Sendable, Equatable {
  public let generation: UUID
  public let selection: Int
  public let detail: Bool
  public let scroll: Int
  public let action: ContractBoardAction
  public let requestCaseID: UUID?
  public let recordsSHA256: String
  public let nativeEpoch: UUID
  public let viewportWidth: Double
  public let viewportHeight: Double
  var valid: Bool {
    (0...ScriptBaseClueCatalog.sources.count).contains(selection) && (0...100000).contains(scroll)
      && (action == .accept || action == .back)
      && ScriptCompletionReceipt.validDigest(recordsSHA256)
      && viewportWidth.isFinite && viewportWidth > 0
      && viewportHeight.isFinite && viewportHeight > 0
  }
  public var allowedKeys: Set<String> {
    ["up", "down", "return", "escape", "left", "right", "tab", "pageup", "pagedown", "k"]
  }
}

extension Game {
  /// The same production validation calls used by baseClueProgress. Invalid
  /// retained claims stay unavailable; they are not presented as a fresh empty journal.
  var c01InquiryJournalProgress: ScriptClueProgress? {
    guard ScriptClueVersionedSave.validateClaims(commander, trust: .production),
      ScriptNavigationTradeSave.validateClaims(commander, binding: nil)
    else { return nil }
    return commander.scriptState.savedClueJournal?.progress ?? .empty
  }

  var c01InquiryJournalRows: [NativeC01InquiryJournalRow] {
    var rows: [NativeC01InquiryJournalRow] = [.init(kind: .request,
      key: NativeC01InquiryBoard.requestKey, title: NativeC01InquiryBoard.requestTitle,
      detail: [])]
    guard c01InquiryJournalProgress != nil,
      let journal = commander.scriptState.savedClueJournal
    else { return rows }
    for source in journal.awards.keys.sorted() {
      guard let award = journal.awards[source] else { continue }
      let label = source.hasPrefix("l337.") ? String(source.dropFirst(5)) : source
      let title = label.replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "/", with: " / ").capitalized
      rows.append(.init(kind: .retainedClue, key: award.receiptID,
        title: "Recorded source: " + title,
        detail: ["Recorded source: " + title, "This source's clue is retained in your journal.",
          "This entry is read-only. It does not replay the job or pay its reward again."]))
    }
    return rows
  }

  var c01InquiryJournalSummary: [String] {
    guard let progress = c01InquiryJournalProgress else {
      return ["Journal", "The retained clue journal is unavailable."]
    }
    return ["Journal",
      "\(progress.collectedClueIDs.count) of \(ScriptBaseClueCatalog.requiredClueIDs.count) source clues recorded.",
      "Only recorded sources are listed. Requesting an inquiry earns no clue by itself."]
  }

  var c01InquiryJournalDetail: [String] {
    let rows = c01InquiryJournalRows
    guard rows.indices.contains(c01InquiryJournal.selection) else { return ["Review the journal."] }
    let row = rows[c01InquiryJournal.selection]
    switch row.kind {
    case .retainedClue: return row.detail
    case .request:
      guard let review = c01InquiryJournal.review else {
        return [NativeC01InquiryBoard.requestTitle, "Review the charter evidence desk."]
      }
      guard review.allowed, review.presentedIntake?.role == .intake else {
        return [NativeC01InquiryBoard.requestTitle] + review.issues
          + ["Back leaves your case, original commission and recorded clues unchanged."]
      }
      return [NativeC01InquiryBoard.requestTitle, "Charter evidence service: intake desk.",
        "Confirm rechecks your arrival and opens a separate Glass Meridian inquiry case.",
        "No fee, cargo space or original commission completion is required for this request.",
        "Original progress, losses and rewards remain unchanged. Measurements and independent receiving are still required.",
        "Confirm requests this case. Back cancels without opening it."]
    }
  }

  var scriptC01InquiryJournalPageIdentity: NativeC01InquiryJournalPageIdentity {
    let rows = c01InquiryJournalRows
    let progress = c01InquiryJournalProgress
    var facts = [progress == nil ? "unavailable" : "validated"]
    for row in rows { facts += [row.key, row.title] }
    if let progress { facts += progress.collectedClueIDs + progress.missingClueIDs }
    if let root = commander.scriptState.savedC01Inquiry {
      facts += [root.caseRecord.id.uuidString, String(root.caseRecord.revision)]
    }
    facts += [String(commander.flightSimulation.visit), String(gameplayRevision)]
    facts += ["viewport-width-bits:" + String(viewportWidth.bitPattern),
      "viewport-height-bits:" + String(viewportHeight.bitPattern)]
    return .init(generation: c01InquiryJournal.generation,
      selection: c01InquiryJournal.selection, detail: c01InquiryJournal.detail,
      scroll: c01InquiryJournal.scroll,
      action: c01InquiryJournal.action, requestCaseID: c01InquiryJournal.review?.caseID,
      recordsSHA256: ScriptPackLibrary.hash(Data(facts.joined(separator: "\n").utf8)),
      nativeEpoch: nativeStationRuntimeEpoch,
      viewportWidth: viewportWidth, viewportHeight: viewportHeight)
  }

  mutating func openC01InquiryJournal() {
    guard MissionUIAction.journal.isEnabled(in: self) else { return }
    let previous = screen == .journal ? c01InquiryJournal.previous : screen
    c01InquiryJournal = .init()
    c01InquiryJournal.previous = previous
    screen = .journal
  }

  /// Existing ordinary controls, executed inside the original command snapshot
  /// and writer rollback. This function never calls a publisher or earns a clue.
  mutating func c01InquiryJournalKey(_ key: String) {
    guard screen == .journal else { return }
    if key == "escape" {
      if c01InquiryJournal.detail {
        c01InquiryJournal.detail = false
        c01InquiryJournal.review = nil
        c01InquiryJournal.action = .back
      } else {
        screen = c01InquiryJournal.previous == .journal ? .status : c01InquiryJournal.previous
      }
      c01InquiryJournal.scroll = 0
      c01InquiryJournal.generation = UUID()
      return
    }
    let rows = c01InquiryJournalRows
    guard !rows.isEmpty else { return }
    if !c01InquiryJournal.detail {
      if ["up", "down", "pageup", "pagedown"].contains(key) {
        let move = ["up", "pageup"].contains(key) ? -1 : 1
        c01InquiryJournal.selection = max(0, min(rows.count - 1, c01InquiryJournal.selection + move))
        c01InquiryJournal.generation = UUID()
      } else if key == "return", rows.indices.contains(c01InquiryJournal.selection) {
        c01InquiryJournal.detail = true
        c01InquiryJournal.scroll = 0
        c01InquiryJournal.action = .back
        if case .request = rows[c01InquiryJournal.selection].kind {
          c01InquiryJournal.review = c01InquiryRequestReview()
        } else { c01InquiryJournal.review = nil }
        c01InquiryJournal.generation = UUID()
      }
      return
    }
    if ["up", "down", "pageup", "pagedown"].contains(key) {
      let direction = ["up", "pageup"].contains(key) ? -1 : 1
      c01InquiryJournal.scroll = c01InquiryJournalDetailWindow(
        width: viewportWidth, height: viewportHeight).moved(direction * (key.hasPrefix("page") ? 8 : 1))
      c01InquiryJournal.generation = UUID()
      return
    }
    if ["left", "right", "tab"].contains(key), c01InquiryJournalCanConfirm {
      c01InquiryJournal.action = c01InquiryJournal.action == .back ? .accept : .back
      c01InquiryJournal.generation = UUID()
      return
    }
    guard key == "return" else { return }
    if c01InquiryJournal.action == .back {
      c01InquiryJournal.scroll = 0
      c01InquiryJournal.detail = false
      c01InquiryJournal.review = nil
      c01InquiryJournal.generation = UUID()
      return
    }
    guard rows.indices.contains(c01InquiryJournal.selection),
      case .request = rows[c01InquiryJournal.selection].kind,
      c01InquiryJournal.action == .accept, let review = c01InquiryJournal.review
    else { return }
    do {
      try confirmC01InquiryRequest(review)
      c01InquiryJournal.detail = false
      c01InquiryJournal.scroll = 0
      c01InquiryJournal.review = nil
      c01InquiryJournal.action = .back
    } catch {
      notify("INQUIRY REQUEST UNAVAILABLE - REVIEW THE CURRENT DESK")
      c01InquiryJournal.review = c01InquiryRequestReview()
      c01InquiryJournal.action = .back
      c01InquiryJournal.scroll = 0
    }
    c01InquiryJournal.generation = UUID()
  }
}

extension Game {
  var c01InquiryJournalCanConfirm: Bool {
    let rows = c01InquiryJournalRows
    guard c01InquiryJournal.detail, rows.indices.contains(c01InquiryJournal.selection),
      case .request = rows[c01InquiryJournal.selection].kind
    else { return false }
    return c01InquiryJournal.review?.allowed == true
  }

  func c01InquiryJournalDetailLines(width: Double) -> [String] {
    let columns = max(10, Int(min(700, width - 48) / (6 * GameTypography.scale)))
    return c01InquiryJournalDetail.flatMap { ScriptLibraryText.wrap($0, width: columns) + [""] }
  }

  func c01InquiryJournalDetailWindow(width: Double, height: Double) -> ScrollWindow {
    .init(count: c01InquiryJournalDetailLines(width: width).count,
      visible: max(1, Int((height - 260) / 19)), offset: c01InquiryJournal.scroll)
  }

  func c01InquiryJournalListWindow(height: Double) -> ScrollWindow {
    let visible = max(1, Int((height - 250) / 44))
    return .init(count: c01InquiryJournalRows.count, visible: visible,
      offset: max(0, c01InquiryJournal.selection - visible + 1))
  }
}
