import Foundation

extension Game {
  /// Actual retained feature state; canonical native inventory and installed library are not triggers.
  public var requiresScriptDurability: Bool {
    if nativeDurabilityWatcher() { return true }
    if nativeDurabilityPeople() { return true }
    if nativeDurabilityUtility() { return true }
    if nativeDurabilityEMP() || nativeDurabilityAlien() { return true }
    if nativeDurabilityNewt() { return true }
    if isMissionTrial || nativeDurabilityLegacy() || nativeDurabilityCalendar()
      || nativeDurabilityInstances() || nativeDurabilityContracts()
    {
      return true
    }
    return nativeDurabilityScript() || nativeDurabilityAccommodation()
  }
}
