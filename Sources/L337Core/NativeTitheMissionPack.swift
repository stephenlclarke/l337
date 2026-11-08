import Foundation

extension NativeTitheCommissionDefinition {
  static let nativeCapability = "native-tithe-commission-v1"
  static let originalSourceSHA256 = "1fe19892fe4cff0da61da5d547dfb6eebb8842b15680607b8adf69dfa238a67a"
  static let originalObjectivesSHA256 = "7967de35116df4b73489e13b155f8ce59593bc318fcc3e09fc72eb42f682539d"
  static let manifestSHA256 = "b19a24cf9171802487ae350c78cbb6823e8b5168e25bc7891ebee03e73e4b414"
  static let moduleSHA256 = "8279601c2528e2ef16ecc3da55d0b19a733d6b31450d9d92f39f86a60aeb7f54"

  static func applies(_ pack: borrowing ScriptPack) -> Bool {
    if pack.manifest.stateID == stateID { return true }
    return pack.digest == digest
  }

  /// Exact content identity only. A valid pack issues no native desk, person or apparatus.
  static func matches(_ pack: borrowing ScriptPack) -> Bool {
    guard pack.manifest.stateID == stateID, pack.manifest.version == version, pack.digest == digest,
      ScriptPackLibrary.hash(pack.manifestBytes) == manifestSHA256,
      ScriptPackLibrary.hash(pack.source) == moduleSHA256, pack.entryBytes == pack.source,
      pack.models.isEmpty, pack.resourceBytes.isEmpty,
      pack.manifest.mission.title == "The Tithe of Worlds",
      pack.manifest.mission.milestones == NativeTitheOriginalStage.allCases.map(\.objective),
      pack.manifest.handlers.count == 1,
      pack.manifest.handlers.first?.event == "mission.accepted",
      pack.manifest.handlers.first?.function == "accepted",
      Set(pack.manifest.capabilities) == Set(["script-lua-v1", "story-v2", "durable-commands-v2", nativeCapability])
    else { return false }
    return true
  }

  static func validateDeclaration(_ manifest: ScriptManifest) throws {
    guard manifest.stateID == stateID else {
      guard !manifest.capabilities.contains(nativeCapability) else {
        throw MissionPackError("The native Tithe capability belongs only to its original definition.")
      }
      return
    }
    guard manifest.version == version, manifest.module == "scripts/main.lua",
      manifest.mission.title == "The Tithe of Worlds",
      manifest.mission.milestones == NativeTitheOriginalStage.allCases.map(\.objective),
      manifest.handlers.count == 1, manifest.handlers.first?.event == "mission.accepted",
      manifest.handlers.first?.function == "accepted", manifest.courier == nil,
      manifest.board == nil, manifest.providerContract == nil, manifest.equipment == nil,
      manifest.encounters == nil, manifest.npcs == nil, manifest.modules == nil,
      manifest.trial == nil,
      Set(manifest.capabilities) == Set(["script-lua-v1", "story-v2", "durable-commands-v2", nativeCapability])
    else { throw MissionPackError("Restore the original fourteen-stage Tithe of Worlds definition.") }
  }
}

extension ScriptPackLibrary {
  static var bundledTitheOfWorldsDirectory: URL {
    bundledCourierDirectory.deletingLastPathComponent().appendingPathComponent("l337-tithe-of-worlds")
  }
}

extension Game {
  var titheCommissionPack: ScriptPack? {
    scriptPacks.first(where: NativeTitheCommissionDefinition.matches)
  }

  func titheCommissionUnavailable(_ pack: borrowing ScriptPack) -> String? {
    guard NativeTitheCommissionDefinition.matches(pack) else {
      return "Restore the original fourteen-stage Tithe of Worlds definition."
    }
    guard titheCommissionMission != nil else {
      return NativeTitheCommissionContactSource.unavailable
    }
    guard NativeTitheCommissionSave.validateClaims(commander) else {
      return "The original Tithe commission and native desk history cannot currently be verified."
    }
    return nil
  }
}
