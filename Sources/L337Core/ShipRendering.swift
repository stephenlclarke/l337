import Foundation

public enum ShipDisplayStyle: String, Codable, Sendable, CaseIterable {
  case whiteWireframe, colourWireframe, shadedPanels

  public var next: Self {
    switch self {
    case .whiteWireframe: .colourWireframe
    case .colourWireframe: .shadedPanels
    case .shadedPanels: .whiteWireframe
    }
  }
  public var label: String {
    switch self {
    case .whiteWireframe: "WHITE WIREFRAME"
    case .colourWireframe: "COLOUR WIREFRAME"
    case .shadedPanels: "SHADED PANELS"
    }
  }
}

public struct ScreenPoint: Sendable, Equatable {
  public let x: Double
  public let y: Double
  public init(_ x: Double, _ y: Double) {
    self.x = x
    self.y = y
  }
}

public struct ShipPanel: Sendable, Equatable {
  public let vertices: [ScreenPoint]
  public let colour: UInt32
  public let isOpticalPane: Bool
  public let opticalAperture: [ScreenPoint]?

  init(vertices: [ScreenPoint], colour: UInt32, isOpticalPane: Bool = false,
    opticalAperture: [ScreenPoint]? = nil)
  {
    self.vertices = vertices
    self.colour = colour
    self.isOpticalPane = isOpticalPane
    self.opticalAperture = opticalAperture
  }
}

extension Hull {
  public var ink: Ink {
    switch self {
    case .cobra, .constrictor: .cyan
    case .viper: .blue
    case .sidewinder, .cargo: .yellow
    case .asteroid: .orange
    case .station: .blue
    case .missile: .red
    case .thargoid, .thargon: .green
    }
  }
}

enum ShipProjection {
  static func shade(_ ink: Ink, normal: Vector3) -> UInt32 {
    shade(ink.rawValue, normal: normal)
  }

  static func shade(_ rgba: UInt32, normal: Vector3, emissive: Bool = false) -> UInt32 {
    if emissive { return rgba }
    let light = Vector3(-0.4, 0.6, -1)
    let brightness = 0.25 + 0.75 * max(0, normal.dot(light) / (normal.length * light.length))
    let r = UInt32(Double((rgba >> 24) & 255) * brightness)
    let g = UInt32(Double((rgba >> 16) & 255) * brightness)
    let b = UInt32(Double((rgba >> 8) & 255) * brightness)
    return r << 24 | g << 16 | b << 8 | 255
  }

  /// Faces in front of or on the near plane need only their final screen points.
  static func polygon(
    _ face: [Int], vertices: [Vector3], projection: FlightProjection = .legacy
  ) -> [ScreenPoint] {
    guard !face.isEmpty, face.allSatisfy({ vertices[$0].z >= 1 }) else {
      return polygon(face.map { vertices[$0] }, projection: projection)
    }
    let points = face.map { projection.point(vertices[$0]) }
    return points.allSatisfy { $0.x.isFinite && $0.y.isFinite } ? points : []
  }

  static func polygon(_ vertices: [Vector3], projection: FlightProjection = .legacy)
    -> [ScreenPoint]
  {
    guard var previous = vertices.last else { return [] }
    var clipped: [Vector3] = []
    for current in vertices {
      if (current.z >= 1) != (previous.z >= 1) {
        clipped.append(
          previous + (current - previous) * ((1 - previous.z) / (current.z - previous.z)))
      }
      if current.z >= 1 { clipped.append(current) }
      previous = current
    }
    let points = clipped.map { projection.point($0) }
    return points.allSatisfy { $0.x.isFinite && $0.y.isFinite } ? points : []
  }
}

extension Frame {
  /// Ship surfaces visible to the renderer, excluding HUD graphics and offscreen texture faces.
  public var hasShipSurfaces: Bool {
    worldGraphics.contains(where: visibleShipSurface)
      || graphics.contains(where: visibleShipSurface)
  }

  private func visibleShipSurface(_ graphic: Graphic) -> Bool {
    switch graphic {
    case .panel: return true
    case .textured(let triangle):
      guard triangle.vertices.count == 3,
        triangle.vertices.allSatisfy(ShipTextureRaster.validVertex),
        ShipTextureRaster.validClip(triangle.clip), ShipTextureRaster.validClip(flightClip),
        triangle.brightness.isFinite, (0...1).contains(triangle.brightness),
        ShipTextureAssets.pixels(for: triangle.texture) != nil
      else { return false }
      let left = max(triangle.clip.x, flightClip.x)
      let top = max(triangle.clip.y, flightClip.y)
      let right = min(triangle.clip.maxX, flightClip.maxX)
      let bottom = min(triangle.clip.maxY, flightClip.maxY)
      guard left < right, top < bottom else { return false }
      var clipped = triangle.vertices.map(\.point)
      clipped = Self.clipPolygon(clipped, axis: \.x, limit: left, above: true)
      clipped = Self.clipPolygon(clipped, axis: \.x, limit: right, above: false)
      clipped = Self.clipPolygon(clipped, axis: \.y, limit: top, above: true)
      clipped = Self.clipPolygon(clipped, axis: \.y, limit: bottom, above: false)
      guard clipped.count >= 3 else { return false }
      // A bounding-box intersection alone can accept a face lying outside a viewport corner.
      let origin = clipped[0]
      let area = (1..<(clipped.count - 1)).reduce(0.0) { sum, index in
        let a = clipped[index]
        let b = clipped[index + 1]
        return sum + (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x)
      }
      return abs(area) > 1e-12
    default: return false
    }
  }

  public mutating func textured(_ triangle: ShipTexturedTriangle) {
    graphics.append(.textured(triangle))
    guard rasterizeGraphics, let texture = ShipTextureAssets.pixels(for: triangle.texture),
      ShipTextureRaster.validClip(triangle.clip), ShipTextureRaster.validClip(flightClip)
    else { return }
    let leftEdge = max(0, triangle.clip.x, flightClip.x)
    let topEdge = max(0, triangle.clip.y, flightClip.y)
    let rightEdge = min(Double(Self.width), triangle.clip.maxX, flightClip.maxX)
    let bottomEdge = min(Double(Self.height), triangle.clip.maxY, flightClip.maxY)
    guard rightEdge > leftEdge, bottomEdge > topEdge else { return }
    let bounded = ShipTexturedTriangle(
      vertices: triangle.vertices, texture: triangle.texture, brightness: triangle.brightness,
      clip: .init(
        x: leftEdge, y: topEdge, width: rightEdge - leftEdge, height: bottomEdge - topEdge),
      appearance: triangle.appearance)
    guard let tile = ShipTextureRaster.tile(triangle: bounded, pixels: texture)
    else { return }
    let left = Int(tile.origin.x.rounded())
    let top = Int(tile.origin.y.rounded())
    for y in 0..<tile.height {
      for x in 0..<tile.width {
        let colour = tile.rgba[y * tile.width + x]
        let column = left + x
        let row = top + y
        if colour & 255 != 0, (0..<Self.width).contains(column), (0..<Self.width).contains(row) {
          pixels[row * Self.width + column] = colour
        }
      }
    }
  }

  public mutating func panel(_ vertices: [ScreenPoint], colour: UInt32) {
    panel(vertices, colour: colour, isOpticalPane: false)
  }

  mutating func panel(_ vertices: [ScreenPoint], colour: UInt32, isOpticalPane: Bool,
    opticalAperture: [ScreenPoint]? = nil)
  {
    guard vertices.count >= 3, vertices.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
      return
    }
    var clipped = vertices
    // The rotating startup ship is wholly framed inside this exact inclusive clip.
    // Retain its vertices directly; crossing polygons use the original clipping path.
    if !vertices.allSatisfy({
      $0.x >= flightClip.x && $0.x <= flightClip.maxX - 1
        && $0.y >= flightClip.y && $0.y <= flightClip.maxY - 1
    }) {
      clipped = Self.clipPolygon(clipped, axis: \.x, limit: flightClip.x, above: true)
      clipped = Self.clipPolygon(clipped, axis: \.x, limit: flightClip.maxX - 1, above: false)
      clipped = Self.clipPolygon(clipped, axis: \.y, limit: flightClip.y, above: true)
      clipped = Self.clipPolygon(clipped, axis: \.y, limit: flightClip.maxY - 1, above: false)
    }
    guard clipped.count >= 3 else { return }
    graphics.append(.panel(ShipPanel(vertices: clipped, colour: colour, isOpticalPane: isOpticalPane,
      opticalAperture: opticalAperture)))
    if rasterizeGraphics {
      let fill = opticalAperture.map { Self.clipPanel(clipped, to: $0) } ?? clipped
      if fill.count >= 3 { fillPanel(fill, colour: colour, isOpticalPane: isOpticalPane) }
    }
  }

  private static func clipPanel(_ vertices: [ScreenPoint], to aperture: [ScreenPoint]) -> [ScreenPoint] {
    guard aperture.count >= 3 else { return [] }
    let area = aperture.indices.reduce(0.0) { total, i in
      let a = aperture[i], b = aperture[(i + 1) % aperture.count]
      return total + a.x * b.y - a.y * b.x
    }
    guard area != 0 else { return [] }
    var clipped = vertices
    for i in aperture.indices {
      let a = aperture[i], b = aperture[(i + 1) % aperture.count]
      func distance(_ p: ScreenPoint) -> Double {
        let value = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
        return area > 0 ? value : -value
      }
      guard var previous = clipped.last else { break }
      var start = distance(previous)
      var next: [ScreenPoint] = []
      for current in clipped {
        let end = distance(current)
        if (start >= 0) != (end >= 0) {
          let t = start / (start - end)
          next.append(.init(previous.x + t * (current.x - previous.x),
            previous.y + t * (current.y - previous.y)))
        }
        if end >= 0 { next.append(current) }
        previous = current
        start = end
      }
      clipped = next
    }
    return clipped
  }

  private static func clipPolygon(
    _ vertices: [ScreenPoint], axis: KeyPath<ScreenPoint, Double>, limit: Double, above: Bool
  ) -> [ScreenPoint] {
    guard var previous = vertices.last else { return [] }
    var result: [ScreenPoint] = []
    for current in vertices {
      let start = previous[keyPath: axis]
      let end = current[keyPath: axis]
      let startInside = above ? start >= limit : start <= limit
      let endInside = above ? end >= limit : end <= limit
      if startInside != endInside {
        let t = (limit - start) / (end - start)
        result.append(
          ScreenPoint(
            previous.x + t * (current.x - previous.x), previous.y + t * (current.y - previous.y)))
      }
      if endInside { result.append(current) }
      previous = current
    }
    return result
  }

  private mutating func fillPanel(_ vertices: [ScreenPoint], colour: UInt32, isOpticalPane: Bool) {
    let low = max(0, Int(vertices.map(\.y).min() ?? 12))
    let high = min(Self.height - 1, Int(vertices.map(\.y).max() ?? 175))
    guard low <= high else { return }
    for y in low...high {
      let row = Double(y) + 0.5
      var crossings: [Double] = []
      for index in vertices.indices {
        let a = vertices[index]
        let b = vertices[(index + 1) % vertices.count]
        if (a.y <= row && b.y > row) || (b.y <= row && a.y > row) {
          crossings.append(a.x + (row - a.y) * (b.x - a.x) / (b.y - a.y))
        }
      }
      guard let left = crossings.min(), let right = crossings.max() else { continue }
      let first = max(0, Int(ceil(left - 0.5)))
      // Shared pane edges belong to only one triangle at a sample center.
      let rightSample = isOpticalPane ? ceil(right - 0.5) - 1 : floor(right - 0.5)
      let last = min(255, Int(rightSample))
      guard first <= last else { continue }
      for x in first...last {
        let index = y * Self.width + x
        pixels[index] = isOpticalPane ? Self.opticalBlend(colour, over: pixels[index]) : colour
      }
    }
  }

  private static func opticalBlend(_ source: UInt32, over destination: UInt32) -> UInt32 {
    let sourceAlpha = source & 255
    let foregroundWeight = sourceAlpha * 255
    let backgroundWeight = (destination & 255) * (255 - sourceAlpha)
    let total = foregroundWeight + backgroundWeight
    guard total > 0 else { return 0 }
    func channel(_ shift: UInt32) -> UInt32 {
      let foreground = (source >> shift) & 255
      let background = (destination >> shift) & 255
      return (foreground * foregroundWeight + background * backgroundWeight + total / 2) / total
    }
    return channel(24) << 24 | channel(16) << 16 | channel(8) << 8 | (total + 127) / 255
  }
}
