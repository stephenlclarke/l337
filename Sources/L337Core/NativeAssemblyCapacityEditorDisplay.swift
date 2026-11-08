import Foundation

extension Display {
  static func assemblyCapacityConsole(_ game: Game, width: Double, height: Double) -> Frame {
    var frame = Frame()
    frame.responsive = true
    frame.rasterizeGraphics = false
    frame.canvas = .init(x: 0, y: 0, width: width, height: height)
    guard let display = game.nativeAssemblyCapacityEditorDisplay else { return frame }
    let font = GameTypography.scale
    let contentWidth = min(700, width - 48)
    let left = (width - contentWidth) / 2
    let columns = max(12, Int(contentWidth / (6 * font)))
    frame.label("ASSEMBLY PLANNING / " + display.side, left, 20, scale: font, ink: .yellow)
    frame.label("Player plans. No crews dispatched.", left, 52, scale: font, ink: .cyan)
    frame.label("Four slots; model slot \(display.protectedSlot) protected.", left, 74, scale: font, ink: .cyan)
    let rowStep = max(18, min(25, (height - 300) / 9))
    for (index, row) in display.rows.enumerated() {
      let selected = index == display.selection
      frame.label((selected ? "> " : "  ") + row, left, 112 + Double(index) * rowStep,
        scale: font, ink: selected ? .cyan : .white)
    }
    let feedback = display.feedback.flatMap { ScriptLibraryText.wrap($0, width: columns) }
    let feedbackTop = 112 + 9 * rowStep + 12
    let feedbackCount = max(0, min(5, Int((height - 148 - feedbackTop) / 20)))
    for (index, line) in feedback.prefix(feedbackCount).enumerated() {
      frame.label(line, left, feedbackTop + Double(index) * 20, scale: font, ink: .orange)
    }
    let message = display.message.isEmpty ? (display.dirty ? "Unsaved changes" : "No unsaved changes") : display.message
    for (index, line) in ScriptLibraryText.wrap(message, width: columns).prefix(2).enumerated() {
      frame.label(line, left, height - 126 + Double(index) * 20, scale: font, ink: .cyan)
    }
    if let question = display.confirmation {
      frame.label(question, left, height - 80, scale: font, ink: .yellow)
      frame.label((display.confirms ? "> " : "  ") + "Confirm", left, height - 55, scale: font, ink: .cyan)
      frame.label((display.confirms ? "  " : "> ") + "Back", left + contentWidth / 2,
        height - 55, scale: font, ink: .cyan)
      frame.label("Left/Right: choose  Return: select", left, height - 22, scale: font)
    } else {
      frame.label("Arrows: row / choice  Return: select", left, height - 55, scale: font)
      frame.label("Esc: discard edits and back", left, height - 22, scale: font)
    }
    return frame
  }
}
