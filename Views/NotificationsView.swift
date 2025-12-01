import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var notifications: AppNotificationCenter

    var body: some View {
        List {
            Section("History") {
                ForEach(notifications.notifications) { notification in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            StatusBadge(text: notification.level.rawValue.capitalized, color: notification.level.color)
                            Spacer()
                            Text(notification.createdAt, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(notification.title)
                            .font(.headline)
                        Text(notification.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Notifications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear", role: .destructive) { notifications.clearAll() }
            }
        }
    }
}
