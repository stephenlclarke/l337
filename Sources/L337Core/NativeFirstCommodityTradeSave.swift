import Foundation

enum NativeFirstCommodityTradeSave {
  static let version = 141
  static let alienVersion = 142
  static let field = "firstNativeCommodityTrade"

  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.firstNativeCommodityTrade != nil
  }
  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard let receipt = commander.scriptState.firstNativeCommodityTrade else { return true }
    guard receipt.valid, receipt.owner == commander.equipmentOwnerID,
      let world = commander.nativeStations, world.mainStations.contains(receipt.dock.station),
      receipt.dock.sequence < world.nextMainDockSequence,
      receipt.dock.actor.visit <= commander.flightSimulation.visit,
      receipt.physicalTime <= commander.flightSimulation.physicalTime,
      receipt.calendarOperation <= (commander.scriptState.calendarLedger?.operation ?? 0)
    else { return false }
    return true
  }

  /// The new leaf belongs only to the missions root of its distinct current envelope.
  /// All old envelopes, embedded state, misplaced fields and unknown leaf keys refuse.
  static func validateFields(
    _ data: Data, location: ScriptSaveJSONPreflight.InquiryArchiveLocation, schema: Int?
  ) throws {
    let permitted = location == .missions && contains(schema)
    let found = try ScriptSaveJSONPreflight.validateCommodityTradeArchive(
      data, location: location, permitsRoot: permitted)
    guard !permitted || found else { throw SaveError.invalidCommander }
    guard found else { return }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SaveError.invalidCommander
    }
    if let raw = root[field] {
      guard permitted, let leaf = raw as? [String: Any] else { throw SaveError.invalidCommander }
      let bytes = try JSONSerialization.data(withJSONObject: leaf)
      guard bytes.count <= 32768 else { throw SaveError.invalidCommander }
      try ScriptSaveJSONPreflight.validateCommodityTradeData(bytes)
      let receipt = try JSONDecoder().decode(NativeFirstCommodityTrade.self, from: bytes)
      guard receipt.valid,
        (leaf as NSDictionary).isEqual(
          try JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)))
      else { throw SaveError.invalidCommander }
    } else if permitted { throw SaveError.invalidCommander }
  }
}
