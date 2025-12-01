import Foundation

public enum AuthError: LocalizedError {
    case noRefreshToken
    case tokenRefreshFailed

    public var errorDescription: String? {
        switch self {
        case .noRefreshToken:
            return "No refresh token available"
        case .tokenRefreshFailed:
            return "Token refresh failed"
        }
    }
}

public actor AuthenticationManager {
    private let accountService: PlatformAccountService
    private let keychainManager: KeychainManager

    public init(accountService: PlatformAccountService, keychainManager: KeychainManager) {
        self.accountService = accountService
        self.keychainManager = keychainManager
    }

    public func validAccessToken(for platform: MarketplacePlatform) async throws -> String? {
        guard let account = try await accountService.getAccount(for: platform) else {
            return nil
        }

        if account.isTokenExpired {
            try await refreshToken(for: platform)
            guard let refreshedAccount = try await accountService.getAccount(for: platform) else {
                return nil
            }
            return try keychainManager.retrieveToken(for: refreshedAccount.platform)
        }

        return try keychainManager.retrieveToken(for: account.platform)
    }

    public func refreshToken(for platform: MarketplacePlatform) async throws {
        guard let account = try await accountService.getAccount(for: platform),
              let refreshToken = account.refreshToken else {
            throw AuthError.noRefreshToken
        }

        let newToken = try await accountService.refreshAccessToken(for: platform, refreshToken: refreshToken)
        try keychainManager.storeToken(newToken, for: platform)

        var updatedAccount = account
        updatedAccount.accessToken = newToken
        updatedAccount.tokenExpiresAt = Date().addingTimeInterval(3600)
        try await accountService.update(updatedAccount)
    }
}

public protocol PlatformAccountService {
    func getAccount(for platform: MarketplacePlatform) async throws -> PlatformAccount?
    func update(_ account: PlatformAccount) async throws
    func refreshAccessToken(for platform: MarketplacePlatform, refreshToken: String) async throws -> String
}
