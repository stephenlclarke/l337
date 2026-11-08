import Foundation
import Testing

@testable import L337Core

/// Structural storage and codec inputs; these tests publish no mission evidence.
struct NativeGlassMeridianStateStorageTests {
  private func permission(
    _ value: NativeGlassMeridianPermission, physicalTime: Double
  ) -> NativeGlassMeridianPermission {
    .init(
      mission: value.mission, operation: value.operation, owner: value.owner, dock: value.dock,
      carrier: value.carrier, inventoryRevision: value.inventoryRevision, fit: value.fit,
      visited: value.visited, identified: value.identified, physicalTime: physicalTime)
  }

  @Test func copiedArraysDetachAndEqualityKeepsNaNAndSignedZeroSemantics() throws {
    let fixture = NativeGlassMeridianUnitTests()
    let original = try fixture.fixture()
    let retained = original
    var changed = original
    let sealed = try fixture.sealed(original, ordinal: 0)
    changed.readings.append(sealed)
    changed.losses.append(
      .init(ordinal: 0, generation: 0, marker: sealed.authority.marker, physicalTime: 1))
    #expect(original == retained && original.readings.isEmpty && original.losses.isEmpty)
    #expect(changed.readings.count == 1 && changed.losses.count == 1 && changed != original)

    let nan = NativeGlassMeridianState(
      permission: permission(original.permission, physicalTime: .nan))
    let copiedNaN = nan
    #expect(nan.permission.physicalTime.isNaN && copiedNaN.permission.physicalTime.isNaN)
    #expect(nan != copiedNaN)

    let positiveZero = NativeGlassMeridianState(
      permission: permission(original.permission, physicalTime: 0.0))
    let negativeZero = NativeGlassMeridianState(
      permission: permission(original.permission, physicalTime: -0.0))
    #expect(positiveZero == negativeZero)
    #expect(positiveZero.permission.physicalTime.sign == .plus)
    #expect(negativeZero.permission.physicalTime.sign == .minus)
  }

  @Test func populatedOptionalRecordsDetachWithoutChangingTheRetainedCapture() throws {
    let fixture = try C01SurveyorFixture()
    let original = try fixture.held()
    let capture = try #require(original.surveyor?.capture)
    var changed = original
    changed.surveyor?.capture = nil
    changed.readings.removeLast()
    #expect(changed.surveyor?.capture == nil && changed.readings.count == 1)
    #expect(original.surveyor?.capture == capture && original.readings.count == 2)
    #expect(changed != original)
  }

  @Test func throwingNestedModifyRetainsPartialChangesOnlyInItsWritableCopy() throws {
    enum Expected: Error { case stop }
    func clearThenThrow(_ state: inout NativeGlassMeridianState) throws {
      state.readings.removeAll()
      state.surveyor?.capture = nil
      throw Expected.stop
    }
    let fixture = try C01SurveyorFixture()
    let original = try fixture.held()
    let retained = original
    var changed = original
    #expect(throws: Expected.self) { try clearThenThrow(&changed) }
    #expect(changed.readings.isEmpty && changed.surveyor?.capture == nil)
    #expect(original == retained && original.readings.count == 2)
    #expect(original.surveyor?.capture != nil)
    changed.readings = original.readings
    changed.surveyor?.capture = original.surveyor?.capture
    #expect(changed == original)
  }

  @Test func currentJSONKeepsItsDirectFieldsAndHasNoStorageEnvelope() throws {
    let fixture = try C01SurveyorFixture()
    let original = try fixture.held()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let bytes = try encoder.encode(original)
    let object = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    #expect(Set(object.keys) == ["permission", "readings", "losses", "surveyor"])
    #expect(object["storage"] == nil && object["value"] == nil)
    let decoded = try JSONDecoder().decode(NativeGlassMeridianState.self, from: bytes)
    #expect(decoded == original)
    #expect(try encoder.encode(decoded) == bytes)
    let wrapped = try JSONSerialization.data(withJSONObject: ["storage": [object]])
    #expect(throws: (any Error).self) {
      try JSONDecoder().decode(NativeGlassMeridianState.self, from: wrapped)
    }
  }

  @Test func fullInitializerAndExistingReadingValidatorsKeepTheirValueContract() throws {
    let fixture = try C01SurveyorFixture()
    let original = try fixture.held()
    let rebuilt = NativeGlassMeridianState(
      permission: original.permission, readings: original.readings, losses: original.losses,
      surveyor: original.surveyor, reservationCase: original.reservationCase,
      timingStandard: original.timingStandard, laneRepair: original.laneRepair)
    #expect(rebuilt == original)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    #expect(try encoder.encode(rebuilt) == encoder.encode(original))
    #expect(NativeGlassMeridian.readingsValid(original))
    #expect(NativeGlassMeridian.lossesValid(original))
    var duplicate = rebuilt
    duplicate.readings.append(duplicate.readings[0])
    #expect(!NativeGlassMeridian.readingsValid(duplicate))
    #expect(original.readings.count == 2 && rebuilt.readings.count == 2)
  }
}
