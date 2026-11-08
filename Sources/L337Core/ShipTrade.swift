import Foundation

public struct ShipTradeQuote: Sendable {
  public let selected: CatalogueShip
  public let purchase: Int
  public let allowance: Int
  public let net: Int
  public let balance: Int
  public let issues: [String]
  public var allowed: Bool { issues.isEmpty }
  public var rows: [String] {
    [
      "Selected: " + selected.name,
      String(format: "Hull price: %.1f CR", Double(purchase) / 10),
      String(format: "Trade-in allowance: %.1f CR", Double(allowance) / 10),
      String(format: "Net %@: %.1f CR", net < 0 ? "credit" : "cost", Double(abs(net)) / 10),
      String(format: "Resulting cash: %.1f CR", Double(balance) / 10),
      "Cargo, fuel, portable equipment and mission property transfer.",
      "Hull-bound fittings leave with the sold hull.",
      "Unsupported portable fittings remain owned in storage.",
      "No new lasers, missiles or free fuel are included.",
    ] + (issues.isEmpty ? ["Compatible fit. Confirm to exchange hulls."] : issues)
  }
}
extension Game {
  public var shipTradeQuote: ShipTradeQuote? {
    guard let selected = showroomShip else { return nil }
    return shipTradeQuote(for: selected)
  }
  func shipTradeQuote(for requested: CatalogueShip) -> ShipTradeQuote? {
    let bison: OriginalBisonActivation.Source?
    let selected: CatalogueShip
    if OriginalBisonActivation.contains(requested.id) {
      guard let source = OriginalBisonActivation.source(for: requested.id) else { return nil }
      bison = source
      selected = source.ship
    } else {
      bison = nil
      guard let canonical = ShipCatalogue.ship(requested.id) else { return nil }
      selected = canonical
    }
    guard !OriginalDetailedHullStage.blocksRuntime(selected.id), let next = selected.game else {
      return nil
    }
    let purchase = next.price * 10
    let allowance = commander.performance.price * 10 * 3 / 4
    let net = purchase - allowance
    let balance = commander.unlimitedCash ? commander.credits : commander.credits - net
    var issues: [String] = []
    if next.price <= 0 { issues.append("This hull is unpriced and not for sale.") }
    if selected.catalogue.purchasePolicy == .never {
      issues.append("This hull is not for sale.")
    }
    if selected.catalogue.purchasePolicy == .pendingFabrication {
      issues.append("Fabrication for this hull is not yet available.")
    }
    if selected.id == OriginalImpalaVoyagerActivation.id {
      if !OriginalImpalaVoyagerActivation.authenticates(selected) {
        issues.append("Original Impala source is unavailable.")
      } else if currentSystem.technology < OriginalImpalaVoyagerActivation.minimumBuildTechLevel {
        issues.append("Impala fabrication requires TL14.")
      }
    }
    if selected.catalogue.purchasePolicy == .xyzzyOnly && !commander.xyzzyActive {
      issues.append("This hull requires XYZZY access.")
    }
    if !docked || !dockedAtMainStation { issues.append("Exchange requires a main station.") }
    if selected.id == commander.shipID { issues.append("You already own this hull.") }
    if balance < 0 { issues.append("Insufficient cash for this exchange.") }
    if balance > 4_294_967_295 { issues.append("Credit would exceed the account limit.") }
    let projected: Commander
    do {
      projected = try commander.projectedEquipmentTransfer(to: selected.id)
    } catch {
      issues.append("Physical fittings or carried resources are incompatible with this hull.")
      // The entry guard has already refused every staged physical hull.
      var fallback = commander
      fallback.shipID = selected.id
      projected = fallback
    }
    issues += shipTransferIssues(to: projected)
    if selected.catalogue.purchasePolicy == .blueprintFabrication {
      issues += originalFabricationIssues(
        ship: selected, minimumTechnology: bison?.minimumTechnology
          ?? selected.catalogue.minimumBuildTechLevel)
    }
    return .init(
      selected: selected, purchase: purchase, allowance: allowance, net: net, balance: balance,
      issues: issues)
  }
  /// Fabrication uses fresh owned arrival and blueprint evidence, never the displayed quote.
  private func originalFabricationIssues(ship: CatalogueShip, minimumTechnology: Int?) -> [String] {
    var issues: [String] = []
    if commander.fleetBlueprintAcquisition(for: ship.id) == nil {
      issues.append(
        "Earn this hull's blueprint through paid EMP disable, "
          + "authorized empty-section cutting and physical sample recovery.")
    }
    if !scriptDurabilityAvailable { issues.append("Choose a commander save before fabrication.") }
    guard case .living(let destination) = nativeOriginalMainStationDestination,
      destination.identity.system == systemIdentity, nativeCrewExchangeEpoch != nil
    else {
      issues.append("Fabrication requires a current arrival at a living main station.")
      return issues
    }
    let system = destination.identity.system
    guard let worlds = try? OriginalWorldCatalogue.loadBundled(),
      let world = try? worlds.world(galaxy: system.galaxy, system: system.system)
    else {
      issues.append("The current fabrication world's source is unavailable.")
      return issues
    }
    guard let minimumTechnology else {
      issues.append("This hull has no authenticated fabrication technology requirement.")
      return issues
    }
    if world.technology < minimumTechnology {
      issues.append("This hull requires TL\(minimumTechnology) fabrication.")
    }
    return issues
  }
  private func shipTransferIssues(to projected: Commander) -> [String] {
    let next = projected.performance
    var issues: [String] = []
    if !(commander.nativePeople?.held.isEmpty ?? true)
      || commander.scriptState.instances.values.contains(where: {
        $0.savedOwnedCargo?.held.isEmpty == false
      }),
      commander.cargoTonnes > projected.standardCargoCapacity
    {
      issues.append(
        "Protected people and issuer-owned freight require real hold space. Transfer them explicitly before choosing this hull."
      )
    }
    if commander.cargoTonnes > projected.capacity {
      issues.append(
        "Sell cargo first: hold requires \(commander.cargoTonnes)t; new capacity \(projected.capacity)t. Mission cargo cannot be sold."
      )
    }
    if commander.equipmentInventory == nil,
      commander.equipment.contains("Large Cargo Bay") && next.cargoExpansion == 0
    {
      issues.append("Cargo expansion cannot transfer to this hull. Choose a compatible hull.")
    }
    for mount in LaserMount.allCases
    where projected.laser(on: mount) != nil && !next.supports(mount) {
      issues.append(mount.label + " laser has no matching mount. Choose a compatible hull.")
    }
    if projected.missiles > next.missiles {
      issues.append(
        "Use excess missiles first: \(projected.missiles) held; \(next.missiles) pylons available.")
    }
    if commander.fuel > projected.fuelCapacity {
      issues.append("Use excess fuel first; new tank is smaller.")
    }
    if let plan = commander.navigationPlan,
      zip(plan.path, plan.path.dropFirst()).contains(where: {
        systems[$0].distance(to: systems[$1])
          > projected.fullTankJumpDistance
      })
    {
      issues.append("Clear the incompatible navigation route before exchanging.")
    }
    if let issue = commander.nativeCrewTransferIssue(to: projected.shipID) { issues.append(issue) }
    return issues
  }
  mutating func confirmShipTrade() {
    guard !paused, showroom.trading, let quote = shipTradeQuote, quote.allowed else { return }
    guard ownedEquipmentEventCapacityAvailable else {
      notify("HULL EXCHANGE REFUSED - MISSION EVENT CAPACITY")
      return
    }
    let previous = commander.shipID
    // Re-evaluate the quote at confirmation; no state changes happen on opening or Back.
    do {
      try commitShipTradeCandidate(quote)
    } catch {
      notify("HULL EXCHANGE REFUSED - FITTINGS OR RESOURCES INCOMPATIBLE")
      return
    }
    showroom.baseline = commander.shipID
    showroom.baselineUsesCurrent = true
    showroom.trading = false
    showroom.scroll = 0
    notify("NOW FLYING " + commander.ship.name.uppercased())
    emitScriptEvent(
      "ship.changed", values: ["previous": .string(previous), "ship": .string(commander.shipID)])
  }
  /// Finish the copied fitting transaction before entering mission event dispatch.
  private mutating func commitShipTradeCandidate(_ quote: ShipTradeQuote) throws {
    var candidate = self
    try candidate.commander.prepareEquipment()
    try candidate.commander.transferEquipment(
      to: quote.selected.id, hullID: UUID(), crewEpoch: nativeCrewExchangeEpoch)
    candidate.commander.credits = quote.balance
    candidate.preserveEquipmentResourceFractions(from: self)
    self = candidate
  }
  /// Hull and fitting changes reserve their observation before publishing physical custody.
  var ownedEquipmentEventCapacityAvailable: Bool {
    let recipients = commander.scriptState.instances.values.filter { $0.outcome == .active }.count
    return recipients <= 4096
      && commander.scriptState.pendingEvents.count <= 4096 - recipients
      && commander.scriptState.nextEvent <= UInt64(Int64.max) - 1 - UInt64(recipients)
  }
  mutating func shipTradeKey(_ key: String) {
    switch key {
    case "escape": showroom.trading = false
    case "left", "right", "tab": showroom.confirmTrade.toggle()
    case "up", "down", "pageup", "pagedown":
      let count = Display.shipTradeRows(self, width: viewportWidth).count
      let visible = ShipTradeLayout(width: viewportWidth, height: viewportHeight).count
      let window = ScrollWindow(count: count, visible: visible, offset: showroom.tradeScroll)
      showroom.tradeScroll = window.moved(key == "up" || key == "pageup" ? -4 : 4)
    case "return":
      if showroom.confirmTrade { confirmShipTrade() } else { showroom.trading = false }
    default: break
    }
  }
}
