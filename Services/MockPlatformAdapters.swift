import Foundation

/// Lightweight mock adapters to unblock UI flows while backends are under development.
public enum MockAdapterError: Error { case forcedFailure }

public actor MockMercariAdapter: MercariAPIClientProtocol {
    public var shouldFail: Bool
    public init(shouldFail: Bool = false) { self.shouldFail = shouldFail }

    public func createListing(from product: Product) async throws -> String {
        if shouldFail { throw MockAdapterError.forcedFailure }
        return "mock-mercari-\(product.id.uuidString.prefix(8))"
    }

    public func deleteListing(listingId: String) async throws {
        if shouldFail { throw MockAdapterError.forcedFailure }
    }

    public func getListingStats(listingId: String) async throws -> ListingStats {
        if shouldFail { throw MockAdapterError.forcedFailure }
        return ListingStats(views: Int.random(in: 0...25), active: Bool.random())
    }

    public func fetchOrders() async throws -> [Order] {
        if shouldFail { throw MockAdapterError.forcedFailure }
        return []
    }

    public func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws {
        if shouldFail { throw MockAdapterError.forcedFailure }
    }
}

public actor MockFacebookAdapter: FacebookAPIClientProtocol {
    public var shouldFail: Bool
    public init(shouldFail: Bool = false) { self.shouldFail = shouldFail }

    public func createListing(from product: Product) async throws -> String {
        if shouldFail { throw MockAdapterError.forcedFailure }
        return "mock-facebook-\(product.id.uuidString.prefix(8))"
    }

    public func deleteListing(listingId: String) async throws {
        if shouldFail { throw MockAdapterError.forcedFailure }
    }

    public func getListingStats(listingId: String) async throws -> ListingStats {
        if shouldFail { throw MockAdapterError.forcedFailure }
        return ListingStats(views: Int.random(in: 0...50), active: Bool.random())
    }

    public func fetchOrders() async throws -> [Order] {
        if shouldFail { throw MockAdapterError.forcedFailure }
        return []
    }

    public func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws {
        if shouldFail { throw MockAdapterError.forcedFailure }
    }
}
