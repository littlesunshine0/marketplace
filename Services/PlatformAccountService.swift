import Foundation

public actor InMemoryAccountService: PlatformAccountService {
    private var accounts: [MarketplacePlatform: PlatformAccount] = [:]

    public init() {}

    public func getAccount(for platform: MarketplacePlatform) async throws -> PlatformAccount? {
        accounts[platform]
    }

    public func update(_ account: PlatformAccount) async throws {
        accounts[account.platform] = account
    }

    public func refreshAccessToken(for platform: MarketplacePlatform, refreshToken: String) async throws -> String {
        // Simulate refresh flow for demonstration purposes
        return "refreshed-\(platform.rawValue.lowercased())-token"
    }
}
