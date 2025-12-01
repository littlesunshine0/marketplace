Multi-Platform Marketplace Manager Blueprint
===========================================

Hybrid Approach: Inventory + Order Aggregation + Earnings Dashboard

1. ARCHITECTURE OVERVIEW
------------------------

### System Architecture
```
┌─────────────────────────────────────────────────────────┐
│                   SwiftUI Presentation Layer              │
│  (Views, Forms, Dashboards, State Management)            │
└────────────────────┬────────────────────────────────────┘
                    │
┌────────────────────▼────────────────────────────────────┐
│               Service Layer (Business Logic)             │
│  ┌──────────────────────────────────────────────────────┤
│  │ • ListingService (Create/Edit/Sync)                   │
│  │ • OrderAggregatorService (Fetch from all platforms)   │
│  │ • EarningsService (Calculate totals & analytics)      │
│  │ • PlatformAuthService (OAuth2 management)             │
│  └──────────────────────────────────────────────────────┤
└────────────────────┬────────────────────────────────────┘
                    │
┌────────────────────▼────────────────────────────────────┐
│            API Integration Layer                          │
│  ┌──────────────────────────────────────────────────────┤
│  │ • EBayAPIClient                                        │
│  │ • MercariAPIClient                                     │
│  │ • FacebookAPIClient                                    │
│  │ • StripePaymentClient                                  │
│  │ • APIClient (Base networking)                          │
│  └──────────────────────────────────────────────────────┤
└────────────────────┬────────────────────────────────────┘
                    │
┌────────────────────▼────────────────────────────────────┐
│              Data Persistence Layer                       │
│  • Core Data / SwiftData (Local inventory cache)          │
│  • Keychain (OAuth tokens, API keys)                      │
│  • UserDefaults (Settings, preferences)                   │
└──────────────────────────────────────────────────────────┘
```

### Key Design Principles
- Service-oriented: Each platform interaction isolated
- Reactive state management: Combine framework for real-time updates
- Offline-first: Local caching with sync capabilities
- Token management: Secure OAuth2 token refresh
- Error resilience: Graceful fallbacks for API failures

### Current Priorities (June 2026 refresh)
- Ship sandbox-ready OAuth flows for eBay, Mercari, and Facebook with resilient token refresh.
- Harden sync engine with exponential backoff, duplicate detection, and per-platform health status.
- Deliver Inventory → Publish → Orders loop with audit logs and optimistic UI feedback.
- Add structured telemetry (logs + counters) to support observability and support playbooks.

### Specification Anchors
- **Requirements**: See `requirements.md` for functional and non-functional expectations.
- **Design Spec**: See `design-spec.md` for architectural decisions, data flows, and testing strategy.
- **Implementation Checklist**: Use `implementation-checklist.md` before releases and major merges.

2. DATA MODELS
--------------

### Core Models

**Product (Local Listing)**
```swift
// Models/Product.swift
import Foundation

struct Product: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var price: Decimal
    var quantity: Int
    var category: String
    var condition: Condition
    var images: [ProductImage]
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    
    enum Condition: String, Codable {
        case new, likeNew, good, fair, poor
    }
}

struct ProductImage: Identifiable, Codable {
    let id: UUID
    let data: Data? // Local image data
    let remoteURL: URL? // URL on platform servers
    let order: Int
}
```

**PlatformListing (Platform-Specific)**
```swift
// Models/PlatformListing.swift
import Foundation

struct PlatformListing: Identifiable, Codable {
    let id: UUID
    let productId: UUID // Reference to local Product
    let platform: MarketplacePlatform
    let platformListingId: String // eBay item ID, Mercari ID, etc.
    var status: ListingStatus
    var publishedAt: Date?
    var expiresAt: Date?
    var viewCount: Int
    var platformURL: URL
    var syncedAt: Date
    
    enum ListingStatus: String, Codable {
        case draft, active, paused, sold, expired, archived
    }
}

enum MarketplacePlatform: String, Codable, CaseIterable {
    case ebay = "eBay"
    case mercari = "Mercari"
    case facebook = "Facebook Marketplace"
}
```

**Order (Aggregated from Platforms)**
```swift
// Models/Order.swift
import Foundation

struct Order: Identifiable, Codable {
    let id: UUID
    let platformOrderId: String
    let platform: MarketplacePlatform
    let productId: UUID?
    let buyerName: String
    var quantity: Int
    var itemPrice: Decimal
    var totalAmount: Decimal // Including fees
    var fees: OrderFees
    var status: OrderStatus
    var createdAt: Date
    var estimatedDeliveryAt: Date?
    var paidAt: Date?
    var shippedAt: Date?
    
    enum OrderStatus: String, Codable {
        case pending, paid, processing, shipped, delivered, cancelled, returned
    }
}

struct OrderFees: Codable {
    let platformFee: Decimal
    let paymentProcessingFee: Decimal
    let shippingFee: Decimal? // If seller covers
    
    var totalFees: Decimal {
        platformFee + paymentProcessingFee + (shippingFee ?? 0)
    }
}
```

**PlatformAccount (OAuth Credentials)**
```swift
// Models/PlatformAccount.swift
import Foundation

struct PlatformAccount: Identifiable, Codable {
    let id: UUID
    let platform: MarketplacePlatform
    var accountName: String
    var accessToken: String // Store encrypted in Keychain
    var refreshToken: String?
    var tokenExpiresAt: Date?
    var scopes: [String]
    var isActive: Bool
    var connectedAt: Date
    
    var isTokenExpired: Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        return Date() > expiresAt
    }
}
```

**Earnings (Analytics)**
```swift
// Models/Earnings.swift
import Foundation

struct DailyEarnings: Identifiable, Codable {
    let id: UUID
    let date: Date
    let platform: MarketplacePlatform?
    var grossSales: Decimal
    var totalFees: Decimal
    var netEarnings: Decimal { grossSales - totalFees }
    var orderCount: Int
}

struct EarningsSummary: Codable {
    let period: DateInterval
    let totalGrossSales: Decimal
    let totalFees: Decimal
    let totalNetEarnings: Decimal
    let orderCount: Int
    let averageOrderValue: Decimal
    let platformBreakdown: [MarketplacePlatform: PlatformEarnings]
}

struct PlatformEarnings: Codable {
    let platform: MarketplacePlatform
    let grossSales: Decimal
    let fees: Decimal
    let orderCount: Int
}
```

3. SERVICE LAYER
----------------

### Base API Client
```swift
// Services/APIClient.swift
import Foundation

protocol APIClientProtocol {
    associatedtype Response: Decodable
    
    var baseURL: URL { get }
    var session: URLSession { get }
    
    func request<T: Decodable>(_ endpoint: APIEndpoint, 
                               expecting: T.Type) async throws -> T
}

actor APIClient: APIClientProtocol {
    typealias Response = Decodable
    
    let baseURL: URL
    let session: URLSession
    let authenticationManager: AuthenticationManager
    
    init(baseURL: URL, 
         authenticationManager: AuthenticationManager) {
        self.baseURL = baseURL
        self.authenticationManager = authenticationManager
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }
    
    func request<T: Decodable>(_ endpoint: APIEndpoint, 
                               expecting: T.Type) async throws -> T {
        var urlRequest = endpoint.urlRequest(baseURL: baseURL)
        
        // Add authentication header
        if let token = try await authenticationManager.validAccessToken(
            for: endpoint.platform) {
            urlRequest.setValue("Bearer \(token)", 
                              forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            // Token expired, attempt refresh
            try await authenticationManager.refreshToken(for: endpoint.platform)
            return try await request(endpoint, expecting: T.self)
        case 429:
            throw APIError.rateLimited
        default:
            throw APIError.httpError(httpResponse.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case rateLimited
    case decodingError(DecodingError)
    case networkError(URLError)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

protocol APIEndpoint {
    var platform: MarketplacePlatform { get }
    var path: String { get }
    var method: String { get }
    var headers: [String: String] { get }
    var body: Data? { get }
    
    func urlRequest(baseURL: URL) -> URLRequest
}

extension APIEndpoint {
    func urlRequest(baseURL: URL) -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        return request
    }
}
```

### Authentication Manager
```swift
// Services/AuthenticationManager.swift
import Foundation

actor AuthenticationManager {
    private let accountService: PlatformAccountService
    private let keychainManager: KeychainManager
    
    init(accountService: PlatformAccountService,
         keychainManager: KeychainManager) {
        self.accountService = accountService
        self.keychainManager = keychainManager
    }
    
    func validAccessToken(for platform: MarketplacePlatform) async throws -> String? {
        guard let account = try await accountService.getAccount(for: platform) else {
            return nil
        }
        
        if account.isTokenExpired {
            try await refreshToken(for: platform)
            guard let refreshedAccount = try await accountService.getAccount(for: platform) else {
                return nil
            }
            return try keychainManager.retrieveToken(for: platform)
        }
        
        return try keychainManager.retrieveToken(for: platform)
    }
    
    func refreshToken(for platform: MarketplacePlatform) async throws {
        guard let account = try await accountService.getAccount(for: platform),
              let refreshToken = account.refreshToken else {
            throw AuthError.noRefreshToken
        }
        
        let newToken = try await platform.apiClient.refreshAccessToken(
            refreshToken: refreshToken
        )
        
        try keychainManager.storeToken(newToken, for: platform)
        
        var updatedAccount = account
        updatedAccount.accessToken = newToken
        updatedAccount.tokenExpiresAt = Date().addingTimeInterval(3600) // 1 hour
        try await accountService.update(updatedAccount)
    }
}

enum AuthError: LocalizedError {
    case noRefreshToken
    case tokenRefreshFailed
}
```

### Listing Service
```swift
// Services/ListingService.swift
import Foundation
import Combine

@MainActor
final class ListingService: ObservableObject {
    @Published var products: [Product] = []
    @Published var platformListings: [PlatformListing] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let persistenceManager: PersistenceManager
    private let ebayClient: EBayAPIClient
    private let mercariClient: MercariAPIClient
    private let facebookClient: FacebookAPIClient
    
    init(persistenceManager: PersistenceManager,
         ebayClient: EBayAPIClient,
         mercariClient: MercariAPIClient,
         facebookClient: FacebookAPIClient) {
        self.persistenceManager = persistenceManager
        self.ebayClient = ebayClient
        self.mercariClient = mercariClient
        self.facebookClient = facebookClient
        
        Task {
            await loadProducts()
        }
    }
    
    // MARK: - Local Management
    
    func createProduct(_ product: Product) async throws {
        try persistenceManager.save(product)
        await loadProducts()
    }
    
    func updateProduct(_ product: Product) async throws {
        try persistenceManager.update(product)
        await loadProducts()
    }
    
    func deleteProduct(_ id: UUID) async throws {
        try persistenceManager.delete(Product.self, id: id)
        // Also delete associated platform listings
        try await deletePlatformListings(for: id)
        await loadProducts()
    }
    
    private func loadProducts() async {
        products = (try? persistenceManager.fetch(Product.self)) ?? []
        platformListings = (try? persistenceManager.fetch(PlatformListing.self)) ?? []
    }
    
    // MARK: - Multi-Platform Publishing
    
    func publishToAllPlatforms(_ product: Product, 
                              platforms: [MarketplacePlatform]) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let tasks = platforms.map { platform in
            publishToSinglePlatform(product, platform: platform)
        }
        
        try await Task.collectThrowing(tasks)
    }
    
    private func publishToSinglePlatform(_ product: Product, 
                                         platform: MarketplacePlatform) async throws {
        let platformListingId: String
        
        switch platform {
        case .ebay:
            platformListingId = try await ebayClient.createListing(from: product)
        case .mercari:
            platformListingId = try await mercariClient.createListing(from: product)
        case .facebook:
            platformListingId = try await facebookClient.createListing(from: product)
        }
        
        var listing = PlatformListing(
            id: UUID(),
            productId: product.id,
            platform: platform,
            platformListingId: platformListingId,
            status: .active,
            publishedAt: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3600), // 30 days
            viewCount: 0,
            platformURL: URL(string: "https://\(platform.rawValue).com/item/\(platformListingId)")!,
            syncedAt: Date()
        )
        
        try persistenceManager.save(listing)
        await loadProducts()
    }
    
    func syncListingStats() async throws {
        isLoading = true
        defer { isLoading = false }
        
        for listing in platformListings {
            switch listing.platform {
            case .ebay:
                let stats = try await ebayClient.getListingStats(
                    listingId: listing.platformListingId
                )
                var updatedListing = listing
                updatedListing.viewCount = stats.views
                updatedListing.status = stats.active ? .active : .sold
                updatedListing.syncedAt = Date()
                try persistenceManager.update(updatedListing)
                
            case .mercari:
                let stats = try await mercariClient.getListingStats(
                    listingId: listing.platformListingId
                )
                var updatedListing = listing
                updatedListing.viewCount = stats.views
                updatedListing.syncedAt = Date()
                try persistenceManager.update(updatedListing)
                
            case .facebook:
                let stats = try await facebookClient.getListingStats(
                    listingId: listing.platformListingId
                )
                var updatedListing = listing
                updatedListing.viewCount = stats.views
                updatedListing.syncedAt = Date()
                try persistenceManager.update(updatedListing)
            }
        }
    }
    
    // MARK: - Deletion
    
    private func deletePlatformListings(for productId: UUID) async throws {
        let listingsToDelete = platformListings.filter { $0.productId == productId }
        
        for listing in listingsToDelete {
            switch listing.platform {
            case .ebay:
                try await ebayClient.endListing(listingId: listing.platformListingId)
            case .mercari:
                try await mercariClient.deleteListing(listingId: listing.platformListingId)
            case .facebook:
                try await facebookClient.deleteListing(listingId: listing.platformListingId)
            }
            
            try persistenceManager.delete(PlatformListing.self, id: listing.id)
        }
    }
}
```

### Order Aggregator Service
```swift
// Services/OrderAggregatorService.swift
import Foundation
import Combine

@MainActor
final class OrderAggregatorService: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading = false
    @Published var lastSyncedAt: Date?
    
    private let persistenceManager: PersistenceManager
    private let ebayClient: EBayAPIClient
    private let mercariClient: MercariAPIClient
    private let facebookClient: FacebookAPIClient
    private var syncTimer: Timer?
    
    init(persistenceManager: PersistenceManager,
         ebayClient: EBayAPIClient,
         mercariClient: MercariAPIClient,
         facebookClient: FacebookAPIClient) {
        self.persistenceManager = persistenceManager
        self.ebayClient = ebayClient
        self.mercariClient = mercariClient
        self.facebookClient = facebookClient
        
        Task {
            await loadOrders()
        }
        
        // Sync every 5 minutes
        startPeriodicSync(interval: 300)
    }
    
    func fetchOrdersFromAllPlatforms() async throws {
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
    
    private func loadOrders() async {
        orders = (try? persistenceManager.fetch(Order.self)) ?? []
        orders.sort { $0.createdAt > $1.createdAt }
    }
    
    func updateOrderStatus(_ orderId: UUID, 
                          newStatus: Order.OrderStatus,
                          platform: MarketplacePlatform) async throws {
        guard let order = orders.first(where: { $0.id == orderId }) else { return }
        
        switch platform {
        case .ebay:
            try await ebayClient.updateOrderStatus(
                platformOrderId: order.platformOrderId,
                status: newStatus
            )
        case .mercari:
            try await mercariClient.updateOrderStatus(
                platformOrderId: order.platformOrderId,
                status: newStatus
            )
        case .facebook:
            try await facebookClient.updateOrderStatus(
                platformOrderId: order.platformOrderId,
                status: newStatus
            )
        }
        
        var updatedOrder = order
        updatedOrder.status = newStatus
        try persistenceManager.update(updatedOrder)
        await loadOrders()
    }
    
    private func startPeriodicSync(interval: TimeInterval) {
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                try? await self?.fetchOrdersFromAllPlatforms()
            }
        }
    }
    
    deinit {
        syncTimer?.invalidate()
    }
}
```

### Earnings Service
```swift
// Services/EarningsService.swift
import Foundation

@MainActor
final class EarningsService: ObservableObject {
    @Published var dailyEarnings: [DailyEarnings] = []
    @Published var earningsSummary: EarningsSummary?
    
    private let persistenceManager: PersistenceManager
    private let orderService: OrderAggregatorService
    
    init(persistenceManager: PersistenceManager,
         orderService: OrderAggregatorService) {
        self.persistenceManager = persistenceManager
        self.orderService = orderService
    }
    
    func calculateEarnings(for period: DateInterval) async {
        let orders = orderService.orders.filter { order in
            period.contains(order.paidAt ?? order.createdAt)
        }
        
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
        
        // Calculate daily breakdown
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
```

4. PLATFORM-SPECIFIC API CLIENTS
--------------------------------

### eBay API Client
```swift
// Services/EBayAPIClient.swift
import Foundation

actor EBayAPIClient {
    private let apiClient: APIClient
    private let appId: String
    private let certId: String
    
    init(appId: String, certId: String, apiClient: APIClient) {
        self.appId = appId
        self.certId = certId
        self.apiClient = apiClient
    }
    
    // MARK: - Listings
    
    func createListing(from product: Product) async throws -> String {
        let request = CreateListingRequest(from: product)
        let response: CreateListingResponse = try await apiClient.request(
            EBayEndpoint.createListing(request),
            expecting: CreateListingResponse.self
        )
        return response.itemId
    }
    
    func endListing(listingId: String) async throws {
        _ = try await apiClient.request(
            EBayEndpoint.endListing(listingId),
            expecting: EmptyResponse.self
        )
    }
    
    func getListingStats(listingId: String) async throws -> ListingStats {
        let response: ListingStatsResponse = try await apiClient.request(
            EBayEndpoint.getListingStats(listingId),
            expecting: ListingStatsResponse.self
        )
        return response.stats
    }
    
    // MARK: - Orders
    
    func fetchOrders() async throws -> [Order] {
        let response: OrdersFetchResponse = try await apiClient.request(
            EBayEndpoint.fetchOrders(),
            expecting: OrdersFetchResponse.self
        )
        return response.orders.map { $0.toOrder(platform: .ebay) }
    }
    
    func updateOrderStatus(platformOrderId: String, 
                          status: Order.OrderStatus) async throws {
        _ = try await apiClient.request(
            EBayEndpoint.updateOrderStatus(platformOrderId, status),
            expecting: EmptyResponse.self
        )
    }
    
    // MARK: - Token Refresh
    
    func refreshAccessToken(refreshToken: String) async throws -> String {
        let response: TokenRefreshResponse = try await apiClient.request(
            EBayEndpoint.refreshToken(refreshToken),
            expecting: TokenRefreshResponse.self
        )
        return response.accessToken
    }
}
```

#### eBay Endpoints
```swift
enum EBayEndpoint: APIEndpoint {
    case createListing(CreateListingRequest)
    case endListing(String)
    case getListingStats(String)
    case fetchOrders
    case updateOrderStatus(String, Order.OrderStatus)
    case refreshToken(String)
    
    var platform: MarketplacePlatform { .ebay }
    
    var path: String {
        switch self {
        case .createListing:
            return "/api/v1.0/listing/create"
        case .endListing(let id):
            return "/api/v1.0/listing/\(id)/end"
        case .getListingStats(let id):
            return "/api/v1.0/listing/\(id)/stats"
        case .fetchOrders:
            return "/api/v1.0/orders"
        case .updateOrderStatus(let id, _):
            return "/api/v1.0/order/\(id)/status"
        case .refreshToken:
            return "/api/v1.0/auth/refresh"
        }
    }
    
    var method: String {
        switch self {
        case .createListing, .refreshToken:
            return "POST"
        case .endListing, .updateOrderStatus:
            return "PUT"
        case .getListingStats, .fetchOrders:
            return "GET"
        }
    }
    
    var headers: [String: String] {
        ["Content-Type": "application/json"]
    }
    
    var body: Data? {
        switch self {
        case .createListing(let request):
            return try? JSONEncoder().encode(request)
        case .updateOrderStatus(_, let status):
            return try? JSONEncoder().encode(["status": status.rawValue])
        case .refreshToken(let token):
            return try? JSONEncoder().encode(["refreshToken": token])
        default:
            return nil
        }
    }
}
```

#### eBay Request/Response Models
```swift
struct CreateListingRequest: Codable {
    let title: String
    let description: String
    let price: Decimal
    let quantity: Int
    let imageUrls: [String]
    let category: String
    
    init(from product: Product) {
        self.title = product.title
        self.description = product.description
        self.price = product.price
        self.quantity = product.quantity
        self.imageUrls = product.images.compactMap { $0.remoteURL?.absoluteString }
        self.category = product.category
    }
}

struct CreateListingResponse: Codable {
    let itemId: String
}

struct ListingStats: Codable {
    let views: Int
    let active: Bool
}

struct ListingStatsResponse: Codable {
    let stats: ListingStats
}

struct OrdersFetchResponse: Codable {
    let orders: [EBayOrderDTO]
}

struct EBayOrderDTO: Codable {
    let orderId: String
    let buyerName: String
    let itemPrice: Decimal
    let totalAmount: Decimal
    let fees: OrderFeesDTO
    let createdAt: Date
    
    func toOrder(platform: MarketplacePlatform) -> Order {
        Order(
            id: UUID(),
            platformOrderId: orderId,
            platform: platform,
            productId: nil,
            buyerName: buyerName,
            quantity: 1,
            itemPrice: itemPrice,
            totalAmount: totalAmount,
            fees: fees.toOrderFees(),
            status: .pending,
            createdAt: createdAt
        )
    }
}

struct OrderFeesDTO: Codable {
    let platformFee: Decimal
    let processingFee: Decimal
    let shippingFee: Decimal?
    
    func toOrderFees() -> OrderFees {
        OrderFees(
            platformFee: platformFee,
            paymentProcessingFee: processingFee,
            shippingFee: shippingFee
        )
    }
}

struct TokenRefreshResponse: Codable {
    let accessToken: String
    let expiresIn: Int
}

struct EmptyResponse: Codable {}
```

### Mercari API Client (Similar Pattern)
```swift
// Services/MercariAPIClient.swift
actor MercariAPIClient {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // Implement following same pattern as eBayAPIClient
    // Methods: createListing, deleteListing, getListingStats, fetchOrders, updateOrderStatus
}
```

### Facebook API Client (Similar Pattern)
```swift
// Services/FacebookAPIClient.swift
actor FacebookAPIClient {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    // Implement following same pattern as eBayAPIClient
    // Note: Use Facebook Graph API endpoint structure
}
```

5. PERSISTENCE LAYER
--------------------

### Persistence Manager
```swift
// Services/PersistenceManager.swift
import Foundation
import CoreData

actor PersistenceManager {
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    init() {
        self.container = NSPersistentContainer(name: "MarketplaceApp")
        self.container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data error: \(error)")
            }
        }

        self.context = container.newBackgroundContext()
        self.context.automaticallyMergesChangesFromParent = true
    }
    
    func save<T: Encodable>(_ object: T) throws {
        // Implement Core Data save logic
    }
    
    func update<T: Encodable>(_ object: T) throws {
        // Implement Core Data update logic
    }
    
    func fetch<T: Decodable>(_ type: T.Type) throws -> [T] {
        // Implement Core Data fetch logic
        return []
    }
    
    func delete<T>(_ type: T.Type, id: UUID) throws {
        // Implement Core Data delete logic
    }
}
```

### Keychain Manager
```swift
// Services/KeychainManager.swift
import Foundation
import Security

actor KeychainManager {
    func storeToken(_ token: String, for platform: MarketplacePlatform) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.marketplace.token",
            kSecAttrAccount as String: platform.rawValue,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }
    
    func retrieveToken(for platform: MarketplacePlatform) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.marketplace.token",
            kSecAttrAccount as String: platform.rawValue,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        guard let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
}

enum KeychainError: LocalizedError {
    case saveFailed
    case retrieveFailed
}
```

6. SWIFTUI VIEWS
----------------

### Tab Navigation Root
```swift
// Views/ContentView.swift
import SwiftUI

@main
struct MarketplaceApp: App {
    @StateObject private var listingService: ListingService
    @StateObject private var orderService: OrderAggregatorService
    @StateObject private var earningsService: EarningsService
    
    var body: some Scene {
        WindowGroup {
            TabView {
                // Inventory Tab
                InventoryView()
                    .tabItem {
                        Label("Inventory", systemImage: "list.bullet")
                    }
                    .environmentObject(listingService)
                
                // Orders Tab
                OrdersView()
                    .tabItem {
                        Label("Orders", systemImage: "bag")
                    }
                    .environmentObject(orderService)
                
                // Earnings Tab
                EarningsView()
                    .tabItem {
                        Label("Earnings", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .environmentObject(earningsService)
                
                // Settings Tab
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }
        }
    }
}
```

### Inventory Management View
```swift
// Views/InventoryView.swift
import SwiftUI

struct InventoryView: View {
    @EnvironmentObject var listingService: ListingService
    @State private var showCreateListing = false
    @State private var selectedProduct: Product?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(listingService.products) { product in
                    NavigationLink(value: product) {
                        ProductListRow(product: product, 
                                      listings: listingService.platformListings
                                        .filter { $0.productId == product.id })
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showCreateListing = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateListing) {
                CreateListingView(listingService: listingService)
            }
            .navigationDestination(for: Product.self) { product in
                ProductDetailView(product: product, listingService: listingService)
            }
        }
    }
}

struct ProductListRow: View {
    let product: Product
    let listings: [PlatformListing]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(product.title)
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text("\(product.quantity) in stock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("$\(product.price, format: .currency(code: \"USD\"))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                // Platform indicators
                HStack(spacing: 4) {
                    ForEach(listings) { listing in
                        Image(systemName: platformIcon(listing.platform))
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }
    
    private func platformIcon(_ platform: MarketplacePlatform) -> String {
        switch platform {
        case .ebay:
            return "e.circle.fill"
        case .mercari:
            return "m.circle.fill"
        case .facebook:
            return "f.circle.fill"
        }
    }
}

struct CreateListingView: View {
    @EnvironmentObject var listingService: ListingService
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var price: Decimal = 0
    @State private var quantity = 1
    @State private var selectedPlatforms: Set<MarketplacePlatform> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Product Details") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(4...)
                    TextField("Price", value: $price, format: .currency(code: "USD"))
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...1000)
                }
                
                Section("Publish To") {
                    ForEach(MarketplacePlatform.allCases, id: \.self) { platform in
                        Toggle(platform.rawValue, isOn: .init(
                            get: { selectedPlatforms.contains(platform) },
                            set: { if $0 { selectedPlatforms.insert(platform) } else { selectedPlatforms.remove(platform) } }
                        ))
                    }
                }
            }
            .navigationTitle("Create Listing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let product = Product(
                                id: UUID(),
                                title: title,
                                description: description,
                                price: price,
                                quantity: quantity,
                                category: "General",
                                condition: .good,
                                images: [],
                                tags: [],
                                createdAt: Date(),
                                updatedAt: Date()
                            )
                            
                            do {
                                try await listingService.createProduct(product)
                                try await listingService.publishToAllPlatforms(
                                    product,
                                    platforms: Array(selectedPlatforms)
                                )
                                dismiss()
                            } catch {
                                print("Error: \(error)")
                            }
                        }
                    }
                    .disabled(title.isEmpty || selectedPlatforms.isEmpty)
                }
            }
        }
    }
}
```

### Orders Dashboard
```swift
// Views/OrdersView.swift
import SwiftUI

struct OrdersView: View {
    @EnvironmentObject var orderService: OrderAggregatorService
    @State private var selectedFilter: OrderStatusFilter = .all
    
    var filteredOrders: [Order] {
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
                        NavigationLink(value: order) {
                            OrderListRow(order: order)
                        }
                    }
                }
            }
            .navigationTitle("Orders")
            .navigationDestination(for: Order.self) { order in
                OrderDetailView(order: order)
            }
            .task {
                do {
                    try await orderService.fetchOrdersFromAllPlatforms()
                } catch {
                    print("Error fetching orders: \(error)")
                }
            }
        }
    }
}
```

```swift
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
                Text("$\(order.totalAmount, format: .currency(code: "USD"))")
                    .fontWeight(.semibold)
            }
            
            Text(order.platform.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func statusColor(_ status: Order.OrderStatus) -> Color {
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
```

```swift
enum OrderStatusFilter: String, CaseIterable {
    case all = "All"
    case pending = "Pending"
    case shipped = "Shipped"
    case delivered = "Delivered"
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
```

### Earnings Dashboard
```swift
// Views/EarningsView.swift
import SwiftUI

struct EarningsView: View {
    @EnvironmentObject var earningsService: EarningsService
    @State private var selectedPeriod: EarningsPeriod = .thisMonth
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(EarningsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if let summary = earningsService.earningsSummary {
                    // Summary Cards
                    VStack(spacing: 12) {
                        EarningCard(
                            title: "Gross Sales",
                            amount: summary.totalGrossSales,
                            color: .blue
                        )
                        
                        EarningCard(
                            title: "Total Fees",
                            amount: summary.totalFees,
                            color: .red
                        )
                        
                        EarningCard(
                            title: "Net Earnings",
                            amount: summary.totalNetEarnings,
                            color: .green
                        )
                    }
                    .padding()
                    
                    // Platform Breakdown
                    Section("By Platform") {
                        VStack(spacing: 8) {
                            ForEach(summary.platformBreakdown.values.sorted(by: { $0.grossSales > $1.grossSales })) { platform in
                                HStack {
                                    Text(platform.platform.rawValue)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("$\(platform.grossSales, format: .currency(code: "USD"))")
                                            .fontWeight(.semibold)
                                        Text("\(platform.orderCount) orders")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                } else {
                    VStack {
                        ProgressView()
                        Text("Loading earnings...")
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Earnings")
            .task {
                let period = selectedPeriod.dateInterval
                await earningsService.calculateEarnings(for: period)
            }
        }
    }
}
```

```swift
struct EarningCard: View {
    let title: String
    let amount: Decimal
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("$\(amount, format: .currency(code: "USD"))")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
```

```swift
enum EarningsPeriod: String, CaseIterable {
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case thisYear = "This Year"
    
    var dateInterval: DateInterval {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .thisWeek:
            let start = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: now)
            let weekStart = calendar.date(from: start)!
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
            return DateInterval(start: weekStart, end: weekEnd)
            
        case .thisMonth:
            let start = calendar.dateComponents([.year, .month], from: now)
            let monthStart = calendar.date(from: start)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return DateInterval(start: monthStart, end: monthEnd)
            
        case .lastMonth:
            let start = calendar.dateComponents([.year, .month], from: now)
            var components = start
            components.month! -= 1
            let monthStart = calendar.date(from: components)!
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
            return DateInterval(start: monthStart, end: monthEnd)
            
        case .thisYear:
            let start = calendar.dateComponents([.year], from: now)
            let yearStart = calendar.date(from: start)!
            let yearEnd = calendar.date(byAdding: .year, value: 1, to: yearStart)!
            return DateInterval(start: yearStart, end: yearEnd)
        }
    }
}
```

### Settings & Platform Connection
```swift
// Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @State private var connectedAccounts: [PlatformAccount] = []
    @State private var showConnectSheet = false
    @State private var selectedPlatform: MarketplacePlatform?
    
    var body: some View {
        NavigationStack {
            List {
                Section("Connected Accounts") {
                    ForEach(connectedAccounts) { account in
                        HStack {
                            Image(systemName: platformIcon(account.platform))
                            VStack(alignment: .leading) {
                                Text(account.platform.rawValue)
                                    .font(.headline)
                                Text(account.accountName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if account.isTokenExpired {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.orange)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: { showConnectSheet = true }) {
                        HStack {
                            Image(systemName: "plus")
                            Text("Connect New Account")
                        }
                    }
                }
                
                Section("About") {
                    Text("Marketplace Manager v1.0")
                    Text("© 2025")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showConnectSheet) {
                ConnectPlatformView(isPresented: $showConnectSheet)
            }
        }
    }
    
    private func platformIcon(_ platform: MarketplacePlatform) -> String {
        switch platform {
        case .ebay:
            return "e.circle.fill"
        case .mercari:
            return "m.circle.fill"
        case .facebook:
            return "f.circle.fill"
        }
    }
}
```

```swift
struct ConnectPlatformView: View {
    @Binding var isPresented: Bool
    @State private var selectedPlatform: MarketplacePlatform = .ebay
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Select Platform") {
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(MarketplacePlatform.allCases, id: \.self) { platform in
                            Text(platform.rawValue).tag(platform)
                        }
                    }
                }
                
                Section {
                    Button(action: initiateOAuth) {
                        HStack {
                            Spacer()
                            Text("Connect with \(selectedPlatform.rawValue)")
                            Spacer()
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Connect Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
    
    private func initiateOAuth() {
        // Implement OAuth2 flow for selected platform
        // Open Safari/WebView with platform's OAuth endpoint
    }
}
```

7. DATA FLOW DIAGRAM
--------------------
```
User Interface (SwiftUI Views)
    ↓
View Models / Observed Objects
    ↓
Service Layer (Business Logic)
    ├─ ListingService
    ├─ OrderAggregatorService
    ├─ EarningsService
    └─ AuthenticationManager
    ↓
API Client Layer
    ├─ EBayAPIClient
    ├─ MercariAPIClient
    ├─ FacebookAPIClient
    └─ StripePaymentClient
    ↓
Platform APIs (eBay, Mercari, Facebook, Stripe)

Persistence & Security
    ├─ Core Data (Local caching)
    ├─ Keychain (Token storage)
    └─ UserDefaults (Settings)
```

8. IMPLEMENTATION ROADMAP
-------------------------
- **Phase 1: Foundation**
  - Core data models (Product, Order, PlatformAccount)
  - Base APIClient and authentication manager
  - Keychain/token management
  - Core Data setup
- **Phase 2: Platform Integration**
  - eBay API implementation
  - OAuth2 flow
  - Create/end listings
  - Fetch orders
  - Order status updates
  - Mercari API implementation (follow same pattern)
  - Facebook Graph API implementation (follow same pattern)
- **Phase 3: Core Services**
  - ListingService (create, edit, sync)
  - OrderAggregatorService (fetch, update, sync)
  - EarningsService (analytics, calculations)
- **Phase 4: UI Implementation**
  - Inventory management views
  - Order dashboard
  - Earnings analytics
  - Settings & platform connections
- **Phase 5: Polish & Testing**
  - Error handling & recovery
  - Offline support
  - Performance optimization
  - Unit & integration tests

9. KEY CONSIDERATIONS
---------------------
- **Security**
  - Always store tokens in Keychain, never UserDefaults
  - Implement token refresh before expiration
  - Use HTTPS for all API calls
  - Validate SSL certificates
- **Rate Limiting**
  - Implement exponential backoff for failed requests
  - Cache data locally to reduce API calls
  - Batch requests when possible (e.g., order syncing)
- **Sync Strategy**
  - Automatic sync every 5 minutes for orders
  - On-demand sync for listings
  - Background URL session for iOS 13+
- **Error Handling**
  - Graceful degradation when platform APIs fail
  - Show user-friendly error messages
  - Retry logic with user opt-in
- **Testing**
  - Mock API clients for unit testing
  - Core Data in-memory store for tests
  - Integration tests with sandbox APIs

10. NEXT STEPS
--------------
- OAuth2 Implementation: Set up redirect schemes and OAuth flows for each platform
- API Integration: Begin with eBay's comprehensive REST API
- Local Persistence: Implement Core Data models and migration strategy
- UI Flows: Build create listing → publish → view orders → track earnings
- Payment Processing: Integrate Stripe or PayPal for direct payments (optional)

This blueprint provides a professional, scalable foundation for a multi-platform marketplace management app. You can extend it with additional features like shipping label generation, inventory alerts, seller analytics, and more.
