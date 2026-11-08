import Foundation

/// Source preparation bookkeeping only. G1 owns the real cumulative allowance
/// and links each actual result/failure once. None of these values admits a
/// body, certifies physical clearance or replaces original construction work.
enum NativeC01InquiryPreparationWork {
  typealias G = NativeC01InquiryCurveGeometry

  enum Phase: Int, Sendable, CaseIterable {
    case control, sourceMass, sourceRepresentation, atlas, materialView
    case hullInput, welding, triangulation, components, bvh, bvhComparison, metadata
    case curveSetup
  }
  struct PhaseCount: Sendable {
    let phase: Phase
    let records: Int
    let nodes: Int
  }
  struct Report: Sendable {
    let queries: Int
    let triangles: Int
    let nodes: Int
    let phases: [PhaseCount]

    fileprivate init(queries: Int, triangles: Int, nodes: Int, phases: [PhaseCount]) {
      self.queries = queries; self.triangles = triangles; self.nodes = nodes
      self.phases = phases
    }
  }
  enum Failure: Error, Sendable {
    case allowance
    case invalidSource
    case native(HullSweepFailure)
    case solver(NativeC01InquiryCompoundValidatedCurve.Failure)
    case unproven
  }
  enum Outcome<Value: Sendable>: Sendable {
    case prepared(Value, Report)
    case refused(Failure, Report)
  }

  /// Deliberately synchronous and non-Sendable. No global mutable preparation
  /// owner, escaping async callback, new unchecked conformance or live receipt.
  final class Meter {
    var work: G.Work
    private let initialQueries: Int
    private let initialTriangles: Int
    private let initialNodes: Int
    private var phaseRecords = Array(repeating: 0, count: Phase.allCases.count)
    private var phaseNodes = Array(repeating: 0, count: Phase.allCases.count)

    init(work: G.Work) {
      self.work = work
      initialQueries = work.queries; initialTriangles = work.triangles; initialNodes = work.nodes
    }

    /// One unit is a source processing record/predicate, not a CPU instruction.
    /// Variable traversals and native comparator invocations pay BEFORE work.
    func records(_ count: Int, _ phase: Phase) throws {
      try work.reservePreparedMetadataRecords(count)
      phaseRecords[phase.rawValue] += count
    }

    func node(_ phase: Phase) throws {
      try work.node()
      phaseNodes[phase.rawValue] += 1
    }

    var report: Report {
      .init(queries: work.queries - initialQueries, triangles: work.triangles - initialTriangles,
        nodes: work.nodes - initialNodes, phases: Phase.allCases.map { phase in
          .init(phase: phase, records: phaseRecords[phase.rawValue], nodes: phaseNodes[phase.rawValue])
        })
    }
  }

  /// The same caller ledger receives all progress, including failed native
  /// preparation. The operation must use this meter for its actual traversals;
  /// this wrapper alone cannot pay work that happened before it was called.
  static func perform<Value: Sendable>(work: inout G.Work,
    _ operation: (Meter) throws -> Value) -> Outcome<Value>
  {
    // Charge bounded entry bookkeeping before allocating the meter/phase list.
    do { try work.node() }
    catch {
      return .refused(.allowance, .init(queries: 0, triangles: 0, nodes: 0, phases: []))
    }
    let meter = Meter(work: work)
    defer { work = meter.work }
    func report() -> Report {
      let measured = meter.report
      // Meter starts after the already-charged entry node; include it once.
      return .init(queries: measured.queries, triangles: measured.triangles,
        nodes: measured.nodes + 1, phases: measured.phases.map { phase in
          .init(phase: phase.phase, records: phase.records,
            nodes: phase.nodes + (phase.phase == .control ? 1 : 0))
        })
    }
    do { return .prepared(try operation(meter), report()) }
    catch G.Failure.workBudgetExceeded { return .refused(.allowance, report()) }
    catch let failure as HullSweepFailure { return .refused(.native(failure), report()) }
    catch let failure as NativeC01InquiryCompoundValidatedCurve.Failure { return .refused(.solver(failure), report()) }
    catch let failure as Failure { return .refused(failure, report()) }
    catch { return .refused(.unproven, report()) }
  }
}
