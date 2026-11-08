import Foundation

/// Read-only current module facts. This value grants no fitting, recharge or payment authority.
public struct EMPModuleBankReadout: Sendable, Equatable {
  public let moduleID: UUID
  public let fitted: Bool
  public let remaining: Double
  public let capacity: Double
  public let storedShots: Int
  public let powerGrade: Int
  public let capacityGrade: Int
  public let rechargeGrade: Int
  public let ratedRecharge: Double

  fileprivate init?(_ item: OwnedEquipmentItem) {
    guard item.node == EMPModuleGradePolicy.node, item.empBankValid,
      let bank = item.empBank, let grades = item.empGrades,
      let shots = bank.availableShots(cost: EMPModuleGradePolicy.pulseCost)
    else { return nil }
    moduleID = item.id
    fitted = item.location != nil
    remaining = bank.remaining
    capacity = bank.capacity
    storedShots = shots
    powerGrade = grades.power
    capacityGrade = grades.capacity
    rechargeGrade = grades.recharge
    ratedRecharge = EMPModuleGradePolicy.rechargeRates[grades.recharge]
  }

  public var bankLine: String {
    "EMP STORED: " + String(format: "%.1f / %.1f (%d shots)", remaining, capacity, storedShots)
  }

  public var rechargeLine: String {
    "EMP RATED RECHARGE: " + String(format: "%.1f /S", ratedRecharge)
  }
}

public enum EMPModuleShopAction: Sendable {
  case choose(UUID)
  case purchase(EMPModulePurchaseContext)
  case disabled(String)
  case page(Int)
  case back
}

public struct EMPModuleShopControl: Sendable {
  public let bounds: CanvasRect
  public let label: String
  public let action: EMPModuleShopAction
}

/// One painted view owns at most three opaque quotes, all for the visibly selected UUID.
/// Contexts stay outside Frame so the ordinary renderer retains its value semantics.
public final class EMPModuleUpgradePresentation: Sendable {
  public let frame: Frame
  public let controls: [EMPModuleShopControl]
  public let selectedModule: UUID?
  public let visibleModule: UUID?
  public let page: Int
  public let focus: Int
  public let bank: EMPModuleBankReadout?
  private let commander: Commander
  private let epoch: InventoryContextEpoch
  private let selection: Int
  private let mount: LaserMount
  private let workTool: Bool
  private let docked: Bool
  private let paused: Bool

  public func isCurrent(in game: Game) -> Bool {
    game.commander == commander && game.inventoryContextEpoch == epoch
      && game.selection == selection && game.equipmentMount == mount
      && game.equipmentWorkTool == workTool && game.docked == docked
      && game.paused == paused && game.empModuleManagementAvailable
  }

  public func action(at point: ScreenPoint) -> EMPModuleShopAction? {
    controls.first { $0.bounds.contains(point) }?.action
  }

  fileprivate init(
    game: Game, selected: UUID?, page requestedPage: Int, focus requestedFocus: Int,
    notice: String?, busy: Bool, width: Double, height: Double
  ) {
    commander = game.commander
    epoch = game.inventoryContextEpoch
    selection = game.selection
    mount = game.equipmentMount
    workTool = game.equipmentWorkTool
    docked = game.docked
    paused = game.paused
    let modules = game.empModuleBankReadouts.sorted {
      $0.moduleID.uuidString < $1.moduleID.uuidString
    }
    let visiblePage = max(0, min(requestedPage, max(0, modules.count - 1)))
    let visibleID = modules.indices.contains(visiblePage) ? modules[visiblePage].moduleID : nil
    let chosen = modules.count == 1 ? modules.first?.moduleID
      : (selected == visibleID ? selected : nil)
    selectedModule = chosen
    let chosenBank = modules.first { $0.moduleID == chosen }
    bank = chosenBank
    page = visiblePage
    visibleModule = visibleID
    let canvasWidth = width.isFinite ? max(0, width) : 0
    let canvasHeight = height.isFinite ? max(0, height) : 0
    var painted = Frame()
    painted.responsive = true
    painted.rasterizeGraphics = false
    painted.canvas = CanvasRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)
    let font = canvasWidth < 600 || canvasHeight < 420 ? 1.0 : min(2, GameTypography.scale)
    let line = ceil(font * 7) + 5
    let left = 12.0
    let available = max(0, canvasWidth - left * 2)
    var buttons: [EMPModuleShopControl] = []
    let expectedCount = canvasWidth >= 260 && canvasHeight >= 244
      ? (visibleID == nil ? 4 : modules.count > 1 ? 6 : 5)
      : (canvasWidth >= 120 && canvasHeight >= 48 ? 1 : 0)
    let paintedFocus = max(0, min(requestedFocus, max(0, expectedCount - 1)))
    func clipped(_ text: String) -> String {
      String(text.prefix(max(0, Int(min(160, (available - 12) / (6 * font))))))
    }
    func button(_ label: String, _ detail: String?, y: Double, action: EMPModuleShopAction) {
      let h = detail == nil ? line + 6 : line * 2 + 4
      let rect = CanvasRect(x: left, y: y, width: available, height: h)
      guard rect.width >= 24, rect.y >= 0, rect.maxY <= canvasHeight - 4 else { return }
      let active = buttons.count == paintedFocus
      let ink: Ink = active ? .yellow : .cyan
      painted.stroke(rect.x, rect.y, rect.maxX, rect.y, ink)
      painted.stroke(rect.x, rect.maxY, rect.maxX, rect.maxY, ink)
      painted.label(clipped(label), rect.x + 6, rect.y + 3, scale: font, ink: ink)
      if let detail {
        painted.label(clipped(detail), rect.x + 6, rect.y + line + 3, scale: font, ink: .white)
      }
      buttons.append(.init(bounds: rect, label: label, action: action))
    }
    if canvasWidth >= 260, canvasHeight >= 244 {
      painted.label("MANAGE EMP", left, 8, scale: font, ink: .yellow)
      let moduleY = 8 + line + 5
      if let visible = modules.indices.contains(visiblePage) ? modules[visiblePage] : nil {
        let state = visible.fitted ? "FITTED" : "STORED"
        button(visible.moduleID.uuidString,
          "\(state) - \(chosen == visible.moduleID ? "SELECTED" : "CHOOSE MODULE")",
          y: moduleY, action: .choose(visible.moduleID))
      }
      let pageY = moduleY + line * 2 + 8
      if modules.count > 1 {
        button("MODULE \(visiblePage + 1)/\(modules.count) - NEXT", nil, y: pageY,
          action: .page((visiblePage + 1) % modules.count))
      }
      let bankY = pageY + line + 10
      painted.label(clipped(chosenBank?.bankLine ?? "CHOOSE MODULE BEFORE BUYING"), left, bankY,
        scale: font, ink: .white)
      let grades = chosenBank.map {
        "P\($0.powerGrade) C\($0.capacityGrade) R\($0.rechargeGrade) - "
          + String(format: "RATED %.1f /S", $0.ratedRecharge)
      } ?? "NO MODULE SELECTED"
      painted.label(clipped(grades), left, bankY + line, scale: font, ink: .white)
      var y = bankY + line * 2 + 4
      for axis in EMPModuleAxis.allCases {
        let grade = chosenBank.map {
          switch axis {
          case .power: $0.powerGrade
          case .capacity: $0.capacityGrade
          case .recharge: $0.rechargeGrade
          }
        }
        let offer = grade.flatMap { EMPModuleGradePolicy.offer(axis: axis, next: $0 + 1) }
        var intent: EMPModulePurchaseContext?
        var refusal: String?
        if !busy, game.empModuleManagementAvailable, let chosen {
          do { intent = try game.empModulePurchaseContext(module: chosen, axis: axis) }
          catch EMPModulePurchaseError.loan { refusal = "LOAN: UPGRADES UNAVAILABLE" }
          catch EMPModulePurchaseError.missingPaidBase { refusal = "PAID OWNED MODULE REQUIRED" }
          catch EMPModulePurchaseError.insufficientFunds { refusal = "INSUFFICIENT CREDITS" }
          catch { refusal = "UPGRADE UNAVAILABLE" }
        }
        let price = offer.map { String(format: "%.1f CR", Double(game.shopPrice($0)) / 10) }
        let reason: String
        if busy { reason = "WAITING FOR COMMIT" }
        else if !game.empModuleManagementAvailable { reason = "EQUIPMENT SERVICE UNAVAILABLE" }
        else if chosen == nil { reason = "CHOOSE MODULE" }
        else if offer == nil { reason = "MAXIMUM GRADE" }
        else if let offer, !game.equipmentAvailable(offer) { reason = "UNAVAILABLE AT THIS SHOP" }
        else if let price = offer.map({ game.shopPrice($0) }), game.commander.availableCredits < price {
          reason = "INSUFFICIENT CREDITS"
        } else { reason = refusal ?? "RETURN: BUY THIS GRADE" }
        button(axis.rawValue.uppercased() + " " + (grade.map(String.init) ?? "-")
          + (offer == nil ? "" : " -> \((grade ?? 0) + 1) " + (price ?? "")),
          reason, y: y, action: intent.map { .purchase($0) } ?? .disabled(reason))
        y += line * 2 + 8
      }
      button("BACK (ESC)", nil, y: y, action: .back)
      if let notice, y + line * 2 + 10 <= canvasHeight - 7 * font {
        painted.label(clipped(notice), left, y + line + 10, scale: font, ink: .orange)
      }
    } else {
      if canvasWidth >= 120, canvasHeight >= 48 {
        painted.label(clipped("ENLARGE TO MANAGE EMP"), 12, 8, scale: 1, ink: .yellow)
        button("BACK (ESC)", nil, y: 24, action: .back)
      }
    }
    controls = buttons
    focus = max(0, min(paintedFocus, max(0, buttons.count - 1)))
    frame = painted
  }
}

extension Game {
  public var empModuleBankReadouts: [EMPModuleBankReadout] {
    commander.equipmentInventory?.items.compactMap(EMPModuleBankReadout.init) ?? []
  }

  public var empModuleManagementAvailable: Bool {
    screen == .equipment && docked && !paused && !equipmentCrewSelected
      && Equipment.all.indices.contains(selection)
      && EquipmentRuntimeCatalog.node(for: Equipment.all[selection].name) == EMPModuleGradePolicy.node
      && commander.equipmentInventory?.items.contains {
        $0.node == EMPModuleGradePolicy.node && $0.empBankValid
      } == true
  }

  /// This is the base shop's typed already-owned predicate, never a parsed requirement message.
  public var empModuleReturnOpensManagement: Bool {
    guard empModuleManagementAvailable, let inventory = commander.equipmentInventory,
      let history = commander.equipmentPurchaseHistory,
      EquipmentRuntimeCatalog.graph.nodes.first(where: { $0.id == EMPModuleGradePolicy.node })?
        .policy == .shop
    else { return false }
    return inventory.items.contains {
      $0.node == EMPModuleGradePolicy.node
        && EMPModuleGrades.hasPaidBase($0, owner: inventory.owner, history: history)
    }
  }

  public func empModuleManagementBounds(width: Double, height: Double) -> CanvasRect? {
    guard empModuleManagementAvailable else { return nil }
    let layout = EquipmentLayout(game: self, width: width, height: height)
    let top = CockpitLayout(game: self, width: width, height: height).dashboardTop
    let rect = CanvasRect(x: layout.left, y: top - 62 - Double(layout.detailLineCount - 3) * layout.row,
      width: min(layout.contentWidth, 10 * 6 * layout.font), height: 7 * layout.font)
    return rect.x >= 0 && rect.y >= 0 && rect.maxX <= width && rect.maxY <= height ? rect : nil
  }

  public func empModuleUpgradePresentation(
    selected: UUID?, page: Int = 0, focus: Int = 0, notice: String? = nil, busy: Bool = false,
    width: Double, height: Double
  ) -> EMPModuleUpgradePresentation {
    EMPModuleUpgradePresentation(game: self, selected: selected, page: page, focus: focus,
      notice: notice, busy: busy, width: width, height: height)
  }
}
