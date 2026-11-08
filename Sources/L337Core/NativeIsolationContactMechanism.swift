import Foundation

/// Identifies what the native meter establishes; zero energy never means an open contact.
enum NativeIsolationProofKind: String, Codable, Sendable {
  case energizedFlow, dryMechanical

  static func connectedReading(_ meter: NativeIsolationMeterEvidence) -> Self? {
    guard meter.valid, meter.contact == .connected else { return nil }
    if meter.transferred > 0, meter.before.remainingSupply > 0, meter.before.headroom > 0 {
      return .energizedFlow
    }
    if meter.transferred == 0, meter.before == meter.after,
      meter.before.remainingSupply == 0, meter.before.headroom == 0
    {
      return .dryMechanical
    }
    return nil
  }

  func permitsOpening(_ meter: NativeIsolationMeterEvidence) -> Bool {
    Self.connectedReading(meter) == self && matchesIsolatedAccounts(meter.after)
  }

  func matchesIsolatedAccounts(_ accounts: NativeIsolationEnergyAccounts) -> Bool {
    guard accounts.valid else { return false }
    switch self {
    case .energizedFlow: return accounts.remainingSupply > 0 && accounts.headroom > 0
    case .dryMechanical: return accounts.remainingSupply == 0 && accounts.headroom == 0
    }
  }
}

/// Receipt for the switch actually consumed by NativeIsolationEnergyAccounts.transfer.
/// Its saved epoch is historical evidence; only a fresh endpoint can issue a live change.
struct NativeIsolationContactChange: Codable, Equatable, Sendable {
  let epoch: UUID
  let source: UUID
  let module: UUID
  let supply: UUID
  let load: UUID
  let before: NativeIsolationContact
  let after: NativeIsolationContact
  let proof: NativeIsolationProofKind

  func valid(
    authority: NativeIsolationMeasurementAuthority, operation: UUID, revision: UInt64,
    meter: NativeIsolationMeterEvidence
  ) -> Bool {
    let original = NativeIsolationWorkSource(owner: authority.owner)
    return source == original.id && source == authority.source
      && module == original.module(authority.role) && module == authority.module
      && supply == original.supply(authority.role) && load == original.load(authority.role)
      && before == .connected && meter.contact == before
      && after == .latchedOpen(operation: operation, revision: revision)
      && proof.permitsOpening(meter)
  }
}
