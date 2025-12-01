import SwiftUI

enum OrderStatusFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case shipped = "Shipped"
    case delivered = "Delivered"
}

struct OrdersView: View {
    @EnvironmentObject var viewModel: OrdersViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                ordersTable
            }
            .padding()
            .navigationTitle("Orders")
            .toolbar { toolbar }
        }
    }

    private var header: some View {
        HStack {
            Text("Orders Dashboard")
                .font(.largeTitle)
                .bold()
            Spacer()
            TextField("Search", text: $viewModel.searchTerm)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
            Picker("Status", selection: $viewModel.filter) {
                ForEach(OrderStatusFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var ordersTable: some View {
        Table(viewModel.filteredOrders) {
            TableColumn("Platform") { order in
                Label(order.platform.rawValue, systemImage: icon(for: order.platform))
            }
            TableColumn("Buyer") { order in
                Text(order.buyerName)
            }
            TableColumn("Total") { order in
                Text("$\(order.totalAmount, format: .currency(code: "USD"))")
            }
            TableColumn("Status") { order in
                StatusBadge(text: order.status.rawValue.capitalized, color: statusColor(order.status))
            }
            TableColumn("Created") { order in
                Text(order.createdAt, style: .date)
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                Task { await viewModel.refresh() }
            } label: {
                Label("Sync", systemImage: "arrow.clockwise")
            }
        }
    }

    private func icon(for platform: MarketplacePlatform) -> String {
        switch platform {
        case .ebay: return "e.circle.fill"
        case .mercari: return "m.circle.fill"
        case .facebook: return "f.circle.fill"
        }
    }

    private func statusColor(_ status: Order.OrderStatus) -> Color {
        switch status {
        case .pending: return .yellow
        case .paid, .processing: return .blue
        case .shipped: return .orange
        case .delivered: return .green
        case .cancelled, .returned: return .red
        }
    }
}
