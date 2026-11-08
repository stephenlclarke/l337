import Foundation

extension BisonColdLoopCandidate {
  /// Signed local solid primitives. The source supplies moments; the consumer
  /// neither integrates these shapes nor turns their unit-density volume into stock.
  struct MechanismPrimitive: Decodable, Sendable {
    enum Shape: Sendable {
      case box(dimensions: [Double])
      case sector(inner: Double, outer: Double, z0: Double, z1: Double, a: Double, b: Double)
    }
    let centre: [Double]
    let rotation: [[Double]]
    let sign: Int
    let shape: Shape

    private enum CodingKeys: String, CodingKey {
      case kind, centre, rotation, sign, dimensions, inner, outer, z0, z1, a, b
    }
    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      centre = try values.decode([Double].self, forKey: .centre)
      rotation = try values.decode([[Double]].self, forKey: .rotation)
      sign = try values.decode(Int.self, forKey: .sign)
      switch try values.decode(String.self, forKey: .kind) {
      case "box": shape = .box(dimensions: try values.decode([Double].self, forKey: .dimensions))
      case "sector":
        shape = try .sector(inner: values.decode(Double.self, forKey: .inner),
          outer: values.decode(Double.self, forKey: .outer), z0: values.decode(Double.self, forKey: .z0),
          z1: values.decode(Double.self, forKey: .z1), a: values.decode(Double.self, forKey: .a),
          b: values.decode(Double.self, forKey: .b))
      default:
        throw DecodingError.dataCorruptedError(forKey: .kind, in: values, debugDescription: "Unknown proposed primitive")
      }
    }
  }

  struct MechanismPart: Decodable, Sendable {
    let domain: String
    let geometricVolumeCubicMetres: Double
    let group: String
    let id: String
    let materialOrJointQualified: Bool
    let physical: BisonCommissioningCandidateV3.SourceMassState
    let proposedEffectiveDensityKgPerCubicMetre: Double
    let terms: [MechanismPrimitive]
  }

  struct MechanismAssembly: Decodable, Sendable {
    enum Cavity: Sendable {
      case cylinder(radius: Double, terms: [MechanismPrimitive])
      case square(side: Double, boxes: [BisonBedFeedCandidateV4.Results.Layout.Box])
    }
    let id: String
    let allDry: BisonCommissioningCandidateV3.SourceMassState
    let assemblyCentreMetres: [Double]
    let cavityLengthMetres: Double
    let cavity: Cavity
    let dryVoidTerms: [MechanismPrimitive]
    let fluid: ConnectedAssembly.GeometricMoments
    let fluidBase: ConnectedAssembly.GeometricMoments
    let housing: BisonCommissioningCandidateV3.SourceMassState
    let housingGeometry: ConnectedAssembly.GeometricMoments
    let housingProposedEffectiveDensityKgPerCubicMetre: Double
    let outer: BisonBedFeedCandidateV4.Results.Layout.Box
    let outerDimensionsMetres: [Double]
    let parts: [MechanismPart]
    let referenceAngleRadians: Double
    let unobservedDryVoid: ConnectedAssembly.GeometricMoments?

    private enum CodingKeys: String, CodingKey {
      case id, allDry, assemblyCentreMetres, cavityLengthMetres, cavityCylinderRadiusMetres, cavitySquareMetres
      case dryVoidTerms, fluid, fluidBase, fluidBaseTerms, fluidBaseBoxes, housing, housingGeometry
      case housingProposedEffectiveDensityKgPerCubicMetre, outer, outerDimensionsMetres, parts
      case referenceAngleRadians, unobservedDryVoid
    }
    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      let assemblyID = try values.decode(String.self, forKey: .id)
      id = assemblyID
      allDry = try values.decode(BisonCommissioningCandidateV3.SourceMassState.self, forKey: .allDry)
      assemblyCentreMetres = try values.decode([Double].self, forKey: .assemblyCentreMetres)
      cavityLengthMetres = try values.decode(Double.self, forKey: .cavityLengthMetres)
      switch assemblyID {
      case "pump":
        cavity = try .cylinder(radius: values.decode(Double.self, forKey: .cavityCylinderRadiusMetres),
          terms: values.decode([MechanismPrimitive].self, forKey: .fluidBaseTerms))
      case "valve":
        cavity = try .square(side: values.decode(Double.self, forKey: .cavitySquareMetres),
          boxes: values.decode([BisonBedFeedCandidateV4.Results.Layout.Box].self, forKey: .fluidBaseBoxes))
      default:
        throw DecodingError.dataCorruptedError(forKey: .id, in: values, debugDescription: "Unknown proposed assembly")
      }
      dryVoidTerms = try values.decode([MechanismPrimitive].self, forKey: .dryVoidTerms)
      fluid = try values.decode(ConnectedAssembly.GeometricMoments.self, forKey: .fluid)
      fluidBase = try values.decode(ConnectedAssembly.GeometricMoments.self, forKey: .fluidBase)
      housing = try values.decode(BisonCommissioningCandidateV3.SourceMassState.self, forKey: .housing)
      housingGeometry = try values.decode(ConnectedAssembly.GeometricMoments.self, forKey: .housingGeometry)
      housingProposedEffectiveDensityKgPerCubicMetre = try values.decode(Double.self, forKey: .housingProposedEffectiveDensityKgPerCubicMetre)
      outer = try values.decode(BisonBedFeedCandidateV4.Results.Layout.Box.self, forKey: .outer)
      outerDimensionsMetres = try values.decode([Double].self, forKey: .outerDimensionsMetres)
      parts = try values.decode([MechanismPart].self, forKey: .parts)
      referenceAngleRadians = try values.decode(Double.self, forKey: .referenceAngleRadians)
      unobservedDryVoid = try values.decodeIfPresent(ConnectedAssembly.GeometricMoments.self, forKey: .unobservedDryVoid)
    }
  }

  struct MechanismConfiguration: Decodable, Sendable {
    let actualMotionOrRestObserved: Bool
    let dry: BisonCommissioningCandidateV3.SourceMassState
    let gateAngleRadians: Double
    let portableStates: [BisonCommissioningCandidateV3.SourceMassState]
    let pumpAngleRadians: Double
    let wallRefittedAtThisAngle: Bool
  }

  struct MechanismClearance: Decodable, Sendable {
    let coldToleranceOrMaterialQualified: Bool
    let id: String
    let minimumNominalMetres: Double
  }

  struct MovingBodyReferences: Decodable, Sendable {
    struct Configuration: Decodable, Sendable {
      struct Body: Decodable, Sendable {
        let actualMotionStateObserved: Bool
        let centreMetres: [Double]
        let explicitVelocitySpinAndFluidExcessEnergyRequired: Bool
        let id: String
        let inertiaAboutCentreOfMassKgM2: [Double]
        let jointOriginInSourceMetres: [Double]
        let massKg: Double
        let poseAngleRadians: Double
        let positiveCoordinateAxisInSourceFrame: [Double]
        let primitivePartIDs: [String]
      }
      let gateAngleRadians: Double
      let movingRigidBodies: [Body]
      let pumpAngleRadians: Double
      let wallRefittedAtThisAngle: Bool
    }
    let actualObservations: [String]
    let configurations: [Configuration]
    let scope: String
  }
}
