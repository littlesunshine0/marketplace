import Foundation

public struct PublishJob: Identifiable, Codable, Equatable {
    public enum Status: Codable, Equatable {
        case inFlight
        case succeeded
        case failed(ErrorWrapper)

        var isRetryable: Bool {
            if case .failed = self { return true }
            return false
        }

        var errorDescription: String? {
            if case .failed(let wrapper) = self { return wrapper.message }
            return nil
        }
    }

    public struct ErrorWrapper: Codable, Equatable, Error {
        public let message: String
        public init(_ message: String) { self.message = message }
    }

    public let id: UUID
    public let productId: UUID
    public var platforms: Set<MarketplacePlatform>
    public var status: Status
    public var retryCount: Int
    public var lastError: String?

    public init(id: UUID, productId: UUID, platforms: Set<MarketplacePlatform>, status: Status, retryCount: Int, lastError: String?) {
        self.id = id
        self.productId = productId
        self.platforms = platforms
        self.status = status
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

public extension PublishJob.Status {
    static func failed(_ error: Error) -> PublishJob.Status { .failed(.init(String(describing: error))) }
}
