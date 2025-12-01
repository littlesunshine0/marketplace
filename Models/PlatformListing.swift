import Foundation

public struct PlatformListing: Identifiable, Codable, Equatable {
    public let id: UUID
    public let productId: UUID
    public let platform: MarketplacePlatform
    public let platformListingId: String
    public var status: ListingStatus
    public var publishedAt: Date?
    public var expiresAt: Date?
    public var viewCount: Int
    public var platformURL: URL
    public var syncedAt: Date

    public init(
        id: UUID,
        productId: UUID,
        platform: MarketplacePlatform,
        platformListingId: String,
        status: ListingStatus,
        publishedAt: Date?,
        expiresAt: Date?,
        viewCount: Int,
        platformURL: URL,
        syncedAt: Date
    ) {
        self.id = id
        self.productId = productId
        self.platform = platform
        self.platformListingId = platformListingId
        self.status = status
        self.publishedAt = publishedAt
        self.expiresAt = expiresAt
        self.viewCount = viewCount
        self.platformURL = platformURL
        self.syncedAt = syncedAt
    }
}

public enum ListingStatus: String, Codable {
    case draft
    case active
    case paused
    case sold
    case expired
    case archived
}

public enum MarketplacePlatform: String, Codable, CaseIterable {
    case ebay = "eBay"
    case mercari = "Mercari"
    case facebook = "Facebook Marketplace"
}
