import Foundation

/// Explicit menu destinations leave the existing flight and numbered-screen keys alone.
public enum MissionUIAction: String, CaseIterable, Sendable {
  case gallery = "gallery-open"
  case contacts = "contacts-open"
  case originalSealConsent = "original-seal-consent"
  case originalWakeScan = "original-wake-scan"
  case originalRegisterRecovery = "original-register-recover"
  case reviewRecoveredRegister = "recovered-register-review"
  case contracts = "contracts-open"
  case rumours = "rumours-open"
  case trial = "gallery-trial"
  case retry = "mission-resume"
  case returnToCommander = "trial-return"
  case restartTrial = "trial-restart"
  case library = "library-open"
  case assemblyCalibrationStart = "assembly-calibration-start"
  case assemblyCalibrationCancel = "assembly-calibration-cancel"
  case assemblyCapacityConsole = "assembly-capacity-open"
  case journal = "journal-open"

  public var title: String {
    switch self {
    case .gallery: "Mission Gallery"
    case .contacts: "Mission Contacts"
    case .originalSealConsent: "Contact Selected Freighter"
    case .originalWakeScan: "Scan Selected Wake Mark"
    case .originalRegisterRecovery: "Recover Original Custody Register"
    case .reviewRecoveredRegister: "Read Recovered Custody Register"
    case .contracts: "Station Contracts"
    case .rumours: "Station Rumours"
    case .trial:
      "Try Selected Mission"
    case .retry: "Retry Selected Mission"
    case .returnToCommander: "Return to Commander"
    case .restartTrial: "Restart Mission Trial"
    case .library: "Mission Library"
    case .assemblyCalibrationStart: "Start Surface Calibration"
    case .assemblyCalibrationCancel: "Stop Surface Calibration"
    case .assemblyCapacityConsole: "Assembly Planning Console"
    case .journal: "Journal"
    }
  }

  public func title(in game: Game) -> String {
    self == .trial && game.selectedGalleryMissionIsOwnedAssignment ? "Try Campaign" : title
  }

  public func isEnabled(in game: Game) -> Bool {
    switch self {
    case .originalSealConsent: return (try? game.makeHollowManifestConsentReview()) != nil
    case .originalWakeScan: return game.hollowManifestWakeTarget != nil
    case .originalRegisterRecovery: return game.hollowManifestRegisterTarget != nil
    case .reviewRecoveredRegister: return game.canOpenC03ArchiveReader
    case .assemblyCalibrationStart: return game.canStartAssemblyCalibration
    case .assemblyCalibrationCancel: return game.canCancelAssemblyCalibration
    case .assemblyCapacityConsole: return game.canOpenAssemblyCapacityEditor
    case .contracts:
      return game.docked && (game.dockedAtMainStation || game.nativeStationBoardContext != nil)
        && !game.paused && !game.showroom.trading
        && ![Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff].contains(
          game.screen)
    case .trial:
      return game.screen == .gallery
        && (game.canTrialSelectedMission || game.canReviewSelectedCampaignTrial)
    case .retry:
      return game.screen == .gallery && game.canRetrySelectedGalleryEntry
    case .returnToCommander, .restartTrial:
      return game.isMissionTrial
    case .library:
      return true
    case .journal:
      return !game.acceptsTextInput && !game.showroom.trading
        && ![Screen.demo, .title, .gameOver, .help, .secret, .mission, .handoff].contains(game.screen)
    case .gallery, .contacts, .rumours:
      return !game.paused && !game.acceptsTextInput
        && ![
          Screen.demo, .title, .gameOver, .secret, .help, .mission, .handoff, .showroom, .gallery,
        ]
        .contains(game.screen)
        && (self == .gallery || game.docked)
    }
  }

  /// Page-affecting actions use the actor's existing exact painted-page proof.
  public var requiresPageProof: Bool {
    self == .contracts || self == .trial || self == .retry || self == .originalSealConsent
      || self == .originalWakeScan || self == .originalRegisterRecovery
      || self == .reviewRecoveredRegister
  }
}

/// Captured in the native input stream. The actor rechecks epoch, availability and page proof.
public struct MissionUIIntent: Sendable, Equatable {
  public let action: MissionUIAction
  public let presentation: ScriptPagePresentation
  public let screen: Screen
  public let inventoryContext: InventoryContextEpoch
  private let assemblyCalibrationSelection: NativeAssemblyCalibrationSelection?
  private let originalSealTarget: ActorIdentity?
  private let originalWakeTarget: ActorIdentity?
  private let originalRegisterTarget: ActorIdentity?
  /// Check again inside GameRuntime immediately before dispatch, without an intervening await.
  public func isCurrent(in game: Game) -> Bool {
    screen == game.screen && inventoryContext == game.inventoryContextEpoch
      && presentation.epoch == game.scriptPagePresentation.epoch && action.isEnabled(in: game)
      && (!action.requiresPageProof || presentation == game.scriptPagePresentation)
      && (action != .assemblyCalibrationStart
        || assemblyCalibrationSelection?.isCurrent(in: game) == true)
      && (action != .originalSealConsent
        || (originalSealTarget != nil && originalSealTarget == game.hollowManifestConsentTarget))
      && (action != .originalWakeScan
        || (originalWakeTarget != nil && originalWakeTarget == game.hollowManifestWakeTarget))
      && (action != .originalRegisterRecovery
        || (originalRegisterTarget != nil && originalRegisterTarget == game.hollowManifestRegisterTarget))
  }

  public init(action: MissionUIAction, game: Game, presentation: ScriptPagePresentation) {
    self.action = action
    self.presentation = presentation
    screen = game.screen
    inventoryContext = game.inventoryContextEpoch
    originalSealTarget = action == .originalSealConsent ? game.hollowManifestConsentTarget : nil
    originalWakeTarget = action == .originalWakeScan ? game.hollowManifestWakeTarget : nil
    originalRegisterTarget = action == .originalRegisterRecovery ? game.hollowManifestRegisterTarget : nil
    assemblyCalibrationSelection = action == .assemblyCalibrationStart
      ? NativeAssemblyCalibrationSelection.capture(in: game) : nil
  }
}

extension GameRuntime {
  /// Validate and dispatch in one actor turn so a restore cannot race the captured proof.
  public func missionUICommand(_ intent: MissionUIIntent) {
    guard intent.isCurrent(in: game) else { return }
    if handleAssemblyCalibrationUI(intent) { return }
    if handleC03ArchiveReaderUI(intent) { return }
    if intent.action.requiresPageProof {
      scriptPageKey(intent.action.rawValue, expected: intent.presentation)
    } else {
      key(intent.action.rawValue)
    }
  }
}
