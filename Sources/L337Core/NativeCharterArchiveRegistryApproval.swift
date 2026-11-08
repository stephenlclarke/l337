import Foundation

/// Static source-content approval only. No case, measurement, clue or live ingress authority.
/// Exact reviewed v4 fictional content; all independent role and live ingress gates remain separate.
enum NativeCharterArchiveRegistryApproval {
  enum Failure: Error, Equatable, Sendable { case unapproved, unavailable, sourceMismatch, invalidContent }

  struct Registry: Sendable {
    let sources: [Source]
    let provenance: Provenance
    fileprivate init(sources: [Source], provenance: Provenance) {
      self.sources = sources
      self.provenance = provenance
    }
    func source(for sourceID: String) -> Source? {
      sources.first { $0.sourceID == sourceID }
    }
  }

  struct Source: Sendable {
    let sourceID: String
    let clueID: String
    let receiptID: String
    let archiveSHA256: String
    let calibrationSHA256: String
    let observations: [Observation]
    fileprivate init(
      sourceID: String, clueID: String, receiptID: String,
      archiveSHA256: String, calibrationSHA256: String, observations: [Observation]
    ) {
      self.sourceID = sourceID
      self.clueID = clueID
      self.receiptID = receiptID
      self.archiveSHA256 = archiveSHA256
      self.calibrationSHA256 = calibrationSHA256
      self.observations = observations
    }
  }

  struct Observation: Sendable {
    let recordID: String
    let replicaID: String
    let originIdentity: String
    let originDomain: String
    let payloadSHA256: String
    fileprivate init(
      recordID: String, replicaID: String, originIdentity: String,
      originDomain: String, payloadSHA256: String
    ) {
      self.recordID = recordID
      self.replicaID = replicaID
      self.originIdentity = originIdentity
      self.originDomain = originDomain
      self.payloadSHA256 = payloadSHA256
    }
  }

  struct Provenance: Sendable {
    let sourceSetCommit: String
    let sourceSetPath: String
    let sourceSetSHA256: String
    let corpusSchema: String
    let corpusRevision: String
    let corpusSHA256: String
    fileprivate init(
      sourceSetCommit: String, sourceSetPath: String, sourceSetSHA256: String,
      corpusSchema: String, corpusRevision: String, corpusSHA256: String
    ) {
      self.sourceSetCommit = sourceSetCommit
      self.sourceSetPath = sourceSetPath
      self.sourceSetSHA256 = sourceSetSHA256
      self.corpusSchema = corpusSchema
      self.corpusRevision = corpusRevision
      self.corpusSHA256 = corpusSHA256
    }
  }

  private struct OriginalPin: Decodable, Equatable, Sendable {
    let commit: String
    let path: String
    let sha256: String
    let jsonPointer: String
  }
  private struct ResourcePin: Decodable, Equatable, Sendable {
    let path: String
    let sha256: String
  }
  private struct FactPin: Decodable, Equatable, Sendable {
    let commit: String
    let path: String
    let fileSHA256: String
    let jsonPointer: String
    let fragmentSHA256: String
  }
  private struct ObservationData: Decodable, Equatable, Sendable {
    let ordinal: Int
    let recordID: String
    let replicaID: String
    let originIdentity: String
    let originDomain: String
    let payloadSHA256: String
    let originalFacts: [FactPin]
    let relativeChronology: String
    let authoringClass: String
    let scope: String
  }
  private struct SourceData: Decodable, Equatable, Sendable {
    let sourceID: String
    let clueID: String
    let receiptID: String
    let definition: OriginalPin
    let profile: OriginalPin
    let archive: ResourcePin
    let calibration: ResourcePin
    let observations: [ObservationData]
  }
  private struct SourceSet: Decodable, Equatable, Sendable {
    let commit: String
    let path: String
    let sha256: String
  }
  private struct Document: Decodable, Sendable {
    let schema: String
    let publication: String
    let contentScope: String
    let revision: String
    let sourceSet: SourceSet
    let sources: [SourceData]
  }
  private struct Canonical: Sendable {
    let sourceID: String
    let clueID: String
    let definitionPath: String
    let definitionSHA256: String
    let requiresProfileSuccessor: Bool
  }
  // These descriptors are native reviewed content, never decoded or accepted from a caller.
  private struct SourceApprovalDescriptor: Sendable {
    let source: SourceData
    let archiveBytes: Int
    let calibrationBytes: Int
  }
  private struct CorpusDescriptor: Sendable {
    let bytes: Int
    let sha256: String
    let revision: String
    let sources: [SourceApprovalDescriptor]
  }
  private enum Approval: Sendable {
    case pendingReview
    case published(CorpusDescriptor)
  }
  // Human approved this exact v4 content direction for bundled publication only.
  // Reviewed content-set SHA256: 1d3d1bb928634cb97dec31d49f7b677062eeebea306500c1fa5a1ec4d04ba64f
  // Actual approval receipt SHA256: 4811c3846f4de7a8243a96bd633d49b72da430765e85c5f57c38b49ba89040b0
  private static let approval = Approval.published(publishedCorpusDescriptor)
  private static let schema = "l337.charter-archive-registry/1"
  private static let scope = "fictional-public-model-only"
  private static let originalCommit = "c70110b292077588a0855fb48127adfb1b611c9d"
  private static let sourceSetPath = "docs/meridian/missions/definitions/unwritten-route.json"
  private static let sourceSetSHA256 = "462d3446973aa45a7b31cf414931a3fed99a969f03f4919f4715e669e0b8176d"
  private static let profilePath = "docs/meridian/missions/gameplay/recovery-policy.json"
  private static let profileSHA256 = "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b"
  // Immutable six-link development source; this is not corpus publication.
  private static let committedProfileSuccessorCommit = "cf9d14ad5328238206411bb1e5ebaea2e7e798f0"
  private static let committedProfileSuccessorPath =
    "docs/meridian/missions/gameplay/recovery-policy-corpus-successor.json"
  private static let committedProfileSuccessorSHA256 =
    "bab72a03d34c800343ae632f61f748cb6ce33da9007243146f896418660da0f1"
  private static let canonical: [Canonical] = [
    .init(sourceID: "l337.assembly-of-orbits", clueID: "assembly-of-orbits-trace",
      definitionPath: "docs/meridian/missions/definitions/assembly-of-orbits.json",
      definitionSHA256: "7ffa8831f6a912e6c30d43453624c4bfb66f4cd0cedd8e76df8259c7d73cf514",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.blue-reservoir", clueID: "blue-reservoir-trace",
      definitionPath: "docs/meridian/missions/definitions/blue-reservoir.json",
      definitionSHA256: "e4855e11a8b2bca689d9e7b7a09c5bbbc62e00004da4965bf57371bc44a7c767",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.borrowed-dawn", clueID: "borrowed-dawn-trace",
      definitionPath: "docs/meridian/missions/definitions/borrowed-dawn.json",
      definitionSHA256: "71fd1b43f385f2dd44d7a809908dd3e58b1bceab2e3278c5d8bb18e22f47dc7c",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.borrowed-voice", clueID: "voice-unclaimed-channel",
      definitionPath: "docs/meridian/missions/definitions/borrowed-voice.json",
      definitionSHA256: "302542daa4a97fcf7bdf46329327e156171544a367ee4e19974c3ad46d0c62f8",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.cold-reserve", clueID: "cold-reserve-trace",
      definitionPath: "docs/meridian/missions/definitions/cold-reserve.json",
      definitionSHA256: "7ef144813ca785c44fd0a07a4c94e0a9f529fef90c2c489b5f5f2b69b04d3aa8",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/bonded-freight", clueID: "bonded-freight-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/cabin-journey", clueID: "cabin-journey-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/consented-freight", clueID: "consented-freight-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/consented-survey", clueID: "consented-survey-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/corridor-defence", clueID: "corridor-defence-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/custody-rescue", clueID: "custody-rescue-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/hostile-larvaal-defence", clueID: "hostile-larvaal-defence-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/identified-salvage", clueID: "identified-salvage-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/isolation-work", clueID: "isolation-work-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/measured-extraction", clueID: "measured-extraction-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/mutual-contribution", clueID: "mutual-contribution-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/orbital-evacuation", clueID: "orbital-evacuation-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/orbital-outlook", clueID: "orbital-outlook-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/sealed-dispatch", clueID: "sealed-dispatch-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.contract/verified-warrant", clueID: "verified-warrant-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.courier", clueID: "courier-empty-destination",
      definitionPath: "docs/meridian/missions/definitions/courier.json",
      definitionSHA256: "93061611f090d9e2b35a138f4026411ec425a35f38413f79586b44f17ecc63e3",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.false-colours", clueID: "false-colours-trace",
      definitionPath: "docs/meridian/missions/definitions/false-colours.json",
      definitionSHA256: "4a8f144011e8611f77cc82ff7019faf4a3a275b3b21c93aea5d023dc17f9b4db",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.fleet-of-neighbours", clueID: "fleet-of-neighbours-trace",
      definitionPath: "docs/meridian/missions/definitions/fleet-of-neighbours.json",
      definitionSHA256: "18829ed037b93166312d33b67652ceea447dbc427e549b50c47dd9bed9e8d479",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.garden-in-transit", clueID: "garden-in-transit-trace",
      definitionPath: "docs/meridian/missions/definitions/garden-in-transit.json",
      definitionSHA256: "455def33ff05273c8a9b0133f81c53f5367721bf724f9efe9c09ae313fc2ddab",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.glass-meridian", clueID: "meridian-offset",
      definitionPath: "docs/meridian/missions/definitions/glass-meridian.json",
      definitionSHA256: "14e29571b5c6335ecca5068516448224944e6881462aa329f14bb6a1cb2ea572",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.guiding-light", clueID: "lantern-extra-echo",
      definitionPath: "docs/meridian/missions/definitions/guiding-light.json",
      definitionSHA256: "95204252f6c21570eb703108209c2759f62667d1c13036abd7109b29e47a4aa5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.harbour-without-orders", clueID: "harbour-without-orders-trace",
      definitionPath: "docs/meridian/missions/definitions/harbour-without-orders.json",
      definitionSHA256: "5f0790b611519cccfae130a27e3b74440fd706107216c95c70e02e29fc57d667",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.hollow-manifest", clueID: "manifest-hidden-imprint",
      definitionPath: "docs/meridian/missions/definitions/hollow-manifest.json",
      definitionSHA256: "82d8567a390bdd82b68a08430b071da84696e07e6b1d5a027f3ee5690e065e2a",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.honest-circuit", clueID: "honest-circuit-trace",
      definitionPath: "docs/meridian/missions/definitions/honest-circuit.json",
      definitionSHA256: "b7a30dd4d3d37883c244f01c0a5c58bc5e643e262f27b85069d66696c91beb72",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.kind-distance", clueID: "kind-distance-trace",
      definitionPath: "docs/meridian/missions/definitions/kind-distance.json",
      definitionSHA256: "c7196b310ab1f71ccc5e955e47a5f5723eccc2b5ef147e9490a18dc2f66826c6",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.listening-frontier", clueID: "listening-frontier-trace",
      definitionPath: "docs/meridian/missions/definitions/listening-frontier.json",
      definitionSHA256: "d321b0c06d7b0213adc827e1cd727cb1f9064c8ab01b0032f4d6cb91a6027570",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.long-return", clueID: "long-return-trace",
      definitionPath: "docs/meridian/missions/definitions/long-return.json",
      definitionSHA256: "3e1decc3b4982885c539b6a07c6b8b7a1dea71a57f0fe54e6257258cd9e84019",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.magnetic-orchard", clueID: "magnetic-orchard-trace",
      definitionPath: "docs/meridian/missions/definitions/magnetic-orchard.json",
      definitionSHA256: "935ff7abd683c06d625b7331e233e5b45a6493423282f31ed8da205b0c71ce3c",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.measure-of-care", clueID: "measure-of-care-trace",
      definitionPath: "docs/meridian/missions/definitions/measure-of-care.json",
      definitionSHA256: "a11a2939995a20c5e2a97ba25b56887e06a8aa231b1d81aefd8eab039b75d004",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.memory-atlas", clueID: "memory-atlas-trace",
      definitionPath: "docs/meridian/missions/definitions/memory-atlas.json",
      definitionSHA256: "376678f1e4ca646d299e2205739e74f81f02b525a6a2f187db0ce9893218a7d6",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.mutual-shelter", clueID: "mutual-shelter-trace",
      definitionPath: "docs/meridian/missions/definitions/mutual-shelter.json",
      definitionSHA256: "f19d6a6a811da621daebf0b77491ae7679a41a151985fa426697bfffdb059be6",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.open-measure", clueID: "open-measure-trace",
      definitionPath: "docs/meridian/missions/definitions/open-measure.json",
      definitionSHA256: "9c712197b46f25e90514b3b6c0913dcbdf9d062123ffc99547085577845ee6d6",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.open-shadow", clueID: "open-shadow-trace",
      definitionPath: "docs/meridian/missions/definitions/open-shadow.json",
      definitionSHA256: "96379e8bb6578901715a852078536da14bbe4a175d2165cdc7d91197eb4411d2",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.passengers-horizon", clueID: "passengers-horizon-trace",
      definitionPath: "docs/meridian/missions/definitions/passengers-horizon.json",
      definitionSHA256: "1b86aea8e6b5600a0b748040ac1ad970406391cc26eebbdb0af92d67e95e2804",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.public-record", clueID: "public-record-trace",
      definitionPath: "docs/meridian/missions/definitions/public-record.json",
      definitionSHA256: "0ebf720710dc5d7954158e2c25d6d0a346bc0883481d0d39fe4634f5f68e4bb5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.quiet-choir", clueID: "choir-silent-voice",
      definitionPath: "docs/meridian/missions/definitions/quiet-choir.json",
      definitionSHA256: "41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.quiet-nursery", clueID: "quiet-nursery-trace",
      definitionPath: "docs/meridian/missions/definitions/quiet-nursery.json",
      definitionSHA256: "728e4ce3b41e76dadd7993953f205f8e1afeaa30414e1dca210b4712c8562c6b",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.rubble-covenant", clueID: "rubble-covenant-trace",
      definitionPath: "docs/meridian/missions/definitions/rubble-covenant.json",
      definitionSHA256: "969316d8421735c4589e75a69a8bc5e3c3a0eaa0f44ce28c2ce249a88cf0f559",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.shared-pulse", clueID: "shared-pulse-trace",
      definitionPath: "docs/meridian/missions/definitions/shared-pulse.json",
      definitionSHA256: "305f9ae59bd503a625704d9505e7114ccdb8d1094da10f2cc7edb2f4f9c168e7",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.shattered-wake", clueID: "wake-before-impact",
      definitionPath: "docs/meridian/missions/definitions/shattered-wake.json",
      definitionSHA256: "50a55d876d1edf40eab3f517ff97d30eaeb4d837f3d766d4312378f9ccf72c2b",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.small-lights", clueID: "small-lights-trace",
      definitionPath: "docs/meridian/missions/definitions/small-lights.json",
      definitionSHA256: "2b8efb2ef80c459fa1bdbe852709fd69eeff45cfedc4773cc5b120f747fcd641",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.still-current", clueID: "current-resting-arc",
      definitionPath: "docs/meridian/missions/definitions/still-current.json",
      definitionSHA256: "a4cd54915cd51048002f88c862f99665bcc11f65785ec8fb3dc62a7109e67f47",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.tithe-of-worlds", clueID: "tithe-unclaimed-reserve",
      definitionPath: "docs/meridian/missions/definitions/tithe-of-worlds.json",
      definitionSHA256: "1fe19892fe4cff0da61da5d547dfb6eebb8842b15680607b8adf69dfa238a67a",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.training/defensive-flight", clueID: "defensive-flight-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.training/flight-reception", clueID: "flight-reception-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.training/navigation-trade", clueID: "navigation-trade-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.training/safe-gunnery", clueID: "safe-gunnery-family-trace",
      definitionPath: "docs/meridian/missions/definitions/original-families.json",
      definitionSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.uncounted-names", clueID: "uncounted-names-trace",
      definitionPath: "docs/meridian/missions/definitions/uncounted-names.json",
      definitionSHA256: "318d89b6837750dcb5abc0b149e6fbc80e751e7b63a85b4a285776671ee54bd5",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.under-tow", clueID: "under-tow-trace",
      definitionPath: "docs/meridian/missions/definitions/under-tow.json",
      definitionSHA256: "b5dac526f44b1599b66400a47e4bbf0a5e38f4b0c9cd9fa8431992bab75a9cb2",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.unfinished-map", clueID: "unfinished-map-trace",
      definitionPath: "docs/meridian/missions/definitions/unfinished-map.json",
      definitionSHA256: "453551f24efbc6a3ad54bd7904cb7e6007d317f73481e4364aff93ed0b934862",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.warrant-ledger", clueID: "warrant-ledger-trace",
      definitionPath: "docs/meridian/missions/definitions/warrant-ledger.json",
      definitionSHA256: "16b225e3565f7eefb6f0297bfaf2c68831ccda7d05a48de40e501c991b360dcc",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.wayfarer-exchange", clueID: "exchange-unbooked-window",
      definitionPath: "docs/meridian/missions/definitions/wayfarer-exchange.json",
      definitionSHA256: "9be9729169d2f52ab0b10755b048a473d7fba470e02d707fcdcadcfaf737bd97",
      requiresProfileSuccessor: false),
    .init(sourceID: "l337.wayfarer-service/cold-chain", clueID: "exchange-service-cold-chain",
      definitionPath: "docs/meridian/missions/definitions/wayfarer-services.json",
      definitionSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4",
      requiresProfileSuccessor: true),
    .init(sourceID: "l337.wayfarer-service/convoy-watch", clueID: "exchange-service-convoy-watch",
      definitionPath: "docs/meridian/missions/definitions/wayfarer-services.json",
      definitionSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4",
      requiresProfileSuccessor: true),
    .init(sourceID: "l337.wayfarer-service/field-relief", clueID: "exchange-service-field-relief",
      definitionPath: "docs/meridian/missions/definitions/wayfarer-services.json",
      definitionSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4",
      requiresProfileSuccessor: true),
    .init(sourceID: "l337.wayfarer-service/record-recovery", clueID: "exchange-service-record-recovery",
      definitionPath: "docs/meridian/missions/definitions/wayfarer-services.json",
      definitionSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4",
      requiresProfileSuccessor: true),
    .init(sourceID: "l337.wayfarer-service/repair-loop", clueID: "exchange-service-repair-loop",
      definitionPath: "docs/meridian/missions/definitions/wayfarer-services.json",
      definitionSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4",
      requiresProfileSuccessor: true),
    .init(sourceID: "l337.wayfarer-service/seed-transfer", clueID: "exchange-service-seed-transfer",
      definitionPath: "docs/meridian/missions/definitions/wayfarer-services.json",
      definitionSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4",
      requiresProfileSuccessor: true),
    .init(sourceID: "l337.witness-window", clueID: "witness-window-trace",
      definitionPath: "docs/meridian/missions/definitions/witness-window.json",
      definitionSHA256: "4edcb88c16f0a0aa6a815378d1b5db43d8d5723a9e6635f71b939ec28c87a29a",
      requiresProfileSuccessor: false),
  ]

  private static let retained: Result<Registry, any Error> = Result { try readRegistry() }
  static func load() throws -> Registry { try retained.get() }

  private static func readRegistry() throws -> Registry {
    guard case .published(let descriptor) = approval else { throw Failure.unapproved }
    guard descriptor.bytes > 0, digest(descriptor.sha256), text(descriptor.revision),
      descriptor.sources.count == canonical.count,
      descriptor.sources.map({ $0.source.sourceID }) == canonical.map(\.sourceID),
      descriptor.sources.allSatisfy({ $0.archiveBytes > 0 && $0.calibrationBytes > 0 })
    else { throw Failure.invalidContent }
    let resources = Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
    } ?? Bundle.module
    guard let root = resources.resourceURL else { throw Failure.unavailable }
    let directory = root.appendingPathComponent("MissionPacks/native-unwritten-route")
    let bytes = try ScriptPackLibrary.readFile("charter-archive-registry.json", in: directory)
    guard bytes.count == descriptor.bytes, ScriptPackLibrary.hash(bytes) == descriptor.sha256 else {
      throw Failure.sourceMismatch
    }
    let document = try candidate(bytes)
    guard document.revision == descriptor.revision else { throw Failure.sourceMismatch }
    var sources: [Source] = []
    for (data, approved) in zip(document.sources, descriptor.sources) {
      // Exact whole source-specific provenance is approved, not just its source ID or checksum shape.
      guard data == approved.source else { throw Failure.sourceMismatch }
      let archive = try readResource(data.archive, count: approved.archiveBytes, in: directory)
      _ = try readResource(data.calibration, count: approved.calibrationBytes, in: directory)
      if data.sourceID == "l337.glass-meridian" { try validateC01(data, archive: archive) }
      sources.append(Source(
        sourceID: data.sourceID, clueID: data.clueID, receiptID: data.receiptID,
        archiveSHA256: data.archive.sha256, calibrationSHA256: data.calibration.sha256,
        observations: data.observations.map {
          Observation(recordID: $0.recordID, replicaID: $0.replicaID,
            originIdentity: $0.originIdentity, originDomain: $0.originDomain,
            payloadSHA256: $0.payloadSHA256)
        }))
    }
    return Registry(sources: sources, provenance: Provenance(
      sourceSetCommit: document.sourceSet.commit, sourceSetPath: document.sourceSet.path,
      sourceSetSHA256: document.sourceSet.sha256, corpusSchema: document.schema,
      corpusRevision: document.revision, corpusSHA256: descriptor.sha256))
  }

  private static func readResource(_ pin: ResourcePin, count: Int, in directory: URL) throws -> Data {
    guard resourceName(pin.path), digest(pin.sha256) else { throw Failure.invalidContent }
    let bytes = try ScriptPackLibrary.readFile(pin.path, in: directory)
    guard bytes.count == count, ScriptPackLibrary.hash(bytes) == pin.sha256 else {
      throw Failure.sourceMismatch
    }
    try ScriptSaveJSONPreflight.validate(bytes)
    _ = try JSONSerialization.jsonObject(with: bytes)
    return bytes
  }

  /// Pure candidate checks never issue a Registry or content approval.
  static func validateCandidateBytes(_ bytes: Data) throws { _ = try candidate(bytes) }

  private static func candidate(_ bytes: Data) throws -> Document {
    try ScriptSaveJSONPreflight.validate(bytes)
    try shape(bytes)
    let document = try JSONDecoder().decode(Document.self, from: bytes)
    let actualCatalog = ScriptBaseClueCatalog.sources.sorted { $0.sourceID < $1.sourceID }
    guard canonical.count == 64, actualCatalog.count == canonical.count,
      zip(actualCatalog, canonical).allSatisfy({ pair in
        pair.0.sourceID == pair.1.sourceID && pair.0.clueID == pair.1.clueID
      }),
      document.schema == schema, document.publication == "published-source",
      document.contentScope == scope, text(document.revision),
      document.sourceSet == SourceSet(
        commit: originalCommit, path: sourceSetPath, sha256: sourceSetSHA256),
      document.sources.count == canonical.count,
      document.sources.map(\.sourceID) == canonical.map(\.sourceID)
    else { throw Failure.invalidContent }
    var recordIDs = Set<String>()
    for (source, expected) in zip(document.sources, canonical) {
      try validateSource(source, expected: expected)
      for record in source.observations {
        guard recordIDs.insert(record.recordID).inserted else { throw Failure.invalidContent }
      }
    }
    guard recordIDs.count == 192 else { throw Failure.invalidContent }
    return document
  }

  private static func validateSource(_ source: SourceData, expected: Canonical) throws {
    let pointer = "/profiles/" + source.sourceID.replacingOccurrences(of: "~", with: "~0")
      .replacingOccurrences(of: "/", with: "~1")
    guard source.clueID == expected.clueID,
      source.receiptID == "l337.unwritten-route/clue/" + expected.clueID,
      source.definition.commit == originalCommit, source.definition.path == expected.definitionPath,
      source.definition.sha256 == expected.definitionSHA256, jsonPointer(source.definition.jsonPointer),
      source.profile.jsonPointer == pointer,
      hexadecimal(source.profile.commit, count: 40), digest(source.profile.sha256),
      resourceName(source.archive.path), resourceName(source.calibration.path),
      source.archive.path != source.calibration.path,
      digest(source.archive.sha256), digest(source.calibration.sha256),
      source.observations.map(\.ordinal) == [0, 1, 2],
      Set(source.observations.map(\.replicaID)).count == 3,
      Set(source.observations.map(\.originIdentity)).count == 3,
      Set(source.observations.map(\.originDomain)).count == 3
    else { throw Failure.invalidContent }
    if expected.requiresProfileSuccessor {
      // Preserve the historical mismatch; accept only the actual committed
      // six-link correction, never another merely well-formed commit or path.
      guard source.profile.commit == committedProfileSuccessorCommit,
        source.profile.path == committedProfileSuccessorPath,
        source.profile.sha256 == committedProfileSuccessorSHA256
      else {
        throw Failure.invalidContent
      }
    } else {
      guard source.profile.commit == originalCommit, source.profile.path == profilePath,
        source.profile.sha256 == profileSHA256
      else {
        throw Failure.invalidContent
      }
    }
    for record in source.observations {
      guard record.recordID.hasPrefix(source.sourceID + "/archive/"), text(record.recordID),
        text(record.replicaID), text(record.originIdentity), text(record.originDomain),
        digest(record.payloadSHA256), record.relativeChronology == "before-original-source-offer",
        record.authoringClass == "new-fictional-public-model", record.scope == scope,
        !record.originalFacts.isEmpty,
        Set(record.originalFacts.map { $0.path + "#" + $0.jsonPointer }).count == record.originalFacts.count
      else { throw Failure.invalidContent }
      for fact in record.originalFacts {
        let originalDefinition = fact.path == expected.definitionPath
          && fact.fileSHA256 == expected.definitionSHA256
        let originalClue = fact.path == sourceSetPath && fact.fileSHA256 == sourceSetSHA256
        guard fact.commit == originalCommit, originalDefinition || originalClue,
          jsonPointer(fact.jsonPointer), digest(fact.fragmentSHA256)
        else { throw Failure.invalidContent }
      }
    }
  }

  private static func validateC01(_ source: SourceData, archive: Data) throws {
    let content = try NativeC01CharterArchiveApproval.load()
    guard source.archive.sha256 == content.archiveSHA256,
      source.calibration.sha256 == content.calibrationSHA256,
      let group = content.archive.sourceGroups[source.sourceID], group.declarations.count == 3,
      let root = try JSONSerialization.jsonObject(with: archive) as? [String: Any],
      let groups = root["sourceGroups"] as? [String: Any],
      let rawGroup = groups[source.sourceID] as? [String: Any],
      let declarations = rawGroup["declarations"] as? [Any], declarations.count == 3
    else { throw Failure.sourceMismatch }
    for (index, expected) in source.observations.enumerated() {
      let actual = group.declarations[index]
      var payload = try JSONSerialization.data(
        withJSONObject: declarations[index], options: [.sortedKeys, .withoutEscapingSlashes])
      payload.append(10)
      let facts = actual.originalFacts.map {
        FactPin(commit: $0.commit, path: $0.path, fileSHA256: $0.fileSHA256,
          jsonPointer: $0.jsonPointer, fragmentSHA256: $0.fragmentUTF8SHA256)
      }
      guard actual.recordID == expected.recordID, actual.replicaID == expected.replicaID,
        actual.origin.identity == expected.originIdentity, actual.origin.domain == expected.originDomain,
        ScriptPackLibrary.hash(payload) == expected.payloadSHA256, facts == expected.originalFacts
      else { throw Failure.sourceMismatch }
    }
  }

  private static func shape(_ bytes: Data) throws {
    let root = try object(JSONSerialization.jsonObject(with: bytes), keys: [
      "schema", "publication", "contentScope", "revision", "sourceSet", "sources",
    ])
    let set = try object(root["sourceSet"], keys: ["commit", "path", "sha256"])
    guard root["schema"] as? String == schema,
      root["publication"] as? String == "published-source", root["contentScope"] as? String == scope,
      set["commit"] as? String == originalCommit, set["path"] as? String == sourceSetPath,
      set["sha256"] as? String == sourceSetSHA256
    else { throw Failure.invalidContent }
    guard let sources = root["sources"] as? [Any], sources.count == 64 else {
      throw Failure.invalidContent
    }
    guard sources.compactMap({ ($0 as? [String: Any])?["sourceID"] as? String })
      == canonical.map(\.sourceID)
    else { throw Failure.invalidContent }
    for raw in sources {
      let source = try object(raw, keys: [
        "sourceID", "clueID", "receiptID", "definition", "profile", "archive", "calibration", "observations",
      ])
      for field in ["definition", "profile"] {
        _ = try object(source[field], keys: ["commit", "path", "sha256", "jsonPointer"])
      }
      for field in ["archive", "calibration"] {
        _ = try object(source[field], keys: ["path", "sha256"])
      }
      guard let observations = source["observations"] as? [Any], observations.count == 3 else {
        throw Failure.invalidContent
      }
      for rawRecord in observations {
        let record = try object(rawRecord, keys: [
          "ordinal", "recordID", "replicaID", "originIdentity", "originDomain", "payloadSHA256",
          "originalFacts", "relativeChronology", "authoringClass", "scope",
        ])
        guard let facts = record["originalFacts"] as? [Any], !facts.isEmpty else {
          throw Failure.invalidContent
        }
        for fact in facts {
          _ = try object(fact, keys: ["commit", "path", "fileSHA256", "jsonPointer", "fragmentSHA256"])
        }
      }
    }
  }

  private static func object(_ value: Any?, keys: [String]) throws -> [String: Any] {
    guard let object = value as? [String: Any], Set(object.keys) == Set(keys),
      !object.values.contains(where: { $0 is NSNull })
    else { throw Failure.invalidContent }
    return object
  }
  private static func hexadecimal(_ value: String, count: Int) -> Bool {
    value.utf8.count == count && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
  }
  private static func digest(_ value: String) -> Bool { hexadecimal(value, count: 64) }
  private static func text(_ value: String) -> Bool {
    !value.isEmpty && value.utf8.count <= 4096 && !value.unicodeScalars.contains { $0.value < 32 }
  }
  private static func jsonPointer(_ value: String) -> Bool { text(value) && value.hasPrefix("/") }
  private static func resourceName(_ value: String) -> Bool {
    text(value) && value.hasSuffix(".json") && !value.contains("/") && !value.contains("\\")
      && !value.contains("..")
  }
}


extension NativeCharterArchiveRegistryApproval {
  /// Exact approved fictional content descriptor. Source roles remain UNISSUED;
  /// publication supplies no consent, independent evidence, case or measurement authority.
  private static let publishedCorpusDescriptor = CorpusDescriptor(
    bytes: 212206,
    sha256: "8940764d1b23880852aa275d33357af9dbe8817804419431fa53a066f480c45d",
    revision: "canonical64-charter-source-proposals-v4-explicit-specification-context",
    sources: [
      .init(source: .init(sourceID: "l337.assembly-of-orbits", clueID: "assembly-of-orbits-trace",
        receiptID: "l337.unwritten-route/clue/assembly-of-orbits-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/assembly-of-orbits.json", sha256: "7ffa8831f6a912e6c30d43453624c4bfb66f4cd0cedd8e76df8259c7d73cf514", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.assembly-of-orbits"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.assembly-of-orbits/archive/corridor-capacity-editor", replicaID: "proposed-replica-corridor-capacity-editor",
          originIdentity: "proposed-corridor-capacity-editor", originDomain: "corridor-capacity-editor",
          payloadSHA256: "49e331363655afee827dea134911950613d7ed175b736ee44cc564621e7173b8",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/assembly-of-orbits.json", fileSHA256: "7ffa8831f6a912e6c30d43453624c4bfb66f4cd0cedd8e76df8259c7d73cf514", jsonPointer: "/story", fragmentSHA256: "ba243138f7bf288091bfa0ce2541256470232ae655ba6bfb2f71f244b7073366")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.assembly-of-orbits/archive/crew-stop-authority-custodian", replicaID: "proposed-replica-crew-stop-authority-custodian",
          originIdentity: "proposed-crew-stop-authority-custodian", originDomain: "crew-stop-authority-custodian",
          payloadSHA256: "e3b68b6d27c1cfe7740e18e0083d165f08ab3ccae83f28d223a560ecd3b128cb",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/assembly-of-orbits.json", fileSHA256: "7ffa8831f6a912e6c30d43453624c4bfb66f4cd0cedd8e76df8259c7d73cf514", jsonPointer: "/stages/1/objective", fragmentSHA256: "854e99fac096e2a26144fe76e7f4b4b8322cbe28be4492632d3574708e9ffb30")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.assembly-of-orbits/archive/protected-slot-reference-curator", replicaID: "proposed-replica-protected-slot-reference-curator",
          originIdentity: "proposed-protected-slot-reference-curator", originDomain: "protected-slot-reference-curator",
          payloadSHA256: "12640e44665598380b9fbe0d3561c426037e05ba4dcf0cd5fd61f845a9680c0b",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/assembly-of-orbits.json", fileSHA256: "7ffa8831f6a912e6c30d43453624c4bfb66f4cd0cedd8e76df8259c7d73cf514", jsonPointer: "/completionClue/receipt", fragmentSHA256: "976b808115bcc49601448f6ea7f24ba0aa43c06b9d9ec5258a865bd31bd01e27")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.blue-reservoir", clueID: "blue-reservoir-trace",
        receiptID: "l337.unwritten-route/clue/blue-reservoir-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/blue-reservoir.json", sha256: "e4855e11a8b2bca689d9e7b7a09c5bbbc62e00004da4965bf57371bc44a7c767", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.blue-reservoir"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.blue-reservoir/archive/reservoir-custody-editor", replicaID: "proposed-replica-reservoir-custody-editor",
          originIdentity: "proposed-reservoir-custody-editor", originDomain: "reservoir-custody-editor",
          payloadSHA256: "7a11b992e67f8ba5c6125aa6649a90441437bafd53becad95c62a7f24a951587",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/blue-reservoir.json", fileSHA256: "e4855e11a8b2bca689d9e7b7a09c5bbbc62e00004da4965bf57371bc44a7c767", jsonPointer: "/story", fragmentSHA256: "7be820399a7a83314999e58f3cef4e68b15e0c7d75f8821d7798be936081bfc9")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.blue-reservoir/archive/return-flow-reference-custodian", replicaID: "proposed-replica-return-flow-reference-custodian",
          originIdentity: "proposed-return-flow-reference-custodian", originDomain: "return-flow-reference-custodian",
          payloadSHA256: "3534af1e87f3d7c093f7bb12786d390667a861f0f225f345f65e1c4d65292c0a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/blue-reservoir.json", fileSHA256: "e4855e11a8b2bca689d9e7b7a09c5bbbc62e00004da4965bf57371bc44a7c767", jsonPointer: "/stages/1/objective", fragmentSHA256: "4b3b255d8f1ce7f6f7db6c64141128b4ed452f2d599390fe83b6aeceafbb6cd0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.blue-reservoir/archive/oxygen-limit-curator", replicaID: "proposed-replica-oxygen-limit-curator",
          originIdentity: "proposed-oxygen-limit-curator", originDomain: "oxygen-limit-curator",
          payloadSHA256: "47fb72f8c782178a18355be316e5c122b58e389dd654d0f6666709765a5401d0",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/blue-reservoir.json", fileSHA256: "e4855e11a8b2bca689d9e7b7a09c5bbbc62e00004da4965bf57371bc44a7c767", jsonPointer: "/completionClue/receipt", fragmentSHA256: "e89fc9a1b4c447b0262fdf87b114d2c2cabd8b830aef45c03c50cf61cc62b72e")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.borrowed-dawn", clueID: "borrowed-dawn-trace",
        receiptID: "l337.unwritten-route/clue/borrowed-dawn-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-dawn.json", sha256: "71fd1b43f385f2dd44d7a809908dd3e58b1bceab2e3278c5d8bb18e22f47dc7c", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.borrowed-dawn"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.borrowed-dawn/archive/reflector-stop-editor", replicaID: "proposed-replica-reflector-stop-editor",
          originIdentity: "proposed-reflector-stop-editor", originDomain: "reflector-stop-editor",
          payloadSHA256: "a94489e62ccb6cb0e82d4e6a34bcde404d7bca58bc3b0b0bc02057660cebb13a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-dawn.json", fileSHA256: "71fd1b43f385f2dd44d7a809908dd3e58b1bceab2e3278c5d8bb18e22f47dc7c", jsonPointer: "/story", fragmentSHA256: "9f1133526b0e911abd4e327c6a4f0531e10d7b13672c7c5d95fc9413f05e954c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.borrowed-dawn/archive/illumination-reference-custodian", replicaID: "proposed-replica-illumination-reference-custodian",
          originIdentity: "proposed-illumination-reference-custodian", originDomain: "illumination-reference-custodian",
          payloadSHA256: "4c34646c27413b646099954560cc6d4eff10f96dd57ac910dbd6af44ca0a6fd4",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-dawn.json", fileSHA256: "71fd1b43f385f2dd44d7a809908dd3e58b1bceab2e3278c5d8bb18e22f47dc7c", jsonPointer: "/stages/1/objective", fragmentSHA256: "8513ac3174b490cf87eac8347318e16b0e3c4697403058a7c9c3695674dddd7f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.borrowed-dawn/archive/thermal-shutter-curator", replicaID: "proposed-replica-thermal-shutter-curator",
          originIdentity: "proposed-thermal-shutter-curator", originDomain: "thermal-shutter-curator",
          payloadSHA256: "3d7fcab00f33dc07cb43db39fba07edc058e4ca2852257ae22802458e6255267",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-dawn.json", fileSHA256: "71fd1b43f385f2dd44d7a809908dd3e58b1bceab2e3278c5d8bb18e22f47dc7c", jsonPointer: "/completionClue/receipt", fragmentSHA256: "fb858c12951edb0e8f820134cbff318af2767d5e8df2c2e150c49b99f4f26a7d")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.borrowed-voice", clueID: "voice-unclaimed-channel",
        receiptID: "l337.unwritten-route/clue/voice-unclaimed-channel",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-voice.json", sha256: "302542daa4a97fcf7bdf46329327e156171544a367ee4e19974c3ad46d0c62f8", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.borrowed-voice"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.borrowed-voice/archive/voice-attribution-editor", replicaID: "proposed-replica-voice-attribution-editor",
          originIdentity: "proposed-voice-attribution-editor", originDomain: "voice-attribution-editor",
          payloadSHA256: "61d7f8feca807cbbad3f58daa303e5d200e4311a275d2d811a7785db020df91f",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-voice.json", fileSHA256: "302542daa4a97fcf7bdf46329327e156171544a367ee4e19974c3ad46d0c62f8", jsonPointer: "/story", fragmentSHA256: "774280070ebf910dbb08059beae2cd417878f0d1927b61f2f5a7bb71ef40e582")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.borrowed-voice/archive/borrowed-channel-reception-custodian", replicaID: "proposed-replica-borrowed-channel-reception-custodian",
          originIdentity: "proposed-borrowed-channel-reception-custodian", originDomain: "borrowed-channel-reception-custodian",
          payloadSHA256: "f70e91eb97457292ba60792f506d94005fbcf857634d0572581d6b0138b25873",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-voice.json", fileSHA256: "302542daa4a97fcf7bdf46329327e156171544a367ee4e19974c3ad46d0c62f8", jsonPointer: "/stages/1/objective", fragmentSHA256: "d4ac7e4491fe692a8a1191c58d1673107ca5841aa415ce43fdf83e7188a9498c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.borrowed-voice/archive/voice-trace-curator", replicaID: "proposed-replica-voice-trace-curator",
          originIdentity: "proposed-voice-trace-curator", originDomain: "voice-trace-curator",
          payloadSHA256: "c1d7870268dfc5af1fb210cf8bbfab05daefe114f28eb528a4c18844e5c5e625",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/borrowed-voice.json", fileSHA256: "302542daa4a97fcf7bdf46329327e156171544a367ee4e19974c3ad46d0c62f8", jsonPointer: "/completionClue/receipt", fragmentSHA256: "c2cd54393483f724e15c7ca198469a1f37a762fa3f6703688227cb75e420ab67")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.cold-reserve", clueID: "cold-reserve-trace",
        receiptID: "l337.unwritten-route/clue/cold-reserve-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/cold-reserve.json", sha256: "7ef144813ca785c44fd0a07a4c94e0a9f529fef90c2c489b5f5f2b69b04d3aa8", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.cold-reserve"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.cold-reserve/archive/dispatch-isolation-editor", replicaID: "proposed-replica-dispatch-isolation-editor",
          originIdentity: "proposed-dispatch-isolation-editor", originDomain: "dispatch-isolation-editor",
          payloadSHA256: "3865bd4769304ef372f3d96118273c50423b87b6eeed66603da5618e15efe1dc",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/cold-reserve.json", fileSHA256: "7ef144813ca785c44fd0a07a4c94e0a9f529fef90c2c489b5f5f2b69b04d3aa8", jsonPointer: "/story", fragmentSHA256: "b14ad3859441e2dc343332143ba5b05ffa96e0c3aa2a371d1501f0f479b853da")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.cold-reserve/archive/reserve-custody-custodian", replicaID: "proposed-replica-reserve-custody-custodian",
          originIdentity: "proposed-reserve-custody-custodian", originDomain: "reserve-custody-custodian",
          payloadSHA256: "70f7a6f5b116436eee19c0dc1196c2b58de14e02708d9a1b4cb71b37c66d50b5",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/cold-reserve.json", fileSHA256: "7ef144813ca785c44fd0a07a4c94e0a9f529fef90c2c489b5f5f2b69b04d3aa8", jsonPointer: "/stages/1/objective", fragmentSHA256: "854e99fac096e2a26144fe76e7f4b4b8322cbe28be4492632d3574708e9ffb30")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.cold-reserve/archive/dispatch-reference-curator", replicaID: "proposed-replica-dispatch-reference-curator",
          originIdentity: "proposed-dispatch-reference-curator", originDomain: "dispatch-reference-curator",
          payloadSHA256: "a0ee6b1488170b6baac74855b0bd921b1b5867d1f687c77a2e5b9b8336741107",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/cold-reserve.json", fileSHA256: "7ef144813ca785c44fd0a07a4c94e0a9f529fef90c2c489b5f5f2b69b04d3aa8", jsonPointer: "/completionClue/receipt", fragmentSHA256: "01429dbc663ec7e148b15bcf823349f09d20878d1f0beca11db240ce906488ab")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/bonded-freight", clueID: "bonded-freight-family-trace",
        receiptID: "l337.unwritten-route/clue/bonded-freight-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/2/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1bonded-freight"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/bonded-freight/archive/machinery-bond-editor", replicaID: "proposed-replica-machinery-bond-editor",
          originIdentity: "proposed-machinery-bond-editor", originDomain: "machinery-bond-editor",
          payloadSHA256: "ae56adecfd6d51c5e56dc45077b9df771482e6fbf27285f9068604c6b9d75d05",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/2/offerDialog", fragmentSHA256: "0543d108734e3dea49d675bfe5af79fda93dcf9ca1769688911d114c40c34f97")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/bonded-freight/archive/bonded-workshop-reception-custodian", replicaID: "proposed-replica-bonded-workshop-reception-custodian",
          originIdentity: "proposed-bonded-workshop-reception-custodian", originDomain: "bonded-workshop-reception-custodian",
          payloadSHA256: "4d98acf3fc3d65e171fb63cf559bad4c9c58db79d696b5aaf4c49b8a83cbe6fa",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/2/stages/1/objective", fragmentSHA256: "261e2befab4208f8f5b71a4b9b0fd0a27905f37ec6e6dc473937ac9139c98d5e")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/bonded-freight/archive/bond-reference-curator", replicaID: "proposed-replica-bond-reference-curator",
          originIdentity: "proposed-bond-reference-curator", originDomain: "bond-reference-curator",
          payloadSHA256: "9427a9c596b52df1d0cca65e41fda1a21b02334b3d7fadc8c754c0a8b89a8c3f",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/2/completionClue/receipt", fragmentSHA256: "0bc368f3ebb10ba02f130aac5dcced0fabd6cd2f1dfbe4ce8edf85c698eab543")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/cabin-journey", clueID: "cabin-journey-family-trace",
        receiptID: "l337.unwritten-route/clue/cabin-journey-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/3/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1cabin-journey"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/cabin-journey/archive/cabin-consent-editor", replicaID: "proposed-replica-cabin-consent-editor",
          originIdentity: "proposed-cabin-consent-editor", originDomain: "cabin-consent-editor",
          payloadSHA256: "d3d564629be9cedb969190f49fac085726b64cae47d4a3ec966335630c34792d",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/3/offerDialog", fragmentSHA256: "f6a3cf42714da219e42d4f10c095b413157e1f621f08a25681238a5b2b4790a0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/cabin-journey/archive/journey-reception-custodian", replicaID: "proposed-replica-journey-reception-custodian",
          originIdentity: "proposed-journey-reception-custodian", originDomain: "journey-reception-custodian",
          payloadSHA256: "f59f509ba76eaa547cbffdd1bf47b6b66abe450fe19f89910add4f66620bf4ba",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/3/stages/1/objective", fragmentSHA256: "9edcbfc96c625cbbc5b23400c2a505b15e64ffbbb2877d642cde4b9cd8e49816")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/cabin-journey/archive/passenger-reference-curator", replicaID: "proposed-replica-passenger-reference-curator",
          originIdentity: "proposed-passenger-reference-curator", originDomain: "passenger-reference-curator",
          payloadSHA256: "0fb7cb5d75c7dafabacf4bd8585eed83f525d2134a842d8cc4e8f0561f2f3ad4",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/3/completionClue/receipt", fragmentSHA256: "3813f6fbd3d8762c5d2819366291e6277a2c345c01c0919b14e985ba81fbb71d")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/consented-freight", clueID: "consented-freight-family-trace",
        receiptID: "l337.unwritten-route/clue/consented-freight-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/1/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1consented-freight"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/consented-freight/archive/freight-consent-editor", replicaID: "proposed-replica-freight-consent-editor",
          originIdentity: "proposed-freight-consent-editor", originDomain: "freight-consent-editor",
          payloadSHA256: "8cc8d16ff0beea5a5a9e6e99d061103a3f3f99ac843b512b1d74a28d521a737c",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/1/offerDialog", fragmentSHA256: "4406e6692a920dd43a126e11421dcb696faed0c5e66f70f29177f482659bcb44")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/consented-freight/archive/freight-delivery-custodian", replicaID: "proposed-replica-freight-delivery-custodian",
          originIdentity: "proposed-freight-delivery-custodian", originDomain: "freight-delivery-custodian",
          payloadSHA256: "17d94aef39e3f9a4104d805238f91d643eefedce019db2b2cb00fbf2b4c5dad8",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/1/stages/1/objective", fragmentSHA256: "84d00a23245c671a017fae762d19588106807b809439d52b7e3d154fc584d52d")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/consented-freight/archive/freight-settlement-reference-curator", replicaID: "proposed-replica-freight-settlement-reference-curator",
          originIdentity: "proposed-freight-settlement-reference-curator", originDomain: "freight-settlement-reference-curator",
          payloadSHA256: "65ac400e868d7fdcefc92bcea4bead3508059dd746963c6c4bf0b9ae507a231c",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/1/completionClue/receipt", fragmentSHA256: "a5917368b4b489156665387c02e631804286d2b1775253ba48572e1aae4ccbde")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/consented-survey", clueID: "consented-survey-family-trace",
        receiptID: "l337.unwritten-route/clue/consented-survey-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/9/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1consented-survey"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/consented-survey/archive/survey-consent-editor", replicaID: "proposed-replica-survey-consent-editor",
          originIdentity: "proposed-survey-consent-editor", originDomain: "survey-consent-editor",
          payloadSHA256: "40458de98a5351b7114b557d1e743d4ecc725cb660c0fcabc3fb061c59a501e6",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/9/offerDialog", fragmentSHA256: "eecf758d0bc1dc5d65fafc54302c2693d86abaf0ac0fbb571f2926fff7adbabf")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/consented-survey/archive/orbital-task-reference-custodian", replicaID: "proposed-replica-orbital-task-reference-custodian",
          originIdentity: "proposed-orbital-task-reference-custodian", originDomain: "orbital-task-reference-custodian",
          payloadSHA256: "c433856a1622e6bfa7b67d6b36d862e05bbaff57781936c0e2b49d0098e83da4",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/9/stages/1/objective", fragmentSHA256: "e173cf0b88a9905516f3f636039263d108c2bc25a88e68d1e77c51cfab4afe27")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/consented-survey/archive/survey-trace-curator", replicaID: "proposed-replica-survey-trace-curator",
          originIdentity: "proposed-survey-trace-curator", originDomain: "survey-trace-curator",
          payloadSHA256: "36901b10df0c1c435c6cb8ae90640dab02d09d1b00560816807c8869d4421d2e",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/9/completionClue/receipt", fragmentSHA256: "eb9474d9490504f3c4683d3c22f5135d26aa6d6ff0d625df1be98b2fbacd2bf8")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/corridor-defence", clueID: "corridor-defence-family-trace",
        receiptID: "l337.unwritten-route/clue/corridor-defence-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/6/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1corridor-defence"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/corridor-defence/archive/corridor-registration-editor", replicaID: "proposed-replica-corridor-registration-editor",
          originIdentity: "proposed-corridor-registration-editor", originDomain: "corridor-registration-editor",
          payloadSHA256: "272b122a21087e734c9a3d306cb9afe55cf7bca832a43b07eaec518085f88c55",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/6/offerDialog", fragmentSHA256: "d3eb6208798288904c7d59fe65d1f302e5e11c018aa486872ce9680c933123d7")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/corridor-defence/archive/defence-attribution-custodian", replicaID: "proposed-replica-defence-attribution-custodian",
          originIdentity: "proposed-defence-attribution-custodian", originDomain: "defence-attribution-custodian",
          payloadSHA256: "966de2909359ba97941c0cd08ac7eb6db5bd8816469c0f48929b44527cfbb6de",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/6/stages/1/objective", fragmentSHA256: "c589a4622b969c96b66cd702bb734ff9ad87e3b15c504632cb53cf62a0062c32")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/corridor-defence/archive/corridor-trace-curator", replicaID: "proposed-replica-corridor-trace-curator",
          originIdentity: "proposed-corridor-trace-curator", originDomain: "corridor-trace-curator",
          payloadSHA256: "3183d2c35197a7fea66f4d9a249a244d0afd082a9cb98513f816c198fcd229e3",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/6/completionClue/receipt", fragmentSHA256: "7712d42dc1922d97d910149d17b9898053965e93b2a0635154bb70ee9e9c1e1b")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/custody-rescue", clueID: "custody-rescue-family-trace",
        receiptID: "l337.unwritten-route/clue/custody-rescue-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/7/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1custody-rescue"),
        archive: .init(path: "charter-archive-models-a.json", sha256: "31def56c1114556324405731dcc208340f7eb4aa1eb06eee669fdeaa4d39beb0"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/custody-rescue/archive/rescue-consent-editor", replicaID: "proposed-replica-rescue-consent-editor",
          originIdentity: "proposed-rescue-consent-editor", originDomain: "rescue-consent-editor",
          payloadSHA256: "f79b136fc54bc0796c19aac0e38442948289a778ec134345329177e3dd0f30e0",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/7/offerDialog", fragmentSHA256: "adfa0931db6627222b914680da75d43133971adf0f92d07143935d531ec30ec1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/custody-rescue/archive/survivor-reception-custodian", replicaID: "proposed-replica-survivor-reception-custodian",
          originIdentity: "proposed-survivor-reception-custodian", originDomain: "survivor-reception-custodian",
          payloadSHA256: "c061b4ea24e48026606213a20ec9da0d3a1dc12b572563f53d539d80256de6df",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/7/stages/1/objective", fragmentSHA256: "0328847a58976389a871e0987b72817332b2481b92b14db7e01666bd3790b890")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/custody-rescue/archive/rescue-reference-curator", replicaID: "proposed-replica-rescue-reference-curator",
          originIdentity: "proposed-rescue-reference-curator", originDomain: "rescue-reference-curator",
          payloadSHA256: "ccc17393345cf332c08022cd6bbd9c1dc92704dde9978bfec3461f955903cd19",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/7/completionClue/receipt", fragmentSHA256: "5bce76d8ea3bd38c691a3fa015b17a4abfce82547486454452032dfeb9aa10e6")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234796, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/hostile-larvaal-defence", clueID: "hostile-larvaal-defence-family-trace",
        receiptID: "l337.unwritten-route/clue/hostile-larvaal-defence-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/14/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1hostile-larvaal-defence"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/hostile-larvaal-defence/archive/designated-hostile-editor", replicaID: "proposed-replica-designated-hostile-editor",
          originIdentity: "proposed-designated-hostile-editor", originDomain: "designated-hostile-editor",
          payloadSHA256: "6472f0ab69c94387b3a6c44316fb55c7b448a51863bf3148a2d8ce5e4a82e3c2",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/14/offerDialog", fragmentSHA256: "0f4f047f075967d94d69560d4486a4dfbcf85273ab205bcb15676661e6a0d75f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/hostile-larvaal-defence/archive/larvaal-attribution-custodian", replicaID: "proposed-replica-larvaal-attribution-custodian",
          originIdentity: "proposed-larvaal-attribution-custodian", originDomain: "larvaal-attribution-custodian",
          payloadSHA256: "87d4a263a8a25bf06bf3a6d24b524c2e47e64f81b5ec999772cfce96b98dcab7",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/14/stages/1/objective", fragmentSHA256: "a11b0718192160d4dfccf52c75194f46825bfa96b33d3db8ad530085cd2eff2c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/hostile-larvaal-defence/archive/hostile-task-trace-curator", replicaID: "proposed-replica-hostile-task-trace-curator",
          originIdentity: "proposed-hostile-task-trace-curator", originDomain: "hostile-task-trace-curator",
          payloadSHA256: "2e3c73aa032126bac835443ed69192aead4fb499879ee5e8bb9f41de9e86a14a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/14/completionClue/receipt", fragmentSHA256: "bc689b132a812dec5e8e3271352cd31b90c77b469933a6b0c134f6b59c845652")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/identified-salvage", clueID: "identified-salvage-family-trace",
        receiptID: "l337.unwritten-route/clue/identified-salvage-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/8/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1identified-salvage"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/identified-salvage/archive/salvage-scope-editor", replicaID: "proposed-replica-salvage-scope-editor",
          originIdentity: "proposed-salvage-scope-editor", originDomain: "salvage-scope-editor",
          payloadSHA256: "99e5bea35d893c7078821f570698ef0a7efa0ca0ecad05470ff5b074ef9c298e",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/8/offerDialog", fragmentSHA256: "55d4d099656dc8aa86213fdb96afb2240fccbcf728dd252656476fee36e1e9ba")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/identified-salvage/archive/recovered-custody-custodian", replicaID: "proposed-replica-recovered-custody-custodian",
          originIdentity: "proposed-recovered-custody-custodian", originDomain: "recovered-custody-custodian",
          payloadSHA256: "949cb7bf874daf86ad7e532f316246433a288f2d9111b20a11bffac20fcc0846",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/8/stages/1/objective", fragmentSHA256: "8d6f4438b8a973fa70b4ce824eb98ceb5caea4a3afbf138a2ce58181c63f480a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/identified-salvage/archive/salvage-reference-curator", replicaID: "proposed-replica-salvage-reference-curator",
          originIdentity: "proposed-salvage-reference-curator", originDomain: "salvage-reference-curator",
          payloadSHA256: "8833fa946b3b41811ba03ab8745f7f9070fc8a860f3f5bc74f30c238370ab399",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/8/completionClue/receipt", fragmentSHA256: "198ef20412e11f1af81230917e6d8058b3a2242ca7ac8e254ef81226ba07f08a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/isolation-work", clueID: "isolation-work-family-trace",
        receiptID: "l337.unwritten-route/clue/isolation-work-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/10/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1isolation-work"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/isolation-work/archive/external-isolation-editor", replicaID: "proposed-replica-external-isolation-editor",
          originIdentity: "proposed-external-isolation-editor", originDomain: "external-isolation-editor",
          payloadSHA256: "b3a4fcf98b8565a29d4d4d2faba75455c1d1a43f537bc865213678d8b135a8e0",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/10/offerDialog", fragmentSHA256: "f49657b225a716155e0e9e6eb4a17fa50a52181dbd3528b93c58df0ebdf19c2c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/isolation-work/archive/isolated-work-custodian", replicaID: "proposed-replica-isolated-work-custodian",
          originIdentity: "proposed-isolated-work-custodian", originDomain: "isolated-work-custodian",
          payloadSHA256: "fb6d235a95a75067b0b2e2837ea0822b6e16a13efae21d12aaee16c345b52f4a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/10/stages/1/objective", fragmentSHA256: "46e0e5a7cfb701e9f331a4c63f18e21841e980423e390d67061ca01661545bfa")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/isolation-work/archive/isolation-reference-curator", replicaID: "proposed-replica-isolation-reference-curator",
          originIdentity: "proposed-isolation-reference-curator", originDomain: "isolation-reference-curator",
          payloadSHA256: "c69c0f0a887e4bb60c3dcce445d63157936c5b67069ca225711fab9e3b0cab2f",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/10/completionClue/receipt", fragmentSHA256: "eefd2b1cc9f113e9115414251ddc44119ac89af1116e51e64b02a2e76c7c6cd2")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/measured-extraction", clueID: "measured-extraction-family-trace",
        receiptID: "l337.unwritten-route/clue/measured-extraction-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/11/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1measured-extraction"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/measured-extraction/archive/extraction-scope-editor", replicaID: "proposed-replica-extraction-scope-editor",
          originIdentity: "proposed-extraction-scope-editor", originDomain: "extraction-scope-editor",
          payloadSHA256: "f40ef9ab341b6c2166c141548fffcf9e1e198d5f206b92df7c9c6132469ba74d",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/11/offerDialog", fragmentSHA256: "f194b8bae0dc465fe72005716dc5f566d13c52e7231aca0b5778f464ba0db288")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/measured-extraction/archive/material-reception-custodian", replicaID: "proposed-replica-material-reception-custodian",
          originIdentity: "proposed-material-reception-custodian", originDomain: "material-reception-custodian",
          payloadSHA256: "ef0b2c6728589b51485fba7331f485cbc14658493695c467a597ea5e912bd932",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/11/stages/1/objective", fragmentSHA256: "3db2225f233656de61c16b159fa227a1025b35b809d6fa4f9456c85dee049618")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/measured-extraction/archive/extraction-reference-curator", replicaID: "proposed-replica-extraction-reference-curator",
          originIdentity: "proposed-extraction-reference-curator", originDomain: "extraction-reference-curator",
          payloadSHA256: "77ec3a52f28b7510851fa946dd77104d0107be57374d490b8240b6738844448e",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/11/completionClue/receipt", fragmentSHA256: "08cd13ac8a508fdf0224b7f8d7e1698e9b5b363f97991cbfe03bd88b7c178d0e")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/mutual-contribution", clueID: "mutual-contribution-family-trace",
        receiptID: "l337.unwritten-route/clue/mutual-contribution-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/12/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1mutual-contribution"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/mutual-contribution/archive/contribution-consent-editor", replicaID: "proposed-replica-contribution-consent-editor",
          originIdentity: "proposed-contribution-consent-editor", originDomain: "contribution-consent-editor",
          payloadSHA256: "0c4688094a6c086327887ae78179b40d91f98601b35e2a6b1788571e6f2eb0c6",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/12/offerDialog", fragmentSHA256: "d270a54a125a9c05df1594445ed99e871046f2c7fabf77364512f69b75e7a536")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/mutual-contribution/archive/resource-transfer-custodian", replicaID: "proposed-replica-resource-transfer-custodian",
          originIdentity: "proposed-resource-transfer-custodian", originDomain: "resource-transfer-custodian",
          payloadSHA256: "ff468b43a054d3a9363498f9b134654d23fe2addc7a196103edc2ec51bd0b462",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/12/stages/1/objective", fragmentSHA256: "4c0f4aff50e1a57affbb0e956009294fac04281a42c9e5fe24b4780a7c84818a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/mutual-contribution/archive/contribution-reference-curator", replicaID: "proposed-replica-contribution-reference-curator",
          originIdentity: "proposed-contribution-reference-curator", originDomain: "contribution-reference-curator",
          payloadSHA256: "374d72245a9dc9dcda448485f7d8b05f481d7c1104dc5cd02c9a6f1b5f18c6ec",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/12/completionClue/receipt", fragmentSHA256: "f8c21dc8e00cbf3ab1841c2e8b967da182123b70c7653221438a50aeb501c4a9")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/orbital-evacuation", clueID: "orbital-evacuation-family-trace",
        receiptID: "l337.unwritten-route/clue/orbital-evacuation-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/13/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1orbital-evacuation"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/orbital-evacuation/archive/evacuation-registration-editor", replicaID: "proposed-replica-evacuation-registration-editor",
          originIdentity: "proposed-evacuation-registration-editor", originDomain: "evacuation-registration-editor",
          payloadSHA256: "589717c05ccd6e9303988493a4c53d1307d7533630c70dd103ea68c6bec7d939",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/13/offerDialog", fragmentSHA256: "0ae1a8132d5e62be073cec98c301def830716631fd1405c10f3d3298c7823433")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/orbital-evacuation/archive/boarding-reception-custodian", replicaID: "proposed-replica-boarding-reception-custodian",
          originIdentity: "proposed-boarding-reception-custodian", originDomain: "boarding-reception-custodian",
          payloadSHA256: "3167306eaac879f52a3b2b8fcfe331347b227537e8be98ccb4b2bc5398d858b1",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/13/stages/1/objective", fragmentSHA256: "3cf98bd4ce4fd2709b30a5960aac77d67daf18e0a2b2f31ee1ac02e74380b650")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/orbital-evacuation/archive/evacuation-reference-curator", replicaID: "proposed-replica-evacuation-reference-curator",
          originIdentity: "proposed-evacuation-reference-curator", originDomain: "evacuation-reference-curator",
          payloadSHA256: "bf2288723951c63ce89565a2bb186c7c2e2740f3c16ba1ed2254bab76e692b74",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/13/completionClue/receipt", fragmentSHA256: "2eebad636bf60149e506686f30929f462d71f20c1341a5c9b91aa6817c73b85b")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/orbital-outlook", clueID: "orbital-outlook-family-trace",
        receiptID: "l337.unwritten-route/clue/orbital-outlook-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/4/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1orbital-outlook"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/orbital-outlook/archive/outlook-consent-editor", replicaID: "proposed-replica-outlook-consent-editor",
          originIdentity: "proposed-outlook-consent-editor", originDomain: "outlook-consent-editor",
          payloadSHA256: "5f8516dfb366fa050ec73f2be2d4672220f95662d61f74ba5dd1c6399e8bd9a7",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/4/offerDialog", fragmentSHA256: "7c1a034a4a66f33d1c4a6d0a278d40841895452f84529f0f64ac727e2cde46a7")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/orbital-outlook/archive/viewing-route-custodian", replicaID: "proposed-replica-viewing-route-custodian",
          originIdentity: "proposed-viewing-route-custodian", originDomain: "viewing-route-custodian",
          payloadSHA256: "820249bd1f7264fc82403a6e4eaa2d19ca3cea92aef56a4f17e48854d7757e96",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/4/stages/1/objective", fragmentSHA256: "d9126d4bfc45ec724b0771bac8ef28b8945c4d80ec75136e5103c2b1a6fae6bf")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/orbital-outlook/archive/outlook-reference-curator", replicaID: "proposed-replica-outlook-reference-curator",
          originIdentity: "proposed-outlook-reference-curator", originDomain: "outlook-reference-curator",
          payloadSHA256: "6915e8047979a271ad01c81277a1d3d94027e9472c8e6dc6d778449d1faa032c",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/4/completionClue/receipt", fragmentSHA256: "98f77fe73bb8084fa14b0a268ab52658da3e5086926f67c6daeaa1fedfe947d0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/sealed-dispatch", clueID: "sealed-dispatch-family-trace",
        receiptID: "l337.unwritten-route/clue/sealed-dispatch-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/0/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1sealed-dispatch"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/sealed-dispatch/archive/dispatch-seal-editor", replicaID: "proposed-replica-dispatch-seal-editor",
          originIdentity: "proposed-dispatch-seal-editor", originDomain: "dispatch-seal-editor",
          payloadSHA256: "5a61bdf278d05008448b234f1640a609ad5c77acd6ec61cb7a16f47278b0d839",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/0/offerDialog", fragmentSHA256: "4f5cd7b9efbdbc8c216c1f0b2d60809ac24b591c735a168191bdfa7ef4b2159c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/sealed-dispatch/archive/sealed-item-reception-custodian", replicaID: "proposed-replica-sealed-item-reception-custodian",
          originIdentity: "proposed-sealed-item-reception-custodian", originDomain: "sealed-item-reception-custodian",
          payloadSHA256: "d2a51233d9f912f4c55f6e9ad20d69c04ef792eb7d4058d0de735571d0256ef3",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/0/stages/1/objective", fragmentSHA256: "850deb190120c55dde5ead2380961fc9cc583f489adeb4be052601fea168061a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/sealed-dispatch/archive/sealed-dispatch-reference-curator", replicaID: "proposed-replica-sealed-dispatch-reference-curator",
          originIdentity: "proposed-sealed-dispatch-reference-curator", originDomain: "sealed-dispatch-reference-curator",
          payloadSHA256: "6685394e04b99177e5fd013bec27bf27a79ebd0924a2f0c3d266cd1489eebdcc",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/0/completionClue/receipt", fragmentSHA256: "14d6ad200f577faa736b5321dea4f4442aa5bc9f3c70ec4f244d750dabb017b7")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.contract/verified-warrant", clueID: "verified-warrant-family-trace",
        receiptID: "l337.unwritten-route/clue/verified-warrant-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/5/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.contract~1verified-warrant"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.contract/verified-warrant/archive/hostile-warrant-editor", replicaID: "proposed-replica-hostile-warrant-editor",
          originIdentity: "proposed-hostile-warrant-editor", originDomain: "hostile-warrant-editor",
          payloadSHA256: "6c022610e9644ae9d091cd09faf6debcf8a063edfddc03e39dc245761a76ecf4",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/5/offerDialog", fragmentSHA256: "226f3cf384b22ba09ed2fb5d4e06ee43a3231259d3f6db4efa8848132484e1ce")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.contract/verified-warrant/archive/warrant-action-custodian", replicaID: "proposed-replica-warrant-action-custodian",
          originIdentity: "proposed-warrant-action-custodian", originDomain: "warrant-action-custodian",
          payloadSHA256: "a4600b825477d2014d06aaf2658d274a3ad3d4008b691f962ebb67c03c9a08b3",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/5/stages/1/objective", fragmentSHA256: "404858b8bac6ced73fb4b936f899921c4bad5c6636b0ab7dcfd2e781ac2a3de3")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.contract/verified-warrant/archive/warrant-reference-curator", replicaID: "proposed-replica-warrant-reference-curator",
          originIdentity: "proposed-warrant-reference-curator", originDomain: "warrant-reference-curator",
          payloadSHA256: "6246d9d4fd3e173ff8d062e2eeb324d8cc2d535c1f528b7bf3e99f1bab59cc8f",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/5/completionClue/receipt", fragmentSHA256: "2cec9602b015df90a26f6d678d4f042e276b2bcd2f127e5c1c4df84f55d930b1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.courier", clueID: "courier-empty-destination",
        receiptID: "l337.unwritten-route/clue/courier-empty-destination",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/courier.json", sha256: "93061611f090d9e2b35a138f4026411ec425a35f38413f79586b44f17ecc63e3", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.courier"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.courier/archive/courier-release-editor", replicaID: "proposed-replica-courier-release-editor",
          originIdentity: "proposed-courier-release-editor", originDomain: "courier-release-editor",
          payloadSHA256: "dadfdf17df64734d8833cfde2701f4505142d00fba8071be66d495d13cebaec8",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/courier.json", fileSHA256: "93061611f090d9e2b35a138f4026411ec425a35f38413f79586b44f17ecc63e3", jsonPointer: "/story", fragmentSHA256: "ea227df6bfeb432168da9f4073ec0e0ed9e7e29432f71cdb5ef402f9bac25180")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.courier/archive/custody-interlock-custodian", replicaID: "proposed-replica-custody-interlock-custodian",
          originIdentity: "proposed-custody-interlock-custodian", originDomain: "custody-interlock-custodian",
          payloadSHA256: "aa77f12372d8da615018ba4faa8ef0b89fde9e7262f77cd0945a0fabfb474efc",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/courier.json", fileSHA256: "93061611f090d9e2b35a138f4026411ec425a35f38413f79586b44f17ecc63e3", jsonPointer: "/stages/1/objective", fragmentSHA256: "306783183370bf66ff0b6dcaf089436448e15e692754be1604c2312f796e11b2")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.courier/archive/courier-return-reference-curator", replicaID: "proposed-replica-courier-return-reference-curator",
          originIdentity: "proposed-courier-return-reference-curator", originDomain: "courier-return-reference-curator",
          payloadSHA256: "7a0fe9c1f21b805ba2e143a44178c298282917c54bfe5439ebafcccdea47cfa3",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/courier.json", fileSHA256: "93061611f090d9e2b35a138f4026411ec425a35f38413f79586b44f17ecc63e3", jsonPointer: "/completionClue/receipt", fragmentSHA256: "1901a73b7dd9be480fc36f16ffcfce0a0db56cebc0126c259fa0e3f43d0b30ff")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.false-colours", clueID: "false-colours-trace",
        receiptID: "l337.unwritten-route/clue/false-colours-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/false-colours.json", sha256: "4a8f144011e8611f77cc82ff7019faf4a3a275b3b21c93aea5d023dc17f9b4db", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.false-colours"),
        archive: .init(path: "charter-archive-models-b.json", sha256: "367aec865975f84d471cfc2bfa0f0e35b82b56271164a8b6b1cc1b82aa376f96"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.false-colours/archive/key-revocation-editor", replicaID: "proposed-replica-key-revocation-editor",
          originIdentity: "proposed-key-revocation-editor", originDomain: "key-revocation-editor",
          payloadSHA256: "c6ef5cf86f2154cb74a42212ddbca70e41808d5748fae0cc324d2a7c991f0afe",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/false-colours.json", fileSHA256: "4a8f144011e8611f77cc82ff7019faf4a3a275b3b21c93aea5d023dc17f9b4db", jsonPointer: "/story", fragmentSHA256: "f5539e7374b998302d35b20f60d3da3e85a582e7e2c457e92570991c6d3f080a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.false-colours/archive/identity-reissue-custodian", replicaID: "proposed-replica-identity-reissue-custodian",
          originIdentity: "proposed-identity-reissue-custodian", originDomain: "identity-reissue-custodian",
          payloadSHA256: "98eb10ef5627bd8f7c0b08a5153abb37fda841f932d2147b1ad4796a9df866c9",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/false-colours.json", fileSHA256: "4a8f144011e8611f77cc82ff7019faf4a3a275b3b21c93aea5d023dc17f9b4db", jsonPointer: "/stages/1/objective", fragmentSHA256: "db16f6480ae8a54ff6b135791d562ecc2b3206d046139b717a7c58d02c84d012")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.false-colours/archive/identity-reference-curator", replicaID: "proposed-replica-identity-reference-curator",
          originIdentity: "proposed-identity-reference-curator", originDomain: "identity-reference-curator",
          payloadSHA256: "0184617e343f5e794d1d5c35c281eae5a039788a1c79a24b2e156f2e67ff66af",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/false-colours.json", fileSHA256: "4a8f144011e8611f77cc82ff7019faf4a3a275b3b21c93aea5d023dc17f9b4db", jsonPointer: "/completionClue/receipt", fragmentSHA256: "35410d2c0a6f30a48472f03464d71f001f34bee34d0763282e9ffc8b1ffdc4fd")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 234594, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.fleet-of-neighbours", clueID: "fleet-of-neighbours-trace",
        receiptID: "l337.unwritten-route/clue/fleet-of-neighbours-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/fleet-of-neighbours.json", sha256: "18829ed037b93166312d33b67652ceea447dbc427e549b50c47dd9bed9e8d479", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.fleet-of-neighbours"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.fleet-of-neighbours/archive/arrived-fleet-editor", replicaID: "proposed-replica-arrived-fleet-editor",
          originIdentity: "proposed-arrived-fleet-editor", originDomain: "arrived-fleet-editor",
          payloadSHA256: "8199ca6c50cfcc3d7a17af9e05acfaa5a2a5606312b16925308e14376179c3b5",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/fleet-of-neighbours.json", fileSHA256: "18829ed037b93166312d33b67652ceea447dbc427e549b50c47dd9bed9e8d479", jsonPointer: "/story", fragmentSHA256: "93fd665c3a912ea85259bb62dd4d87734cd772266c0c24a38e6914bf17ffa509")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.fleet-of-neighbours/archive/fleet-capacity-custodian", replicaID: "proposed-replica-fleet-capacity-custodian",
          originIdentity: "proposed-fleet-capacity-custodian", originDomain: "fleet-capacity-custodian",
          payloadSHA256: "815d1ab36ccdb77799120ca02032e2e51aa397634890905449306bd0c45e87cd",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/fleet-of-neighbours.json", fileSHA256: "18829ed037b93166312d33b67652ceea447dbc427e549b50c47dd9bed9e8d479", jsonPointer: "/stages/1/objective", fragmentSHA256: "854e99fac096e2a26144fe76e7f4b4b8322cbe28be4492632d3574708e9ffb30")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.fleet-of-neighbours/archive/fleet-schedule-reference-curator", replicaID: "proposed-replica-fleet-schedule-reference-curator",
          originIdentity: "proposed-fleet-schedule-reference-curator", originDomain: "fleet-schedule-reference-curator",
          payloadSHA256: "82922d4c4778384bb41d390c77df16d0209893a9165578b52a9377b8c4957436",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/fleet-of-neighbours.json", fileSHA256: "18829ed037b93166312d33b67652ceea447dbc427e549b50c47dd9bed9e8d479", jsonPointer: "/completionClue/receipt", fragmentSHA256: "ec2281f03f70f5384ca472fec631e097f05ed151718f956fadb274ff1b355ff1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.garden-in-transit", clueID: "garden-in-transit-trace",
        receiptID: "l337.unwritten-route/clue/garden-in-transit-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/garden-in-transit.json", sha256: "455def33ff05273c8a9b0133f81c53f5367721bf724f9efe9c09ae313fc2ddab", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.garden-in-transit"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.garden-in-transit/archive/quarantine-custody-editor", replicaID: "proposed-replica-quarantine-custody-editor",
          originIdentity: "proposed-quarantine-custody-editor", originDomain: "quarantine-custody-editor",
          payloadSHA256: "18f455d28e959e3bcdf21225ffa113144ae33e9311c74be14abdfc94f9f17b2b",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/garden-in-transit.json", fileSHA256: "455def33ff05273c8a9b0133f81c53f5367721bf724f9efe9c09ae313fc2ddab", jsonPointer: "/story", fragmentSHA256: "a7344106396c3f10bf35c6b2cc285782c88c3d4533621c0d2030febf08999279")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.garden-in-transit/archive/climate-reference-custodian", replicaID: "proposed-replica-climate-reference-custodian",
          originIdentity: "proposed-climate-reference-custodian", originDomain: "climate-reference-custodian",
          payloadSHA256: "4099b1c7200f9bd03be3f5c98241d908944e1b32bf6e2e10dba4e9676218db86",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/garden-in-transit.json", fileSHA256: "455def33ff05273c8a9b0133f81c53f5367721bf724f9efe9c09ae313fc2ddab", jsonPointer: "/stages/1/objective", fragmentSHA256: "557dc3d5606a0b4299df51134ad224ed8184b767244f6614e1dcd18d77e05c57")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.garden-in-transit/archive/garden-reception-reference-curator", replicaID: "proposed-replica-garden-reception-reference-curator",
          originIdentity: "proposed-garden-reception-reference-curator", originDomain: "garden-reception-reference-curator",
          payloadSHA256: "a88e146f63818726a891d58e4f891cb0dca6f05c12c03d0f0e40bc0269fc7d41",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/garden-in-transit.json", fileSHA256: "455def33ff05273c8a9b0133f81c53f5367721bf724f9efe9c09ae313fc2ddab", jsonPointer: "/completionClue/receipt", fragmentSHA256: "d6da5011e9ba75cd1b4365ca7075660fc8af26e1eb4aeeeeffca9222f856ef7a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.glass-meridian", clueID: "meridian-offset",
        receiptID: "l337.unwritten-route/clue/meridian-offset",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/glass-meridian.json", sha256: "14e29571b5c6335ecca5068516448224944e6881462aa329f14bb6a1cb2ea572", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.glass-meridian"),
        archive: .init(path: "charter-archive-observations.json", sha256: "131fec20b046881742ae3b76ef6e69bf64ca9caad65482267dbf6417ffebb26a"), calibration: .init(path: "recovery-policy.json", sha256: "35fe099defefccbd7d5c917e156e36de95240079536325c88c4f56468c98ea04"),
        observations: [
        .init(ordinal: 0, recordID: "l337.glass-meridian/archive/traffic-notice", replicaID: "charter-replica-traffic",
          originIdentity: "proposed-avenor-lane-notice-custodian", originDomain: "traffic-publication",
          payloadSHA256: "65e420e62faecda10489da8dfb293742b60a317847b381eef21456d9af4062bc",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/glass-meridian.json", fileSHA256: "14e29571b5c6335ecca5068516448224944e6881462aa329f14bb6a1cb2ea572", jsonPointer: "/story", fragmentSHA256: "9f90fe9d1aedbd0c325cb14d9f8835b0e482aefb71c370510f0f83fbdeab8a9d")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.glass-meridian/archive/clock-notice", replicaID: "charter-replica-certification",
          originIdentity: "proposed-certified-lane-clock-custodian", originDomain: "clock-certification",
          payloadSHA256: "c104ba048e4534998b3a41dcba2e1a31e9dd4ba39a57f54200eac9524b7bc8e0",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/glass-meridian.json", fileSHA256: "14e29571b5c6335ecca5068516448224944e6881462aa329f14bb6a1cb2ea572", jsonPointer: "/story", fragmentSHA256: "1e4a81f17ab56a0eda35f4dc164cd265973e44d83d40aafc67c8f83f08c3447d")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.glass-meridian/archive/trace-reference", replicaID: "charter-replica-reference",
          originIdentity: "proposed-independent-meridian-reference-custodian", originDomain: "independent-reference",
          payloadSHA256: "138dbdc2e2c7aa35996fba42d11942a0f69ac13970f94863352bf3cddabf2b9f",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/glass-meridian.json", fileSHA256: "14e29571b5c6335ecca5068516448224944e6881462aa329f14bb6a1cb2ea572", jsonPointer: "/completionClue/journalText", fragmentSHA256: "4112a5d32e27361859fc2f1bfec418b9a197397af3cfc8363767207f01365f8b")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 22201, calibrationBytes: 3023),
      .init(source: .init(sourceID: "l337.guiding-light", clueID: "lantern-extra-echo",
        receiptID: "l337.unwritten-route/clue/lantern-extra-echo",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/guiding-light.json", sha256: "95204252f6c21570eb703108209c2759f62667d1c13036abd7109b29e47a4aa5", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.guiding-light"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.guiding-light/archive/sight-line-editor", replicaID: "proposed-replica-sight-line-editor",
          originIdentity: "proposed-sight-line-editor", originDomain: "sight-line-editor",
          payloadSHA256: "4f37d0650bd24eeb25b402933e8f2dc4855d6c12ae4277db7496400f60e577f4",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/guiding-light.json", fileSHA256: "95204252f6c21570eb703108209c2759f62667d1c13036abd7109b29e47a4aa5", jsonPointer: "/story", fragmentSHA256: "0c36014ba81b402aaf5af7d41a90bb3e7e2242e302e95f2e639bf5633cedfae6")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.guiding-light/archive/coverage-interval-custodian", replicaID: "proposed-replica-coverage-interval-custodian",
          originIdentity: "proposed-coverage-interval-custodian", originDomain: "coverage-interval-custodian",
          payloadSHA256: "bf369996556110b4ac4e554d62785f2451dbda887fb9d72354c97f47df8ebb8d",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/guiding-light.json", fileSHA256: "95204252f6c21570eb703108209c2759f62667d1c13036abd7109b29e47a4aa5", jsonPointer: "/stages/1/objective", fragmentSHA256: "306783183370bf66ff0b6dcaf089436448e15e692754be1604c2312f796e11b2")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.guiding-light/archive/guiding-beacon-reference-curator", replicaID: "proposed-replica-guiding-beacon-reference-curator",
          originIdentity: "proposed-guiding-beacon-reference-curator", originDomain: "guiding-beacon-reference-curator",
          payloadSHA256: "b050d7a0db49440d522a58aa5a2f81130f3a41eabc5e4e41e1660b2ad5043250",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/guiding-light.json", fileSHA256: "95204252f6c21570eb703108209c2759f62667d1c13036abd7109b29e47a4aa5", jsonPointer: "/completionClue/receipt", fragmentSHA256: "f0b085d5c55270307424468ffe646c37f47f01074d3c615f86517a9e914168a2")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.harbour-without-orders", clueID: "harbour-without-orders-trace",
        receiptID: "l337.unwritten-route/clue/harbour-without-orders-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/harbour-without-orders.json", sha256: "5f0790b611519cccfae130a27e3b74440fd706107216c95c70e02e29fc57d667", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.harbour-without-orders"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.harbour-without-orders/archive/berth-occupancy-editor", replicaID: "proposed-replica-berth-occupancy-editor",
          originIdentity: "proposed-berth-occupancy-editor", originDomain: "berth-occupancy-editor",
          payloadSHA256: "92a580028666852ae473de80adbcea89d35232f7d431fb3a4465fa199fbf8f36",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/harbour-without-orders.json", fileSHA256: "5f0790b611519cccfae130a27e3b74440fd706107216c95c70e02e29fc57d667", jsonPointer: "/story", fragmentSHA256: "787212c3f9815c4e0bbd6d3b0e9f95bf3451637faa539b8bc3b2708ff334c745")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.harbour-without-orders/archive/allocation-exclusion-custodian", replicaID: "proposed-replica-allocation-exclusion-custodian",
          originIdentity: "proposed-allocation-exclusion-custodian", originDomain: "allocation-exclusion-custodian",
          payloadSHA256: "ae90931a744e2bdff64b3dc4b6c23f983e99aac752120a39f1cb048fe03508dd",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/harbour-without-orders.json", fileSHA256: "5f0790b611519cccfae130a27e3b74440fd706107216c95c70e02e29fc57d667", jsonPointer: "/stages/1/objective", fragmentSHA256: "8513ac3174b490cf87eac8347318e16b0e3c4697403058a7c9c3695674dddd7f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.harbour-without-orders/archive/harbour-reference-curator", replicaID: "proposed-replica-harbour-reference-curator",
          originIdentity: "proposed-harbour-reference-curator", originDomain: "harbour-reference-curator",
          payloadSHA256: "efaf02227187817a6c01006558e78af91aa535d37323e1012be8e72a30ba3832",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/harbour-without-orders.json", fileSHA256: "5f0790b611519cccfae130a27e3b74440fd706107216c95c70e02e29fc57d667", jsonPointer: "/completionClue/receipt", fragmentSHA256: "28bc1f52d925d850c63bec0e52f73852cb341f983f53adced3d9fef314e5672f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.hollow-manifest", clueID: "manifest-hidden-imprint",
        receiptID: "l337.unwritten-route/clue/manifest-hidden-imprint",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/hollow-manifest.json", sha256: "82d8567a390bdd82b68a08430b071da84696e07e6b1d5a027f3ee5690e065e2a", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.hollow-manifest"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.hollow-manifest/archive/manifest-source-editor", replicaID: "proposed-replica-manifest-source-editor",
          originIdentity: "proposed-manifest-source-editor", originDomain: "manifest-source-editor",
          payloadSHA256: "64899ec1b9ca081b06bca9979b9ccadaa85a1882c6f0d0c7131942fc391dabd2",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/hollow-manifest.json", fileSHA256: "82d8567a390bdd82b68a08430b071da84696e07e6b1d5a027f3ee5690e065e2a", jsonPointer: "/story", fragmentSHA256: "a21090114638ea9f8091fef905293418e70e0f4a856de84e6541d44555532a27")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.hollow-manifest/archive/manifest-reception-custodian", replicaID: "proposed-replica-manifest-reception-custodian",
          originIdentity: "proposed-manifest-reception-custodian", originDomain: "manifest-reception-custodian",
          payloadSHA256: "850bc694cbbbd4c20d4ac385bbdc77645b32b8bdc8210455f119e40982c474e2",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/hollow-manifest.json", fileSHA256: "82d8567a390bdd82b68a08430b071da84696e07e6b1d5a027f3ee5690e065e2a", jsonPointer: "/stages/1/objective", fragmentSHA256: "9e8022814dba05a9d891825ad304fde80c3474fdea2aa084843a6ab2516a347b")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.hollow-manifest/archive/protected-manifest-trace-curator", replicaID: "proposed-replica-protected-manifest-trace-curator",
          originIdentity: "proposed-protected-manifest-trace-curator", originDomain: "protected-manifest-trace-curator",
          payloadSHA256: "45e69b6997d85a5b7f8ce8dea125d1e9aca1cb84235b2034ee9a7735dc35b678",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/hollow-manifest.json", fileSHA256: "82d8567a390bdd82b68a08430b071da84696e07e6b1d5a027f3ee5690e065e2a", jsonPointer: "/completionClue/receipt", fragmentSHA256: "d9e572410fe9993597e38b0da5fd1f4623765f05ead2f708fe67ff773933c791")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.honest-circuit", clueID: "honest-circuit-trace",
        receiptID: "l337.unwritten-route/clue/honest-circuit-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/honest-circuit.json", sha256: "b7a30dd4d3d37883c244f01c0a5c58bc5e643e262f27b85069d66696c91beb72", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.honest-circuit"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.honest-circuit/archive/course-fuel-editor", replicaID: "proposed-replica-course-fuel-editor",
          originIdentity: "proposed-course-fuel-editor", originDomain: "course-fuel-editor",
          payloadSHA256: "31a5dc9cd1be3fd9491b26bdc92c3db3d535faed74386880af8425cd267a9c97",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/honest-circuit.json", fileSHA256: "b7a30dd4d3d37883c244f01c0a5c58bc5e643e262f27b85069d66696c91beb72", jsonPointer: "/story", fragmentSHA256: "f12b20baff0f4b6057f058f0a0b6d5490a308e91a5cd97ff226cbe8841ef1782")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.honest-circuit/archive/flight-accounting-custodian", replicaID: "proposed-replica-flight-accounting-custodian",
          originIdentity: "proposed-flight-accounting-custodian", originDomain: "flight-accounting-custodian",
          payloadSHA256: "5561af2a7da5824ec8876bf4d7ed698f5556abee135561bb873d93711eacfe48",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/honest-circuit.json", fileSHA256: "b7a30dd4d3d37883c244f01c0a5c58bc5e643e262f27b85069d66696c91beb72", jsonPointer: "/stages/1/objective", fragmentSHA256: "4d0cbe6144ad03b4ec83989059001b803c3f88fedd8715641b0f48c993502614")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.honest-circuit/archive/circuit-reference-curator", replicaID: "proposed-replica-circuit-reference-curator",
          originIdentity: "proposed-circuit-reference-curator", originDomain: "circuit-reference-curator",
          payloadSHA256: "384f663f30329eb2d9f4430f67d7de99b1d003bb1fdc67ff790723568c16cc5a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/honest-circuit.json", fileSHA256: "b7a30dd4d3d37883c244f01c0a5c58bc5e643e262f27b85069d66696c91beb72", jsonPointer: "/completionClue/receipt", fragmentSHA256: "a2462dcf95c989f602b54f0b8c5c3f2b0b3d93d894518aa665943c6fce600cbc")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.kind-distance", clueID: "kind-distance-trace",
        receiptID: "l337.unwritten-route/clue/kind-distance-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/kind-distance.json", sha256: "c7196b310ab1f71ccc5e955e47a5f5723eccc2b5ef147e9490a18dc2f66826c6", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.kind-distance"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.kind-distance/archive/anonymous-permission-editor", replicaID: "proposed-replica-anonymous-permission-editor",
          originIdentity: "proposed-anonymous-permission-editor", originDomain: "anonymous-permission-editor",
          payloadSHA256: "c247cbd2bb03e9c4fa33a37e0ace23723015e2486f77be1834a3945e0a8c6b88",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/kind-distance.json", fileSHA256: "c7196b310ab1f71ccc5e955e47a5f5723eccc2b5ef147e9490a18dc2f66826c6", jsonPointer: "/story", fragmentSHA256: "e4e76dc3c79ddf8b3621eca6473b6cbb20610ecd1d30e39973cdda1e2c4714df")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.kind-distance/archive/reply-reception-custodian", replicaID: "proposed-replica-reply-reception-custodian",
          originIdentity: "proposed-reply-reception-custodian", originDomain: "reply-reception-custodian",
          payloadSHA256: "e018cdabf1cf9b9d3487a3db094a966d818784e03cebc4fd814873f0e5013b30",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/kind-distance.json", fileSHA256: "c7196b310ab1f71ccc5e955e47a5f5723eccc2b5ef147e9490a18dc2f66826c6", jsonPointer: "/stages/1/objective", fragmentSHA256: "22625371f9c2372ccf00c34b5c1a6929fef7afdba3d552c6943584f787cc19ee")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.kind-distance/archive/revocation-reference-curator", replicaID: "proposed-replica-revocation-reference-curator",
          originIdentity: "proposed-revocation-reference-curator", originDomain: "revocation-reference-curator",
          payloadSHA256: "e14c6f620d594c299bd85c1ca4b4936eb53cf177fcc70d9f72ddc76c8990c1fc",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/kind-distance.json", fileSHA256: "c7196b310ab1f71ccc5e955e47a5f5723eccc2b5ef147e9490a18dc2f66826c6", jsonPointer: "/completionClue/receipt", fragmentSHA256: "4cdcfcaf4ac0e6a9087a5e3122608ff41fcaa4c4b7d794d1fc79263241d4d8e0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.listening-frontier", clueID: "listening-frontier-trace",
        receiptID: "l337.unwritten-route/clue/listening-frontier-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/listening-frontier.json", sha256: "d321b0c06d7b0213adc827e1cd727cb1f9064c8ab01b0032f4d6cb91a6027570", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.listening-frontier"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.listening-frontier/archive/quiet-window-editor", replicaID: "proposed-replica-quiet-window-editor",
          originIdentity: "proposed-quiet-window-editor", originDomain: "quiet-window-editor",
          payloadSHA256: "65d7be1e10381866dca4af016b57b57c328df0ea90af25178eebaaf13d1135ff",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/listening-frontier.json", fileSHA256: "d321b0c06d7b0213adc827e1cd727cb1f9064c8ab01b0032f4d6cb91a6027570", jsonPointer: "/story", fragmentSHA256: "7d0168ed9ddedc037eaa840ff42e137df8354cc50fac5b324f3857862542a849")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.listening-frontier/archive/reciprocal-timing-custodian", replicaID: "proposed-replica-reciprocal-timing-custodian",
          originIdentity: "proposed-reciprocal-timing-custodian", originDomain: "reciprocal-timing-custodian",
          payloadSHA256: "1470d7b63f151d997e7f181ef2e7e24e847de7d40c0611447b2d1e144d152bca",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/listening-frontier.json", fileSHA256: "d321b0c06d7b0213adc827e1cd727cb1f9064c8ab01b0032f4d6cb91a6027570", jsonPointer: "/stages/1/objective", fragmentSHA256: "30da95f821e5e8f9e04ce43fa4e6a64703e82219bc7e8dd56b64a94226533e94")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.listening-frontier/archive/listening-reference-curator", replicaID: "proposed-replica-listening-reference-curator",
          originIdentity: "proposed-listening-reference-curator", originDomain: "listening-reference-curator",
          payloadSHA256: "6fa0534d8bc1fc688e6c87fb0104d14a074e8f29a5c271fbfed7462213ccef41",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/listening-frontier.json", fileSHA256: "d321b0c06d7b0213adc827e1cd727cb1f9064c8ab01b0032f4d6cb91a6027570", jsonPointer: "/completionClue/receipt", fragmentSHA256: "72f86b198282ff3dccefb1787fa2d567d9a240b9f9afb90db3c17b82be30082a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.long-return", clueID: "long-return-trace",
        receiptID: "l337.unwritten-route/clue/long-return-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/long-return.json", sha256: "3e1decc3b4982885c539b6a07c6b8b7a1dea71a57f0fe54e6257258cd9e84019", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.long-return"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.long-return/archive/carrier-custody-editor", replicaID: "proposed-replica-carrier-custody-editor",
          originIdentity: "proposed-carrier-custody-editor", originDomain: "carrier-custody-editor",
          payloadSHA256: "63588e0857253a836680ce4a6fa50e27d479249f5cbd01529e0ef58c5ef5d643",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/long-return.json", fileSHA256: "3e1decc3b4982885c539b6a07c6b8b7a1dea71a57f0fe54e6257258cd9e84019", jsonPointer: "/story", fragmentSHA256: "44a82b522538f74424665859570e8cd4f11667668088b078223578b0940bd250")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.long-return/archive/handoff-reception-custodian", replicaID: "proposed-replica-handoff-reception-custodian",
          originIdentity: "proposed-handoff-reception-custodian", originDomain: "handoff-reception-custodian",
          payloadSHA256: "ed45559b0970f8c3bbe4880f07b261285eaad25f33f46e4a48b59ccfff806d22",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/long-return.json", fileSHA256: "3e1decc3b4982885c539b6a07c6b8b7a1dea71a57f0fe54e6257258cd9e84019", jsonPointer: "/stages/1/objective", fragmentSHA256: "295a3f0c2c3879eb389a3a31ff8eb5c37ff27e243b2faa19105af2119b24eca0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.long-return/archive/return-route-reference-curator", replicaID: "proposed-replica-return-route-reference-curator",
          originIdentity: "proposed-return-route-reference-curator", originDomain: "return-route-reference-curator",
          payloadSHA256: "6e174373a82c6d8ed22ca3cef450abcfe618730eef14b94aad74802080a14b1a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/long-return.json", fileSHA256: "3e1decc3b4982885c539b6a07c6b8b7a1dea71a57f0fe54e6257258cd9e84019", jsonPointer: "/completionClue/receipt", fragmentSHA256: "dc044147666223c955697a690ca9f60ca5c09b84d495bed99c5d5afe0e4aee58")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.magnetic-orchard", clueID: "magnetic-orchard-trace",
        receiptID: "l337.unwritten-route/clue/magnetic-orchard-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/magnetic-orchard.json", sha256: "935ff7abd683c06d625b7331e233e5b45a6493423282f31ed8da205b0c71ce3c", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.magnetic-orchard"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.magnetic-orchard/archive/field-boundary-editor", replicaID: "proposed-replica-field-boundary-editor",
          originIdentity: "proposed-field-boundary-editor", originDomain: "field-boundary-editor",
          payloadSHA256: "f9d3f44ab3425965515efab7bf158f5a56c4d08fd8ebadc9cb38e9293d0c8333",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/magnetic-orchard.json", fileSHA256: "935ff7abd683c06d625b7331e233e5b45a6493423282f31ed8da205b0c71ce3c", jsonPointer: "/story", fragmentSHA256: "d72ba9e097008b09e0bc1c44c51608b8163dbe637828396b95b409491414f561")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.magnetic-orchard/archive/non-destructive-release-custodian", replicaID: "proposed-replica-non-destructive-release-custodian",
          originIdentity: "proposed-non-destructive-release-custodian", originDomain: "non-destructive-release-custodian",
          payloadSHA256: "7e964ff7460251f2fb5939320eefac1b2dc1a36d951d522e7e93f08282560d68",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/magnetic-orchard.json", fileSHA256: "935ff7abd683c06d625b7331e233e5b45a6493423282f31ed8da205b0c71ce3c", jsonPointer: "/stages/1/objective", fragmentSHA256: "ffb228c6777b46ae3777fdbd5e23ac2edf878b0e0def839e602b444ee6c93068")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.magnetic-orchard/archive/orchard-reference-curator", replicaID: "proposed-replica-orchard-reference-curator",
          originIdentity: "proposed-orchard-reference-curator", originDomain: "orchard-reference-curator",
          payloadSHA256: "7c587f7404685ad277f179181dfdcd40f8c809446e3cc976621221d41a75f1cb",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/magnetic-orchard.json", fileSHA256: "935ff7abd683c06d625b7331e233e5b45a6493423282f31ed8da205b0c71ce3c", jsonPointer: "/completionClue/receipt", fragmentSHA256: "ea59acdf0fcd990e85fc6c65da9f0c6149590beb199e86cf51b5ae7acfd1f8c2")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.measure-of-care", clueID: "measure-of-care-trace",
        receiptID: "l337.unwritten-route/clue/measure-of-care-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/measure-of-care.json", sha256: "a11a2939995a20c5e2a97ba25b56887e06a8aa231b1d81aefd8eab039b75d004", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.measure-of-care"),
        archive: .init(path: "charter-archive-models-c.json", sha256: "10ea1688c3bec1f266f04b01ece849e2531e595fa4376d64da1ed705f2100c24"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.measure-of-care/archive/medical-reference-editor", replicaID: "proposed-replica-medical-reference-editor",
          originIdentity: "proposed-medical-reference-editor", originDomain: "medical-reference-editor",
          payloadSHA256: "e5c2c70e7ae22fa7166f817aa59213f0394a2271d8acb0b5bb3ecd6ffbbeb097",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/measure-of-care.json", fileSHA256: "a11a2939995a20c5e2a97ba25b56887e06a8aa231b1d81aefd8eab039b75d004", jsonPointer: "/story", fragmentSHA256: "b83a284749cd1f085508e94df25b869c997983a7cb526a8e6865e9a4ebb16ec1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.measure-of-care/archive/cold-calibration-custodian", replicaID: "proposed-replica-cold-calibration-custodian",
          originIdentity: "proposed-cold-calibration-custodian", originDomain: "cold-calibration-custodian",
          payloadSHA256: "4e9c13a14c6148fa96d21f4066cb2f6f957662eb09d593c75a018a88faec6274",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/measure-of-care.json", fileSHA256: "a11a2939995a20c5e2a97ba25b56887e06a8aa231b1d81aefd8eab039b75d004", jsonPointer: "/stages/1/objective", fragmentSHA256: "93d3d1b44dbf1ef1af78c12cc82fac9834973352366801f9aae867fef490133c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.measure-of-care/archive/care-reference-curator", replicaID: "proposed-replica-care-reference-curator",
          originIdentity: "proposed-care-reference-curator", originDomain: "care-reference-curator",
          payloadSHA256: "9ef5dfda7d78d8ba87bcbd82db6a8a6a48add284b7e021fa7867bb2988028ff5",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/measure-of-care.json", fileSHA256: "a11a2939995a20c5e2a97ba25b56887e06a8aa231b1d81aefd8eab039b75d004", jsonPointer: "/completionClue/receipt", fragmentSHA256: "0a94bd90def0bcd9175ad8afb11be9ee81b25c61ef03559e1d37b066cc720d3c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.memory-atlas", clueID: "memory-atlas-trace",
        receiptID: "l337.unwritten-route/clue/memory-atlas-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/memory-atlas.json", sha256: "376678f1e4ca646d299e2205739e74f81f02b525a6a2f187db0ce9893218a7d6", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.memory-atlas"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.memory-atlas/archive/coordinate-provenance-editor", replicaID: "proposed-replica-coordinate-provenance-editor",
          originIdentity: "proposed-coordinate-provenance-editor", originDomain: "coordinate-provenance-editor",
          payloadSHA256: "b4b6a10903763d2d0ca37591793abf549e29e13032b606e6eece58406fa7e423",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/memory-atlas.json", fileSHA256: "376678f1e4ca646d299e2205739e74f81f02b525a6a2f187db0ce9893218a7d6", jsonPointer: "/story", fragmentSHA256: "409b5731acae66c48ce4db4d9ddd4dfd1ff244d1bf47ef7af471af8df97bbea4")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.memory-atlas/archive/testimony-attribution-custodian", replicaID: "proposed-replica-testimony-attribution-custodian",
          originIdentity: "proposed-testimony-attribution-custodian", originDomain: "testimony-attribution-custodian",
          payloadSHA256: "2fb289650462d12032bba031f5c81912ea30c62b8e74521a7ee307e8a3c69263",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/memory-atlas.json", fileSHA256: "376678f1e4ca646d299e2205739e74f81f02b525a6a2f187db0ce9893218a7d6", jsonPointer: "/stages/1/objective", fragmentSHA256: "ffb228c6777b46ae3777fdbd5e23ac2edf878b0e0def839e602b444ee6c93068")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.memory-atlas/archive/memory-reference-curator", replicaID: "proposed-replica-memory-reference-curator",
          originIdentity: "proposed-memory-reference-curator", originDomain: "memory-reference-curator",
          payloadSHA256: "791cf3725f83d181b9918231cc9ba79daa52d47a5f30d5c0d7ac80fdf22a80cc",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/memory-atlas.json", fileSHA256: "376678f1e4ca646d299e2205739e74f81f02b525a6a2f187db0ce9893218a7d6", jsonPointer: "/completionClue/receipt", fragmentSHA256: "df789efcc871af2c645552f44ed5935b9aba7e88e412bc11deeb825b491bdb3f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.mutual-shelter", clueID: "mutual-shelter-trace",
        receiptID: "l337.unwritten-route/clue/mutual-shelter-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/mutual-shelter.json", sha256: "f19d6a6a811da621daebf0b77491ae7679a41a151985fa426697bfffdb059be6", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.mutual-shelter"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.mutual-shelter/archive/emergency-capacity-editor", replicaID: "proposed-replica-emergency-capacity-editor",
          originIdentity: "proposed-emergency-capacity-editor", originDomain: "emergency-capacity-editor",
          payloadSHA256: "a53c75c660b6db095c6c60019ba354e18f1566c6b180768ade1c31bf90c47e3d",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/mutual-shelter.json", fileSHA256: "f19d6a6a811da621daebf0b77491ae7679a41a151985fa426697bfffdb059be6", jsonPointer: "/story", fragmentSHA256: "202ee1e5667aecc9ff8dec1df665d84e4365210344d6743db7fd6ee5fdb66509")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.mutual-shelter/archive/shelter-stress-custodian", replicaID: "proposed-replica-shelter-stress-custodian",
          originIdentity: "proposed-shelter-stress-custodian", originDomain: "shelter-stress-custodian",
          payloadSHA256: "8327dcfb5b379edc9ef22e9960392ae1917df2f0300113a3bceb26bd67eff88a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/mutual-shelter.json", fileSHA256: "f19d6a6a811da621daebf0b77491ae7679a41a151985fa426697bfffdb059be6", jsonPointer: "/stages/1/objective", fragmentSHA256: "db16f6480ae8a54ff6b135791d562ecc2b3206d046139b717a7c58d02c84d012")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.mutual-shelter/archive/shelter-allocation-reference-curator", replicaID: "proposed-replica-shelter-allocation-reference-curator",
          originIdentity: "proposed-shelter-allocation-reference-curator", originDomain: "shelter-allocation-reference-curator",
          payloadSHA256: "48946cb99f94a8e5ba971ec4ff4a1dcdffccfe50248520e7296e3befa5e44144",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/mutual-shelter.json", fileSHA256: "f19d6a6a811da621daebf0b77491ae7679a41a151985fa426697bfffdb059be6", jsonPointer: "/completionClue/receipt", fragmentSHA256: "cd847cf31a3dc4eee3a5ed6d3005a7243706a6578c6ae7d32266f95a02b168d9")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.open-measure", clueID: "open-measure-trace",
        receiptID: "l337.unwritten-route/clue/open-measure-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-measure.json", sha256: "9c712197b46f25e90514b3b6c0913dcbdf9d062123ffc99547085577845ee6d6", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.open-measure"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.open-measure/archive/nominal-fit-editor", replicaID: "proposed-replica-nominal-fit-editor",
          originIdentity: "proposed-nominal-fit-editor", originDomain: "nominal-fit-editor",
          payloadSHA256: "ffd954265e1778bfa7b896153f486b37723a50d3eb95e12f62e9e84fd652b1c5",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-measure.json", fileSHA256: "9c712197b46f25e90514b3b6c0913dcbdf9d062123ffc99547085577845ee6d6", jsonPointer: "/story", fragmentSHA256: "67a24816aa15bfcc1ab003ea7175ac5ae4f5420259df9708f3cd16bffddc23a5")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.open-measure/archive/tolerance-reference-custodian", replicaID: "proposed-replica-tolerance-reference-custodian",
          originIdentity: "proposed-tolerance-reference-custodian", originDomain: "tolerance-reference-custodian",
          payloadSHA256: "52a172d65040161e2252d14246c8f169e6ef1a6988f355987895892afbfe390b",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-measure.json", fileSHA256: "9c712197b46f25e90514b3b6c0913dcbdf9d062123ffc99547085577845ee6d6", jsonPointer: "/stages/1/objective", fragmentSHA256: "4b3b255d8f1ce7f6f7db6c64141128b4ed452f2d599390fe83b6aeceafbb6cd0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.open-measure/archive/open-gauge-curator", replicaID: "proposed-replica-open-gauge-curator",
          originIdentity: "proposed-open-gauge-curator", originDomain: "open-gauge-curator",
          payloadSHA256: "90a7927c81f7cb6a8bdb65f3561e6f86cb1f2f77e63fc82e3e5c560eb9e6681d",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-measure.json", fileSHA256: "9c712197b46f25e90514b3b6c0913dcbdf9d062123ffc99547085577845ee6d6", jsonPointer: "/completionClue/receipt", fragmentSHA256: "35a89e2d5f485481809908f29f70dfdd76abcf645e2913ee2d5db06fff3da2b4")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.open-shadow", clueID: "open-shadow-trace",
        receiptID: "l337.unwritten-route/clue/open-shadow-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-shadow.json", sha256: "96379e8bb6578901715a852078536da14bbe4a175d2165cdc7d91197eb4411d2", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.open-shadow"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.open-shadow/archive/collision-channel-editor", replicaID: "proposed-replica-collision-channel-editor",
          originIdentity: "proposed-collision-channel-editor", originDomain: "collision-channel-editor",
          payloadSHA256: "ee09eb3e08c1512257a71439ab7254033acbb8e7a58e1de961b4e386a4852722",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-shadow.json", fileSHA256: "96379e8bb6578901715a852078536da14bbe4a175d2165cdc7d91197eb4411d2", jsonPointer: "/story", fragmentSHA256: "2b27e146554d55c7512148ba1e6b4a05c31baf0a9a4b8c70f287593993c1418e")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.open-shadow/archive/private-identity-boundary-custodian", replicaID: "proposed-replica-private-identity-boundary-custodian",
          originIdentity: "proposed-private-identity-boundary-custodian", originDomain: "private-identity-boundary-custodian",
          payloadSHA256: "305c034f550b0044941880df8fd4f2686af650b32f5890fdaf3db8cd796042ce",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-shadow.json", fileSHA256: "96379e8bb6578901715a852078536da14bbe4a175d2165cdc7d91197eb4411d2", jsonPointer: "/stages/1/objective", fragmentSHA256: "ffb228c6777b46ae3777fdbd5e23ac2edf878b0e0def839e602b444ee6c93068")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.open-shadow/archive/shadow-reference-curator", replicaID: "proposed-replica-shadow-reference-curator",
          originIdentity: "proposed-shadow-reference-curator", originDomain: "shadow-reference-curator",
          payloadSHA256: "00f374191fea6e7c4244cc75010e86d41d00e292db34f0a68ce34500fcf46644",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/open-shadow.json", fileSHA256: "96379e8bb6578901715a852078536da14bbe4a175d2165cdc7d91197eb4411d2", jsonPointer: "/completionClue/receipt", fragmentSHA256: "db66ae271c300d11417f05f21a0f499d5b5e4a4778983935034d83724f99b51d")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.passengers-horizon", clueID: "passengers-horizon-trace",
        receiptID: "l337.unwritten-route/clue/passengers-horizon-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/passengers-horizon.json", sha256: "1b86aea8e6b5600a0b748040ac1ad970406391cc26eebbdb0af92d67e95e2804", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.passengers-horizon"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.passengers-horizon/archive/boarding-clearance-editor", replicaID: "proposed-replica-boarding-clearance-editor",
          originIdentity: "proposed-boarding-clearance-editor", originDomain: "boarding-clearance-editor",
          payloadSHA256: "9b6719ce6b617e83f03d0d3f9c2440b55ce89aa3197f067d65380a66de1eea20",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/passengers-horizon.json", fileSHA256: "1b86aea8e6b5600a0b748040ac1ad970406391cc26eebbdb0af92d67e95e2804", jsonPointer: "/story", fragmentSHA256: "2b04b803bad80e3757b35ef13ca72c9c5b3f6f0b29ad3c8765689ead80c5b820")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.passengers-horizon/archive/accessible-route-custodian", replicaID: "proposed-replica-accessible-route-custodian",
          originIdentity: "proposed-accessible-route-custodian", originDomain: "accessible-route-custodian",
          payloadSHA256: "6d766c6e5a7ef01a0fc0afea1c61703b214e03c9312dd1123e4f1560d5d4b001",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/passengers-horizon.json", fileSHA256: "1b86aea8e6b5600a0b748040ac1ad970406391cc26eebbdb0af92d67e95e2804", jsonPointer: "/stages/1/objective", fragmentSHA256: "196d768072fd259c96972151ab65844176c413bf3e197674a64034b2092e517f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.passengers-horizon/archive/horizon-reference-curator", replicaID: "proposed-replica-horizon-reference-curator",
          originIdentity: "proposed-horizon-reference-curator", originDomain: "horizon-reference-curator",
          payloadSHA256: "39395f4549d69571a6fcbe9efc9f2c7a86773023c4f9d03f3c87a8639a3035ba",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/passengers-horizon.json", fileSHA256: "1b86aea8e6b5600a0b748040ac1ad970406391cc26eebbdb0af92d67e95e2804", jsonPointer: "/completionClue/receipt", fragmentSHA256: "6f8f85a597eba0681e0d18611442e5e956dad407d11984baf27441244ff900be")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.public-record", clueID: "public-record-trace",
        receiptID: "l337.unwritten-route/clue/public-record-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/public-record.json", sha256: "0ebf720710dc5d7954158e2c25d6d0a346bc0883481d0d39fe4634f5f68e4bb5", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.public-record"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.public-record/archive/protected-record-editor", replicaID: "proposed-replica-protected-record-editor",
          originIdentity: "proposed-protected-record-editor", originDomain: "protected-record-editor",
          payloadSHA256: "b4c8ce975bba0da5e198af798b94d85b7708a3e4fa3ab1fafb27e130367e7036",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/public-record.json", fileSHA256: "0ebf720710dc5d7954158e2c25d6d0a346bc0883481d0d39fe4634f5f68e4bb5", jsonPointer: "/story", fragmentSHA256: "da0e072b4e1c65782b5c7df3677f61868b3c6c3740062dc088ee4cf652d244a4")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.public-record/archive/reply-attribution-custodian", replicaID: "proposed-replica-reply-attribution-custodian",
          originIdentity: "proposed-reply-attribution-custodian", originDomain: "reply-attribution-custodian",
          payloadSHA256: "b1ba7c042319bc0e08e3b40c7ce817b70a4b11c30db6503dd97bce782fece9f1",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/public-record.json", fileSHA256: "0ebf720710dc5d7954158e2c25d6d0a346bc0883481d0d39fe4634f5f68e4bb5", jsonPointer: "/stages/1/objective", fragmentSHA256: "22625371f9c2372ccf00c34b5c1a6929fef7afdba3d552c6943584f787cc19ee")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.public-record/archive/public-record-reference-curator", replicaID: "proposed-replica-public-record-reference-curator",
          originIdentity: "proposed-public-record-reference-curator", originDomain: "public-record-reference-curator",
          payloadSHA256: "99a7e523746c9dea7cc8c4290227367d832c2add92b34263caa6042952cd1b18",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/public-record.json", fileSHA256: "0ebf720710dc5d7954158e2c25d6d0a346bc0883481d0d39fe4634f5f68e4bb5", jsonPointer: "/completionClue/receipt", fragmentSHA256: "2c963d9b42ff396f8c3ee2100f46b9528d652b2dc38f0c2a557eaf6a2dff4ab6")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.quiet-choir", clueID: "choir-silent-voice",
        receiptID: "l337.unwritten-route/clue/choir-silent-voice",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-choir.json", sha256: "41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.quiet-choir"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.quiet-choir/archive/spectral-source-editor", replicaID: "proposed-replica-spectral-source-editor",
          originIdentity: "proposed-spectral-source-editor", originDomain: "spectral-source-editor",
          payloadSHA256: "da2212f4530612ed7c32762dc5771ff2343dc0cda05e9b330e589349a74f4724",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-choir.json", fileSHA256: "41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60", jsonPointer: "/story", fragmentSHA256: "117f6c3f59965817cfef64090521be31f4e9e1a6589a292ee31b3736e309f6cc")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.quiet-choir/archive/choir-reception-custodian", replicaID: "proposed-replica-choir-reception-custodian",
          originIdentity: "proposed-choir-reception-custodian", originDomain: "choir-reception-custodian",
          payloadSHA256: "5fb5fffa8c4017df9586ca88b91b59a21a348c7b8b3dc8a29f226ceba1f2bb48",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-choir.json", fileSHA256: "41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60", jsonPointer: "/stages/1/objective", fragmentSHA256: "707066f55feb784fef5f041fd19a1b7ae19aabf18600805f5d32ac1fb6ea8372")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.quiet-choir/archive/quiet-signal-reference-curator", replicaID: "proposed-replica-quiet-signal-reference-curator",
          originIdentity: "proposed-quiet-signal-reference-curator", originDomain: "quiet-signal-reference-curator",
          payloadSHA256: "f0c9f5490718b80313dde4f7270dc21c260ec1be69f2f2a68882eb8da367a158",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-choir.json", fileSHA256: "41c9d24ae171e09f4b0bb43c5bbbdae602544d6b80bf86ec3e9da0c7ab2f0e60", jsonPointer: "/completionClue/receipt", fragmentSHA256: "671d32e052f5b17a8041cd540f36ad4b72592de5612654fc4871fc2e827e156f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.quiet-nursery", clueID: "quiet-nursery-trace",
        receiptID: "l337.unwritten-route/clue/quiet-nursery-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-nursery.json", sha256: "728e4ce3b41e76dadd7993953f205f8e1afeaa30414e1dca210b4712c8562c6b", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.quiet-nursery"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.quiet-nursery/archive/pressure-reference-editor", replicaID: "proposed-replica-pressure-reference-editor",
          originIdentity: "proposed-pressure-reference-editor", originDomain: "pressure-reference-editor",
          payloadSHA256: "6fc0d8ee7817dce4814c5653404f748dbdaa8c710ccdfb404eb4010bd0517725",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-nursery.json", fileSHA256: "728e4ce3b41e76dadd7993953f205f8e1afeaa30414e1dca210b4712c8562c6b", jsonPointer: "/story", fragmentSHA256: "13463d266ed58b5727a6764aca41b442df88c2aa6700cd0b6c5f45fd18ee2036")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.quiet-nursery/archive/waveform-comparison-custodian", replicaID: "proposed-replica-waveform-comparison-custodian",
          originIdentity: "proposed-waveform-comparison-custodian", originDomain: "waveform-comparison-custodian",
          payloadSHA256: "7c5040c9cf896f51c80d37df4c6670be65e5f261994ef774b22e97460697a535",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-nursery.json", fileSHA256: "728e4ce3b41e76dadd7993953f205f8e1afeaa30414e1dca210b4712c8562c6b", jsonPointer: "/stages/1/objective", fragmentSHA256: "93d3d1b44dbf1ef1af78c12cc82fac9834973352366801f9aae867fef490133c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.quiet-nursery/archive/nursery-reference-curator", replicaID: "proposed-replica-nursery-reference-curator",
          originIdentity: "proposed-nursery-reference-curator", originDomain: "nursery-reference-curator",
          payloadSHA256: "320b0919e13aed8c09a56bdf9347d66deb740f34077cdf8e2570302798f1644c",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/quiet-nursery.json", fileSHA256: "728e4ce3b41e76dadd7993953f205f8e1afeaa30414e1dca210b4712c8562c6b", jsonPointer: "/completionClue/receipt", fragmentSHA256: "0c43fa46e3214e7cadacf78ce7368b2294139639f79dbd23495925558c948451")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.rubble-covenant", clueID: "rubble-covenant-trace",
        receiptID: "l337.unwritten-route/clue/rubble-covenant-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/rubble-covenant.json", sha256: "969316d8421735c4589e75a69a8bc5e3c3a0eaa0f44ce28c2ce249a88cf0f559", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.rubble-covenant"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.rubble-covenant/archive/rubble-mass-editor", replicaID: "proposed-replica-rubble-mass-editor",
          originIdentity: "proposed-rubble-mass-editor", originDomain: "rubble-mass-editor",
          payloadSHA256: "4aa46167f5e1a77337c52a945a3e2266036022218c85a9b94dab50ea8fa49441",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/rubble-covenant.json", fileSHA256: "969316d8421735c4589e75a69a8bc5e3c3a0eaa0f44ce28c2ce249a88cf0f559", jsonPointer: "/story", fragmentSHA256: "7c61b5dc97ebd9522335011e15bffeea6ebb31571560151185599718196b9370")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.rubble-covenant/archive/drift-clearance-custodian", replicaID: "proposed-replica-drift-clearance-custodian",
          originIdentity: "proposed-drift-clearance-custodian", originDomain: "drift-clearance-custodian",
          payloadSHA256: "d016e30a3fa5b5d9edaee297d3ca9ddc9588a776e3d0330c25c26238b28e85b0",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/rubble-covenant.json", fileSHA256: "969316d8421735c4589e75a69a8bc5e3c3a0eaa0f44ce28c2ce249a88cf0f559", jsonPointer: "/stages/1/objective", fragmentSHA256: "26127857a3329cf5a7127cf0ce6c478b41f4eedfdef515f1101fb5ec6cc6785f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.rubble-covenant/archive/rubble-reference-curator", replicaID: "proposed-replica-rubble-reference-curator",
          originIdentity: "proposed-rubble-reference-curator", originDomain: "rubble-reference-curator",
          payloadSHA256: "5775b7dcba8f26e80045c232b17e7b8d70f482c8f31b26ea15f2ad28a403cd78",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/rubble-covenant.json", fileSHA256: "969316d8421735c4589e75a69a8bc5e3c3a0eaa0f44ce28c2ce249a88cf0f559", jsonPointer: "/completionClue/receipt", fragmentSHA256: "d1be1857f4fef8df7cf085b229451ab4304e2c139ed12c5ce2e2112680fe4019")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.shared-pulse", clueID: "shared-pulse-trace",
        receiptID: "l337.unwritten-route/clue/shared-pulse-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shared-pulse.json", sha256: "305f9ae59bd503a625704d9505e7114ccdb8d1094da10f2cc7edb2f4f9c168e7", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.shared-pulse"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.shared-pulse/archive/acknowledgement-source-editor", replicaID: "proposed-replica-acknowledgement-source-editor",
          originIdentity: "proposed-acknowledgement-source-editor", originDomain: "acknowledgement-source-editor",
          payloadSHA256: "032e85ab2f21d8e6de247e1e09450a9cb58cacb98ef89336e9149f6b215825ae",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shared-pulse.json", fileSHA256: "305f9ae59bd503a625704d9505e7114ccdb8d1094da10f2cc7edb2f4f9c168e7", jsonPointer: "/story", fragmentSHA256: "1d9f599ccbbef0cc7dcaaaa2e835c9f3a762e2f174ed51065847502eb2d6e7ff")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.shared-pulse/archive/feedback-cutoff-custodian", replicaID: "proposed-replica-feedback-cutoff-custodian",
          originIdentity: "proposed-feedback-cutoff-custodian", originDomain: "feedback-cutoff-custodian",
          payloadSHA256: "5d55035c2144072eb4ca69c4473bf17055e314462d21c463773df1ab08514e21",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shared-pulse.json", fileSHA256: "305f9ae59bd503a625704d9505e7114ccdb8d1094da10f2cc7edb2f4f9c168e7", jsonPointer: "/stages/1/objective", fragmentSHA256: "ffb228c6777b46ae3777fdbd5e23ac2edf878b0e0def839e602b444ee6c93068")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.shared-pulse/archive/shared-pulse-reference-curator", replicaID: "proposed-replica-shared-pulse-reference-curator",
          originIdentity: "proposed-shared-pulse-reference-curator", originDomain: "shared-pulse-reference-curator",
          payloadSHA256: "90ce324dda924fe4318d4b11bf5a5a93ad8c65c220fdd058d3b4f6480d06debf",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shared-pulse.json", fileSHA256: "305f9ae59bd503a625704d9505e7114ccdb8d1094da10f2cc7edb2f4f9c168e7", jsonPointer: "/completionClue/receipt", fragmentSHA256: "064415e41a1db7b7336dabe1ca4009200da3052c89e3b3b57be27d466a040529")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.shattered-wake", clueID: "wake-before-impact",
        receiptID: "l337.unwritten-route/clue/wake-before-impact",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shattered-wake.json", sha256: "50a55d876d1edf40eab3f517ff97d30eaeb4d837f3d766d4312378f9ccf72c2b", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.shattered-wake"),
        archive: .init(path: "charter-archive-models-d.json", sha256: "cd38e1fc05df0677f96d106796ed07f03d7ba5f94f6e93ee15be68a0d2792baf"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.shattered-wake/archive/impact-account-editor", replicaID: "proposed-replica-impact-account-editor",
          originIdentity: "proposed-impact-account-editor", originDomain: "impact-account-editor",
          payloadSHA256: "ab374bdfb219661074bf92e8b3cc368fe41e9e13abe3ef436082d42e7610c406",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shattered-wake.json", fileSHA256: "50a55d876d1edf40eab3f517ff97d30eaeb4d837f3d766d4312378f9ccf72c2b", jsonPointer: "/story", fragmentSHA256: "40a4a36485e78da8e37cad7483aeb174fc68f9336c2c4e051acef86e2be1528c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.shattered-wake/archive/wake-recovery-custodian", replicaID: "proposed-replica-wake-recovery-custodian",
          originIdentity: "proposed-wake-recovery-custodian", originDomain: "wake-recovery-custodian",
          payloadSHA256: "e25eb6a2b9c42a345bbfc9a3b5566cfd01be11a616583fe2539f417f5083b4c7",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shattered-wake.json", fileSHA256: "50a55d876d1edf40eab3f517ff97d30eaeb4d837f3d766d4312378f9ccf72c2b", jsonPointer: "/stages/1/objective", fragmentSHA256: "c0f0503114d0c7c26d2d522bb1efee6609c1abb83fabb01ca019db4fa5a08cc6")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.shattered-wake/archive/impact-trace-curator", replicaID: "proposed-replica-impact-trace-curator",
          originIdentity: "proposed-impact-trace-curator", originDomain: "impact-trace-curator",
          payloadSHA256: "6b4fc662d8ecaf8e7b595e0cf4ab52cee7b756d73c2fe308130c6dd795876d01",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/shattered-wake.json", fileSHA256: "50a55d876d1edf40eab3f517ff97d30eaeb4d837f3d766d4312378f9ccf72c2b", jsonPointer: "/completionClue/receipt", fragmentSHA256: "23e66c4414c3cb5a375f10a21904808812dcaf9c0c69aa158e98eb92d0ef21ca")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236625, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.small-lights", clueID: "small-lights-trace",
        receiptID: "l337.unwritten-route/clue/small-lights-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/small-lights.json", sha256: "2b8efb2ef80c459fa1bdbe852709fd69eeff45cfedc4773cc5b120f747fcd641", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.small-lights"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.small-lights/archive/dependency-fault-editor", replicaID: "proposed-replica-dependency-fault-editor",
          originIdentity: "proposed-dependency-fault-editor", originDomain: "dependency-fault-editor",
          payloadSHA256: "d363c707993fc5c31ea5e57047465a06d6d9ad68bf6fde7adf7ec928dd8a7257",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/small-lights.json", fileSHA256: "2b8efb2ef80c459fa1bdbe852709fd69eeff45cfedc4773cc5b120f747fcd641", jsonPointer: "/story", fragmentSHA256: "a5a093c551737d43c48f0d06c8538542a8ffe12e4956f70dd75af0e6fba1f623")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.small-lights/archive/isolation-response-custodian", replicaID: "proposed-replica-isolation-response-custodian",
          originIdentity: "proposed-isolation-response-custodian", originDomain: "isolation-response-custodian",
          payloadSHA256: "9ef9236d145dac11a717786f792a555ab393fcb514aca3d7accdb9d03b72504e",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/small-lights.json", fileSHA256: "2b8efb2ef80c459fa1bdbe852709fd69eeff45cfedc4773cc5b120f747fcd641", jsonPointer: "/stages/1/objective", fragmentSHA256: "306783183370bf66ff0b6dcaf089436448e15e692754be1604c2312f796e11b2")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.small-lights/archive/small-lights-reference-curator", replicaID: "proposed-replica-small-lights-reference-curator",
          originIdentity: "proposed-small-lights-reference-curator", originDomain: "small-lights-reference-curator",
          payloadSHA256: "2edea70995e65ac83d71d16998f2b237ba0be45175de76b4af8a34dd4b951893",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/small-lights.json", fileSHA256: "2b8efb2ef80c459fa1bdbe852709fd69eeff45cfedc4773cc5b120f747fcd641", jsonPointer: "/completionClue/receipt", fragmentSHA256: "a823232fb897dd68ddd603727c466b2f1080015bec0f5cdc3fc3715e911752b5")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.still-current", clueID: "current-resting-arc",
        receiptID: "l337.unwritten-route/clue/current-resting-arc",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/still-current.json", sha256: "a4cd54915cd51048002f88c862f99665bcc11f65785ec8fb3dc62a7109e67f47", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.still-current"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.still-current/archive/energy-source-editor", replicaID: "proposed-replica-energy-source-editor",
          originIdentity: "proposed-energy-source-editor", originDomain: "energy-source-editor",
          payloadSHA256: "f918c51fce3b09abc6155b16c372938e00865860e78f1a0c9b74dcbd8713d9b7",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/still-current.json", fileSHA256: "a4cd54915cd51048002f88c862f99665bcc11f65785ec8fb3dc62a7109e67f47", jsonPointer: "/story", fragmentSHA256: "575ce571122d3b5d9dfb6dad8cc4bfe13221d244ca5d0f036e4e4fafaadb99c4")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.still-current/archive/current-reception-custodian", replicaID: "proposed-replica-current-reception-custodian",
          originIdentity: "proposed-current-reception-custodian", originDomain: "current-reception-custodian",
          payloadSHA256: "ff0acb70dc4f2c66e84c3504ef35219132370a8042618d3a34be507c75970a54",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/still-current.json", fileSHA256: "a4cd54915cd51048002f88c862f99665bcc11f65785ec8fb3dc62a7109e67f47", jsonPointer: "/stages/1/objective", fragmentSHA256: "bfe0ad18d75395b43434a265a2e4f9ad77de17fcb33880270869a5ec65bc9986")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.still-current/archive/energy-trace-curator", replicaID: "proposed-replica-energy-trace-curator",
          originIdentity: "proposed-energy-trace-curator", originDomain: "energy-trace-curator",
          payloadSHA256: "3138ef70066c94a86327931b904681d3654c313e148218b94ddb6c1d9f97a76b",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/still-current.json", fileSHA256: "a4cd54915cd51048002f88c862f99665bcc11f65785ec8fb3dc62a7109e67f47", jsonPointer: "/completionClue/receipt", fragmentSHA256: "128b8218d4f6fda22d1d8d6c5b68241dc26541292f1c2d452051c56e4f940ddc")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.tithe-of-worlds", clueID: "tithe-unclaimed-reserve",
        receiptID: "l337.unwritten-route/clue/tithe-unclaimed-reserve",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/tithe-of-worlds.json", sha256: "1fe19892fe4cff0da61da5d547dfb6eebb8842b15680607b8adf69dfa238a67a", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.tithe-of-worlds"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.tithe-of-worlds/archive/reserve-claim-editor", replicaID: "proposed-replica-reserve-claim-editor",
          originIdentity: "proposed-reserve-claim-editor", originDomain: "reserve-claim-editor",
          payloadSHA256: "e3f1195178b189b6412c8e7247de79c9433c2b3b78240a939c64f5107b95b49c",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/tithe-of-worlds.json", fileSHA256: "1fe19892fe4cff0da61da5d547dfb6eebb8842b15680607b8adf69dfa238a67a", jsonPointer: "/story", fragmentSHA256: "92d03e0ed10f0c61e593a77d5aaec81d21dd307b2f4f08019835344b072227c0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.tithe-of-worlds/archive/world-allocation-custodian", replicaID: "proposed-replica-world-allocation-custodian",
          originIdentity: "proposed-world-allocation-custodian", originDomain: "world-allocation-custodian",
          payloadSHA256: "cd58839956c06c3d0d40ef63c87f05709940e55e72ee6f23eb1f156d8a05151c",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/tithe-of-worlds.json", fileSHA256: "1fe19892fe4cff0da61da5d547dfb6eebb8842b15680607b8adf69dfa238a67a", jsonPointer: "/stages/1/objective", fragmentSHA256: "c8c59ac65e6f51b39228970f55567ddb79d8ae2b6434391ae8e33fa7e116f4ea")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.tithe-of-worlds/archive/tithe-reference-curator", replicaID: "proposed-replica-tithe-reference-curator",
          originIdentity: "proposed-tithe-reference-curator", originDomain: "tithe-reference-curator",
          payloadSHA256: "c92a31cda94f6c54b7f2b60fec651f5bda7c5d5844edd3860415a869da919996",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/tithe-of-worlds.json", fileSHA256: "1fe19892fe4cff0da61da5d547dfb6eebb8842b15680607b8adf69dfa238a67a", jsonPointer: "/completionClue/receipt", fragmentSHA256: "1cf1cbf27c4dca039013576024513256f5ab1ec2e3b8faf53d7f852cdd1262ac")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.training/defensive-flight", clueID: "defensive-flight-family-trace",
        receiptID: "l337.unwritten-route/clue/defensive-flight-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/17/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.training~1defensive-flight"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.training/defensive-flight/archive/break-off-envelope-editor", replicaID: "proposed-replica-break-off-envelope-editor",
          originIdentity: "proposed-break-off-envelope-editor", originDomain: "break-off-envelope-editor",
          payloadSHA256: "be01b483e07998e5c166e0c05d65515e31e6ac43484455d73420da86fc67d0f6",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/17/offerDialog", fragmentSHA256: "dca26efd95908dbb52250d2a6e1d123491e24cd781e1ea90846985c6c8968c7d")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.training/defensive-flight/archive/evasion-evidence-custodian", replicaID: "proposed-replica-evasion-evidence-custodian",
          originIdentity: "proposed-evasion-evidence-custodian", originDomain: "evasion-evidence-custodian",
          payloadSHA256: "dad184090ba45e935168c4191e3d4895d8403bec4612d16e47ceb3d324b36aa4",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/17/stages/1/objective", fragmentSHA256: "e7412e7dbabc4ee7810b50d95ceeccc0298ed8f5ffacfdb90b6cd8dd293cc254")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.training/defensive-flight/archive/defensive-flight-reference-curator", replicaID: "proposed-replica-defensive-flight-reference-curator",
          originIdentity: "proposed-defensive-flight-reference-curator", originDomain: "defensive-flight-reference-curator",
          payloadSHA256: "43ce36ff46cae59b94524892cf772b43cb74c603f85a9081ffd1157e231f6da6",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/17/completionClue/receipt", fragmentSHA256: "5e286fd567a1bde74d0e86bf73746e1114ead028ff94f5a23ce25bf00f1678f1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.training/flight-reception", clueID: "flight-reception-family-trace",
        receiptID: "l337.unwritten-route/clue/flight-reception-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/15/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.training~1flight-reception"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.training/flight-reception/archive/practice-offer-editor", replicaID: "proposed-replica-practice-offer-editor",
          originIdentity: "proposed-practice-offer-editor", originDomain: "practice-offer-editor",
          payloadSHA256: "83aa9840e185104b98decf79050afedbcb49ff3675ea11e35d00359cc4b353ec",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/15/offerDialog", fragmentSHA256: "17a7328aba75a9f1ceb7abe002dce61d1678e0282415bab20ed0047ef8c91f70")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.training/flight-reception/archive/practice-reception-custodian", replicaID: "proposed-replica-practice-reception-custodian",
          originIdentity: "proposed-practice-reception-custodian", originDomain: "practice-reception-custodian",
          payloadSHA256: "22c4a891d952bdb133e9a8860f26dc49fff5385721d4bea4874a0ff7916e6fb3",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/15/stages/1/objective", fragmentSHA256: "6df1dbcfa443dc54aee5d7a4b84b4313c94e4750e497e7caa74d216118366ec0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.training/flight-reception/archive/flight-practice-reference-curator", replicaID: "proposed-replica-flight-practice-reference-curator",
          originIdentity: "proposed-flight-practice-reference-curator", originDomain: "flight-practice-reference-curator",
          payloadSHA256: "af2482df559e6f9ce12cd6e354d9204e49c1ad507224663737af6bc88939c007",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/15/completionClue/receipt", fragmentSHA256: "11d0e17e811bfa331b681ba9c4c80aec1b4483dd4a34f786d683bd5d2684a1ab")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.training/navigation-trade", clueID: "navigation-trade-family-trace",
        receiptID: "l337.unwritten-route/clue/navigation-trade-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/18/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.training~1navigation-trade"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.training/navigation-trade/archive/route-quote-editor", replicaID: "proposed-replica-route-quote-editor",
          originIdentity: "proposed-route-quote-editor", originDomain: "route-quote-editor",
          payloadSHA256: "f4cad944e54d6ac16bd85f6b27818b73eef3910309b21dbf365befe2d632f381",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/18/offerDialog", fragmentSHA256: "cb3b188f8938a222ffb0fece7a5307689b3ad2e62002635a777227423a273da7")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.training/navigation-trade/archive/trade-settlement-custodian", replicaID: "proposed-replica-trade-settlement-custodian",
          originIdentity: "proposed-trade-settlement-custodian", originDomain: "trade-settlement-custodian",
          payloadSHA256: "2c89a50db017397e5fd5a884357d01cfd8dd64317a2f203179db63a55f6a783a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/18/stages/1/objective", fragmentSHA256: "ce7ef04652264f289924a4cd6f0a564cfb4a86300504fe36f3ebe03fd086eb3f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.training/navigation-trade/archive/navigation-reference-curator", replicaID: "proposed-replica-navigation-reference-curator",
          originIdentity: "proposed-navigation-reference-curator", originDomain: "navigation-reference-curator",
          payloadSHA256: "b1b7db042b8761f79c22ad85e377b1a7d73259263acd33d902ba1a929af47a39",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/18/completionClue/receipt", fragmentSHA256: "eedf0aa2fead777740eee775a558744b6af842649faa7fdf2424bcbf93d44982")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.training/safe-gunnery", clueID: "safe-gunnery-family-trace",
        receiptID: "l337.unwritten-route/clue/safe-gunnery-family-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", sha256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/16/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.training~1safe-gunnery"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.training/safe-gunnery/archive/training-target-editor", replicaID: "proposed-replica-training-target-editor",
          originIdentity: "proposed-training-target-editor", originDomain: "training-target-editor",
          payloadSHA256: "6bb9f9dfe281b97d8df60e045cddf2725067f4fe3cb0a0eda33ae1c9459b0221",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/16/offerDialog", fragmentSHA256: "c9a9eb0f45f2ee0d36dd3e7372db9236c113ffdac29ee0da0eec3a82ab1d9377")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.training/safe-gunnery/archive/safe-shot-attribution-custodian", replicaID: "proposed-replica-safe-shot-attribution-custodian",
          originIdentity: "proposed-safe-shot-attribution-custodian", originDomain: "safe-shot-attribution-custodian",
          payloadSHA256: "0be2b31022d217299b4ae1062d1aa38a8664aea6397b8ea5893653a904fb8dbe",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/16/stages/1/objective", fragmentSHA256: "5a3ae8a94b24a7bddb57dd4650441b3dcd513c02859a2a2ca8aff5f3e6664cde")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.training/safe-gunnery/archive/gunnery-reference-curator", replicaID: "proposed-replica-gunnery-reference-curator",
          originIdentity: "proposed-gunnery-reference-curator", originDomain: "gunnery-reference-curator",
          payloadSHA256: "16be50c05bba552413fd275ee4e463ed189af1133a3ad6c5328bdf7e49d01ee8",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/original-families.json", fileSHA256: "abf67f6506e9f392014913b3c9e9d08672283e9a8f830a7e4621f178fe8a40f5", jsonPointer: "/templates/16/completionClue/receipt", fragmentSHA256: "620da55d0dd587c9e270c1e73aa26ae3bb637ce4dfa400a0ef357fb3c4a349aa")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.uncounted-names", clueID: "uncounted-names-trace",
        receiptID: "l337.unwritten-route/clue/uncounted-names-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/uncounted-names.json", sha256: "318d89b6837750dcb5abc0b149e6fbc80e751e7b63a85b4a285776671ee54bd5", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.uncounted-names"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.uncounted-names/archive/person-standing-editor", replicaID: "proposed-replica-person-standing-editor",
          originIdentity: "proposed-person-standing-editor", originDomain: "person-standing-editor",
          payloadSHA256: "18b4273012b25c937ed0f6630e4e280049996af53b59bb12e6b483f5466f16d8",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/uncounted-names.json", fileSHA256: "318d89b6837750dcb5abc0b149e6fbc80e751e7b63a85b4a285776671ee54bd5", jsonPointer: "/story", fragmentSHA256: "bc76c31eea9cd5b7da1830e5bfcc9a7ffc9f45f0e4c8ebb2cb7808e9afb05c0b")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.uncounted-names/archive/receiving-permission-custodian", replicaID: "proposed-replica-receiving-permission-custodian",
          originIdentity: "proposed-receiving-permission-custodian", originDomain: "receiving-permission-custodian",
          payloadSHA256: "f8283801367df9bc74f87e92cffd3f9fcd36f8e81284e32dd4eb1538f9b18250",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/uncounted-names.json", fileSHA256: "318d89b6837750dcb5abc0b149e6fbc80e751e7b63a85b4a285776671ee54bd5", jsonPointer: "/stages/1/objective", fragmentSHA256: "295a3f0c2c3879eb389a3a31ff8eb5c37ff27e243b2faa19105af2119b24eca0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.uncounted-names/archive/names-reference-curator", replicaID: "proposed-replica-names-reference-curator",
          originIdentity: "proposed-names-reference-curator", originDomain: "names-reference-curator",
          payloadSHA256: "05ea7edf90c4843cf2da0b101db1dd2ffb1da6223ee6ca691db80793f5d32707",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/uncounted-names.json", fileSHA256: "318d89b6837750dcb5abc0b149e6fbc80e751e7b63a85b4a285776671ee54bd5", jsonPointer: "/completionClue/receipt", fragmentSHA256: "902287a56e623dc1d8b3dcd870bc624d348f929479f6765a56e5e2c0e4a6fe65")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.under-tow", clueID: "under-tow-trace",
        receiptID: "l337.unwritten-route/clue/under-tow-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/under-tow.json", sha256: "b5dac526f44b1599b66400a47e4bbf0a5e38f4b0c9cd9fa8431992bab75a9cb2", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.under-tow"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.under-tow/archive/coupler-geometry-editor", replicaID: "proposed-replica-coupler-geometry-editor",
          originIdentity: "proposed-coupler-geometry-editor", originDomain: "coupler-geometry-editor",
          payloadSHA256: "94ddba7f73fcb23ec808d4ada9e6c152f7b4b3d9bbb5fae31305aa1739dd676f",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/under-tow.json", fileSHA256: "b5dac526f44b1599b66400a47e4bbf0a5e38f4b0c9cd9fa8431992bab75a9cb2", jsonPointer: "/story", fragmentSHA256: "0be16e4d62fdeeee4a8151ef20ad714fbcb0755cbf06fe090d91707640a79a57")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.under-tow/archive/tow-load-custodian", replicaID: "proposed-replica-tow-load-custodian",
          originIdentity: "proposed-tow-load-custodian", originDomain: "tow-load-custodian",
          payloadSHA256: "ced4a0336e6eac90b46ce3d8b7a6e5c534a60ae28d2f0fa31d5d3f38b95939c7",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/under-tow.json", fileSHA256: "b5dac526f44b1599b66400a47e4bbf0a5e38f4b0c9cd9fa8431992bab75a9cb2", jsonPointer: "/stages/1/objective", fragmentSHA256: "553b6a8963e74713d1e13c19fa5f8545c4c200279adad460c995522c873c7f51")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.under-tow/archive/tow-reference-curator", replicaID: "proposed-replica-tow-reference-curator",
          originIdentity: "proposed-tow-reference-curator", originDomain: "tow-reference-curator",
          payloadSHA256: "658048f5f00018a1c6564bf098ecfb73c18f647cde726a1b66f096ae477d58fb",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/under-tow.json", fileSHA256: "b5dac526f44b1599b66400a47e4bbf0a5e38f4b0c9cd9fa8431992bab75a9cb2", jsonPointer: "/completionClue/receipt", fragmentSHA256: "2a86f6178ef02f2de76ea2efcfdd8e5864d0e2af92334ba4dc04c516a8c567b8")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.unfinished-map", clueID: "unfinished-map-trace",
        receiptID: "l337.unwritten-route/clue/unfinished-map-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/unfinished-map.json", sha256: "453551f24efbc6a3ad54bd7904cb7e6007d317f73481e4364aff93ed0b934862", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.unfinished-map"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.unfinished-map/archive/uncertainty-envelope-editor", replicaID: "proposed-replica-uncertainty-envelope-editor",
          originIdentity: "proposed-uncertainty-envelope-editor", originDomain: "uncertainty-envelope-editor",
          payloadSHA256: "a5dbcde492237a9dfa3cf3191317d16c387714281c7117b0a4b7b32dbf077545",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/unfinished-map.json", fileSHA256: "453551f24efbc6a3ad54bd7904cb7e6007d317f73481e4364aff93ed0b934862", jsonPointer: "/story", fragmentSHA256: "e07ce8012238519bd1f3f080b3334a365e38b17390d3dcc965a6b197b1e4341c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.unfinished-map/archive/survey-provenance-custodian", replicaID: "proposed-replica-survey-provenance-custodian",
          originIdentity: "proposed-survey-provenance-custodian", originDomain: "survey-provenance-custodian",
          payloadSHA256: "0d3fd44d65d5703780d59cb3b74a0d6830dff48f5152a840108646785896df35",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/unfinished-map.json", fileSHA256: "453551f24efbc6a3ad54bd7904cb7e6007d317f73481e4364aff93ed0b934862", jsonPointer: "/stages/1/objective", fragmentSHA256: "ffb228c6777b46ae3777fdbd5e23ac2edf878b0e0def839e602b444ee6c93068")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.unfinished-map/archive/unfinished-chart-reference-curator", replicaID: "proposed-replica-unfinished-chart-reference-curator",
          originIdentity: "proposed-unfinished-chart-reference-curator", originDomain: "unfinished-chart-reference-curator",
          payloadSHA256: "3ab79afeda96cd53502e8bfed7337b074b1ef2b1c241611bf9cf0d616eeb7ad2",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/unfinished-map.json", fileSHA256: "453551f24efbc6a3ad54bd7904cb7e6007d317f73481e4364aff93ed0b934862", jsonPointer: "/completionClue/receipt", fragmentSHA256: "ec44431b6190d896248874532b38a96b7aa81dddc9bc05fba1572ce8d62c546a")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.warrant-ledger", clueID: "warrant-ledger-trace",
        receiptID: "l337.unwritten-route/clue/warrant-ledger-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/warrant-ledger.json", sha256: "16b225e3565f7eefb6f0297bfaf2c68831ccda7d05a48de40e501c991b360dcc", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.warrant-ledger"),
        archive: .init(path: "charter-archive-models-e.json", sha256: "ba99e9598b1174051a58714e824f4490f111bc1cbf5d7b1375829445fb011a39"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.warrant-ledger/archive/conflicting-claim-editor", replicaID: "proposed-replica-conflicting-claim-editor",
          originIdentity: "proposed-conflicting-claim-editor", originDomain: "conflicting-claim-editor",
          payloadSHA256: "2dbb462d8118398d46f7e6a7a14551c1004ac4f2688c9ebefab931e4d6c6fd91",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/warrant-ledger.json", fileSHA256: "16b225e3565f7eefb6f0297bfaf2c68831ccda7d05a48de40e501c991b360dcc", jsonPointer: "/story", fragmentSHA256: "bcf7c68310bcb6455760d08b31489799d80b58ad4b98cf3ea33818f72efc29fc")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.warrant-ledger/archive/adjudication-evidence-custodian", replicaID: "proposed-replica-adjudication-evidence-custodian",
          originIdentity: "proposed-adjudication-evidence-custodian", originDomain: "adjudication-evidence-custodian",
          payloadSHA256: "2bafca36deb5770f6cd94825d0e5b26befbfdf81a68b6aeb166e87dc7806e266",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/warrant-ledger.json", fileSHA256: "16b225e3565f7eefb6f0297bfaf2c68831ccda7d05a48de40e501c991b360dcc", jsonPointer: "/stages/1/objective", fragmentSHA256: "854e99fac096e2a26144fe76e7f4b4b8322cbe28be4492632d3574708e9ffb30")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.warrant-ledger/archive/dispute-reference-curator", replicaID: "proposed-replica-dispute-reference-curator",
          originIdentity: "proposed-dispute-reference-curator", originDomain: "dispute-reference-curator",
          payloadSHA256: "7a185bfb89c3ba6cb1eaf24e5b5307590f50c338b442a678b037c4540c7922d1",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/warrant-ledger.json", fileSHA256: "16b225e3565f7eefb6f0297bfaf2c68831ccda7d05a48de40e501c991b360dcc", jsonPointer: "/completionClue/receipt", fragmentSHA256: "ac85d71807ae379fc00bdb63473a37942f84f208ae2d558c65ec327ac425b36c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 236610, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.wayfarer-exchange", clueID: "exchange-unbooked-window",
        receiptID: "l337.unwritten-route/clue/exchange-unbooked-window",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-exchange.json", sha256: "9be9729169d2f52ab0b10755b048a473d7fba470e02d707fcdcadcfaf737bd97", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.wayfarer-exchange"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.wayfarer-exchange/archive/exchange-offer-editor", replicaID: "proposed-replica-exchange-offer-editor",
          originIdentity: "proposed-exchange-offer-editor", originDomain: "exchange-offer-editor",
          payloadSHA256: "0b2b6f6fd3c24fd048542544bd2144db60ca43c83606b72f5ab8d5e44f90f49b",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-exchange.json", fileSHA256: "9be9729169d2f52ab0b10755b048a473d7fba470e02d707fcdcadcfaf737bd97", jsonPointer: "/story", fragmentSHA256: "70e8f1044bb3b37cc491d6f48cc8df7b3336407963db1798710caa453dac72bd")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.wayfarer-exchange/archive/service-instance-reception-custodian", replicaID: "proposed-replica-service-instance-reception-custodian",
          originIdentity: "proposed-service-instance-reception-custodian", originDomain: "service-instance-reception-custodian",
          payloadSHA256: "dd7d075176fc7c6a257199731ac8c3627a116f9b935c3ad9319a418746cc4267",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-exchange.json", fileSHA256: "9be9729169d2f52ab0b10755b048a473d7fba470e02d707fcdcadcfaf737bd97", jsonPointer: "/stages/1/objective", fragmentSHA256: "eb77be5484dcf75bfe8da702799ca7d6c07c582a7b1cea5cf54fc5489d0eae31")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.wayfarer-exchange/archive/exchange-reference-curator", replicaID: "proposed-replica-exchange-reference-curator",
          originIdentity: "proposed-exchange-reference-curator", originDomain: "exchange-reference-curator",
          payloadSHA256: "f4ea5dbba8bbd01b50359a062f848ca14194778eea6652248fe95a75c657562f",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-exchange.json", fileSHA256: "9be9729169d2f52ab0b10755b048a473d7fba470e02d707fcdcadcfaf737bd97", jsonPointer: "/completionClue/receipt", fragmentSHA256: "11ba03b597f417b6560eb60ecc57553e9ae8c595908bb9096c3d67fe96b23743")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.wayfarer-service/cold-chain", clueID: "exchange-service-cold-chain",
        receiptID: "l337.unwritten-route/clue/exchange-service-cold-chain",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", sha256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/0/id"),
        profile: .init(commit: "cf9d14ad5328238206411bb1e5ebaea2e7e798f0", path: "docs/meridian/missions/gameplay/recovery-policy-corpus-successor.json", sha256: "bab72a03d34c800343ae632f61f748cb6ce33da9007243146f896418660da0f1", jsonPointer: "/profiles/l337.wayfarer-service~1cold-chain"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.wayfarer-service/cold-chain/archive/medical-integrity-editor", replicaID: "proposed-replica-medical-integrity-editor",
          originIdentity: "proposed-medical-integrity-editor", originDomain: "medical-integrity-editor",
          payloadSHA256: "6f669d5b9f89588763fa1fcc1db16b3d6c2dac056102f897e45c386a7a9570f4",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/0/description", fragmentSHA256: "ecc690662e66938813b077d4f84094a4adbcfaba61af7bd0ce206e1ebf920d9f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.wayfarer-service/cold-chain/archive/sealed-sample-reception-custodian", replicaID: "proposed-replica-sealed-sample-reception-custodian",
          originIdentity: "proposed-sealed-sample-reception-custodian", originDomain: "sealed-sample-reception-custodian",
          payloadSHA256: "972519e3017b5aaccff1581e6f53c04b766b1e1c601ba4e1332d8aa36e9707be",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/0/stages/1/objective", fragmentSHA256: "ecc690662e66938813b077d4f84094a4adbcfaba61af7bd0ce206e1ebf920d9f")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.wayfarer-service/cold-chain/archive/clinic-service-reference-curator", replicaID: "proposed-replica-clinic-service-reference-curator",
          originIdentity: "proposed-clinic-service-reference-curator", originDomain: "clinic-service-reference-curator",
          payloadSHA256: "a56b336124a6f33f6c92cfc556ac651ea5c4620e30e0108abf34a7a3f62acd40",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/0/completionClue/receipt", fragmentSHA256: "6cddb80762292185734b6f6e4068f391457770440073fa5b4906a8dfddffeb07")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.wayfarer-service/convoy-watch", clueID: "exchange-service-convoy-watch",
        receiptID: "l337.unwritten-route/clue/exchange-service-convoy-watch",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", sha256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/5/id"),
        profile: .init(commit: "cf9d14ad5328238206411bb1e5ebaea2e7e798f0", path: "docs/meridian/missions/gameplay/recovery-policy-corpus-successor.json", sha256: "bab72a03d34c800343ae632f61f748cb6ce33da9007243146f896418660da0f1", jsonPointer: "/profiles/l337.wayfarer-service~1convoy-watch"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.wayfarer-service/convoy-watch/archive/convoy-registration-editor", replicaID: "proposed-replica-convoy-registration-editor",
          originIdentity: "proposed-convoy-registration-editor", originDomain: "convoy-registration-editor",
          payloadSHA256: "814fc813d1a375a942cc3c50788da04431fed080e6e3226a994edef2d894e43c",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/5/description", fragmentSHA256: "89061b503507856e70a96402b689bac8803642ba64ae9aa52bc836343b4ae4dd")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.wayfarer-service/convoy-watch/archive/convoy-protection-custodian", replicaID: "proposed-replica-convoy-protection-custodian",
          originIdentity: "proposed-convoy-protection-custodian", originDomain: "convoy-protection-custodian",
          payloadSHA256: "ddfebf4f4ae019ac852da405f11b2a59062f59d69e7a872293f85d9aae765190",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/5/stages/1/objective", fragmentSHA256: "89061b503507856e70a96402b689bac8803642ba64ae9aa52bc836343b4ae4dd")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.wayfarer-service/convoy-watch/archive/watch-reference-curator", replicaID: "proposed-replica-watch-reference-curator",
          originIdentity: "proposed-watch-reference-curator", originDomain: "watch-reference-curator",
          payloadSHA256: "f0ba6d607d97680e36df89a35354748a506a31138153773d0be574fd10bcf5b6",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/5/completionClue/receipt", fragmentSHA256: "7b7220603ad2912260027a31195f1485aaeea1d4c994579f14977c262a35c1af")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.wayfarer-service/field-relief", clueID: "exchange-service-field-relief",
        receiptID: "l337.unwritten-route/clue/exchange-service-field-relief",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", sha256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/3/id"),
        profile: .init(commit: "cf9d14ad5328238206411bb1e5ebaea2e7e798f0", path: "docs/meridian/missions/gameplay/recovery-policy-corpus-successor.json", sha256: "bab72a03d34c800343ae632f61f748cb6ce33da9007243146f896418660da0f1", jsonPointer: "/profiles/l337.wayfarer-service~1field-relief"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.wayfarer-service/field-relief/archive/remote-utility-editor", replicaID: "proposed-replica-remote-utility-editor",
          originIdentity: "proposed-remote-utility-editor", originDomain: "remote-utility-editor",
          payloadSHA256: "5a15940b8273f4225cb9089cc426b69b10b7e1a02ea03264775dd6454888b7fe",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/3/description", fragmentSHA256: "b67daafc4092ce60c571be9f79016cd22fd5d232a94e22b4d270c9a3e0d0198c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.wayfarer-service/field-relief/archive/relief-reception-custodian", replicaID: "proposed-replica-relief-reception-custodian",
          originIdentity: "proposed-relief-reception-custodian", originDomain: "relief-reception-custodian",
          payloadSHA256: "c71548c4eddcd4a9d11673099499cd34674e1a76ef9710ed4f21c56dd589db5a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/3/stages/1/objective", fragmentSHA256: "b67daafc4092ce60c571be9f79016cd22fd5d232a94e22b4d270c9a3e0d0198c")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.wayfarer-service/field-relief/archive/utility-reference-curator", replicaID: "proposed-replica-utility-reference-curator",
          originIdentity: "proposed-utility-reference-curator", originDomain: "utility-reference-curator",
          payloadSHA256: "39720b57faa4bf69b57379186d67fc6ea5ae4cedf71dd62752cde18bc51c4fab",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/3/completionClue/receipt", fragmentSHA256: "118575680bae4279e64b92335b4ac1e2e1c29fe496ec86b3ae2b8a3d475f54f1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.wayfarer-service/record-recovery", clueID: "exchange-service-record-recovery",
        receiptID: "l337.unwritten-route/clue/exchange-service-record-recovery",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", sha256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/4/id"),
        profile: .init(commit: "cf9d14ad5328238206411bb1e5ebaea2e7e798f0", path: "docs/meridian/missions/gameplay/recovery-policy-corpus-successor.json", sha256: "bab72a03d34c800343ae632f61f748cb6ce33da9007243146f896418660da0f1", jsonPointer: "/profiles/l337.wayfarer-service~1record-recovery"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.wayfarer-service/record-recovery/archive/crew-record-custody-editor", replicaID: "proposed-replica-crew-record-custody-editor",
          originIdentity: "proposed-crew-record-custody-editor", originDomain: "crew-record-custody-editor",
          payloadSHA256: "176202af58460d1cde7e65e7a6d121f81b40ece5b6cbc903b194e88c98dc15b3",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/4/description", fragmentSHA256: "0c2c785394de8891b8e43abc3f2c5dbc46a9e3e87365f33d36915b71db0ac0af")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.wayfarer-service/record-recovery/archive/protected-record-reception-custodian", replicaID: "proposed-replica-protected-record-reception-custodian",
          originIdentity: "proposed-protected-record-reception-custodian", originDomain: "protected-record-reception-custodian",
          payloadSHA256: "d7d55af08f60741c795b3da913bca2323aec28b83ffece2a3b70a2c00a2d80e9",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/4/stages/1/objective", fragmentSHA256: "0c2c785394de8891b8e43abc3f2c5dbc46a9e3e87365f33d36915b71db0ac0af")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.wayfarer-service/record-recovery/archive/crew-record-reference-curator", replicaID: "proposed-replica-crew-record-reference-curator",
          originIdentity: "proposed-crew-record-reference-curator", originDomain: "crew-record-reference-curator",
          payloadSHA256: "7d2e706ce784bbadb8dff9f3befb430abb7cdb40930710bb69db2a977cfb1ef3",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/4/completionClue/receipt", fragmentSHA256: "b6d407abe266e8c7457e96c5da46165bc66134c7793e39683ea8f0863cecb8a1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.wayfarer-service/repair-loop", clueID: "exchange-service-repair-loop",
        receiptID: "l337.unwritten-route/clue/exchange-service-repair-loop",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", sha256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/1/id"),
        profile: .init(commit: "cf9d14ad5328238206411bb1e5ebaea2e7e798f0", path: "docs/meridian/missions/gameplay/recovery-policy-corpus-successor.json", sha256: "bab72a03d34c800343ae632f61f748cb6ce33da9007243146f896418660da0f1", jsonPointer: "/profiles/l337.wayfarer-service~1repair-loop"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.wayfarer-service/repair-loop/archive/repair-component-editor", replicaID: "proposed-replica-repair-component-editor",
          originIdentity: "proposed-repair-component-editor", originDomain: "repair-component-editor",
          payloadSHA256: "83a0a65934e1fb5de3ff10647ab84ffcf12ec7183a683405ef002805e1aa1998",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/1/description", fragmentSHA256: "8295adb068f461b32b81c9bae30be677fa89457a25eb1fc977d11f270f8f4cdb")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.wayfarer-service/repair-loop/archive/repair-return-custodian", replicaID: "proposed-replica-repair-return-custodian",
          originIdentity: "proposed-repair-return-custodian", originDomain: "repair-return-custodian",
          payloadSHA256: "f427344d939c508f4eeb6d4f955c9838323f80a28c2a1c4b23b53de8ba662d19",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/1/stages/1/objective", fragmentSHA256: "8295adb068f461b32b81c9bae30be677fa89457a25eb1fc977d11f270f8f4cdb")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.wayfarer-service/repair-loop/archive/repair-loop-reference-curator", replicaID: "proposed-replica-repair-loop-reference-curator",
          originIdentity: "proposed-repair-loop-reference-curator", originDomain: "repair-loop-reference-curator",
          payloadSHA256: "d18733cf21ef73e1543ed077aa181c92741aceb414a2807046d120d93db478e9",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/1/completionClue/receipt", fragmentSHA256: "e16c283616aa57df2bba69278777b70dd3c8d56933bcd2f521118596f38463f1")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.wayfarer-service/seed-transfer", clueID: "exchange-service-seed-transfer",
        receiptID: "l337.unwritten-route/clue/exchange-service-seed-transfer",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", sha256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/2/id"),
        profile: .init(commit: "cf9d14ad5328238206411bb1e5ebaea2e7e798f0", path: "docs/meridian/missions/gameplay/recovery-policy-corpus-successor.json", sha256: "bab72a03d34c800343ae632f61f748cb6ce33da9007243146f896418660da0f1", jsonPointer: "/profiles/l337.wayfarer-service~1seed-transfer"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.wayfarer-service/seed-transfer/archive/seed-bank-custody-editor", replicaID: "proposed-replica-seed-bank-custody-editor",
          originIdentity: "proposed-seed-bank-custody-editor", originDomain: "seed-bank-custody-editor",
          payloadSHA256: "8100b1f5ea2002ea34ff8f24a1d8b682902bb4e8abc353b56289627fd8fb9f18",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/2/description", fragmentSHA256: "1179aa5086fcd39a0c7b849e88ad993af27ce5b3ee9a0668b034cf376cc3c1c6")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.wayfarer-service/seed-transfer/archive/seed-integrity-reception-custodian", replicaID: "proposed-replica-seed-integrity-reception-custodian",
          originIdentity: "proposed-seed-integrity-reception-custodian", originDomain: "seed-integrity-reception-custodian",
          payloadSHA256: "7d20118cc6ed584e2311c137eb1b319c1bc7b56defcf63ecdeaed7b3c0c0eca9",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/2/stages/1/objective", fragmentSHA256: "1179aa5086fcd39a0c7b849e88ad993af27ce5b3ee9a0668b034cf376cc3c1c6")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.wayfarer-service/seed-transfer/archive/seed-transfer-reference-curator", replicaID: "proposed-replica-seed-transfer-reference-curator",
          originIdentity: "proposed-seed-transfer-reference-curator", originDomain: "seed-transfer-reference-curator",
          payloadSHA256: "687aecd7d8dd1c5025eba9bb2be4c01fe4b98e0e5710f911ee0dd74263c8df8a",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/wayfarer-services.json", fileSHA256: "45f522e0dc7a8bab84d50dbc6ad76c56c024b686ff4fb66403e19a57534b45f4", jsonPointer: "/templates/2/completionClue/receipt", fragmentSHA256: "67c947a2254084c799720d9878f8d29875b4ddd022c04f95aa61fb18513b2173")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222),
      .init(source: .init(sourceID: "l337.witness-window", clueID: "witness-window-trace",
        receiptID: "l337.unwritten-route/clue/witness-window-trace",
        definition: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/witness-window.json", sha256: "4edcb88c16f0a0aa6a815378d1b5db43d8d5723a9e6635f71b939ec28c87a29a", jsonPointer: "/id"),
        profile: .init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/gameplay/recovery-policy.json", sha256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b", jsonPointer: "/profiles/l337.witness-window"),
        archive: .init(path: "charter-archive-models-f.json", sha256: "57f6e46f38eb71ed00f7d953efe5d0a6cc4ae3947eeb809fba32e2cb27a4bf10"), calibration: .init(path: "charter-calibration-models.json", sha256: "2bd2c4c198b9820407c3cccd3bfa93deaed6e8b307ec794fb0647e96c0a9e46d"),
        observations: [
        .init(ordinal: 0, recordID: "l337.witness-window/archive/evidence-key-editor", replicaID: "proposed-replica-evidence-key-editor",
          originIdentity: "proposed-evidence-key-editor", originDomain: "evidence-key-editor",
          payloadSHA256: "dcfa1fe017ac33eb9f1ee0827a8f4c87110b0380bdc538896f6f92f411ea3b73",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/witness-window.json", fileSHA256: "4edcb88c16f0a0aa6a815378d1b5db43d8d5723a9e6635f71b939ec28c87a29a", jsonPointer: "/story", fragmentSHA256: "c71293c8cc1a77da6997ba3d5fefcff365e1eb9d181a2ca6268ca3b46941b6a2")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 1, recordID: "l337.witness-window/archive/revoked-preview-custodian", replicaID: "proposed-replica-revoked-preview-custodian",
          originIdentity: "proposed-revoked-preview-custodian", originDomain: "revoked-preview-custodian",
          payloadSHA256: "a1e4a040d798506fe2de51be74e245743a3c21c307d2ac2ea107297ecdcfc3ff",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/witness-window.json", fileSHA256: "4edcb88c16f0a0aa6a815378d1b5db43d8d5723a9e6635f71b939ec28c87a29a", jsonPointer: "/stages/1/objective", fragmentSHA256: "295a3f0c2c3879eb389a3a31ff8eb5c37ff27e243b2faa19105af2119b24eca0")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only"),
        .init(ordinal: 2, recordID: "l337.witness-window/archive/witness-reference-curator", replicaID: "proposed-replica-witness-reference-curator",
          originIdentity: "proposed-witness-reference-curator", originDomain: "witness-reference-curator",
          payloadSHA256: "be32c79b86bffdd2d5a1105c207fb89ff505f127e2099f9c9f7a398542c8b557",
          originalFacts: [.init(commit: "c70110b292077588a0855fb48127adfb1b611c9d", path: "docs/meridian/missions/definitions/witness-window.json", fileSHA256: "4edcb88c16f0a0aa6a815378d1b5db43d8d5723a9e6635f71b939ec28c87a29a", jsonPointer: "/completionClue/receipt", fragmentSHA256: "4d3c0b85a1f1eb67235b87d75ed58bd38ee51b494cb1138b4ce2948c14e12c10")],
          relativeChronology: "before-original-source-offer", authoringClass: "new-fictional-public-model", scope: "fictional-public-model-only")
      ]), archiveBytes: 214643, calibrationBytes: 157222)
    ])
}
