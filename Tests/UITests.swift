import XCTest

final class UITests: XCTestCase {
    func testPublishFlowShowsOptimisticJob() async throws {
        let persistence = PersistenceManager()
        let listingService = ListingService(
            persistenceManager: persistence,
            ebayClient: MockEbayAdapter(),
            mercariClient: MockMercariAdapter(),
            facebookClient: MockFacebookAdapter()
        )

        let product = Product(
            id: UUID(),
            title: "Vintage Tee",
            description: "Soft cotton tee",
            price: 20,
            quantity: 1,
            category: "Apparel",
            condition: .good,
            images: [],
            tags: [],
            createdAt: Date(),
            updatedAt: Date()
        )

        try await listingService.createProduct(product)
        try await listingService.publishToAllPlatforms(product, platforms: [.ebay, .mercari])

        XCTAssertEqual(listingService.publishJobs.count, 1)
        XCTAssertEqual(listingService.publishJobs.first?.status, .succeeded)
    }
}

private actor MockEbayAdapter: EBayAPIClientProtocol {
    func createListing(from product: Product) async throws -> String { "mock-ebay" }
    func endListing(listingId: String) async throws {}
    func getListingStats(listingId: String) async throws -> ListingStats { .init(views: 0, active: true) }
    func fetchOrders() async throws -> [Order] { [] }
    func updateOrderStatus(platformOrderId: String, status: OrderStatus) async throws {}
}
