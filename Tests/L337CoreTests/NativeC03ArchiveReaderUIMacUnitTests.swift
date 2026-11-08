import AppKit
import Foundation
import Testing

@testable import L337Core
@testable import L337Mac

@Suite(.serialized)
struct NativeC03ArchiveReaderUIMacUnitTests {
  @Test func actualNativeMenuPaintedBoundsAndClickQueueUseTheRecoveredPage() async throws {
    let fixture = try await actualC03ArchiveReaderUIFixture()
    defer { fixture.commission.clean() }
    let recovered = fixture.recovered
    // Only Sendable Game/intent values cross the main actor boundary, never the fixture.
    let intent = try await MainActor.run {
      var intents: [MissionUIIntent] = []
      let target = NativeMissionMenu(snapshot: { recovered },
        paintedPresentation: { recovered.scriptPagePresentation }, enqueue: { intents.append($0) })
      let menu = NSMenu()
      target.install(in: menu)
      let item = try #require(menu.items.first {
        $0.representedObject as? String == MissionUIAction.reviewRecoveredRegister.rawValue
      })
      #expect(target.validateMenuItem(item) && item.keyEquivalent.isEmpty)
      let chosen = target.choose(.reviewRecoveredRegister)
      try #require(chosen && intents.count == 1)
      return intents[0]
    }
    await fixture.runtime.missionUICommand(intent)
    // The actual native view paints at bounds different from the actor's last viewport.
    await fixture.runtime.setViewport(width: 1280, height: 720)
    let opened = await fixture.runtime.snapshot()
    try #require(opened.isC03ArchiveReaderVisible)
    let click = try await MainActor.run {
      let view = GameView(frame: .init(x: 0, y: 0, width: 640, height: 480))
      view.game = opened
      let context = try #require(CGContext(data: nil, width: 640, height: 480,
        bitsPerComponent: 8, bytesPerRow: 640 * 4, space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      context.translateBy(x: 0, y: 480)
      context.scaleBy(x: 1, y: -1)
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
      view.draw(view.bounds)
      NSGraphicsContext.restoreGraphicsState()
      let painted = try #require(view.paintedMissionMenuPresentation)
      var paintedGame = opened
      paintedGame.viewportWidth = 640
      paintedGame.viewportHeight = 480
      #expect(painted == paintedGame.scriptPagePresentation)
      #expect(painted != opened.scriptPagePresentation)
      _ = try #require(context.makeImage())
      let display = try #require(opened.c03ArchiveReaderDisplay)
      let layout = NativeC03ArchiveReaderLayout(page: display.page, width: 640, height: 480, offset: 0)
      let local = NSPoint(x: layout.left + layout.width - 1, y: layout.buttonsY)
      let location = view.convert(local, to: nil)
      let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: location,
        modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0,
        clickCount: 1, pressure: 1))
      view.mouseDown(with: event)
      let packet = try #require(view.pending.last)
      try #require(packet.hasPrefix("script-page-click:"))
      #expect(!view.pending.contains { $0.hasPrefix("library-click:") })
      let parts = packet.dropFirst("script-page-click:".count).split(separator: ":")
      try #require(parts.count == 3)
      let data = try #require(Data(base64Encoded: String(parts[0])))
      let proof = try JSONDecoder().decode(ScriptPagePresentation.self, from: data)
      #expect(proof == painted)
      let x = try #require(Double(parts[1]))
      let y = try #require(Double(parts[2]))
      #expect(abs(x - local.x) < 0.001 && abs(y - local.y) < 0.001)
      view.frame.size = .init(width: 800, height: 480)
      #expect(view.paintedMissionMenuPresentation == nil)
      return (proof: proof, x: x, y: y)
    }
    // Use the same existing actor viewport update as the native input consumer.
    await fixture.runtime.setViewport(width: 640, height: 480)
    await fixture.runtime.scriptPageClick(x: click.x, y: click.y, expected: click.proof)
    let next = await fixture.runtime.snapshot()
    #expect(next.c03ArchiveReaderDisplay?.page.section == .firstSeal)
    #expect(next.hollowManifestMission == recovered.hollowManifestMission)
  }
}
