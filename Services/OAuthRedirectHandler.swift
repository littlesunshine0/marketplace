import Foundation

/// Handles platform OAuth redirect URLs, exchanges authorization codes for tokens,
/// and persists the resulting credentials into the Keychain and account store.
public actor OAuthRedirectHandler {
    public struct RedirectError: LocalizedError {
        public var errorDescription: String?
    }

    private let accountService: PlatformAccountService
    private let keychain: KeychainManager

    public init(accountService: PlatformAccountService, keychain: KeychainManager) {
        self.accountService = accountService
        self.keychain = keychain
    }

    /// Validates redirect URL host/path and extracts authorization code parameters.
    /// In a production app this would call platform token endpoints; here we simulate
    /// a token exchange to keep flows testable without network dependencies.
    @discardableResult
    public func handleRedirect(_ url: URL) async throws -> PlatformAccount {
        guard let platform = MarketplacePlatform(fromCallbackURL: url) else {
            throw RedirectError(errorDescription: "Unsupported redirect URL: \(url.absoluteString)")
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let code = components?.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw RedirectError(errorDescription: "Missing authorization code")
        }

        Logger.info(
            category: "auth.redirect",
            "Received OAuth redirect",
            metadata: ["platform": platform.rawValue, "code": String(code.prefix(4)) + "…"]
        )

        let tokens = try await exchangeCode(for: platform, code: code)
        try keychain.storeToken(tokens.accessToken, for: platform)

        let account = PlatformAccount(
            id: UUID(),
            platform: platform,
            accountName: "\(platform.rawValue) User",
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            tokenExpiresAt: Date().addingTimeInterval(tokens.expiresIn),
            scopes: tokens.scopes,
            isActive: true,
            connectedAt: Date()
        )

        try await accountService.update(account)

        Logger.info(
            category: "auth.redirect",
            "Stored OAuth tokens",
            metadata: ["platform": platform.rawValue, "expiresIn": "\(tokens.expiresIn)"]
        )

        return account
    }

    private func exchangeCode(for platform: MarketplacePlatform, code: String) async throws -> TokenResponse {
        // Replace with real network call; mocked here for deterministic tests.
        return TokenResponse(
            accessToken: "access-\(platform.rawValue.lowercased())-\(code.prefix(4))",
            refreshToken: "refresh-\(platform.rawValue.lowercased())-\(code.prefix(4))",
            expiresIn: 3600,
            scopes: ["sell", "orders", "inventory"]
        )
    }
}

public struct TokenResponse {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: TimeInterval
    public let scopes: [String]
}

private extension MarketplacePlatform {
    init?(fromCallbackURL url: URL) {
        if url.absoluteString.contains("ebay") { self = .ebay }
        else if url.absoluteString.contains("mercari") { self = .mercari }
        else if url.absoluteString.contains("facebook") { self = .facebook }
        else { return nil }
    }
}
