import Foundation

enum NativeSecondCommoditySaleSave {
  static let version = 147
  static let alienVersion = 148
  static let field = "secondNativeCommoditySale"

  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    commander.scriptState.secondNativeCommoditySale != nil
  }

  static func validateClaims(_ commander: borrowing Commander) -> Bool {
    guard let second = commander.scriptState.secondNativeCommoditySale else { return true }
    guard let first = commander.scriptState.firstNativeCommoditySale,
      second.valid(after: first), NativeFirstCommoditySaleSave.validateClaims(commander),
      second.sale.owner == commander.equipmentOwnerID,
      let world = commander.nativeStations, world.mainStations.contains(second.sale.dock.station),
      second.sale.dock.sequence < world.nextMainDockSequence,
      second.sale.dock.actor.visit <= commander.flightSimulation.visit,
      second.sale.physicalTime <= commander.flightSimulation.physicalTime,
      second.sale.calendarOperation <= (commander.scriptState.calendarLedger?.operation ?? 0)
    else { return false }
    return true
  }

  static func validateFields(
    _ data: Data, location: ScriptSaveJSONPreflight.InquiryArchiveLocation, schema: Int?
  ) throws {
    let permits = location == .missions && contains(schema)
    let found = try ScriptSaveJSONPreflight.validateCommodityTradeArchive(
      data, location: location, permitsRoot: permits, field: field)
    guard found == permits else { throw SaveError.invalidCommander }
    guard found else { return }
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let leaf = root[field] as? [String: Any]
    else { throw SaveError.invalidCommander }
    let bytes = try JSONSerialization.data(withJSONObject: leaf)
    guard bytes.count <= 32768 else { throw SaveError.invalidCommander }
    let second = try JSONDecoder().decode(NativeSecondCommoditySale.self, from: bytes)
    guard second.sale.valid, second.firstOperation != second.sale.operation,
      (leaf as NSDictionary).isEqual(
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(second)))
    else { throw SaveError.invalidCommander }
  }
}
