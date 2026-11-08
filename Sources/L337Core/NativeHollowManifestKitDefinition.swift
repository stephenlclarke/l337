import Foundation

/// The laboratory's original one-tonne loan. It is held physical equipment, not a fitted weapon.
enum NativeHollowManifestKitDefinition {
  static let resource = NativeHollowManifestDefinition.inspectionKitID
  static let name = "Torenran Inspection Kit"
  static let node = EquipmentNodeID(family: .init("c03-inspection-kit"), key: name)
  static let cargoTonnes = NativeHollowManifestDefinition.inspectionKitMassTonnes
  static let issueLocation = NativeHollowManifestDefinition.laboratoryWorld
  static let returnLocation = NativeHollowManifestDefinition.issuer
  static let purchaseNode = EquipmentPurchaseNode(
    id: node, displayName: name, policy: .acquisitionOnly)
  static let gear = ScriptGearDefinition(
    id: resource, name: name, quantity: 1, loan: true, mount: nil, returnPolicy: "all")

  static func issuer(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c03-torenran-laboratory-v1:\(owner)")
  }

  static func serial(mission: UUID) -> UUID {
    OwnedGear.issuedIdentity(mission: mission, resource: resource, index: 0)
  }

  static func occupiedTonnes(in inventory: OwnedEquipmentInventory?) -> Int {
    inventory?.items.filter { $0.node == node }.count ?? 0
  }
}
