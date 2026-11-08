import Foundation

/// Fixed C01 content only. No case, operator, fixture, clue or offer authority.
/// Exact approved fictional content; case, operator and live ingress authority remain separate.
enum NativeC01CharterArchiveApproval {
  enum Failure: Error, Sendable { case unavailable, sourceMismatch, invalidSchema, invalidContent, unapproved }
  enum Resource: Sendable { case archive, calibration }
  private enum Approval: Sendable { case pendingReview, approvedPublishedContent }
  enum Publication: String, Decodable, Sendable {
    case prospective
    case publishedSource = "published-source"
  }

  private static let sourceID = "l337.glass-meridian"
  private static let scope = "fictional-public-model-only"
  private static let originalCommit = "c70110b292077588a0855fb48127adfb1b611c9d"
  private static let originalPath = "docs/meridian/missions/definitions/glass-meridian.json"
  private static let originalSHA256 =
    "14e29571b5c6335ecca5068516448224944e6881462aa329f14bb6a1cb2ea572"
  private static let traceSHA256 =
    "4112a5d32e27361859fc2f1bfec418b9a197397af3cfc8363767207f01365f8b"
  // Exact v4 content-set SHA256: 1d3d1bb928634cb97dec31d49f7b677062eeebea306500c1fa5a1ec4d04ba64f
  // Actual human publication approval receipt SHA256: 4811c3846f4de7a8243a96bd633d49b72da430765e85c5f57c38b49ba89040b0
  private static let approval = Approval.approvedPublishedContent
  private static let archiveBytes = 22201
  private static let archiveSHA256 = "131fec20b046881742ae3b76ef6e69bf64ca9caad65482267dbf6417ffebb26a"
  private static let calibrationBytes = 3023
  private static let calibrationSHA256 = "35fe099defefccbd7d5c917e156e36de95240079536325c88c4f56468c98ea04"

  struct Content: Sendable {
    let archive: ArchiveDocument
    let calibration: CalibrationDocument
    let archiveSHA256: String
    let calibrationSHA256: String
    fileprivate init(
      archive: ArchiveDocument, calibration: CalibrationDocument,
      archiveSHA256: String, calibrationSHA256: String
    ) {
      self.archive = archive
      self.calibration = calibration
      self.archiveSHA256 = archiveSHA256
      self.calibrationSHA256 = calibrationSHA256
    }
  }

  struct ArchiveDocument: Decodable, Sendable {
    let schema: String
    let publication: Publication
    let contentScope: String
    let sourceGroups: [String: ArchiveGroup]
  }

  struct ArchiveGroup: Decodable, Sendable {
    let sourceBinding: SourceBinding
    let declarations: [Declaration]
    let institutionalServiceSource: InstitutionalServiceSource
    let serviceStaffingPolicy: ServiceStaffingPolicy
    let challengeArchiveRoles: [ChallengeArchiveRole]
  }

  enum DutyRole: String, Decodable, Sendable {
    case intake
    case independentReview = "independent-review"
  }

  struct InstitutionalServiceSource: Decodable, Sendable {
    let definitionID: String
    let definitionRevision: String
    let definitionSHA256: String
    let sourceBinding: SourceBinding
    let hostPolicy: String
    let provenance: [PolicyFragmentReference]
    let subjectDefinitions: [InstitutionalSubjectDefinition]
    let initialDutyMapping: [InitialDutyMapping]
    let activationLaw: String
    let availabilityLifecycleRule: String
    let staffingPolicyReference: PolicyIdentity
    let challengeArchiveRolesReference: PolicyIdentity
    let scopeRule: String
  }

  struct PolicyFragmentReference: Decodable, Sendable {
    let commit: String
    let path: String
    let fileSHA256: String
    let jsonPointer: String
    let fragmentBytes: Int
    let fragmentSHA256: String
  }

  struct InstitutionalSubjectDefinition: Decodable, Sendable {
    let definitionKey: String
    let ordinal: Int
  }

  struct InitialDutyMapping: Decodable, Sendable {
    let roleKey: DutyRole
    let subjectDefinitionKey: String
  }

  struct PolicyIdentity: Decodable, Sendable {
    let identity: String
    let revision: String
    let sha256: String
  }

  struct ServiceStaffingPolicy: Decodable, Sendable {
    let policyID: String
    let policyRevision: String
    let policySHA256: String
    let institutionalDefinitionID: String
    let institutionalDefinitionRevision: String
    let roles: [StaffRolePolicy]
    let requiredAssignmentProof: String
    let reviewInputBasis: String
  }

  struct StaffRolePolicy: Decodable, Sendable {
    let roleKey: DutyRole
    let function: String
    let allowedInputs: [String]
    let outputBasis: String
    let prohibitedBasis: [String]
  }

  struct ChallengeArchiveRole: Decodable, Sendable {
    let sourceID: String
    let contentRevision: String
    let challengeOrdinal: Int
    let recordID: String
    let replicaID: String
    let origin: Origin
    let recordPayloadSHA256: String
    let originalFactIDs: [String]
    let modelInput: ModelInputReference
    let sourceSetBinding: SourceSetReference
  }

  struct ModelInputReference: Decodable, Sendable {
    let resourcePath: String
    let resourceSHA256: String
    let profileSchema: String
    let jsonPointer: String
    let offsetDegrees: Int
  }

  struct SourceBinding: Decodable, Sendable {
    let sourceID: String
    let clueID: String
    let clueReceipt: String
    let originalDefinition: OriginalDefinition
    let recoveryProfileSelector: RecoveryReference
    let sourceSetBinding: SourceSetReference
  }

  struct OriginalDefinition: Decodable, Sendable {
    let bytes: Int
    let commit: String
    let path: String
    let sha256: String
  }

  struct RecoveryReference: Decodable, Sendable {
    let commit: String
    let jsonPointer: String
    let path: String
    let sha256: String
  }

  struct SourceSetReference: Decodable, Sendable {
    let commit: String
    let path: String
    let selector: String
    let sha256: String
  }

  struct Declaration: Decodable, Sendable {
    let recordID: String
    let replicaID: String
    let origin: Origin
    let proposedStatement: String
    let inputBasis: String
    let nonPrivateScope: String
    let relativeChronology: Chronology
    let subjectWorld: SubjectWorld
    let originalFacts: [Fact]
    let hiddenTraceReference: HiddenTrace
    let authoringClass: String
  }

  struct Origin: Decodable, Sendable {
    let identity: String
    let domain: String
  }

  struct Chronology: Decodable, Sendable {
    let kind: String
    let order: Int
    let originStatus: String
    let relation: String
  }

  struct SubjectWorld: Decodable, Sendable {
    let galaxy: Int
    let locationKey: String
    let originalStageSelector: String
    let system: Int
  }

  struct Fact: Decodable, Sendable {
    let characterSpanHalfOpen: [Int]
    let commit: String
    let factID: String
    let fileSHA256: String
    let fragment: String
    let fragmentUTF8SHA256: String
    let jsonPointer: String
    let path: String
    let supports: String
  }

  struct HiddenTrace: Decodable, Sendable {
    let commit: String
    let contentSHA256: String
    let fileSHA256: String
    let jsonPointer: String
    let path: String
    let visibleBeforeActualClueReceipt: Bool
  }

  struct CalibrationDocument: Decodable, Sendable {
    let schema: String
    let publication: Publication
    let contentScope: String
    let sourcePins: SourceBinding
    let profiles: [String: CalibrationGroup]
  }

  struct CalibrationGroup: Decodable, Sendable {
    let continuityCalibration: Calibration
  }

  struct Calibration: Decodable, Sendable {
    let adaptation: String
    let aimDegrees: Int
    let benchAcceptance: String
    let dwellSeconds: Int
    let independence: String
    let mechanic: String
    let observations: Int
    let parameterStatus: String
    let parameters: PulseParameters
    let referenceFrame: String
    let sourceModelRequirement: String
    let surfaceRangeNativeUnits: [Int]
  }

  struct PulseParameters: Decodable, Sendable {
    let phaseOffsetsDegrees: [Int]
    let sampleCycles: Int
    let toleranceDegrees: Int
  }

  private struct RecordDescriptor: Sendable {
    let record: String
    let replica: String
    let origin: String
    let domain: String
    let statementSHA256: String
    let inputBasisSHA256: String
    let system: Int
    let locationKey: String
    let stage: String
    let fact: String
    let pointer: String
    let span: [Int]
    let fragmentSHA256: String
  }

  // Exact proposed statements and input bases were reviewed as new authorship.
  // These integrity pins neither sign them nor establish actual observation.
  private static let records: [RecordDescriptor] = [
    .init(
      record: "l337.glass-meridian/archive/traffic-notice",
      replica: "charter-replica-traffic",
      origin: "proposed-avenor-lane-notice-custodian",
      domain: "traffic-publication",
      statementSHA256: "821287b7f2648b280549eb4a7b13eb81fe532f02cf163b9a7d33d1f99ea33808",
      inputBasisSHA256: "528052fe0ae980c2b918528df7516faee6a897bfe0cba54048b492c5a95f7d88",
      system: 7,
      locationKey: "G01-S007",
      stage: "/stages[id=accept]",
      fact: "lane-report",
      pointer: "/story",
      span: [0, 89],
      fragmentSHA256: "9f90fe9d1aedbd0c325cb14d9f8835b0e482aefb71c370510f0f83fbdeab8a9d"),
    .init(
      record: "l337.glass-meridian/archive/clock-notice",
      replica: "charter-replica-certification",
      origin: "proposed-certified-lane-clock-custodian",
      domain: "clock-certification",
      statementSHA256: "19831f2e0a1e1ffd89c2d4dcdef95550860bf2b42be5a8713dde1eda41e4dc28",
      inputBasisSHA256: "5e00d0e4fff843847f93686e08fdfc065d94b9ede3d81f1adb1128a1d70169a2",
      system: 185,
      locationKey: "G01-S185",
      stage: "/stages[id=compare-clocks]",
      fact: "clock-disagreement",
      pointer: "/story",
      span: [90, 156],
      fragmentSHA256: "1e4a81f17ab56a0eda35f4dc164cd265973e44d83d40aafc67c8f83f08c3447d"),
    .init(
      record: "l337.glass-meridian/archive/trace-reference",
      replica: "charter-replica-reference",
      origin: "proposed-independent-meridian-reference-custodian",
      domain: "independent-reference",
      statementSHA256: "7270516d2c5531145e606db035c45b600d11521ea28d0c374d0da70a98dd42d9",
      inputBasisSHA256: "ede3a677d19be34743d5e76213d95c8736039257708340d6ebe3318c43672012",
      system: 162,
      locationKey: "G01-S162",
      stage: "/stages[id=recover-standard]",
      fact: "hidden-trace",
      pointer: "/completionClue/journalText",
      span: [0, 147],
      fragmentSHA256: "4112a5d32e27361859fc2f1bfec418b9a197397af3cfc8363767207f01365f8b"),
  ]

  private static let retainedContent: Result<Content, any Error> = Result {
    try readContent()
  }

  static func load() throws -> Content { try retainedContent.get() }

  private static func readContent() throws -> Content {
    let resources = Bundle.main.resourceURL.flatMap {
      Bundle(url: $0.appendingPathComponent("L337_L337Core.bundle"))
    } ?? Bundle.module
    guard let resourceURL = resources.resourceURL else { throw Failure.unavailable }
    let directory = resourceURL.appendingPathComponent("MissionPacks/native-unwritten-route")
    let archive = try read(.archive, in: directory)
    let calibration = try read(.calibration, in: directory)
    try archiveShape(archive)
    try calibrationShape(calibration)
    let decoder = JSONDecoder()
    let source = try decoder.decode(ArchiveDocument.self, from: archive)
    let profile = try decoder.decode(CalibrationDocument.self, from: calibration)
    try validate(source, profile: profile)
    // Publication is bound to the approved content and exact resource bytes above.
    // This entry does not issue case, operator, observation or live ingress authority.
    guard approval == .approvedPublishedContent,
      source.publication == .publishedSource, profile.publication == .publishedSource
    else { throw Failure.unapproved }
    return Content(
      archive: source, calibration: profile,
      archiveSHA256: archiveSHA256, calibrationSHA256: calibrationSHA256)
  }

  private static func read(_ resource: Resource, in directory: URL) throws -> Data {
    let name: String
    switch resource {
    case .archive: name = "charter-archive-observations.json"
    case .calibration: name = "recovery-policy.json"
    }
    let data = try ScriptPackLibrary.readFile(name, in: directory)
    try validateResourceBytes(data, for: resource)
    return data
  }

  /// Fixed content integrity only; passing never constructs Content or grants approval.
  static func validateResourceBytes(_ data: Data, for resource: Resource) throws {
    let expected: (count: Int, hash: String)
    switch resource {
    case .archive: expected = (archiveBytes, archiveSHA256)
    case .calibration: expected = (calibrationBytes, calibrationSHA256)
    }
    guard data.count == expected.count, ScriptPackLibrary.hash(data) == expected.hash else {
      throw Failure.sourceMismatch
    }
    try ScriptSaveJSONPreflight.validate(data)
  }

  static func validate(_ archive: ArchiveDocument, profile: CalibrationDocument) throws {
    guard archive.schema == "l337.c01.charter-archive-content/2",
      profile.schema == "l337.c01.continuity-calibration-content/1",
      archive.contentScope == scope, profile.contentScope == scope,
      archive.publication == profile.publication,
      let group = archive.sourceGroups[sourceID], group.declarations.count == records.count,
      Set(group.declarations.map(\.recordID)).count == records.count,
      Set(group.declarations.map(\.replicaID)).count == records.count,
      Set(group.declarations.map { $0.origin.identity }).count == records.count,
      Set(group.declarations.map { $0.origin.domain }).count == records.count,
      let calibration = profile.profiles[sourceID]?.continuityCalibration
    else { throw Failure.invalidContent }
    try validateBinding(group.sourceBinding)
    try validateBinding(profile.sourcePins)
    try validateStaffingPolicy(group.serviceStaffingPolicy)
    try validateChallengeArchiveRoles(
      group.challengeArchiveRoles, declarations: group.declarations, calibration: calibration)
    try validateInstitutionalServiceSource(
      group.institutionalServiceSource, staffing: group.serviceStaffingPolicy,
      roles: group.challengeArchiveRoles)
    for (index, declaration) in group.declarations.enumerated() {
      try validateDeclaration(declaration, descriptor: records[index], order: index + 1)
    }
    guard calibration.parameterStatus == "new project estimate",
      calibration.observations == 3, calibration.dwellSeconds == 12,
      calibration.aimDegrees == 2, calibration.surfaceRangeNativeUnits == [250, 1500],
      calibration.parameters.phaseOffsetsDegrees == [0, 45, 90],
      calibration.parameters.sampleCycles == 3, calibration.parameters.toleranceDegrees == 2
    else { throw Failure.invalidContent }
  }

  // These fixed policy descriptors bind new static content, never actual staff or authority.
  private static let institutionalDefinitionID = "l337.glass-meridian/institutional-charter-service"
  private static let institutionalDefinitionRevision = "c01-institutional-service-v1"
  private static let institutionalDefinitionSHA256 = "4b68fef89c5568ee634bf66080fbe001adfae1f49489e46d4cd824bb3e8b50a0"
  private static let staffingPolicyID = "l337.glass-meridian/service-staffing"
  private static let staffingPolicyRevision = "c01-charter-staffing-v1"
  private static let staffingPolicySHA256 = "712d73b41c7075050bcb39d785894fb384544943704058b03844098745789db6"
  private static let archiveRolesID = "l337.glass-meridian/challenge-archive-roles"
  private static let archiveRolesRevision = "c01-archive-role-correspondence-v1"
  private static let archiveRolesSHA256 = "84592c54fa604c2fca68dd5b51ead0ceeac223751ce47e8a0a8c1428df6c237c"
  private static let institutionalSubjectKeys = [
    "l337.glass-meridian/charter-subject/0",
    "l337.glass-meridian/charter-subject/1",
  ]
  private static let declarationPayloadSHA256 = [
    "65e420e62faecda10489da8dfb293742b60a317847b381eef21456d9af4062bc",
    "c104ba048e4534998b3a41dcba2e1a31e9dd4ba39a57f54200eac9524b7bc8e0",
    "138dbdc2e2c7aa35996fba42d11942a0f69ac13970f94863352bf3cddabf2b9f",
  ]

  private static let serviceProvenance: [PolicyFragmentReference] = [
    .init(
      commit: "c70110b292077588a0855fb48127adfb1b611c9d",
      path: "docs/meridian/missions/gameplay/recovery-policy.json",
      fileSHA256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b",
      jsonPointer: "/continuityInquiry/service",
      fragmentBytes: 772,
      fragmentSHA256: "c9ef801c80c3a37cfcc0070eb9ffb62756b7e2b26c4b05bcce4b60cad287e55a"),
    .init(
      commit: "c70110b292077588a0855fb48127adfb1b611c9d",
      path: "docs/meridian/missions/gameplay/recovery-policy.json",
      fileSHA256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b",
      jsonPointer: "/continuityInquiry/costPolicy",
      fragmentBytes: 386,
      fragmentSHA256: "0908761f3aa64f58bcfa2ee967807cf5dc9d3363e2e1d3fd99a2c2f4a865227d"),
    .init(
      commit: "c70110b292077588a0855fb48127adfb1b611c9d",
      path: "docs/meridian/missions/gameplay/recovery-policy.json",
      fileSHA256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b",
      jsonPointer: "/continuityInquiry/entry",
      fragmentBytes: 334,
      fragmentSHA256: "5f94a39866758929ca78fcd179d6f392f3272946df6eb25f5dfe7bab6bc99d95"),
    .init(
      commit: "c70110b292077588a0855fb48127adfb1b611c9d",
      path: "docs/meridian/missions/gameplay/recovery-policy.json",
      fileSHA256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b",
      jsonPointer: "/continuityInquiry/stages/0",
      fragmentBytes: 842,
      fragmentSHA256: "bf125f8e755d745d03d692a698cd7d41ec1916a31927609fe018290314aab717"),
    .init(
      commit: "c70110b292077588a0855fb48127adfb1b611c9d",
      path: "docs/meridian/missions/gameplay/recovery-policy.json",
      fileSHA256: "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b",
      jsonPointer: "/continuityInquiry/stages/3",
      fragmentBytes: 957,
      fragmentSHA256: "d57a5b745aee2a3603dc8cb7cc1cad0aa8a88a46b5eb0757c62638b13630f6ea"),
  ]

  private static let staffingRoles: [StaffRolePolicy] = [
    .init(
      roleKey: .intake,
      function: "Actual service opens this C01 inquiry/mandate and binds three case challenges.",
      allowedInputs: [
        "approved C01 source/profile/content/corpus pins",
        "actual current living station arrival and available native staffing assignment",
        "canonical case request and original outcome reference",
      ],
      outputBasis: "Administrative mandate/challenge bindings only; no measurement/bench/audit verdict or clue.",
      prohibitedBasis: [
        "claimed original mission success or private staff consent",
        "stored or caller-supplied passed flag",
        "approval of its own final audit",
      ]
    ),
    .init(
      roleKey: .independentReview,
      function: "A different actual authorized operator receives and independently checks the measured C01 case.",
      allowedInputs: [
        "its own current source-approved native staffing assignment and real arrival/receiving action",
        "all three actual case measurement receipts and actual passing bench output observations",
        "direct approved archive-origin/model-channel references for at least two independently corroborated origins",
        "actual original outcome/loss references as reference facts",
      ],
      outputBasis: "Native verified audit receipt with exact "
        + "case/assignment/measurement/bench/archive correspondence, never a restatement of "
        + "intake approval.",
      prohibitedBasis: [
        "intake mandate or control settings alone",
        "renamed copy of an intake result",
        "roleID/UUID inequality treated as independent input or a real receiving action",
      ]
    ),
  ]

  private static func validateInstitutionalServiceSource(
    _ value: InstitutionalServiceSource, staffing: ServiceStaffingPolicy,
    roles: [ChallengeArchiveRole]
  ) throws {
    try validateBinding(value.sourceBinding)
    guard value.definitionID == institutionalDefinitionID,
      value.definitionRevision == institutionalDefinitionRevision,
      value.definitionSHA256 == institutionalDefinitionSHA256,
      value.hostPolicy == "every-operational-main-station",
      value.provenance.count == serviceProvenance.count,
      value.subjectDefinitions.count == 2, value.initialDutyMapping.count == 2,
      value.activationLaw == "root-confirmed-first-request-two-subjects-two-duties-first-case-one-root-same-writer-v1",
      value.availabilityLifecycleRule == "actual-operational-host-and-committed-available-subject-standing-assignment-no-rebirth-v1",
      value.scopeRule == "standing-public-duty-zero-commander-resources-no-original-success-sh141-and-tender-separate-v1",
      value.staffingPolicyReference.identity == staffing.policyID,
      value.staffingPolicyReference.revision == staffing.policyRevision,
      value.staffingPolicyReference.sha256 == staffing.policySHA256,
      value.challengeArchiveRolesReference.identity == archiveRolesID,
      value.challengeArchiveRolesReference.revision == archiveRolesRevision,
      value.challengeArchiveRolesReference.sha256 == archiveRolesSHA256, roles.count == 3
    else { throw Failure.invalidContent }
    for (actual, expected) in zip(value.provenance, serviceProvenance) {
      guard actual.commit == expected.commit, actual.path == expected.path,
        actual.fileSHA256 == expected.fileSHA256, actual.jsonPointer == expected.jsonPointer,
        actual.fragmentBytes == expected.fragmentBytes, actual.fragmentSHA256 == expected.fragmentSHA256
      else { throw Failure.invalidContent }
    }
    for (index, subject) in value.subjectDefinitions.enumerated() {
      guard subject.ordinal == index, subject.definitionKey == institutionalSubjectKeys[index] else {
        throw Failure.invalidContent
      }
    }
    guard value.initialDutyMapping[0].roleKey == .intake,
      value.initialDutyMapping[1].roleKey == .independentReview,
      value.initialDutyMapping[0].subjectDefinitionKey == institutionalSubjectKeys[0],
      value.initialDutyMapping[1].subjectDefinitionKey == institutionalSubjectKeys[1]
    else { throw Failure.invalidContent }
  }

  private static func validateStaffingPolicy(_ value: ServiceStaffingPolicy) throws {
    guard value.policyID == staffingPolicyID, value.policyRevision == staffingPolicyRevision,
      value.policySHA256 == staffingPolicySHA256,
      value.institutionalDefinitionID == institutionalDefinitionID,
      value.institutionalDefinitionRevision == institutionalDefinitionRevision,
      value.requiredAssignmentProof == "Actual operator subject reference and native service assignment "
        + "activation/lifecycle proof for each role; two distinct actual subjects, not just "
        + "role/assignment UUIDs. Content policy is not such a proof.",
      value.reviewInputBasis == "Independent native access to approved archive origins/model-channel "
        + "correspondence plus all actual measured/bench outputs; no acceptance from intake "
        + "summary alone.",
      value.roles.count == staffingRoles.count
    else { throw Failure.invalidContent }
    for (actual, expected) in zip(value.roles, staffingRoles) {
      guard actual.roleKey == expected.roleKey, actual.function == expected.function,
        actual.allowedInputs == expected.allowedInputs, actual.outputBasis == expected.outputBasis,
        actual.prohibitedBasis == expected.prohibitedBasis
      else { throw Failure.invalidContent }
    }
  }

  private static func validateChallengeArchiveRoles(
    _ values: [ChallengeArchiveRole], declarations: [Declaration], calibration: Calibration
  ) throws {
    guard values.count == records.count, declarations.count == records.count,
      calibration.parameters.phaseOffsetsDegrees.count == records.count
    else { throw Failure.invalidContent }
    for (index, value) in values.enumerated() {
      let record = records[index]
      let declaration = declarations[index]
      guard value.sourceID == sourceID, value.contentRevision == archiveRolesRevision,
        value.challengeOrdinal == index,
        value.recordID == declaration.recordID, value.recordID == record.record,
        value.replicaID == declaration.replicaID, value.replicaID == record.replica,
        value.origin.identity == declaration.origin.identity, value.origin.identity == record.origin,
        value.origin.domain == declaration.origin.domain, value.origin.domain == record.domain,
        value.recordPayloadSHA256 == declarationPayloadSHA256[index],
        value.originalFactIDs == declaration.originalFacts.map(\.factID),
        value.originalFactIDs == [record.fact],
        value.sourceSetBinding.commit == originalCommit,
        value.sourceSetBinding.path == "docs/meridian/missions/definitions/unwritten-route.json",
        value.sourceSetBinding.selector == "requiredSources/requiredClueIDs; existing exact64Core mapping",
        value.sourceSetBinding.sha256 == "462d3446973aa45a7b31cf414931a3fed99a969f03f4919f4715e669e0b8176d",
        value.modelInput.resourcePath ==
          "Sources/L337Core/Resources/MissionPacks/native-unwritten-route/recovery-policy.json",
        value.modelInput.resourceSHA256 == calibrationSHA256,
        value.modelInput.profileSchema == "l337.c01.continuity-calibration-content/1",
        value.modelInput.jsonPointer ==
          "/profiles/l337.glass-meridian/continuityCalibration/parameters/phaseOffsetsDegrees/\(index)",
        value.modelInput.offsetDegrees == calibration.parameters.phaseOffsetsDegrees[index]
      else { throw Failure.invalidContent }
    }
  }

  private static func validateBinding(_ binding: SourceBinding) throws {
    guard binding.sourceID == sourceID, binding.clueID == "meridian-offset",
      binding.clueReceipt == "l337.unwritten-route/clue/meridian-offset",
      binding.originalDefinition.commit == originalCommit,
      binding.originalDefinition.path == originalPath,
      binding.originalDefinition.bytes == 32509,
      binding.originalDefinition.sha256 == originalSHA256,
      binding.recoveryProfileSelector.commit == originalCommit,
      binding.recoveryProfileSelector.path == "docs/meridian/missions/gameplay/recovery-policy.json",
      binding.recoveryProfileSelector.jsonPointer == "/profiles/l337.glass-meridian",
      binding.recoveryProfileSelector.sha256
        == "d9c50d192297e824dcd01796ba17c2c6f33b887ec9c2c9e52585e104c5d65e5b",
      binding.sourceSetBinding.commit == originalCommit,
      binding.sourceSetBinding.path == "docs/meridian/missions/definitions/unwritten-route.json",
      binding.sourceSetBinding.selector == "requiredSources/requiredClueIDs; existing exact64Core mapping",
      binding.sourceSetBinding.sha256
        == "462d3446973aa45a7b31cf414931a3fed99a969f03f4919f4715e669e0b8176d"
    else { throw Failure.invalidContent }
  }

  private static func validateDeclaration(
    _ value: Declaration, descriptor: RecordDescriptor, order: Int
  ) throws {
    guard value.recordID == descriptor.record, value.replicaID == descriptor.replica,
      value.origin.identity == descriptor.origin, value.origin.domain == descriptor.domain,
      ScriptPackLibrary.hash(Data(value.proposedStatement.utf8)) == descriptor.statementSHA256,
      ScriptPackLibrary.hash(Data(value.inputBasis.utf8)) == descriptor.inputBasisSHA256,
      value.nonPrivateScope ==
        "non-private source trace and calibration use only; no crew/recorder/personal case data",
      value.authoringClass == "PROSPECTIVE_NEW_FICTIONAL_SOURCE_DECLARATION",
      value.relativeChronology.kind == "source-relative-narrative-order",
      value.relativeChronology.order == order,
      value.relativeChronology.originStatus == "NEW_PROPOSED_CHRONOLOGY_NOT_PHYSICAL_TIME",
      value.relativeChronology.relation == "BEFORE_FIRST_SOURCE_OFFER",
      value.subjectWorld.galaxy == 0, value.subjectWorld.system == descriptor.system,
      value.subjectWorld.locationKey == descriptor.locationKey,
      value.subjectWorld.originalStageSelector == descriptor.stage,
      value.originalFacts.count == 1, let fact = value.originalFacts.first,
      fact.factID == descriptor.fact, fact.commit == originalCommit,
      fact.path == originalPath, fact.fileSHA256 == originalSHA256,
      fact.jsonPointer == descriptor.pointer, fact.characterSpanHalfOpen == descriptor.span,
      fact.fragmentUTF8SHA256 == descriptor.fragmentSHA256,
      ScriptPackLibrary.hash(Data(fact.fragment.utf8)) == descriptor.fragmentSHA256,
      fact.supports ==
        "Original narrative/content fact only; not an existing independently signed archive observation.",
      value.hiddenTraceReference.commit == originalCommit,
      value.hiddenTraceReference.path == originalPath,
      value.hiddenTraceReference.fileSHA256 == originalSHA256,
      value.hiddenTraceReference.jsonPointer == "/completionClue/journalText",
      value.hiddenTraceReference.contentSHA256 == traceSHA256,
      !value.hiddenTraceReference.visibleBeforeActualClueReceipt
    else { throw Failure.invalidContent }
  }

  private static func object(_ value: Any?, keys: [String]) throws -> [String: Any] {
    guard let object = value as? [String: Any], Set(object.keys) == Set(keys) else {
      throw Failure.invalidSchema
    }
    return object
  }

  private static func array(_ value: Any?) throws -> [Any] {
    guard let values = value as? [Any] else { throw Failure.invalidSchema }
    return values
  }

  private static func bindingShape(_ raw: Any?) throws {
    let binding = try object(raw, keys: ["sourceID", "clueID", "clueReceipt",
      "originalDefinition", "recoveryProfileSelector", "sourceSetBinding"])
    _ = try object(binding["originalDefinition"], keys: ["bytes", "commit", "path", "sha256"])
    _ = try object(binding["recoveryProfileSelector"], keys: ["commit", "jsonPointer", "path", "sha256"])
    _ = try object(binding["sourceSetBinding"], keys: ["commit", "path", "selector", "sha256"])
  }

  static func archiveShape(_ bytes: Data) throws {
    let root = try object(JSONSerialization.jsonObject(with: bytes),
      keys: ["schema", "publication", "contentScope", "sourceGroups"])
    let groups = try object(root["sourceGroups"], keys: [sourceID])
    let group = try object(groups[sourceID], keys: ["sourceBinding", "declarations",
      "institutionalServiceSource", "serviceStaffingPolicy", "challengeArchiveRoles"])
    try bindingShape(group["sourceBinding"])
    try institutionalServiceShape(group["institutionalServiceSource"])
    try staffingPolicyShape(group["serviceStaffingPolicy"])
    try challengeArchiveRolesShape(group["challengeArchiveRoles"])
    let declarations = try array(group["declarations"])
    guard declarations.count == records.count else { throw Failure.invalidSchema }
    for raw in declarations {
      let value = try object(raw, keys: ["recordID", "replicaID", "origin", "proposedStatement",
        "inputBasis", "nonPrivateScope", "relativeChronology", "subjectWorld", "originalFacts",
        "hiddenTraceReference", "authoringClass"])
      _ = try object(value["origin"], keys: ["identity", "domain"])
      _ = try object(value["relativeChronology"], keys: ["kind", "order", "originStatus", "relation"])
      _ = try object(value["subjectWorld"], keys: ["galaxy", "locationKey", "originalStageSelector", "system"])
      for fact in try array(value["originalFacts"]) {
        _ = try object(fact, keys: ["characterSpanHalfOpen", "commit", "factID", "fileSHA256",
          "fragment", "fragmentUTF8SHA256", "jsonPointer", "path", "supports"])
      }
      _ = try object(value["hiddenTraceReference"], keys: ["commit", "contentSHA256", "fileSHA256",
        "jsonPointer", "path", "visibleBeforeActualClueReceipt"])
    }
  }

  private static func institutionalServiceShape(_ raw: Any?) throws {
    let value = try object(raw, keys: [
      "definitionID",
      "definitionRevision",
      "definitionSHA256",
      "sourceBinding",
      "hostPolicy",
      "provenance",
      "subjectDefinitions",
      "initialDutyMapping",
      "activationLaw",
      "availabilityLifecycleRule",
      "staffingPolicyReference",
      "challengeArchiveRolesReference",
      "scopeRule",
    ])
    try bindingShape(value["sourceBinding"])
    for reference in try array(value["provenance"]) {
      _ = try object(reference, keys: [
        "commit",
        "path",
        "fileSHA256",
        "jsonPointer",
        "fragmentBytes",
        "fragmentSHA256",
      ])
    }
    for subject in try array(value["subjectDefinitions"]) {
      _ = try object(subject, keys: ["definitionKey", "ordinal"])
    }
    for duty in try array(value["initialDutyMapping"]) {
      _ = try object(duty, keys: ["roleKey", "subjectDefinitionKey"])
    }
    _ = try object(value["staffingPolicyReference"], keys: ["identity", "revision", "sha256"])
    _ = try object(value["challengeArchiveRolesReference"], keys: ["identity", "revision", "sha256"])
  }

  private static func staffingPolicyShape(_ raw: Any?) throws {
    let value = try object(raw, keys: [
      "policyID",
      "policyRevision",
      "policySHA256",
      "institutionalDefinitionID",
      "institutionalDefinitionRevision",
      "roles",
      "requiredAssignmentProof",
      "reviewInputBasis",
    ])
    for role in try array(value["roles"]) {
      let policy = try object(role, keys: ["roleKey", "function", "allowedInputs", "outputBasis", "prohibitedBasis"])
      _ = try array(policy["allowedInputs"])
      _ = try array(policy["prohibitedBasis"])
    }
  }

  private static func challengeArchiveRolesShape(_ raw: Any?) throws {
    for role in try array(raw) {
      let value = try object(role, keys: [
        "sourceID",
        "contentRevision",
        "challengeOrdinal",
        "recordID",
        "replicaID",
        "origin",
        "recordPayloadSHA256",
        "originalFactIDs",
        "modelInput",
        "sourceSetBinding",
      ])
      _ = try object(value["origin"], keys: ["identity", "domain"])
      _ = try array(value["originalFactIDs"])
      _ = try object(value["modelInput"], keys: ["resourcePath", "resourceSHA256", "profileSchema", "jsonPointer", "offsetDegrees"])
      _ = try object(value["sourceSetBinding"], keys: ["commit", "path", "selector", "sha256"])
    }
  }

  static func calibrationShape(_ bytes: Data) throws {
    let root = try object(JSONSerialization.jsonObject(with: bytes),
      keys: ["schema", "publication", "contentScope", "sourcePins", "profiles"])
    try bindingShape(root["sourcePins"])
    let profiles = try object(root["profiles"], keys: [sourceID])
    let group = try object(profiles[sourceID], keys: ["continuityCalibration"])
    let profile = try object(group["continuityCalibration"], keys: ["adaptation", "aimDegrees",
      "benchAcceptance", "dwellSeconds", "independence", "mechanic", "observations",
      "parameterStatus", "parameters", "referenceFrame", "sourceModelRequirement", "surfaceRangeNativeUnits"])
    _ = try object(profile["parameters"], keys: ["phaseOffsetsDegrees", "sampleCycles", "toleranceDegrees"])
  }
}


extension NativeC01CharterArchiveApproval {
  /// Exact published resource identity for the human-approved fictional content.
  private struct PublishedContentDescriptor: Sendable {
    let revision: String
    let archiveBytes: Int
    let archiveSHA256: String
    let calibrationBytes: Int
    let calibrationSHA256: String
    let institutionalDefinitionSHA256: String
    let staffingPolicySHA256: String
    let archiveRolesSHA256: String
  }
  private static let publishedContentDescriptor = PublishedContentDescriptor(
    revision: "c01-charter-institutional-published-v4",
    archiveBytes: 22201, archiveSHA256: "131fec20b046881742ae3b76ef6e69bf64ca9caad65482267dbf6417ffebb26a",
    calibrationBytes: 3023, calibrationSHA256: "35fe099defefccbd7d5c917e156e36de95240079536325c88c4f56468c98ea04",
    institutionalDefinitionSHA256: institutionalDefinitionSHA256,
    staffingPolicySHA256: staffingPolicySHA256, archiveRolesSHA256: archiveRolesSHA256)
}
