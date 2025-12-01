import Foundation
import SwiftUI

public enum AppNotificationLevel: String, Codable, CaseIterable, Identifiable {
    case info, success, warning, error
    public var id: String { rawValue }
    public var color: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

public struct AppNotification: Identifiable, Codable, Equatable {
    public let id: UUID
    public let title: String
    public let message: String
    public let level: AppNotificationLevel
    public let createdAt: Date
    public var isRead: Bool

    public init(id: UUID = UUID(), title: String, message: String, level: AppNotificationLevel, createdAt: Date = Date(), isRead: Bool = false) {
        self.id = id
        self.title = title
        self.message = message
        self.level = level
        self.createdAt = createdAt
        self.isRead = isRead
    }
}

@MainActor
public final class AppNotificationCenter: ObservableObject {
    @Published public private(set) var notifications: [AppNotification] = []

    public func push(_ notification: AppNotification) {
        notifications.insert(notification, at: 0)
    }

    public func markRead(_ id: UUID) {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else { return }
        notifications[index].isRead = true
    }

    public func clearAll() {
        notifications.removeAll()
    }
}
