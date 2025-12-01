import SwiftUI

struct NotificationBannerStack: View {
    @ObservedObject var notifications: AppNotificationCenter

    var body: some View {
        VStack(spacing: 8) {
            ForEach(notifications.notifications.prefix(3)) { notification in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: icon(for: notification.level))
                        .foregroundColor(notification.level.color)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.headline)
                        Text(notification.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(notification.createdAt, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .shadow(radius: 2)
            }
        }
        .padding()
    }

    private func icon(for level: AppNotificationLevel) -> String {
        switch level {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        }
    }
}
