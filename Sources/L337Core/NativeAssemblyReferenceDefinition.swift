import Foundation

/// Voss's one original carried instrument; never shop stock, a fitted console or a spare.
enum NativeAssemblyReferenceDefinition {
  static let resource = "assembly-of-orbits-reference"
  static let name = "Assembly Reference Instrument"
  static let node = EquipmentNodeID(family: .init("c23-assembly-reference"), key: name)
  static let cargoTonnes = 1
  static let purchaseNode = EquipmentPurchaseNode(id: node, displayName: name, policy: .acquisitionOnly)
  static let gear = ScriptGearDefinition(
    id: resource, name: name, quantity: 1, loan: true, mount: nil, returnPolicy: "all")

  static func issuer(owner: UUID) -> UUID {
    ScriptIdentity.uuid("c23-irkenan-voss-reference-owner-v1:\(owner)")
  }

  static func serial(mission: UUID) -> UUID {
    OwnedGear.issuedIdentity(mission: mission, resource: resource, index: 0)
  }

  static func occupiedTonnes(in inventory: OwnedEquipmentInventory?) -> Int {
    inventory?.items.filter { $0.node == node }.count ?? 0
  }
}
