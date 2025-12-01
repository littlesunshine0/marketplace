import Foundation

public struct DailyEarnings: Identifiable, Codable, Equatable {
    public let id: UUID
    public let date: Date
    public let platform: MarketplacePlatform?
    public var grossSales: Decimal
    public var totalFees: Decimal
    public var netEarnings: Decimal { grossSales - totalFees }
    public var orderCount: Int

    public init(
        id: UUID,
        date: Date,
        platform: MarketplacePlatform?,
        grossSales: Decimal,
        totalFees: Decimal,
        orderCount: Int
    ) {
        self.id = id
        self.date = date
        self.platform = platform
        self.grossSales = grossSales
        self.totalFees = totalFees
        self.orderCount = orderCount
    }
}

public struct EarningsSummary: Codable, Equatable {
    public let period: DateInterval
    public let totalGrossSales: Decimal
    public let totalFees: Decimal
    public let totalNetEarnings: Decimal
    public let orderCount: Int
    public let averageOrderValue: Decimal
    public let platformBreakdown: [MarketplacePlatform: PlatformEarnings]

    public init(
        period: DateInterval,
        totalGrossSales: Decimal,
        totalFees: Decimal,
        totalNetEarnings: Decimal,
        orderCount: Int,
        averageOrderValue: Decimal,
        platformBreakdown: [MarketplacePlatform: PlatformEarnings]
    ) {
        self.period = period
        self.totalGrossSales = totalGrossSales
        self.totalFees = totalFees
        self.totalNetEarnings = totalNetEarnings
        self.orderCount = orderCount
        self.averageOrderValue = averageOrderValue
        self.platformBreakdown = platformBreakdown
    }
}

public struct PlatformEarnings: Codable, Equatable, Identifiable {
    public var id: MarketplacePlatform { platform }
    public let platform: MarketplacePlatform
    public let grossSales: Decimal
    public let fees: Decimal
    public let orderCount: Int

    public init(platform: MarketplacePlatform, grossSales: Decimal, fees: Decimal, orderCount: Int) {
        self.platform = platform
        self.grossSales = grossSales
        self.fees = fees
        self.orderCount = orderCount
    }
}
