/// Original carried watcher from the Reris commission, returned there after the audit.
/// Declaring it supplies no instrument observation, diary, consent, landmark or receiver.
enum NativeMemoryAtlasReferenceDefinition {
  static let logicalResource = "memory-atlas-reference"
  static let name = "Atlas Reference Watcher"
  static let node = EquipmentNodeID(family: .init("memory-atlas-reference"), key: name)
  static let cargoTonnes = 1
  static let purchaseNode = EquipmentPurchaseNode(
    id: node, displayName: name, policy: .acquisitionOnly)

  /// The real source selects its own unit and episode resource. No serial is generated;
  /// protected original custody persists until its actual return, not a timer or setting.
  static func gear(for source: EquipmentIssueSource) -> ScriptGearDefinition {
    .init(id: source.resource, name: name, quantity: 1, loan: true,
      mount: nil, returnPolicy: "all")
  }

  /// Actual matching canonical inventory only. Type/mass cannot prove measured coordinates.
  static func occupiedTonnes(in inventory: OwnedEquipmentInventory?) -> Int {
    inventory?.items.filter { $0.node == node }.count ?? 0
  }
}
