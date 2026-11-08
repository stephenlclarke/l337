import Foundation
import Testing

@testable import L337Core

/// Address/shape checks only; these fixtures never claim an actual living source person.
struct NativeC03CrewIdentityUnitTests {
  @Test func exactlySixOriginalAddressesMatchTheSingleCurrentSourceRecipe() throws {
    let owner = UUID(), mission = UUID()
    let recipe = try NativeC03EvacuationAccommodation.candidate(owner: owner, mission: mission)
    for (ordinal, assignment) in recipe.assignments.enumerated() {
      let person = NativeC03CrewIdentity(owner: owner, mission: mission, ordinal: ordinal)
      #expect(person.valid && person == assignment.person)
      #expect(person.source == recipe.source)
      #expect(person.id == ScriptIdentity.uuid(person.key))
    }
    #expect(Set(recipe.assignments.map(\.person)).count == 6)
  }

  @Test(arguments: [Int.min, -1, 6, Int.max])
  func addressesOutsideTheOriginalSixCannotValidate(_ ordinal: Int) {
    let owner = UUID(), mission = UUID()
    let person = NativeC03CrewIdentity(owner: owner, mission: mission, ordinal: ordinal)
    #expect(!person.valid)
    #expect(!person.belongsTo(owner: owner, mission: mission, source: person.source))
  }

  @Test func wrongOwnerMissionSourceOrOrdinalCannotAliasAnOriginal() throws {
    let owner = UUID(), mission = UUID()
    let person = NativeC03CrewIdentity(owner: owner, mission: mission, ordinal: 0)
    let next = NativeC03CrewIdentity(owner: owner, mission: mission, ordinal: 1)
    #expect(person.id != next.id && person.source == next.source)
    #expect(!person.belongsTo(owner: UUID(), mission: mission, source: person.source))
    #expect(!person.belongsTo(owner: owner, mission: UUID(), source: person.source))
    #expect(!person.belongsTo(owner: owner, mission: mission, source: UUID()))
    let encoded = try JSONEncoder().encode(person)
    #expect(try JSONDecoder().decode(NativeC03CrewIdentity.self, from: encoded) == person)
  }
}
