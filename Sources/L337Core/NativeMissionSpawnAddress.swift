enum NativeMissionSpawnAddress {
  /// Mission actors and ordnance use the shared flight allocator. Other native
  /// producers own their sequence namespaces, including valid zero-based counters.
  static func isCurrent(
    _ spawn: SpawnIdentity, system: SystemIdentity, visit: UInt64, nextFlightSpawn: UInt64
  ) -> Bool {
    guard spawn.system == system, spawn.visit == visit else { return false }
    switch spawn.producer {
    case .mission, .ordnance:
      return spawn.sequence > 0 && spawn.sequence < nextFlightSpawn
    case .c01Inquiry:
      // The native Inquiry producer has not installed a current namespace yet.
      return false
    default:
      return true
    }
  }
}
