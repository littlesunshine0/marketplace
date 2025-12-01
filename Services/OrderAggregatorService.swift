import Foundation
import Combine

@MainActor
public final class OrderAggregatorService: ObservableObject {
    @Published public private(set) var orders: [Order] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var lastSyncedAt: Date?

    private let persistenceManager: PersistenceManagerProtocol
    private let ebayClient: EBayAPIClientProtocol
    private let mercariClient: MercariAPIClientProtocol
    private let facebookClient: FacebookAPIClientProtocol

    public init(
        persistenceManager: PersistenceManagerProtocol,
        ebayClient: EBayAPIClientProtocol,
        mercariClient: MercariAPIClientProtocol,
        facebookClient: FacebookAPIClientProtocol
    ) {
        self.persistenceManager = persistenceManager
        self.ebayClient = ebayClient
        self.mercariClient = mercariClient
        self.facebookClient = facebookClient
    }

    public func fetchOrdersFromAllPlatforms() async throws {
        isLoading = true
        defer {
            isLoading = false
            lastSyncedAt = Date()
        }

        async let ebayOrders = ebayClient.fetchOrders()
        async let mercariOrders = mercariClient.fetchOrders()
        async let facebookOrders = facebookClient.fetchOrders()

        let (ebay, mercari, facebook) = try await (ebayOrders, mercariOrders, facebookOrders)
        let allOrders = ebay + mercari + facebook

        for order in allOrders {
            try persistenceManager.save(order)
        }

        await loadOrders()
    }

    public func loadOrders() async {
        orders = (try? persistenceManager.fetch(Order.self)) ?? []
        orders.sort { $0.createdAt > $1.createdAt }
    }

    public func updateOrderStatus(
        _ orderId: UUID,
        newStatus: OrderStatus,
        platform: MarketplacePlatform
    ) async throws {
        guard let order = orders.first(where: { $0.id == orderId }) else { return }

        switch platform {
        case .ebay:
            try await ebayClient.updateOrderStatus(platformOrderId: order.platformOrderId, status: newStatus)
        case .mercari:
            try await mercariClient.updateOrderStatus(platformOrderId: order.platformOrderId, status: newStatus)
        case .facebook:
            try await facebookClient.updateOrderStatus(platformOrderId: order.platformOrderId, status: newStatus)
        }

        var updatedOrder = order
        updatedOrder.status = newStatus
        try persistenceManager.update(updatedOrder)
        await loadOrders()
    }
}
