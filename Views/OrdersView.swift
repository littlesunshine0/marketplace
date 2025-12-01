import SwiftUI

struct OrdersView: View {
    @EnvironmentObject var orderService: OrderAggregatorService
    @State private var selectedFilter: OrderStatusFilter = .all

    private var filteredOrders: [Order] {
        switch selectedFilter {
        case .all:
            return orderService.orders
        case .pending:
            return orderService.orders.filter { $0.status == .pending || $0.status == .paid }
        case .shipped:
            return orderService.orders.filter { $0.status == .shipped }
        case .delivered:
            return orderService.orders.filter { $0.status == .delivered }
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                Picker("Filter", selection: $selectedFilter) {
                    ForEach(OrderStatusFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if filteredOrders.isEmpty {
                    VStack {
                        Image(systemName: "bag")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Orders")
                            .font(.headline)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                } else {
                    List(filteredOrders) { order in
                        OrderListRow(order: order)
                    }
                }
            }
            .navigationTitle("Orders")
            .task {
                try? await orderService.fetchOrdersFromAllPlatforms()
            }
        }
    }
}

struct OrderListRow: View {
    let order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Order #\(order.platformOrderId.prefix(8))")
                    .font(.headline)
                Spacer()
                Badge(text: order.status.rawValue, color: statusColor(order.status))
            }

            HStack {
                Text(order.buyerName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(order.totalAmount as NSNumber, formatter: NumberFormatter.currency)")
                    .fontWeight(.semibold)
            }

            Text(order.platform.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func statusColor(_ status: OrderStatus) -> Color {
        switch status {
        case .pending:
            return .yellow
        case .paid, .processing:
            return .blue
        case .shipped:
            return .orange
        case .delivered:
            return .green
        case .cancelled, .returned:
            return .red
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(4)
    }
}

enum OrderStatusFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case shipped = "Shipped"
    case delivered = "Delivered"
}
