import Testing

@testable import L337Core

@Suite struct SalvageCatalogueTests {
  @Test func retainedSourceProfilesBindCurrentNamesAndExcludePendingOriginals() throws {
    let expected = Set(["SH005", "SH006", "SH012", "SH013", "SH014", "SH019", "SH028",
      "SH034", "SH102", "SH141"])
    #expect(Set(SalvageCatalogue.all.map(\.catalogueShipID)) == expected)
    #expect(SalvageCatalogue.all.count == expected.count)
    let names = ["SH005": "Bison", "SH006": "Bison Mk II", "SH012": "Sable Liner",
      "SH013": "Buffalo", "SH014": "Buffalo Mk II", "SH019": "Gazelle Explorer",
      "SH028": "Lion Citadel", "SH034": "Frog Station", "SH102": "Dhole Haven",
      "SH141": "Salamander Station"]
    for (id, name) in names {
      let profile = try #require(SalvageCatalogue.profile(catalogueShipID: id))
      #expect(profile.name == name && profile.basis.contains(name))
    }
    let pending = Set(OriginalFleetPendingSourceRegistrations.records.keys)
      .union(OriginalFleetRelativePendingSourceRegistrations.records.keys)
      .union(OriginalFleetLarvaalPendingSourceRegistrations.records.keys)
    for id in pending {
      #expect(SalvageCatalogue.profile(catalogueShipID: id) == nil)
      #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .abandoned) == .unsupportedHull)
    }
  }

  @Test func retainedSourceRolesKeepExistingLootProfilesWithoutAlienDefaults() throws {
    let expected: [String: SalvageSourceRole] = [
      "SH005": .commercialTrader, "SH012": .commercialTrader,
      "SH028": .station, "SH019": .generalShip,
    ]
    for (id, role) in expected {
      #expect(try #require(SalvageCatalogue.profile(catalogueShipID: id)).sourceRoles.contains(role))
    }
    for profile in SalvageCatalogue.all {
      #expect(SalvageLootProfiles.profile(roles: profile.sourceRoles) != nil)
    }
    #expect(SalvageCatalogue.profile(catalogueShipID: "SH123") == nil)
    #expect(SalvageCatalogue.profile(catalogueShipID: "SH171") == nil)
  }

  @Test func nonflyableObjectsAndOccupiedOrProtectedCounterpartsNeverBecomeFreeSalvage() {
    for id in ["SH156", "SH161", "SH162", "SH163", "SH164", "SH040", "SH125", "SH023", "SH999"] {
      #expect(SalvageCatalogue.profile(catalogueShipID: id) == nil)
      #expect(
        SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .abandoned) == .unsupportedHull
      )
    }
    for profile in SalvageCatalogue.all {
      let id = profile.catalogueShipID
      #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .abandoned) == .allowed)
      #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .occupied) == .occupied)
      #expect(SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .claimed) == .claimed)
      #expect(
        SalvageCatalogue.eligibility(catalogueShipID: id, ownership: .missionProtected)
          == .missionProtected)
      #expect(
        SalvageCatalogue.eligibility(
          catalogueShipID: id, ownership: .abandoned, activeStation: true) == .activeStation)
      #expect(
        SalvageCatalogue.eligibility(
          catalogueShipID: id, ownership: .abandoned, missionProtected: true) == .missionProtected)
    }
    for id in ["SH028", "SH034", "SH102", "SH141"] {
      #expect(SalvageCatalogue.profile(catalogueShipID: id)?.role == .abandonedInfrastructure)
    }
  }

  @Test func actualMeshBoundsMaterialsAndFaceWorkGeometryRemainUnnormalized() throws {
    let diagnostic = ASANAllocatorDiagnostic.begin(.catalogueMesh)
    defer { diagnostic?.checkpoint(.bodyExit) }
    for profile in SalvageCatalogue.all {
      diagnostic?.checkpoint(.profileEntry, argument: profile.catalogueShipID)
      let ship = try #require(ShipCatalogue.all.first { $0.id == profile.catalogueShipID })
      let mesh = ship.design.rawMesh
      diagnostic?.catalogueDetail(.oracleReady, profile: profile.catalogueShipID)
      #expect(profile.physicalScale == 1)
      #expect(profile.mesh.vertices == mesh.vertices && profile.mesh.faces == mesh.faces)
      #expect(
        profile.mesh.materials == mesh.materials && profile.mesh.faceMaterials == mesh.faceMaterials
      )
      diagnostic?.catalogueDetail(.cacheBefore, profile: profile.catalogueShipID)
      let cached = try #require(ShipCatalogue.rawMesh(profile.catalogueShipID))
      diagnostic?.catalogueDetail(.cacheAfter, profile: profile.catalogueShipID)
      expectSameMesh(profile.mesh, as: mesh)
      expectSameMesh(cached, as: mesh)
      let sharesVertices = profile.mesh.vertices.withUnsafeBufferPointer { profileVertices in
        cached.vertices.withUnsafeBufferPointer { cachedVertices in
          !profileVertices.isEmpty && profileVertices.baseAddress == cachedVertices.baseAddress
        }
      }
      #expect(sharesVertices)
      diagnostic?.catalogueDetail(.parityDone, profile: profile.catalogueShipID)
      #expect(profile.bounds.radius > 0 && profile.bounds.radius.isFinite)
      for vertex in mesh.vertices {
        #expect((vertex - profile.bounds.center).length <= profile.bounds.radius + 1e-8)
        #expect(vertex.x >= profile.minimum.x && vertex.x <= profile.maximum.x)
        #expect(vertex.y >= profile.minimum.y && vertex.y <= profile.maximum.y)
        #expect(vertex.z >= profile.minimum.z && vertex.z <= profile.maximum.z)
      }
      diagnostic?.catalogueDetail(.boundsDone, profile: profile.catalogueShipID)
      #expect(Set(profile.sections.map(\.index)).count == profile.sections.count)
      #expect(Set(profile.sections.map(\.sourceFaceIndex)).count == profile.sections.count)
      for section in profile.sections {
        #expect((10...30).contains(section.workSeconds) && section.radius > 0)
        #expect(abs(section.normal.length - 1) < 1e-8)
        let indices = mesh.faces[section.sourceFaceIndex]
        let vertices = indices.map { mesh.vertices[$0] }
        let center = vertices.reduce(Vector3(0, 0, 0), +) * (1 / Double(vertices.count))
        #expect((center - section.localPosition).length < 1e-8)
        let normal = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0]).unit
        #expect((normal - section.normal).length < 1e-8)
        #expect(vertices.allSatisfy { ($0 - center).length <= section.radius + 1e-8 })
        #expect(section.structural == (section.kind == .hull || section.kind == .cargo))
      }
    }
    diagnostic?.checkpoint(.profilesDone)
    let wolf = try #require(ShipCatalogue.ship("SH161"))
    #expect(wolf.name == "Wolf Citadel" && OriginalDetailedHullStage.blocksRuntime(wolf.id))
    #expect(SalvageCatalogue.profile(catalogueShipID: wolf.id) == nil)
    let wheel = try #require(SalvageCatalogue.profile(catalogueShipID: "SH141"))
    #expect(wheel.bounds.radius > 0)
    try expectActivatedOriginalTexturesAndSaigaScale(diagnostic: diagnostic)
    try expectDisabledProfileMeshesMatchResolvedRecords()
  }

  private func expectSameMesh(_ actual: Mesh, as expected: Mesh) {
    #expect(actual.vertices == expected.vertices)
    #expect(actual.faces == expected.faces)
    #expect(actual.details == expected.details)
    #expect(actual.materials == expected.materials)
    #expect(actual.faceMaterials == expected.faceMaterials)
    #expect(actual.faceTextures == expected.faceTextures)
  }

  private func expectActivatedOriginalTexturesAndSaigaScale(
    diagnostic: ASANAllocatorDiagnostic.Token?
  ) throws {
    for (id, vertices, faces) in [("SH012", 132, 228), ("SH019", 172, 304)] {
      diagnostic?.checkpoint(.textureBefore, argument: id)
      let original = try OriginalFleetShowroomModels.model(for: id)
      let mesh = original.nativeDesign.rawMesh
      #expect(mesh.vertices.count == vertices && mesh.faces.count == faces)
      #expect(original.nativeDesign.textures?.count == 3)
      #expect(mesh.faceTextures.count == faces && mesh.faceTextures.contains { $0 != nil })
      let profile = try #require(SalvageCatalogue.profile(catalogueShipID: id))
      let cached = try #require(ShipCatalogue.rawMesh(id))
      expectSameMesh(profile.mesh, as: mesh)
      expectSameMesh(cached, as: mesh)
      diagnostic?.checkpoint(.textureDone, argument: id)
    }
    diagnostic?.checkpoint(.haflingerBegin, argument: "SH061")
    let ship = try #require(ShipCatalogue.ship("SH061"))
    let physical = try OriginalHullPhysicalContract.saiga.get()
    let authored = physical.model.nativeDesign.rawMesh
    #expect(ship.name == "Saiga" && ship.nativeDesign == physical.model.nativeDesign)
    let cached = try #require(ShipCatalogue.rawMesh("SH061"))
    diagnostic?.checkpoint(.empBefore, argument: "SH061")
    let disabled = try #require(SalvageCatalogue.empProfile(catalogueShipID: "SH061"))
    diagnostic?.checkpoint(.empAfter, argument: "SH061")
    #expect(SalvageCatalogue.profile(catalogueShipID: "SH061") == nil)
    #expect(physical.metresPerSourceUnit == 20)
    #expect(cached.vertices != authored.vertices)
    expectSameMesh(cached, as: physical.physicalMesh)
    expectSameMesh(disabled.mesh, as: physical.physicalMesh)
    diagnostic?.checkpoint(.haflingerDone, argument: "SH061")
  }

  private func expectDisabledProfileMeshesMatchResolvedRecords() throws {
    for ship in ShipCatalogue.all
    where SalvageCatalogue.profile(catalogueShipID: ship.id) == nil {
      if OriginalDetailedHullStage.blocksRuntime(ship.id) {
        #expect(SalvageCatalogue.empProfile(catalogueShipID: ship.id) == nil)
        #expect(ShipCatalogue.rawMesh(ship.id) == nil)
        continue
      }
      guard ship.game != nil else {
        #expect(SalvageCatalogue.empProfile(catalogueShipID: ship.id) == nil)
        continue
      }
      let profile = try #require(SalvageCatalogue.empProfile(catalogueShipID: ship.id))
      let expected: Mesh
      if let physical = ship.physicalSourceContract {
        expected = physical.physicalMesh
      } else if ["SH005", "SH006", "SH007", "SH013", "SH014", "SH026"].contains(ship.id) {
        expected = try #require(ship.nativeDesign).rawMesh
      } else {
        expected = ship.design.rawMesh
      }
      #expect(profile.catalogueShipID == ship.id)
      #expect(profile.role == .disabledOrdinaryShip && profile.physicalScale == 1)
      expectSameMesh(profile.mesh, as: expected)
      try expectSectionGeometryMatchesArrayProjection(profile, mesh: expected)
      let cached = try #require(ShipCatalogue.rawMesh(ship.id))
      let sharesVertices = profile.mesh.vertices.withUnsafeBufferPointer { profileVertices in
        cached.vertices.withUnsafeBufferPointer { cachedVertices in
          !profileVertices.isEmpty && profileVertices.baseAddress == cachedVertices.baseAddress
        }
      }
      #expect(sharesVertices)
    }
  }

  private func expectSectionGeometryMatchesArrayProjection(_ profile: SalvageProfile, mesh: Mesh)
    throws
  {
    for section in profile.sections {
      try #require(mesh.faces.indices.contains(section.sourceFaceIndex))
      let indices = mesh.faces[section.sourceFaceIndex]
      try #require(indices.count >= 3 && indices.allSatisfy(mesh.vertices.indices.contains))
      let vertices = indices.map { mesh.vertices[$0] }
      let cross = (vertices[1] - vertices[0]).cross(vertices[2] - vertices[0])
      try #require(cross.length > 1e-8)
      let midpoint = vertices.reduce(Vector3(0, 0, 0), +) * (1 / Double(vertices.count))
      let normal = cross * (1 / cross.length)
      let radius = try #require(vertices.map { ($0 - midpoint).length }.max())
      #expect(section.localPosition == midpoint)
      #expect(section.normal == normal)
      #expect(section.radius == radius)
    }
  }

  @Test func workSurfaceIDsArePersistentAndTechnologyMetadataResolvesEveryCategory() throws {
    let wreck = WreckIdentity(system: .init(galaxy: 0, system: 7), site: 1, lineage: 123)
    var categories: Set<String> = []
    for profile in SalvageCatalogue.all {
      let surfaces = profile.surfaces(wreck: wreck)
      #expect(surfaces.count == profile.sections.count)
      #expect(surfaces == profile.surfaces(wreck: wreck))
      for (section, surface) in zip(profile.sections, surfaces) {
        #expect(surface.section.wreck == wreck && surface.section.section == section.index)
        #expect(surface.position == section.localPosition && surface.normal == section.normal)
        for id in section.technologyDefinitionIDs {
          _ = try #require(SalvageDefinitions.definition(id: id))
          categories.insert(id)
        }
      }
    }
    #expect(
      categories == [
        "computer-core", "drive-technology", "laser-technology", "shield-technology",
        "missile-standard", "missile-guided", "missile-heavy", "missile-ecm-resistant",
        "laser-hardpoint", "missile-pylon", "spare-escape-pod", "alien-artefact",
      ])
  }
}
