import Foundation

public protocol FacebookAPIClientProtocol {
    func createListing(from product: Product) async throws -> String
    func deleteListing(listingId: String) async throws
    func getListingStats(listingId: String) async throws -> ListingStats
    func fetchOrders() async throws -> [Order]
    func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws
}

public actor FacebookAPIClient: FacebookAPIClientProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func createListing(from product: Product) async throws -> String {
        let request = CreateListingRequest(from: product)
        let response: CreateListingResponse = try await apiClient.request(
            FacebookEndpoint.createListing(request),
            expecting: CreateListingResponse.self
        )
        return response.itemId
    }

    public func deleteListing(listingId: String) async throws {
        _ = try await apiClient.request(FacebookEndpoint.deleteListing(listingId), expecting: EmptyResponse.self)
    }

    public func getListingStats(listingId: String) async throws -> ListingStats {
        let response: ListingStatsResponse = try await apiClient.request(
            FacebookEndpoint.getListingStats(listingId),
            expecting: ListingStatsResponse.self
        )
        return response.stats
    }

    public func fetchOrders() async throws -> [Order] {
        let response: OrdersFetchResponse = try await apiClient.request(
            FacebookEndpoint.fetchOrders,
            expecting: OrdersFetchResponse.self
        )
        return response.orders.map { $0.toOrder(platform: .facebook) }
    }

    public func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws {
        _ = try await apiClient.request(
            FacebookEndpoint.updateOrderStatus(platformOrderId, status),
            expecting: EmptyResponse.self
        )
    }
}

public enum FacebookEndpoint: APIEndpoint {
    case createListing(CreateListingRequest)
    case deleteListing(String)
    case getListingStats(String)
    case fetchOrders
    case updateOrderStatus(String, OrderStatus)

    public var platform: MarketplacePlatform { .facebook }

    public var path: String {
        switch self {
        case .createListing:
            return "/graph/v18.0/listings"
        case .deleteListing(let id):
            return "/graph/v18.0/listings/\(id)"
        case .getListingStats(let id):
            return "/graph/v18.0/listings/\(id)/insights"
        case .fetchOrders:
            return "/graph/v18.0/orders"
        case .updateOrderStatus(let id, _):
            return "/graph/v18.0/orders/\(id)/status"
        }
    }

    public var method: String {
        switch self {
        case .createListing:
            return "POST"
        case .deleteListing:
            return "DELETE"
        case .updateOrderStatus:
            return "POST"
        case .getListingStats, .fetchOrders:
            return "GET"
        }
    }

    public var headers: [String: String] {
        ["Content-Type": "application/json"]
    }

    public var body: Data? {
        switch self {
        case .createListing(let request):
            return try? JSONEncoder().encode(request)
        case .updateOrderStatus(_, let status):
            return try? JSONEncoder().encode(["status": status.rawValue])
        default:
            return nil
        }
    }
}
