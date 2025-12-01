import Foundation
import SwiftUI

@MainActor
final class OrdersViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var filter: OrderStatusFilter = .all
    @Published var searchTerm: String = ""

    private let orderService: OrderAggregatorService
    private let notifications: AppNotificationCenter

    init(orderService: OrderAggregatorService, notifications: AppNotificationCenter) {
        self.orderService = orderService
        self.notifications = notifications
        Task { await refresh() }
    }

    var filteredOrders: [Order] {
        let base = orders.filter { order in
            searchTerm.isEmpty || order.buyerName.localizedCaseInsensitiveContains(searchTerm) || order.platformOrderId.localizedCaseInsensitiveContains(searchTerm)
        }
        switch filter {
        case .all:
            return base
        case .pending:
            return base.filter { $0.status == .pending || $0.status == .paid }
        case .shipped:
            return base.filter { $0.status == .shipped }
        case .delivered:
            return base.filter { $0.status == .delivered }
        }
    }

    func refresh() async {
        do {
            try await orderService.fetchOrdersFromAllPlatforms()
            orders = orderService.orders
            notifications.push(AppNotification(title: "Orders synced", message: "Updated at \(Date().formatted(date: .abbreviated, time: .shortened))", level: .success))
        } catch {
            notifications.push(AppNotification(title: "Order sync failed", message: error.localizedDescription, level: .error))
        }
    }
}
