import Foundation

public protocol AuthenticationManaging {
    func validAccessToken(for platform: MarketplacePlatform) async throws -> String?
    func refreshToken(for platform: MarketplacePlatform) async throws
}

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

public actor AuthenticationManager: AuthenticationManaging {
    private let accountService: PlatformAccountService
    private let keychainManager: KeychainManager
    private let telemetry: TelemetryService?

    public init(accountService: PlatformAccountService, keychainManager: KeychainManager, telemetry: TelemetryService? = nil) {
        self.accountService = accountService
        self.keychainManager = keychainManager
        self.telemetry = telemetry
    }

    public func validAccessToken(for platform: MarketplacePlatform) async throws -> String? {
        guard let account = try await accountService.getAccount(for: platform) else {
            Logger.warning(category: "auth", "No stored account for platform", metadata: ["platform": platform.rawValue])
            return nil
        }

        if account.isTokenExpired {
            Logger.info(category: "auth", "Access token expired; attempting refresh", metadata: ["platform": platform.rawValue])
            try await refreshToken(for: platform)
            guard let refreshedAccount = try await accountService.getAccount(for: platform) else {
                Logger.error(category: "auth", "Account missing after refresh", metadata: ["platform": platform.rawValue])
                return nil
            }
            return try keychainManager.retrieveToken(for: refreshedAccount.platform)
        }

        return try keychainManager.retrieveToken(for: account.platform)
    }

    public func refreshToken(for platform: MarketplacePlatform) async throws {
        guard let account = try await accountService.getAccount(for: platform),
              let refreshToken = account.refreshToken else {
            Logger.error(category: "auth", "Refresh token unavailable", metadata: ["platform": platform.rawValue])
            throw AuthError.noRefreshToken
        }

        do {
            let newToken = try await accountService.refreshAccessToken(for: platform, refreshToken: refreshToken)
            try keychainManager.storeToken(newToken, for: platform)

            var updatedAccount = account
            updatedAccount.accessToken = newToken
            updatedAccount.tokenExpiresAt = Date().addingTimeInterval(3600)
            try await accountService.update(updatedAccount)
            Logger.info(category: "auth", "Refreshed access token", metadata: ["platform": platform.rawValue])
            telemetry?.recordTokenRefresh(platform: platform)
        } catch {
            Logger.error(
                category: "auth",
                "Token refresh failed",
                metadata: [
                    "platform": platform.rawValue,
                    "error": String(describing: error)
                ]
            )
            throw AuthError.tokenRefreshFailed
        }
    }
}

public protocol PlatformAccountService {
    func getAccount(for platform: MarketplacePlatform) async throws -> PlatformAccount?
    func update(_ account: PlatformAccount) async throws
    func refreshAccessToken(for platform: MarketplacePlatform, refreshToken: String) async throws -> String
}
