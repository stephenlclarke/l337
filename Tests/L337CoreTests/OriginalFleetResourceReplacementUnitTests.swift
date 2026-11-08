import Foundation
import Testing

@testable import L337Core

struct OriginalFleetResourceReplacementUnitTests {
  @Test func larvaalSourcesKeepTheirOwnRolesUnitsAndMissingEvidenceWithoutHumanDefaults() throws {
    #expect(OriginalFleetLarvaalPendingSourceRegistrations.records.count == 15)
    var game = Game(executive: false)
    let before = game.commander
    for (id, entry) in OriginalFleetLarvaalPendingSourceRegistrations.records {
      let ship = try #require(ShipCatalogue.ship(id))
      let current = try #require(OriginalFleetR3Data.contract(for: id))
      let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
      try OriginalDetailedHullStage.authenticate(ship, bytes: bytes)
      #expect(try OriginalPlayerHullActivation.resolve(ship) == ship)
      #expect(ship.game == current.performance && ship.name == current.name)
      #expect(ship.catalogue.origin == .alien && current.origin == .larvaal)
      #expect(ship.catalogue.primaryType == .alien && ship.catalogue.primaryRole == nil)
      #expect(ship.catalogue.roleWeights.isEmpty && ship.catalogue.galaxies.isEmpty)
      #expect(ship.catalogue.regions.isEmpty && !ship.catalogue.readyForNaturalEncounters)
      #expect(!ship.catalogue.playerFlyable && !ship.catalogue.normalPurchaseEligible)
      #expect(ship.catalogue.minimumBuildTechLevel == nil && ship.catalogue.aliases?.isEmpty == true)
      #expect(ship.nativeHull == nil && ship.nativeCombat == nil)
      let fit = try ShipAccommodationProfile(ship: ship)
      #expect(fit.operatingCrew == current.accommodation?.operatingCrew)
      #expect(fit.equipmentUnits == current.fitting?.equipmentUnits)
      if id == "SH123" {
        let accepted = try OriginalFleetShowroomModels.model(for: id)
        #expect(ship.design == accepted.nativeDesign && ship.nativeDesign == nil)
        #expect(entry.metresPerSourceUnit == "unissued" && entry.physicalRecordSHA256 == nil)
        #expect(throws: OriginalDetailedHullStage.Failure.nativeSourceUnissued(id)) {
          try OriginalDetailedHullStage.requireRuntime(id)
        }
      } else if entry.sourceNativeFaces <= 512 {
        try #require(entry.physicalRecordSHA256 != nil && entry.metresPerSourceUnit == "1")
        let source = try OriginalFleetCurrentHullSource(id: id)
        #expect(source.engineering.id == id && source.engineering.metresPerSourceUnit == 1)
        let physical = try #require(ship.physicalSourceContract)
        #expect(physical.engineering?.id == id && physical.physicalMesh.vertices == source.mesh.vertices)
        #expect(OriginalFleetRuntimeHullSource.source(for: id) == nil)
        #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
          id: id, sourceFaces: entry.sourceNativeFaces)) {
          try OriginalDetailedHullStage.requireRuntime(id)
        }
      } else {
        #expect(entry.sourceNativeFaces > 512)
        #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
          id: id, actualSourceFaces: entry.sourceNativeFaces, maximum: 512)) {
          try OriginalDetailedHullStage.requireRuntime(id)
        }
      }
      #expect(ShipCatalogue.rawMesh(id) == nil && game.shipTradeQuote(for: ship) == nil)
      #expect(SalvageCatalogue.empProfile(catalogueShipID: id) == nil)
      #expect(!ScriptNPCModel.referenceValid("catalogue:" + id))
      #expect(throws: (any Error).self) {
        try game.commander.transferEquipment(to: id, hullID: UUID())
      }
      #expect(game.commander == before)
    }
    let drone = try #require(OriginalFleetR3Data.contract(for: "SH125")?.accommodation)
    #expect(drone.nativeAutonomous && drone.nativeCrew == 0 && drone.conversionCrew == 1)
    let medusa = try #require(ShipCatalogue.ship("SH171"))
    #expect(OriginalFleetR3Data.contract(for: medusa.id)?.purchasePolicy == .plughQuestFabrication)
    #expect(medusa.catalogue.purchasePolicy == .never && !medusa.catalogue.discoveryEligible)
    game.commander.xyzzyActive = true
    let enabled = game.commander
    #expect(game.shipTradeQuote(for: medusa) == nil && game.commander == enabled)
  }

  @Test func relativeHumanResourcesKeepCurrentR3AndExactUnscaledOriginalSource() throws {
    #expect(OriginalFleetRelativePendingSourceRegistrations.records.count == 73)
    for (id, entry) in OriginalFleetRelativePendingSourceRegistrations.records {
      let ship = try #require(ShipCatalogue.ship(id))
      let contract = try #require(OriginalFleetR3Data.contract(for: id))
      let performance = try #require(ship.game)
      let engineering = try #require(OriginalFleetPhysicalData.registrations[id])
      let source = try OriginalFleetShowroomModels.model(for: id)
      let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
      try OriginalDetailedHullStage.authenticate(ship, bytes: bytes)
      #expect(try OriginalPlayerHullActivation.resolve(ship) == ship)
      #expect(ship.name == contract.name && ship.catalogue.family == contract.family)
      #expect(ship.catalogue.origin == .human && contract.origin == .human)
      #expect(ship.game == contract.performance && ship.nativeDesign == source.nativeDesign)
      #expect(source.sourceSHA256 == entry.nativeSourceSHA256)
      #expect(ship.design.vertices.count == entry.detailedVertices)
      #expect(ship.design.faces.count == entry.detailedFaces)
      #expect(ship.nativeDesign?.faces.count == entry.sourceNativeFaces)
      #expect(ship.nativeHull == nil && ship.nativeCombat == nil)
      #expect(entry.metresPerSourceUnit == engineering.calibration.exactScale)
      #expect(entry.physicalRecordSHA256 == engineering.sha256)
      #expect(ship.catalogue.aliases?.isEmpty == true)
      #expect(ship.catalogue.minimumBuildTechLevel == nil && ship.catalogue.rarity == .pending)
      #expect(ship.catalogue.roleWeights.isEmpty && !ship.catalogue.readyForNaturalEncounters)
      #expect(!ship.catalogue.playerFlyable && !ship.catalogue.normalPurchaseEligible)
      let standard = try #require(ship.profiles.first { $0.group == "project-refit-v1" })
      #expect(Set(standard.fields.map(\.key)).count == standard.fields.count)
      #expect(standard.fields.first { $0.key == "maximum_speed_project_units" }?.number == ship.game?.speed)
      #expect(standard.fields.first { $0.key == "fuel_capacity_tenths_ly" }?.number == Double(performance.fuel))
      let fit = try ShipAccommodationProfile(ship: ship)
      #expect(fit.equipmentUnits == contract.fitting?.equipmentUnits)
      #expect(fit.operatingCrew == contract.accommodation?.operatingCrew)
      #expect(throws: OriginalDetailedHullStage.Failure.invalidDetailedResource(id)) {
        try OriginalDetailedHullStage.authenticate(ship, bytes: bytes + Data("\n".utf8))
      }
    }
  }

  @Test func relativeSourcePresenceCannotBypassNativeLimitOrSharedRuntimeGuards() throws {
    var game = Game(executive: false)
    let before = game.commander
    for (id, entry) in OriginalFleetRelativePendingSourceRegistrations.records {
      let ship = try #require(ShipCatalogue.ship(id))
      if entry.sourceNativeFaces > 512 {
        #expect(throws: OriginalDetailedHullStage.Failure.nativeLODUnqualified(
          id: id, actualSourceFaces: entry.sourceNativeFaces, maximum: 512)) {
          try OriginalDetailedHullStage.requireRuntime(id)
        }
      } else {
        #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
          id: id, sourceFaces: entry.sourceNativeFaces)) {
          try OriginalDetailedHullStage.requireRuntime(id)
        }
      }
      #expect(ShipCatalogue.rawMesh(id) == nil)
      #expect(SalvageCatalogue.empProfile(catalogueShipID: id) == nil)
      #expect(!ScriptNPCModel.referenceValid("catalogue:" + id))
      #expect(game.shipTradeQuote(for: ship) == nil)
      #expect(throws: (any Error).self) {
        try game.commander.transferEquipment(to: id, hullID: UUID())
      }
      #expect(game.commander == before)
    }
  }

  @Test func currentResourcesRetainExactSelectedNativeSourceAndIssuedEngineeringIdentity() throws {
    #expect(OriginalFleetPendingSourceRegistrations.records.count == 49)
    for id in OriginalFleetPendingSourceRegistrations.records.keys.sorted() {
      let ship = try #require(ShipCatalogue.ship(id))
      let registration = try #require(OriginalDetailedHullStage.registration(for: id))
      let current = try #require(OriginalFleetR3Data.contract(for: id))
      let selected = try OriginalFleetShowroomModels.model(for: id)
      let bytes = try Data(contentsOf: ShipCatalogue.folder.appendingPathComponent(id + ".toml"))
      try OriginalDetailedHullStage.authenticate(ship, bytes: bytes)
      #expect(try OriginalPlayerHullActivation.resolve(ship) == ship)
      #expect(ship.name == current.name && ship.catalogue.family == current.family)
      #expect(ship.game == current.performance)
      #expect(ship.nativeDesign == selected.nativeDesign)
      #expect(ship.design.vertices.count == registration.detailedVertices)
      #expect(ship.design.faces.count == registration.detailedFaces)
      #expect(ship.nativeHull == nil && ship.nativeCombat == nil)
      #expect(ship.originalDefinition?.sourceSHA256 == current.sourceSHA256)
      #expect(Array(ship.sourceProfilesIncludingOriginal.dropLast()) == ship.profiles)
      #expect(ship.sourceProfilesIncludingOriginal.last?.fields.contains {
        $0.key == "original.sourceSHA256" && $0.text == current.sourceSHA256
      } == true)
      #expect(ship.catalogue.aliases?.isEmpty == true)
      let standard = try #require(ship.profiles.first { $0.group == "project-refit-v1" })
      #expect(Set(standard.fields.map(\.key)).count == standard.fields.count)
      #expect(standard.fields.first { $0.key == "maximum_speed_project_units" }?.number == ship.game?.speed)
      #expect(standard.fields.first { $0.key == "hyperspace_range_ly" }?.unit == "LY")
      #expect(standard.fields.first { $0.key == "cargo_tonnes" }?.unit == "t")
      #expect(standard.fields.first { $0.key == "hull_price_credits" }?.unit == "CR")
      let accommodation = try ShipAccommodationProfile(ship: ship)
      #expect(accommodation.equipmentUnits == current.fitting?.equipmentUnits)
      #expect(accommodation.maximumPhysicalCabinModules == current.accommodation?.maximumCabins)
      let source = try OriginalFleetCurrentHullSource(id: id)
      #expect(source.contract.sourceSHA256 == current.sourceSHA256)
      #expect(source.model.nativeDesign == selected.nativeDesign)
    }
    #expect(ShipCatalogue.ship("SH036")?.name == "Zebu")
    #expect(ShipCatalogue.ship("SH036")?.searchText.contains("Drake") == false)
  }

  @Test func sourceReplacementDoesNotInventPopulationTechnologyOrPlayerRights() throws {
    for id in OriginalFleetPendingSourceRegistrations.records.keys.sorted() {
      let ship = try #require(ShipCatalogue.ship(id))
      #expect(ship.catalogue.valid(shipID: id, performance: ship.game, nativeCombat: nil))
      #expect(ship.catalogue.minimumBuildTechLevel == nil && ship.catalogue.rarity == .pending)
      #expect(ship.catalogue.galaxies.isEmpty && ship.catalogue.regions.isEmpty)
      #expect(ship.catalogue.roleWeights.isEmpty && !ship.catalogue.readyForNaturalEncounters)
      #expect(!ship.catalogue.playerFlyable && !ship.catalogue.normalPurchaseEligible)
      #expect(ship.catalogue.mechanicsStatus == .pending && ship.catalogue.placementStatus == .pending)
      if ["SH043", "SH081"].contains(id) {
        #expect(ship.catalogue.purchasePolicy == .never)
        #expect(ship.catalogue.collectionMilestone == .destruction && ship.game?.price == 0)
      } else {
        #expect(ship.catalogue.purchasePolicy == .pendingFabrication)
        #expect(ship.catalogue.collectionMilestone == .blueprintAndFabrication)
      }
    }
  }

  @Test func evenSmallNativeSourcesCannotBypassPendingAdmissionFittingOrAcquisition() throws {
    var game = Game(executive: false)
    let before = game.commander
    for id in OriginalFleetPendingSourceRegistrations.records.keys.sorted() {
      let ship = try #require(ShipCatalogue.ship(id))
      let registration = try #require(OriginalDetailedHullStage.registration(for: id))
      #expect(throws: OriginalDetailedHullStage.Failure.nativeEvidencePending(
        id: id, sourceFaces: registration.sourceNativeFaces)) {
        try OriginalDetailedHullStage.requireRuntime(id)
      }
      #expect(ShipCatalogue.rawMesh(id) == nil)
      #expect(SalvageCatalogue.empProfile(catalogueShipID: id) == nil)
      #expect(!ScriptNPCModel.referenceValid("catalogue:" + id))
      #expect(game.shipTradeQuote(for: ship) == nil)
      #expect(throws: (any Error).self) {
        try game.commander.transferEquipment(to: id, hullID: UUID())
      }
      #expect(game.commander == before)
    }
  }
}
