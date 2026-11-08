import Foundation

/// Runtime-only reader of the existing recovered original. It owns no source document,
/// observation, permission or receipt, and accepts no caller-supplied register contents.
struct NativeC03RecoveredArchiveReader: Equatable, Sendable {
  enum Section: Int, CaseIterable, Equatable, Sendable {
    case declarations, firstSeal, secondSeal, wakeReferences, crewNotice
  }
  enum Step: Equatable, Sendable { case previous, next }
  enum ReaderError: Error, Sendable { case staleView }

  enum Basis: Equatable, Sendable {
    case documentClaim, observedSealReference, recordedWakeReference, recordedComparison, requirement
  }
  struct Row: Equatable, Sendable {
    let label: String
    let value: String
    let basis: Basis
    /// An existing record/inspection identifier for presentation, never a new capability.
    let reference: UUID?
  }
  struct Page: Equatable, Sendable {
    let section: Section
    let register: UUID
    let transfer: UUID
    let title: String
    let rows: [Row]
    let notice: String
  }

  private struct Context: Equatable, Sendable {
    let mission: UUID
    let revision: UInt64
    let register: UUID
    let transfer: UUID
    let comparison: UUID
    let kit: NativeHollowManifestKitBinding
    let epoch: UUID
  }
  private struct Source: Sendable {
    let context: Context
    let held: NativeC03HeldRegisterData
    let inspections: [NativeC03SealLaboratoryAnalysis.Observation]
    let wakes: [NativeC03WakeTrail.Observation]
  }

  private let context: Context
  private(set) var section: Section = .declarations

  private init(source: Source) { context = source.context }

  static func open(in game: borrowing Game) throws -> Self {
    try .init(source: Self.source(in: game))
  }

  /// Input availability reuses the same original/current-source check as a read.
  /// This is not a permission and creates no page, observation or mission receipt.
  func isCurrent(in game: borrowing Game) -> Bool { (try? current(in: game)) != nil }

  func page(in game: borrowing Game) throws -> Page {
    Self.project(section, source: try current(in: game))
  }

  /// A refused stale/missing-kit read cannot move the cursor or modify the case.
  mutating func select(_ section: Section, in game: borrowing Game) throws -> Page {
    let source = try current(in: game)
    self.section = section
    return Self.project(section, source: source)
  }

  mutating func move(_ step: Step, in game: borrowing Game) throws -> Page {
    let source = try current(in: game)
    let offset = step == .previous ? -1 : 1
    section = Section(rawValue: section.rawValue + offset) ?? section
    return Self.project(section, source: source)
  }

  private func current(in game: borrowing Game) throws -> Source {
    guard context.epoch == game.nativeStationRuntimeEpoch else { throw ReaderError.staleView }
    let source = try Self.source(in: game)
    guard source.context == context else { throw ReaderError.staleView }
    return source
  }

  private static func source(in game: borrowing Game) throws -> Source {
    let held = try game.hollowManifestHeldRegisterData()
    guard let instance = game.hollowManifestMission, let state = instance.savedHollowManifest,
      held.mission == instance.id, held.contents.mission == instance.id,
      held.comparison.valid(in: state, contents: held.contents),
      held.contents.seals.count == 2, held.contents.wakeObservations.count == 3,
      let laboratory = state.laboratory, laboratory.facts.analysis.facts.observations.count == 2,
      let trail = state.wakeTrail, trail.observations.count == 3
    else { throw SaveError.invalidCommander }
    return .init(context: .init(mission: held.mission, revision: instance.revision,
      register: held.contents.serial, transfer: held.transfer, comparison: held.comparison.operation,
      kit: held.kit, epoch: game.nativeStationRuntimeEpoch), held: held,
      inspections: laboratory.facts.analysis.facts.observations, wakes: trail.observations)
  }

  private static func project(_ section: Section, source: Source) -> Page {
    let held = source.held
    let contents = held.contents
    let title: String
    let rows: [Row]
    switch section {
    case .declarations:
      title = "Recovered register / cargo declarations"
      rows = [
        .init(label: "Register cargo", value: cargoName(contents.recordedCargo),
          basis: .documentClaim, reference: contents.serial),
        .init(label: "Insurance declaration", value: cargoName(contents.insuranceDeclaration),
          basis: .documentClaim, reference: contents.serial),
        .init(label: "Recorded comparison", value: "The two written cargo declarations conflict.",
          basis: .recordedComparison, reference: held.comparison.operation),
      ]
    case .firstSeal, .secondSeal:
      let index = section == .firstSeal ? 0 : 1
      let seal = contents.seals[index]
      // source() validates the actual comparison and both bounded original arrays.
      let observation = source.inspections[index]
      title = "Recovered register / original seal \(index + 1)"
      rows = [
        .init(label: "Register seal", value: "Record identifies this original seal.",
          basis: .documentClaim, reference: seal.seal),
        .init(label: "Laboratory inspection", value: "The identifiers match this retained inspection.",
          basis: .observedSealReference, reference: observation.inspection),
        .init(label: "Inspected hull", value: "The same original hull is referenced by the record and inspection.",
          basis: .observedSealReference, reference: seal.hull),
        .init(label: "Register imprint", value: "The imprint reference matches the original observed seal.",
          basis: .observedSealReference, reference: seal.imprint),
      ]
    case .wakeReferences:
      title = "Recovered register / recorded wake references"
      rows = source.wakes.enumerated().map { index, observation in
        .init(label: "Wake \(index + 1)",
          value: "Register reference matches this recorded observation in the same order.",
          basis: .recordedWakeReference, reference: observation.operation)
      }
    case .crewNotice:
      title = "Recovered register / crew notice"
      rows = [
        .init(label: "Register claim", value: contents.crewWereToldContents
          ? "The register claims the crew were told the contents."
          : "The register claims the crew were not told the contents.",
          basis: .documentClaim, reference: contents.serial),
        .init(label: "Independent evidence required",
          value: "Obtain the original rescued crew's unaltered log before Toren reconciles the ledger at Garrivek.",
          basis: .requirement, reference: nil),
      ]
    }
    return .init(section: section, register: contents.serial, transfer: held.transfer,
      title: title, rows: rows,
      notice: "This recovered register alone does not prove physical cargo, warehouse dates, crew knowledge or responsibility.")
  }

  private static func cargoName(_ cargo: NativeC03CustodyRegisterContent.Cargo) -> String {
    switch cargo {
    case .sealedRefineryWaste: "Sealed refinery waste"
    case .machinery: "Machinery"
    }
  }
}

extension Game {
  func hollowManifestRecoveredArchiveReader() throws -> NativeC03RecoveredArchiveReader {
    try .open(in: self)
  }
}
