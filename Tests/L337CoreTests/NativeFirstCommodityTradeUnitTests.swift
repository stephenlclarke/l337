import Foundation
import Testing

@testable import L337Core

private extension GameRuntime {
  func chooseFirstCommodityTradeTestScreen(index: Int, buying: Bool = true) {
    game.screen = buying ? .buy : .sell
    game.selection = index
  }
}

private func firstCommodityTradeFixture() async throws -> (GameRuntime, Int) {
  let runtime = GameRuntime(game: Game(executive: false))
  try await runtime.startNewCommander()
  let game = await runtime.snapshot()
  try #require(game.commander.valid && game.nativeMainStationDockEvidenceIsCurrent)
  try #require(game.commander.cargoTonnes < game.commander.standardCargoCapacity)
  let items = game.market
  let cargo = game.commander.cargo
  let credits = game.commander.availableCredits
  let index = try #require(items.indices.first {
    Commodity.all[$0].unit == "t" && items[$0].quantity > 0
      && items[$0].price <= credits && cargo[$0] == 0
  })
  await runtime.chooseFirstCommodityTradeTestScreen(index: index)
  return (runtime, index)
}

private func firstTradeLeaf(_ receipt: NativeFirstCommodityTrade) throws -> [String: Any] {
  try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
}

struct NativeFirstCommodityTradeUnitTests {
  @Test func realPurchaseRecordsFirstTradeAndLaterRealSalePreservesItsIdentity() async throws {
    let (runtime, index) = try await firstCommodityTradeFixture()
    var game = await runtime.snapshot()
    let before = game.commander
    let stock = game.market[index].quantity
    let price = game.market[index].price
    game.trade(buy: true)
    let receipt = try #require(game.commander.scriptState.firstNativeCommodityTrade)
    #expect(receipt.valid && receipt.side == .buy && receipt.quantity == 1)
    #expect(receipt.unitPrice == price && receipt.before.credits == before.credits)
    #expect(receipt.after.stock == stock - 1 && receipt.after.cargo == 1)
    #expect(receipt.after.credits == before.credits - price)
    #expect(game.commander.scriptState.firstNativeCommoditySale == nil)
    #expect(NativeAssemblyOfOrbitsTrade.current(in: game.commander) == receipt)
    game.trade(buy: false)
    #expect(game.commander.cargo[index] == 0)
    #expect(game.commander.scriptState.firstNativeCommodityTrade === receipt)
    #expect(game.commander.scriptState.firstNativeCommoditySale?.quantity == 1)
    #expect(NativeFirstCommoditySaleSave.validateClaims(game.commander))
    #expect(game.commander.scriptState.instances.isEmpty)
  }

  @Test func refusedEmptySaleAndZeroStockPurchaseCreateNoHistory() async throws {
    let (runtime, index) = try await firstCommodityTradeFixture()
    var game = await runtime.snapshot()
    let before = game.commander
    let market = game.market
    game.trade(buy: false)
    #expect(game.commander == before && game.market == market)
    #expect(game.commander.scriptState.firstNativeCommodityTrade == nil)
    // Negative admission input only: an actually empty market cannot produce a purchase.
    game.market[index].quantity = 0
    let empty = game.market
    // Stock belongs to commander.originalMarkets; snapshot after the negative setup.
    let beforeEmptyPurchase = game.commander
    game.trade(buy: true)
    #expect(game.commander == beforeEmptyPurchase && game.market == empty)
    #expect(game.commander.scriptState.firstNativeCommodityTrade == nil)
    // Invalid observer DATA must refuse before subtraction, not trap or invent a trade.
    game.recordFirstNativeCommodityTrade(buying: true, index: index,
      before: .init(stock: 0, cargo: Int.min, credits: before.credits), unitPrice: game.market[index].price)
    #expect(game.commander == beforeEmptyPurchase && game.commander.scriptState.firstNativeCommodityTrade == nil)
    game.commander.cargo[index] = Int.min
    let invalidAfter = game.commander
    game.recordFirstNativeCommodityTrade(buying: false, index: index,
      before: .init(stock: 0, cargo: 0, credits: before.credits), unitPrice: game.market[index].bidPrice)
    #expect(game.commander == invalidAfter && game.commander.scriptState.firstNativeCommodityTrade == nil)
  }

  @Test func realUnlimitedCashPurchaseRetainsTheActualWaivedPayment() async throws {
    let (runtime, index) = try await firstCommodityTradeFixture()
    var game = await runtime.snapshot()
    game.commander.unlimitedCash = true
    let credits = game.commander.credits
    game.trade(buy: true)
    let receipt = try #require(game.commander.scriptState.firstNativeCommodityTrade)
    #expect(receipt.valid && receipt.side == .buy && receipt.paymentWaived)
    #expect(receipt.before.credits == credits && receipt.after.credits == credits)
    #expect(game.commander.cargo[index] == receipt.before.cargo + 1)
  }

  @Test(arguments: [141, 142])
  func actualReceiptRequiresItsOwnStrictNamespaceAndMissionsRoot(schema: Int) async throws {
    let (runtime, _) = try await firstCommodityTradeFixture()
    var game = await runtime.snapshot()
    game.trade(buy: true)
    let receipt = try #require(game.commander.scriptState.firstNativeCommodityTrade)
    try NativeFirstCommodityTradeSave.validateFields(Data("{}".utf8), location: .missions, schema: 21)
    // Reserved native root names remain ordinary keys inside arbitrary legacy ScriptValue data.
    let legacyData = Data("{\"instances\":{\"example\":{\"data\":{\"firstNativeCommodityTrade\":{\"note\":\"user data\"}}}}}".utf8)
    try NativeFirstCommodityTradeSave.validateFields(legacyData, location: .missions, schema: 21)
    #expect(throws: (any Error).self) {
      try NativeFirstCommodityTradeSave.validateFields(legacyData, location: .missions, schema: schema)
    }
    #expect(throws: (any Error).self) {
      try NativeFirstCommodityTradeSave.validateFields(Data("[]".utf8), location: .missions, schema: 21)
    }
    let leaf = try firstTradeLeaf(receipt)
    let bytes = try JSONSerialization.data(withJSONObject: [NativeFirstCommodityTradeSave.field: leaf])
    try NativeFirstCommodityTradeSave.validateFields(bytes, location: .missions, schema: schema)
    for old in [21, 26, 65, 66, 139, 140] {
      #expect(throws: (any Error).self) {
        try NativeFirstCommodityTradeSave.validateFields(bytes, location: .missions, schema: old)
      }
    }
    let locations: [ScriptSaveJSONPreflight.InquiryArchiveLocation] = [
      .pointer, .commander, .contracts, .world,
    ]
    for location in locations {
      #expect(throws: (any Error).self) {
        try NativeFirstCommodityTradeSave.validateFields(bytes, location: location, schema: schema)
      }
    }
    #expect(throws: (any Error).self) {
      try NativeFirstCommodityTradeSave.validateFields(Data("{}".utf8), location: .missions, schema: schema)
    }
    let embedded = try JSONSerialization.data(withJSONObject: ["savedScriptState": [
      NativeFirstCommodityTradeSave.field: leaf,
    ]])
    #expect(throws: (any Error).self) {
      try NativeFirstCommodityTradeSave.validateFields(embedded, location: .commander, schema: schema)
    }
    #expect(ScriptSaveStore.publicationSchema(game.commander, alien: schema == 142) == schema)
  }

  @Test func rawDuplicateFractionalUnknownAndForgedBalancesRefuseBeforeAdmission() async throws {
    let (runtime, _) = try await firstCommodityTradeFixture()
    var game = await runtime.snapshot()
    game.trade(buy: true)
    let receipt = try #require(game.commander.scriptState.firstNativeCommodityTrade)
    let original = try firstTradeLeaf(receipt)
    var wrongPrice = original
    wrongPrice["unitPrice"] = receipt.unitPrice + 1
    var unknown = original
    unknown["granted"] = true
    var wrongBalance = original
    var after = try #require(original["after"] as? [String: Any])
    after["cargo"] = receipt.after.cargo + 1
    wrongBalance["after"] = after
    for leaf in [wrongPrice, unknown, wrongBalance] {
      let bytes = try JSONSerialization.data(withJSONObject: [NativeFirstCommodityTradeSave.field: leaf])
      #expect(throws: (any Error).self) {
        try NativeFirstCommodityTradeSave.validateFields(bytes, location: .missions, schema: 141)
      }
    }
    let encoded = String(decoding: try JSONEncoder().encode(receipt), as: UTF8.self)
    let fractional = encoded.replacingOccurrences(of: "\"quantity\":1", with: "\"quantity\":1.0")
    try #require(fractional != encoded)
    let root = "\"firstNativeCommodityTrade\":"
    for text in ["{" + root + fractional + "}",
      "{" + root + encoded + "," + root + encoded + "}",
      "{\"instances\":{\"hidden\":{" + root + encoded + "}}}"] {
      #expect(throws: (any Error).self) {
        try NativeFirstCommodityTradeSave.validateFields(Data(text.utf8), location: .missions, schema: 141)
      }
    }
    let restored = try JSONDecoder().decode(NativeFirstCommodityTrade.self,
      from: JSONEncoder().encode(receipt))
    #expect(restored == receipt && restored.valid)
  }

  @Test func historicalOwnerCannotBeBorrowedFromAnotherCommander() async throws {
    let (runtime, _) = try await firstCommodityTradeFixture()
    var game = await runtime.snapshot()
    game.trade(buy: true)
    let receipt = try #require(game.commander.scriptState.firstNativeCommodityTrade)
    try #require(NativeFirstCommodityTradeSave.validateClaims(game.commander))
    var wrongOwner = try firstTradeLeaf(receipt)
    wrongOwner["owner"] = UUID().uuidString
    let forged = try JSONDecoder().decode(NativeFirstCommodityTrade.self,
      from: JSONSerialization.data(withJSONObject: wrongOwner))
    game.commander.scriptState.firstNativeCommodityTrade = forged
    #expect(!NativeFirstCommodityTradeSave.validateClaims(game.commander))
    #expect(NativeAssemblyOfOrbitsTrade.current(in: game.commander) == nil)
    #expect(!game.commander.valid)
  }
  @Test func preFeatureHoldCanRecordItsFirstActualSaleAndAutoTradeRetainsFirstRealOperation()
    async throws
  {
    let (runtime, index) = try await firstCommodityTradeFixture()
    var game = await runtime.snapshot()
    game.trade(buy: true)
    try #require(game.commander.cargo[index] == 1)
    // Migration DATA projection only: retain every actual purchased item and balance,
    // but omit this new feature's history as a genuine pre-feature save would do.
    game.commander.scriptState.firstNativeCommodityTrade = nil
    let before = game.commander
    let stock = game.market[index].quantity
    let price = game.market[index].bidPrice
    game.trade(buy: false)
    let sale = try #require(game.commander.scriptState.firstNativeCommodityTrade)
    #expect(sale.valid && sale.side == .sell && !sale.paymentWaived && sale.quantity == 1)
    #expect(sale.before.stock == stock && sale.after.stock == stock + 1)
    #expect(sale.before.credits == before.credits && sale.after.credits == game.commander.credits)
    #expect(sale.unitPrice == price && game.commander.scriptState.firstNativeCommoditySale != nil)

    var automated = await runtime.snapshot()
    let destination = try #require(automated.knownSystems.first {
      $0.id != automated.commander.system && automated.currentSystem.distance(to: $0)
        <= automated.commander.maximumJumpDistance && !automated.profitableExports(to: $0).isEmpty
    })
    automated.selectedSystem = destination.id
    automated.autoTrade()
    let purchase = try #require(automated.commander.scriptState.firstNativeCommodityTrade)
    #expect(purchase.valid && purchase.side == .buy && purchase.quantity > 0)
    #expect(automated.commander.scriptState.firstNativeCommoditySale == nil)
    #expect(NativeFirstCommodityTradeSave.validateClaims(automated.commander))
    automated.autoTrade()
    #expect(automated.commander.scriptState.firstNativeCommodityTrade === purchase)
    #expect(automated.commander.scriptState.firstNativeCommoditySale != nil)
  }
}
