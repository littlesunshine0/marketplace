import Foundation

public struct ListingStats: Codable, Equatable {
    public let views: Int
    public let active: Bool

    public init(views: Int, active: Bool) {
        self.views = views
        self.active = active
    }
}

public protocol EBayAPIClientProtocol {
    func createListing(from product: Product) async throws -> String
    func endListing(listingId: String) async throws
    func getListingStats(listingId: String) async throws -> ListingStats
    func fetchOrders() async throws -> [Order]
    func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws
}

public actor EBayAPIClient: EBayAPIClientProtocol {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func createListing(from product: Product) async throws -> String {
        let request = CreateListingRequest(from: product)
        let response: CreateListingResponse = try await apiClient.request(
            EBayEndpoint.createListing(request),
            expecting: CreateListingResponse.self
        )
        return response.itemId
    }

    public func endListing(listingId: String) async throws {
        _ = try await apiClient.request(EBayEndpoint.endListing(listingId), expecting: EmptyResponse.self)
    }

    public func getListingStats(listingId: String) async throws -> ListingStats {
        let response: ListingStatsResponse = try await apiClient.request(
            EBayEndpoint.getListingStats(listingId),
            expecting: ListingStatsResponse.self
        )
        return response.stats
    }

    public func fetchOrders() async throws -> [Order] {
        let response: OrdersFetchResponse = try await apiClient.request(
            EBayEndpoint.fetchOrders,
            expecting: OrdersFetchResponse.self
        )
        return response.orders.map { $0.toOrder(platform: .ebay) }
    }

    public func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws {
        _ = try await apiClient.request(
            EBayEndpoint.updateOrderStatus(platformOrderId, status),
            expecting: EmptyResponse.self
        )
    }
}

public enum EBayEndpoint: APIEndpoint {
    case createListing(CreateListingRequest)
    case endListing(String)
    case getListingStats(String)
    case fetchOrders
    case updateOrderStatus(String, OrderStatus)

    public var platform: MarketplacePlatform { .ebay }

    public var path: String {
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
        }
    }

    public var method: String {
        switch self {
        case .createListing:
            return "POST"
        case .endListing, .updateOrderStatus:
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

public struct CreateListingRequest: Codable {
    public let title: String
    public let description: String
    public let price: Decimal
    public let quantity: Int
    public let imageUrls: [String]
    public let category: String

    public init(from product: Product) {
        title = product.title
        description = product.description
        price = product.price
        quantity = product.quantity
        imageUrls = product.images.compactMap { $0.remoteURL?.absoluteString }
        category = product.category
    }
}

public struct CreateListingResponse: Codable {
    public let itemId: String
}

public struct ListingStatsResponse: Codable {
    public let stats: ListingStats
}

public struct OrdersFetchResponse: Codable {
    public let orders: [EBayOrderDTO]
}

public struct EBayOrderDTO: Codable {
    public let orderId: String
    public let buyerName: String
    public let itemPrice: Decimal
    public let totalAmount: Decimal
    public let fees: OrderFeesDTO
    public let createdAt: Date

    public func toOrder(platform: MarketplacePlatform) -> Order {
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
            createdAt: createdAt,
            estimatedDeliveryAt: nil,
            paidAt: nil,
            shippedAt: nil
        )
    }
}

public struct OrderFeesDTO: Codable {
    public let platformFee: Decimal
    public let processingFee: Decimal
    public let shippingFee: Decimal?

    public func toOrderFees() -> OrderFees {
        OrderFees(
            platformFee: platformFee,
            paymentProcessingFee: processingFee,
            shippingFee: shippingFee
        )
    }
}

public struct EmptyResponse: Codable {}
