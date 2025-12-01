import Foundation

public enum KeychainError: LocalizedError {
    case saveFailed
    case retrieveFailed

    public var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save token"
        case .retrieveFailed:
            return "Failed to retrieve token"
        }
    }
}

public actor KeychainManager {
    private var storage: [MarketplacePlatform: String] = [:]

    public init() {}

    public func storeToken(_ token: String, for platform: MarketplacePlatform) throws {
        storage[platform] = token
    }

    public func retrieveToken(for platform: MarketplacePlatform) throws -> String? {
        storage[platform]
    }
}
