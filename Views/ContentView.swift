import SwiftUI

@main
struct MarketplaceApp: App {
    @StateObject private var listingService: ListingService
    @StateObject private var orderService: OrderAggregatorService
    @StateObject private var earningsService: EarningsService

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

        _listingService = StateObject(wrappedValue: listingService)
        _orderService = StateObject(wrappedValue: orderService)
        _earningsService = StateObject(wrappedValue: EarningsService(
            persistenceManager: persistence,
            orderService: orderService
        ))
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                InventoryView()
                    .tabItem { Label("Inventory", systemImage: "list.bullet") }
                    .environmentObject(listingService)

                OrdersView()
                    .tabItem { Label("Orders", systemImage: "bag") }
                    .environmentObject(orderService)

                EarningsView()
                    .tabItem { Label("Earnings", systemImage: "chart.line.uptrend.xyaxis") }
                    .environmentObject(earningsService)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        }
    }
}
