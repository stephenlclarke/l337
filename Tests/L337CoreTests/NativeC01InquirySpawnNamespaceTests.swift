import Testing

@testable import L337Core

/// Syntactic spawn DATA only; no native actor, admission or namespace is issued.
struct NativeC01InquirySpawnNamespaceTests {
  @Test(arguments: [UInt64(0), 1, 2, UInt64.max])
  func unissuedInquiryNamespaceCannotPassAnyFlightCursor(sequence: UInt64) {
    let system = SystemIdentity(galaxy: 0, system: 7)
    let spawn = SpawnIdentity(system: system, visit: 1, sequence: sequence,
      member: 0, producer: .c01Inquiry)
    for cursor in [UInt64(0), 1, 2, UInt64.max] {
      #expect(!NativeMissionSpawnAddress.isCurrent(spawn, system: system,
        visit: 1, nextFlightSpawn: cursor))
    }
  }

  @Test(arguments: [SpawnProducer.mission, .ordnance])
  func existingSharedFlightNamespacesKeepTheirAllocatedBoundary(producer: SpawnProducer) {
    let system = SystemIdentity(galaxy: 0, system: 7)
    for sequence in [UInt64(0), 1, 2, 3] {
      let spawn = SpawnIdentity(system: system, visit: 1, sequence: sequence,
        member: 0, producer: producer)
      #expect(NativeMissionSpawnAddress.isCurrent(spawn, system: system,
        visit: 1, nextFlightSpawn: 3) == (sequence == 1 || sequence == 2))
      #expect(!NativeMissionSpawnAddress.isCurrent(spawn, system: system,
        visit: 2, nextFlightSpawn: 3))
      #expect(!NativeMissionSpawnAddress.isCurrent(spawn,
        system: .init(galaxy: 0, system: 8), visit: 1, nextFlightSpawn: 3))
    }
  }

  @Test(arguments: [SpawnProducer.ambient, .asteroids, .cargo, .mining, .salvage,
    .security, .persistence, .derelicts, .emp, .provider])
  func existingSeparateNamespacesRetainZeroBasedAddressPolicy(producer: SpawnProducer) {
    let system = SystemIdentity(galaxy: 0, system: 7)
    let spawn = SpawnIdentity(system: system, visit: 1, sequence: 0,
      member: 0, producer: producer)
    #expect(NativeMissionSpawnAddress.isCurrent(spawn, system: system,
      visit: 1, nextFlightSpawn: 0))
    #expect(!NativeMissionSpawnAddress.isCurrent(spawn, system: system,
      visit: 2, nextFlightSpawn: 0))
  }
}
