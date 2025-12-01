import Foundation

public struct PriceCheckResult: Equatable {
    public let suggestedPrice: Decimal
    public let delta: Decimal
    public let rationale: String
}

public protocol PriceCheckServiceProtocol {
    func suggestPrice(for product: Product) async -> PriceCheckResult
}

public actor PriceCheckService: PriceCheckServiceProtocol {
    public init() {}

    public func suggestPrice(for product: Product) async -> PriceCheckResult {
        let competitorFactor = Decimal.random(in: -5...10)
        let suggested = max(1, product.price + competitorFactor)
        let delta = suggested - product.price
        let rationale = delta > 0 ? "Raising price to match market demand" : "Lowering price to stay competitive"
        return PriceCheckResult(suggestedPrice: suggested, delta: delta, rationale: rationale)
    }
}
