import Foundation

extension Display {
  public static func c01InquiryJournal(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    let font = GameTypography.scale
    let contentWidth = min(700, width - 48)
    let left = (width - contentWidth) / 2
    let columns = max(10, Int(contentWidth / (6 * font)))
    frame.label("JOURNAL", left, 20, scale: font, ink: .yellow)
    let summary = game.c01InquiryJournalSummary.dropFirst().flatMap {
      ScriptLibraryText.wrap($0, width: columns)
    }
    for (index, line) in summary.prefix(3).enumerated() {
      frame.label(line, left, 52 + Double(index) * 19, scale: font, ink: .cyan)
    }
    if game.c01InquiryJournal.detail {
      let window = game.c01InquiryJournalDetailWindow(width: width, height: height)
      let lines = game.c01InquiryJournalDetailLines(width: width)
      for (index, line) in lines.dropFirst(window.offset).prefix(window.visible).enumerated() {
        frame.label(line, left, 124 + Double(index) * 19, scale: font)
      }
      if let hint = window.hint { frame.label(hint, left, height - 132, scale: font, ink: .cyan) }
      if game.c01InquiryJournalCanConfirm {
        frame.label((game.c01InquiryJournal.action == .accept ? "> " : "  ") + "Confirm",
          left, height - 64, scale: font, ink: .cyan)
      }
      frame.label((game.c01InquiryJournal.action == .back ? "> " : "  ") + "Back",
        left + contentWidth / 2, height - 64, scale: font, ink: .cyan)
      frame.label(game.c01InquiryJournalCanConfirm
        ? "Left/Right: choose  Return: select  Esc: back"
        : "Return / Esc: back", left, height - 22, scale: font)
    } else {
      let rows = game.c01InquiryJournalRows
      let window = game.c01InquiryJournalListWindow(height: height)
      for index in window.offset..<min(window.count, window.offset + window.visible) {
        let selected = index == game.c01InquiryJournal.selection
        for (lineIndex, line) in ScriptLibraryText.wrap(rows[index].title, width: columns - 2)
          .prefix(2).enumerated()
        {
          frame.label((lineIndex == 0 && selected ? "> " : "  ") + line, left,
            124 + Double(index - window.offset) * 44 + Double(lineIndex) * 19,
            scale: font, ink: selected ? .cyan : .white)
        }
      }
      if let hint = window.hint { frame.label(hint, left, height - 132, scale: font, ink: .cyan) }
      frame.label("Arrows: choose  Return: read  Esc: back  K: help",
        left, height - 22, scale: font)
    }
    if game.messageTime > 0 {
      for (index, line) in ScriptLibraryText.wrap(game.message, width: columns).prefix(2).enumerated() {
        frame.label(line, left, height - 104 + Double(index) * 19, scale: font, ink: .orange)
      }
    }
    return frame
  }
}
