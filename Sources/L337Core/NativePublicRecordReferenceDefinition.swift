/// Protected original one-tonne reference declaration, not a recorder reading, evidence version, reply or consent.
/// The display label is new project UI wording, not finite calibrated stock, observer authority or receiving.
enum NativePublicRecordReferenceDefinition {
  static let logicalResource = "public-record-reference"
  static let name = "Public Record Reference Instrument"
  static let node = EquipmentNodeID(family: .init("public-record-reference"), key: name)
  static let cargoTonnes = 1
  static let purchaseNode = EquipmentPurchaseNode(
    id: node, displayName: name, policy: .acquisitionOnly)

  /// A genuine future native issuer chooses the original physical resource and serial.
  static func gear(for source: EquipmentIssueSource) -> ScriptGearDefinition {
    .init(id: source.resource, name: name, quantity: 1, loan: true,
      mount: nil, returnPolicy: "all")
  }

  /// Inventory mass only, never routing decisions, independent recordings, evidence hashes, replies or receiving authority.
  static func occupiedTonnes(in inventory: OwnedEquipmentInventory?) -> Int {
    inventory?.items.filter { $0.node == node }.count ?? 0
  }
}
