import Foundation
import SwiftUI

@MainActor
final class EarningsViewModel: ObservableObject {
    @Published var selectedPeriod: EarningsPeriod = .thisMonth
    @Published var summary: EarningsSummary?
    @Published var daily: [DailyEarnings] = []

    private let earningsService: EarningsService
    private let notifications: AppNotificationCenter

    init(earningsService: EarningsService, notifications: AppNotificationCenter) {
        self.earningsService = earningsService
        self.notifications = notifications
        Task { await refresh() }
    }

    func refresh() async {
        let interval = selectedPeriod.dateInterval
        await earningsService.calculateEarnings(for: interval)
        summary = earningsService.earningsSummary
        daily = earningsService.dailyEarnings
        notifications.push(AppNotification(title: "Earnings refreshed", message: selectedPeriod.rawValue, level: .info))
    }
}
