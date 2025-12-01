import SwiftUI

enum SidebarDestination: Hashable {
    case inventory
    case orders
    case earnings
    case notifications
    case help
}

@main
struct MarketplaceApp: App {
    @StateObject private var listingService: ListingService
    @StateObject private var orderService: OrderAggregatorService
    @StateObject private var earningsService: EarningsService
    @StateObject private var priceCheckService: PriceCheckService
    @StateObject private var notifications = AppNotificationCenter()

    @StateObject private var inventoryViewModel: InventoryViewModel
    @StateObject private var ordersViewModel: OrdersViewModel
    @StateObject private var earningsViewModel: EarningsViewModel

    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    @State private var destination: SidebarDestination? = .inventory

    init() {
        let persistence = PersistenceManager()
        let keychain = KeychainManager()
        let accountService = InMemoryAccountService()
        let authManager = AuthenticationManager(accountService: accountService, keychainManager: keychain)
        let baseURL = URL(string: "https://api.example.com")!
        let apiClient = APIClient(baseURL: baseURL, authenticationManager: authManager)
        let ebay = EBayAPIClient(apiClient: apiClient)
        let mercari = MercariAPIClient(apiClient: apiClient)
        let facebook = FacebookAPIClient(apiClient: apiClient)

        let listingService = ListingService(
            persistenceManager: persistence,
            ebayClient: ebay,
            mercariClient: mercari,
            facebookClient: facebook
        )

        let orderService = OrderAggregatorService(
            persistenceManager: persistence,
            ebayClient: ebay,
            mercariClient: mercari,
            facebookClient: facebook
        )

        let earningsService = EarningsService(
            persistenceManager: persistence,
            orderService: orderService
        )

        let priceCheck = PriceCheckService()

        _listingService = StateObject(wrappedValue: listingService)
        _orderService = StateObject(wrappedValue: orderService)
        _earningsService = StateObject(wrappedValue: earningsService)
        _priceCheckService = StateObject(wrappedValue: priceCheck)

        _inventoryViewModel = StateObject(wrappedValue: InventoryViewModel(listingService: listingService, priceCheckService: priceCheck, notifications: notifications))
        _ordersViewModel = StateObject(wrappedValue: OrdersViewModel(orderService: orderService, notifications: notifications))
        _earningsViewModel = StateObject(wrappedValue: EarningsViewModel(earningsService: earningsService, notifications: notifications))
    }

    var body: some Scene {
        WindowGroup {
            NavigationSplitView(columnVisibility: $sidebarVisibility) {
                sidebar
            } detail: {
                detail
                    .toolbar { mainToolbar }
                    .overlay(alignment: .top) {
                        NotificationBannerStack(notifications: notifications)
                    }
            }
            .environmentObject(listingService)
            .environmentObject(orderService)
            .environmentObject(earningsService)
            .environmentObject(inventoryViewModel)
            .environmentObject(ordersViewModel)
            .environmentObject(earningsViewModel)
            .environmentObject(notifications)
        }
        .commands { appCommands }
    }

    private var sidebar: some View {
        List(selection: $destination) {
            Section("Workflows") {
                Label("Inventory", systemImage: "shippingbox")
                    .tag(SidebarDestination.inventory)
                Label("Orders", systemImage: "cart")
                    .tag(SidebarDestination.orders)
                Label("Earnings", systemImage: "chart.line.uptrend.xyaxis")
                    .tag(SidebarDestination.earnings)
            }

            Section("Operations") {
                Label("Notifications", systemImage: "bell")
                    .tag(SidebarDestination.notifications)
                Label("Platform Help", systemImage: "questionmark.circle")
                    .tag(SidebarDestination.help)
            }
        }
        .navigationTitle("Marketplace")
        .toolbar { sidebarToolbar }
    }

    @ToolbarContentBuilder
    private var sidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                withAnimation { sidebarVisibility = sidebarVisibility == .detailOnly ? .all : .detailOnly }
            } label: {
                Label("Toggle Sidebar", systemImage: "sidebar.leading")
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch destination {
        case .inventory, .none:
            InventoryView()
        case .orders:
            OrdersView()
        case .earnings:
            EarningsView()
        case .notifications:
            NotificationsView()
        case .help:
            PlatformHelpView()
        }
    }

    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button {
                Task { await inventoryViewModel.createDraft() }
            } label: {
                Label("New Product", systemImage: "plus")
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button {
                Task { await ordersViewModel.refresh() }
            } label: {
                Label("Sync Orders", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button {
                notifications.clearAll()
            } label: {
                Label("Clear Notifications", systemImage: "bell.slash")
            }
        }
    }

    private var appCommands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Product") { Task { await inventoryViewModel.createDraft() } }
                .keyboardShortcut("n", modifiers: [.command])
            Button("Publish Selection") { Task { await inventoryViewModel.publishSelection(to: MarketplacePlatform.allCases) } }
                .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandMenu("Orders") {
            Button("Sync Orders") { Task { await ordersViewModel.refresh() } }
                .keyboardShortcut("r", modifiers: [.command])
        }

        CommandMenu("Help") {
            Button("Open Platform Help") { destination = .help }
                .keyboardShortcut("/", modifiers: [.command])
        }
    }
}
