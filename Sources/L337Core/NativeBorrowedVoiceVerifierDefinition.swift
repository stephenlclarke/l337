/// Original held verifier collected at Noserin and returned with its record at Aiven.
/// This declaration supplies no physical clock, signed record, receiver or native source.
enum NativeBorrowedVoiceVerifierDefinition {
  static let logicalResource = "independent-verifier"
  static let name = "Renn Independent Verifier"
  static let node = EquipmentNodeID(family: .init("borrowed-voice-verifier"), key: name)
  static let cargoTonnes = 1
  static let purchaseNode = EquipmentPurchaseNode(
    id: node, displayName: name, policy: .acquisitionOnly)

  /// Real source-selected resource and unit, never a derived or replacement serial.
  /// Protected original custody lasts until its genuine receiving transfer.
  static func gear(for source: EquipmentIssueSource) -> ScriptGearDefinition {
    .init(id: source.resource, name: name, quantity: 1, loan: true,
      mount: nil, returnPolicy: "all")
  }

  /// Full matching canonical inventory count only, not proof of the clock or its contents.
  static func occupiedTonnes(in inventory: OwnedEquipmentInventory?) -> Int {
    inventory?.items.filter { $0.node == node }.count ?? 0
  }
}
