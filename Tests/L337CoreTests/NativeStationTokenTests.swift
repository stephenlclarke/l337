import Foundation
import Testing

@testable import L337Core

@Test func stationIdentityTokensKeepExactASCIIAndByteBoundsWithoutGrantingSourceAuthority() throws {
  let source = try #require(NativeStationSource.bindings.first)
  let world = UUID()
  func identity(_ key: String) -> NativeStationIdentity {
    .init(
      world: world, system: source.system, definition: source.descriptor.definition,
      version: source.descriptor.version, key: key)
  }
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._"
  for value in UInt32(0)...255 {
    let character = String(try #require(UnicodeScalar(value)))
    let candidate = identity(character)
    #expect(!candidate.valid && NativeStationSource.binding(for: candidate) == nil)
    #expect(throws: SaveError.invalidCommander) {
      _ = try JSONDecoder().decode(NativeStationIdentity.self, from: JSONEncoder().encode(candidate))
    }
  }
  // Valid station identities are exact adopted sites, not arbitrary well-formed ASCII tokens.
  for key in [
    alphabet, String(repeating: "A", count: 80),
    "", String(repeating: "A", count: 81), "A B", "A/B", "A:B", "A\nB", "A\0B",
    "A\u{200D}B", "e\u{301}", "\u{FF21}", String(repeating: "\u{E9}", count: 40),
  ] {
    let candidate = identity(key)
    #expect(!candidate.valid && NativeStationSource.binding(for: candidate) == nil)
    #expect(throws: SaveError.invalidCommander) {
      _ = try JSONDecoder().decode(NativeStationIdentity.self, from: JSONEncoder().encode(candidate))
    }
  }
  let actual = source.identity(world: world)
  #expect(actual.valid && NativeStationSource.binding(for: actual) == source)
  let alias = identity(actual.key + ".")
  #expect(!alias.valid && NativeStationSource.binding(for: alias) == nil)
  let outsideLocalSource = NativeStationIdentity(
    world: world, system: .init(galaxy: source.system.galaxy, system: 256),
    definition: source.descriptor.definition, version: source.descriptor.version, key: actual.key)
  #expect(!outsideLocalSource.valid && NativeStationSource.binding(for: outsideLocalSource) == nil)
}
