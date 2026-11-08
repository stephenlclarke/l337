import Foundation

extension GameRuntime {
  /// The existing typed intent rechecks screen/page/inventory and the captured start
  /// selection. This dispatch has no await, persistent transaction or mission event.
  func handleAssemblyCalibrationUI(_ intent: MissionUIIntent) -> Bool {
    switch intent.action {
    case .assemblyCalibrationStart:
      guard intent.isCurrent(in: game) else { return true }
      do {
        let started = try assemblyCalibrationControls.startCalibration(in: game)
        game.notify(started
          ? "SURFACE CALIBRATION STARTED - NO REGISTER READING"
          : "CALIBRATION UNAVAILABLE - FRONT AIM AND CLEAR SURFACE 250-1500 REQUIRED")
      } catch {
        assemblyCalibrationControls.cancel()
        game.notify("SURFACE CALIBRATION STOPPED - SENSOR QUERY REFUSED")
      }
      invalidateInventoryContext()
      refreshAssemblyCalibrationProjection()
      return true
    case .assemblyCalibrationCancel:
      guard intent.isCurrent(in: game) else { return true }
      assemblyCalibrationControls.cancel()
      invalidateInventoryContext()
      refreshAssemblyCalibrationProjection()
      game.notify("SURFACE CALIBRATION STOPPED - NO REGISTER READING")
      return true
    default: return false
    }
  }

  /// Called only immediately before the ordinary admitted motion step. A sensor error
  /// stops calibration with a visible reason; it neither suppresses nor bypasses physics.
  func beginAssemblyCalibrationMotion() {
    _ = assemblyCalibrationControls.synchronizedReadout(in: game)
    guard assemblyCalibrationControls.readout.mode != .off else { return }
    do { try assemblyCalibrationControls.beginMotion(in: game) }
    catch {
      assemblyCalibrationControls.cancel()
      game.notify("SURFACE CALIBRATION STOPPED - SENSOR QUERY REFUSED")
    }
  }

  /// Only the actual native advance hook calls this; snapshots/rendering never do.
  func finishAssemblyCalibrationMotion() {
    guard assemblyCalibrationControls.readout.mode != .off else { return }
    do { try assemblyCalibrationControls.finishMotion(in: game) }
    catch {
      assemblyCalibrationControls.cancel()
      game.notify("SURFACE CALIBRATION STOPPED - SENSOR QUERY REFUSED")
    }
  }

  /// Epoch synchronization only. This cannot acquire optics or consume a pending bracket.
  /// The Game carries an immutable display DTO, never the controller or private samples.
  func refreshAssemblyCalibrationProjection() {
    let readout = assemblyCalibrationControls.synchronizedReadout(in: game)
    game.nativeAssemblyCalibrationDisplay = readout.mode == .off ? nil : readout
  }

  /// Successful load uses this; failed load never reaches it. Trial/new-visit replacement
  /// also discards old controls through epoch synchronization before the next snapshot.
  func resetAssemblyCalibration() {
    assemblyCalibrationControls.cancel()
    game.nativeAssemblyCalibrationDisplay = nil
  }
}
