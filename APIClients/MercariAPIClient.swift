import Foundation

public protocol MercariAPIClientProtocol {
    func createListing(from product: Product) async throws -> String
    func deleteListing(listingId: String) async throws
    func getListingStats(listingId: String) async throws -> ListingStats
    func fetchOrders() async throws -> [Order]
    func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws
}

public actor MercariAPIClient: MercariAPIClientProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func createListing(from product: Product) async throws -> String {
        let request = CreateListingRequest(from: product)
        let response: CreateListingResponse = try await apiClient.request(
            MercariEndpoint.createListing(request),
            expecting: CreateListingResponse.self
        )
        return response.itemId
    }

    public func deleteListing(listingId: String) async throws {
        _ = try await apiClient.request(MercariEndpoint.deleteListing(listingId), expecting: EmptyResponse.self)
    }

    public func getListingStats(listingId: String) async throws -> ListingStats {
        let response: ListingStatsResponse = try await apiClient.request(
            MercariEndpoint.getListingStats(listingId),
            expecting: ListingStatsResponse.self
        )
        return response.stats
    }

    public func fetchOrders() async throws -> [Order] {
        let response: OrdersFetchResponse = try await apiClient.request(
            MercariEndpoint.fetchOrders,
            expecting: OrdersFetchResponse.self
        )
        return response.orders.map { $0.toOrder(platform: .mercari) }
    }

    public func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws {
        _ = try await apiClient.request(
            MercariEndpoint.updateOrderStatus(platformOrderId, status),
            expecting: EmptyResponse.self
        )
    }
}

public enum MercariEndpoint: APIEndpoint {
    case createListing(CreateListingRequest)
    case deleteListing(String)
    case getListingStats(String)
    case fetchOrders
    case updateOrderStatus(String, OrderStatus)

    public var platform: MarketplacePlatform { .mercari }

    public var path: String {
        switch self {
        case .createListing:
            return "/api/v1/listings"
        case .deleteListing(let id):
            return "/api/v1/listings/\(id)"
        case .getListingStats(let id):
            return "/api/v1/listings/\(id)/stats"
        case .fetchOrders:
            return "/api/v1/orders"
        case .updateOrderStatus(let id, _):
            return "/api/v1/orders/\(id)/status"
        }
    }

    public var method: String {
        switch self {
        case .createListing:
            return "POST"
        case .deleteListing:
            return "DELETE"
        case .updateOrderStatus:
            return "PUT"
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
