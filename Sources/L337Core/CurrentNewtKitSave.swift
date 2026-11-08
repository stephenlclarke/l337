import Foundation

/// The current finite kit has its own envelope, composed with the existing mission claims.
/// Structural decoding grants no birth, hardware, custody or native admission authority.
enum CurrentNewtKitSave {
  static let version = 145
  static let alienVersion = 146
  static let maximumLeafBytes = 32768
  static let fields: Set<String> = [
    "currentNewtKitStock", "currentNewtKitReceipt", "currentNewtKitConfiguration",
  ]

  static func contains(_ schema: Int?) -> Bool { schema == version || schema == alienVersion }

  @inline(never)
  static func hasClaims(_ commander: borrowing Commander) -> Bool {
    if hasEncounterClaims(commander.encounterDirector) { return true }
    if commander.npcPersistence.hasCurrentNewtKitClaims { return true }
    return hasEMPClaims(commander.savedEMPState)
  }

  @inline(never)
  static func hasEncounterClaims(_ director: EncounterDirector?) -> Bool {
    director?.pendingRequests.contains(where: {
      $0.currentNewtKitConfiguration != nil
    }) == true
  }

  @inline(never)
  static func hasEMPClaims(_ state: EMPState?) -> Bool {
    state?.records.values.contains { record in
      claims(record.hull.body) || claims(record.custody.original.body)
        || record.pods.contains { claims($0.body) }
        || record.savedCurrentTrafficTransfer?.currentNewtKitStock != nil
        || record.custody.traffic?.currentNewtKitStock != nil
    } == true
  }

  private static func claims(_ body: borrowing SpaceBody) -> Bool {
    let physical = (copy body).physical
    return physical?.currentNewtKitStock != nil || physical?.currentNewtKitReceipt != nil
  }

  @discardableResult
  static func validateFields(
    _ data: Data, location: ScriptSaveJSONPreflight.InquiryArchiveLocation, schema: Int?
  ) throws -> Bool {
    try ScriptSaveJSONPreflight.validateCurrentNewtKitFields(
      data, location: location,
      permitsClaims: contains(schema) && (location == .commander || location == .world))
  }

  /// Compare the complete typed leaf with the raw object so Codable cannot discard unknown
  /// fields or turn explicit null into absence. The lexical stream checks duplicate keys first.
  static func validateLeaf(_ data: Data, field: String) throws {
    let encoded: Data
    switch field {
    case "currentNewtKitStock":
      let stock = try JSONDecoder().decode(CurrentNewtKitStock.self, from: data)
      guard stock.structurallyValid else { throw SaveError.invalidCommander }
      encoded = try JSONEncoder().encode(stock)
    case "currentNewtKitReceipt":
      let receipt = try JSONDecoder().decode(CurrentNewtKitReceipt.self, from: data)
      guard receipt.structurallyValid else { throw SaveError.invalidCommander }
      encoded = try JSONEncoder().encode(receipt)
    default: throw SaveError.invalidCommander
    }
    guard let original = try JSONSerialization.jsonObject(with: data) as? NSDictionary,
      original.isEqual(try JSONSerialization.jsonObject(with: encoded))
    else { throw SaveError.invalidCommander }
  }
}
