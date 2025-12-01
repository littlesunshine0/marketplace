import Foundation
import Combine

@MainActor
public final class EarningsService: ObservableObject {
    @Published public private(set) var dailyEarnings: [DailyEarnings] = []
    @Published public private(set) var earningsSummary: EarningsSummary?

    private let persistenceManager: PersistenceManagerProtocol
    private let orderService: OrderAggregatorService

    public init(persistenceManager: PersistenceManagerProtocol, orderService: OrderAggregatorService) {
        self.persistenceManager = persistenceManager
        self.orderService = orderService
    }

    public func calculateEarnings(for period: DateInterval) async {
        let orders = orderService.orders.filter { period.contains($0.paidAt ?? $0.createdAt) }

        var platformBreakdown: [MarketplacePlatform: PlatformEarnings] = [:]
        var totalGrossSales: Decimal = 0
        var totalFees: Decimal = 0

        for platform in MarketplacePlatform.allCases {
            let platformOrders = orders.filter { $0.platform == platform }
            let gross = platformOrders.reduce(0) { $0 + $1.itemPrice }
            let fees = platformOrders.reduce(0) { $0 + $1.fees.totalFees }

            platformBreakdown[platform] = PlatformEarnings(
                platform: platform,
                grossSales: gross,
                fees: fees,
                orderCount: platformOrders.count
            )

            totalGrossSales += gross
            totalFees += fees
        }

        earningsSummary = EarningsSummary(
            period: period,
            totalGrossSales: totalGrossSales,
            totalFees: totalFees,
            totalNetEarnings: totalGrossSales - totalFees,
            orderCount: orders.count,
            averageOrderValue: orders.isEmpty ? 0 : totalGrossSales / Decimal(orders.count),
            platformBreakdown: platformBreakdown
        )

        let groupedByDay = Dictionary(grouping: orders) { order in
            Calendar.current.startOfDay(for: order.paidAt ?? order.createdAt)
        }

        dailyEarnings = groupedByDay.map { date, dayOrders in
            let gross = dayOrders.reduce(0) { $0 + $1.itemPrice }
            let fees = dayOrders.reduce(0) { $0 + $1.fees.totalFees }

            return DailyEarnings(
                id: UUID(),
                date: date,
                platform: nil,
                grossSales: gross,
                totalFees: fees,
                orderCount: dayOrders.count
            )
        }.sorted { $0.date > $1.date }
    }
}
