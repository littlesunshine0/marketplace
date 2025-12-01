import Foundation

public actor Scheduler {
    private let listingService: ListingService
    private let orderAggregator: OrderAggregatorService
    private let telemetry: TelemetryService

    public init(listingService: ListingService, orderAggregator: OrderAggregatorService, telemetry: TelemetryService) {
        self.listingService = listingService
        self.orderAggregator = orderAggregator
        self.telemetry = telemetry
    }

    public func runSyncCycle() async {
        Logger.info(category: "scheduler", "Starting sync cycle")
        do {
            try await orderAggregator.fetchOrdersFromAllPlatforms()
            telemetry.recordSyncSuccess()
        } catch {
            telemetry.recordRetry(reason: String(describing: error))
            Logger.error(category: "scheduler", "Order sync failed", metadata: ["error": String(describing: error)])
        }

        await listingService.retryFailedPublishes()
        Logger.info(category: "scheduler", "Completed sync cycle")
    }
}
