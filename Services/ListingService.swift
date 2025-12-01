import Foundation
import Combine

@MainActor
public final class ListingService: ObservableObject {
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var platformListings: [PlatformListing] = []
    @Published public private(set) var publishJobs: [PublishJob] = []
    @Published public var isLoading = false
    @Published public var error: Error?

    private let persistenceManager: PersistenceManagerProtocol
    private let ebayClient: EBayAPIClientProtocol
    private let mercariClient: MercariAPIClientProtocol
    private let facebookClient: FacebookAPIClientProtocol

    public init(
        persistenceManager: PersistenceManagerProtocol,
        ebayClient: EBayAPIClientProtocol,
        mercariClient: MercariAPIClientProtocol,
        facebookClient: FacebookAPIClientProtocol
    ) {
        self.persistenceManager = persistenceManager
        self.ebayClient = ebayClient
        self.mercariClient = mercariClient
        self.facebookClient = facebookClient
    }

    // MARK: - Local Management

    public func createProduct(_ product: Product) async throws {
        try persistenceManager.save(product)
        await loadProducts()
    }

    public func updateProduct(_ product: Product) async throws {
        try persistenceManager.update(product)
        await loadProducts()
    }

    public func deleteProduct(_ id: UUID) async throws {
        try persistenceManager.delete(Product.self, id: id)
        try await deletePlatformListings(for: id)
        await loadProducts()
    }

    public func loadProducts() async {
        products = (try? persistenceManager.fetch(Product.self)) ?? []
        platformListings = (try? persistenceManager.fetch(PlatformListing.self)) ?? []
    }

    // MARK: - Multi-Platform Publishing

    public func publishToAllPlatforms(_ product: Product, platforms: [MarketplacePlatform]) async throws {
        isLoading = true
        defer { isLoading = false }

        let optimisticJob = PublishJob(
            id: UUID(),
            productId: product.id,
            platforms: Set(platforms),
            status: .inFlight,
            retryCount: 0,
            lastError: nil
        )
        publishJobs.append(optimisticJob)

        do {
            let tasks = platforms.map { publishToSinglePlatform(product, platform: $0) }
            try await Task.whenAllSucceed(tasks, returning: Void.self)
            updateJobStatus(for: optimisticJob.id, status: .succeeded)
        } catch {
            updateJobStatus(for: optimisticJob.id, status: .failed(error))
            Logger.error(category: "listing.publish", "Publish failed", metadata: ["productId": product.id.uuidString])
            throw error
        }
    }

    private func publishToSinglePlatform(_ product: Product, platform: MarketplacePlatform) async throws {
        let platformListingId: String

        switch platform {
        case .ebay:
            platformListingId = try await ebayClient.createListing(from: product)
        case .mercari:
            platformListingId = try await mercariClient.createListing(from: product)
        case .facebook:
            platformListingId = try await facebookClient.createListing(from: product)
        }

        let listing = PlatformListing(
            id: UUID(),
            productId: product.id,
            platform: platform,
            platformListingId: platformListingId,
            status: .active,
            publishedAt: Date(),
            expiresAt: Date().addingTimeInterval(30 * 24 * 3600),
            viewCount: 0,
            platformURL: URL(string: "https://example.com/item/\(platformListingId)")!,
            syncedAt: Date()
        )

        try persistenceManager.save(listing)
        await loadProducts()
        Logger.info(category: "listing.publish", "Published listing", metadata: ["platform": platform.rawValue, "productId": product.id.uuidString])
    }

    public func syncListingStats() async throws {
        isLoading = true
        defer { isLoading = false }

        for listing in platformListings {
            switch listing.platform {
            case .ebay:
                let stats = try await ebayClient.getListingStats(listingId: listing.platformListingId)
                try persist(stats: stats, for: listing, activeFlag: stats.active)
            case .mercari:
                let stats = try await mercariClient.getListingStats(listingId: listing.platformListingId)
                try persist(stats: stats, for: listing, activeFlag: stats.active)
            case .facebook:
                let stats = try await facebookClient.getListingStats(listingId: listing.platformListingId)
                try persist(stats: stats, for: listing, activeFlag: stats.active)
            }
        }
    }

    private func persist(stats: ListingStats, for listing: PlatformListing, activeFlag: Bool) throws {
        var updatedListing = listing
        updatedListing.viewCount = stats.views
        updatedListing.status = activeFlag ? .active : .sold
        updatedListing.syncedAt = Date()
        try persistenceManager.update(updatedListing)
    }

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

    public func retryFailedPublishes(maxRetries: Int = 3) async {
        for job in publishJobs where job.status.isRetryable && job.retryCount < maxRetries {
            guard let product = products.first(where: { $0.id == job.productId }) else { continue }
            for platform in job.platforms {
                do {
                    try await publishToSinglePlatform(product, platform: platform)
                } catch {
                    Logger.warning(category: "listing.publish", "Retry failed", metadata: ["platform": platform.rawValue, "productId": product.id.uuidString])
                    updateJobStatus(for: job.id, status: .failed(error), incrementRetry: true)
                    continue
                }
            }
            updateJobStatus(for: job.id, status: .succeeded)
        }
    }

    private func updateJobStatus(for jobId: UUID, status: PublishJob.Status, incrementRetry: Bool = false) {
        guard let index = publishJobs.firstIndex(where: { $0.id == jobId }) else { return }
        publishJobs[index].status = status
        publishJobs[index].lastError = status.errorDescription
        if incrementRetry { publishJobs[index].retryCount += 1 }
    }
}
