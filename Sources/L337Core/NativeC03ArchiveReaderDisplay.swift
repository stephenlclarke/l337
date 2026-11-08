import Foundation

/// The same mission-specific pane geometry drives painting, scrolling and typed clicks.
struct NativeC03ArchiveReaderLayout {
  let left: Double
  let width: Double
  let title: [String]
  let heading: [String]
  let lines: [String]
  let bodyTop: Double
  let buttonsY: Double
  let hintY: Double
  let footerY: Double
  let window: ScrollWindow
  let font = GameTypography.scale
  let row = 19.0

  init(page: NativeC03RecoveredArchiveReader.Page, width: Double, height: Double, offset: Int) {
    self.width = min(700, max(1, width - 48))
    left = (width - self.width) / 2
    let columns = max(1, Int(self.width / (6 * GameTypography.scale)))
    title = Array(ScriptLibraryText.wrap("THE HOLLOW MANIFEST", width: columns).prefix(2))
    heading = Array(ScriptLibraryText.wrap(
      "\(page.section.rawValue + 1)/5 \(page.title)", width: columns).prefix(2))
    bodyTop = 20 + Double(title.count + heading.count + 2) * 19
    buttonsY = height - 3 * 19 - 18
    hintY = buttonsY - 19 - 8
    footerY = height - 2 * 19 - 6
    var text: [String] = []
    for item in page.rows {
      text.append(item.label + " [" + Self.basis(item.basis) + "]")
      text.append(item.value)
      if let reference = item.reference { text.append("Reference: " + reference.uuidString) }
      text.append("")
    }
    text.append(page.notice)
    lines = text.flatMap { ScriptLibraryText.wrap($0, width: columns) }
    window = .init(count: lines.count,
      visible: max(1, Int((hintY - 6 - bodyTop) / 19)), offset: offset)
  }

  func key(at point: ScreenPoint) -> String? {
    guard point.x.isFinite, point.y.isFinite, point.x >= left, point.x < left + width,
      point.y >= buttonsY - 6, point.y < buttonsY + row + 2
    else { return nil }
    if point.x < left + width / 3 { return "left" }
    if point.x < left + width * 2 / 3 { return "escape" }
    return "right"
  }

  private static func basis(_ basis: NativeC03RecoveredArchiveReader.Basis) -> String {
    switch basis {
    case .documentClaim: "DOCUMENT CLAIM"
    case .observedSealReference: "SEAL INSPECTION"
    case .recordedWakeReference: "RECORDED WAKE"
    case .recordedComparison: "WRITTEN COMPARISON"
    case .requirement: "EVIDENCE REQUIRED"
    }
  }
}

extension Display {
  static func c03RecoveredRegister(_ display: NativeC03ArchiveReaderDisplay,
    width: Double, height: Double) -> Frame
  {
    let layout = NativeC03ArchiveReaderLayout(page: display.page,
      width: width, height: height, offset: display.scroll)
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    for (index, text) in layout.title.enumerated() {
      frame.label(text, layout.left, 20 + Double(index) * layout.row,
        scale: layout.font, ink: .yellow)
    }
    let headingY = 20 + Double(layout.title.count) * layout.row
    for (index, text) in layout.heading.enumerated() {
      frame.label(text, layout.left, headingY + Double(index) * layout.row,
        scale: layout.font, ink: .cyan)
    }
    frame.label("DOCUMENT / NOT PROOF", layout.left, layout.bodyTop - layout.row,
      scale: layout.font, ink: .yellow)
    for (index, text) in layout.lines.dropFirst(layout.window.offset)
      .prefix(layout.window.visible).enumerated()
    {
      frame.label(text, layout.left, layout.bodyTop + Double(index) * layout.row, scale: layout.font)
    }
    if let hint = layout.window.hint {
      frame.label(hint, layout.left, layout.hintY, scale: layout.font, ink: .cyan)
    }
    for (index, title) in ["PREV", "BACK", "NEXT"].enumerated() {
      frame.label(title, layout.left + Double(index) * layout.width / 3, layout.buttonsY,
        scale: layout.font, ink: .cyan)
    }
    frame.label("ARROWS: PAGES / SCROLL", layout.left, layout.footerY, scale: layout.font)
    frame.label("ESC: BACK / K: HELP", layout.left, layout.footerY + layout.row, scale: layout.font)
    return frame
  }
}
