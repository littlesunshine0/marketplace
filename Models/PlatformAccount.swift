import Foundation

public struct PlatformAccount: Identifiable, Codable, Equatable {
    public let id: UUID
    public let platform: MarketplacePlatform
    public var accountName: String
    public var accessToken: String
    public var refreshToken: String?
    public var tokenExpiresAt: Date?
    public var scopes: [String]
    public var isActive: Bool
    public var connectedAt: Date

    public init(
        id: UUID,
        platform: MarketplacePlatform,
        accountName: String,
        accessToken: String,
        refreshToken: String?,
        tokenExpiresAt: Date?,
        scopes: [String],
        isActive: Bool,
        connectedAt: Date
    ) {
        self.id = id
        self.platform = platform
        self.accountName = accountName
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenExpiresAt = tokenExpiresAt
        self.scopes = scopes
        self.isActive = isActive
        self.connectedAt = connectedAt
    }

    public var isTokenExpired: Bool {
        guard let expiresAt = tokenExpiresAt else { return false }
        return Date() > expiresAt
    }
}
