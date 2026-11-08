/// Explicit NEW C01 coupled-producer prescription, not an inference from native
/// body velocity, absent NPCs or canonical spin. These are conditional C1 field
/// inputs only. They cannot admit a body or qualify a native time window.
enum NativeC01InquiryPassiveFixtureForceLaw {
  typealias Solver = NativeC01InquiryCompoundValidatedCurve
  typealias G = NativeC01InquiryCurveGeometry
  typealias P = NativeC01InquiryPreparationWork
  typealias Contact = NativeC01InquiryCutContactSet

  enum Prescription: Sendable {
    /// COM evolves under the coupled field: no imposed fixed angular velocity
    /// or model-origin trajectory. Contact reactions are added by Contact.
    case coupledPassiveCOM
  }

  static let revision = "c01-coupled-passive-com-external-law-v1"

  struct ConditionalField: Sendable {
    let prescription: Prescription
    let revision: String
    /// Component order is q4/C3/P3/L3, followed by one explicit time variable.
    let stateDomain: [Solver.Interval]
    let absoluteTimeRange: Solver.Interval
    let componentCount: Int
    let variableCount: Int
    /// Per body WORLD F3, WORLD torque ABOUT THE CURRENT COM3.
    let externalRanges: [Contact.ExternalWrench]
    /// Row-major (6*m) by (13*m+1), including the explicit time column.
    let externalJacobian: [Solver.Interval]

    fileprivate init(prescription: Prescription, domain: [Solver.Interval],
      time: Solver.Interval, components: Int, ranges: [Contact.ExternalWrench],
      jacobian: [Solver.Interval])
    {
      self.prescription = prescription; revision = NativeC01InquiryPassiveFixtureForceLaw.revision
      stateDomain = domain; absoluteTimeRange = time; componentCount = components
      variableCount = domain.count + 1; externalRanges = ranges; externalJacobian = jacobian
    }
  }

  /// The authored passive law is the SAME constant function over the WHOLE
  /// supplied B x T. Exact zero derivatives follow from this prescription,
  /// not finite differences or a sampled state. Native ownership, complete
  /// source lifetime and event absence are deliberately not established here.
  static func prepareConditionalField(prescription: Prescription,
    stateDomain: [Solver.Interval], absoluteTimeRange: Solver.Interval, work: inout G.Work
  ) -> P.Outcome<ConditionalField> {
    P.perform(work: &work) { meter in
      try meter.records(2, .metadata)
      guard (13...52).contains(stateDomain.count), stateDomain.count % 13 == 0,
        absoluteTimeRange.valid, absoluteTimeRange.lower >= 0
      else { throw P.Failure.invalidSource }
      try meter.records(stateDomain.count, .metadata)
      guard stateDomain.allSatisfy(\.valid) else { throw P.Failure.invalidSource }
      let components = stateDomain.count / 13
      let variables = stateDomain.count + 1
      let jacobianRecords = 6 * components * variables
      // All dimensions are bounded above before multiplication/allocation.
      try meter.records(jacobianRecords + 6 * components + 1, .metadata)
      let zero = Solver.VectorBox.point(.init(0, 0, 0))
      let ranges = Array(repeating: Contact.ExternalWrench(worldForce: zero,
        worldTorqueAtCOM: zero), count: components)
      let jacobian = Array(repeating: Solver.Interval.point(0), count: jacobianRecords)
      return .init(prescription: prescription, domain: stateDomain, time: absoluteTimeRange,
        components: components, ranges: ranges, jacobian: jacobian)
    }
  }
}
