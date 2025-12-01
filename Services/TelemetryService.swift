import Foundation

public actor TelemetryService {
    public struct Metrics: Codable, Equatable {
        public var successfulSyncs: Int
        public var retryCount: Int
        public var tokenRefreshes: Int
        public var lastErrorReason: String?
    }

    private(set) var metrics = Metrics(successfulSyncs: 0, retryCount: 0, tokenRefreshes: 0, lastErrorReason: nil)

    public init() {}

    public func recordSyncSuccess() {
        metrics.successfulSyncs += 1
        Logger.info(category: "telemetry", "Sync success", metadata: ["count": "\(metrics.successfulSyncs)"])
    }

    public func recordRetry(reason: String) {
        metrics.retryCount += 1
        metrics.lastErrorReason = reason
        Logger.warning(category: "telemetry", "Retry triggered", metadata: ["reason": reason, "count": "\(metrics.retryCount)"])
    }

    public func recordTokenRefresh(platform: MarketplacePlatform) {
        metrics.tokenRefreshes += 1
        Logger.info(category: "telemetry", "Token refreshed", metadata: ["platform": platform.rawValue, "count": "\(metrics.tokenRefreshes)"])
    }
}
